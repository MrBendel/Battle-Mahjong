extends RefCounted


static func insets(viewport_size: Vector2, safe_rect: Rect2i, screen_size: Vector2i) -> Rect2:
	if safe_rect.size == Vector2i.ZERO or screen_size == Vector2i.ZERO:
		return Rect2()
	var scale := viewport_size / Vector2(screen_size)
	var safe_end := safe_rect.position + safe_rect.size
	return Rect2(
		maxf(0.0, float(safe_rect.position.x) * scale.x),
		maxf(0.0, float(safe_rect.position.y) * scale.y),
		maxf(0.0, float(screen_size.x - safe_end.x) * scale.x),
		maxf(0.0, float(screen_size.y - safe_end.y) * scale.y)
	)


static func content_rect(viewport_size: Vector2, edge_insets: Rect2) -> Rect2:
	return Rect2(
		edge_insets.position,
		Vector2(
			maxf(0.0, viewport_size.x - edge_insets.position.x - edge_insets.size.x),
			maxf(0.0, viewport_size.y - edge_insets.position.y - edge_insets.size.y)
		)
	)
