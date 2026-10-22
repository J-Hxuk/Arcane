extends RefCounted
## Shared basic sword tuning for the world and the legacy combat test scene.
const MELEE_BASE_DAMAGE := 8.0
const MELEE_BODY_SCALING := 0.04
const MELEE_INTERVAL := 0.8
static func melee_damage(body_talent: float) -> float:
	return MELEE_BASE_DAMAGE + maxf(0.0, body_talent) * MELEE_BODY_SCALING
