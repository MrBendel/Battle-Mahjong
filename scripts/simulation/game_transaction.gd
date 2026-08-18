extends RefCounted

const GameChangeScript := preload("res://scripts/simulation/game_change.gd")
const GameCommandScript := preload("res://scripts/simulation/game_command.gd")

const SCHEMA_VERSION := 1

var transaction_id: String
var definition_hash: String
var revision: int
var actor_id: String
var command_id: String
var command_type: String
var logical_tick: int
var playback_time_ms: int
var changes: Array
var result: String
var reverts_transaction_id: String
var previous_state_hash: String
var next_state_hash: String
var telemetry: Dictionary


func _init(
		command: Variant,
		transaction_changes: Array,
		transaction_result: String,
		reverts_id: String = ""
) -> void:
	revision = command.expected_revision + 1
	transaction_id = "tx_%06d" % revision
	actor_id = command.actor_id
	command_id = command.command_id
	command_type = command.type
	logical_tick = revision
	playback_time_ms = command.playback_time_ms
	changes = transaction_changes.duplicate()
	result = transaction_result
	reverts_transaction_id = reverts_id
	telemetry = {}


func to_dict() -> Dictionary:
	var serialized_changes: Array = []
	for change in changes:
		serialized_changes.append(change.to_dict())
	return {
		"schema_version": SCHEMA_VERSION,
		"transaction_id": transaction_id,
		"definition_hash": definition_hash,
		"revision": revision,
		"actor_id": actor_id,
		"command_id": command_id,
		"command_type": command_type,
		"logical_tick": logical_tick,
		"playback_time_ms": playback_time_ms,
		"changes": serialized_changes,
		"result": result,
		"reverts_transaction_id": reverts_transaction_id,
		"previous_state_hash": previous_state_hash,
		"next_state_hash": next_state_hash,
		"telemetry": telemetry.duplicate(true),
	}


func duplicate_transaction() -> RefCounted:
	var copied_changes: Array = []
	for change in changes:
		copied_changes.append(change.call("duplicate_change"))
	var command := GameCommandScript.new(command_type, {}, revision - 1, command_id, actor_id, playback_time_ms)
	var copy: Variant = get_script().new(command, copied_changes, result, reverts_transaction_id)
	copy.transaction_id = transaction_id
	copy.definition_hash = definition_hash
	copy.logical_tick = logical_tick
	copy.playback_time_ms = playback_time_ms
	copy.previous_state_hash = previous_state_hash
	copy.next_state_hash = next_state_hash
	copy.telemetry = telemetry.duplicate(true)
	return copy


static func from_dict(data: Dictionary) -> RefCounted:
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION:
		return null
	var revision_value := int(data.get("revision", 0))
	var command := GameCommandScript.new(
		str(data.get("command_type", "")),
		{},
		revision_value - 1,
		str(data.get("command_id", "")),
		str(data.get("actor_id", "")),
		int(data.get("playback_time_ms", 0))
	)
	var parsed_changes: Array = []
	for serialized_change in data.get("changes", []):
		parsed_changes.append(GameChangeScript.from_dict(serialized_change))

	var script: Script = load("res://scripts/simulation/game_transaction.gd")
	var transaction: Variant = script.new(
		command,
		parsed_changes,
		str(data.get("result", "")),
		str(data.get("reverts_transaction_id", ""))
	)
	transaction.transaction_id = str(data.get("transaction_id", ""))
	transaction.definition_hash = str(data.get("definition_hash", ""))
	transaction.logical_tick = int(data.get("logical_tick", revision_value))
	transaction.playback_time_ms = int(data.get("playback_time_ms", 0))
	transaction.previous_state_hash = str(data.get("previous_state_hash", ""))
	transaction.next_state_hash = str(data.get("next_state_hash", ""))
	transaction.telemetry = data.get("telemetry", {}).duplicate(true)
	return transaction
