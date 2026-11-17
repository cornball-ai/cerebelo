# The slash commands a session bot answers in its room. The built-ins here --
# cd, provider, model, rc -- are handled locally and change the session; a
# `/command` the bot does not own passes through to the agent (Claude's and
# Codex's own commands), and a plain message is an ordinary prompt. The names
# match default_commands(), so the published MSC4332 list and what the bot
# acts on stay one set.

#' A session's mutable state
#'
#' The slash handlers read and set a session's \code{cwd}, \code{provider},
#' and \code{model}. The event relay extends this record with the room,
#' thread, and agent-runner handle; the handlers here touch only those three
#' fields, in place, so the loop sees each change.
#'
#' @param cwd,provider,model Initial values, or NULL.
#' @return An environment holding \code{cwd}, \code{provider}, \code{model}.
#' @examples
#' s <- session_state(provider = "anthropic")
#' s$provider
#' @export
session_state <- function(cwd = NULL, provider = NULL, model = NULL) {
    e <- new.env(parent = emptyenv())
    e$cwd <- cwd
    e$provider <- provider
    e$model <- model
    e
}

#' Parse an inbound slash command
#'
#' Splits a message body into a command name and its argument. The name is the
#' first word after \code{sigil}; the argument is the rest of the line,
#' trimmed and kept whole, so a path with spaces survives. A body that does
#' not start with \code{sigil}, or carries only the sigil, is not a command.
#'
#' @param body The message text.
#' @param sigil The command prefix; \code{"/"} by default.
#' @return \code{list(name, arg)}, or NULL when \code{body} is not a command.
#' @examples
#' parse_command("/cd ~/proj")
#' parse_command("hello")
#' @export
parse_command <- function(body, sigil = "/") {
    if (!(is.character(body) && length(body) == 1L) || is.na(body)) {
        return(NULL)
    }
    b <- trimws(body)
    n <- nchar(sigil)
    if (!startsWith(b, sigil) || nchar(b) <= n) {
        return(NULL)
    }
    rest <- substring(b, n + 1L)
    name <- regmatches(rest, regexpr("^\\S+", rest))
    if (!length(name) || !nzchar(name)) {
        return(NULL)
    }
    arg <- trimws(substring(rest, nchar(name) + 1L))
    list(name = name, arg = arg)
}

# Built-in handlers. Each takes the session and the argument string and
# returns the line the bot replies with; cd/provider/model set a field, rc is
# a placeholder until terminal mirroring is wired (see the bot-side plan).
.cmd_cd <- function(session, arg) {
    if (!nzchar(arg)) {
        return("Usage: /cd <dir>")
    }
    session$cwd <- arg
    paste0("Working directory set to ", arg)
}

.cmd_provider <- function(session, arg) {
    if (!nzchar(arg)) {
        return("Usage: /provider <name>")
    }
    session$provider <- arg
    paste0("Provider set to ", arg)
}

.cmd_model <- function(session, arg) {
    if (!nzchar(arg)) {
        return("Usage: /model <name>")
    }
    session$model <- arg
    paste0("Model set to ", arg)
}

.cmd_rc <- function(session, arg) {
    "Terminal mirroring (/rc) is not available yet."
}

#' Handle an inbound message as a slash command
#'
#' Classifies a message and, for a built-in, acts on \code{session}. The
#' result's \code{action} is one of: \code{"reply"} (a built-in ran; send
#' \code{text}), \code{"passthrough"} (a \code{/command} the bot does not own;
#' forward it to the agent), or \code{"prompt"} (not a command; treat the body
#' as an ordinary prompt). The built-ins -- \code{cd}, \code{provider},
#' \code{model}, \code{rc} -- match \code{\link{default_commands}}.
#'
#' @param session A \code{\link{session_state}} the built-ins act on.
#' @param body The message text.
#' @param sigil The command prefix; \code{"/"} by default.
#' @return A list with \code{action}, and \code{text} when it is
#'   \code{"reply"}.
#' @examples
#' s <- session_state()
#' handle_command(s, "/cd ~/proj")
#' handle_command(s, "what's the plan?")
#' @export
handle_command <- function(session, body, sigil = "/") {
    parsed <- parse_command(body, sigil = sigil)
    if (is.null(parsed)) {
        return(list(action = "prompt"))
    }
    handler <- switch(parsed$name, cd = .cmd_cd, provider = .cmd_provider,
                      model = .cmd_model, rc = .cmd_rc, NULL)
    if (is.null(handler)) {
        return(list(action = "passthrough"))
    }
    list(action = "reply", text = handler(session, parsed$arg))
}
