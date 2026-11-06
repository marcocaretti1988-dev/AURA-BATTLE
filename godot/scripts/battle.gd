extends Control
## AURA BATTLE - la sfida in piazza.
## Modalità (GameData.mode):
##  - "tour": Tour d'Italia, 3 round (Ingresso, Esibizione, Posa Finale) al meglio di 3 contro l'IA
##  - "free": Free Style, balli liberi sulle note, la pista accelera ogni 10 note prese
##  - "tutorial": Free Style guidato in 8 passi
##  - "challenge": Aura Challenge, memorizza la sequenza di mosse e ripetila a tempo

const FLOOR_Y := 0.0
const MOVE_LABELS := {"dance": "DANCE", "gesture": "GESTURE", "walk": "MODEL\nWALK", "mewing": "MEWING",
	"aura": "AURA\nPOSE", "celebrate": "CELE-\nBRATE", "combo": "COMBO", "special": "SPECIAL"}
const ANIM_OF := {"dance": "dance", "walk": "walk", "mewing": "mewing", "aura": "aura", "celebrate": "win", "special": "aura"}
const CH_MOVES := ["dance", "gesture", "walk", "mewing", "aura", "celebrate"]

class Note:
	var beat := 0.0
	var m := ""
	var m2 := ""          # seconda mossa (nota doppia)
	var state := 0        # 0 attesa, 1 presa, 2 mancata, 3 saltata, 4 tenuta, 5 rilasciata
	var t := 0.0
	var length := 0.0     # nota lunga (battiti)
	var gold := false
	var got := {}

class Perf:
	var id := ""
	var dancer: Dancer
	var is_player := false
	var score := 0
	var total := 0
	var combo := 0
	var best_combo := 0
	var combo_steps := 0
	var charges := 0
	var clean_run := 0
	var meter := 0.0
	var last_move := ""
	var rep := 0
	var last_q := 0
	var gesture_alt := false
	var busy_until := -999.0
	var linger_until := -999.0
	var home := Vector3.ZERO
	var target := Vector3.ZERO
	var walk_dir := 1.0
	var ai_beat := -1.0
	var ai_move := ""
	var ai_err := 0.0
	var queue: Array = []

var mode := "tour"
var stage: Stage
var conductor: Conductor
var P: Perf
var O: Perf
var active: Perf
var venue := ""
var round_i := 0
var round_wins := [0, 0]
var turn := "player"
var phase := "vs"         # vs -> intro -> perform -> gap -> result -> end
var paused := false
var timer := 0.0
var start_beat := 0.0
var notes: Array = []
var next_note_beat := 0.0
var last_note_move := ""
var lane_ahead := 10.0
var hype := 50.0
var stats := {"p": 0, "g": 0, "ok": 0, "miss": 0}
var held := {}
var last_beat_i := -999
var misses_t: Array = []
var last_close := 0.0
var free_hits := 0
var free_lvl := 0
# tutorial
var tut_i := 0
var tut_got := 0
# challenge
var ch := {}

# UI
var ui: CanvasLayer
var root_ui: Control
var lane: NoteLane
var lbl_p: Label
var lbl_o: Label
var lbl_round: Label
var lbl_banner: Label
var bar_p: ProgressBar
var box_o: PanelContainer
var move_btns := {}
var tut_box: PanelContainer
var tut_lbl: Label
var seq_bar: HBoxContainer
var overlay: Control


func _ready() -> void:
	mode = GameData.mode
	venue = GameData.current_venue()
	stage = Stage.new()
	add_child(stage)
	stage.set_venue(venue)
	_build_ui()
	conductor = Conductor.new()
	add_child(conductor)
	conductor.play_song(GameData.song_for_venue(venue))
	P = _make_perf(GameData.sel_char, true)
	if mode == "tour":
		O = _make_perf(GameData.current_opp(), false)
	stage.hype = hype
	if mode == "tour":
		box_o.visible = true
		await _show_vs()
		_start_round()
	else:
		box_o.visible = false
		P.target = Vector3.ZERO
		P.home = P.target
		active = P
		_start_solo()


func _make_perf(id: String, is_player: bool) -> Perf:
	var p := Perf.new()
	p.id = id
	p.is_player = is_player
	p.dancer = Dancer.new()
	stage.world.add_child(p.dancer)
	p.dancer.setup(id)
	p.dancer.position = Vector3(-1.2 if is_player else 1.2, 0, 0)
	return p


