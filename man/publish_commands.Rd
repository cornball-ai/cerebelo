% tinyrox says don't edit this manually, but it can't stop you!
\name{publish_commands}
\alias{publish_commands}
\title{Publish a bot's command list to a room}
\usage{
publish_commands(
  client,
  room_id,
  commands = default_commands(),
  self_id = NULL,
  sigil = "/"
)
}
\arguments{
\item{client}{A chat.api client with state-event support
(\code{chat_capabilities(client)$set_state}).}

\item{room_id}{The room to publish into.}

\item{commands}{The command list; \code{default_commands()} by default.}

\item{self_id}{The bot's user id for the state key; read from the client
with \code{\link[chat.api]{chat_whoami}} when NULL.}

\item{sigil}{The command prefix; \code{"/"} by default.}
}
\value{
Invisibly, the result of the state write.
}
\description{
Writes the bot's slash-command list as an \code{org.matrix.msc4332.commands}
state event in \code{room_id}, keyed by the bot's own user id, so a client
can offer autocomplete. Call it when the list changes: on joining a session
room, and after a command alters it (for example a provider switch that
brings different agent commands). The write goes through chat.api's
state-event support, so it is not tied to one homeserver.
}
\examples{
\dontrun{
publish_commands(client, "!session:cornball.ai")
}
}
