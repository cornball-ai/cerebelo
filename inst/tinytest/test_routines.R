library(tinytest)

cerebelo:::.clear_routines()
on.exit(cerebelo:::.clear_routines(), add = TRUE)

# add_routine: registers and returns invisibly
e <- cerebelo::add_routine("noop", "hourly", function() NULL)
expect_equal(e$name, "noop")
expect_equal(e$schedule, "hourly")
expect_true(is.function(e$fn))
expect_true(is.na(e$last_fired))

# list_routines: returns a data.frame with one row
df <- cerebelo::list_routines()
expect_inherits(df, "data.frame")
expect_equal(nrow(df), 1L)
expect_equal(df$name, "noop")
expect_true(is.na(df$last_fired))
expect_inherits(df$next_fire, "POSIXct")

# add_routine: invalid schedule rejected
expect_error(cerebelo::add_routine("bad", "nonsense", function() NULL))
expect_error(cerebelo::add_routine("bad", "Mon 99:99", function() NULL))

# add_routine: validates types
expect_error(cerebelo::add_routine(1, "hourly", function() NULL))
expect_error(cerebelo::add_routine("x", 1, function() NULL))
expect_error(cerebelo::add_routine("x", "hourly", "not a function"))

# remove_routine: returns TRUE for present, FALSE for missing
expect_true(cerebelo::remove_routine("noop"))
expect_false(cerebelo::remove_routine("noop"))
expect_equal(nrow(cerebelo::list_routines()), 0L)

# tick_routines: a freshly-registered routine (NA last_fired) does not
# fire on first tick. The tick watermarks it to now so the next
# scheduled occurrence fires on its own. Catches a regression where the
# baseline was now-1, leaving only a 1-second window per scheduled
# second to fire on a 30-second tick interval.
cerebelo:::.clear_routines()
counter_na <- 0L
cerebelo::add_routine("watermark", "hourly", function() {
    counter_na <<- counter_na + 1L
})
n_init <- cerebelo::tick_routines(state_path = NULL)
expect_equal(n_init, 0L)
expect_equal(counter_na, 0L)
expect_false(is.na(cerebelo:::.get_last_fired("watermark")))

# tick_routines: fires past-due routines, updates last_fired
cerebelo:::.clear_routines()
counter <- 0L
cerebelo::add_routine("ticker", "hourly", function() {
    counter <<- counter + 1L
})
# Force a baseline two hours in the past so an hourly routine is due.
cerebelo:::.set_last_fired("ticker", Sys.time() - 7200)

n <- cerebelo::tick_routines(state_path = NULL)
expect_equal(n, 1L)
expect_equal(counter, 1L)

# Second tick within the same hour: nothing fires.
n2 <- cerebelo::tick_routines(state_path = NULL)
expect_equal(n2, 0L)
expect_equal(counter, 1L)

# tick_routines: catches and reports errors, keeps going
cerebelo:::.clear_routines()
cerebelo::add_routine("boom", "hourly",
                     function() stop("intentional"))
cerebelo::add_routine("ok", "hourly", function() invisible(NULL))
cerebelo:::.set_last_fired("boom", Sys.time() - 7200)
cerebelo:::.set_last_fired("ok",   Sys.time() - 7200)

# Capture the message stream so test output stays clean.
out <- capture.output(
    n <- cerebelo::tick_routines(state_path = NULL),
    type = "message"
)
expect_equal(n, 2L)  # both fire even though one errors
expect_true(any(grepl("\\[routine boom\\] error", out)))

cerebelo:::.clear_routines()
