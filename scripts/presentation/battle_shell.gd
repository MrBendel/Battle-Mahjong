extends Control

signal return_to_town_requested
const Host := preload("res://scripts/simulation/battle/battle_host.gd")
const Definition := preload("res://scripts/simulation/battle/battle_definition.gd")
const Factory := preload("res://scripts/simulation/reference_game_factory.gd")
const Game := preload("res://scripts/simulation/game_state.gd")
const GameDefinition := preload("res://scripts/simulation/game_definition.gd")
const Insertion := preload("res://scripts/simulation/battle/battle_insertion.gd")
const Board := preload("res://scripts/presentation/board_view.gd")
const Tray := preload("res://scripts/presentation/tray_view.gd")
const TileSkinResource := preload("res://scripts/presentation/tile_skin.gd")
const AttackFx := preload("res://scripts/presentation/battle_attack_fx.gd")
const Hud := preload("res://scripts/presentation/battle_hud.gd")
const CharacterView := preload("res://scripts/presentation/battle_character_view.gd")
const Overlay := preload("res://scripts/presentation/battle_overlay.gd")
const Scale := preload("res://scripts/presentation/presentation_scale.gd")
const Safe := preload("res://scripts/presentation/safe_area.gd")
var gameplay_theme: Resource = preload("res://configuration/default_gameplay_theme.tres")
@export_file("*.json") var battle_tuning_path := "res://configuration/battle/prototype.json"
var seed := 42
var snapshot: Dictionary = {}
var safe_area_override := Rect2()
var _host: RefCounted
var _game: RefCounted
var _skin: RefCounted
var _board: Control
var _tray: Control
var _fx: Control
var _hud: Control
var _character: Control
var _overlay: Control
var _pause: Button
var _background: NinePatchRect
var _thread: Thread
var _active_ms := 0.0
var _paused := false
var _retry := false
var _definition_hash := ""
var _board_revision := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background = NinePatchRect.new()
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_background.set_patch_margin(side, gameplay_theme.background_patch_margin)
	add_child(_background)
	_hud = Hud.new()
	_hud.gameplay_theme = gameplay_theme
	add_child(_hud)
	_character = CharacterView.new()
	_character.character = gameplay_theme.battle_character if gameplay_theme.battle_character != null else preload("res://configuration/battle/rivet.tres")
	_character.gameplay_theme = gameplay_theme
	_hud.opponent_name = _character.character.display_name
	add_child(_character)
	_fx = AttackFx.new()
	_fx.gameplay_theme = gameplay_theme
	_fx.hud = _hud
	add_child(_fx)
	_pause = Button.new()
	_pause.text = "Ⅱ"
	_pause.pressed.connect(pause_battle)
	add_child(_pause)
	_overlay = Overlay.new()
	add_child(_overlay)
	_overlay.resumed.connect(func() -> void:
		_paused = false
		_overlay.hide())
	_overlay.restarted.connect(func() -> void: _retry = true)
	_overlay.town_requested.connect(func() -> void: return_to_town_requested.emit())
	resized.connect(_layout)
	_layout()
	_start()

func _start() -> void:
	_fx.clear()
	_character.reset()
	_overlay.clear_reaction()
	_paused = false
	_active_ms = 0
	snapshot = {}
	_board_revision = -1
	_definition_hash = ""
	_overlay.show_message("PREPARING BATTLE", false)
	_overlay.retry_button.disabled = true
	_thread = Thread.new()
	_thread.start(func() -> Dictionary:
		var tuning := Definition.from_json_file(battle_tuning_path)
		if not Definition.validation_errors(tuning).is_empty():
			return {"initial": true, "accepted": false, "reason": "invalid_battle_tuning"}
		tuning.seed = seed
		var generated: Dictionary = Factory.new().create_generated(seed)
		_host = Host.new(tuning, generated.definition, generated.solution)
		return {"initial": true, "accepted": _host.store != null,
			"events": _host.opening_events,
			"snapshot": _host.store.snapshot() if _host.store != null else {}})

func _process(delta: float) -> void:
	_fx.suspended = _paused
	_character.suspended = _paused
	_fx.active_ms = int(_active_ms)
	if _thread != null:
		if _thread.is_alive():
			return
		var result: Dictionary = _thread.wait_to_finish()
		_thread = null
		_overlay.retry_button.disabled = false
		if result.get("initial", false) and result.accepted and not _paused:
			_overlay.hide()
		if result.has("snapshot") and not result.snapshot.is_empty():
			_present(result.snapshot)
		_fx.board = _board
		_fx.skin = _skin
		_fx.suspended = _paused
		_fx.consume(result.get("events", []))
		_character.consume(result.get("events", []))
		if not snapshot.is_empty() and snapshot.status != "playing":
			_overlay.show_reaction(_character.reaction_texture(), _character.reaction_text())
		if not result.accepted and result.get("reason", "") not in ["invalid_selection", "battle_finished"]:
			_paused = true
			_overlay.show_message("BATTLE INTERRUPTED", false)
	if _retry:
		_retry = false
		seed += 1
		_start()
		return
	if _paused or snapshot.is_empty() or snapshot.status != "playing":
		return
	_active_ms += delta * 1000.0
	var due: int = _host.next_event_ms()
	if due >= 0 and due <= int(_active_ms):
		_dispatch("")

