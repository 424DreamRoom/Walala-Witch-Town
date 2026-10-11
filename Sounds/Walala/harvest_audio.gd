extends RefCounted
## Explicit resource references also include these clips in exported builds.
const SOUNDS := {
	"gather": [preload("res://Sounds/Walala/Harvest/gather_01.ogg"), preload("res://Sounds/Walala/Harvest/gather_02.ogg")],
	"chop": [preload("res://Sounds/Walala/Harvest/chop_01.ogg"), preload("res://Sounds/Walala/Harvest/chop_02.ogg"), preload("res://Sounds/Walala/Harvest/chop_03.ogg")],
	"mine": [preload("res://Sounds/Walala/Harvest/mine_01.ogg"), preload("res://Sounds/Walala/Harvest/mine_02.ogg"), preload("res://Sounds/Walala/Harvest/mine_03.ogg")],
	"cast": [preload("res://Sounds/Walala/Harvest/cast_01.ogg"), preload("res://Sounds/Walala/Harvest/cast_02.ogg")],
	"bite": [preload("res://Sounds/Walala/Harvest/bite_01.ogg")],
	"catch": [preload("res://Sounds/Walala/Harvest/catch_01.ogg"), preload("res://Sounds/Walala/Harvest/catch_02.ogg")],
}
const GAIN_DB := {"gather": 16.0, "chop": -6.0, "mine": -8.0, "cast": -3.0, "bite": -5.0, "catch": -5.0}
# These original foliage recordings are very quiet; calibrate each without editing bytes.
const VARIANT_GAIN_DB := {"gather": [16.0, 22.0]}

static func gain_db(key: String, index: int = 0) -> float:
	if VARIANT_GAIN_DB.has(key): return VARIANT_GAIN_DB[key][index]
	return GAIN_DB.get(key, -6.0)
