extends RefCounted
## Licensed human syllables. Explicit preloads also retain the clips in exports.
const POOLS := {
	"alex": [preload("res://Sounds/Walala/Dialogue/Blips/alex_01.wav"), preload("res://Sounds/Walala/Dialogue/Blips/alex_02.wav"), preload("res://Sounds/Walala/Dialogue/Blips/alex_03.wav")],
	"ian": [preload("res://Sounds/Walala/Dialogue/Blips/ian_01.wav"), preload("res://Sounds/Walala/Dialogue/Blips/ian_02.wav"), preload("res://Sounds/Walala/Dialogue/Blips/ian_03.wav")],
	"sean": [preload("res://Sounds/Walala/Dialogue/Blips/sean_01.wav"), preload("res://Sounds/Walala/Dialogue/Blips/sean_02.wav"), preload("res://Sounds/Walala/Dialogue/Blips/sean_03.wav")],
	"karen": [preload("res://Sounds/Walala/Dialogue/Blips/karen_01.wav"), preload("res://Sounds/Walala/Dialogue/Blips/karen_02.wav"), preload("res://Sounds/Walala/Dialogue/Blips/karen_03.wav")],
	"meghan": [preload("res://Sounds/Walala/Dialogue/Blips/meghan_01.wav"), preload("res://Sounds/Walala/Dialogue/Blips/meghan_02.wav"), preload("res://Sounds/Walala/Dialogue/Blips/meghan_03.wav")],
}
const PROFILES := {
	"walala-witch": ["meghan", 1.08], "yingluo": ["karen", 1.0],
	"mori": ["karen", 0.94], "ember": ["sean", 0.94],
	"nagi": ["ian", 1.0], "lumi": ["meghan", 0.96],
	"aster": ["karen", 1.10], "toma": ["alex", 1.0],
	"pip": ["alex", 1.16], "reed": ["ian", 0.94],
	"yuki": ["meghan", 1.03], "orla": ["sean", 1.03],
}
const GAIN_DB := -8.0
const MIN_INTERVAL_USEC := 125000

static func profile(speaker_id: String) -> Array:
	var id := speaker_id.get_file().get_basename().to_lower()
	if PROFILES.has(id): return PROFILES[id]
	# Unknown speakers still get a repeatable voice; never hash translated UI text.
	var actors := ["meghan", "karen", "alex", "ian", "sean"]
	return [actors[absi(id.hash()) % actors.size()], 1.0]
