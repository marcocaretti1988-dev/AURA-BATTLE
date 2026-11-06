class_name Conductor
extends AudioStreamPlayer
## Orologio musicale: suona la canzone e dice in che battito siamo.
## I battiti sono tempi (secondi) misurati sul file audio (data/game_data.json -> songs).
## Dopo l'intro (battito 32) la canzone gira in loop sulle battute intere, e la griglia
## dei battiti continua senza salti (come nella versione HTML).

var beats: PackedFloat64Array = PackedFloat64Array()
var bpm := 120.0
var beat_len := 0.5
var loop_start_k := 0     # indice del battito dove riparte il loop
var loop_end_k := 0       # indice del battito dove finisce il loop
var loops := 0            # quante volte ha già girato
var fallback_t0 := 0.0    # se non c'è canzone: orologio a bpm fisso


func play_song(song_id: String) -> void:
	var s: Dictionary = GameData.data["songs"][song_id]
	stream = load("res://assets/music/" + String(s["file"]))
	beats = PackedFloat64Array(s["beats"])
	bpm = float(s["bpm"])
	beat_len = 60.0 / bpm
	loop_start_k = mini(32, beats.size() - 9)
	loop_end_k = loop_start_k
	var dur: float = stream.get_length()
	while loop_end_k + 4 < beats.size() and beats[loop_end_k + 4] < dur - 1.2:
		loop_end_k += 4
	loops = 0
	volume_db = 0.0 if GameData.music_on else -80.0
	play()


func play_bpm(new_bpm: float) -> void:
	stop()
	beats = PackedFloat64Array()
	bpm = new_bpm
	beat_len = 60.0 / bpm
	fallback_t0 = Time.get_ticks_msec() / 1000.0


## tempo della canzone in secondi, compensato per la latenza audio
func song_time() -> float:
	if beats.is_empty() or not playing:
		return Time.get_ticks_msec() / 1000.0 - fallback_t0
	var lat := GameData.audio_offset if GameData.audio_offset >= 0.0 else AudioServer.get_output_latency()
	return get_playback_position() + AudioServer.get_time_since_last_mix() - lat


func _process(_dt: float) -> void:
	# loop sulle battute intere
	if playing and not beats.is_empty() and loop_end_k - loop_start_k >= 16:
		if get_playback_position() >= beats[loop_end_k]:
			seek(beats[loop_start_k] + (get_playback_position() - beats[loop_end_k]))
			loops += 1


## battito attuale (con decimali). 0 = primo battito della canzone
func beat() -> float:
	var t := song_time()
	if beats.is_empty():
		return t / beat_len
	var extra := float(loops * (loop_end_k - loop_start_k))
	if t <= beats[0]:
		return (t - beats[0]) / beat_len + extra
	var i := beats.bsearch(t) - 1
	if i >= beats.size() - 1:
		return float(beats.size() - 1) + (t - beats[-1]) / beat_len + extra
	return float(i) + (t - beats[i]) / (beats[i + 1] - beats[i]) + extra


## errore in secondi rispetto al battito più vicino (negativo = in anticipo)
func error_to(target_beat: float) -> float:
	return (beat() - target_beat) * beat_len
