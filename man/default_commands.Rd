% tinyrox says don't edit this manually, but it can't stop you!
\name{default_commands}
\alias{default_commands}
\title{A bot's built-in session commands}
\usage{
default_commands()
}
\value{
A list of command entries.
}
\description{
The slash commands every agent-session bot answers, in the shape
\code{\link{command_list_content}} and \code{\link{publish_commands}}
expect: a list of entries, each with a \code{syntax} string whose first
word is the command name, a plain-text \code{description}, and an
\code{arguments} list of \code{list(type, description)} (empty when the
command takes none).
}
\details{
\code{cd} sets the session's working directory, \code{provider} and
\code{model} switch the agent, and \code{rc} mirrors a live terminal
session into the room. A persona appends its own entries in config and
passes the combined list to \code{publish_commands()}.

}
\examples{
str(default_commands())
}
