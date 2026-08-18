extends RefCounted

const DEFAULT_TRAY_CAPACITY := 4


static func create(tray_capacity: int = DEFAULT_TRAY_CAPACITY) -> Dictionary:
	return {
		"tray_capacity": tray_capacity,
		"momentum_max": 100000,
		"momentum_pair_gain": 30000,
		"momentum_thresholds": [0, 20000, 40000, 60000, 80000],
		"momentum_decay_per_ms": [5, 7, 10, 14, 19],
		"pair_base_score": 100,
	}
