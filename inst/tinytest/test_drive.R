library(tinytest)

# The agent drive loop's bridge: the handlers acp.api's Codex client drives
# a turn with, exercised against the loopback transport with synthetic
# events. No live Codex: this proves the event-to-card mapping and the room
# sends. Driving the real daemon is drive_codex_once(), tested by hand.

if (!requireNamespace("chat.api", quietly = TRUE)) {
    exit_file("chat.api not installed")
}

# ---- Each agentMessage item becomes its own card ----
# A Codex turn can hold a commentary preamble and a final answer as two
# agentMessage items; codex_to_event drives each off its own item/completed,
# so they render as two cards, not one merged blob. The user's own prompt,
# echoed back as a userMessage item, carries nothing new.
local({
    lo <- chat.api::chat_loopback()
    reg <- cerebelo::session_registry()
    s <- cerebelo::bind_session(reg, "room", session_id = "t1",
                                provider = "codex")
    h <- cerebelo:::.codex_handlers(lo, "room", s)

    h$on_event("item/completed", list(turnId = "u1",
        item = list(type = "userMessage", id = "u", text = "hi")))
    expect_equal(length(chat.api::chat_poll(lo)$messages), 0L)

    h$on_event("item/completed", list(turnId = "u1",
        item = list(type = "agentMessage", id = "m1", text = "One moment.")))
    h$on_event("item/completed", list(turnId = "u1",
        item = list(type = "agentMessage", id = "m2", text = "All done.")))
    h$on_event("turn/completed",
               list(turnId = "u1", turn = list(status = "completed")))

    cards <- lapply(chat.api::chat_poll(lo)$messages,
                    function(m) m$raw$content[["ai.cornball.agent"]])
    texts <- Filter(function(c) identical(c$kind, "text"), cards)
    expect_equal(length(texts), 2L)
    expect_identical(texts[[1L]]$text, "One moment.")
    expect_identical(texts[[2L]]$text, "All done.")
    expect_identical(texts[[1L]]$session_id, "t1")
    end <- Filter(function(c) identical(c$kind, "turn_end"), cards)
    expect_equal(length(end), 1L)
})

# ---- An unmapped kind sends nothing but is captured ----
# codex_to_event() returns NULL for a kind it does not map yet (reasoning,
# tool, plan await their live method names), so nothing reaches the room,
# but the capture still records it for mapping.
local({
    lo <- chat.api::chat_loopback()
    reg <- cerebelo::session_registry()
    s <- cerebelo::bind_session(reg, "room", session_id = "t1",
                                provider = "codex")
    seen <- character()
    cap <- function(method, params) seen[[length(seen) + 1L]] <<- method
    h <- cerebelo:::.codex_handlers(lo, "room", s, capture = cap)

    h$on_event("item/reasoning/delta", list(turnId = "u1", delta = "hmm"))
    expect_equal(length(chat.api::chat_poll(lo)$messages), 0L)
    expect_true("item/reasoning/delta" %in% seen)
})

# ---- An approval posts a card and declines for now ----
local({
    lo <- chat.api::chat_loopback()
    reg <- cerebelo::session_registry()
    s <- cerebelo::bind_session(reg, "room", session_id = "t1",
                                provider = "codex")
    h <- cerebelo:::.codex_handlers(lo, "room", s)

    decision <- h$on_approval("item/commandExecution/requestApproval",
                              list(turnId = "u1", command = "ls -a"))
    expect_identical(decision, "decline")
    msg <- chat.api::chat_poll(lo)$messages[[1L]]
    ev <- msg$raw$content[["ai.cornball.agent"]]
    expect_identical(ev$kind, "approval_request")
    expect_true(grepl("ls -a", msg$body, fixed = TRUE))
    # The three decisions Codex offers, mapped to the card's option kinds.
    kinds <- vapply(ev$options, function(o) o$kind, character(1L))
    expect_identical(kinds, c("allow_once", "allow_always", "reject_once"))
})

# ---- The capture logger writes one JSON line per event ----
local({
    f <- tempfile(fileext = ".jsonl")
    cap <- cerebelo::capture_to_file(f)
    cap("turn/started", list(turnId = "u1"))
    cap("item/agentMessage/delta", list(turnId = "u1", delta = "hi"))
    lines <- readLines(f)
    expect_equal(length(lines), 2L)
    expect_true(grepl("turn/started", lines[[1L]], fixed = TRUE))
    expect_true(grepl("\"delta\":\"hi\"", lines[[2L]], fixed = TRUE))
})
