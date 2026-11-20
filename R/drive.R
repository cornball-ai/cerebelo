# The agent drive loop: cerebelo polls a chat room, drives an agent over
# acp.api for each turn, and renders the agent's events as
# ai.cornball.agent cards through chat.api. This is the half of run()'s
# loop that stands in for corteza's own bot_run_step when a room is backed
# by an external ACP agent. Codex is the first; the Codex event mapping is
# R/codex_events.R, the card codec R/agent_events.R, and the session
# registry and inbound router R/relay.R.

#' Render a running agent turn into a chat room
#'
#' Builds the pair of callbacks acp.api's Codex client drives a turn with.
#' \code{on_event} maps each Codex event to an \code{\link{agent_events}}
#' card and sends it; \code{on_approval} posts the approval card and, for
#' now, declines. Every raw event passes to \code{capture} first, so the
#' stream can be recorded while the Codex mapping (R/codex_events.R) is
#' still being filled in.
#'
#' @param chat A chat.api client.
#' @param room_id Character. The room the cards go to.
#' @param session A relay session bound by \code{\link{bind_session}}; its
#'   \code{session_id} tags the cards.
#' @param capture Function of \code{(method, params)}, or NULL.
#' @return A list with \code{on_event}, \code{on_approval}, \code{send} and
#'   \code{edit}: the first two for \code{codex_turn}, the last two the
#'   room operations \code{\link{relay_emit}} drives.
#' @keywords internal
.codex_handlers <- function(chat, room_id, session, capture = NULL) {
    send <- function(content) {
        ids <- chat.api::chat_send(chat, room_id,
                                   text = content$body %||% "",
                                   kind = .content_kind(content),
                                   content = .card_keys(content))
        if (length(ids)) {
            ids[[length(ids)]]
        } else {
            NULL
        }
    }
    edit <- function(message_id, content) {
        chat.api::chat_edit(chat, room_id, message_id,
                            text = content$body %||% "", content = .card_keys(content))
        invisible(NULL)
    }
    on_event <- function(method, params) {
        if (!is.null(capture)) {
            capture(method, params)
        }
        event <- codex_to_event(method, params, session$session_id)
        if (!is.null(event)) {
            relay_emit(session, event, send, edit)
        }
        invisible(NULL)
    }
    on_approval <- function(method, params) {
        if (!is.null(capture)) {
            capture(method, params)
        }
        event <- codex_approval_to_event(method, params, .approval_id(),
            session$session_id)
        relay_emit(session, event, send, edit)
        "decline"
    }
    list(on_event = on_event, on_approval = on_approval, send = send,
         edit = edit)
}

# A card's chat kind: the agent events are m.notice, which renders without
# a notification ping; anything else is an ordinary message.
.content_kind <- function(content) {
    if (identical(content$msgtype, "m.notice")) {
        "notice"
    } else {
        "message"
    }
}

# The caller's own content keys for chat_send(): the card payload, with the
# keys chat.api writes itself (body, msgtype) dropped. NULL for none.
.card_keys <- function(content) {
    keys <- content[setdiff(names(content), c("body", "msgtype"))]
    if (length(keys)) {
        keys
    } else {
        NULL
    }
}

# A fresh approval id, unique enough to match an inbound answer against the
# pending request. The relay holds the request under this id.
.approval_id <- function() {
    paste0("ap-", as.integer(Sys.time()), "-", sample.int(1000000L, 1L))
}

#' Drive one Codex turn into a chat room
#'
#' Connects to the running Codex app server, opens a thread for \code{cwd},
#' sends \code{prompt} as one turn, and streams the turn's events into
#' \code{room_id} as cards. This is the capture entry: it drives the live
#' Codex daemon and records every event through \code{capture}, so the
#' Codex kinds R/codex_events.R does not map yet (tool, plan, reasoning)
#' can be read off a real session rather than guessed. The poll loop run()
#' uses is built on the same \code{\link{.codex_handlers}}.
#'
#' @param chat A chat.api client connected to the room.
#' @param room_id Character. The room the cards go to.
#' @param prompt Character. The user turn to send Codex.
#' @param cwd Character. The directory the Codex thread works in.
#' @param sandbox,approval_policy Passed to \code{codex_thread_start}; the
#'   default thread is read-only and acts without asking, which suits an
#'   unattended capture.
#' @param capture Function of \code{(method, params)}, or NULL.
#' @param timeout Seconds to wait for the turn to end.
#' @return The turn's final status, such as \code{"completed"}, or NULL
#'   when acp.api is not installed.
#' @export
drive_codex_once <- function(chat, room_id, prompt, cwd = getwd(),
                             sandbox = "read-only",
                             approval_policy = "never", capture = NULL,
                             timeout = 300) {
    if (!requireNamespace("acp.api", quietly = TRUE)) {
        message("cerebelo: acp.api is not installed; no Codex driver")
        return(NULL)
    }
    client <- acp.api::codex_connect()
    on.exit(acp.api::codex_close(client), add = TRUE)
    thread <- acp.api::codex_thread_start(client, cwd = cwd,
        sandbox = sandbox, approval_policy = approval_policy)
    registry <- session_registry()
    session <- bind_session(registry, room_id, session_id = thread,
                            provider = "codex")
    h <- .codex_handlers(chat, room_id, session, capture = capture)
    acp.api::codex_turn(client, thread, prompt, on_event = h$on_event,
                        on_approval = h$on_approval, timeout = timeout)
}

#' Record an agent's raw event stream to a file
#'
#' Returns a \code{capture} function for \code{\link{drive_codex_once}}: it
#' appends one JSON line per event to \code{path}. Use it on a live session
#' to collect the real Codex event vocabulary, both the kinds already
#' mapped and the ones still to map.
#'
#' @param path Character. The file to append each event to.
#' @return A function of \code{(method, params)}, called for its effect.
#' @export
capture_to_file <- function(path) {
    function(method, params) {
        line <- jsonlite::toJSON(list(method = method, params = params),
                                 auto_unbox = TRUE, null = "null",
                                 force = TRUE)
        cat(line, "\n", file = path, append = TRUE, sep = "")
        invisible(NULL)
    }
}
