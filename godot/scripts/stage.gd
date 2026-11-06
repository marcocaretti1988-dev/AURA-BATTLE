class_name Stage
extends Control
## La piazza in 3D: telecamera, sfondo disegnato, luci, pubblico, cielo stellato,
## aura del ballerino ed effetti (colonna della special, coriandoli, fumo CO2, onda sul cerchio).
## Lo zoom della telecamera usa una proiezione "frustum" spostata: equivale a ingrandire
## l'immagine 2D (come nella versione web), così lo sfondo resta sempre allineato al pavimento.

const CAM_POS := Vector3(0, 0.64, 7.2)
const CAM_LOOK := Vector3(0, 0.78, 0)
const CAM_FOV := 46.0
const BG_DIST := 40.0

var world: Node3D
var base_size := 0.0
var camera: Camera3D
var bg_plane: MeshInstance3D
var bg_mat: StandardMaterial3D
var bg_size := Vector2.ONE
var venue := ""
var crowd: Array = []
var crowd_target = null        # Vector3 verso cui si sposta il pubblico (vincitore) o null
var hype := 50.0
var pulse := 0.0               # 1 sul battito, poi scende
var focus: Node3D = null       # chi balla adesso
var focus_col := Color.WHITE
var focus_meter := 0.0         # barra aura 0..1
var dancing := false           # avvicinamento della telecamera

# telecamera (zoom 2D)
var zoom := 1.0
var zoom_c := Vector2.ZERO
var push := 0.0
var kick_v := 0.0
var shot_t := 0.0
var shot_kind := ""
var shot_target: Node3D = null

# effetti
var sky := {}
var aura_spr: Sprite3D
var sparks: CPUParticles3D
var pillar: MeshInstance3D
var pillar_t := 9.0
var confetti: CPUParticles3D
var co2: Array[CPUParticles3D] = []
var ring: MeshInstance3D
var ring_t := 9.0
var tex_radial: GradientTexture2D
var tex_flare: ImageTexture


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	world = Node3D.new()
	add_child(world)
	tex_radial = _radial()
	tex_flare = _flare_tex()
	_build_world()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()


func _on_resize() -> void:
	_place_background()


func _vsize() -> Vector2:
	return get_viewport().get_visible_rect().size


func _radial() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.45))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


func _flare_tex() -> ImageTexture:
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := (x - n / 2.0) / (n / 2.0)
			var dy := (y - n / 2.0) / (n / 2.0)
			var r := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - r, 0, 1)
			a = a * a * 0.7 + maxf(0, 1.0 - absf(dy) * 14.0) * (1.0 - absf(dx)) + maxf(0, 1.0 - absf(dx) * 14.0) * (1.0 - absf(dy))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0, 1)))
	return ImageTexture.create_from_image(img)


func _add_mat(tex: Texture2D, col := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = tex
	m.albedo_color = col
	m.no_depth_test = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# ------------------------------------------------------------------ mondo
func _build_world() -> void:
	camera = Camera3D.new()
	camera.fov = CAM_FOV
	camera.near = 0.05
	camera.projection = Camera3D.PROJECTION_FRUSTUM
	base_size = 2.0 * camera.near * tan(deg_to_rad(CAM_FOV / 2.0))
	camera.size = base_size
	camera.far = 200.0
	world.add_child(camera)
	camera.position = CAM_POS
	camera.look_at(CAM_LOOK)
	camera.current = true
	bg_mat = StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_plane = MeshInstance3D.new()
	var q := QuadMesh.new()
	var h := 2.0 * BG_DIST * tan(deg_to_rad(CAM_FOV / 2.0)) * 1.7
	bg_size = Vector2(h * 1672.0 / 941.0, h)
	q.size = bg_size
	bg_plane.mesh = q
	bg_plane.material_override = bg_mat
	bg_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(bg_plane)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.01, 0.06)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.85)
	e.ambient_light_energy = 0.95
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
	_build_crowd()
	_build_sky()
	_build_fx()


func set_venue(id: String) -> void:
	venue = id
	bg_mat.albedo_texture = load("res://assets/venues/%s.jpg" % id)
	bg_mat.albedo_color = Color(0.72, 0.72, 0.86) if GameData.is_night() else Color.WHITE
	_place_background()


