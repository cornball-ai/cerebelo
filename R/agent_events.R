# The agent-session event codec. An agent running in a Matrix room speaks
# through `ai.cornball.agent` events: each is an m.notice with a plain-text
# fallback plus one namespaced payload the cerebro app reads. This file
# builds those payloads, wraps them into message content, and maps an ACP
# agent's updates onto them. The Codex and corteza mappings join it beside.
# The contract is ~/tasks/dev/agent-session-events-draft.md.

# The message key an agent event travels under, and the payload version.
.AGENT_EVENT_KEY <- "ai.cornball.agent"
.AGENT_EVENT_VERSION <- 1L

# Build a payload: the common fields, then the kind's own, dropping absent
# ones so the event stays small.
.agent_event <- function(kind, session_id, turn_id = NULL, ...) {
    event <- list(v = .AGENT_EVENT_VERSION, kind = kind,
                  session_id = session_id)
    if (!is.null(turn_id)) {
        event$turn_id <- turn_id
    }
    extra <- list(...)
    extra <- extra[!vapply(extra, is.null, logical(1))]
    c(event, extra)
}

#' Agent-session event payloads
#'
#' Each function builds the \code{ai.cornball.agent} payload for one event
#' kind the relay sends into a room: the common fields (\code{v},
#' \code{kind}, \code{session_id}, \code{turn_id}) plus the kind's own.
#' Absent optional fields are dropped. Pass a payload to
#' \code{\link{agent_message}} for the message content to send.
#'
#' @param session_id,turn_id The session and turn the event belongs to.
#' @param text Reply or reasoning text.
#' @param message_id Groups the chunks of one message, when known.
#' @param final \code{TRUE} on the last chunk of a message.
#' @param tool_call_id,title,tool_kind,status,input,output A tool call and
#'   its progress; \code{status} is one of \code{"pending"},
#'   \code{"in_progress"}, \code{"completed"} or \code{"failed"}.
#' @param entries A plan: a list of \code{list(content, status)}.
#' @param approval_id,options An approval request and its choices, each
#'   \code{list(id, name, kind)}.
#' @param stop_reason,preview How a turn ended, and up to 140 characters of
#'   its reply.
#' @param agent,cwd,commands,config_options What a session offers: the
#'   agent's name, its working directory, its command list, its options.
#' @param message An error message.
#'
#' @return A named list: the event payload.
#'
#' @examples
#' str(agent_text("Hello.", "s1", "t1", final = TRUE))
#' str(agent_turn_end("s1", "t1", "end_turn"))
#'
#' @name agent_events
#' @export
agent_text <- function(text, session_id, turn_id, message_id = NULL,
                       final = FALSE) {
    .agent_event("text", session_id, turn_id, text = text,
                 message_id = message_id, final = final)
}

#' @rdname agent_events
#' @export
agent_thought <- function(text, session_id, turn_id, message_id = NULL) {
    .agent_event("thought", session_id, turn_id, text = text,
                 message_id = message_id)
}

#' @rdname agent_events
#' @export
agent_tool <- function(tool_call_id, session_id, turn_id, title = NULL,
                       tool_kind = NULL, status = NULL, input = NULL,
                       output = NULL) {
    .agent_event("tool", session_id, turn_id, tool_call_id = tool_call_id,
                 title = title, tool_kind = tool_kind, status = status,
                 input = input, output = output)
}

#' @rdname agent_events
#' @export
agent_plan <- function(entries, session_id, turn_id) {
    .agent_event("plan", session_id, turn_id, entries = entries)
}

#' @rdname agent_events
#' @export
agent_approval_request <- function(approval_id, session_id, turn_id, title,
                                   options, tool_call_id = NULL) {
    .agent_event("approval_request", session_id, turn_id,
                 approval_id = approval_id, tool_call_id = tool_call_id,
                 title = title, options = options)
}

#' @rdname agent_events
#' @export
agent_turn_end <- function(session_id, turn_id, stop_reason, preview = NULL) {
    .agent_event("turn_end", session_id, turn_id, stop_reason = stop_reason,
                 preview = preview)
}

#' @rdname agent_events
#' @export
agent_session_info <- function(session_id, agent = NULL, title = NULL,
                               cwd = NULL, commands = NULL,
                               config_options = NULL, turn_id = NULL) {
    .agent_event("session_info", session_id, turn_id, agent = agent,
                 title = title, cwd = cwd, commands = commands,
                 config_options = config_options)
}

#' @rdname agent_events
#' @export
agent_error <- function(message, session_id, turn_id = NULL) {
    .agent_event("error", session_id, turn_id, message = message)
}

# The plain-text fallback a stock Matrix client shows for an event. Kinds the
# app reads only through the payload fall back to "".
.agent_fallback <- function(event) {
    switch(event$kind,
           text = event$text %||% "",
           thought = event$text %||% "",
           tool = sprintf("[tool] %s (%s)",
                          event$title %||% event$tool_kind %||% "tool",
                          event$status %||% "pending"),
           plan = .plan_text(event$entries),
           approval_request = sprintf(
                                      "Approve %s? Reply /approve %s or /deny %s",
                                      event$title %||% "this", event$approval_id, event$approval_id),
           turn_end = .turn_end_text(event),
           session_info = .session_info_text(event),
           error = event$message %||% "",
           "")
}

# A turn's closing line: its short reply preview when one was kept, else a word
# for how it ended, so the chat-list preview and a stock client are not blank.
.turn_end_text <- function(event) {
    preview <- event$preview %||% ""
    if (nzchar(preview)) {
        return(preview)
    }
    switch(event$stop_reason %||% "end_turn", end_turn = "Done",
           cancelled = "Stopped", sprintf("Stopped (%s)", event$stop_reason))
}

