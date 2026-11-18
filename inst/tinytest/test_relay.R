library(tinytest)

# The registry binds a session to a room and looks it up; an unbound room is
# NULL. bind_session extends session_state with the relay's turn state.
reg <- cerebelo::session_registry()
s <- cerebelo::bind_session(reg, "!r:host", runner = "fake", session_id = "s1",
                            cwd = "/home/troy", provider = "codex",
                            model = "gpt")
expect_identical(cerebelo::session_for(reg, "!r:host"), s)
expect_null(cerebelo::session_for(reg, "!other:host"))
expect_equal(s$room, "!r:host")
expect_equal(s$session_id, "s1")
expect_equal(s$runner, "fake")
expect_equal(s$provider, "codex")
expect_equal(s$cwd, "/home/troy")
expect_null(s$turn)
expect_equal(s$buffer, "")
expect_true(is.environment(s$tool_events))
expect_true(is.environment(s$approvals))

# A re-bind replaces the room's session.
s2 <- cerebelo::bind_session(reg, "!r:host", provider = "claude")
expect_equal(cerebelo::session_for(reg, "!r:host")$provider, "claude")
expect_false(identical(s, s2))

# Inbound: the app's structured approval_response wins, option_id carried.
sess <- cerebelo::session_state()
msg <- list(body = "/approve a1",
            raw = list(content = list("ai.cornball.agent" = list(
                kind = "approval_response", approval_id = "a1",
                option_id = "acceptForSession"))))
r <- cerebelo::relay_inbound(sess, msg)
expect_equal(r$action, "approval")
expect_equal(r$approval_id, "a1")
expect_equal(r$option_id, "acceptForSession")
expect_null(r$decision)

# A typed /approve //deny carries a decision, no option_id.
ap <- cerebelo::relay_inbound(sess, list(body = "/approve a2"))
expect_equal(ap$action, "approval")
expect_equal(ap$approval_id, "a2")
expect_null(ap$option_id)
expect_equal(ap$decision, "approve")
dn <- cerebelo::relay_inbound(sess, list(body = "/deny a3"))
expect_equal(dn$decision, "deny")
expect_equal(dn$approval_id, "a3")

# /stop is its own action.
expect_equal(cerebelo::relay_inbound(sess, list(body = "/stop"))$action, "stop")

# Everything else falls to handle_command: a built-in, a passthrough, a prompt.
cd <- cerebelo::relay_inbound(sess, list(body = "/cd ~/proj"))
expect_equal(cd$action, "reply")
expect_equal(sess$cwd, "~/proj")
expect_equal(cerebelo::relay_inbound(sess, list(body = "/mcp list"))$action,
             "passthrough")
expect_equal(cerebelo::relay_inbound(sess, list(body = "fix the test"))$action,
             "prompt")

# A non-approval namespaced key does not hijack routing; the body decides.
msg2 <- list(body = "hello",
             raw = list(content = list("ai.cornball.agent" = list(
                 kind = "text", text = "hello"))))
expect_equal(cerebelo::relay_inbound(sess, msg2)$action, "prompt")

# relay_emit: capture sends and edits.
sent <- list()
edited <- list()
send <- function(content) {
    sent[[length(sent) + 1L]] <<- content
    paste0("$e", length(sent))
}
edit <- function(eid, content) {
    edited[[length(edited) + 1L]] <<- list(eid = eid, content = content)
    invisible()
}
reg2 <- cerebelo::session_registry()
es <- cerebelo::bind_session(reg2, "!r:host", session_id = "s1")

# Text buffers across chunks and flushes once at final.
cerebelo::relay_emit(es, cerebelo::agent_text("Hel", "s1", "t1"), send)
cerebelo::relay_emit(es, cerebelo::agent_text("lo.", "s1", "t1", final = TRUE),
                     send)
expect_equal(length(sent), 1L)
expect_equal(sent[[1]]$body, "Hello.")
expect_equal(sent[[1]][["ai.cornball.agent"]]$text, "Hello.")
expect_equal(es$buffer, "")

# thought is dropped.
cerebelo::relay_emit(es, cerebelo::agent_thought("hmm", "s1", "t1"), send)
expect_equal(length(sent), 1L)

# A non-text event flushes pending text first, then sends itself.
cerebelo::relay_emit(es, cerebelo::agent_text("tail", "s1", "t1"), send)
pl <- cerebelo::agent_plan(list(list(content = "a", status = "pending")),
                           "s1", "t1")
cerebelo::relay_emit(es, pl, send)
expect_equal(length(sent), 3L)
expect_equal(sent[[2]]$body, "tail")
expect_equal(sent[[3]][["ai.cornball.agent"]]$kind, "plan")

# A tool card sends once and records its event id; the update edits in place.
cerebelo::relay_emit(es, cerebelo::agent_tool("c1", "s1", "t1",
    title = "Run ls", status = "pending"), send, edit)
expect_equal(length(sent), 4L)
expect_equal(get("c1", envir = es$tool_events), "$e4")
cerebelo::relay_emit(es, cerebelo::agent_tool("c1", "s1", "t1",
    title = "Run ls", status = "completed"), send, edit)
expect_equal(length(sent), 4L)
expect_equal(length(edited), 1L)
expect_equal(edited[[1]]$eid, "$e4")
expect_equal(edited[[1]]$content[["ai.cornball.agent"]]$status, "completed")

# With no edit function, a tool update is a fresh send.
cerebelo::relay_emit(es, cerebelo::agent_tool("c1", "s1", "t1",
    status = "completed"), send)
expect_equal(length(sent), 5L)

# approval_request is sent and remembered; turn_end clears the turn.
ar <- cerebelo::agent_approval_request("ap1", "s1", "t1", title = "Run ls",
    options = list(list(id = "accept", name = "Allow", kind = "allow_once")))
cerebelo::relay_emit(es, ar, send)
expect_equal(get("ap1", envir = es$approvals)$kind, "approval_request")
cerebelo::relay_emit(es, cerebelo::agent_turn_end("s1", "t1", "end_turn"), send)
expect_null(es$turn)
