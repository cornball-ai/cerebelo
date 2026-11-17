library(tinytest)

# parse_command: name plus the whole-remainder arg; non-commands are NULL.
expect_null(cerebelo::parse_command("hello"))
expect_null(cerebelo::parse_command("/"))
expect_null(cerebelo::parse_command("/ cd"))
expect_null(cerebelo::parse_command(NA_character_))
p <- cerebelo::parse_command("/cd ~/my proj")
expect_equal(p$name, "cd")
expect_equal(p$arg, "~/my proj")
rc <- cerebelo::parse_command("/rc")
expect_equal(rc$name, "rc")
expect_equal(rc$arg, "")
expect_equal(cerebelo::parse_command("!model opus", sigil = "!")$name, "model")

# handle_command: built-ins mutate the session and reply; the agent's own
# commands pass through; plain text is a prompt.
s <- cerebelo::session_state()
r1 <- cerebelo::handle_command(s, "/cd /home/troy/cerebelo")
expect_equal(r1$action, "reply")
expect_equal(s$cwd, "/home/troy/cerebelo")
expect_true(grepl("/home/troy/cerebelo", r1$text, fixed = TRUE))
cerebelo::handle_command(s, "/provider codex")
expect_equal(s$provider, "codex")
cerebelo::handle_command(s, "/model opus")
expect_equal(s$model, "opus")

# a missing argument is a usage note, with no mutation.
s2 <- cerebelo::session_state(cwd = "/start")
u <- cerebelo::handle_command(s2, "/cd")
expect_true(grepl("Usage", u$text, fixed = TRUE))
expect_equal(s2$cwd, "/start")

# unknown command -> passthrough; plain text -> prompt; rc -> not yet.
expect_equal(cerebelo::handle_command(s, "/compact")$action, "passthrough")
expect_equal(cerebelo::handle_command(s, "what's up")$action, "prompt")
rcr <- cerebelo::handle_command(s, "/rc")
expect_equal(rcr$action, "reply")
expect_true(grepl("not available", rcr$text, fixed = TRUE))

# every published command has a handler, so none silently passes through.
nms <- vapply(cerebelo::default_commands(),
              function(cmd) sub("\\s.*", "", cmd$syntax), character(1))
for (nm in nms) {
    res <- cerebelo::handle_command(cerebelo::session_state(), paste0("/", nm))
    expect_equal(res$action, "reply")
}
