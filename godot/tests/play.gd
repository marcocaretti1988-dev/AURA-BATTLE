extends SceneTree
## prova automatica: godot -s tests/play.gd -- <modalita> <secondi> [cartella_screenshot]
var t := 0.0
var mode := "tour"
var dur := 20.0
var out := ""
var next_shot := 2.0
var n := 0
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: mode = a[0]
	if a.size() > 1: dur = float(a[1])
	if a.size() > 2: out = a[2]
	await process_frame
	var gd = root.get_node("GameData")
	gd.sel_char = "jester"
	gd.tutorial_done = true
	gd.start_mode(mode)
	change_scene_to_file("res://scenes/battle.tscn")
func _process(dt: float) -> bool:
	t += dt
	var b = current_scene
	if b and b.has_method("on_move") and b.phase == "perform" and b.turn == "player":
		if mode == "challenge":
			if not b.ch.is_empty() and b.ch["phase"] == "play":
				var sb: float = b.ch["slot_beats"]
				var rel: float = (b.conductor.beat() - b.ch["play_beat"]) / sb
				var idx := roundi(rel)
				if absf(rel - idx) * sb * b.conductor.beat_len < 0.03 and idx >= 0 and idx < b.ch["seq"].size() and b.ch["results"][idx] == null:
					b.on_move(b.ch["seq"][idx])
		else:
			var nn = b._nearest_note(b.conductor.beat())
			if nn and absf(b.conductor.beat() - nn.beat) * b.conductor.beat_len < 0.03:
				b.on_move(nn.m)
				if nn.m2 != "": b.on_move(nn.m2)
				if nn.length > 0: b.held[nn.m] = true
			for k in b.held.keys():
				var still := false
				for x in b.notes:
					if x.state == 4 and x.m == k: still = true
				if not still: b.held.erase(k)
			if mode == "tutorial":
				if b.P.charges > 0 and b._tut_steps()[b.tut_i]["kind"] == "combo": b.on_move("combo")
				if b.P.meter >= 100 and b._tut_steps()[b.tut_i]["kind"] == "special" and b.P.queue.is_empty(): b.on_move("special")
	if out != "" and t >= next_shot:
		root.get_texture().get_image().save_png("%s/%s_%02d.png" % [out, mode, n])
		n += 1
		next_shot += dur / 6.0
	if int(t) != int(t - dt) and b and "phase" in b:
		print("t=%d phase=%s P=%d tut=%d ch=%s" % [int(t), b.phase, b.P.total if b.P else -1, b.tut_i, str(b.ch.get("level", "")) + "/" + str(b.ch.get("lives", ""))])
	return t > dur
