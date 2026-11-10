extends Node2D
## Chunky fighter drawn in the match. Legs, the free arm, and the sword arm
## move with the walk, the swing windup, and the skill casts.

const Balance = preload("res://scripts/balance.gd")

var gender := "female"
var team := 0
var facing := 0.0
var move_blend := 0.0
var swing := 0.0
var attack_wind := 0.0
var casting := false
var channeling := false
var dashing := false
var dead := false
var carrying := false
var weapon_kind := "none"
var ghost := false
var hit_flash := 0.0
var gait := 0.0

var _flip := 1.0
var _origin := Vector2.ZERO
var _pose := -1
var _oval_pts := PackedVector2Array([
	Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO,
	Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO,
])
var _quad := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])

static var _circle := PackedVector2Array()


func sync_from(u) -> void:
	gender = str(u.gender)
	team = int(u.team)
	facing = float(u.facing)
	move_blend = float(u.move_blend)
	swing = float(u.swing_vis)
	attack_wind = float(u.attack_wind)
	casting = u.cast != null
	channeling = u.channel != null
	dashing = u.dash != null
	dead = bool(u.dead)
	carrying = u.carrying != null
	weapon_kind = str(u.weapon)
	ghost = false
	hit_flash = float(u.hit_flash)


func _ready() -> void:
	_ensure_circle()


func _ensure_circle() -> void:
	if not _circle.is_empty():
		return
	for i in 8:
		var a := TAU * float(i) / 8.0
		_circle.append(Vector2(cos(a), sin(a)))


func _process(delta: float) -> void:
	_ensure_circle()
	var moving := (move_blend > 0.05 and not dead) or casting or channeling
	if move_blend > 0.05 and not dead:
		gait += delta * (2.2 + move_blend * 8.0)
	elif casting or channeling:
		gait += delta * 6.0
	var step := 0
	if moving:
		step = int(gait * 1.5) & 7
	var pose := step
	pose = pose * 4 + _view_id()
	pose = pose * 3 + _weapon_id()
	pose = pose * 8 + mini(int(swing * 12.0), 7)
	pose = pose * 8 + mini(int(attack_wind * 12.0), 7)
	if dead:
		pose += 100000
	if carrying:
		pose += 200000
	if casting:
		pose += 400000
	if channeling:
		pose += 800000
	if dashing:
		pose += 1600000
	if ghost:
		pose += 3200000
	if hit_flash > 0.0:
		pose += 6400000
	if gender == "male":
		pose += 12800000
	if team == 1:
		pose += 25600000
	if pose == _pose:
		return
	_pose = pose
	queue_redraw()


