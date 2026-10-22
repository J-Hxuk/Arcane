extends AudioStreamPlayer
## Small original synthesized cues; no external audio assets.
var _cache: Dictionary = {}
func _exit_tree() -> void:
	stop()
	stream = null
	_cache.clear()
func cue(spell_id: String, effect: String) -> void:
	if not _cache.has(spell_id):
		var rate := 22050
		var count := 3307
		var pcm := PackedByteArray(); pcm.resize(count * 2)
		var pitch := 220.0 + float(absi(spell_id.hash()) % 480)
		for i in count:
			var t := float(i) / rate; var envelope := pow(1.0-float(i)/count, 2)
			var wave := sin(TAU*(pitch*t-300*t*t)) * 0.35
			if effect in ["barrier", "cone", "shockwave"]: wave += sin(i*1.719)*sin(i*0.713)*0.2
			pcm.encode_s16(i*2, roundi(wave*envelope*12000))
		var sound := AudioStreamWAV.new(); sound.format = AudioStreamWAV.FORMAT_16_BITS
		sound.mix_rate = rate; sound.data = pcm; _cache[spell_id] = sound
	stop() # Retire the previous playback before changing its stream during rapid experiments.
	stream = _cache[spell_id]; volume_db = -12; play()
