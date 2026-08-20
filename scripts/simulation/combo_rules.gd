extends RefCounted


static func count_at(state: Variant, playback_time_ms: int) -> int:
	if state.combo_count <= 0:
		return 0
	if state.combo_expires_at_ms > 0 and playback_time_ms >= state.combo_expires_at_ms:
		return 0
	return state.combo_count


static func remaining_ms_at(state: Variant, playback_time_ms: int) -> int:
	if state.combo_expires_at_ms <= 0 or count_at(state, playback_time_ms) == 0:
		return 0
	return maxi(0, state.combo_expires_at_ms - playback_time_ms)


static func expiry_after_pair(playback_time_ms: int, configuration: Dictionary) -> int:
	return playback_time_ms + int(configuration.combo_window_ms)
