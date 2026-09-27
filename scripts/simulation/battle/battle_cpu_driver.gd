extends RefCounted

const Cpu := preload("res://scripts/simulation/battle/battle_cpu.gd")
const MAX_EVENTS_PER_CALL := 128
var _store: RefCounted


func _init(store: RefCounted) -> void:
	_store = store


## The caller supplies active-play milliseconds; it must exclude pauses.
## A capped catch-up call never drops events: repeat the same horizon if pending.
func advance_to(active_time_ms: int) -> Dictionary:
	if active_time_ms < 0 or active_time_ms > Cpu.MAX_TIME_MS:
		return {"accepted": false, "reason": "invalid_time"}
	var events: Array[Dictionary] = []
	for unused in range(MAX_EVENTS_PER_CALL):
		var state: Dictionary = _store.snapshot()
		if state.is_empty() or not state.has("cpu_schedule"):
			return {"accepted": false, "reason": "cpu_unavailable"}
		if active_time_ms < state.cpu_schedule.last_event_ms:
			return {"accepted": false, "reason": "stale_time"}
		if state.status != "playing" or state.cpu_schedule.next_event_ms > active_time_ms:
			return {"accepted": true, "events": events, "pending": false}
		var schedule: Dictionary = state.cpu_schedule
		var result: Dictionary = _store.submit({
			"id": "cpu_event_%d" % (schedule.event_count + 1),
			"expected_revision": state.revision, "type": "cpu_step", "side": "cpu",
			"at_ms": schedule.next_event_ms,
		})
		if not result.accepted:
			return {"accepted": false, "reason": result.reason, "events": events}
		events.append(result.transaction)
	var final: Dictionary = _store.snapshot()
	return {"accepted": true, "events": events,
		"pending": final.status == "playing" and final.cpu_schedule.next_event_ms <= active_time_ms}
