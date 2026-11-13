extends Node2D
## Ground fire, shots, and skill shapes. Painted effects while something is
## on screen. No per-flame buffer, particle, or extra canvas item.

const Balance = preload("res://scripts/balance.gd")
const State = preload("res://scripts/state.gd")
const ART := "res://assets/art/fighters/game/"

var sim: Node = null
var _lane = null
var _font: Font
var _drawing := false
var _dot := PackedVector2Array([
	Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO,
	Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO,
])
var _quad := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _tri := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _pent := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _loop := PackedVector2Array([
	Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO,
	Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO,
])

static var _circle := PackedVector2Array()
var _art := {}


func _ready() -> void:
	sim = get_parent()
	_font = ThemeDB.fallback_font
	z_index = 20
	if _circle.is_empty():
		for i in 8:
			var a := TAU * float(i) / 8.0
			_circle.append(Vector2(cos(a), sin(a)))
	_load_art()


func _process(_delta: float) -> void:
	var draw := _needs_draw()
	if draw or _drawing:
		queue_redraw()
	_drawing = draw


func _needs_draw() -> bool:
	if sim == null or sim.get("phase") == "boot":
		return false
	if not sim.fires.is_empty() or not sim.shots.is_empty() or not sim.mega_fx.is_empty():
		return true
	if not sim.saber_fx.is_empty() or not sim.bursts.is_empty() or not sim.floats.is_empty():
		return true
	if not sim.skill_fx.is_empty():
		return true
	for u in sim.units:
		if u.channel != null or u.cast != null or int(u.net_skill) != 0:
			return true
	for k in sim.keeps:
		if float(k["cap"]) > 0.0:
			return true
	for d in sim.diamonds:
		if float(d.bank) > 0.05 and d.carrier != null:
			return true
	return false


func _blob(at: Vector2, radius: float, color: Color) -> void:
	for i in 8:
		var c: Vector2 = _circle[i]
		_dot[i] = at + c * radius
	draw_colored_polygon(_dot, color)


func _ring(at: Vector2, radius: float, color: Color, width: float) -> void:
	for i in 8:
		_loop[i] = at + _circle[i] * radius
	_loop[8] = _loop[0]
	draw_polyline(_loop, color, width, true)


