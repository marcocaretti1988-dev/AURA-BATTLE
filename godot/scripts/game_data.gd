extends Node
## Autoload "GameData": tutti i dati del gioco (letti da data/game_data.json)
## + lo stato condiviso tra le scene (personaggio scelto, piazza, tour, impostazioni).

const DATA_PATH := "res://data/game_data.json"
const SAVE_PATH := "user://aura_battle_save.cfg"

var data: Dictionary = {}
var char_ids: Array = []
var venue_ids: Array = []
var move_ids: Array = ["dance", "gesture", "walk", "mewing", "aura", "celebrate"]

# stato della partita
var sel_char: String = "jester"
var venue_sel: String = "tour"        # "tour" oppure l'id di una piazza
var difficulty: String = "normal"     # easy / normal / hard
var opp_list: Array = []
var opp_index: int = 0
var tour_order: Array = []
var results: Array = []
var music_on := true
var sfx_on := true
var best_score := 0


func _ready() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	data = JSON.parse_string(f.get_as_text())
	char_ids = data["characters"].keys()
	venue_ids = data["venues"].keys()
	_load_save()
	_setup_input()


func character(id: String) -> Dictionary:
	return data["characters"][id]

func color_of(id: String) -> Color:
	return Color(character(id)["color"])

func glow_of(id: String) -> Color:
	var g: Array = character(id)["glow"]
	return Color8(int(g[0]), int(g[1]), int(g[2]))

func move(id: String) -> Dictionary:
	return data["moves"][id]

func venue(id: String) -> Dictionary:
	return data["venues"][id]

func song_for_venue(v: String) -> String:
	var s: String = data["venue_song"].get(v, "milano")
	return s if data["songs"].has(s) else "milano"


## --- Tour d'Italia: lista dei rivali e piazza di ogni sfida ---
func start_tour() -> void:
	opp_list = char_ids.filter(func(c): return c != sel_char)
	opp_list.shuffle()
	opp_list = opp_list.slice(0, int(data.get("rivals", 5)))
	opp_index = 0
	results.clear()
	tour_order = venue_ids.duplicate()
	tour_order.shuffle()

func current_venue() -> String:
	if venue_sel != "tour":
		return venue_sel
	return tour_order[opp_index % tour_order.size()]

func current_opp() -> String:
	return opp_list[opp_index]


## --- velocità della pista: sale sfida dopo sfida ---
func speed_level(round_index: int) -> int:
	var l := opp_index + (1 if round_index == 2 else 0)
	if difficulty == "hard":
		l += 1
	elif difficulty == "easy":
		l -= 1
	return clampi(l, 0, data["speed_step"].size() - 1)

func note_step(round_index: int) -> int:
	return int(data["speed_step"][speed_level(round_index)])

func lane_ahead(round_index: int) -> float:
	return float(data["speed_ahead"][speed_level(round_index)])


## --- giudizio del tempismo (errore in secondi) ---
func judge(err_sec: float) -> Dictionary:
	var e := absf(err_sec)
	for j in data["judge"]:
		if e <= float(j["max_err"]):
			return j
	return data["judge"][-1]


## --- salvataggio ---
func _load_save() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) == OK:
		best_score = c.get_value("game", "best", 0)
		music_on = c.get_value("game", "music", true)
		sfx_on = c.get_value("game", "sfx", true)
		difficulty = c.get_value("game", "difficulty", "normal")

func save() -> void:
	var c := ConfigFile.new()
	c.set_value("game", "best", best_score)
	c.set_value("game", "music", music_on)
	c.set_value("game", "sfx", sfx_on)
	c.set_value("game", "difficulty", difficulty)
	c.save(SAVE_PATH)


## --- tasti da tastiera (1-6 mosse, C combo, Spazio special, Esc pausa) ---
func _setup_input() -> void:
	var keys := {
		"move_dance": KEY_1, "move_gesture": KEY_2, "move_walk": KEY_3, "move_mewing": KEY_4,
		"move_aura": KEY_5, "move_celebrate": KEY_6, "move_combo": KEY_C, "move_special": KEY_SPACE, "pause": KEY_ESCAPE,
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			var ev := InputEventKey.new()
			ev.physical_keycode = keys[a]
			InputMap.action_add_event(a, ev)