func _draw() -> void:
	var view := _facing_view()
	_flip = -1.0 if view == "left" else 1.0
	var lean := Vector2(cos(facing), sin(facing)) * (0.16 if dashing else 0.0)
	_origin = lean + Vector2(0.0, 0.32 if dead else 0.0)
	var skin := _ink(Color(0.97, 0.78, 0.62))
	var skin_hi := _ink(Color(1.0, 0.9, 0.76))
	var cloth := _ink(Color(0.36, 0.2, 0.48) if gender == "male" else Color(0.94, 0.9, 0.8))
	var cloth_hi := _ink(cloth.lightened(0.2))
	var pants := _ink(Color(0.24, 0.16, 0.4) if gender == "male" else Color(0.13, 0.2, 0.42))
	var boot := _ink(Color(0.32, 0.18, 0.12) if gender == "male" else Color(0.1, 0.16, 0.36))
	var hair := _ink(Color(0.34, 0.18, 0.12) if gender == "male" else Color(0.07, 0.1, 0.24))
	var scarf := _ink(Color(0.82, 0.16, 0.24) if team == 0 else Color(0.2, 0.5, 0.9))
	var outline := _ink(Color(0.09, 0.06, 0.12))
	_oval(Vector2(0.0, 0.08), 0.38, 0.12, _ink(Color(0.05, 0.1, 0.05, 0.38)))
	if swing > 0.0 or attack_wind > 0.0:
		_oval(Vector2(0.15, -0.35), 0.78, 0.58, _ink(Color(1.0, 0.82, 0.28, 0.38)))
	elif casting:
		_oval(Vector2(0.0, -0.42), 0.7, 0.55, _ink(Color(1.0, 0.5, 0.16, 0.42)))
	elif channeling:
		_oval(Vector2(0.0, -0.42), 0.86, 0.64, _ink(Color(1.0, 0.28, 0.22, 0.4)))
	var stride := sin(gait) * 0.62 * clampf(move_blend, 0.0, 1.0)
	if dead:
		stride = 0.85
	_leg(Vector2(-0.1, -0.3), -stride, pants, boot, outline)
	if view == "back":
		_sword_arm(outline, skin)
	else:
		_off_arm(outline, skin)
	_oval(Vector2(0.0, -0.52), 0.32, 0.36, outline)
	_oval(Vector2(0.0, -0.52), 0.27, 0.31, cloth)
	_oval(Vector2(-0.07, -0.64), 0.12, 0.1, cloth_hi)
	_leg(Vector2(0.1, -0.28), stride, pants, boot, outline)
	_oval(Vector2(0.02, -0.72), 0.16, 0.08, scarf)
	if gender == "female":
		_oval(Vector2(-0.3, -0.78), 0.11, 0.16, hair)
		_oval(Vector2(-0.22, -1.08), 0.1, 0.08, _ink(Color(0.2, 0.5, 0.9)))
	_oval(Vector2(0.0, -0.96), 0.25, 0.23, outline)
	_oval(Vector2(0.0, -0.96), 0.21, 0.19, skin)
	_oval(Vector2(-0.06, -1.04), 0.08, 0.06, skin_hi)
	if gender == "female":
		_oval(Vector2(-0.02, -1.08), 0.24, 0.14, hair)
	else:
		_oval(Vector2(0.0, -1.1), 0.22, 0.12, hair)
	if view == "back":
		_oval(Vector2(0.0, -1.02), 0.2, 0.14, hair)
	else:
		_oval(Vector2(-0.08, -0.98), 0.04, 0.045, outline)
		_oval(Vector2(0.07, -0.98), 0.04, 0.045, outline)
		_oval(Vector2(-0.07, -0.99), 0.014, 0.014, _ink(Color.WHITE))
		_oval(Vector2(0.08, -0.99), 0.014, 0.014, _ink(Color.WHITE))
		_sword_arm(outline, skin)


func _view_id() -> int:
	var view := _facing_view()
	if view == "back":
		return 1
	if view == "right":
		return 2
	if view == "left":
		return 3
	return 0


func _weapon_id() -> int:
	if weapon_kind == "sword":
		return 1
	if weapon_kind == "wand":
		return 2
	return 0


func _facing_view() -> String:
	var names: PackedStringArray = PackedStringArray(["front", "back", "right", "left"])
	var angles: Array[float] = [PI * 0.5, -PI * 0.5, 0.0, PI]
	var best := "front"
	var best_d := 99.0
	for i in names.size():
		var d := absf(Balance.ang_diff(facing, angles[i]))
		if d < best_d:
			best_d = d
			best = names[i]
	return best


func _arm_angle() -> float:
	if dead:
		return 0.2
	if attack_wind > 0.0:
		var wind := clampf(1.0 - attack_wind / 0.28, 0.0, 1.0)
		return lerpf(0.55, -1.7, wind)
	if swing > 0.0:
		var slash := 1.0 - clampf(swing / 0.26, 0.0, 1.0)
		return lerpf(-1.7, 1.9, slash)
	if channeling:
		return -0.35 + sin(gait) * 0.2
	if casting:
		return lerpf(0.2, -1.7, 0.5 + 0.5 * sin(gait * 3.0))
	return 0.5 + sin(gait) * 0.42 * move_blend


func _off_arm(outline: Color, skin: Color) -> void:
	var angle := 0.55 - sin(gait) * 0.4 * move_blend
	if swing > 0.0 or attack_wind > 0.0 or casting:
		angle = 0.15
	var shoulder := Vector2(-0.16, -0.6)
	var dir := Vector2(sin(angle) * -1.0, cos(angle))
	var hand := shoulder + dir * 0.26
	var sleeve := _ink(Color(0.28, 0.16, 0.12) if gender == "male" else Color(0.12, 0.18, 0.4))
	_capsule(shoulder, hand, 0.065, outline)
	_capsule(shoulder, hand, 0.05, sleeve)
	_oval(hand, 0.055, 0.055, skin)


