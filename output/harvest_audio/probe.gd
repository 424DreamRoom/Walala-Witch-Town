extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var files: Array[String] = []
	var base := "res://Sounds/HarvestCandidates_20261011/SFX/"
	for kind in ["impactWood_medium", "impactMining"]:
		for i in range(3):
			files.append(base + "KenneyImpactSounds/Audio/%s_%03d.ogg" % [kind, i])
	for i in range(1, 16):
		files.append(base + "WaterSplashSlime/splash_%02d.ogg" % i)
	for i in range(1, 4):
		files.append(base + "WaterSplashSlime/bubble_%02d.ogg" % i)
	files.append("res://Sounds/Walala/Harvest/gather_01.ogg")
	var report := {}
	for path in files:
		var stream := AudioStreamOggVorbis.load_from_file(path)
		if stream == null: continue
		var playback := stream.instantiate_playback()
		playback.start()
		var samples: int = ceili(stream.get_length() * 44100)
		var peak := 0.0
		var energy := 0.0
		var first := -1
		var last := 0
		var count := 0
		while count < samples:
			var pcm := playback.mix_audio(1.0, mini(4096, samples - count))
			if pcm.is_empty(): break
			for frame in pcm:
				var amplitude: float = maxf(absf(frame.x), absf(frame.y))
				peak = maxf(peak, amplitude)
				energy += frame.length_squared() / 2.0
				if amplitude > 0.005:
					if first < 0: first = count
					last = count
				count += 1
		playback.stop()
		var info := {"seconds": stream.get_length(), "peak": peak, "rms_db": linear_to_db(sqrt(energy / samples)), "onset": first / 44100.0, "tail": stream.get_length() - last / 44100.0}
		report[path.get_file()] = info
		print(path.get_file(), " ", JSON.stringify(info))
	FileAccess.open("res://output/harvest_audio/candidate_metrics.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	quit()
