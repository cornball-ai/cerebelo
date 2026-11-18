% tinyrox says don't edit this manually, but it can't stop you!
\name{codex_approval_to_event}
\alias{codex_approval_to_event}
\title{Map a Codex approval request to an approval event}
\usage{
codex_approval_to_event(
  method,
  params,
  approval_id,
  session_id,
  turn_id = NULL
)
}
\arguments{
\item{method}{The request method, such as
\code{"item/commandExecution/requestApproval"}.}

\item{params}{The request parameters; \code{command} names the action.}

\item{approval_id}{The id to tag this request with.}

\item{session_id,turn_id}{The session and turn the request belongs to.}
}
\value{
An \code{approval_request} event payload.
}
\description{
Translates a Codex \code{.../requestApproval} server request into an
\code{approval_request} payload. The option ids are the decisions Codex
expects back (\code{"accept"}, \code{"acceptForSession"},
\code{"decline"}), so the relay returns the chosen id straight to
\code{codex_listen}'s \code{on_approval}.
}
\examples{
p <- list(threadId = "t1", command = "ls")
str(codex_approval_to_event("item/commandExecution/requestApproval", p,
                            "a1", "s1"))

}
