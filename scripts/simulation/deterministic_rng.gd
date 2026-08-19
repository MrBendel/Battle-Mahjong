extends RefCounted
class_name DeterministicRng

const _MODULUS := 2147483647
const _MULTIPLIER := 48271

var initial_seed: int
var _state: int

func _init(seed: int = 1) -> void:
	set_seed(seed)


func set_seed(seed: int) -> void:
	initial_seed = _normalize_seed(seed)
	_state = initial_seed


func get_seed() -> int:
	return initial_seed


func get_state() -> int:
	return _state


func next_int() -> int:
	_state = int((int(_state) * _MULTIPLIER) % _MODULUS)
	return _state


func next_float() -> float:
	return float(next_int()) / float(_MODULUS)


func range_int(min_value: int, max_value: int) -> int:
	if max_value < min_value:
		push_error("DeterministicRng.range_int called with max_value below min_value.")
		return min_value

	var span := max_value - min_value + 1
	return min_value + (next_int() % span)


func _normalize_seed(seed: int) -> int:
	var normalized := seed % _MODULUS
	if normalized <= 0:
		normalized += _MODULUS - 1
	return normalized
