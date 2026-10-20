extends SceneTree

## Generate the small, tonal UI cue set used by the current interface mix.
##
## The files are deliberately kept outside MyArt/.  Each cue is a short,
## deterministic 44.1 kHz PCM WAV with a softened attack and release, so the
## UI has one coherent musical colour instead of mixing unrelated click packs.

const RATE := 44100
const OUT_DIR := "res://Sounds/Walala/UI/Polished"
const TAU_F := TAU

func _initialize() -> void:
	_generate_all()
	quit()

func _generate_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_write("hover.wav", _cue_hover())
	_write("click.wav", _cue_click())
	_write("open.wav", _cue_open())
	_write("close.wav", _cue_close())
	_write("confirm.wav", _cue_confirm())
	_write("error.wav", _cue_error())
	_write("toggle.wav", _cue_toggle())
	_write("slider.wav", _cue_slider())

func _blank(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(ceil(seconds * RATE)))
	return samples

func _add_tone(samples: PackedFloat32Array, start: float, duration: float,
		frequency: float, amplitude: float, brightness: float = 0.18) -> void:
	var first := maxi(0, int(floor(start * RATE)))
	var last := mini(samples.size(), int(ceil((start + duration) * RATE)))
	for i in range(first, last):
		var t := float(i - first) / RATE
		var n := t / duration
		var attack := minf(1.0, t / 0.006)
		var release := minf(1.0, maxf(0.0, duration - t) / 0.018)
		var envelope := attack * release * exp(-3.5 * n)
		var fundamental := sin(TAU_F * frequency * t)
		var second := sin(TAU_F * frequency * 2.0 * t + 0.14)
		var third := sin(TAU_F * frequency * 3.0 * t + 0.31)
		samples[i] += amplitude * envelope * (fundamental + brightness * second + brightness * 0.34 * third)

func _add_soft_tick(samples: PackedFloat32Array, start: float, frequency: float, amplitude: float) -> void:
	_add_tone(samples, start, 0.055, frequency, amplitude, 0.12)
	_add_tone(samples, start + 0.004, 0.035, frequency * 2.01, amplitude * 0.18, 0.08)

func _cue_hover() -> PackedFloat32Array:
	var result := _blank(0.095)
	_add_tone(result, 0.0, 0.09, 1174.66, 0.30, 0.12)
	_add_tone(result, 0.002, 0.065, 2349.32, 0.07, 0.08)
	return result

func _cue_click() -> PackedFloat32Array:
	var result := _blank(0.13)
	_add_tone(result, 0.0, 0.115, 587.33, 0.43, 0.20)
	_add_tone(result, 0.004, 0.09, 880.0, 0.16, 0.13)
	return result

func _cue_open() -> PackedFloat32Array:
	var result := _blank(0.29)
	_add_tone(result, 0.0, 0.19, 523.25, 0.28, 0.18)
	_add_tone(result, 0.065, 0.19, 659.25, 0.25, 0.18)
	_add_tone(result, 0.13, 0.19, 783.99, 0.22, 0.18)
	return result

func _cue_close() -> PackedFloat32Array:
	var result := _blank(0.29)
	_add_tone(result, 0.0, 0.19, 783.99, 0.25, 0.18)
	_add_tone(result, 0.065, 0.19, 659.25, 0.23, 0.18)
	_add_tone(result, 0.13, 0.19, 523.25, 0.20, 0.18)
	return result

func _cue_confirm() -> PackedFloat32Array:
	var result := _blank(0.38)
	_add_tone(result, 0.0, 0.28, 261.63, 0.18, 0.14)
	_add_tone(result, 0.0, 0.22, 523.25, 0.25, 0.18)
	_add_tone(result, 0.075, 0.22, 659.25, 0.24, 0.18)
	_add_tone(result, 0.15, 0.23, 783.99, 0.23, 0.18)
	_add_tone(result, 0.225, 0.29, 1046.50, 0.21, 0.20)
	return result

func _cue_error() -> PackedFloat32Array:
	var result := _blank(0.28)
	_add_tone(result, 0.0, 0.17, 392.0, 0.28, 0.20)
	_add_tone(result, 0.085, 0.18, 293.66, 0.25, 0.20)
	return result

func _cue_toggle() -> PackedFloat32Array:
	var result := _blank(0.18)
	_add_tone(result, 0.0, 0.12, 659.25, 0.30, 0.16)
	_add_tone(result, 0.045, 0.13, 987.77, 0.27, 0.16)
	return result

func _cue_slider() -> PackedFloat32Array:
	var result := _blank(0.075)
	_add_soft_tick(result, 0.0, 1318.51, 0.23)
	return result

func _write(file_name: String, samples: PackedFloat32Array) -> void:
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i in samples.size():
		var sample := clampf(samples[i], -0.92, 0.92)
		pcm.encode_s16(i * 2, int(round(sample * 32767.0)))
	var header := PackedByteArray()
	header.resize(44)
	header.encode_u32(0, 0x46464952) # RIFF
	header.encode_u32(4, 36 + pcm.size())
	header.encode_u32(8, 0x45564157) # WAVE
	header.encode_u32(12, 0x20746D66) # fmt 
	header.encode_u32(16, 16)
	header.encode_u16(20, 1) # PCM
	header.encode_u16(22, 1) # mono
	header.encode_u32(24, RATE)
	header.encode_u32(28, RATE * 2)
	header.encode_u16(32, 2)
	header.encode_u16(34, 16)
	header.encode_u32(36, 0x61746164) # data
	header.encode_u32(40, pcm.size())
	var file := FileAccess.open(OUT_DIR + "/" + file_name, FileAccess.WRITE)
	file.store_buffer(header)
	file.store_buffer(pcm)
	file.close()
