extends SceneTree

const Definition := preload("res://scripts/simulation/battle/battle_definition.gd")
const Store := preload("res://scripts/simulation/battle/battle_store.gd")
const Face := preload("res://scripts/simulation/tile_face.gd")
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func send(store: RefCounted, side: String, pairs: int, time: int) -> Dictionary:
	return store.submit({"id": "send_%d" % store.snapshot().revision,
		"expected_revision": store.snapshot().revision, "type": "send_attack", "side": side,
		"pair_count": pairs, "at_ms": time})

func run() -> void:
	var definition := Definition.defaults()
	definition.attacks.delay_ms = 1000 # Fixed deadline fixture, independent of playtest tuning.
	var store := Store.new(definition)
	var cpu_before: Dictionary = store.snapshot().cpu_schedule
	check(send(store, "cpu", 50, 0).accepted, "multi-pool attack accepted")
	var original: Dictionary = store.snapshot().sides.player.pending_attacks[0]
	check(original.tile_pairs.size() == original.pair_count, "pair count matches payload")
	var ids := {}
	var counts := {}
	for pair in original.tile_pairs:
		check(pair.tiles.size() == 2, "exactly two tiles per pair")
		var first: Dictionary = pair.tiles[0]
		var second: Dictionary = pair.tiles[1]
		var face := Face.new(first.face_family, first.face_value)
		check(face.equals(Face.new(second.face_family, second.face_value)), "pair matches via normal identity rules")
		check(face.logical_id().begins_with("reference_"), "default pool preserves reference identity")
		counts[face.logical_id()] = int(counts.get(face.logical_id(), 0)) + 1
		for tile in pair.tiles:
			check(not ids.has(tile.id), "unique physical tile ID")
			ids[tile.id] = true
	check(counts.size() == 24, "pool exhausted before repeat")
	for count in counts.values():
		check(count in [2, 3], "balanced identity frequency in large attack")
	check(store.snapshot().cpu_schedule == cpu_before, "payload RNG independent from CPU")
	var same := Store.new(definition)
	send(same, "cpu", 50, 0)
	check(same.transactions() == store.transactions(), "same seed reproduces payload and RNG")
	var other_definition := definition.duplicate(true)
	other_definition.seed += 1
	var other := Store.new(other_definition)
	send(other, "cpu", 50, 0)
	check(other.snapshot().sides.player.pending_attacks[0].tile_pairs != original.tile_pairs, "different seed changes identities")
	var rng_before: int = store.snapshot().payload_rng_state
	var result := send(store, "player", 3, 100)
	check(result.accepted, "partial cancellation accepted")
	check(store.snapshot().payload_rng_state == rng_before, "fully spent counterattack does not draw unused payload")
	check(result.transaction.events[0].tile_pairs == original.tile_pairs.slice(0, 3), "cancellation records exact whole pairs")
	check(store.snapshot().sides.player.pending_attacks[0].tile_pairs == original.tile_pairs.slice(3), "surviving identities and IDs unchanged")
	store.submit({"id": "land", "expected_revision": store.snapshot().revision,
		"type": "advance_attacks", "side": "player", "at_ms": 1000})
	check(store.snapshot().landed_attacks[0].tile_pairs == original.tile_pairs.slice(3), "landing preserves surviving payload")
	check(store.snapshot().landed_attacks[0].pair_count == 47, "landing count remains balanced")
	send(store, "player", 2, 1100)
	for pair in store.snapshot().sides.cpu.pending_attacks[0].tile_pairs:
		for tile in pair.tiles:
			check(not ids.has(tile.id), "IDs unique across sources and attacks")
	var replay := Store.new(definition)
	for transaction in store.transactions():
		check(replay.apply_transaction(transaction).accepted, "payload transaction replays")
	check(replay.snapshot() == store.snapshot(), "payload replay reproduces RNG and landings")
	var tampered: Dictionary = store.transactions()[0].duplicate(true)
	tampered.after.sides.player.pending_attacks[0].tile_pairs[0].tiles[0].face_value = "invalid"
	check(not Store.new(definition).apply_transaction(tampered).accepted, "tampered tile rejected")
	tampered = store.transactions()[0].duplicate(true)
	tampered.after.payload_rng_state += 1
	check(not Store.new(definition).apply_transaction(tampered).accepted, "tampered payload RNG rejected")
	var limited_definition := definition.duplicate(true)
	limited_definition.payload.max_pairs = 2
	var limited := Store.new(limited_definition)
	send(limited, "cpu", 2, 0)
	var before := limited.snapshot()
	check(not send(limited, "player", 5, 100).accepted and limited.snapshot() == before, "oversize excess rolls back cancellation and RNG")
	check(send(limited, "player", 4, 100).accepted, "limit applies only after cancellation")
	check(limited.snapshot().sides.cpu.pending_attacks[0].tile_pairs.size() == 2, "only excess generates payload")
	var custom := definition.duplicate(true)
	custom.payload.faces = [{"family": "dragon", "value": "red_dragon"}]
	var singleton := Store.new(custom)
	custom.payload.faces[0].value = "white_dragon"
	send(singleton, "player", 3, 0)
	for pair in singleton.snapshot().sides.cpu.pending_attacks[0].tile_pairs:
		check(pair.tiles[0].face_value == "red_dragon", "single-face pool supported and snapshotted")
	for faces in [[], [{"family": "reference", "value": "25"}], [{"family": "wind", "value": "red_dragon"}],
		[{"family": "dots", "value": "0"}], [{"family": "dots", "value": "1"}, {"family": "dots", "value": "1"}], ["bad"]]:
		var invalid := definition.duplicate(true)
		invalid.payload.faces = faces
		check(not Definition.validation_errors(invalid).is_empty(), "invalid vocabulary rejected")
	var old := definition.duplicate(true)
	old.rules_version = 4
	old.erase("cpu_attack_charge_units")
	old.erase("payload")
	old.erase("insertion")
	var legacy := Store.new(old)
	send(legacy, "cpu", 2, 0)
	check(not legacy.snapshot().has("payload_rng_state") and not legacy.snapshot().sides.player.pending_attacks[0].has("tile_pairs"), "rules 4 retain count-only attacks")
	# Natural charge generation enters the same payload path.
	var charged := Store.new(definition)
	var event := {"source_hash": "board", "source_revision": 1, "at_ms": 100,
		"pair_count": 1, "natural_pairs": 1, "score": 100, "streak": 1,
		"momentum_units": 0, "momentum_tier": 1, "cleared_layers": [0, 1]}
	check(charged.submit({"id": "match", "expected_revision": 0, "type": "player_event", "side": "player", "event": event}).accepted, "charge attack accepted")
	check(charged.snapshot().sides.cpu.pending_attacks[0].tile_pairs.size() == 1, "charge crossing creates physical pair")
	print("Battle B5: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
