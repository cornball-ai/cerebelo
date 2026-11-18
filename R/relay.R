# The agent-session relay: the per-room state a session keeps, and the
# routing of an inbound message. An agent runs in a Matrix room; cerebelo
# binds a session to that room, drives the agent (acp.api, later), and maps
# its events to ai.cornball.agent messages (R/agent_events.R, R/codex_events.R).
# This file holds the session registry and the inbound router. The drive loop
# that pumps the runner joins it once acp.api is a dependency.

#' A registry of per-room agent sessions
#'
#' A session is bound to the room it serves. The registry maps a room id to
#' its bound session; \code{\link{session_for}} looks one up and
#' \code{\link{bind_session}} adds one.
#'
#' @return An environment, the empty registry.
#' @examples
#' reg <- session_registry()
#' bind_session(reg, "!room:host", provider = "codex")
#' session_for(reg, "!room:host")$provider
#' @name session_registry
#' @export
session_registry <- function() {
    new.env(parent = emptyenv())
}

#' @rdname session_registry
#'
#' @details \code{bind_session} extends a \code{\link{session_state}} with the
#'   room it serves, the agent runner that drives it, and the live turn state
#'   the relay keeps: the current turn id, a text buffer flushed at
#'   boundaries, the tool-call-id to event-id map for in-place card edits, and
#'   the pending approvals.
#'
#' @param registry A \code{session_registry}.
#' @param room_id The room the session serves.
#' @param runner The agent-runner handle, or NULL until one is attached.
#' @param session_id The agent session id the events carry, or NULL until the
#'   runner assigns one.
#' @param cwd,provider,model Initial session fields, passed to
#'   \code{\link{session_state}}.
#' @return \code{bind_session} returns the bound session, an environment, also
#'   stored in \code{registry}.
#' @export
bind_session <- function(registry, room_id, runner = NULL, session_id = NULL,
                         cwd = NULL, provider = NULL, model = NULL) {
    s <- session_state(cwd = cwd, provider = provider, model = model)
    s$room <- room_id
    s$session_id <- session_id
    s$runner <- runner
    s$turn <- NULL
    s$buffer <- ""
    s$tool_events <- new.env(parent = emptyenv())
    s$approvals <- new.env(parent = emptyenv())
    assign(room_id, s, envir = registry)
    s
}

#' @rdname session_registry
#'
#' @return \code{session_for} returns the bound session, or NULL.
#' @export
session_for <- function(registry, room_id) {
    if (exists(room_id, envir = registry, inherits = FALSE)) {
        get(room_id, envir = registry, inherits = FALSE)
    } else {
        NULL
    }
}

#' Classify an inbound message for the relay
#'
#' Routes a message arriving in a session room. Session controls come first:
#' an \code{approval_response} (the app's \code{ai.cornball.agent} key, or a
#' \code{/approve}//\code{/deny} typed in a stock client) and \code{/stop}.
#' Anything else falls to \code{\link{handle_command}}: a built-in acts on the
#' session, a \code{/command} the bot does not own passes through to the
#' agent, and plain text is an ordinary prompt.
#'
#' The approval result carries the \code{approval_id} and either an explicit
#' \code{option_id} (when the app named one) or a \code{decision} of
#' \code{"approve"} / \code{"deny"} (from a typed command); the resolver that
#' holds the pending request maps a decision to one of its options.
#'
#' @param session A session bound by \code{\link{bind_session}}.
#' @param message A chat.api message: its \code{body}, and \code{raw$content}
#'   for the namespaced key.
#' @param sigil The command prefix; \code{"/"} by default.
#' @return A list with \code{action}: \code{"approval"} (with
#'   \code{approval_id}, and \code{option_id} or \code{decision}),
#'   \code{"stop"}, or one of \code{\link{handle_command}}'s results
#'   (\code{"reply"} / \code{"passthrough"} / \code{"prompt"}).
#' @examples
#' s <- session_state()
#' relay_inbound(s, list(body = "/approve a1"))
#' relay_inbound(s, list(body = "fix the test"))
#' @export
relay_inbound <- function(session, message, sigil = "/") {
    key <- tryCatch(message$raw$content[[.AGENT_EVENT_KEY]],
                    error = function(e) NULL)
    if (is.list(key) && identical(key$kind, "approval_response")) {
        return(list(action = "approval", approval_id = key$approval_id,
                    option_id = key$option_id, decision = NULL))
    }
    body <- message$body %||% ""
    parsed <- parse_command(body, sigil = sigil)
    if (!is.null(parsed)) {
        if (parsed$name == "approve" || parsed$name == "deny") {
            return(list(action = "approval", approval_id = parsed$arg,
                        option_id = NULL, decision = parsed$name))
        }
        if (parsed$name == "stop") {
            return(list(action = "stop"))
        }
    }
    handle_command(session, body, sigil = sigil)
}

