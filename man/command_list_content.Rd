% tinyrox says don't edit this manually, but it can't stop you!
\name{command_list_content}
\alias{command_list_content}
\title{Build the MSC4332 command-list event content}
\usage{
command_list_content(commands = default_commands(), sigil = "/")
}
\arguments{
\item{commands}{A list of command entries, as \code{default_commands()}
returns.}

\item{sigil}{The command prefix; \code{"/"} by default.}
}
\value{
A named list, ready as the content for
  \code{\link[chat.api]{chat_set_state}}.
}
\description{
Formats a command list (see \code{\link{default_commands}}) as the content
of an \code{org.matrix.msc4332.commands} state event: a \code{sigil} and a
\code{commands} array whose entries carry \code{syntax}, an \code{m.text}
\code{description}, and optional typed \code{arguments}. Pure, so the shape
is testable without a transport.
}
\examples{
str(command_list_content())
}