## il centro del cerchio disegnato nella piazza deve coincidere con il centro del palco 3D
func _place_background() -> void:
	if camera == null:
		return
	var vs := _vsize()
	var cal: Array = GameData.data["venue_calibration"].get(venue, [0.5, 0.67])
	var o := to_screen(Vector3.ZERO)
	var hf := 2.0 * BG_DIST * tan(deg_to_rad(CAM_FOV / 2.0))
	var x := (o.x / vs.x - 0.5) * hf * (vs.x / vs.y)
	var y := -(o.y / vs.y - 0.5) * hf
	bg_plane.position = Vector3(x - (float(cal[0]) - 0.5) * bg_size.x, y - (0.5 - float(cal[1])) * bg_size.y, -BG_DIST)


## posizione sullo schermo (pixel) di un punto 3D, senza lo zoom della telecamera
func to_screen(p: Vector3) -> Vector2:
	var x := camera.unproject_position(p)
	return zoom_c + (x - zoom_c) / zoom if zoom != 1.0 else x


# ------------------------------------------------------------------ pubblico
func _build_crowd() -> void:
	var ids := ["crowdA", "crowdB", "crowdC"]
	var clips: Dictionary = GameData.data["crowd_clips"]
	var spots: Array = []
	for sx in [-1.0, 1.0]:
		for row in [[4.3, 6], [5.4, 7], [6.5, 6]]:
			var n: int = row[1]
			for i in n:
				var a := deg_to_rad(88.0 + i * (62.0 / (n - 1)) + randf_range(-4, 4))
				var r: float = row[0] + randf_range(-0.25, 0.25)
				spots.append(Vector3(sx * r * sin(a), 0, r * cos(a)))
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
		var tint := Color.from_hsv(randf(), randf_range(0.15, 0.45), 1.0) * 1.15
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
				var anim := ap.get_animation_library(lib_name).get_animation(an)
				anim.loop_mode = Animation.LOOP_LINEAR
				Dancer._stay_in_place(anim)
		var calm: String = c["calm"] if ap.has_animation(c["calm"]) else ap.get_animation_list()[0]
		var wild: String = c["wild"] if ap.has_animation(c["wild"]) else calm
		ap.play(calm)
		ap.seek(randf() * ap.get_animation(calm).length, true)
		crowd.append({"node": inst, "ap": ap, "calm": calm, "wild": wild, "sp": randf_range(0.85, 1.15), "fast": c.get("fast", false), "home": spots[i]})


func _update_crowd(dt: float) -> void:
	var h := hype / 100.0
	for c in crowd:
		var ap: AnimationPlayer = c["ap"]
		var want: String = c["wild"] if h > 0.6 else c["calm"]
		if ap.current_animation != want:
			ap.play(want, 0.4)
		ap.speed_scale = ((0.8 + h * 0.4) if c["fast"] else (0.35 + h * 0.9)) * c["sp"]
		var n: Node3D = c["node"]
		var home: Vector3 = c["home"]
		var tgt := home if crowd_target == null else home + (Vector3(crowd_target) - home) * 0.22
		n.position = n.position.lerp(tgt, minf(1.0, dt * 1.5))
		var look := Vector3.ZERO if crowd_target == null else Vector3(crowd_target)
		if focus and crowd_target == null:
			look = focus.global_position
		var ya := atan2(look.x - n.position.x, look.z - n.position.z)
		n.rotation.y = lerp_angle(n.rotation.y, ya, minf(1.0, dt * 3.0))


# ------------------------------------------------------------------ cielo: stelle che brillano, si accendono, cadono
func _build_sky() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = 90
	var q := QuadMesh.new()
	q.size = Vector2.ONE * bg_size.y * 0.012
	mm.mesh = q
	var stars := []
	for i in 90:
		var u := randf()
		var v := 0.02 + pow(randf(), 1.4) * 0.3
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3((u - 0.5) * bg_size.x, (0.5 - v) * bg_size.y, 0.3)))
		stars.append({"ph": randf() * TAU, "sp": randf_range(0.6, 2.2), "b": randf_range(0.5, 1.1)})
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := _add_mat(tex_radial)
	m.vertex_color_use_as_albedo = true
	mmi.material_override = m
	bg_plane.add_child(mmi)
	sky = {"mm": mm, "stars": stars, "flares": [], "shoot": [], "next_flare": 1.0, "next_shoot": 2.0}
	for i in 4:
		var f := MeshInstance3D.new()
		var fq := QuadMesh.new()
		fq.size = Vector2.ONE
		f.mesh = fq
		f.material_override = _add_mat(tex_flare)
		f.visible = false
		bg_plane.add_child(f)
		sky["flares"].append({"n": f, "t": 9.0, "dur": 1.0, "size": 1.0})
	var g := Gradient.new()
	g.set_color(0, Color(0.5, 0.6, 1.0, 0.0))
	g.set_color(1, Color(1, 1, 1, 1))
	var tt := GradientTexture2D.new()
	tt.gradient = g
	tt.width = 128
	tt.height = 8
	for i in 4:
		var s := MeshInstance3D.new()
		var sq := QuadMesh.new()
		sq.size = Vector2.ONE
		s.mesh = sq
		s.material_override = _add_mat(tt)
		s.visible = false
		bg_plane.add_child(s)
		var hd := MeshInstance3D.new()
		var hq := QuadMesh.new()
		hq.size = Vector2.ONE
		hd.mesh = hq
		hd.material_override = _add_mat(tex_flare)
		hd.visible = false
		bg_plane.add_child(hd)
		sky["shoot"].append({"m": s, "h": hd, "t": 9.0, "life": 1.0, "p": Vector2.ZERO, "v": Vector2.ZERO, "len": 1.0})


