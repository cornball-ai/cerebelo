% tinyrox says don't edit this manually, but it can't stop you!
\name{drive_codex_once}
\alias{drive_codex_once}
\title{Drive one Codex turn into a chat room}
\usage{
drive_codex_once(
  chat,
  room_id,
  prompt,
  cwd = getwd(),
  sandbox = "read-only",
  approval_policy = "never",
  capture = NULL,
  timeout = 300
)
}
\arguments{
\item{chat}{A chat.api client connected to the room.}

\item{room_id}{Character. The room the cards go to.}

\item{prompt}{Character. The user turn to send Codex.}

\item{cwd}{Character. The directory the Codex thread works in.}

\item{capture}{Function of \code{(method, params)}, or NULL.}

\item{timeout}{Seconds to wait for the turn to end.}

\item{sandbox,approval_policy}{Passed to \code{codex_thread_start}; the
default thread is read-only and acts without asking, which suits an
unattended capture.}
}
\value{
The turn's final status, such as \code{"completed"}, or NULL
  when acp.api is not installed.
}
\description{
Connects to the running Codex app server, opens a thread for \code{cwd},
sends \code{prompt} as one turn, and streams the turn's events into
\code{room_id} as cards. This is the capture entry: it drives the live
Codex daemon and records every event through \code{capture}, so the
Codex kinds R/codex_events.R does not map yet (tool, plan, reasoning)
can be read off a real session rather than guessed. The poll loop run()
uses is built on the same \code{\link{.codex_handlers}}.
}