func _draw() -> void:
	if sim == null or sim.get("phase") == "boot":
		return
	for f in sim.fires:
		_fire(f)
	for s in sim.shots:
		if s.kind == "fireball":
			_fireball(s)
		elif s.kind == "gem":
			_gem(s.pos)
	for u in sim.units:
		var skill := _live_skill(u)
		var beam = _beam_lane(u)
		if skill == "mega":
			_mega_ring(u)
		elif beam != null:
			_saber(beam, Color(1.0, 0.97, 0.62, 0.28), Color(1.0, 0.82, 0.02, 1.0), Color(1.0, 0.95, 0.75, 0.35))
		elif skill != "":
			_prepare(u, skill)
	for fx in sim.mega_fx:
		_blast(fx)
	for cast_fx in sim.skill_fx:
		_strike(cast_fx)
	for fx in sim.saber_fx:
		var a2 := clampf(float(fx.t) / float(fx.dur), 0.0, 1.0)
		_saber(fx, Color(1.0, 0.95, 0.7, 0.45 * a2), Color(1.0, 0.95, 0.55, 0.9 * a2), Color(1.0, 1.0, 0.9, 0.85 * a2))
	for k in sim.keeps:
		if float(k["cap"]) <= 0.0:
			continue
		var door: float = k["door"]
		var at: Vector2 = k["pos"] + Vector2(cos(door), sin(door)) * (float(k["r"]) + 0.15)
		var col := Color(0.95, 0.3, 0.45) if int(k["cap_team"]) == 0 else Color(0.35, 0.75, 1.0)
		draw_arc(at, 0.55, -PI * 0.5, -PI * 0.5 + TAU * float(k["cap"]) / 3.0, 18, col, 0.08, true)
	for i in sim.diamonds.size():
		var d = sim.diamonds[i]
		if float(d.bank) <= 0.05 or d.carrier == null:
			continue
		var vault = sim.vaults[d.carrier.team]
		var col2 := Color(1.0, 0.85, 0.35, 0.9)
		draw_arc(vault["pos"], float(vault["r"]), -PI * 0.5, -PI * 0.5 + TAU * float(d.bank) / 10.0, 28, col2, 0.07, true)
	for p in sim.bursts:
		var c: Color = p.color
		c.a = clampf(float(p.t) / 0.35, 0.0, 1.0)
		_blob(p.pos, float(p.r), c)
	if _font == null:
		return
	for f2 in sim.floats:
		var col3: Color = f2.color
		col3.a = clampf(float(f2.t) / 0.28, 0.0, 1.0)
		draw_set_transform(f2.pos, 0.0, Vector2(0.022, 0.022))
		draw_string(_font, Vector2(-8, 0), str(f2.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col3)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _fire(f) -> void:
	var life := clampf(float(f.t) / 2.4, 0.0, 1.0)
	if life <= 0.02:
		return
	var at: Vector2 = f.pos
	var radius := float(f.r)
	var tex: Texture2D = _art.get("ember-left")
	if tex == null:
		_blob(at, radius, Color(0.75, 0.16, 0.03, 0.55 * life))
		var salt := int(absf(at.x * 17.0 + at.y * 9.0))
		var side := 0.12 if ((int(life * 16.0) + salt) & 1) == 0 else -0.12
		_blob(at + Vector2(side, -radius * 0.42), radius * 0.5, Color(1.0, 0.78, 0.22, 0.92 * life))
		return
	_paint(tex, at, Vector2(radius * 2.6, radius * 2.6), 0.0, life)


func _fireball(s) -> void:
	var at: Vector2 = s.pos
	var vel := Vector2(float(s.vx), float(s.vy))
	var speed := vel.length()
	var dir := Vector2.RIGHT
	if speed > 0.001:
		dir = vel / speed
	var tex: Texture2D = _art.get("fireball-active")
	if tex == null:
		_blob(at - dir * 0.42, 0.16, Color(1.0, 0.3, 0.04, 0.4))
		_blob(at, 0.28, Color(1.0, 0.46, 0.08, 0.94))
		_blob(at + dir * 0.1, 0.12, Color(1.0, 0.97, 0.76, 0.96))
		return
	_paint(tex, at, Vector2(3.7, 2.3), dir.angle(), 1.0)


func _gem(at: Vector2) -> void:
	_quad[0] = at + Vector2(0.0, -0.24)
	_quad[1] = at + Vector2(0.16, 0.0)
	_quad[2] = at + Vector2(0.0, 0.24)
	_quad[3] = at + Vector2(-0.16, 0.0)
	draw_colored_polygon(_quad, Color(0.72, 0.96, 1.0, 0.95))
	_tri[0] = at + Vector2(-0.06, -0.1)
	_tri[1] = at + Vector2(0.07, -0.02)
	_tri[2] = at + Vector2(0.0, 0.08)
	draw_colored_polygon(_tri, Color(1.0, 1.0, 1.0, 0.88))


func _mega_zone(at: Vector2, radius: float, pulse: float, fade: float) -> void:
	if fade <= 0.02 or radius <= 0.01:
		return
	var span := radius * pulse
	_blob(at, span, Color(1.0, 0.24, 0.12, 0.18 * fade))
	_blob(at, span * 0.38, Color(1.0, 0.62, 0.18, 0.22 * fade))
	_ring(at, span, Color(1.0, 0.9, 0.45, 0.9 * fade), 0.16)
	_ring(at, span * 0.72, Color(1.0, 0.4, 0.14, 0.75 * fade), 0.08)


func _saber(ch, fill: Color, edge: Color, core: Color) -> void:
	var ang := float(ch.ang)
	var fwd := Vector2(cos(ang), sin(ang))
	var side := Vector2(-fwd.y, fwd.x)
	var half := float(ch.w) * 0.5
	var origin: Vector2 = ch.pos
	var length := float(ch.len)
	_quad[0] = origin + side * half
	_quad[1] = _quad[0] + fwd * length
	_quad[2] = origin - side * half + fwd * length
	_quad[3] = origin - side * half
	draw_colored_polygon(_quad, fill)
	_pent[0] = _quad[0]
	_pent[1] = _quad[1]
	_pent[2] = _quad[2]
	_pent[3] = _quad[3]
	_pent[4] = _quad[0]
	draw_polyline(_pent, edge, 0.28, true)
	draw_line((_quad[0] + _quad[3]) * 0.5, (_quad[1] + _quad[2]) * 0.5, core, 0.1, true)
	draw_line(_quad[1], _quad[2], Color(1.0, 0.9, 0.1, edge.a), 0.36, true)


func _beam_lane(u):
	if u.channel != null and str(u.channel.kind) == "saber":
		return u.channel
	if int(u.net_pose) != 4 or int(u.net_skill) != 3:
		return null
	if _lane == null:
		_lane = State.new()
	_lane.pos = u.global_position
	_lane.ang = u.facing
	_lane.len = Balance.SABER_LEN
	_lane.w = Balance.SABER_W
	return _lane


func _load_art() -> void:
	for skill in ["ignite", "spark", "ember", "fireball", "ice", "mega"]:
		for stage in ["prepare", "active", "left"]:
			var key := "%s-%s" % [skill, stage]
			var path := ART + "skill-%s.png" % key
			if ResourceLoader.exists(path):
				_art[key] = load(path)


func _live_skill(u) -> String:
	if u.cast != null:
		return str(u.cast.name)
	if u.channel != null and str(u.channel.kind) == "mega":
		return "mega"
	var id := int(u.net_skill)
	if id > 0 and id < Balance.NET_SKILL_IDS.size():
		return str(Balance.NET_SKILL_IDS[id])
	return ""


func _prepare(u, skill: String) -> void:
	var fwd := Vector2(cos(u.facing), sin(u.facing))
	var at: Vector2 = u.global_position
	if skill == "ignite":
		_paint(_art.get("ignite-prepare"), at + fwd * 0.8, Vector2(0.7, 0.7), 0.0, 0.95)
	elif skill == "spark":
		draw_line(at, at + fwd * Balance.DASH_DIST, Color(0.75, 0.92, 1.0, 0.7), 0.14, true)
	elif skill == "ember":
		_paint(_art.get("ember-prepare"), at, Vector2(1.15, 0.75), 0.0, 0.9)
	elif skill == "fireball":
		_paint(_art.get("fireball-prepare"), at + fwd * 0.75, Vector2(0.9, 0.75), 0.0, 0.95)
	elif skill == "ice":
		_paint(_art.get("ice-prepare"), at + fwd * 0.65, Vector2(0.95, 0.8), 0.0, 0.9)


func _mega_ring(u) -> void:
	var fwd := Vector2(cos(u.facing), sin(u.facing))
	var pos: Vector2 = u.global_position + fwd * Balance.MEGA_AHEAD
	var rad := Balance.MEGA_RADIUS
	if u.channel != null:
		pos = u.channel.pos
		rad = float(u.channel.r)
	var pulse := 0.82 + 0.18 * absf(sin(float(sim.time) * 6.0))
	var tex: Texture2D = _art.get("mega-prepare")
	if tex == null:
		_mega_zone(pos, rad * pulse, 1.0, 0.9)
		return
	_paint(tex, pos, Vector2(rad * 2.0 * pulse, rad * 2.0 * pulse), 0.0, 0.94)


func _blast(fx) -> void:
	var dur := float(fx.dur) if float(fx.dur) > 0.0 else 1.7
	var life := clampf(float(fx.t) / dur, 0.0, 1.0)
	var rad := float(fx.r)
	var at: Vector2 = fx.pos
	var boom: Texture2D = _art.get("mega-active")
	var crater: Texture2D = _art.get("mega-left")
	if boom == null or crater == null:
		var k := 1.0 - life
		_mega_zone(at, rad * (0.2 + 0.85 * k), 1.0, life)
		return
	if life > 0.38:
		_paint(boom, at, Vector2(rad * 2.15, rad * 2.35), 0.0, 1.0)
	if life < 0.72:
		var fade := 1.0 if life < 0.38 else (0.72 - life) / 0.34
		_paint(crater, at, Vector2(rad * 1.55, rad * 1.55), 0.0, fade)


func _strike(fx) -> void:
	var dur := float(fx.dur) if float(fx.dur) > 0.0 else 0.64
	var life := clampf(float(fx.t) / dur, 0.0, 1.0)
	var kind := str(fx.kind)
	var active := life > 0.42
	var stage := "active" if active else "left"
	var alpha := 1.0 if active else clampf(life / 0.42, 0.0, 1.0)
	var ang := float(fx.ang)
	var fwd := Vector2(cos(ang), sin(ang))
	var at: Vector2 = fx.pos
	var size := Vector2(1.3, 1.3)
	var rot := 0.0
	if kind == "ignite":
		size = Vector2(1.5, 1.5)
		rot = ang
		at += fwd * 0.45
	elif kind == "spark":
		size = Vector2(8.0, 0.45)
		rot = ang
		at += fwd * 4.0
	elif kind == "ember":
		size = Vector2(1.6, 1.2)
		rot = ang
	elif kind == "ice":
		size = Vector2(1.7, 1.45) if active else Vector2(1.35, 1.15)
	_paint(_art.get("%s-%s" % [kind, stage]), at, size, rot, alpha)


func _paint(tex: Texture2D, at: Vector2, size: Vector2, ang: float, alpha: float) -> void:
	if tex == null or alpha <= 0.02:
		return
	draw_set_transform(at, ang, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-size * 0.5, size), false, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
