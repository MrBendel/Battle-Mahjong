extends RefCounted

const DEFAULT_PATH := "res://configuration/battle/prototype.json"
const Cpu := preload("res://scripts/simulation/battle/battle_cpu.gd")
const Charge := preload("res://scripts/simulation/battle/battle_charge.gd")
const Attacks := preload("res://scripts/simulation/battle/battle_attacks.gd")
const Payload := preload("res://scripts/simulation/battle/battle_payload.gd")
const Insertion := preload("res://scripts/simulation/battle/battle_insertion.gd")
const MAX_COUNTER := 1000000000


static func defaults() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_PATH))
	if not parsed is Dictionary:
		return {}
	# JSON parses numbers as floats; normalize only integral configuration values.
	var result: Dictionary = parsed.duplicate(true)
	for key in result:
		if result[key] is Dictionary:
			for nested in result[key]:
				var value: Variant = result[key][nested]
				if value is float and is_finite(value) and value == floor(value):
					result[key][nested] = int(value)
		if result[key] is float and is_finite(result[key]) and result[key] == floor(result[key]):
			result[key] = int(result[key])
	return result


static func validation_errors(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["rules_version", "seed", "player_starting_pairs", "cpu_starting_pairs"]:
		if not data.get(key) is int:
			errors.append("%s must be an integer." % key)
	if not errors.is_empty():
		return errors
	if data.rules_version not in [1, 2, 3, 4, 5, 6, 7, 8]:
		errors.append("Unsupported Battle rules version.")
	for key in ["player_starting_pairs", "cpu_starting_pairs"]:
		if data[key] < 1 or data[key] > MAX_COUNTER:
			errors.append("%s is outside the supported range." % key)
	if data.rules_version >= 2:
		if not data.get("cpu") is Dictionary:
			errors.append("CPU configuration is required for Battle rules 2.")
		else:
			errors.append_array(Cpu.validation_errors(data.cpu))
	if data.rules_version >= 3:
		if not data.get("charge") is Dictionary:
			errors.append("Charge configuration is required for Battle rules 3.")
		else:
			errors.append_array(Charge.validation_errors(data.charge))
	if data.rules_version >= 4:
		if not data.get("attacks") is Dictionary:
			errors.append("Attack tuning required for Battle rules 4.")
		else:
			errors.append_array(Attacks.validation_errors(data.attacks))
	if data.rules_version >= 5:
		if not data.get("payload") is Dictionary:
			errors.append("Payload configuration required for Battle rules 5.")
		else:
			errors.append_array(Payload.validation_errors(data.payload))
	if data.rules_version >= 6:
		if not data.get("insertion") is Dictionary:
			errors.append("Insertion tuning required for Battle rules 6.")
		else:
			errors.append_array(Insertion.validation_errors(data.insertion))
	if data.rules_version >= 8 and (not data.get("cpu_attack_charge_units") is int or data.cpu_attack_charge_units < 0 or data.cpu_attack_charge_units > 1000000):
		errors.append("Invalid CPU attack charge units.")
	for key in data:
		if key not in ["rules_version", "seed", "player_starting_pairs", "cpu_starting_pairs"] and not (key == "cpu" and data.rules_version >= 2) and not (key == "charge" and data.rules_version >= 3) and not (key == "attacks" and data.rules_version >= 4) and not (key == "payload" and data.rules_version >= 5) and not (key == "insertion" and data.rules_version >= 6) and not (key == "cpu_attack_charge_units" and data.rules_version >= 8):
			errors.append("Unknown Battle definition field: %s" % key)
	return errors
