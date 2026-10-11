extends RefCounted
## CC0 JRPG Pack 4 Calm — Juhani Junkala / SubspaceAudio.
## Stable gameplay keys keep existing phase transitions and saves compatible.
const TRACKS := {
	"title": preload("res://Sounds/Walala/Music/title.ogg"),
	"day_town": preload("res://Sounds/Walala/Music/day.ogg"),
	"night_town3": preload("res://Sounds/Walala/Music/night.ogg"),
}

static func looped(key: String) -> AudioStreamOggVorbis:
	var stream := TRACKS[key].duplicate() as AudioStreamOggVorbis
	stream.set_meta("fmod_source_path", TRACKS[key].resource_path)
	stream.loop = true
	return stream
