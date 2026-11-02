class_name Dancer
extends Node3D
## Un personaggio Meshy (GLB riggato con tutti i balli).
## - assegna a ogni mossa del gioco le sue animazioni (data/game_data.json -> characters.<id>.anims)
## - toglie lo spostamento del corpo (root motion) così balla sul posto
## - la coreografia continua da dove era rimasta e resta sullo stesso ballo finché non è finito
## - lo tiene sopra il pavimento (le mosse a terra non finiscono sotto la piazza)

const TARGET_HEIGHT := 1.75

var id := ""
var anims: Dictionary = {}
var model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var anim_state := "idle"
var cur_clip := ""
var stick: Dictionary = {}     # mossa -> [clip, velocità] scelto
var pos: Dictionary = {}       # clip -> punto della coreografia
var played: Dictionary = {}    # clip -> secondi già ballati
var base_y := 0.0


func setup(char_id: String) -> void:
	id = char_id
	anims = GameData.character(id)["anims"]
	model = load("res://assets/characters/%s.glb" % id).instantiate()
	add_child(model)
	player = model.find_children("*", "AnimationPlayer", true, false)[0]
	var sk := model.find_children("*", "Skeleton3D", true, false)
	skeleton = sk[0] if sk.size() > 0 else null
	_prepare_animations()
	_fit_height()
	play_state("idle")


func _prepare_animations() -> void:
	for lib_name in player.get_animation_library_list():
		var lib := player.get_animation_library(lib_name)
		for n in lib.get_animation_list():
			var a: Animation = lib.get_animation(n)
			a.loop_mode = Animation.LOOP_LINEAR
			_stay_in_place(a)


## toglie la deriva orizzontale dei fianchi (resta l'oscillazione del ballo)
static func _stay_in_place(a: Animation) -> void:
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		if not String(a.track_get_path(t)).to_lower().ends_with("hips"):
			continue
		var n := a.track_get_key_count(t)
		if n < 2:
			continue
		var p0: Vector3 = a.track_get_key_value(t, 0)
		var p1: Vector3 = a.track_get_key_value(t, n - 1)
		for k in n:
			var f := float(k) / float(n - 1)
			var v: Vector3 = a.track_get_key_value(t, k)
			v.x -= p0.x + (p1.x - p0.x) * f
			v.z -= p0.z + (p1.z - p0.z) * f
			a.track_set_key_value(t, k, v)


func _fit_height() -> void:
	var box := AABB()
	var first := true
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if box.size.y > 0.01:
		var k := TARGET_HEIGHT / box.size.y
		model.scale = Vector3.ONE * k
		model.position.y = -box.position.y * k
		base_y = model.position.y


## sceglie la clip per una mossa: resta sullo stesso ballo finché la coreografia non è finita
func _pick(state: String) -> Array:
	var list: Array = anims.get(state, anims.get("idle", []))
	list = list.filter(func(e): return player.has_animation(e[0]))
	if list.is_empty():
		return [player.get_animation_list()[0], 1.0]
	var st: Array = stick.get(state, [])
	if not st.is_empty() and list.any(func(e): return e[0] == st[0]) and not _done(st[0]):
		return st
	var nxt: Array = list.pick_random()
	if not st.is_empty() and list.size() > 1:
		var i := list.map(func(e): return e[0]).find(st[0])
		nxt = list[(i + 1) % list.size()]
	pos[nxt[0]] = 0.0
	played[nxt[0]] = 0.0
	stick[state] = nxt
	return nxt

func _done(clip: String) -> bool:
	return played.get(clip, 0.0) >= player.get_animation(clip).length - 0.15


## fa partire l'animazione di una mossa (idle, dance, sixseven, funny, walk, mewing, aura, win, lose, menu, entrance)
func play_state(state: String, blend := 0.2) -> void:
	var pk := _pick(state)
	var clip: String = pk[0]
	var spd: float = pk[1]
	anim_state = state
	if clip == cur_clip:
		player.speed_scale = spd
		return
	if cur_clip != "":
		pos[cur_clip] = player.current_animation_position
	cur_clip = clip
	player.play(clip, blend)
	player.speed_scale = spd
	player.seek(pos.get(clip, 0.0), true)


func freeze() -> void:
	player.pause()


func _process(dt: float) -> void:
	if cur_clip != "" and player.is_playing():
		played[cur_clip] = played.get(cur_clip, 0.0) + dt * player.speed_scale
	_ground_lock()


## alza il modello se un osso (mani, testa nelle mosse a terra) scende sotto il pavimento
func _ground_lock() -> void:
	if skeleton == null:
		return
	model.position.y = base_y
	var min_y := INF
	for b in skeleton.get_bone_count():
		var y := (skeleton.global_transform * skeleton.get_bone_global_pose(b)).origin.y
		min_y = minf(min_y, y)
	var lift := global_position.y + 0.04 - min_y
	if lift > 0.0:
		model.position.y += lift / maxf(scale.y, 0.001)


## gira il personaggio verso un punto del palco
func face(target: Vector3, amount := 1.0) -> void:
	var d := target - global_position
	rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z) * amount, 0.15)
