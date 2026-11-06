extends SceneTree
var t := 0.0
func _initialize() -> void:
	await process_frame
	change_scene_to_file("res://scenes/menu.tscn")
func _process(dt: float) -> bool:
	t += dt
	if t > 2.0:
		root.get_texture().get_image().save_png("/tmp/claude-0/gmenu.png")
		return true
	return false
