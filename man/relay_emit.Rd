% tinyrox says don't edit this manually, but it can't stop you!
\name{relay_emit}
\alias{relay_emit}
\title{Turn an agent event into a room operation}
\usage{
relay_emit(session, event, send, edit = NULL)
}
\arguments{
\item{session}{A session bound by \code{\link{bind_session}}.}

\item{event}{An event payload from an \code{\link{agent_events}}
constructor or the ACP / Codex mappers.}

\item{send}{A function \code{send(content)} that posts a message and
returns its event id. A capturing fake in tests; chat.api's send carrying
the namespaced content in the live relay.}

\item{edit}{A function \code{edit(event_id, content)} that replaces a prior
message, or NULL to post a tool update as a fresh message instead.}
}
\value{
Invisibly NULL; the session's buffer, tool map, approvals and turn
  are updated in place.
}
\description{
Applies one \code{\link{agent_events}} payload to a session: streamed text
is buffered and flushed at a boundary, a tool event is sent once and then
edited in place by \code{tool_call_id}, an approval is sent and remembered,
and the rest are sent as they arrive. \code{thought} is dropped (the draft
omits it unless a room opts in).
}
\examples{
reg <- session_registry()
s <- bind_session(reg, "!r:host", session_id = "s1")
relay_emit(s, agent_text("Hi.", "s1", "t1", final = TRUE),
           send = function(content) "$e1")
}
