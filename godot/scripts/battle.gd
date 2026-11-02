extends Control
## AURA BATTLE - la sfida in piazza.
## 3 round (Ingresso, Esibizione, Posa Finale), al meglio di 3. In ogni round balla prima
## il giocatore (seguendo le note della pista) e poi il rivale (IA). Vince chi fa più Aura Points.
## Tutta la scena è costruita da codice, così il socio può leggere tutto in un posto solo.

const FLOOR_Y := 0.0
const CAM_POS := Vector3(0, 0.64, 7.2)
const CAM_LOOK := Vector3(0, 0.78, 0)
const CAM_FOV := 46.0
const BG_DIST := 40.0
const MOVE_COLS := {"combo": "#16e3e8", "special": "#ff3030"}
const MOVE_LABELS := {"dance": "DANCE", "gesture": "GESTURE", "walk": "MODEL\nWALK", "mewing": "MEWING",
	"aura": "AURA\nPOSE", "celebrate": "CELE-\nBRATE", "combo": "COMBO", "special": "SPECIAL"}
const ANIM_OF := {"dance": "dance", "walk": "walk", "mewing": "mewing", "aura": "aura", "celebrate": "win", "special": "aura"}

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
	var gesture_alt := false
	var busy_until := -999.0     # battito in cui finisce la mossa in corso
	var linger_until := -999.0   # continua a ballare fino a questo battito
	var home := Vector3.ZERO
	var target := Vector3.ZERO
	var walk_dir := 1.0
	var ai_beat := -1.0
	var ai_move := ""
	var ai_err := 0.0
	var queue: Array = []        # mosse automatiche della combo [battito, mossa]

var conductor: Conductor
var camera: Camera3D
var bg_plane: MeshInstance3D
var bg_mat: StandardMaterial3D
var crowd: Array = []
var P: Perf
var O: Perf
var active: Perf
var venue := ""
var round_i := 0
var round_wins := [0, 0]
var turn := "player"
var phase := "intro"
var timer := 0.0
var start_beat := 0.0
var notes: Array = []
var next_note_beat := 0.0
var last_note_move := ""
var lane_ahead := 10.0
var hype := 50.0
var stats := {"p": 0, "g": 0, "ok": 0, "miss": 0}
var held := {}
var tts_voice := ""
var last_voice := 0.0

# UI
var ui: CanvasLayer
var lane: NoteLane
var lbl_p: Label
var lbl_o: Label
var lbl_round: Label
var lbl_banner: Label
var bar_p: ProgressBar
var result_panel: PanelContainer


func _ready() -> void:
	venue = GameData.current_venue()
	_build_world()
	_build_ui()
	conductor = Conductor.new()
	add_child(conductor)
	conductor.play_song(GameData.song_for_venue(venue))
	P = _make_perf(GameData.sel_char, true)
	O = _make_perf(GameData.current_opp(), false)
	var voices := DisplayServer.tts_get_voices_for_language("en")
	tts_voice = voices[0] if voices.size() > 0 else ""
	get_viewport().size_changed.connect(_place_background)
	_place_background()
	var v := GameData.venue(venue)
	banner("SFIDA %d/%d - %s - %s" % [GameData.opp_index + 1, GameData.opp_list.size(), v["name"], v["city"]])
	say("%s versus %s!" % [GameData.character(P.id)["name"].to_lower(), GameData.character(O.id)["name"].to_lower()])
	await get_tree().create_timer(2.2).timeout
	_start_round()


# ------------------------------------------------------------------ mondo 3D
func _build_world() -> void:
	var world := Node3D.new()
	add_child(world)
	camera = Camera3D.new()
	camera.fov = CAM_FOV
	camera.near = 0.05
	camera.far = 200.0
	world.add_child(camera)
	camera.position = CAM_POS
	camera.look_at(CAM_LOOK)
	camera.current = true
	# sfondo: la piazza disegnata, su un piano attaccato alla telecamera
	bg_mat = StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_texture = load("res://assets/venues/%s.jpg" % venue)
	bg_plane = MeshInstance3D.new()
	var q := QuadMesh.new()
	var h := 2.0 * BG_DIST * tan(deg_to_rad(CAM_FOV / 2.0)) * 1.3
	q.size = Vector2(h * 1672.0 / 941.0, h)
	bg_plane.mesh = q
	bg_plane.material_override = bg_mat
	bg_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(bg_plane)
	# luci
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.01, 0.06)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.55, 0.85)
	e.ambient_light_energy = 0.9
	env.environment = e
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.3
	key.light_color = Color(1.0, 0.95, 0.88)
	key.shadow_enabled = true
	world.add_child(key)
	key.rotation_degrees = Vector3(-50, -25, 0)
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.7, 0.3, 1.0)
	rim.light_energy = 2.0
	rim.omni_range = 8.0
	world.add_child(rim)
	rim.position = Vector3(0, 2.5, -2.5)
	# ombre sul pavimento (piano invisibile che riceve solo le ombre)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mi.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shadow_to_opacity = true
	sm.albedo_color = Color(0, 0, 0, 1)
	floor_mi.material_override = sm
	world.add_child(floor_mi)
	_build_crowd(world)