func shooting_stars(n := 1) -> void:
	for k in n:
		for s in sky["shoot"]:
			if s["t"] >= s["life"]:
				var dir := 1.0 if randf() < 0.5 else -1.0
				var ang := randf_range(0.22, 0.5)
				var sp := bg_size.y * randf_range(0.55, 0.85)
				s["p"] = Vector2(randf_range(-0.35, 0.25) * dir * bg_size.x, (0.5 - randf_range(0.02, 0.14)) * bg_size.y)
				s["v"] = Vector2(cos(ang) * sp * dir, -sin(ang) * sp)
				s["len"] = bg_size.y * randf_range(0.12, 0.22)
				s["life"] = randf_range(0.7, 1.1)
				s["t"] = -k * 0.18
				break


func _update_sky(dt: float, t: float) -> void:
	var mm: MultiMesh = sky["mm"]
	var stars: Array = sky["stars"]
	for i in stars.size():
		var st: Dictionary = stars[i]
		var tw := pow(maxf(0.0, sin(t * st["sp"] + st["ph"])), 4.0)
		var b: float = st["b"] * (0.35 + 0.65 * tw) + pulse * 0.25 * st["b"]
		mm.set_instance_color(i, Color(b, b, b, 1))
	var h := hype / 100.0
	sky["next_flare"] -= dt
	if sky["next_flare"] <= 0:
		sky["next_flare"] = randf_range(0.6, 1.8) * (1.2 - h * 0.6)
		for f in sky["flares"]:
			if f["t"] >= f["dur"]:
				var i := randi() % stars.size()
				f["n"].position = mm.get_instance_transform(i).origin + Vector3(0, 0, 0.05)
				f["t"] = 0.0
				f["dur"] = randf_range(0.8, 1.4)
				f["size"] = bg_size.y * randf_range(0.05, 0.09)
				break
	for f in sky["flares"]:
		f["t"] += dt
		var k: float = sin(PI * f["t"] / f["dur"]) if f["t"] < f["dur"] else 0.0
		f["n"].visible = k > 0.01
		f["n"].scale = Vector3.ONE * f["size"] * (0.3 + k * 0.7)
		f["n"].rotation.z = f["t"] * 0.8
		(f["n"].material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, k)
	sky["next_shoot"] -= dt
	if sky["next_shoot"] <= 0:
		sky["next_shoot"] = randf_range(3.0, 7.0) * (1.25 - h * 0.7)
		shooting_stars(2 if randf() < 0.15 + h * 0.2 else 1)
	for s in sky["shoot"]:
		s["t"] += dt
		var on: bool = s["t"] >= 0 and s["t"] < s["life"]
		s["m"].visible = on
		s["h"].visible = on
		if not on:
			continue
		var p: Vector2 = s["p"] + s["v"] * s["t"]
		var a := sin(PI * s["t"] / s["life"])
		var ang := atan2(s["v"].y, s["v"].x)
		s["m"].scale = Vector3(s["len"], s["len"] * 0.1, 1)
		s["m"].rotation.z = ang
		s["m"].position = Vector3(p.x - cos(ang) * s["len"] / 2.0, p.y - sin(ang) * s["len"] / 2.0, 0.4)
		(s["m"].material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, a)
		s["h"].position = Vector3(p.x, p.y, 0.45)
		s["h"].scale = Vector3.ONE * bg_size.y * 0.05
		(s["h"].material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, a)


