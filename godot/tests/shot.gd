extends SceneTree
var t := 0.0
var shots := [3.0, 9.0, 14.0]
func _initialize() -> void:
	await process_frame
	var gd = root.get_node("GameData")
	gd.sel_char = "titan"
	gd.start_tour()
	change_scene_to_file("res://scenes/battle.tscn")
func _process(dt: float) -> bool:
	t += dt
	var b = current_scene
	if b and b.has_method("on_move") and b.phase == "perform" and b.turn == "player":
		var n = b._nearest_note(b.conductor.beat())
		if n and absf(b.conductor.beat() - n.beat) * b.conductor.beat_len < 0.03:
			b.on_move(n.m)
	if not shots.is_empty() and t >= shots[0]:
		var img := root.get_texture().get_image()
		img.save_png("/tmp/claude-0/gshot_%d.png" % int(shots[0]))
		shots.pop_front()
	return t > 15.0
