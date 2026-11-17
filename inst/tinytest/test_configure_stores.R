library(tinytest)

cfgstore <- cerebelo:::.configure_store
cfgstores <- cerebelo:::.configure_stores

# .configure_store: an absent or empty path configures nothing; a present
# path exports the env var even with no setter.
local({
    nm <- "CEREBELO_TEST_ENV"
    was <- Sys.getenv(nm, unset = NA)
    on.exit({
        if (is.na(was)) Sys.unsetenv(nm) else Sys.setenv(CEREBELO_TEST_ENV = was)
    }, add = TRUE)
    Sys.unsetenv(nm)

    expect_false(cfgstore(NULL, nm, "vault", identity))
    expect_false(cfgstore("", nm, "vault", identity))
    expect_equal(Sys.getenv(nm), "")

    expect_true(cfgstore("/tmp/x", nm, "vault", NULL))
    expect_equal(Sys.getenv(nm), "/tmp/x")
})

# .configure_store: a setter runs with the path; a failing setter is
# caught so a bad path never stops the caller, and the env var still went
# out for the child scripts.
local({
    nm <- "CEREBELO_TEST_ENV"
    was <- Sys.getenv(nm, unset = NA)
    on.exit({
        if (is.na(was)) Sys.unsetenv(nm) else Sys.setenv(CEREBELO_TEST_ENV = was)
    }, add = TRUE)

    seen <- NULL
    cfgstore("/tmp/y", nm, "vault", function(p) seen <<- p)
    expect_equal(seen, "/tmp/y")

    msgs <- character()
    withCallingHandlers(
        expect_true(cfgstore("/tmp/z", nm, "vault", function(p) stop("nope"))),
        message = function(m) {
            msgs <<- c(msgs, conditionMessage(m))
            invokeRestart("muffleMessage")
        })
    expect_equal(Sys.getenv(nm), "/tmp/z")
    expect_true(any(grepl("not usable", msgs, fixed = TRUE)))
})

# .configure_stores: wire the two config keys to PENSAR_VAULT and
# HACER_REPO; an empty config touches neither.
local({
    wv <- Sys.getenv("PENSAR_VAULT", unset = NA)
    wh <- Sys.getenv("HACER_REPO", unset = NA)
    opt <- getOption("pensar.vault")
    tv <- tempfile("vlt-")
    td <- tempfile("todo-")
    on.exit({
        if (is.na(wv)) Sys.unsetenv("PENSAR_VAULT") else Sys.setenv(PENSAR_VAULT = wv)
        if (is.na(wh)) Sys.unsetenv("HACER_REPO") else Sys.setenv(HACER_REPO = wh)
        options(pensar.vault = opt)
        unlink(c(tv, td), recursive = TRUE)
    }, add = TRUE)

    suppressMessages(cfgstores(list(vault = tv, todo = td)))
    expect_equal(Sys.getenv("PENSAR_VAULT"), tv)
    expect_equal(Sys.getenv("HACER_REPO"), td)

    Sys.unsetenv("PENSAR_VAULT")
    suppressMessages(cfgstores(list()))
    expect_equal(Sys.getenv("PENSAR_VAULT"), "")
})
