library(tinytest)

# item/agentMessage/delta -> text; turnId read without partial-matching turn.
txt <- cerebelo::codex_to_event("item/agentMessage/delta",
    list(threadId = "t1", turnId = "u1", delta = "Hi."), "s1")
expect_equal(txt$kind, "text")
expect_equal(txt$text, "Hi.")
expect_equal(txt$turn_id, "u1")

# turn/completed -> turn_end; the id and status come from the nested turn.
done <- cerebelo::codex_to_event("turn/completed",
    list(threadId = "t1", turn = list(id = "u1", status = "completed")), "s1")
expect_equal(done$kind, "turn_end")
expect_equal(done$stop_reason, "end_turn")
expect_equal(done$turn_id, "u1")

# Status maps to a stop reason, with an unknown one passed through.
expect_equal(cerebelo::codex_to_event("turn/completed",
    list(turn = list(id = "u1", status = "interrupted")), "s1")$stop_reason,
    "cancelled")
expect_equal(cerebelo::codex_to_event("turn/completed",
    list(turn = list(id = "u1", status = "failed")), "s1")$stop_reason,
    "failed")

# An explicit turn_id wins over the event's.
expect_equal(cerebelo::codex_to_event("item/agentMessage/delta",
    list(turnId = "u1", delta = "x"), "s1", turn_id = "override")$turn_id,
    "override")

# A turn boundary and an unmapped item are both NULL.
expect_null(cerebelo::codex_to_event("turn/started",
    list(turn = list(id = "u1")), "s1"))
expect_null(cerebelo::codex_to_event("item/reasoning/delta",
    list(delta = "hmm"), "s1"))

# A Codex approval request -> approval_request with the Codex decisions as
# the option ids.
apr <- cerebelo::codex_approval_to_event(
    "item/commandExecution/requestApproval",
    list(threadId = "t1", command = "ls", callId = "c1"), "a1", "s1")
expect_equal(apr$kind, "approval_request")
expect_equal(apr$approval_id, "a1")
expect_equal(apr$title, "ls")
expect_equal(apr$tool_call_id, "c1")
expect_equal(vapply(apr$options, function(o) o$id, ""),
             c("accept", "acceptForSession", "decline"))
expect_equal(apr$options[[1]]$kind, "allow_once")

# The approval body tells the user how to answer, in the slash form.
expect_equal(cerebelo::agent_message(apr)$body,
             "Approve ls? Reply /approve a1 or /deny a1")

# A missing command falls back to a generic title.
apr2 <- cerebelo::codex_approval_to_event("item/patch/requestApproval",
    list(threadId = "t1"), "a2", "s1")
expect_equal(apr2$title, "this action")
