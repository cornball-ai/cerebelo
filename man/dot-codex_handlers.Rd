% tinyrox says don't edit this manually, but it can't stop you!
\name{.codex_handlers}
\alias{.codex_handlers}
\title{Render a running agent turn into a chat room}
\usage{
.codex_handlers(chat, room_id, session, capture = NULL)
}
\arguments{
\item{chat}{A chat.api client.}

\item{room_id}{Character. The room the cards go to.}

\item{session}{A relay session bound by \code{\link{bind_session}}; its
\code{session_id} tags the cards.}

\item{capture}{Function of \code{(method, params)}, or NULL.}
}
\value{
A list with \code{on_event}, \code{on_approval}, \code{send} and
  \code{edit}: the first two for \code{codex_turn}, the last two the
  room operations \code{\link{relay_emit}} drives.
}
\description{
Builds the pair of callbacks acp.api's Codex client drives a turn with.
\code{on_event} maps each Codex event to an \code{\link{agent_events}}
card and sends it; \code{on_approval} posts the approval card and, for
now, declines. Every raw event passes to \code{capture} first, so the
stream can be recorded while the Codex mapping (R/codex_events.R) is
still being filled in.
}
\keyword{internal}