#' Turn an agent event into a room operation
#'
#' Applies one \code{\link{agent_events}} payload to a session: streamed text
#' is buffered and flushed at a boundary, a tool event is sent once and then
#' edited in place by \code{tool_call_id}, an approval is sent and remembered,
#' and the rest are sent as they arrive. \code{thought} is dropped (the draft
#' omits it unless a room opts in).
#'
#' @param session A session bound by \code{\link{bind_session}}.
#' @param event An event payload from an \code{\link{agent_events}}
#'   constructor or the ACP / Codex mappers.
#' @param send A function \code{send(content)} that posts a message and
#'   returns its event id. A capturing fake in tests; chat.api's send carrying
#'   the namespaced content in the live relay.
#' @param edit A function \code{edit(event_id, content)} that replaces a prior
#'   message, or NULL to post a tool update as a fresh message instead.
#' @return Invisibly NULL; the session's buffer, tool map, approvals and turn
#'   are updated in place.
#' @examples
#' reg <- session_registry()
#' s <- bind_session(reg, "!r:host", session_id = "s1")
#' relay_emit(s, agent_text("Hi.", "s1", "t1", final = TRUE),
#'            send = function(content) "$e1")
#' @export
relay_emit <- function(session, event, send, edit = NULL) {
    kind <- event$kind %||% ""
    if (!is.null(event$session_id)) {
        session$session_id <- event$session_id
    }
    if (!is.null(event$turn_id)) {
        session$turn <- event$turn_id
    }
    if (kind == "text") {
        session$buffer <- paste0(session$buffer, event$text %||% "")
        if (isTRUE(event$final)) {
            .relay_flush_text(session, send)
        }
        return(invisible())
    }
    if (kind == "thought") {
        return(invisible())
    }
    # Every other kind is a boundary: flush pending text before it.
    .relay_flush_text(session, send)
    if (kind == "tool") {
        .relay_tool(session, event, send, edit)
    } else {
        send(agent_message(event))
    }
    if (kind == "approval_request") {
        assign(event$approval_id, event, envir = session$approvals)
    } else if (kind == "turn_end") {
        session$turn <- NULL
    }
    invisible()
}

# Flush the pending text as one message, then clear the buffer.
.relay_flush_text <- function(session, send) {
    if (!nzchar(session$buffer %||% "")) {
        return(invisible())
    }
    ev <- agent_text(session$buffer, session$session_id %||% "",
                     session$turn, final = TRUE)
    send(agent_message(ev))
    session$buffer <- ""
    invisible()
}

# Send a tool card the first time its tool_call_id is seen, recording the
# event id; edit that event in place on an update. With no edit function, or
# an id never seen, send a fresh message.
.relay_tool <- function(session, event, send, edit) {
    tcid <- event$tool_call_id
    seen <- if (!is.null(tcid) && exists(tcid, envir = session$tool_events,
            inherits = FALSE)) {
        get(tcid, envir = session$tool_events, inherits = FALSE)
    } else {
        NULL
    }
    content <- agent_message(event)
    if (is.null(seen) || is.null(edit)) {
        eid <- send(content)
        if (!is.null(tcid) && !is.null(eid)) {
            assign(tcid, eid, envir = session$tool_events)
        }
    } else {
        edit(seen, content)
    }
    invisible()
}
