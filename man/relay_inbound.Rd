% tinyrox says don't edit this manually, but it can't stop you!
\name{relay_inbound}
\alias{relay_inbound}
\title{Classify an inbound message for the relay}
\usage{
relay_inbound(session, message, sigil = "/")
}
\arguments{
\item{session}{A session bound by \code{\link{bind_session}}.}

\item{message}{A chat.api message: its \code{body}, and \code{raw$content}
for the namespaced key.}

\item{sigil}{The command prefix; \code{"/"} by default.}
}
\value{
A list with \code{action}: \code{"approval"} (with
  \code{approval_id}, and \code{option_id} or \code{decision}),
  \code{"stop"}, or one of \code{\link{handle_command}}'s results
  (\code{"reply"} / \code{"passthrough"} / \code{"prompt"}).
}
\description{
Routes a message arriving in a session room. Session controls come first:
an \code{approval_response} (the app's \code{ai.cornball.agent} key, or a
\code{/approve}//\code{/deny} typed in a stock client) and \code{/stop}.
Anything else falls to \code{\link{handle_command}}: a built-in acts on the
session, a \code{/command} the bot does not own passes through to the
agent, and plain text is an ordinary prompt.
}
\details{
The approval result carries the \code{approval_id} and either an explicit
\code{option_id} (when the app named one) or a \code{decision} of
\code{"approve"} / \code{"deny"} (from a typed command); the resolver that
holds the pending request maps a decision to one of its options.

}
\examples{
s <- session_state()
relay_inbound(s, list(body = "/approve a1"))
relay_inbound(s, list(body = "fix the test"))
}
