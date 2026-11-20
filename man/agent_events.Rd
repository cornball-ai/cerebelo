% tinyrox says don't edit this manually, but it can't stop you!
\name{agent_events}
\alias{agent_text}
\alias{agent_events}
\alias{agent_thought}
\alias{agent_tool}
\alias{agent_plan}
\alias{agent_approval_request}
\alias{agent_turn_end}
\alias{agent_session_info}
\alias{agent_error}
\title{Agent-session event payloads}
\usage{
agent_text(text, session_id, turn_id, message_id = NULL, final = FALSE)

agent_thought(text, session_id, turn_id, message_id = NULL)

agent_tool(
  tool_call_id,
  session_id,
  turn_id,
  title = NULL,
  tool_kind = NULL,
  status = NULL,
  input = NULL,
  output = NULL
)

agent_plan(entries, session_id, turn_id)

agent_approval_request(
  approval_id,
  session_id,
  turn_id,
  title,
  options,
  tool_call_id = NULL
)

agent_turn_end(session_id, turn_id, stop_reason, preview = NULL)

agent_session_info(
  session_id,
  agent = NULL,
  title = NULL,
  cwd = NULL,
  commands = NULL,
  config_options = NULL,
  turn_id = NULL
)

agent_error(message, session_id, turn_id = NULL)
}
\arguments{
\item{text}{Reply or reasoning text.}

\item{message_id}{Groups the chunks of one message, when known.}

\item{final}{\code{TRUE} on the last chunk of a message.}

\item{entries}{A plan: a list of \code{list(content, status)}.}

\item{message}{An error message.}

\item{session_id,turn_id}{The session and turn the event belongs to.}

\item{tool_call_id,title,tool_kind,status,input,output}{A tool call and
its progress; \code{status} is one of \code{"pending"},
\code{"in_progress"}, \code{"completed"} or \code{"failed"}.}

\item{approval_id,options}{An approval request and its choices, each
\code{list(id, name, kind)}.}

\item{stop_reason,preview}{How a turn ended, and up to 140 characters of
its reply.}

\item{agent,cwd,commands,config_options}{What a session offers: the
agent's name, its working directory, its command list, its options.}
}
\value{
A named list: the event payload.
}
\description{
Each function builds the \code{ai.cornball.agent} payload for one event
kind the relay sends into a room: the common fields (\code{v},
\code{kind}, \code{session_id}, \code{turn_id}) plus the kind's own.
Absent optional fields are dropped. Pass a payload to
\code{\link{agent_message}} for the message content to send.
}
\examples{
str(agent_text("Hello.", "s1", "t1", final = TRUE))
str(agent_turn_end("s1", "t1", "end_turn"))

}
