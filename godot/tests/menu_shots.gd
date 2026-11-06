extends SceneTree
## screenshot di tutte le schermate del menu: godot -s tests/menu_shots.gd -- <cartella>
var t := 0.0
var out := "/tmp"
var steps := ["show_main", "show_select_tour", "show_gallery", "show_settings", "show_calib", "show_howto"]
var i := 0
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	await process_frame
	change_scene_to_file("res://scenes/menu.tscn")
func _process(dt: float) -> bool:
	t += dt
	var m = current_scene
	if t > 2.5 + i * 2.0 and m and m.has_method("show_main"):
		if i > 0:
			root.get_texture().get_image().save_png("%s/menu_%d_%s.png" % [out, i - 1, steps[i - 1]])
		if i >= steps.size(): return true
		var s: String = steps[i]
		if s == "show_select_tour": m.show_select("tour")
		else: m.call(s)
		i += 1
	return false
