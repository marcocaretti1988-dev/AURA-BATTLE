extends Control
## Menu principale e schermate: scelta personaggio e piazza, galleria personaggi,
## impostazioni, sincronizzazione audio, come si gioca.
## Dietro c'è la piazza in 3D con il personaggio scelto che balla.

var stage: Stage
var music: AudioStreamPlayer
var dancers := {}
var screen: Control
var ui: CanvasLayer
var cycle_t := 0.0
var venue_cycle := 0
var beat_t := 0.0
var gallery_id := ""
var calib := {}


func _ready() -> void:
	stage = Stage.new()
	add_child(stage)
	venue_cycle = randi() % GameData.unlocked_venues.size()
	stage.set_venue(GameData.unlocked_venues[venue_cycle])
	stage.hype = 55
	for id in GameData.char_ids:
		var d := Dancer.new()
		stage.world.add_child(d)
		d.setup(id)
		d.visible = false
		dancers[id] = d
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/music/menu.mp3")
	music.volume_db = 0.0 if GameData.music_on else -80.0
	music.finished.connect(func(): music.play())
	add_child(music)
	music.play()
	ui = CanvasLayer.new()
	add_child(ui)
	if not GameData.has_char(GameData.sel_char):
		GameData.sel_char = GameData.unlocked_chars[0]
	show_main()


# ------------------------------------------------------------------ utilità
func _clear() -> void:
	if screen:
		screen.queue_free()
	screen = Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(screen)
	calib = {}
	# console in basso al centro (come nella battle), su tutte le schermate
	var console := Panel.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.024, 0.016, 0.07, 0.88)
	csb.set_corner_radius_all(22)
	csb.shadow_color = Color(0.024, 0.016, 0.07, 0.6)
	csb.shadow_size = 24
	console.add_theme_stylebox_override("panel", csb)
	console.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box(console, 0.5, 1, 0.5, 1, -330, -190, 330, 40)
	screen.add_child(console)


func _box(c: Control, al: float, at: float, ar: float, ab: float, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b


func _panel(l: float, t: float, r: float, b: float) -> VBoxContainer:
	var p := UI.panel()
	_box(p, 0.5, 0.5, 0.5, 0.5, l, t, r, b)
	screen.add_child(p)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	sc.add_child(vb)
	return vb


## mostra in piazza i personaggi: il primo grande al centro, gli altri dietro
func _show_dancers(main: String, others := true) -> void:
	var k := 0
	for id in dancers:
		var d: Dancer = dancers[id]
		if id == main:
			d.visible = true
			d.position = Vector3(1.3, 0, 0.6)
			d.rotation.y = -0.25
			if d.anim_state != "dance" and d.anim_state != "gallery":
				d.play_state("dance")
		elif others and GameData.has_char(id) and k < 4:
			d.visible = true
			d.position = Vector3([-0.4, 3.0, -1.6, 4.0][k], 0, -1.6 - (k % 2) * 0.6)
			d.rotation.y = 0.2
			if d.anim_state != "menu":
				d.play_state("menu")
			k += 1
		else:
			d.visible = false
	stage.focus = dancers[main]
	stage.focus_col = GameData.glow_of(main)
	stage.focus_meter = 0.35


func _process(dt: float) -> void:
	beat_t += dt
	if beat_t > 0.5:
		beat_t = 0.0
		stage.pulse = 1.0
	cycle_t += dt
	if cycle_t > 9.0 and gallery_id == "":
		cycle_t = 0.0
		venue_cycle = (venue_cycle + 1) % GameData.unlocked_venues.size()
		stage.set_venue(GameData.unlocked_venues[venue_cycle])
	if not calib.is_empty():
		_calib_process()


# ------------------------------------------------------------------ menu principale
func show_main() -> void:
	_clear()
	gallery_id = ""
	_show_dancers(GameData.sel_char)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_box(logo, 0, 0, 0, 0, 40, 20, 440, 200)
	screen.add_child(logo)
	var tag := UI.label("CONQUISTA LA PIAZZA. DIVENTA AURA LEGEND.", 9, Color(0.85, 0.8, 1.0))
	_box(tag, 0, 0, 0, 0, 20, 205, 460, 225)
	screen.add_child(tag)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_box(grid, 0, 0, 0, 0, 40, 240, 440, 560)
	screen.add_child(grid)
	var items := [["PLAY", _play_tour, true], ["FREE STYLE", func(): show_select("free"), false],
		["AURA CHALLENGE", func(): show_select("challenge"), false], ["CHARACTERS", show_gallery, false],
		["SETTINGS", show_settings, false], ["HOW TO PLAY", show_howto, false],
		["TUTORIAL", func(): _go("tutorial"), false], [("LINGUA: ITALIANO" if GameData.lang == "it" else "LANGUAGE: ENGLISH"), _toggle_lang, false]]
	for it in items:
		var b := UI.button(it[0], it[1], it[2], Vector2(195, 50), 11)
		grid.add_child(b)
	var cv := VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 12)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box(cv, 0.5, 1, 0.5, 1, -310, -175, 310, -15)
	screen.add_child(cv)
	cv.add_child(UI.label(GameData.character(GameData.sel_char)["name"], 18, GameData.color_of(GameData.sel_char)))
	cv.add_child(UI.label("RECORD: %d" % GameData.best_score, 11, Color(0.85, 0.8, 1.0)))


