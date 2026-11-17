library(tinytest)

# default_commands: the four built-ins; cd carries one argument, rc none.
cmds <- cerebelo::default_commands()
expect_equal(length(cmds), 4L)
expect_equal(cmds[[1]]$syntax, "cd {dir}")
expect_equal(length(cmds[[1]]$arguments), 1L)
expect_equal(cmds[[1]]$arguments[[1]]$type, "string")
expect_equal(cmds[[4]]$syntax, "rc")
expect_equal(length(cmds[[4]]$arguments), 0L)

# command_list_content: the MSC4332 shape -- sigil, a commands array, an
# m.text description, and arguments only where the command has them.
ct <- cerebelo::command_list_content()
expect_equal(ct$sigil, "/")
expect_equal(length(ct$commands), 4L)
cd <- ct$commands[[1]]
expect_equal(cd$syntax, "cd {dir}")
expect_equal(cd$description[["m.text"]][[1]]$body,
             "Set the session's working directory on the host")
expect_equal(cd$arguments[[1]]$type, "string")
expect_equal(cd$arguments[[1]]$description[["m.text"]][[1]]$body, "Directory")
# An argument-less command omits `arguments` entirely.
expect_true(is.null(ct$commands[[4]]$arguments))

# A custom list round-trips, under a custom sigil; the command name is the
# first word of syntax.
custom <- list(list(syntax = "deploy {env}", description = "Ship it",
                    arguments = list(list(type = "string",
                                          description = "Env"))))
cc <- cerebelo::command_list_content(custom, sigil = "!")
expect_equal(cc$sigil, "!")
expect_equal(cc$commands[[1]]$syntax, "deploy {env}")
expect_equal(sub(" .*", "", cc$commands[[1]]$syntax), "deploy")
expect_equal(cc$commands[[1]]$description[["m.text"]][[1]]$body, "Ship it")

# publish_commands: writes the MSC4332 type into the room, keyed by the bot
# id chat_whoami reports, with the built content. A fake chat.api adapter
# captures the state write; no homeserver.
local({
    seen <- new.env(parent = emptyenv())
    registerS3method("chat_whoami", "cmd_fake",
                     function(client, ...) list(id = "@tiny:cornball.ai"),
                     envir = asNamespace("chat.api"))
    registerS3method("chat_set_state", "cmd_fake",
                     function(client, channel, type, content, state_key = "",
                              ...) {
                         seen$channel <- channel
                         seen$type <- type
                         seen$state_key <- state_key
                         seen$content <- content
                         "ok"
                     },
                     envir = asNamespace("chat.api"))
    fake <- structure(list(), class = "cmd_fake")
    cerebelo::publish_commands(fake, "!session:cornball.ai")
    expect_equal(seen$type, "org.matrix.msc4332.commands")
    expect_equal(seen$state_key, "@tiny:cornball.ai")
    expect_equal(seen$channel, "!session:cornball.ai")
    expect_equal(seen$content$sigil, "/")
    expect_equal(length(seen$content$commands), 4L)

    # An explicit self_id skips the chat_whoami lookup.
    cerebelo::publish_commands(fake, "!other:cornball.ai",
                               self_id = "@cornelius:cornball.ai")
    expect_equal(seen$state_key, "@cornelius:cornball.ai")
})
