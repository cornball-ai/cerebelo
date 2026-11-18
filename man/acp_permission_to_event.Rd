% tinyrox says don't edit this manually, but it can't stop you!
\name{acp_permission_to_event}
\alias{acp_permission_to_event}
\title{Map an ACP permission request to an approval event}
\usage{
acp_permission_to_event(params, approval_id, session_id, turn_id)
}
\arguments{
\item{params}{The request parameters: \code{toolCall} and \code{options}.}

\item{approval_id}{The id to tag this request with.}

\item{session_id,turn_id}{The session and turn the request belongs to.}
}
\value{
An \code{approval_request} event payload.
}
\description{
Translates the parameters of a \code{session/request_permission} (as
acp.api's \code{on_permission} hands them over) into an
\code{approval_request} payload. The caller supplies \code{approval_id}:
the id it will match an inbound \code{/approve} or \code{/deny} against.
}
\examples{
p <- list(toolCall = list(toolCallId = "c1", title = "Run ls"),
          options = list(list(optionId = "yes", name = "Allow",
                              kind = "allow_once")))
str(acp_permission_to_event(p, "a1", "s1", "t1"))

}