## il centro del cerchio disegnato nella piazza deve coincidere con il centro del palco 3D
func _place_background() -> void:
	if camera == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var cal: Array = GameData.data["venue_calibration"].get(venue, [0.5, 0.67])
	var q: QuadMesh = bg_plane.mesh
	var o := camera.unproject_position(Vector3.ZERO)
	var hf := 2.0 * BG_DIST * tan(deg_to_rad(CAM_FOV / 2.0))
	var u := o.x / vs.x - 0.5
	var v := o.y / vs.y - 0.5
	var x := u * hf * (vs.x / vs.y)
	var y := -v * hf
	bg_plane.position = Vector3(x - (float(cal[0]) - 0.5) * q.size.x, y - (0.5 - float(cal[1])) * q.size.y, -BG_DIST)


func _build_crowd(world: Node3D) -> void:
	var ids := ["crowdA", "crowdB", "crowdC"]
	var clips: Dictionary = GameData.data["crowd_clips"]
	var spots: Array = []
	for sx in [-1.0, 1.0]:
		for row in [[4.3, 6], [5.4, 7], [6.5, 6]]:
			var n: int = row[1]
			for i in n:
				var t := deg_to_rad(88.0 + i * (62.0 / (n - 1)) + randf_range(-4, 4))
				var r: float = row[0] + randf_range(-0.25, 0.25)
				spots.append(Vector3(sx * r * sin(t), 0, r * cos(t)))
	var scenes := {}
	for id in ids:
		scenes[id] = load("res://assets/crowd/%s.glb" % id)
	for i in spots.size():
		var id: String = ids[i % ids.size()]
		var inst: Node3D = scenes[id].instantiate()
		world.add_child(inst)
		inst.position = spots[i]
		inst.rotation.y = atan2(-spots[i].x, -spots[i].z) + randf_range(-0.2, 0.2)
		inst.scale = Vector3.ONE * randf_range(0.93, 1.07)
		# vestiti di colori diversi: tinta leggera e casuale
		var tint := Color.from_hsv(randf(), randf_range(0.1, 0.35), randf_range(0.8, 1.0))
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s)
				if mat is StandardMaterial3D:
					var mm: StandardMaterial3D = mat.duplicate()
					mm.albedo_color = tint
					mi.set_surface_override_material(s, mm)
		var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
		var c: Dictionary = clips[id]
		for lib_name in ap.get_animation_library_list():
			for an in ap.get_animation_library(lib_name).get_animation_list():
				var a := ap.get_animation_library(lib_name).get_animation(an)
				a.loop_mode = Animation.LOOP_LINEAR
				Dancer._stay_in_place(a)
		var calm: String = c["calm"] if ap.has_animation(c["calm"]) else ap.get_animation_list()[0]
		var wild: String = c["wild"] if ap.has_animation(c["wild"]) else calm
		ap.play(calm)
		ap.seek(randf() * ap.get_animation(calm).length, true)
		crowd.append({"ap": ap, "calm": calm, "wild": wild, "sp": randf_range(0.85, 1.15), "fast": c.get("fast", false)})


func _update_crowd() -> void:
	var h := hype / 100.0
	for c in crowd:
		var ap: AnimationPlayer = c["ap"]
		var want: String = c["wild"] if h > 0.6 else c["calm"]
		if ap.current_animation != want:
			ap.play(want, 0.4)
		ap.speed_scale = ((0.8 + h * 0.4) if c["fast"] else (0.35 + h * 0.9)) * c["sp"]


