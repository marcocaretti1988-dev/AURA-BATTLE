class_name NoteLane
extends Control
## Pista stile Guitar Hero: le note scorrono da destra verso il cerchio bianco.
## Ogni nota ha il colore della sua mossa. Bordo d'oro = vale x3, due cerchi = doppia (x2),
## coda = nota lunga da tenere premuta.

var battle: Node          # la scena Battle (per conductor, note, velocità)
var flash := {}           # mossa -> tempo dell'ultimo colpo riuscito
var icons := {}

func _icon(m: String) -> Texture2D:
	if not icons.has(m):
		icons[m] = load("res://assets/ui/icons/%s.png" % m)
	return icons[m]

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if battle == null or battle.conductor == null:
		return
	var w := size.x
	var h := size.y
	var ly := h * 0.5
	var tx := h * 0.75
	var ahead: float = battle.lane_ahead
	var ppb := (w - tx - h * 0.4) / ahead
	var b: float = battle.conductor.beat()
	var pulse := pow(1.0 - fposmod(b, 1.0), 3.0)
	var r := h * 0.36
	# fondo
	draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.02, 0.11, 0.85))
	draw_rect(Rect2(0, 0, w, h), Color(0.6, 0.65, 1.0, 0.45), false, 1.5)
	# righe dei battiti
	var k := ceili(b)
	while k < b + ahead:
		var x := tx + (k - b) * ppb
		var c := Color(1, 0.78, 0.23, 0.45) if k % 4 == 0 else Color(1, 1, 1, 0.13)
		draw_line(Vector2(x, h * 0.12), Vector2(x, h * 0.88), c, 1.0)
		k += 1
	# bersaglio
	draw_arc(Vector2(tx, ly), r + pulse * 2.0, 0, TAU, 32, Color(1, 1, 1, 0.65 + pulse * 0.35), 3.0)
	# note
	for n in battle.notes:
		if n.state == 3:
			continue
		var x: float = tx + (n.beat - b) * ppb
		var col: Color = Color(GameData.data["note_colors"][n.m])
		if n.state == 1:
			var a: float = 1.0 - (Time.get_ticks_msec() / 1000.0 - n.t) / 0.35
			if a > 0:
				draw_circle(Vector2(tx, ly), r * (1.0 + (1.0 - a)), Color(col, a))
			continue
		var miss: bool = n.state == 2 or n.state == 5
		if n.length > 0:
			var xs: float = tx if n.state == 4 else x
			var xe: float = minf(w - 8, tx + (n.beat + n.length - b) * ppb)
			if xe > xs:
				draw_rect(Rect2(xs, ly - r * 0.5, xe - xs, r), Color(col, 0.55) if not miss else Color(0.3, 0.3, 0.3, 0.4))
			if n.state == 4:
				draw_circle(Vector2(tx, ly), r + pulse * 2.0, col)
				continue
		if x > w - 6 or x < -r:
			continue
		var cc := Color(0.33, 0.33, 0.33, 0.35) if miss else col
		if n.m2 != "":
			var c2: Color = Color(GameData.data["note_colors"][n.m2])
			draw_circle(Vector2(x, ly - r * 0.55), r * 0.7, cc if not n.got.has(n.m) else Color(cc, 0.35))
			draw_circle(Vector2(x, ly + r * 0.55), r * 0.7, (c2 if not miss else cc) if not n.got.has(n.m2) else Color(c2, 0.35))
		else:
			draw_circle(Vector2(x, ly), r, cc)
			draw_arc(Vector2(x, ly), r, 0, TAU, 24, Color(1, 0.88, 0.24) if n.gold and not miss else Color.BLACK, 3.0 if n.gold else 2.0)
			if n.gold and not miss:
				draw_arc(Vector2(x, ly), r + 3 + pulse * 2, 0, TAU, 24, Color(1, 0.88, 0.24, 0.4 + pulse * 0.6), 1.5)
		# icona della mossa al centro della nota
		if n.m2 == "":
			draw_texture_rect(_icon(n.m), Rect2(x - r * 0.75, ly - r * 0.75, r * 1.5, r * 1.5), false)
		else:
			draw_texture_rect(_icon(n.m), Rect2(x - r * 0.5, ly - r * 1.05, r, r), false)
			draw_texture_rect(_icon(n.m2), Rect2(x - r * 0.5, ly + r * 0.05, r, r), false)
