# The MSC4332 command-list state event. cerebelo publishes a bot's slash
# commands here; a client reads them for autocomplete. The type is the
# proposal's unstable name and the state key is the bot's own user id, so a
# room can carry one command list per bot.
# See https://github.com/matrix-org/matrix-spec-proposals/pull/4332.
.MSC4332_TYPE <- "org.matrix.msc4332.commands"

#' A bot's built-in session commands
#'
#' The slash commands every agent-session bot answers, in the shape
#' \code{\link{command_list_content}} and \code{\link{publish_commands}}
#' expect: a list of entries, each with a \code{syntax} string whose first
#' word is the command name, a plain-text \code{description}, and an
#' \code{arguments} list of \code{list(type, description)} (empty when the
#' command takes none).
#'
#' \code{cd} sets the session's working directory, \code{provider} and
#' \code{model} switch the agent, and \code{rc} mirrors a live terminal
#' session into the room. A persona appends its own entries in config and
#' passes the combined list to \code{publish_commands()}.
#'
#' @return A list of command entries.
#' @examples
#' str(default_commands())
#' @export
default_commands <- function() {
    list(
         .command("cd {dir}",
                  "Set the session's working directory on the host",
                  .argument("string", "Directory")),
         .command("provider {name}", "Switch the session's provider",
                  .argument("string", "Provider")),
         .command("model {name}", "Switch the session's model",
                  .argument("string", "Model")),
         .command("rc", "Mirror a live terminal session into this room")
    )
}

# One command entry; the dots are zero or more .argument() lists.
.command <- function(syntax, description, ...) {
    list(syntax = syntax, description = description, arguments = list(...))
}

# One command argument.
.argument <- function(type, description) {
    list(type = type, description = description)
}

# An MSC4332 rich-text block: a plain string in the event's text shape.
.cmd_text <- function(s) {
    list("m.text" = list(list(body = s)))
}

# One command as MSC4332 content. `arguments` is omitted when there are
# none, matching the proposal's examples for argument-less commands.
.command_content <- function(cmd) {
    out <- list(syntax = cmd$syntax, description = .cmd_text(cmd$description))
    if (length(cmd$arguments)) {
        out$arguments <- lapply(cmd$arguments, function(a) {
            list(type = a$type, description = .cmd_text(a$description))
        })
    }
    out
}

#' Build the MSC4332 command-list event content
#'
#' Formats a command list (see \code{\link{default_commands}}) as the content
#' of an \code{org.matrix.msc4332.commands} state event: a \code{sigil} and a
#' \code{commands} array whose entries carry \code{syntax}, an \code{m.text}
#' \code{description}, and optional typed \code{arguments}. Pure, so the shape
#' is testable without a transport.
#'
#' @param commands A list of command entries, as \code{default_commands()}
#'   returns.
#' @param sigil The command prefix; \code{"/"} by default.
#' @return A named list, ready as the content for
#'   \code{\link[chat.api]{chat_set_state}}.
#' @examples
#' str(command_list_content())
#' @export
command_list_content <- function(commands = default_commands(), sigil = "/") {
    list(sigil = sigil, commands = lapply(commands, .command_content))
}

#' Publish a bot's command list to a room
#'
#' Writes the bot's slash-command list as an \code{org.matrix.msc4332.commands}
#' state event in \code{room_id}, keyed by the bot's own user id, so a client
#' can offer autocomplete. Call it when the list changes: on joining a session
#' room, and after a command alters it (for example a provider switch that
#' brings different agent commands). The write goes through chat.api's
#' state-event support, so it is not tied to one homeserver.
#'
#' @param client A chat.api client with state-event support
#'   (\code{chat_capabilities(client)$set_state}).
#' @param room_id The room to publish into.
#' @param commands The command list; \code{default_commands()} by default.
#' @param self_id The bot's user id for the state key; read from the client
#'   with \code{\link[chat.api]{chat_whoami}} when NULL.
#' @param sigil The command prefix; \code{"/"} by default.
#' @return Invisibly, the result of the state write.
#' @examples
#' \dontrun{
#' publish_commands(client, "!session:cornball.ai")
#' }
#' @export
publish_commands <- function(client, room_id, commands = default_commands(),
                             self_id = NULL, sigil = "/") {
    self_id <- self_id %||% chat.api::chat_whoami(client)$id
    content <- command_list_content(commands, sigil = sigil)
    invisible(chat.api::chat_set_state(client, room_id, .MSC4332_TYPE,
                                       content, state_key = self_id))
}
