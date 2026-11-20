% tinyrox says don't edit this manually, but it can't stop you!
\name{capture_to_file}
\alias{capture_to_file}
\title{Record an agent's raw event stream to a file}
\usage{
capture_to_file(path)
}
\arguments{
\item{path}{Character. The file to append each event to.}
}
\value{
A function of \code{(method, params)}, called for its effect.
}
\description{
Returns a \code{capture} function for \code{\link{drive_codex_once}}: it
appends one JSON line per event to \code{path}. Use it on a live session
to collect the real Codex event vocabulary, both the kinds already
mapped and the ones still to map.
}
