% tinyrox says don't edit this manually, but it can't stop you!
\name{session_state}
\alias{session_state}
\title{A session's mutable state}
\usage{
session_state(cwd = NULL, provider = NULL, model = NULL)
}
\arguments{
\item{cwd,provider,model}{Initial values, or NULL.}
}
\value{
An environment holding \code{cwd}, \code{provider}, \code{model}.
}
\description{
The slash handlers read and set a session's \code{cwd}, \code{provider},
and \code{model}. The event relay extends this record with the room,
thread, and agent-runner handle; the handlers here touch only those three
fields, in place, so the loop sees each change.
}
\examples{
s <- session_state(provider = "anthropic")
s$provider
}
