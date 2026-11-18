% tinyrox says don't edit this manually, but it can't stop you!
\name{session_registry}
\alias{session_registry}
\alias{bind_session}
\alias{session_for}
\title{A registry of per-room agent sessions}
\usage{
session_registry()

bind_session(
  registry,
  room_id,
  runner = NULL,
  session_id = NULL,
  cwd = NULL,
  provider = NULL,
  model = NULL
)

session_for(registry, room_id)
}
\arguments{
\item{registry}{A \code{session_registry}.}

\item{room_id}{The room the session serves.}

\item{runner}{The agent-runner handle, or NULL until one is attached.}

\item{session_id}{The agent session id the events carry, or NULL until the
runner assigns one.}

\item{cwd,provider,model}{Initial session fields, passed to
\code{\link{session_state}}.}
}
\value{
An environment, the empty registry.
}
\description{
A session is bound to the room it serves. The registry maps a room id to
its bound session; \code{\link{session_for}} looks one up and
\code{\link{bind_session}} adds one.
}
\details{
\code{bind_session} extends a \code{\link{session_state}} with the
  room it serves, the agent runner that drives it, and the live turn state
  the relay keeps: the current turn id, a text buffer flushed at
  boundaries, the tool-call-id to event-id map for in-place card edits, and
  the pending approvals.
}
\examples{
reg <- session_registry()
bind_session(reg, "!room:host", provider = "codex")
session_for(reg, "!room:host")$provider
}