# A session header line: the agent and, when known, its working directory.
.session_info_text <- function(event) {
    name <- event$title %||% event$agent %||% "agent"
    if (!is.null(event$cwd) && nzchar(event$cwd)) {
        sprintf("%s in %s", name, event$cwd)
    } else {
        name
    }
}

.plan_text <- function(entries) {
    if (!length(entries)) {
        return("")
    }
    lines <- vapply(entries, function(e) {
        sprintf("- [%s] %s", e$status %||% "", e$content %||% "")
    }, character(1))
    paste(lines, collapse = "\n")
}

#' Wrap an agent event as a room message
#'
#' Builds the content of the \code{m.room.message} that carries an event: an
#' \code{m.notice} with a plain-text \code{body} a stock client shows, plus
#' the \code{ai.cornball.agent} payload the cerebro app reads. Send it with
#' the chat.api message helpers.
#'
#' @param event A payload from one of the \code{\link{agent_events}}
#'   constructors.
#'
#' @return A named list: the message content.
#'
#' @examples
#' str(agent_message(agent_text("Hello.", "s1", "t1")))
#'
#' @export
agent_message <- function(event) {
    content <- list(msgtype = "m.notice", body = .agent_fallback(event))
    content[[.AGENT_EVENT_KEY]] <- event
    content
}

#' Map an ACP session update to an agent event
#'
#' Translates one Agent Client Protocol \code{session/update} (as acp.api's
#' \code{acp_poll} delivers it) into an \code{\link{agent_events}} payload.
#' Returns \code{NULL} for an update kind that carries nothing to show.
#'
#' @param update The \code{update} member of a \code{session/update}; its
#'   \code{sessionUpdate} field names the kind.
#' @param session_id,turn_id The session and turn the update belongs to.
#'
#' @return An event payload, or \code{NULL}.
#'
#' @examples
#' u <- list(sessionUpdate = "agent_message_chunk",
#'           content = list(type = "text", text = "Hi."))
#' str(acp_to_event(u, "s1", "t1"))
#'
#' @export
acp_to_event <- function(update, session_id, turn_id) {
    kind <- update$sessionUpdate
    if (is.null(kind)) {
        return(NULL)
    }
    switch(kind,
           agent_message_chunk = agent_text(.content_text(update$content),
            session_id, turn_id),
           agent_thought_chunk = agent_thought(.content_text(update$content),
            session_id, turn_id),
           tool_call = .acp_tool(update, session_id, turn_id),
           tool_call_update = .acp_tool(update, session_id, turn_id),
           plan = agent_plan(.acp_plan(update$entries), session_id, turn_id),
           NULL)
}

#' Map an ACP permission request to an approval event
#'
#' Translates the parameters of a \code{session/request_permission} (as
#' acp.api's \code{on_permission} hands them over) into an
#' \code{approval_request} payload. The caller supplies \code{approval_id}:
#' the id it will match an inbound \code{/approve} or \code{/deny} against.
#'
#' @param params The request parameters: \code{toolCall} and \code{options}.
#' @param approval_id The id to tag this request with.
#' @param session_id,turn_id The session and turn the request belongs to.
#'
#' @return An \code{approval_request} event payload.
#'
#' @examples
#' p <- list(toolCall = list(toolCallId = "c1", title = "Run ls"),
#'           options = list(list(optionId = "yes", name = "Allow",
#'                               kind = "allow_once")))
#' str(acp_permission_to_event(p, "a1", "s1", "t1"))
#'
#' @export
acp_permission_to_event <- function(params, approval_id, session_id, turn_id) {
    options <- lapply(params$options, function(o) {
        list(id = o$optionId, name = o$name %||% "", kind = o$kind %||% "")
    })
    agent_approval_request(approval_id, session_id, turn_id,
                           title = params$toolCall$title %||% "",
                           options = options,
                           tool_call_id = params$toolCall$toolCallId)
}

# Text from an ACP content block, or a list of blocks.
.content_text <- function(content) {
    if (is.null(content)) {
        return("")
    }
    if (!is.null(content$text)) {
        return(content$text)
    }
    texts <- vapply(content, function(b) b$text %||% "", character(1))
    paste(texts, collapse = "")
}

# An ACP tool_call or tool_call_update as a tool event. Input and output are
# kept short, per the event-size rules.
.acp_tool <- function(update, session_id, turn_id) {
    agent_tool(update$toolCallId, session_id, turn_id, title = update$title,
               tool_kind = update$kind, status = update$status,
               input = .acp_tool_input(update),
               output = .acp_tool_output(update$content))
}

.acp_tool_input <- function(update) {
    raw <- update$rawInput %||% update$input
    if (is.null(raw)) {
        return(NULL)
    }
    text <- if (is.character(raw)) {
        paste(raw, collapse = " ")
    } else {
        as.character(jsonlite::toJSON(raw, auto_unbox = TRUE))
    }
    .truncate(text, 250L)
}

.acp_tool_output <- function(content) {
    text <- .content_text(content)
    if (!nzchar(text)) {
        return(NULL)
    }
    .truncate(text, 4000L)
}

.acp_plan <- function(entries) {
    lapply(entries, function(e) {
        list(content = e$content %||% "", status = e$status %||% "")
    })
}

.truncate <- function(text, n) {
    if (is.null(text) || nchar(text) <= n) {
        return(text)
    }
    paste0(substr(text, 1L, n), "...")
}