func _make_perf(id: String, is_player: bool) -> Perf:
	var p := Perf.new()
	p.id = id
	p.is_player = is_player
	p.dancer = Dancer.new()
	add_child(p.dancer)
	p.dancer.setup(id)
	return p


# ------------------------------------------------------------------ interfaccia
func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	lbl_p = _label(root, 18, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_p.set_anchors_preset(Control.PRESET_TOP_LEFT)
	lbl_p.position = Vector2(20, 14)
	bar_p = ProgressBar.new()
	bar_p.show_percentage = false
	bar_p.position = Vector2(20, 96)
	bar_p.size = Vector2(240, 10)
	root.add_child(bar_p)
	lbl_o = _label(root, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	lbl_o.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lbl_o.position = Vector2(-340, 14)
	lbl_o.size = Vector2(320, 90)
	lbl_round = _label(root, 18, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_round.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl_round.position = Vector2(-250, 12)
	lbl_round.size = Vector2(500, 80)
	lbl_banner = _label(root, 34, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_banner.set_anchors_preset(Control.PRESET_CENTER)
	lbl_banner.position = Vector2(-500, -140)
	lbl_banner.size = Vector2(1000, 60)
	# pista Guitar Hero
	lane = NoteLane.new()
	lane.battle = self
	lane.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lane.position = Vector2(-300, -120)
	lane.size = Vector2(600, 56)
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lane)
	# pulsanti delle mosse: 4 a sinistra, 4 a destra
	var left := GridContainer.new()
	left.columns = 2
	left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left.position = Vector2(16, -236)
	var right := GridContainer.new()
	right.columns = 2
	right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right.position = Vector2(-16 - 2 * 130 - 8, -236)
	for g in [left, right]:
		g.add_theme_constant_override("h_separation", 8)
		g.add_theme_constant_override("v_separation", 8)
		root.add_child(g)
	var order := [["dance", left], ["gesture", left], ["walk", left], ["mewing", left],
		["aura", right], ["celebrate", right], ["combo", right], ["special", right]]
	for e in order:
		var m: String = e[0]
		var b := Button.new()
		b.text = MOVE_LABELS[m]
		b.custom_minimum_size = Vector2(130, 104)
		b.add_theme_font_size_override("font_size", 18)
		var col := Color(GameData.data["note_colors"].get(m, MOVE_COLS.get(m, "#888888")))
		for st in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(col, 0.35 if st == "normal" else 0.8)
			sb.border_color = col
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(14)
			b.add_theme_stylebox_override(st, sb)
		b.button_down.connect(func():
			held[m] = true
			on_move(m)
		)
		b.button_up.connect(func():
			held.erase(m)
		)
		e[1].add_child(b)


func _label(parent: Control, fs: int, al: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = al
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func banner(text: String, col := Color(1, 0.78, 0.23)) -> void:
	lbl_banner.text = text
	lbl_banner.add_theme_color_override("font_color", col)
	lbl_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(lbl_banner, "modulate:a", 0.0, 0.5)


func popup(text: String, col: Color, fs := 26) -> void:
	var l := _label(ui.get_child(0), fs, HORIZONTAL_ALIGNMENT_CENTER)
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.size = Vector2(600, 40)
	l.position = Vector2(-300, -60 + randf_range(-10, 10))
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 70, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tw.tween_callback(l.queue_free)


## annunciatore (sintesi vocale del telefono)
func say(text: String, force := true) -> void:
	if tts_voice == "" or not GameData.sfx_on:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not force and now - last_voice < 1.4:
		return
	last_voice = now
	if force:
		DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, tts_voice, 80, 0.7, 1.08)


# ------------------------------------------------------------------ flusso dei round
func _start_round() -> void:
	var r: Dictionary = GameData.data["rounds"][round_i]
	banner(r["name"])
	say(["Round one!", "Round two!", "Final round!"][round_i])
	P.score = 0
	O.score = 0
	turn = "player"
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
	banner(("ROUND VINTO! " if pw else "ROUND PERSO ") + "%d - %d" % [P.score, O.score], Color(1, 0.78, 0.23) if pw else Color(0.5, 0.7, 1))
	say(GameData.character(winner.id)["name"].to_lower() + " wins the round!")
	await get_tree().create_timer(2.6).timeout
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
	say("Victory!" if pw else "Defeat...")
	GameData.results.append({"opp": O.id, "win": pw, "ps": P.total, "os": O.total})
	GameData.best_score = maxi(GameData.best_score, P.total)
	GameData.save()
	_show_result(pw)


func _show_result(pw: bool) -> void:
	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.position = Vector2(-260, -220)
	result_panel.custom_minimum_size = Vector2(520, 440)
	ui.add_child(result_panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	result_panel.add_child(vb)
	var t := Label.new()
	t.text = "VITTORIA!" if pw else "SCONFITTA"
	t.add_theme_font_size_override("font_size", 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var acc := _accuracy()
	var g := _grade(acc)
	var gl := Label.new()
	gl.text = g
	gl.add_theme_font_size_override("font_size", 90)
	gl.add_theme_color_override("font_color", Color({"S": "#ffe03c", "A": "#22d36b", "B": "#2f8bff", "C": "#ff7a1a", "D": "#ff3030"}[g]))
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(gl)
	var info := Label.new()
	info.text = "PRECISIONE %d%%\nPERFECT %d  GREAT %d  GOOD %d  MISS %d\n%d - %d   MIGLIOR COMBO x%d" % [acc, stats["p"], stats["g"], stats["ok"], stats["miss"], P.total, O.total, P.best_combo]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(info)
	var last := GameData.opp_index >= GameData.opp_list.size() - 1
	var b1 := Button.new()
	b1.text = ("PROSSIMA SFIDA >" if not last else "TOUR COMPLETATO!") if pw else "RIPROVA"
	b1.custom_minimum_size = Vector2(0, 60)
	b1.pressed.connect(func():
		if pw and not last:
			GameData.opp_index += 1
		if pw and last:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		else:
			get_tree().reload_current_scene()
	)
	vb.add_child(b1)
	var b2 := Button.new()
	b2.text = "< MENU"
	b2.custom_minimum_size = Vector2(0, 50)
	b2.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
	)
	vb.add_child(b2)


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


# ------------------------------------------------------------------ ciclo
func _process(dt: float) -> void:
	if conductor == null or P == null:
		return
	var b := conductor.beat()
	for p in [P, O]:
		p.dancer.position = p.dancer.position.lerp(p.target, 1.0 - pow(0.002, dt))
		if p == active:
			p.dancer.face(camera.global_position * Vector3(1, 0, 1), 0.3)
		elif active:
			p.dancer.face(active.dancer.global_position, 0.8)
		# fine mossa -> continua a ballare per qualche battito, poi riposo
		if p.busy_until > 0 and b >= p.busy_until:
			p.busy_until = -999.0
			p.target = p.home
			p.linger_until = b + 4.0
		if p.linger_until > 0 and b >= p.linger_until:
			p.linger_until = -999.0
			p.dancer.play_state("idle")
		# combo automatica
		if not p.queue.is_empty() and b >= p.queue[0][0]:
			var q: Array = p.queue.pop_front()
			perform(p, q[1], randfn(0.0, 0.02), {"auto": true})
	_update_crowd()
	_update_hud(b)
	match phase:
		"intro":
			if b >= start_beat:
				phase = "perform"
				popup("GO!", Color(1, 0.78, 0.23), 44)
				if turn == "player":
					say("Dance!")
			elif b >= start_beat - 3:
				lbl_banner.text = str(int(ceil(start_beat - b)))
				lbl_banner.modulate.a = 1.0
			if turn == "player":
				_fill_notes(b)
		"perform":
			timer -= dt
			if turn == "player":
				_fill_notes(b)
				_update_notes(b)
			else:
				_ai(b)
			if timer <= 0.0:
				_end_turn()


func _update_hud(_b: float) -> void:
	lbl_p.text = "%s\n%d\nCOMBO x%.2f (%d)" % [GameData.character(P.id)["name"], P.score, 1.0 + 0.15 * mini(P.combo, 10), P.combo]
	lbl_p.add_theme_color_override("font_color", GameData.color_of(P.id))
	bar_p.value = P.meter
	lbl_o.text = "%s\n%d\nAURA %d%%" % [GameData.character(O.id)["name"], O.score, int(O.meter)]
	lbl_o.add_theme_color_override("font_color", GameData.color_of(O.id))
	var r: Dictionary = GameData.data["rounds"][round_i]
	lbl_round.text = "%s - %s\n%ds   ROUND VINTI %d - %d" % [r["name"], "TU" if turn == "player" else "RIVALE", ceili(maxf(timer, 0.0)), round_wins[0], round_wins[1]]


# ------------------------------------------------------------------ note
func _fill_notes(b: float) -> void:
	var prefs: Dictionary = GameData.character(P.id)["prefs"]
	var step := GameData.note_step(round_i)
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
		if n.state == 4:
			if b >= n.beat + n.length:
				n.state = 1
				n.t = Time.get_ticks_msec() / 1000.0
				var bonus := int(160 * (1 + 0.15 * mini(P.combo, 10)))
				P.score += bonus
				P.total += bonus
				popup("HOLD +%d" % bonus, Color(0.49, 0.97, 1))
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


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	for m in GameData.move_ids + ["combo", "special"]:
		if event.is_action_pressed("move_" + m, false):
			on_move(m)


func on_move(m: String) -> void:
	if phase != "perform" or turn != "player":
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
			popup("AURA NON CARICA", Color(0.6, 0.6, 0.6), 18)
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
			_stat(int(P.get_meta("last_q", 0)))
		return
	if n.m == m:
		n.state = 4 if n.length > 0 else 1
		perform(P, m, err, {"gold": n.gold})
		_stat(int(P.get_meta("last_q", 0)))
	else:
		n.state = 2
		popup("MOSSA SBAGLIATA", Color(1, 0.48, 0.54), 18)
		perform(P, m, 0.3)
		_stat(0)


func _do_combo(p: Perf) -> void:
	if p.charges <= 0:
		popup("NO COMBO", Color(0.6, 0.6, 0.6), 18)
		return
	p.charges -= 1
	var seq: Array = ["dance", "gesture", "walk", "mewing"]
	seq.shuffle()
	seq = seq.slice(0, 3)
	var step := GameData.note_step(round_i)
	var nb := ceilf(conductor.beat() + 0.3)
	for i in 3:
		p.queue.append([nb + i * step, seq[i]])
	popup("COMBO CHAIN!", Color(0.18, 0.88, 0.91), 30)
	if p.is_player:
		for n in notes:
			if n.state == 0 and n.beat < nb + step * 3 + 1:
				n.state = 3


# ------------------------------------------------------------------ IA del rivale
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


# ------------------------------------------------------------------ punteggio (uguale per giocatore e IA)
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
	if move_id == "special":
		var bt := roundi(conductor.beat() - err_sec / conductor.beat_len)
		if q >= 2 and posmod(bt, 4) == 0:
			pts += 400
			popup("MAX AURA!", Color(1, 0.88, 0.24), 40)
			if p.is_player:
				say("Max aura!")
		else:
			popup(GameData.character(p.id)["special"], GameData.glow_of(p.id), 34)
		p.meter = 0
	elif move_id == "celebrate":
		hype = clampf(hype + (8 if q >= 2 else 2), 0, 100)
	if opts.get("gold", false):
		pts *= 3
	if opts.get("double", false):
		pts *= 2
	p.set_meta("last_q", q)
	var ipts := int(round(pts))
	p.score += ipts
	p.total += ipts
	p.best_combo = maxi(p.best_combo, p.combo)
	if move_id != "special":
		p.meter = clampf(p.meter + ipts / 9.0, 0, 100)
	hype = clampf(hype - 7 if q == 0 else hype + ipts / 22.0, 0, 100)
	# animazione: dura fino alla nota successiva
	var anim: String = ANIM_OF.get(move_id, "dance")
	if move_id == "gesture":
		anim = "funny" if p.gesture_alt else "sixseven"
		p.gesture_alt = not p.gesture_alt
	var beats_len := float(mv["beats"]) * GameData.note_step(round_i) / 4.0
	p.dancer.play_state(anim)
	p.busy_until = conductor.beat() + beats_len
	p.linger_until = -999.0
	if move_id == "walk":
		p.walk_dir *= -1.0
		p.target = p.home + Vector3(0.5 * p.walk_dir, 0, 0)
	if p.is_player or q >= 3:
		popup(String(j["name"]) + ("!" if q > 0 else "") + "  +%d" % ipts, _judge_col(q))
	if p.is_player and q >= 3 and randf() < 0.3:
		say(["Perfect!", "Clean!", "Nice!"].pick_random(), false)
	return ipts


func _judge_col(q: int) -> Color:
	return [Color(1, 0.48, 0.54), Color(0.72, 1, 0.69), Color(0.49, 0.97, 1), Color(1, 0.88, 0.35)][q]
