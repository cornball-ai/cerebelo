library(tinytest)

# Constructors build the ai.cornball.agent payload: common fields plus the
# kind's own, with absent optionals dropped.
e <- cerebelo::agent_text("Hello.", "s1", "t1", final = TRUE)
expect_equal(e$v, 1L)
expect_equal(e$kind, "text")
expect_equal(e$session_id, "s1")
expect_equal(e$turn_id, "t1")
expect_equal(e$text, "Hello.")
expect_true(e$final)
expect_null(e$message_id)

tool <- cerebelo::agent_tool("c1", "s1", "t1", title = "Run ls",
                             tool_kind = "execute", status = "pending")
expect_equal(tool$kind, "tool")
expect_equal(tool$tool_call_id, "c1")
expect_equal(tool$status, "pending")
expect_null(tool$output)

si <- cerebelo::agent_session_info("s1", agent = "claude", cwd = "/home/troy")
expect_equal(si$kind, "session_info")
expect_equal(si$cwd, "/home/troy")
expect_null(si$turn_id)

# agent_message wraps a payload as an m.notice with the fallback body and the
# namespaced key.
m <- cerebelo::agent_message(cerebelo::agent_text("Hi.", "s1", "t1"))
expect_equal(m$msgtype, "m.notice")
expect_equal(m$body, "Hi.")
expect_equal(m[["ai.cornball.agent"]]$kind, "text")

# Fallback body per kind.
expect_equal(cerebelo::agent_message(
    cerebelo::agent_tool("c1", "s1", "t1", title = "Run ls",
                         status = "completed"))$body,
    "[tool] Run ls (completed)")
ar <- cerebelo::agent_approval_request("a1", "s1", "t1", title = "Run ls",
    options = list(list(id = "yes", name = "Allow", kind = "allow_once")))
expect_equal(cerebelo::agent_message(ar)$body,
             "Approve Run ls? Reply /approve a1 or /deny a1")
plan <- cerebelo::agent_plan(
    list(list(content = "step one", status = "pending"),
         list(content = "step two", status = "done")), "s1", "t1")
expect_equal(cerebelo::agent_message(plan)$body,
             "- [pending] step one\n- [done] step two")
# thought and turn_end carry an empty fallback; the app reads the key.
expect_equal(cerebelo::agent_message(
    cerebelo::agent_thought("hmm", "s1", "t1"))$body, "")
expect_equal(cerebelo::agent_message(
    cerebelo::agent_turn_end("s1", "t1", "end_turn"))$body, "")

# ACP adapter: each update kind maps to its event; an unknown kind is NULL.
txt <- cerebelo::acp_to_event(
    list(sessionUpdate = "agent_message_chunk",
         content = list(type = "text", text = "Hi.")), "s1", "t1")
expect_equal(txt$kind, "text")
expect_equal(txt$text, "Hi.")
tht <- cerebelo::acp_to_event(
    list(sessionUpdate = "agent_thought_chunk",
         content = list(type = "text", text = "thinking")), "s1", "t1")
expect_equal(tht$kind, "thought")
tl <- cerebelo::acp_to_event(
    list(sessionUpdate = "tool_call", toolCallId = "c1", title = "Run ls",
         kind = "execute", status = "in_progress"), "s1", "t1")
expect_equal(tl$kind, "tool")
expect_equal(tl$tool_call_id, "c1")
expect_equal(tl$tool_kind, "execute")
expect_equal(tl$status, "in_progress")
pl <- cerebelo::acp_to_event(
    list(sessionUpdate = "plan",
         entries = list(list(content = "a", status = "pending"))), "s1", "t1")
expect_equal(pl$kind, "plan")
expect_equal(pl$entries[[1]]$content, "a")
expect_null(cerebelo::acp_to_event(list(sessionUpdate = "whatever"),
                                   "s1", "t1"))
expect_null(cerebelo::acp_to_event(list(), "s1", "t1"))

# Tool input is stringified and truncated.
ti <- cerebelo::acp_to_event(
    list(sessionUpdate = "tool_call", toolCallId = "c1",
         rawInput = list(cmd = "ls", path = strrep("x", 400))), "s1", "t1")
expect_true(nchar(ti$input) <= 253L)
expect_true(endsWith(ti$input, "..."))

# An ACP permission request maps to an approval_request with mapped options.
p <- list(toolCall = list(toolCallId = "c1", title = "Run ls"),
          options = list(list(optionId = "yes", name = "Allow",
                              kind = "allow_once"),
                         list(optionId = "no", name = "Deny",
                              kind = "reject_once")))
apr <- cerebelo::acp_permission_to_event(p, "a1", "s1", "t1")
expect_equal(apr$kind, "approval_request")
expect_equal(apr$approval_id, "a1")
expect_equal(apr$tool_call_id, "c1")
expect_equal(length(apr$options), 2L)
expect_equal(apr$options[[1]]$id, "yes")
expect_equal(apr$options[[1]]$kind, "allow_once")
