# The Codex half of the agent-session event codec. The Codex app server
# (driven by acp.api's codex client) speaks a different event vocabulary than
# ACP; this maps what codex_listen delivers onto the shared agent_events()
# payloads. R/agent_events.R holds the payloads and the ACP mapping.
#
# Mapped so far, from the events acp.api's Codex client exercises:
# item/agentMessage/delta -> text, turn/completed -> turn_end, and a
# .../requestApproval server request -> approval_request. Reasoning, tool and
# plan items await their app-server v2 method names, confirmed against a live
# session before mapping rather than guessed. Codex nests the turn under
# "turn", which partial-matches "turnId"; read every field with [[ ]].

#' Map a Codex app-server event to an agent event
#'
#' Translates one notification from the Codex app server (as acp.api's
#' \code{codex_listen} hands it to \code{on_event}) into an
#' \code{\link{agent_events}} payload. Returns \code{NULL} for an event that
#' carries nothing to show, or one not yet mapped.
#'
#' @param method The event method, such as \code{"item/agentMessage/delta"}.
#' @param params The event parameters.
#' @param session_id The session the event belongs to.
#' @param turn_id The turn, when the caller tracks it; otherwise read from
#'   the event.
#'
#' @return An event payload, or \code{NULL}.
#'
#' @examples
#' p <- list(threadId = "t1", turnId = "u1", delta = "Hi.")
#' str(codex_to_event("item/agentMessage/delta", p, "s1"))
#'
#' @export
codex_to_event <- function(method, params, session_id, turn_id = NULL) {
    tid <- turn_id %||% params[["turnId"]] %||% params[["turn"]][["id"]]
    switch(method,
           `item/agentMessage/delta` = agent_text(params[["delta"]] %||% "",
            session_id, tid),
           `turn/completed` = agent_turn_end(session_id, tid,
            .codex_stop_reason(params[["turn"]][["status"]])),
           NULL)
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