func _sword_arm(outline: Color, skin: Color) -> void:
	var angle := _arm_angle()
	var shoulder := Vector2(0.16, -0.62)
	var dir := Vector2(sin(angle), cos(angle))
	var hand := shoulder + dir * 0.3
	var sleeve := _ink(Color(0.28, 0.16, 0.12) if gender == "male" else Color(0.12, 0.18, 0.4))
	_capsule(shoulder, hand, 0.075, outline)
	_capsule(shoulder, hand, 0.058, sleeve)
	_oval(hand, 0.06, 0.06, skin)
	if carrying:
		var gem := hand + Vector2(0.02, 0.1)
		draw_colored_polygon(PackedVector2Array([
			_p(gem + Vector2(0.0, -0.12)),
			_p(gem + Vector2(0.09, 0.0)),
			_p(gem + Vector2(0.0, 0.12)),
			_p(gem + Vector2(-0.09, 0.0))
		]), _ink(Color(0.75, 0.95, 1.0)))
		return
	if weapon_kind == "wand":
		var wand_tip := hand + dir * 0.72
		_capsule(hand, wand_tip, 0.035, _ink(Color(0.42, 0.28, 0.62)))
		_oval(wand_tip, 0.09, 0.09, _ink(Color(0.55, 0.86, 1.0)))
		return
	if weapon_kind != "sword":
		return
	var tip := hand + dir * 0.98
	var n := Vector2(-dir.y, dir.x)
	var steel := _ink(Color(1.0, 0.62, 0.16))
	var edge := _ink(Color(1.0, 0.92, 0.45))
	draw_colored_polygon(PackedVector2Array([
		_p(hand + n * 0.055),
		_p(hand - n * 0.055),
		_p(tip - n * 0.02),
		_p(tip + n * 0.02)
	]), steel)
	draw_colored_polygon(PackedVector2Array([
		_p(hand + n * 0.02),
		_p(hand),
		_p(tip),
		_p(tip + n * 0.016)
	]), edge)
	_capsule(hand - n * 0.09, hand + n * 0.09, 0.028, _ink(Color(0.45, 0.28, 0.14)))


func _leg(hip: Vector2, angle: float, pants: Color, boot: Color, outline: Color) -> void:
	var dir := Vector2(sin(angle), cos(angle))
	var knee := hip + dir * 0.22
	var foot := hip + dir * 0.42
	_capsule(hip, knee, 0.09, outline)
	_capsule(hip, knee, 0.07, pants)
	_capsule(knee, foot, 0.08, outline)
	_capsule(knee, foot, 0.06, boot)
	_oval(foot + Vector2(dir.x * 0.02, 0.02), 0.1, 0.05, boot)


func _capsule(a: Vector2, b: Vector2, radius: float, color: Color) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 0.001:
		_oval(a, radius, radius, color)
		return
	var dir := delta / length
	var n := Vector2(-dir.y, dir.x) * radius
	_quad[0] = _p(a + n)
	_quad[1] = _p(a - n)
	_quad[2] = _p(b - n)
	_quad[3] = _p(b + n)
	draw_colored_polygon(_quad, color)


func _oval(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var at := _p(center)
	var sx := rx * _flip
	for i in 8:
		var c: Vector2 = _circle[i]
		_oval_pts[i] = at + Vector2(c.x * sx, c.y * ry)
	draw_colored_polygon(_oval_pts, color)


func _p(point: Vector2) -> Vector2:
	return _origin + Vector2(point.x * _flip, point.y)


func _ink(color: Color) -> Color:
	if hit_flash > 0.0:
		color = color.lerp(Color.WHITE, 0.7)
	if ghost:
		color = color.lerp(Color(0.7, 0.93, 1.0), 0.4)
		color.a *= 0.7
	elif dead:
		color = color.lerp(Color(0.4, 0.42, 0.48), 0.45)
		color.a *= 0.72
	return color
