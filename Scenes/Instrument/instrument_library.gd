extends RefCounted
## Three octave rows, seven natural-note columns, matching the instrument panel.
const COLUMNS := ["c", "d", "e", "f", "g", "a", "b"]
const OCTAVES := [4, 5, 6]
const NOTE_NAMES := [
	"C4", "D4", "E4", "F4", "G4", "A4", "B4",
	"C5", "D5", "E5", "F5", "G5", "A5", "B5",
	"C6", "D6", "E6", "F6", "G6", "A6", "B6",
]

static func stream_path(index: int) -> String:
	var row := clampi(floori(index / float(COLUMNS.size())), 0, OCTAVES.size() - 1)
	var column := clampi(index % COLUMNS.size(), 0, COLUMNS.size() - 1)
	return "res://Sounds/Walala/Instrument/piano_%s%d.wav" % [COLUMNS[column], OCTAVES[row]]

static func load_streams() -> Array[AudioStream]:
	var result: Array[AudioStream] = []
	for index in range(NOTE_NAMES.size()):
		var stream: AudioStream = load(stream_path(index))
		if stream == null:
			push_error("Missing instrument sample: " + stream_path(index))
		result.append(stream)
	return result
