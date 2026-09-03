extends Control
class_name PairMatchFx

const DEFAULT_SIZE := Vector2(104.0, 104.0)
const SMOKE_TUFT_PATH := "res://game-assets/fx/match_smoke_tuft.png"
const SMOKE_PARTICLE_COUNT := 6

static var _shared_smoke_material: ParticleProcessMaterial

func _init(effect_size: Vector2 = DEFAULT_SIZE) -> void:
	size = effect_size
	pivot_offset = effect_size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var particles := GPUParticles2D.new()
	particles.name = "SmokeParticles"
	particles.position = size * 0.5
	particles.amount = SMOKE_PARTICLE_COUNT
	particles.lifetime = 0.28
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.64
	particles.visibility_rect = Rect2(-64.0, -64.0, 128.0, 128.0)
	particles.texture = _load_texture(SMOKE_TUFT_PATH)
	particles.process_material = _smoke_material()
	add_child(particles)
	particles.restart()
	var tween := create_tween()
	tween.tween_interval(0.31)
	tween.finished.connect(queue_free)


static func _smoke_material() -> ParticleProcessMaterial:
	if _shared_smoke_material != null:
		return _shared_smoke_material
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	material.direction = Vector3(1.0, 0.0, 0.0)
	material.spread = 180.0
	material.initial_velocity_min = 38.0
	material.initial_velocity_max = 64.0
	material.gravity = Vector3(0.0, -10.0, 0.0)
	material.damping_min = 15.0
	material.damping_max = 24.0
	material.angular_velocity_min = -80.0
	material.angular_velocity_max = 80.0
	material.scale_min = 0.50
	material.scale_max = 0.76
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.62),
		Color(0.72, 0.82, 0.80, 0.0),
	])
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	material.color_ramp = color_ramp
	_shared_smoke_material = material
	return _shared_smoke_material


static func _load_texture(asset_path: String) -> Texture2D:
	if ResourceLoader.exists(asset_path):
		return load(asset_path) as Texture2D
	elif FileAccess.file_exists(asset_path):
		var img := Image.load_from_file(asset_path)
		if img != null:
			return ImageTexture.create_from_image(img)
	return null
