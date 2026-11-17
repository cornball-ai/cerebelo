library(tinytest)

cerebelo:::.clear_routines()
on.exit({
    cerebelo:::.clear_routines()
    Sys.unsetenv("CEREBRO_STATE_DIR")
}, add = TRUE)

dir <- tempfile("cerebelo-state-")
Sys.setenv(CEREBRO_STATE_DIR = dir)
on.exit(unlink(dir, recursive = TRUE), add = TRUE)

# routines_state_path honors env override
expect_equal(cerebelo::routines_state_path(),
             file.path(dir, "routines.json"))

# save then load: last_fired round-trips through JSON
cerebelo::add_routine("a", "hourly", function() NULL)
cerebelo::add_routine("b", "Mon 09:00", function() NULL)
ts <- as.numeric(as.POSIXct("2026-04-25 14:00:00"))
cerebelo:::.set_last_fired("a", ts)
cerebelo:::save_routines_state(cerebelo::routines_state_path())
expect_true(file.exists(cerebelo::routines_state_path()))

# Wipe in-memory last_fired, reload from disk.
cerebelo:::.set_last_fired("a", NA_real_)
n <- cerebelo:::load_routines_state(cerebelo::routines_state_path())
expect_equal(n, 1L)  # only "a" had a saved last_fired
expect_equal(cerebelo:::.get_last_fired("a"), ts)
expect_true(is.na(cerebelo:::.get_last_fired("b")))

# load_routines_state ignores entries for routines no longer registered
cerebelo::remove_routine("a")
n <- cerebelo:::load_routines_state(cerebelo::routines_state_path())
expect_equal(n, 0L)

# load_routines_state on missing file is a no-op
file.remove(cerebelo::routines_state_path())
expect_equal(cerebelo:::load_routines_state(cerebelo::routines_state_path()),
             0L)

cerebelo:::.clear_routines()
