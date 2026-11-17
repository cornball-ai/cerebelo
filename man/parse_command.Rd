% tinyrox says don't edit this manually, but it can't stop you!
\name{parse_command}
\alias{parse_command}
\title{Parse an inbound slash command}
\usage{
parse_command(body, sigil = "/")
}
\arguments{
\item{body}{The message text.}

\item{sigil}{The command prefix; \code{"/"} by default.}
}
\value{
\code{list(name, arg)}, or NULL when \code{body} is not a command.
}
\description{
Splits a message body into a command name and its argument. The name is the
first word after \code{sigil}; the argument is the rest of the line,
trimmed and kept whole, so a path with spaces survives. A body that does
not start with \code{sigil}, or carries only the sigil, is not a command.
}
\examples{
parse_command("/cd ~/proj")
parse_command("hello")
}
