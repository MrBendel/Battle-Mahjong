extends RefCounted
class_name PresentationScale

const SafeAreaScript := preload("res://scripts/presentation/safe_area.gd")
const DEFAULT_REFERENCE_SIZE := Vector2(390.0, 844.0)


static func limiting_scale(
	available_size: Vector2,
	reference_size: Vector2 = DEFAULT_REFERENCE_SIZE,
	minimum_scale: float = 0.01,
	maximum_scale: float = INF
) -> float:
	if reference_size.x <= 0.0 or reference_size.y <= 0.0:
		return minimum_scale
	return clampf(
		minf(available_size.x / reference_size.x, available_size.y / reference_size.y),
		minimum_scale,
		maximum_scale
	)


static func safe_display_scale(
	viewport_size: Vector2,
	edge_insets: Rect2,
	reference_size: Vector2 = DEFAULT_REFERENCE_SIZE,
	minimum_scale: float = 0.01,
	maximum_scale: float = INF
) -> float:
	var safe_rect := SafeAreaScript.content_rect(viewport_size, edge_insets)
	return limiting_scale(safe_rect.size, reference_size, minimum_scale, maximum_scale)
