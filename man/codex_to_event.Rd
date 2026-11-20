% tinyrox says don't edit this manually, but it can't stop you!
\name{codex_to_event}
\alias{codex_to_event}
\title{Map a Codex app-server event to an agent event}
\usage{
codex_to_event(method, params, session_id, turn_id = NULL)
}
\arguments{
\item{method}{The event method, such as \code{"item/completed"}.}

\item{params}{The event parameters.}

\item{session_id}{The session the event belongs to.}

\item{turn_id}{The turn, when the caller tracks it; otherwise read from
the event.}
}
\value{
An event payload, or \code{NULL}.
}
\description{
Translates one notification from the Codex app server (as acp.api's
\code{codex_listen} hands it to \code{on_event}) into an
\code{\link{agent_events}} payload. Returns \code{NULL} for an event that
carries nothing to show, or one not yet mapped.
}
\examples{
p <- list(turnId = "u1",
          item = list(type = "agentMessage", id = "m1", text = "Hi."))
str(codex_to_event("item/completed", p, "s1"))

}