# ================================================================== INTERFACCIA
func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	root_ui = Control.new()
	root_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root_ui)
	# riquadro del giocatore
	var bp := UI.panel()
	_box(bp, 0, 0, 0, 0, 12, 10, 330, 112)
	root_ui.add_child(bp)
	var vb := VBoxContainer.new()
	bp.add_child(vb)
	lbl_p = UI.label("", 11, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	vb.add_child(lbl_p)
	bar_p = ProgressBar.new()
	bar_p.show_percentage = false
	bar_p.custom_minimum_size = Vector2(0, 10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#b44cff")
	fill.set_corner_radius_all(4)
	bar_p.add_theme_stylebox_override("fill", fill)
	vb.add_child(bar_p)
	# riquadro del rivale
	box_o = UI.panel()
	_box(box_o, 1, 0, 1, 0, -330, 10, -12, 112)
	root_ui.add_child(box_o)
	lbl_o = UI.label("", 11, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	box_o.add_child(lbl_o)
	# centro: round, tempo, pausa
	lbl_round = UI.label("", 11, UI.COL_GOLD)
	_box(lbl_round, 0.5, 0, 0.5, 0, -260, 12, 260, 70)
	root_ui.add_child(lbl_round)
	var pb := UI.button("II", _toggle_pause, false, Vector2(48, 40), 12)
	_box(pb, 0.5, 0, 0.5, 0, -24, 72, 24, 112)
	root_ui.add_child(pb)
	lbl_banner = UI.label("", 22, UI.COL_GOLD)
	lbl_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box(lbl_banner, 0.5, 0.5, 0.5, 0.5, -560, -190, 560, -120)
	root_ui.add_child(lbl_banner)
	# console scura + pista Guitar Hero
	var console := Panel.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.024, 0.016, 0.07, 0.88)
	csb.set_corner_radius_all(22)
	csb.shadow_color = Color(0.024, 0.016, 0.07, 0.6)
	csb.shadow_size = 24
	console.add_theme_stylebox_override("panel", csb)
	console.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box(console, 0.5, 1, 0.5, 1, -330, -150, 330, 40)
	root_ui.add_child(console)
	lane = NoteLane.new()
	lane.battle = self
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box(lane, 0.5, 1, 0.5, 1, -300, -124, 300, -66)
	root_ui.add_child(lane)
	# sequenza dell'Aura Challenge
	seq_bar = HBoxContainer.new()
	seq_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	seq_bar.add_theme_constant_override("separation", 6)
	seq_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box(seq_bar, 0.5, 1, 0.5, 1, -300, -124, 300, -66)
	seq_bar.visible = false
	root_ui.add_child(seq_bar)
	# pulsanti delle mosse: 4 a sinistra, 4 a destra
	var left := GridContainer.new()
	left.columns = 2
	_box(left, 0, 1, 0, 1, 14, -232, 14 + 2 * 128 + 8, -14)
	var right := GridContainer.new()
	right.columns = 2
	_box(right, 1, 1, 1, 1, -14 - 2 * 128 - 8, -232, -14, -14)
	for g in [left, right]:
		g.add_theme_constant_override("h_separation", 8)
		g.add_theme_constant_override("v_separation", 8)
		root_ui.add_child(g)
	var keys := {"dance": "1", "gesture": "2", "walk": "3", "mewing": "4", "aura": "5", "celebrate": "6", "combo": "C", "special": "SPACE"}
	for e in [["dance", left], ["gesture", left], ["walk", left], ["mewing", left], ["aura", right], ["celebrate", right], ["combo", right], ["special", right]]:
		var m: String = e[0]
		var b := UI.move_button(m, MOVE_LABELS[m] + "\n" + keys[m])
		b.custom_minimum_size = Vector2(128, 101)
		b.button_down.connect(func():
			held[m] = true
			on_move(m)
		)
		b.button_up.connect(func():
			held.erase(m)
		)
		e[1].add_child(b)
		move_btns[m] = b
	# riquadro del tutorial
	tut_box = UI.panel()
	_box(tut_box, 0.5, 0, 0.5, 0, -330, 120, 330, 230)
	var tv := VBoxContainer.new()
	tut_box.add_child(tv)
	tut_lbl = UI.label("", 11, Color.WHITE)
	tut_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(tut_lbl)
	var skip := UI.button("SALTA TUTORIAL", _tut_finish, false, Vector2(0, 34), 9)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tv.add_child(skip)
	tut_box.visible = false
	root_ui.add_child(tut_box)


## posiziona un controllo con ancore (0..1) e margini in pixel
func _box(c: Control, al: float, at: float, ar: float, ab: float, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b


func banner(text: String, col := UI.COL_GOLD) -> void:
	lbl_banner.text = UI.t(text)
	lbl_banner.add_theme_color_override("font_color", col)
	lbl_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(lbl_banner, "modulate:a", 0.0, 0.5)


func popup(text: String, col: Color, fs := 16) -> void:
	var l := UI.label(text, fs, col)
	var oy := -70.0 + randf_range(-12, 12)
	_box(l, 0.5, 0.5, 0.5, 0.5, -320, oy, 320, oy + 30)
	root_ui.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "offset_top", oy - 70, 0.9)
	tw.parallel().tween_property(l, "offset_bottom", oy - 40, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tw.tween_callback(l.queue_free)


# ================================================================== SCHERMATA VS
func _show_vs() -> void:
	var v := GameData.venue(venue)
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(ov)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.06, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	var sides := []
	for k in 2:
		var id: String = P.id if k == 0 else O.id
		var side := VBoxContainer.new()
		side.alignment = BoxContainer.ALIGNMENT_CENTER
		_box(side, 0.0 if k == 0 else 0.5, 0, 0.5 if k == 0 else 1.0, 1, 0, 0, 0, 0)
		var img := TextureRect.new()
		img.texture = load("res://assets/characters/%s_card.jpg" % id)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(0, 380)
		side.add_child(img)
		side.add_child(UI.label(GameData.character(id)["name"], 18, GameData.color_of(id)))
		ov.add_child(side)
		var sh := -900.0 if k == 0 else 900.0
		side.offset_left = sh
		side.offset_right = sh
		sides.append(side)
	var vs := UI.label("VS", 72, UI.COL_GOLD)
	_box(vs, 0.5, 0.5, 0.5, 0.5, -200, -60, 200, 40)
	vs.pivot_offset = Vector2(200, 50)
	vs.scale = Vector2.ONE * 4
	vs.modulate.a = 0
	ov.add_child(vs)
	var place := UI.label("%s · %s" % [v["name"], v["city"]], 12, Color.WHITE)
	_box(place, 0.5, 0.5, 0.5, 0.5, -400, 50, 400, 80)
	ov.add_child(place)
	UI.sfx("whoosh")
	UI.say("%s versus %s!" % [GameData.character(P.id)["name"].to_lower(), GameData.character(O.id)["name"].to_lower()], true)
	var tw := create_tween().set_parallel(true)
	for s in sides:
		tw.tween_property(s, "offset_left", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "offset_right", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(vs, "scale", Vector2.ONE, 0.5).set_delay(0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(vs, "modulate:a", 1.0, 0.2).set_delay(0.35)
	await get_tree().create_timer(0.4).timeout
	UI.sfx("special", -6)
	await get_tree().create_timer(2.0).timeout
	var tw2 := create_tween()
	tw2.tween_property(ov, "modulate:a", 0.0, 0.35)
	await tw2.finished
	ov.queue_free()
	banner("SFIDA %d/%d - %s - VELOCITA' %d" % [GameData.opp_index + 1, GameData.opp_list.size(), v["name"], GameData.speed_level(0) + 1])


# ================================================================== FLUSSO DEI ROUND (TOUR)
func _start_round() -> void:
	var r: Dictionary = GameData.data["rounds"][round_i]
	banner(r["name"])
	UI.say(["Round one!", "Round two!", "Final round!"][round_i], true)
	P.score = 0
	O.score = 0
	turn = "player"
	stage.crowd_target = null
	stage.fly_in()
	_begin_turn()


func _begin_turn() -> void:
	active = P if turn == "player" else O
	var wait := O if turn == "player" else P
	active.target = Vector3(0, FLOOR_Y, 0)
	active.home = active.target
	wait.target = Vector3(1.55 if turn == "player" else -1.55, FLOOR_Y, -0.6)
	wait.home = wait.target
	active.dancer.play_state("entrance")
	wait.dancer.play_state("idle")
	lane_ahead = GameData.lane_ahead(round_i)
	timer = float(GameData.data["rounds"][round_i]["dur"])
	start_beat = ceilf(conductor.beat()) + 4.0
	phase = "intro"
	notes.clear()
	if turn == "player":
		next_note_beat = start_beat
		last_note_move = ""
	else:
		O.ai_beat = -1.0


func _end_turn() -> void:
	phase = "gap"
	stage.dancing = false
	for n in notes:
		if n.state == 0:
			n.state = 3
	if turn == "player":
		banner("TOCCA A " + GameData.character(O.id)["name"])
		await get_tree().create_timer(1.6).timeout
		turn = "opp"
		_begin_turn()
	else:
		_round_result()


func _round_result() -> void:
	phase = "result"
	var pw := P.score >= O.score
	round_wins[0 if pw else 1] += 1
	var winner := P if pw else O
	winner.dancer.play_state("win")
	(O if pw else P).dancer.play_state("idle")
	stage.crowd_target = winner.dancer.position
	stage.close_up(winner.dancer, 2.4)
	stage.fx_confetti(GameData.glow_of(winner.id))
	UI.sfx("cheer")
	banner(("ROUND VINTO! " if pw else "ROUND PERSO ") + "%d - %d" % [P.score, O.score], UI.COL_GOLD if pw else Color(0.5, 0.7, 1))
	UI.say(GameData.character(winner.id)["name"].to_lower() + " wins the round!", true)
	await get_tree().create_timer(2.8).timeout
	if round_wins[0] >= 2 or round_wins[1] >= 2 or round_i >= 2:
		_match_end()
	else:
		round_i += 1
		_start_round()


func _match_end() -> void:
	phase = "end"
	var pw: bool = round_wins[0] > round_wins[1]
	(P if pw else O).dancer.play_state("win")
	(O if pw else P).dancer.play_state("lose")
	UI.sfx("win" if pw else "lose")
	var last := GameData.opp_index >= GameData.opp_list.size() - 1
	UI.say(("Aura legend!" if last else "Victory!") if pw else "Defeat...", true)
	var grade := _grade(_accuracy())
	GameData.results.append({"opp": O.id, "win": pw, "ps": P.total, "os": O.total, "grade": grade, "venue": venue})
	GameData.best_score = maxi(GameData.best_score, P.total)
	GameData.set_record(venue, P.total, grade)
	var news: Array = GameData.unlock_after_win(O.id, venue) if pw else []
	GameData.save()
	var title := ("TOUR COMPLETATO!" if last else "VITTORIA!") if pw else "SCONFITTA"
	var next_lbl := ("MENU" if last else "PROSSIMA SFIDA >") if pw else "RIPROVA"
	_show_result(title, pw, news, next_lbl, func():
		if pw and not last:
			GameData.opp_index += 1
			get_tree().reload_current_scene()
		elif pw and last:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		else:
			get_tree().reload_current_scene()
	)


# ================================================================== RISULTATI
func _show_result(title: String, good: bool, news: Array, next_lbl: String, next_cb: Callable) -> void:
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(ov)
	overlay = ov
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	var pnl := UI.panel()
	_box(pnl, 0.5, 0.5, 0.5, 0.5, -300, -280, 300, 280)
	ov.add_child(pnl)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	pnl.add_child(vb)
	vb.add_child(UI.label(title, 22, UI.COL_GOLD if good else Color(1, 0.48, 0.54)))
	var acc := _accuracy()
	var g := _grade(acc)
	var gl := UI.label(g, 64, Color({"S": "#ffe03c", "A": "#22d36b", "B": "#2f8bff", "C": "#ff7a1a", "D": "#ff3030"}[g]))
	vb.add_child(gl)
	for n in news:
		vb.add_child(UI.label("★ " + n, 10, Color("#ffe03c")))
	var info := UI.label("PRECISIONE %d%%\nPERFECT %d  GREAT %d  GOOD %d  MISS %d\nPUNTEGGIO %d   MIGLIOR COMBO x%d" % [acc, stats["p"], stats["g"], stats["ok"], stats["miss"], P.total, P.best_combo], 10)
	vb.add_child(info)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	row.add_child(UI.button(next_lbl, next_cb, true, Vector2(0, 48)))
	row.add_child(UI.button("CONDIVIDI", _share, false, Vector2(0, 48)))
	vb.add_child(UI.button("< MENU", func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"), false, Vector2(0, 42)))
	pnl.scale = Vector2.ONE * 0.6
	pnl.pivot_offset = Vector2(300, 280)
	create_tween().tween_property(pnl, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _accuracy() -> int:
	var tot: int = stats["p"] + stats["g"] + stats["ok"] + stats["miss"]
	if tot == 0:
		return 0
	return int(round((stats["p"] + stats["g"] * 0.8 + stats["ok"] * 0.5) / tot * 100.0))

func _grade(a: int) -> String:
	if a >= 95: return "S"
	if a >= 85: return "A"
	if a >= 70: return "B"
	if a >= 50: return "C"
	return "D"

func _stat(q: int) -> void:
	match q:
		3: stats["p"] += 1
		2: stats["g"] += 1
		1: stats["ok"] += 1
		_: stats["miss"] += 1


## immagine del risultato da condividere (1080x1350)
func _share() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1080, 1350)
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)
	var c := Control.new()
	c.size = Vector2(1080, 1350)
	c.theme = UI.theme
	sv.add_child(c)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/venues/%s.jpg" % venue)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = c.size
	c.add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.015, 0.08, 0.55)
	dim.size = c.size
	c.add_child(dim)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = Vector2(290, 30)
	logo.size = Vector2(500, 300)
	c.add_child(logo)
	var card := TextureRect.new()
	card.texture = load("res://assets/characters/%s_card.jpg" % P.id)
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.position = Vector2(370, 360)
	card.size = Vector2(340, 367)
	c.add_child(card)
	var last: Dictionary = GameData.results[-1] if not GameData.results.is_empty() else {}
	var lines := [[GameData.character(P.id)["name"], 44, GameData.color_of(P.id), 800],
		["%s   %d AURA" % [_grade(_accuracy()), P.total], 52, UI.COL_GOLD, 900],
		["%s %d%%  ·  COMBO x%d" % [UI.t("PRECISIONE"), _accuracy(), P.best_combo], 26, Color.WHITE, 990],
		["%s · %s" % [GameData.venue(venue)["name"], GameData.venue(venue)["city"]], 24, UI.COL_GOLD, 1060],
		["AURA BATTLE", 22, Color(1, 1, 1, 0.6), 1270]]
	if mode == "tour" and not last.is_empty():
		lines.insert(4, [("%s vs %s" % [UI.t("VITTORIA!") if last["win"] else UI.t("SCONFITTA"), GameData.character(last["opp"])["name"]]), 24, Color("#22d36b") if last["win"] else Color("#ff7a8a"), 1130])
	for l in lines:
		var lb := UI.label(l[0], l[1], l[2])
		lb.add_theme_constant_override("outline_size", 12)
		lb.position = Vector2(0, l[3])
		lb.size = Vector2(1080, 80)
		c.add_child(lb)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	var path := "user://aura_battle_risultato.png"
	img.save_png(path)
	sv.queue_free()
	var abs_path := ProjectSettings.globalize_path(path)
	if OS.has_feature("pc"):
		OS.shell_open(abs_path)
	popup("IMMAGINE SALVATA", Color(0.49, 0.97, 1), 14)


# ================================================================== FREE STYLE / TUTORIAL / CHALLENGE
func _start_solo() -> void:
	round_i = 0
	stage.fly_in()
	P.dancer.play_state("entrance")
	lane_ahead = GameData.lane_ahead(0)
	start_beat = ceilf(conductor.beat()) + 4.0
	next_note_beat = start_beat
	phase = "intro"
	var v := GameData.venue(venue)
	if mode == "tutorial":
		tut_i = 0
		_tut_enter()
	elif mode == "challenge":
		lane.visible = false
		seq_bar.visible = true
		move_btns["combo"].disabled = true
		move_btns["special"].disabled = true
		ch = {"level": 1, "lives": 3, "score": 0, "streak": 0, "seq": [], "results": [], "phase": "wait", "slot_beats": 2, "show_beat": 0.0, "play_beat": 0.0, "demo": -1}
		banner("AURA CHALLENGE - " + v["name"])
		await get_tree().create_timer(1.2).timeout
		_ch_new_sequence()
	else:
		banner("FREE STYLE - " + v["name"], Color("#7cf7ff"))


func _tut_steps() -> Array:
	return GameData.data["tutorial"]

func _tut_enter() -> void:
	var st: Dictionary = _tut_steps()[tut_i]
	tut_got = 0
	tut_box.visible = true
	tut_lbl.text = "%d / %d\n\n%s" % [tut_i + 1, _tut_steps().size(), st["it"] if GameData.lang == "it" else st["en"]]
	for n in notes:
		if n.state == 0:
			n.state = 3
	next_note_beat = ceilf(conductor.beat()) + 4.0
	if st["kind"] == "combo":
		P.charges = 1
	if st["kind"] == "special":
		P.meter = 100
	if st["kind"] == "end":
		UI.sfx("combo")
		banner("TUTORIAL COMPLETATO!", Color("#ffe03c"))
		GameData.tutorial_done = true
		GameData.save()
		await get_tree().create_timer(4.0).timeout
		if is_inside_tree() and mode == "tutorial":
			_tut_finish()

func _tut_progress(kind: String) -> void:
	if mode != "tutorial" or tut_i >= _tut_steps().size() - 1:
		return
	if _tut_steps()[tut_i]["kind"] != kind and not (kind == "hit" and _tut_steps()[tut_i]["kind"] in ["dance", "basic", "double", "hold", "gold"]):
		return
	tut_got += 1
	if tut_got < int(_tut_steps()[tut_i]["need"]):
		return
	UI.sfx("combo")
	popup("OK!", Color("#22d36b"), 20)
	tut_i += 1
	await get_tree().create_timer(1.2).timeout
	if is_inside_tree():
		_tut_enter()

func _tut_finish() -> void:
	GameData.tutorial_done = true
	GameData.save()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _tut_make(beat: float) -> Note:
	var k: String = _tut_steps()[tut_i]["kind"]
	var basic := ["dance", "gesture", "walk", "mewing"]
	var n := Note.new()
	n.beat = beat
	match k:
		"dance":
			n.m = "dance"
		"basic":
			n.m = basic.filter(func(x): return x != last_note_move).pick_random()
		"double":
			n.m = basic.pick_random()
			n.m2 = basic.filter(func(x): return x != n.m).pick_random()
		"hold":
			n.m = basic.pick_random()
			n.length = 3.0
		"gold":
			n.m = basic.pick_random()
			n.gold = true
		_:
			return null
	return n


# ---- Aura Challenge: memorizza e ripeti
func _ch_new_sequence() -> void:
	var lv: int = ch["level"]
	var n := mini(3 + int((lv - 1) / 2), 8)
	var seq := []
	for i in n:
		var m: String = CH_MOVES.pick_random()
		while i > 0 and m == seq[i - 1] and randf() < 0.8:
			m = CH_MOVES.pick_random()
		seq.append(m)
	ch["seq"] = seq
	ch["slot_beats"] = 1 if lv >= 5 else 2
	ch["results"] = seq.map(func(_x): return null)
	ch["show_beat"] = ceilf(conductor.beat()) + 2.0
	ch["play_beat"] = ch["show_beat"] + n * ch["slot_beats"] + 4
	ch["phase"] = "show"
	ch["demo"] = -1
	for c in seq_bar.get_children():
		c.queue_free()
	for m in seq:
		var tr := TextureRect.new()
		tr.texture = load("res://assets/ui/icons/%s.png" % m)
		tr.custom_minimum_size = Vector2(44, 44)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.modulate = Color(UI.MOVE_COLS[m])
		seq_bar.add_child(tr)
	banner("LIVELLO %d - MEMORIZZA!" % lv)
	UI.say("Level %d" % lv, true)


func _ch_update(b: float) -> void:
	if ch.is_empty():
		return
	var sb: float = ch["slot_beats"]
	if ch["phase"] == "show":
		var i := int(floor((b - ch["show_beat"]) / sb))
		if i >= 0 and i < ch["seq"].size() and ch["demo"] != i:
			ch["demo"] = i
			_ch_anim(ch["seq"][i], sb)
			UI.sfx("tick")
			for k in seq_bar.get_child_count():
				seq_bar.get_child(k).scale = Vector2.ONE * (1.3 if k == i else 1.0)
		if b >= ch["play_beat"] - 4 and ch["demo"] >= ch["seq"].size() - 1:
			ch["phase"] = "count"
			for k in seq_bar.get_child_count():
				seq_bar.get_child(k).modulate.a = 0.25
			banner("TOCCA A TE!")
			UI.say("Your turn!", true)
	elif ch["phase"] == "count":
		if b >= ch["play_beat"] - 0.25:
			ch["phase"] = "play"
	elif ch["phase"] == "play":
		var idx := int(floor((b - ch["play_beat"]) / sb - 0.5))
		for k in mini(idx, ch["seq"].size()):
			if ch["results"][k] == null:
				ch["results"][k] = false
				_ch_miss("MANCATA!")
		if ch["results"].all(func(x): return x != null):
			if ch["phase"] == "play":
				ch["phase"] = "next"
				_ch_done()


func _ch_anim(m: String, sb: float) -> void:
	var anim: String = ANIM_OF.get(m, "dance")
	if m == "gesture":
		anim = "funny" if P.gesture_alt else "sixseven"
		P.gesture_alt = not P.gesture_alt
	P.dancer.play_state(anim)
	P.busy_until = conductor.beat() + sb
	P.linger_until = -999.0


func _ch_input(m: String) -> void:
	if ch.is_empty() or ch["phase"] != "play" or not m in CH_MOVES:
		return
	var b := conductor.beat()
	var sb: float = ch["slot_beats"]
	var rel: float = (b - ch["play_beat"]) / sb
	var idx := roundi(rel)
	if idx < 0 or idx >= ch["seq"].size() or ch["results"][idx] != null:
		return
	var err: float = (rel - idx) * sb * conductor.beat_len
	if m != ch["seq"][idx]:
		ch["results"][idx] = false
		_ch_miss("SBAGLIATA!")
		return
	var j := GameData.judge(err)
	if int(j["q"]) == 0:
		ch["results"][idx] = false
		_ch_miss("FUORI TEMPO")
		return
	ch["results"][idx] = true
	_stat(int(j["q"]))
	ch["streak"] += 1
	var pts := int(round(float(GameData.move(m)["base"]) * float(j["mul"]) * (1.0 + mini(ch["streak"], 20) * 0.1)))
	ch["score"] += pts
	P.score = ch["score"]
	P.total = ch["score"]
	seq_bar.get_child(idx).modulate.a = 1.0
	_ch_anim(m, sb)
	popup("%s +%d" % [j["name"], pts], _judge_col(int(j["q"])))
	UI.sfx(["miss", "good", "great", "perfect"][int(j["q"])])
	stage.kick(1.0)
	stage.fx_ring(GameData.glow_of(P.id))
	hype = clampf(hype + 6 + int(j["q"]) * 2, 0, 100)


func _ch_miss(txt: String) -> void:
	ch["lives"] -= 1
	ch["streak"] = 0
	_stat(0)
	popup(txt, Color(1, 0.48, 0.54), 18)
	UI.sfx("boo", -4)
	hype = clampf(hype - 15, 0, 100)
	P.dancer.play_state("lose")
	if ch["lives"] <= 0 and ch["phase"] != "over":
		ch["phase"] = "over"
		await get_tree().create_timer(1.2).timeout
		_ch_over()


func _ch_done() -> void:
	if ch["phase"] == "over":
		return
	banner("SEQUENZA OK!", Color("#22d36b"))
	UI.sfx("combo")
	UI.say("Perfect sequence!" if ch["results"].all(func(x): return x == true) else "Next level!")
	ch["level"] += 1
	await get_tree().create_timer(1.4).timeout
	if is_inside_tree() and ch["phase"] != "over":
		_ch_new_sequence()


func _ch_over() -> void:
	phase = "end"
	UI.sfx("lose")
	GameData.best_score = maxi(GameData.best_score, P.total)
	GameData.save()
	_show_result("LIVELLO %d" % ch["level"], ch["level"] > 3, [], "RIGIOCA", func(): get_tree().reload_current_scene())


# ================================================================== CICLO
func _toggle_pause() -> void:
	if phase == "end":
		return
	paused = not paused
	if paused:
		conductor.stream_paused = true
		var ov := Control.new()
		ov.set_anchors_preset(Control.PRESET_FULL_RECT)
		ov.name = "Pause"
		ui.add_child(ov)
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.6)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		ov.add_child(dim)
		var pnl := UI.panel()
		_box(pnl, 0.5, 0.5, 0.5, 0.5, -200, -150, 200, 150)
		ov.add_child(pnl)
		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 10)
		pnl.add_child(vb)
		vb.add_child(UI.label("PAUSA", 20, UI.COL_GOLD))
		vb.add_child(UI.button("RIPRENDI", _toggle_pause, true))
		vb.add_child(UI.button("RICOMINCIA", func(): get_tree().reload_current_scene()))
		vb.add_child(UI.button("MENU PRINCIPALE", func(): get_tree().change_scene_to_file("res://scenes/menu.tscn")))
	else:
		conductor.stream_paused = false
		var ov := ui.get_node_or_null("Pause")
		if ov:
			ov.queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not paused and phase in ["intro", "perform"]:
		_toggle_pause()


func _process(dt: float) -> void:
	if conductor == null or P == null or paused:
		return
	var b := conductor.beat()
	# battito: luci, stelle, pubblico
	var bi := int(floor(b))
	if bi != last_beat_i:
		last_beat_i = bi
		stage.pulse = 1.0
		_crowd_beat(bi)
	stage.hype = hype
	UI.crowd_level(hype)
	for p in ([P, O] if O else [P]):
		p.dancer.position = p.dancer.position.lerp(p.target, 1.0 - pow(0.002, dt))
		if p == active:
			p.dancer.face(stage.camera.global_position * Vector3(1, 0, 1), 0.3)
		elif active:
			p.dancer.face(active.dancer.global_position, 0.8)
		if p.busy_until > 0 and b >= p.busy_until:
			p.busy_until = -999.0
			p.target = p.home
			p.linger_until = b + 4.0
		if p.linger_until > 0 and b >= p.linger_until:
			p.linger_until = -999.0
			p.dancer.play_state("idle")
		if not p.queue.is_empty() and b >= p.queue[0][0]:
			var q: Array = p.queue.pop_front()
			perform(p, q[1], randfn(0.0, 0.02), {"auto": true})
	if active:
		stage.focus = active.dancer
		stage.focus_col = GameData.glow_of(active.id)
		stage.focus_meter = active.meter / 100.0
	stage.dancing = phase == "perform"
	_update_hud(b)
	_update_hints(b)
	match phase:
		"intro":
			if b >= start_beat:
				phase = "perform"
				popup("GO!", UI.COL_GOLD, 30)
				UI.sfx("go")
				if turn == "player" and mode != "challenge":
					UI.say("Dance!", true)
			elif b >= start_beat - 3 and mode != "challenge":
				var cd := str(int(ceil(start_beat - b)))
				if lbl_banner.text != cd:
					UI.sfx("tick")
				lbl_banner.text = cd
				lbl_banner.modulate.a = 1.0
			if turn == "player" and mode != "challenge":
				_fill_notes(b)
		"perform":
			if mode == "challenge":
				_ch_update(b)
			elif mode == "tour":
				timer -= dt
				if turn == "player":
					_fill_notes(b)
					_update_notes(b)
				else:
					_ai(b)
				if timer <= 0.0:
					_end_turn()
			else:
				_fill_notes(b)
				_update_notes(b)


func _update_hud(_b: float) -> void:
	var c := GameData.character(P.id)
	var g := _grade(_accuracy()) if stats["p"] + stats["g"] + stats["ok"] + stats["miss"] > 0 else "-"
	lbl_p.text = "%s\n%d\nCOMBO x%.2f (%d)\nAURA %d%%" % [c["name"], P.score, 1.0 + 0.15 * mini(P.combo, 10), P.combo, int(P.meter)]
	lbl_p.add_theme_color_override("font_color", GameData.color_of(P.id))
	bar_p.value = P.meter
	move_btns["combo"].text = "COMBO\n%d" % P.charges
	move_btns["special"].modulate = Color(1.4, 1.4, 1.4) if P.meter >= 100 else Color.WHITE
	if O:
		lbl_o.text = "%s\n%d\nAURA %d%%" % [GameData.character(O.id)["name"], O.score, int(O.meter)]
		lbl_o.add_theme_color_override("font_color", GameData.color_of(O.id))
	match mode:
		"tour":
			var r: Dictionary = GameData.data["rounds"][round_i]
			lbl_round.text = "%s - %s\n%ds   %d - %d" % [UI.t(r["name"]), UI.t("TU") if turn == "player" else UI.t("RIVALE"), ceili(maxf(timer, 0.0)), round_wins[0], round_wins[1]]
		"free":
			lbl_round.text = "FREE STYLE · %s %d\n%s   %s" % [UI.t("VELOCITA'"), free_lvl + 1, g, "BEST x%d" % P.best_combo]
		"tutorial":
			lbl_round.text = "TUTORIAL"
		"challenge":
			if not ch.is_empty():
				lbl_round.text = "%s %d\n%s   VITE %d" % [UI.t("LIVELLO"), ch["level"], str(ch["score"]), ch["lives"]]


## il pulsante della prossima mossa si accende solo mezzo battito prima della nota
func _update_hints(b: float) -> void:
	var nx: Note = null
	for n in notes:
		if n.state == 0 and n.beat > b - 0.3 and (nx == null or n.beat < nx.beat):
			nx = n
	var hint := float(GameData.data.get("hint_beats", 0.5))
	for m in move_btns:
		var on: bool = nx != null and nx.beat - b < hint and (nx.m == m or nx.m2 == m)
		if m != "special":
			move_btns[m].modulate = Color(1.5, 1.5, 1.5) if on else Color.WHITE


## pubblico: battimani, cori "AU-RA!" e "OH-OH", fischi
func _crowd_beat(bi: int) -> void:
	if phase != "perform":
		return
	var h := hype / 100.0
	var bar := posmod(bi, 8)
	if h > 0.45 and bi % 2 == 1:
		UI.sfx("clap", lerpf(-14, -6, h))
	if h > 0.85 and bar < 3:
		UI.sfx("chant_oh", -6)
	elif h > 0.65 and (bar == 4 or bar == 6):
		UI.sfx("chant_au", -6)
		get_tree().create_timer(conductor.beat_len * 0.6).timeout.connect(func(): UI.sfx("chant_ra", -6))
	if h > 0.75 and randf() < 0.12:
		UI.sfx("whistle", -10)


# ================================================================== NOTE
func _fill_notes(b: float) -> void:
	if mode == "tutorial":
		while next_note_beat < b + lane_ahead + 2.0:
			var tn := _tut_make(next_note_beat)
			if tn:
				notes.append(tn)
				last_note_move = tn.m
			next_note_beat += 6.0 if (tn and tn.length > 0) else 4.0
		return
	var prefs: Dictionary = GameData.character(P.id)["prefs"]
	var step := _note_step()
	while next_note_beat < b + lane_ahead + 2.0:
		var opts: Array = GameData.move_ids.filter(func(x): return x != last_note_move)
		var tot := 0.0
		for o in opts:
			tot += float(prefs.get(o, 1.0))
		var r := randf() * tot
		var m: String = opts[0]
		for o in opts:
			r -= float(prefs.get(o, 1.0))
			if r <= 0.0:
				m = o
				break
		var n := Note.new()
		n.beat = next_note_beat
		n.m = m
		var rr := randf()
		var early := notes.size() < 2
		if not early and rr < 0.12 and m != "aura":
			n.length = 3.0
		elif not early and rr < 0.24 and m in ["dance", "gesture", "walk", "mewing"]:
			n.m2 = (["dance", "gesture", "walk", "mewing"].filter(func(x): return x != m)).pick_random()
		elif not early and rr < 0.34:
			n.gold = true
		notes.append(n)
		last_note_move = m
		next_note_beat += float(step + 2) if (n.length > 0 or m == "aura") else float(step)


func _note_step() -> int:
	if mode == "free":
		return int(GameData.data["speed_step"][clampi(free_lvl, 0, 5)])
	if mode == "tutorial":
		return 4
	return GameData.note_step(round_i)


func _update_notes(b: float) -> void:
	var win_beats := 0.2 / conductor.beat_len
	for n in notes:
		if n.state == 0 and b - n.beat > win_beats + 0.04:
			n.state = 2
			n.t = Time.get_ticks_msec() / 1000.0
			_stat(0)
			P.combo = 0
			P.clean_run = 0
			hype = clampf(hype - 4, 0, 100)
			popup("MISS", Color(1, 0.48, 0.54))
			UI.sfx("miss", -6)
			_crowd_miss()
			_rival_react(P, 0)
		if n.state == 4:
			if b >= n.beat + n.length:
				n.state = 1
				n.t = Time.get_ticks_msec() / 1000.0
				var bonus := int(160 * (1 + 0.15 * mini(P.combo, 10)))
				P.score += bonus
				P.total += bonus
				popup("HOLD +%d" % bonus, Color(0.49, 0.97, 1))
				UI.sfx("combo", -4)
				_tut_progress("hit")
			elif not held.has(n.m) and not Input.is_action_pressed("move_" + n.m) and b < n.beat + n.length - 0.3:
				n.state = 5
				popup("RILASCIATA", Color(1, 0.7, 0.7))
	notes = notes.filter(func(n): return b - n.beat - n.length < 3.0)


func _nearest_note(b: float) -> Note:
	var best: Note = null
	var be := 999.0
	for n in notes:
		if n.state != 0:
			continue
		var e := absf(b - n.beat) * conductor.beat_len
		if e < be:
			be = e
			best = n
	return best if be <= 0.2 else null


func _crowd_miss() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	misses_t = misses_t.filter(func(x): return t - x < 6.0)
	misses_t.append(t)
	if misses_t.size() >= 3 or hype < 18:
		misses_t.clear()
		UI.sfx("boo", -2)
		UI.sfx("whistle", -8, 0.8)
		popup("BUUUH!", Color(0.6, 0.63, 0.72), 20)


# ================================================================== INPUT
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause", false):
		_toggle_pause()
		return
	for m in GameData.move_ids + ["combo", "special"]:
		if event.is_action_pressed("move_" + m, false):
			on_move(m)


func on_move(m: String) -> void:
	if paused or phase != "perform" or turn != "player":
		return
	if mode == "challenge":
		_ch_input(m)
		return
	if m == "combo":
		_do_combo(P)
		return
	if m == "special":
		if P.meter >= 100:
			perform(P, "special", conductor.error_to(roundf(conductor.beat())))
			for n in notes:
				if n.state == 0 and n.beat < conductor.beat() + 5:
					n.state = 3
		else:
			popup("AURA NON CARICA", Color(0.6, 0.6, 0.6), 12)
		return
	var b := conductor.beat()
	var n := _nearest_note(b)
	if n == null:
		perform(P, m, conductor.error_to(roundf(b)))
		return
	var err := (b - n.beat) * conductor.beat_len
	n.t = Time.get_ticks_msec() / 1000.0
	if n.m2 != "" and (m == n.m or m == n.m2):
		n.got[m] = err
		if n.got.has(n.m) and n.got.has(n.m2):
			n.state = 1
			perform(P, n.m, (float(n.got[n.m]) + float(n.got[n.m2])) / 2.0, {"double": true, "gold": n.gold})
			_stat(P.last_q)
			if P.last_q >= 1:
				_tut_progress("hit")
		return
	if n.m == m:
		n.state = 4 if n.length > 0 else 1
		perform(P, m, err, {"gold": n.gold})
		_stat(P.last_q)
		if n.length == 0 and P.last_q >= 1:
			_tut_progress("hit")
		_free_speed()
	else:
		n.state = 2
		popup("MOSSA SBAGLIATA", Color(1, 0.48, 0.54), 13)
		perform(P, m, 0.3)
		_stat(0)


func _free_speed() -> void:
	if mode != "free":
		return
	free_hits += 1
	var l := mini(5, int(free_hits / 10))
	if l > free_lvl:
		free_lvl = l
		lane_ahead = float(GameData.data["speed_ahead"][l])
		banner("VELOCITA' %d!" % (l + 1), Color("#2fe0e8"))
		UI.say("Speed up!", true)
		UI.sfx("combo")


func _do_combo(p: Perf) -> void:
	if p.charges <= 0:
		if p.is_player:
			popup("NO COMBO", Color(0.6, 0.6, 0.6), 12)
		return
	p.charges -= 1
	var seq: Array = ["dance", "gesture", "walk", "mewing"]
	seq.shuffle()
	seq = seq.slice(0, 3)
	var step := _note_step()
	var nb := ceilf(conductor.beat() + 0.3)
	for i in 3:
		p.queue.append([nb + i * step, seq[i]])
	popup("COMBO CHAIN!", Color(0.18, 0.88, 0.91), 22)
	UI.sfx("combo")
	if p.is_player:
		_tut_progress("combo")
		for n in notes:
			if n.state == 0 and n.beat < nb + step * 3 + 1:
				n.state = 3


# ================================================================== IA DEL RIVALE
func _ai(b: float) -> void:
	var skill: Dictionary = GameData.data["difficulty"][GameData.difficulty]
	if O.ai_beat > 0:
		if b >= O.ai_beat:
			O.ai_beat = -1.0
			if O.ai_move == "combo":
				_do_combo(O)
			else:
				perform(O, O.ai_move, O.ai_err)
		return
	if b < O.busy_until - 0.2 or not O.queue.is_empty():
		return
	var target := ceilf(b + 0.25)
	if randf() > float(skill["act"]):
		target += 1
	var m := ""
	if O.meter >= 100:
		m = "special"
		target = ceilf(target / 4.0) * 4.0
	elif O.charges > 0 and randf() < 0.35:
		m = "combo"
	else:
		var prefs: Dictionary = GameData.character(O.id)["prefs"]
		var opts: Array = GameData.move_ids.filter(func(x): return x != O.last_move or randf() < float(skill["rep"]))
		var tot := 0.0
		for o in opts:
			tot += float(prefs.get(o, 1.0))
		var r := randf() * tot
		m = opts[0]
		for o in opts:
			r -= float(prefs.get(o, 1.0))
			if r <= 0.0:
				m = o
				break
	O.ai_err = clampf(randfn(0.0, float(skill["sig"])), -0.24, 0.24)
	O.ai_beat = target + O.ai_err / conductor.beat_len
	O.ai_move = m


## il rivale reagisce: serio se fai PERFECT, ride se sbagli
func _rival_react(p: Perf, q: int) -> void:
	if mode != "tour":
		return
	var o := O if p == P else P
	if o == null or o == active or o.busy_until > 0:
		return
	if q >= 3 and randf() < 0.55:
		o.dancer.play_state("mewing")
	elif q == 0 and randf() < 0.7:
		o.dancer.play_state("win")
	elif q == 2 and randf() < 0.25:
		o.dancer.play_state("sixseven")
	o.linger_until = conductor.beat() + 2.0


# ================================================================== PUNTEGGIO
func perform(p: Perf, move_id: String, err_sec: float, opts := {}) -> int:
	var mv := GameData.move(move_id)
	var j := GameData.judge(err_sec)
	var q := int(j["q"])
	var mul := float(j["mul"])
	if move_id == p.last_move and not opts.get("auto", false):
		p.rep += 1
		mul *= maxf(0.15, pow(0.5, p.rep))
		p.combo = 0
		p.clean_run = 0
	else:
		p.rep = 0
		if q >= 1:
			p.combo += 1
			p.combo_steps += 1
			if p.combo_steps % 3 == 0 and p.charges < 2 and move_id != "special":
				p.charges += 1
		else:
			p.combo = 0
		p.clean_run = p.clean_run + 1 if q >= 2 else 0
	p.last_move = move_id
	var combo_mul := 1.0 + 0.15 * mini(p.combo, 10)
	var clean := 2.0 if (p.clean_run > 0 and p.clean_run % 4 == 0) else 1.0
	var crowd_mul := 0.85 + hype / 100.0 * 0.4
	var pts := float(mv["base"]) * mul * combo_mul * clean * crowd_mul
	if clean == 2.0:
		popup("CLEAN COMBO x2!", Color("#7cf7ff"), 18)
	if move_id == "special":
		var bt := roundi(conductor.beat() - err_sec / conductor.beat_len)
		if q >= 2 and posmod(bt, 4) == 0:
			pts += 400
			popup("MAX AURA!", Color(1, 0.88, 0.24), 30)
			if p.is_player:
				UI.say("Max aura!", true)
		else:
			popup(GameData.character(p.id)["special"], GameData.glow_of(p.id), 24)
			if p.is_player:
				UI.say(String(GameData.character(p.id)["special"]).to_lower() + "!", true)
		p.meter = 0
		stage.fx_special(GameData.glow_of(p.id))
		stage.close_up(p.dancer, 1.8)
		UI.sfx("special")
		UI.sfx("ooh", -4)
		get_tree().create_timer(1.2).timeout.connect(func(): UI.sfx("cheer"))
		if p.is_player:
			_tut_progress("special")
	elif move_id == "celebrate":
		hype = clampf(hype + (8 if q >= 2 else 2), 0, 100)
	if opts.get("gold", false):
		pts *= 3
		popup("GOLD x3!", Color("#ffe03c"), 18)
		if q >= 2:
			UI.sfx("ooh", -6)
	if opts.get("double", false):
		pts *= 2
		popup("DOPPIA x2!", Color("#ff9ad5"), 18)
	p.last_q = q
	var ipts := int(round(pts))
	p.score += ipts
	p.total += ipts
	p.best_combo = maxi(p.best_combo, p.combo)
	if move_id != "special":
		var before := p.meter
		p.meter = clampf(p.meter + ipts / 9.0, 0, 100)
		if p.is_player and before < 100 and p.meter >= 100:
			popup("AURA PIENA! PREMI SPECIAL", Color("#b44cff"), 16)
	var prev_h := hype
	hype = clampf(hype - 7 if q == 0 else hype + ipts / 22.0, 0, 100)
	if hype > 82 and prev_h <= 82:
		popup("CROWD GOING WILD!", Color("#ff4fb8"), 20)
		UI.sfx("cheer")
		UI.say("The crowd is going wild!")
	# animazione: dura fino alla nota successiva
	var anim: String = ANIM_OF.get(move_id, "dance")
	if move_id == "gesture":
		anim = "funny" if p.gesture_alt else "sixseven"
		p.gesture_alt = not p.gesture_alt
	var beats_len := float(mv["beats"]) * _note_step() / 4.0
	p.dancer.play_state(anim)
	p.busy_until = conductor.beat() + beats_len
	p.linger_until = -999.0
	if move_id == "walk":
		p.walk_dir *= -1.0
		p.target = p.home + Vector3(0.5 * p.walk_dir, 0, 0)
	# telecamera ed effetti
	if p == active:
		stage.kick(1.0 if q >= 2 else 0.5)
		if q >= 3:
			stage.fx_ring(GameData.glow_of(p.id))
		var now := Time.get_ticks_msec() / 1000.0
		if move_id != "special" and now - last_close > 3.0 and (clean == 2.0 or (opts.get("gold", false) and q >= 2) or (q >= 1 and p.combo >= 6 and p.combo % 3 == 0)):
			last_close = now
			stage.close_up(p.dancer, 1.3)
	if p.is_player or q >= 3:
		popup(UI.t(String(j["name"])) + ("!" if q > 0 else "") + "  +%d" % ipts, _judge_col(q))
	if p.is_player:
		UI.sfx(["miss", "good", "great", "perfect"][q], -3)
		if p.combo > 1 and p.combo % 5 == 0:
			UI.say("Combo %d!" % p.combo)
			UI.sfx("cheer", -6)
		elif q >= 3 and randf() < 0.3:
			UI.say(["Perfect!", "Clean!", "Nice!"].pick_random())
		if q == 0:
			_crowd_miss()
	_rival_react(p, q)
	return ipts


func _judge_col(q: int) -> Color:
	return [Color(1, 0.48, 0.54), Color(0.72, 1, 0.69), Color(0.49, 0.97, 1), Color(1, 0.88, 0.35)][q]
