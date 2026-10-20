extends RefCounted
## CC0 original recordings. Full provenance and measured levels: World/manifest.json.
const AMBIENCE := {
	"birds": preload("res://Sounds/Walala/World/Ambience/birds.ogg"),
	"crickets": preload("res://Sounds/Walala/World/Ambience/crickets.ogg"),
	"water": preload("res://Sounds/Walala/World/Ambience/water.ogg"),
	"fire": preload("res://Sounds/Walala/World/Ambience/fire.ogg"),
	"cooking": preload("res://Sounds/Walala/World/Ambience/cooking.ogg"),
}
const AMBIENCE_GAIN_DB := {"birds": -2.0, "crickets": 1.0, "water": -3.0, "fire": 7.0, "cooking": 13.0}
const SOUNDS := {
	"door_open": [preload("res://Sounds/Walala/World/SFX/door_open_01.ogg"), preload("res://Sounds/Walala/World/SFX/door_open_02.ogg")],
	"door_close": [preload("res://Sounds/Walala/World/SFX/door_close_01.ogg"), preload("res://Sounds/Walala/World/SFX/door_close_02.ogg")],
}
const INDOORS := ["restaurant", "home", "blacksmith", "store", "furniture_store"]

static func ambience_key(phase: String, location: String, weather: String, region: String, cooking: bool) -> String:
	if phase == "result": return ""
	if location == "blacksmith": return "fire"
	if location == "restaurant": return "cooking" if cooking else ""
	if location in INDOORS: return ""
	if location == "dock" or (location == "field" and region == "marsh"): return "water"
	# Rain and snow replace wildlife, avoiding birds or summer insects in a storm.
	if weather != "clear": return ""
	if phase != "day": return "crickets"
	if location == "field" and region in ["quarry", "ruins", "ridge", "observatory"]: return ""
	return "birds"

static func looped(key: String) -> AudioStreamOggVorbis:
	var stream := AMBIENCE[key].duplicate() as AudioStreamOggVorbis
	stream.set_meta("fmod_source_path", AMBIENCE[key].resource_path)
	stream.loop = true
	return stream