func _play_tour() -> void:
	if not GameData.tutorial_done:
		_go("tutorial")
	else:
		show_select("tour")


func _toggle_lang() -> void:
	GameData.lang = "en" if GameData.lang == "it" else "it"
	GameData.save()
	show_main()


func _go(m: String) -> void:
	GameData.start_mode(m)
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


# ------------------------------------------------------------------ scelta personaggio e piazza
func show_select(m: String) -> void:
	_clear()
	var title: String = {"tour": "QUICK BATTLE - SCEGLI", "free": "FREE STYLE - SCEGLI", "challenge": "AURA CHALLENGE - SCEGLI"}[m]
	var vb := _panel(-600, -330, 600, 330)
	vb.add_child(UI.label(title, 16, UI.COL_GOLD))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var info := UI.label("", 9, Color(0.85, 0.85, 1.0))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cards := {}
	var pick := func(id: String):
		GameData.sel_char = id
		for k in cards:
			cards[k].button_pressed = k == id
		var c := GameData.character(id)
		info.text = "%s\n%s" % [UI.t(c["desc"]), UI.t(c["style"])]
		_show_dancers(id, false)
	for id in GameData.char_ids:
		var c := GameData.character(id)
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(170, 210)
		b.icon = load("res://assets/characters/%s_card.jpg" % id)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.text = c["name"]
		b.add_theme_color_override("font_color", Color(c["color"]))
		b.add_theme_font_size_override("font_size", UI.fs_k(9))
		if not GameData.has_char(id):
			b.disabled = true
			b.text = c["name"] + "\n" + UI.t("BLOCCATO")
			b.tooltip_text = UI.t("BATTILO NEL TOUR PER SBLOCCARLO")
		b.pressed.connect(func():
			UI.sfx("click")
			pick.call(id)
		)
		row.add_child(b)
		cards[id] = b
	vb.add_child(info)
	var opts := HBoxContainer.new()
	opts.alignment = BoxContainer.ALIGNMENT_CENTER
	opts.add_theme_constant_override("separation", 12)
	vb.add_child(opts)
	var venue_btn := OptionButton.new()
	venue_btn.add_item(UI.t("TOUR D'ITALIA") + " - " + UI.t("UNA PIAZZA PER SFIDA") if m == "tour" else UI.t("PIAZZA A CASO"))
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
	var diff_btn := OptionButton.new()
	for d in ["FACILE", "NORMALE", "DIFFICILE"]:
		diff_btn.add_item(UI.t(d))
	diff_btn.select(["easy", "normal", "hard"].find(GameData.difficulty))
	opts.add_child(diff_btn)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 12)
	vb.add_child(bottom)
	bottom.add_child(UI.button("< MENU", show_main))
	bottom.add_child(UI.button("ENTRA IN PIAZZA >", func():
		GameData.venue_sel = venue_btn.get_item_metadata(venue_btn.selected)
		GameData.difficulty = ["easy", "normal", "hard"][diff_btn.selected]
		GameData.save()
		_go(m)
	, true, Vector2(260, 50)))
	pick.call(GameData.sel_char)


