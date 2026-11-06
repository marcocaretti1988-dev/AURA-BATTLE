extends Control
## Menu principale + scelta del personaggio e della piazza.

var music: AudioStreamPlayer
var cards: Dictionary = {}
var venue_btn: OptionButton
var diff_btn: OptionButton
var bg: TextureRect
var venue_cycle := 0
var cycle_t := 0.0


func _ready() -> void:
	bg = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = load("res://assets/venues/milano.jpg")
	bg.modulate = Color(0.55, 0.55, 0.7)
	add_child(bg)

	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/music/menu.mp3")
	music.volume_db = 0.0 if GameData.music_on else -80.0
	add_child(music)
	music.play()

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	add_child(vb)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/logo.png")
	logo.custom_minimum_size = Vector2(0, 140)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(logo)

	# schede dei personaggi
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	for id in GameData.char_ids:
		var c := GameData.character(id)
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(150, 220)
		b.icon = load("res://assets/characters/%s_card.jpg" % id)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.text = c["name"]
		b.add_theme_color_override("font_color", Color(c["color"]))
		b.add_theme_font_size_override("font_size", 14)
		if not GameData.has_char(id):
			b.disabled = true
			b.text = c["name"] + "\n" + GameData.tr_text("BLOCCATO")
		b.pressed.connect(func():
			_select(id)
		)
		row.add_child(b)
		cards[id] = b

	# piazza e difficoltà
	var opts := HBoxContainer.new()
	opts.alignment = BoxContainer.ALIGNMENT_CENTER
	opts.add_theme_constant_override("separation", 16)
	vb.add_child(opts)
	venue_btn = OptionButton.new()
	venue_btn.add_item("TOUR D'ITALIA (una piazza per sfida)")
	venue_btn.set_item_metadata(0, "tour")
	var i := 1
	for v in GameData.venue_ids:
		var vd := GameData.venue(v)
		var rec: Dictionary = GameData.venue_records.get(v, {})
		venue_btn.add_item("%s - %s%s" % [vd["name"], vd["city"], ("   [%s %d]" % [rec["grade"], rec["score"]]) if not rec.is_empty() else ""])
		venue_btn.set_item_metadata(i, v)
		venue_btn.set_item_disabled(i, not GameData.has_venue(v))
		i += 1
	opts.add_child(venue_btn)
	diff_btn = OptionButton.new()
	for d in ["easy", "normal", "hard"]:
		diff_btn.add_item({"easy": "FACILE", "normal": "NORMALE", "hard": "DIFFICILE"}[d])
	diff_btn.select(["easy", "normal", "hard"].find(GameData.difficulty))
	opts.add_child(diff_btn)

	var play := Button.new()
	play.text = "ENTRA IN PIAZZA >"
	play.custom_minimum_size = Vector2(320, 64)
	play.add_theme_font_size_override("font_size", 24)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_start)
	vb.add_child(play)

	var rec := Label.new()
	rec.text = "RECORD: %d" % GameData.best_score
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(rec)

	_select(GameData.sel_char)


func _select(id: String) -> void:
	if not GameData.has_char(id):
		id = GameData.unlocked_chars[0]
	GameData.sel_char = id
	for k in cards:
		cards[k].button_pressed = (k == id)


func _process(dt: float) -> void:
	# la piazza dietro al menu cambia ogni 8 secondi
	cycle_t += dt
	if cycle_t > 8.0:
		cycle_t = 0.0
		venue_cycle = (venue_cycle + 1) % GameData.venue_ids.size()
		bg.texture = load("res://assets/venues/%s.jpg" % GameData.venue_ids[venue_cycle])


func _start() -> void:
	GameData.venue_sel = venue_btn.get_item_metadata(venue_btn.selected)
	GameData.difficulty = ["easy", "normal", "hard"][diff_btn.selected]
	GameData.save()
	GameData.start_tour()
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
