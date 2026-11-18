% tinyrox says don't edit this manually, but it can't stop you!
\name{agent_message}
\alias{agent_message}
\title{Wrap an agent event as a room message}
\usage{
agent_message(event)
}
\arguments{
\item{event}{A payload from one of the \code{\link{agent_events}}
constructors.}
}
\value{
A named list: the message content.
}
\description{
Builds the content of the \code{m.room.message} that carries an event: an
\code{m.notice} with a plain-text \code{body} a stock client shows, plus
the \code{ai.cornball.agent} payload the cerebro app reads. Send it with
the chat.api message helpers.
}
\examples{
str(agent_message(agent_text("Hello.", "s1", "t1")))

}
