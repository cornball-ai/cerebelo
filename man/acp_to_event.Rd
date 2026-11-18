% tinyrox says don't edit this manually, but it can't stop you!
\name{acp_to_event}
\alias{acp_to_event}
\title{Map an ACP session update to an agent event}
\usage{
acp_to_event(update, session_id, turn_id)
}
\arguments{
\item{update}{The \code{update} member of a \code{session/update}; its
\code{sessionUpdate} field names the kind.}

\item{session_id,turn_id}{The session and turn the update belongs to.}
}
\value{
An event payload, or \code{NULL}.
}
\description{
Translates one Agent Client Protocol \code{session/update} (as acp.api's
\code{acp_poll} delivers it) into an \code{\link{agent_events}} payload.
Returns \code{NULL} for an update kind that carries nothing to show.
}
\examples{
u <- list(sessionUpdate = "agent_message_chunk",
          content = list(type = "text", text = "Hi."))
str(acp_to_event(u, "s1", "t1"))

}
