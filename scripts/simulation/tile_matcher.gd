extends RefCounted

func faces_match(a: Variant, b: Variant) -> bool:
	return a != null and b != null and a.equals(b)


func tiles_match(a: Variant, b: Variant) -> bool:
	if a == null or b == null:
		return false

	return faces_match(a.face, b.face)