func _dispatch(tile_id: String) -> void:
	if _thread != null or _paused or snapshot.is_empty() or snapshot.status != "playing":
		return
	var at_ms := int(_active_ms)
	_thread = Thread.new()
	_thread.start(func() -> Dictionary:
		var result: Dictionary = _host.advance_to(at_ms) if tile_id.is_empty() else _host.tap(tile_id, at_ms)
		result["snapshot"] = _host.store.snapshot()
		return result)

func _present(state: Dictionary) -> void:
	snapshot = state
	_hud.refresh(state, _host.store.definition_snapshot().charge.attack_threshold_units)
	var data: Dictionary = state.player_board
	if _board_revision != data.state.revision:
		var effective := GameDefinition.from_dict(data.definition)
		var hash_value: String = effective.definition_hash()
		if _game == null or hash_value != _definition_hash:
			_game = Game.new(effective)
			_game.get("_state").assign_from(Insertion.restore(data.state))
			if _board == null:
				_skin = TileSkinResource.new(gameplay_theme.tile_skin_manifest_path)
				_board = Board.new(_game, _skin, gameplay_theme)
				_board.tile_selected.connect(_dispatch)
				_board.locked_tile_tapped.connect(_dispatch)
				add_child(_board)
				_board.set_compact_mode(true)
				_tray = Tray.new(_game, _skin, gameplay_theme)
				add_child(_tray)
				_tray.set_portrait_style(true)
			else:
				_board.set_game_state(_game)
				_tray.set_game_state(_game)
			_definition_hash = hash_value
		else:
			_game.get("_state").assign_from(Insertion.restore(data.state))
		_board_revision = data.state.revision
		_board.refresh()
		_tray.refresh()
		_layout()
	if state.status != "playing":
		_paused = true
		_overlay.show_message("YOU WIN!" if state.winner == "player" else "CPU WINS", false)

func pause_battle() -> void:
	if snapshot.is_empty() or snapshot.status != "playing":
		return
	_paused = true
	_character.suspended = true
	if _board != null:
		_board.reset_input_state()
	_overlay.show_message("BATTLE PAUSED", true)

func _notification(what: int) -> void:
	if is_node_ready() and what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		pause_battle()

func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()

func _layout() -> void:
	if _hud == null:
		return
	var insets := safe_area_override
	if insets == Rect2():
		insets = Safe.insets(size, DisplayServer.get_display_safe_area(), DisplayServer.screen_get_size())
	var safe := Safe.content_rect(size, insets)
	var landscape := safe.size.x > safe.size.y
	var s := Scale.limiting_scale(safe.size, Vector2(844, 390) if landscape else Vector2(390, 844))
	var margin := 12 * s
	_pause.position = safe.position + Vector2(safe.size.x - 38 * s, margin)
	_pause.custom_minimum_size = Vector2.ZERO
	_pause.size = Vector2(28, 28) * s
	_pause.add_theme_font_size_override("font_size", maxi(1, roundi(14 * s)))
	var pause_style := StyleBoxFlat.new()
	pause_style.bg_color = Color(gameplay_theme.battle_panel_color, 0.85)
	pause_style.set_content_margin_all(0)
	for state in ["normal", "hover", "pressed", "focus"]:
		_pause.add_theme_stylebox_override(state, pause_style)
	_pause.size = Vector2(28, 28) * s
	var background_path: String = gameplay_theme.background_landscape_path if landscape and not gameplay_theme.background_landscape_path.is_empty() else gameplay_theme.background_path
	_background.texture = load(background_path)
	_overlay.set_safe_area_insets(insets)
	var board_rect: Rect2
	var tray_rect: Rect2
	# One compact horizontal race header in both orientations. Character events
	# are clipped overlays over this header and never participate in layout.
	var hud_height := 88 * s
	_hud.position = safe.position + Vector2(margin, margin)
	_hud.size = Vector2(safe.size.x - 60 * s, hud_height)
	var tray_height := (54 if landscape else 78) * s
	tray_rect = Rect2(safe.position + Vector2(40 * s, margin + hud_height + 4 * s), Vector2(safe.size.x - 80 * s, tray_height))
	var board_top := tray_rect.end.y + 4 * s
	board_rect = Rect2(Vector2(safe.position.x + margin, board_top), Vector2(safe.size.x - 2 * margin, safe.end.y - margin - board_top))
	if landscape:
		# Keep the existing broad Board's vertical footprint. The same tray
		# tucks below the header on the left instead of consuming a second row.
		tray_rect = Rect2(safe.position + Vector2(margin, 104 * s), Vector2(226, 78) * s)
		board_rect = Rect2(safe.position + Vector2(250 * s, 104 * s), Vector2(safe.size.x - 262 * s, safe.size.y - 116 * s))
	_character.position = Vector2(maxf(_hud.position.x, _hud.get_rect().end.x - 360 * s), _hud.position.y)
	_character.size = Vector2(minf(_hud.size.x, 360 * s), hud_height)
	if _board != null:
		_skin.set_orientation("landscape" if landscape else "portrait")
		_board.position = board_rect.position
		_board.size = board_rect.size
		_board.set_content_scale(1.0)
		_board.refresh_layout()
		_tray.position = tray_rect.position
		_tray.size = tray_rect.size
		_tray.set_tile_visual_size(_board.tile_visual_size() * 0.7)