# ------------------------------------------------------------------ galleria personaggi
func show_gallery() -> void:
	_clear()
	if gallery_id == "" or not GameData.has_char(gallery_id):
		gallery_id = GameData.sel_char
	var d: Dancer = dancers[gallery_id]
	_show_dancers(gallery_id, false)
	d.position = Vector3(0.9, 0, 1.0)
	var c := GameData.character(gallery_id)
	var p := UI.panel()
	_box(p, 0, 0, 0, 1, 16, 16, 520, -16)
	screen.add_child(p)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	sc.add_child(vb)
	vb.add_child(UI.label("CHARACTERS", 16, UI.COL_GOLD))
	var tabs := GridContainer.new()
	tabs.columns = 2
	vb.add_child(tabs)
	for id in GameData.char_ids:
		var b := UI.button(GameData.character(id)["name"], func():
			gallery_id = id
			show_gallery()
		, id == gallery_id, Vector2(230, 40), 9)
		b.disabled = not GameData.has_char(id)
		tabs.add_child(b)
	var info := UI.label("%s\n%s\n%s\n%s: %d" % [c["name"], UI.t(c["desc"]), UI.t(c["style"]), UI.t("BALLI"), d.clip_names().size()], 9, Color(0.9, 0.9, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info)
	var clips := GridContainer.new()
	clips.columns = 2
	vb.add_child(clips)
	for clip in d.clip_names():
		clips.add_child(UI.button(clip.replace("_", " ").to_upper(), func(): d.play_clip(clip), false, Vector2(230, 40), 8))
	vb.add_child(UI.button("< MENU", show_main))


# ------------------------------------------------------------------ impostazioni
func show_settings() -> void:
	_clear()
	var vb := _panel(-300, -300, 300, 300)
	vb.add_child(UI.label("SETTINGS", 16, UI.COL_GOLD))
	var rows := [
		["MUSICA", func(): return "ON" if GameData.music_on else "OFF", func():
			GameData.music_on = not GameData.music_on
			music.volume_db = 0.0 if GameData.music_on else -80.0],
		["EFFETTI SONORI", func(): return "ON" if GameData.sfx_on else "OFF", func(): GameData.sfx_on = not GameData.sfx_on],
		["ANNUNCIATORE", func(): return "ON" if GameData.voice_on else "OFF", func():
			GameData.voice_on = not GameData.voice_on
			if GameData.voice_on:
				UI.say("Aura battle!", true)],
		["DIFFICOLTA'", func(): return UI.t({"easy": "FACILE", "normal": "NORMALE", "hard": "DIFFICILE"}[GameData.difficulty]), func():
			GameData.difficulty = {"easy": "normal", "normal": "hard", "hard": "easy"}[GameData.difficulty]],
		["PIAZZE", func(): return UI.t({"auto": "AUTO (ORARIO)", "night": "NOTTE", "day": "GIORNO"}[GameData.night_mode]), func():
			GameData.night_mode = {"auto": "night", "night": "day", "day": "auto"}[GameData.night_mode]
			stage.set_venue(stage.venue)],
		["LINGUA", func(): return "ITALIANO" if GameData.lang == "it" else "ENGLISH", func():
			GameData.lang = "en" if GameData.lang == "it" else "it"
			show_settings.call_deferred()],
	]
	for r in rows:
		var h := HBoxContainer.new()
		var l := UI.label(r[0], 10, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var b := Button.new()
		b.text = r[1].call()
		b.custom_minimum_size = Vector2(190, 40)
		b.add_theme_font_size_override("font_size", UI.fs_k(10))
		var get_txt: Callable = r[1]
		var act: Callable = r[2]
		b.pressed.connect(func():
			UI.sfx("click")
			act.call()
			GameData.save()
			b.text = get_txt.call()
		)
		h.add_child(b)
		vb.add_child(h)
	var hc := HBoxContainer.new()
	var lc := UI.label("SINCRONIZZA AUDIO", 10, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	lc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hc.add_child(lc)
	hc.add_child(UI.button("CALIBRA", show_calib, false, Vector2(190, 40), 10))
	vb.add_child(hc)
	vb.add_child(UI.button("PRIVACY", func(): OS.shell_open("https://marcocaretti1988-dev.github.io/AURA-BATTLE/web/privacy.html"), false, Vector2(0, 36), 9))
	vb.add_child(UI.button("< MENU", show_main))


# ------------------------------------------------------------------ calibrazione audio
func show_calib() -> void:
	_clear()
	var vb := _panel(-320, -260, 320, 260)
	vb.add_child(UI.label("SINCRONIZZA AUDIO", 16, UI.COL_GOLD))
	var t := UI.label("Con le cuffie Bluetooth il suono arriva in ritardo: questa prova lo misura e corregge il tempo del gioco.", 9)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(t)
	var t2 := UI.label("Tocca lo schermo (o premi SPAZIO) a tempo con il click, per 8 volte.", 9, UI.COL_GOLD)
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(t2)
	var pad := Button.new()
	pad.text = "●"
	pad.custom_minimum_size = Vector2(0, 120)
	pad.add_theme_font_size_override("font_size", 48)
	vb.add_child(pad)
	var count := UI.label("0 / 8", 12)
	vb.add_child(count)
	var res := UI.label(UI.t("RITARDO MISURATO") + ": " + ("AUTO" if GameData.audio_offset < 0 else "%d ms" % int(GameData.audio_offset * 1000)), 10, UI.COL_GOLD)
	vb.add_child(res)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var save_b := UI.button("SALVA", func():
		GameData.audio_offset = calib.get("val", -1.0)
		GameData.save()
		show_settings()
	, true)
	save_b.visible = false
	row.add_child(UI.button("INIZIA", func():
		music.volume_db = -80.0
		calib = {"t0": Time.get_ticks_msec() / 1000.0 + 0.6, "bl": 0.6, "taps": [], "next": 0, "pad": pad, "count": count, "res": res, "save": save_b}
		save_b.visible = false
	))
	row.add_child(save_b)
	row.add_child(UI.button("AZZERA", func():
		GameData.audio_offset = -1.0
		GameData.save()
		res.text = UI.t("RITARDO MISURATO") + ": AUTO"
	))
	row.add_child(UI.button("< SETTINGS", func():
		music.volume_db = 0.0 if GameData.music_on else -80.0
		show_settings()
	))
	pad.button_down.connect(_calib_tap)


func _calib_process() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var k: int = calib["next"]
	if k < 14 and now >= calib["t0"] + k * calib["bl"]:
		UI.sfx("tick", 0.0, 1.0 if k % 4 else 1.5)
		calib["next"] = k + 1
	var ph := fposmod((now - AudioServer.get_output_latency() - calib["t0"]) / calib["bl"], 1.0)
	(calib["pad"] as Button).modulate = Color(1, 1, 1).lerp(Color(1.8, 1.5, 2.2), pow(1.0 - ph, 4))
	if now > calib["t0"] + 14 * calib["bl"] + 0.4 or calib["taps"].size() >= 8:
		_calib_finish()


func _calib_tap() -> void:
	if calib.is_empty() or not calib.has("t0"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var best := INF
	for i in 14:
		var c: float = calib["t0"] + i * calib["bl"]
		if absf(now - c) < absf(best):
			best = now - c
	if absf(best) < 0.45:
		calib["taps"].append(best)
	(calib["count"] as Label).text = "%d / 8" % mini(8, calib["taps"].size())


func _calib_finish() -> void:
	var taps: Array = calib["taps"]
	var res: Label = calib["res"]
	var save_b: Button = calib["save"]
	calib = {}
	music.volume_db = 0.0 if GameData.music_on else -80.0
	if taps.size() < 4:
		res.text = "?"
		return
	taps.sort()
	var v := clampf(taps[taps.size() / 2], 0.0, 0.4)
	calib = {"val": v}
	res.text = UI.t("RITARDO MISURATO") + ": %d ms" % int(v * 1000)
	save_b.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if calib.has("t0") and event.is_action_pressed("move_special", false):
		_calib_tap()


# ------------------------------------------------------------------ come si gioca
func show_howto() -> void:
	_clear()
	var vb := _panel(-420, -300, 420, 300)
	vb.add_child(UI.label("HOW TO PLAY", 16, UI.COL_GOLD))
	var lines := [
		"Le note scorrono nella pista in basso verso il cerchio bianco, ognuna con l'icona e il colore della sua mossa: premi quella mossa quando la nota entra nel cerchio. Sotto, la tessera e il pulsante della prossima mossa si illuminano.",
		"PERFECT / GREAT / GOOD danno piu' Aura Points, OFF BEAT dimezza.",
		"NOTE SPECIALI: con la coda = tienila premuta fino alla fine; doppia (due icone) = premi le due mosse insieme (vale x2); bordo d'oro = vale x3.",
		"Alterna mosse diverse per salire di COMBO. Ripetere la stessa mossa rende sempre meno.",
		"4 mosse diverse pulite di fila = CLEAN COMBO x2.",
		"Ogni 3 combo guadagni una carica COMBO: esegue in automatico le tue ultime 3 mosse.",
		"La barra AURA si riempie coi punti: a barra piena usa SPECIAL, meglio se sul primo beat della battuta (bonus MAX AURA).",
		"Il pubblico caldo moltiplica i punti, quello annoiato li riduce.",
		"QUICK BATTLE: 3 round (Ingresso, Esibizione, Posa Finale) contro i 2 rivali. Chi vince 2 round passa.",
		"TASTIERA: 1-6 mosse, C combo, SPAZIO special, ESC pausa"]
	for ln in lines:
		var l := UI.label("● " + ln, 9, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(l)
	vb.add_child(UI.button("< MENU", show_main))
