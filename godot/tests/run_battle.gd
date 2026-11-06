extends SceneTree
var t := 0.0
var b: Node
func _initialize() -> void:
	await process_frame
	var gd = root.get_node("GameData")
	gd.sel_char = "jester"
	gd.start_tour()
	change_scene_to_file("res://scenes/battle.tscn")
func _process(dt: float) -> bool:
	t += dt
	b = current_scene
	if b and b.has_method("on_move") and b.phase == "perform" and b.turn == "player":
		var n = b._nearest_note(b.conductor.beat())
		if n and absf(b.conductor.beat() - n.beat) * b.conductor.beat_len < 0.03:
			b.on_move(n.m)
			if n.m2 != "": b.on_move(n.m2)
	if int(t * 2) != int((t - dt) * 2) and b and "phase" in b:
		print("t=%.1f phase=%s turn=%s round=%d P=%d O=%d notes=%d beat=%.1f" % [t, b.phase, b.turn, b.round_i, b.P.score if b.P else -1, b.O.score if b.O else -1, b.notes.size(), b.conductor.beat() if b.conductor else -1])
	return t > 40.0
