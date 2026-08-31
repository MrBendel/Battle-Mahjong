extends Control
class_name PairMatchFx

const DEFAULT_SIZE := Vector2(104.0, 104.0)
const SMOKE_TUFT := preload("res://game-assets/fx/match_smoke_tuft.png")
const SMOKE_PARTICLE_COUNT := 6

var play_count := 0
var _particles: CPUParticles2D


func _init(effect_size: Vector2 = DEFAULT_SIZE) -> void:
	size = effect_size
	pivot_offset = effect_size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
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
	add_child(_particles)


func play() -> void:
	play_count += 1
	_particles.restart()
	_particles.emitting = true


static func _smoke_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.90),
		Color(1.0, 1.0, 1.0, 0.72),
		Color(0.82, 0.82, 0.82, 0.0),
	])
	return gradient
