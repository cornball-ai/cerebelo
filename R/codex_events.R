# The Codex half of the agent-session event codec. The Codex app server
# (driven by acp.api's codex client) speaks a different event vocabulary than
# ACP; this maps what codex_listen delivers onto the shared agent_events()
# payloads. R/agent_events.R holds the payloads and the ACP mapping.
#
# Confirmed against a live session: the Codex app server reports work as items
# with a lifecycle, item/started -> item/<kind>/delta -> item/completed, each
# item carrying a type (userMessage, agentMessage, reasoning, and a command
# item when a tool runs). An agentMessage item is the agent's reply; its text
# is empty on started and whole on completed, and one turn can hold several (a
# commentary preamble, then the final answer), so each is driven off its own
# item/completed to become its own card rather than merged into one. A turn
# ends with turn/completed, and a .../requestApproval server request maps to an
# approval_request. Reasoning items and the command item stay unmapped until a
# capture confirms their payload shapes; the box's bwrap sandbox blocks command
# execution, so no command item has been seen yet. Codex nests the turn under
# "turn", which partial-matches "turnId"; read every field with [[ ]].

#' Map a Codex app-server event to an agent event
#'
#' Translates one notification from the Codex app server (as acp.api's
#' \code{codex_listen} hands it to \code{on_event}) into an
#' \code{\link{agent_events}} payload. Returns \code{NULL} for an event that
#' carries nothing to show, or one not yet mapped.
#'
#' @param method The event method, such as \code{"item/completed"}.
#' @param params The event parameters.
#' @param session_id The session the event belongs to.
#' @param turn_id The turn, when the caller tracks it; otherwise read from
#'   the event.
#'
#' @return An event payload, or \code{NULL}.
#'
#' @examples
#' p <- list(turnId = "u1",
#'           item = list(type = "agentMessage", id = "m1", text = "Hi."))
#' str(codex_to_event("item/completed", p, "s1"))
#'
#' @export
codex_to_event <- function(method, params, session_id, turn_id = NULL) {
    tid <- turn_id %||% params[["turnId"]] %||% params[["turn"]][["id"]]
    switch(method,
           `item/completed` = .codex_item_event(params[["item"]], session_id, tid),
           `turn/completed` = agent_turn_end(session_id, tid,
            .codex_stop_reason(params[["turn"]][["status"]])),
           NULL)
}

# A finished Codex item as an agent event, by its type. An agentMessage is the
# agent's reply, whole in item$text, with its id grouping the message; a turn's
# commentary and final answer arrive as separate agentMessage items and so
# become separate cards. A userMessage is the prompt echoed back and carries
# nothing new. Reasoning and command items stay unmapped until a live capture
# confirms their shapes.
.codex_item_event <- function(item, session_id, tid) {
    type <- item[["type"]]
    if (is.null(type) || !identical(type, "agentMessage")) {
        return(NULL)
    }
    text <- item[["text"]] %||% ""
    if (!nzchar(text)) {
        return(NULL)
    }
    agent_text(text, session_id, tid, message_id = item[["id"]], final = TRUE)
}

#' Map a Codex approval request to an approval event
#'
#' Translates a Codex \code{.../requestApproval} server request into an
#' \code{approval_request} payload. The option ids are the decisions Codex
#' expects back (\code{"accept"}, \code{"acceptForSession"},
#' \code{"decline"}), so the relay returns the chosen id straight to
#' \code{codex_listen}'s \code{on_approval}.
#'
#' @param method The request method, such as
#'   \code{"item/commandExecution/requestApproval"}.
#' @param params The request parameters; \code{command} names the action.
#' @param approval_id The id to tag this request with.
#' @param session_id,turn_id The session and turn the request belongs to.
#'
#' @return An \code{approval_request} event payload.
#'
#' @examples
#' p <- list(threadId = "t1", command = "ls")
#' str(codex_approval_to_event("item/commandExecution/requestApproval", p,
#'                             "a1", "s1"))
#'
#' @export
codex_approval_to_event <- function(method, params, approval_id, session_id,
                                    turn_id = NULL) {
    tid <- turn_id %||% params[["turnId"]]
    title <- params[["command"]] %||% params[["reason"]] %||% "this action"
    agent_approval_request(approval_id, session_id, tid, title = title,
                           options = .codex_approval_options(),
                           tool_call_id = params[["callId"]])
}

# A Codex turn status as an agent stop reason.
.codex_stop_reason <- function(status) {
    status <- status %||% "end_turn"
    switch(status, completed = "end_turn", interrupted = "cancelled", status)
}

# The decisions a Codex approval offers. Each id is what codex_listen's
# on_approval returns to the server.
.codex_approval_options <- function() {
    list(list(id = "accept", name = "Allow once", kind = "allow_once"),
         list(id = "acceptForSession", name = "Allow for session",
              kind = "allow_always"),
         list(id = "decline", name = "Decline", kind = "reject_once"))
}
