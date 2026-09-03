extends Control
class_name PairMatchFx

const DEFAULT_SIZE := Vector2(104.0, 104.0)
const IMPACT_BURST := preload("res://game-assets/fx/match_impact_burst.png")
const SMOKE_TUFT := preload("res://game-assets/fx/match_smoke_tuft.png")
const SMOKE_PARTICLE_COUNT := 6
const BURST_VISUAL_SCALE := 0.50
const BURST_EXPAND_SECONDS := 0.07
const BURST_HOLD_SECONDS := 0.07
const BURST_FADE_SECONDS := 0.12

var play_count := 0
var _burst: Sprite2D
var _burst_tween: Tween
var _particles: CPUParticles2D


func _init(effect_size: Vector2 = DEFAULT_SIZE) -> void:
	size = effect_size
	pivot_offset = effect_size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_burst = Sprite2D.new()
	_burst.name = "ImpactBurst"
	_burst.texture = IMPACT_BURST
	_burst.position = size * 0.5
	_burst.centered = true
	_burst.visible = false
	var burst_material := CanvasItemMaterial.new()
	burst_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_burst.material = burst_material
	add_child(_burst)

	_particles = CPUParticles2D.new()
	_particles.name = "SmokeParticles"
	_particles.position = size * 0.5
	_particles.amount = SMOKE_PARTICLE_COUNT
	_particles.lifetime = 0.28
	_particles.one_shot = true
	_particles.explosiveness = 1.0
	_particles.randomness = 0.64
	_particles.texture = SMOKE_TUFT
	_particles.direction = Vector2.RIGHT
	_particles.spread = 180.0
	_particles.initial_velocity_min = 38.0
	_particles.initial_velocity_max = 64.0
	_particles.gravity = Vector2(0.0, -10.0)
	_particles.damping_min = 15.0
	_particles.damping_max = 24.0
	_particles.angular_velocity_min = -80.0
	_particles.angular_velocity_max = 80.0
	_particles.scale_amount_min = 0.50
	_particles.scale_amount_max = 0.76
	_particles.color_ramp = _smoke_gradient()
	_particles.emitting = false
	_particles.z_index = 1
	add_child(_particles)


func play() -> void:
	play_count += 1
	_play_impact_burst()
	_particles.restart()
	_particles.emitting = true


func _play_impact_burst() -> void:
	if _burst_tween != null and _burst_tween.is_valid():
		_burst_tween.kill()
	_burst.visible = true
	_burst.modulate = Color.WHITE
	_burst.scale = Vector2.ONE * (0.34 * BURST_VISUAL_SCALE)
	_burst.rotation = deg_to_rad(float((play_count * 37) % 90) - 45.0)
	_burst_tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_burst_tween.tween_property(
		_burst,
		"scale",
		Vector2.ONE * (1.08 * BURST_VISUAL_SCALE),
		BURST_EXPAND_SECONDS
	)
	_burst_tween.tween_interval(BURST_HOLD_SECONDS)
	_burst_tween.chain().set_parallel(true)
	_burst_tween.tween_property(
		_burst,
		"scale",
		Vector2.ONE * (1.30 * BURST_VISUAL_SCALE),
		BURST_FADE_SECONDS
	)
	_burst_tween.tween_property(_burst, "modulate:a", 0.0, BURST_FADE_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_burst_tween.finished.connect(func() -> void:
		_burst.visible = false
		_burst_tween = null
	)


static func _smoke_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.90),
		Color(1.0, 1.0, 1.0, 0.72),
		Color(0.82, 0.82, 0.82, 0.0),
	])
	return gradient
