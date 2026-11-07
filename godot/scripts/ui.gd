extends Node
## Autoload "UI": stile grafico (font pixel, pulsanti colorati), suoni, voce dell'annunciatore.

const COL_GOLD := Color("#ffc83a")
const COL_PANEL := Color(0.05, 0.03, 0.13, 0.92)
const COL_EDGE := Color("#6a3df0")
const MOVE_COLS := {"dance": "#2f8bff", "gesture": "#ff3b9a", "walk": "#22d36b", "mewing": "#ffe02a",
	"aura": "#a845ff", "celebrate": "#ff7a1a", "combo": "#16e3e8", "special": "#ff3030"}

var font: FontFile
var theme: Theme
var sounds := {}
var pool: Array[AudioStreamPlayer] = []
var crowd_loop: AudioStreamPlayer
var tts_voice := ""
var last_voice := 0.0


func _ready() -> void:
	font = load("res://assets/fonts/PressStart2P-Regular.ttf")
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 15
	theme.set_stylebox("normal", "Button", _box(Color(0.12, 0.06, 0.3, 0.92), COL_EDGE))
	theme.set_stylebox("hover", "Button", _box(Color(0.2, 0.1, 0.42, 0.95), COL_GOLD))
	theme.set_stylebox("pressed", "Button", _box(Color(0.35, 0.16, 0.6, 1.0), COL_GOLD))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("disabled", "Button", _box(Color(0.08, 0.06, 0.14, 0.7), Color(0.25, 0.22, 0.35)))
	theme.set_color("font_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.6))
	theme.set_stylebox("panel", "PanelContainer", _box(COL_PANEL, COL_EDGE, 3, 12))
	theme.set_constant("outline_size", "Label", 6)
	theme.set_color("font_outline_color", "Label", Color.BLACK)
	get_tree().root.theme = theme
	for f in DirAccess.get_files_at("res://assets/sfx"):
		var n := f.trim_suffix(".import")
		if n.ends_with(".wav") and not sounds.has(n.get_basename()):
			sounds[n.get_basename()] = load("res://assets/sfx/" + n)
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	crowd_loop = AudioStreamPlayer.new()
	crowd_loop.stream = sounds.get("crowd_loop")
	crowd_loop.finished.connect(func(): crowd_loop.play())
	crowd_loop.volume_db = -80
	add_child(crowd_loop)
	var voices := DisplayServer.tts_get_voices_for_language("en")
	tts_voice = voices[0] if voices.size() > 0 else ""


func _box(bg: Color, edge: Color, bw := 3, r := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(bw)
	s.set_corner_radius_all(r)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


## i testi sono più grandi per lo schermo del telefono
const FONT_K := 1.3

func fs_k(fs: int) -> int:
	return int(round(fs * FONT_K))


func t(text: String) -> String:
	return GameData.tr_text(text)


## pulsante del menu
func button(text: String, cb: Callable, gold := false, min_size := Vector2(0, 46), fs := 13) -> Button:
	var b := Button.new()
	b.text = t(text)
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", fs_k(fs))
	if gold:
		b.add_theme_stylebox_override("normal", _box(Color(0.42, 0.28, 0.05, 0.95), COL_GOLD))
	b.pressed.connect(func():
		sfx("click")
		cb.call()
	)
	return b


## pulsante colorato di una mossa (con icona)
func move_button(move_id: String, label: String) -> Button:
	var col := Color(MOVE_COLS[move_id])
	var b := Button.new()
	b.text = label
	b.icon = load("res://assets/ui/icons/%s.png" % move_id)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_font_size_override("font_size", fs_k(10))
	b.add_theme_constant_override("icon_max_width", 30)
	b.add_theme_stylebox_override("normal", _box(Color(col.darkened(0.45), 0.85), col, 3, 14))
	b.add_theme_stylebox_override("hover", _box(Color(col.darkened(0.3), 0.9), col.lightened(0.3), 3, 14))
	b.add_theme_stylebox_override("pressed", _box(col, Color.WHITE, 4, 14))
	b.add_theme_stylebox_override("disabled", _box(Color(0.1, 0.08, 0.16, 0.7), Color(col, 0.35), 3, 14))
	b.focus_mode = Control.FOCUS_NONE
	return b


func label(text: String, fs := 12, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = t(text)
	l.add_theme_font_size_override("font_size", fs_k(fs))
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func panel() -> PanelContainer:
	var p := PanelContainer.new()
	return p


## suoni
func sfx(name: String, db := 0.0, pitch := 1.0) -> void:
	if not GameData.sfx_on or not sounds.has(name):
		return
	for p in pool:
		if not p.playing:
			p.stream = sounds[name]
			p.volume_db = db
			p.pitch_scale = pitch
			p.play()
			return


## brusio del pubblico: volume che segue l'hype (0..100), -1 = spento
func crowd_level(h: float) -> void:
	if crowd_loop.stream == null:
		return
	if not crowd_loop.playing:
		crowd_loop.play()
	var target := -80.0 if (h < 0 or not GameData.sfx_on) else lerpf(-24.0, -8.0, h / 100.0)
	crowd_loop.volume_db = lerpf(crowd_loop.volume_db, target, 0.05)


## annunciatore (sintesi vocale del telefono)
func say(text: String, force := false) -> void:
	if tts_voice == "" or not GameData.voice_on:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not force and now - last_voice < 1.4:
		return
	last_voice = now
	if force:
		DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, tts_voice, 80, 0.7, 1.08)