# ------------------------------------------------------------------ aura ed effetti
func _build_fx() -> void:
	aura_spr = Sprite3D.new()
	aura_spr.texture = tex_radial
	aura_spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	aura_spr.shaded = false
	aura_spr.pixel_size = 0.04
	aura_spr.centered = true
	aura_spr.modulate = Color(1, 1, 1, 0)
	aura_spr.render_priority = -1
	world.add_child(aura_spr)
	var am := _add_mat(tex_radial)
	am.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	am.vertex_color_use_as_albedo = true
	aura_spr.material_override = am
	sparks = CPUParticles3D.new()
	sparks.amount = 60
	sparks.lifetime = 1.0
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	sparks.emission_ring_axis = Vector3.UP
	sparks.emission_ring_radius = 0.5
	sparks.emission_ring_inner_radius = 0.15
	sparks.emission_ring_height = 0.1
	sparks.direction = Vector3.UP
	sparks.spread = 12
	sparks.gravity = Vector3(0, 0.6, 0)
	sparks.initial_velocity_min = 0.7
	sparks.initial_velocity_max = 1.6
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.0
	var sq := QuadMesh.new()
	sq.size = Vector2.ONE * 0.08
	sparks.mesh = sq
	var spm := _add_mat(tex_radial)
	spm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spm.vertex_color_use_as_albedo = true
	sparks.material_override = spm
	var cr := Gradient.new()
	cr.set_color(0, Color(1, 1, 1, 1))
	cr.set_color(1, Color(1, 1, 1, 0))
	sparks.color_ramp = cr
	world.add_child(sparks)
	# colonna di luce della mossa speciale
	pillar = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 0.6
	cyl.height = 12.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	pillar.mesh = cyl
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 1)
	gt.fill_to = Vector2(0, 0)
	pillar.material_override = _add_mat(gt)
	pillar.visible = false
	world.add_child(pillar)
	# onda sul cerchio
	ring = MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.size = Vector2(2, 2)
	rq.orientation = PlaneMesh.FACE_Y
	ring.mesh = rq
	var rg := Gradient.new()
	rg.offsets = PackedFloat32Array([0.0, 0.78, 0.9, 1.0])
	rg.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var rt := GradientTexture2D.new()
	rt.gradient = rg
	rt.fill = GradientTexture2D.FILL_RADIAL
	rt.fill_from = Vector2(0.5, 0.5)
	rt.fill_to = Vector2(1.0, 0.5)
	ring.material_override = _add_mat(rt)
	ring.visible = false
	world.add_child(ring)
	ring.position.y = 0.02
	# coriandoli
	confetti = CPUParticles3D.new()
	confetti.amount = 160
	confetti.lifetime = 3.0
	confetti.one_shot = true
	confetti.explosiveness = 0.85
	confetti.emitting = false
	confetti.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	confetti.emission_box_extents = Vector3(3.5, 0.2, 1.5)
	confetti.direction = Vector3(0, -1, 0)
	confetti.spread = 30
	confetti.gravity = Vector3(0, -1.6, 0)
	confetti.initial_velocity_min = 0.2
	confetti.initial_velocity_max = 1.0
	confetti.angular_velocity_min = -360
	confetti.angular_velocity_max = 360
	var cq := QuadMesh.new()
	cq.size = Vector2(0.07, 0.04)
	confetti.mesh = cq
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.vertex_color_use_as_albedo = true
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	confetti.material_override = cm
	world.add_child(confetti)
	confetti.position = Vector3(0, 4.2, 0)
	# getti di CO2 ai lati
	for sx in [-2.6, 2.6]:
		var c := CPUParticles3D.new()
		c.amount = 70
		c.lifetime = 1.4
		c.one_shot = true
		c.explosiveness = 0.3
		c.emitting = false
		c.direction = Vector3(-sx * 0.05, 1, 0)
		c.spread = 9
		c.gravity = Vector3(0, -0.4, 0)
		c.initial_velocity_min = 4.0
		c.initial_velocity_max = 6.0
		c.scale_amount_min = 1.0
		c.scale_amount_max = 3.0
		var smq := QuadMesh.new()
		smq.size = Vector2.ONE * 0.35
		c.mesh = smq
		var smm := StandardMaterial3D.new()
		smm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smm.albedo_texture = tex_radial
		smm.albedo_color = Color(0.9, 0.95, 1.0, 0.35)
		smm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		c.material_override = smm
		world.add_child(c)
		c.position = Vector3(sx, 0.1, -0.8)
		co2.append(c)


func fx_ring(col: Color) -> void:
	ring_t = 0.0
	(ring.material_override as StandardMaterial3D).albedo_color = col


