% tinyrox says don't edit this manually, but it can't stop you!
\name{handle_command}
\alias{handle_command}
\title{Handle an inbound message as a slash command}
\usage{
handle_command(session, body, sigil = "/")
}
\arguments{
\item{session}{A \code{\link{session_state}} the built-ins act on.}

\item{body}{The message text.}

\item{sigil}{The command prefix; \code{"/"} by default.}
}
\value{
A list with \code{action}, and \code{text} when it is
  \code{"reply"}.
}
\description{
Classifies a message and, for a built-in, acts on \code{session}. The
result's \code{action} is one of: \code{"reply"} (a built-in ran; send
\code{text}), \code{"passthrough"} (a \code{/command} the bot does not own;
forward it to the agent), or \code{"prompt"} (not a command; treat the body
as an ordinary prompt). The built-ins -- \code{cd}, \code{provider},
\code{model}, \code{rc} -- match \code{\link{default_commands}}.
}
\examples{
s <- session_state()
handle_command(s, "/cd ~/proj")
handle_command(s, "what's the plan?")
}
