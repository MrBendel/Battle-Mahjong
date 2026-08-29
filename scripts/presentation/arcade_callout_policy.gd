extends RefCounted
class_name ArcadeCalloutPolicy

func choose_for_transaction(telemetry: Dictionary, score_after: int, tuning: Resource) -> Dictionary:
	var modifier_alert := _choose_modifier_reward(telemetry)
	if not modifier_alert.is_empty():
		return modifier_alert
	if bool(telemetry.get("all_flipped_tiles_revealed", false)):
		return _alert("board_progress", "all_tiles_revealed", "ALL TILES REVEALED!")
	return choose_for_pair(telemetry, score_after, tuning)


func choose_for_pair(telemetry: Dictionary, score_after: int, tuning: Resource) -> Dictionary:
	if tuning == null or tuning.combo_alert_interval <= 0 or tuning.first_combo_alert <= 10:
		return {}
	var difficulty_reward: Dictionary = telemetry.get("difficulty_reward", {})
	var difficulty_key := str(difficulty_reward.get("callout_key", ""))
	if difficulty_key == "great":
		return _alert("difficulty", "well_hidden", "WELL HIDDEN!")
	if difficulty_key == "eagle_eyes":
		if int(difficulty_reward.get("difficulty_percentile_bps", 0)) \
				>= tuning.amazing_find_min_percentile_basis_points:
			return _alert("difficulty", "amazing_find", "AMAZING FIND!")
		return _alert("difficulty", "eagle_eyes", "EAGLE EYES!")
	var hidden_pair_recognition: Dictionary = telemetry.get("hidden_pair_recognition", {})
	var hidden_pair_key := str(hidden_pair_recognition.get("callout_key", ""))
	if hidden_pair_key == "great":
		return _alert("difficulty", "well_hidden", "WELL HIDDEN!")
	if hidden_pair_key == "eagle_eyes":
		return _alert("difficulty", "eagle_eyes", "EAGLE EYES!")

	var score_gain := int(telemetry.get("score_gain", 0))
	var score_before := score_after - score_gain
	var crossed_milestone := 0
	for milestone in tuning.score_milestones:
		if score_before < milestone and score_after >= milestone:
			crossed_milestone = milestone
	if crossed_milestone > 0:
		return _alert("score", "score_milestone", "SCORE %s!" % _compact_score(crossed_milestone))

	var combo_before := int(telemetry.get("combo_before", 0))
	var combo_after := int(telemetry.get("combo_after", 0))
	if combo_after > combo_before and _is_combo_milestone(combo_after, tuning):
		return _alert("combo", "combo", "%d COMBO!" % combo_after)
	return {}


func _is_combo_milestone(combo: int, tuning: Resource) -> bool:
	return combo == tuning.first_combo_alert \
		or combo > tuning.first_combo_alert and combo % tuning.combo_alert_interval == 0


func _alert(type: String, key: String, text: String) -> Dictionary:
	return {"type": type, "key": key, "text": text}


func _choose_modifier_reward(telemetry: Dictionary) -> Dictionary:
	var triggered: Array = telemetry.get("modifiers_triggered", [])
	if triggered.is_empty() or not triggered[0] is Dictionary:
		return {}
	var modifier: Dictionary = triggered[0]
	var modifier_type := str(modifier.get("type", ""))
	var effect: Dictionary = modifier.get("effect", {})
	match modifier_type:
		"extra_life":
			return _alert(
				"modifier_reward",
				"extra_life",
				"EXTRA LIFE +%d" % int(effect.get("charges", 1))
			)
		"cold_snap":
			return _alert(
				"modifier_reward",
				"cold_snap",
				"MOMENTUM FROZEN %s" % _format_duration(int(effect.get("duration_ms", 0)))
			)
		"score_multiplier":
			return _alert(
				"modifier_reward",
				"score_multiplier",
				"SCORE BOOST %s" % _format_basis_points(int(effect.get("basis_points", 1000)))
			)
		"tray_plus_one":
			return _alert(
				"modifier_reward",
				"tray_plus_one",
				"TRAY +1 FOR %d PAIRS" % int(effect.get("pair_duration", 0))
			)
	return {}


func _format_duration(duration_ms: int) -> String:
	if duration_ms % 1000 == 0:
		return "%dS" % int(duration_ms / 1000)
	return "%.1fS" % (float(duration_ms) / 1000.0)


func _format_basis_points(basis_points: int) -> String:
	var whole := int(basis_points / 1000)
	var fractional := basis_points % 1000
	if fractional % 100 == 0:
		return "%d.%dX" % [whole, int(fractional / 100)]
	return "%d.%03dX" % [whole, fractional]


func _compact_score(score: int) -> String:
	if score >= 1000 and score % 1000 == 0:
		return "%dK" % int(score / 1000)
	return _formatted_score(score)


func _formatted_score(score: int) -> String:
	var digits := str(score)
	var formatted := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits[index]
	return formatted