func fx_special(col: Color) -> void:
	pillar_t = 0.0
	(pillar.material_override as StandardMaterial3D).albedo_color = col
	fx_confetti(col)
	for c in co2:
		c.restart()
	shooting_stars(3)


func fx_confetti(col: Color) -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([col, Color("#ffc83a"), Color("#ff3b9a"), Color("#2fe0e8"), Color.WHITE])
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	confetti.color_initial_ramp = g
	confetti.restart()


# ------------------------------------------------------------------ telecamera
func kick(v := 1.0) -> void:
	kick_v = maxf(kick_v, v)

func close_up(target: Node3D, dur := 1.3) -> void:
	shot_kind = "close"
	shot_target = target
	shot_t = dur

func fly_in(dur := 2.4) -> void:
	shot_kind = "fly"
	shot_t = dur
	shot_target = null


func _update_camera(dt: float) -> void:
	var z := 1.0
	var vs := _vsize()
	var c := vs * Vector2(0.5, 0.55)
	if shot_t > 0:
		shot_t -= dt
		if shot_kind == "close" and shot_target:
			z = 1.45
			c = to_screen(shot_target.global_position + Vector3(0, 1.2, 0))
		elif shot_kind == "fly":
			z = 1.0 + 0.6 * clampf(shot_t / 2.4, 0, 1)
	elif dancing and focus:
		push = minf(1.0, push + dt * 0.25)
		var p := to_screen(focus.global_position + Vector3(0, 1.05, 0))
		z = 1.0 + 0.13 * push
		c = c.lerp(p, 0.65 * push)
	else:
		push = maxf(0.0, push - dt * 0.8)
	kick_v *= exp(-dt * 5.0)
	z *= 1.0 + kick_v * 0.065
	var k := 1.0 - exp(-dt * 8.0)
	zoom = lerpf(zoom, z, k)
	zoom_c = zoom_c.lerp(c, k) if zoom_c != Vector2.ZERO else c
	# zoom 2D attorno a zoom_c = frustum più piccolo e spostato
	var nc := Vector2(zoom_c.x / vs.x * 2.0 - 1.0, 1.0 - zoom_c.y / vs.y * 2.0)
	var half := base_size / 2.0
	camera.size = base_size / zoom
	camera.frustum_offset = Vector2(nc.x * (zoom - 1.0) / zoom * half * (vs.x / vs.y), nc.y * (zoom - 1.0) / zoom * half)


func _process(dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	pulse = maxf(0.0, pulse - dt * 3.0)
	_update_crowd(dt)
	_update_sky(dt, t)
	_update_camera(dt)
	# aura intorno a chi balla: cresce con la barra aura, a barra piena "brucia"
	var show := focus != null
	aura_spr.visible = show
	sparks.emitting = show
	if show:
		var m := focus_meter
		var full := m >= 1.0
		var fl := (0.75 + sin(t * 23.0) * 0.12 + sin(t * 37.0) * 0.08) if full else 1.0
		aura_spr.global_position = focus.global_position + Vector3(0, 1.1, -0.3)
		aura_spr.pixel_size = 0.03 + m * 0.025
		aura_spr.modulate = Color(focus_col, (0.12 + m * 0.5 + pulse * 0.08) * fl)
		sparks.global_position = focus.global_position
		var sc := focus_col.lightened(0.3) if not full else Color.WHITE.lerp(focus_col, 0.4)
		sparks.color = Color(sc, clampf(0.25 + m * 0.75, 0.0, 1.0))
		sparks.speed_scale = 1.4 if full else 1.0
	# colonna della special
	pillar_t += dt
	pillar.visible = pillar_t < 1.8
	if pillar.visible and focus:
		pillar.global_position = focus.global_position + Vector3(0, 6, 0)
		var a := clampf(1.0 - pillar_t / 1.8, 0, 1)
		var pc := (pillar.material_override as StandardMaterial3D).albedo_color
		(pillar.material_override as StandardMaterial3D).albedo_color = Color(pc, a)
		pillar.scale = Vector3(1.0 + pillar_t, 1, 1.0 + pillar_t)
	ring_t += dt
	ring.visible = ring_t < 0.6
	if ring.visible:
		if focus:
			ring.global_position = Vector3(focus.global_position.x, 0.03, focus.global_position.z)
		var rs := 0.6 + ring_t * 5.0
		ring.scale = Vector3(rs, 1, rs)
		var rc := (ring.material_override as StandardMaterial3D).albedo_color
		(ring.material_override as StandardMaterial3D).albedo_color = Color(rc, 1.0 - ring_t / 0.6)
