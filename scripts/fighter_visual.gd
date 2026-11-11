extends Node2D
## Standing fighter. The body picture changes only when the view, gender, or
## team changes. The hand is a separate sprite, so a sword slash or a wand
## cast is a rotation and does not redraw the canvas.

const Balance = preload("res://scripts/balance.gd")
const ART := "res://assets/art/fighters/game/"
const BODY_H := 1.28
const ARM_LEN := 0.46
const WEAPON_LEN := 0.86

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

var _bob: Node2D
var _body: Sprite2D
var _arm: Node2D
var _hand: Sprite2D
var _weapon: Sprite2D
var _gem: Polygon2D
var _body_key := ""
var _arm_key := ""

static var _cache := {}


func sync_from(u) -> void:
	gender = str(u.gender)
	team = int(u.team)
	facing = float(u.facing)
	move_blend = float(u.move_blend)
	swing = float(u.swing_vis)
	attack_wind = float(u.attack_wind)
	casting = u.cast != null
	channeling = u.channel != null
	dashing = u.dash != null or u.hop != null or u.flight != null
	if u.sim != null and str(u.sim.net_role) == "client":
		var pose := int(u.net_pose)
		casting = pose == 3
		channeling = pose == 4
		dashing = pose == 6
	dead = bool(u.dead)
	carrying = u.carrying != null
	weapon_kind = str(u.weapon)
	ghost = false
	hit_flash = float(u.hit_flash)


func _ready() -> void:
	_bob = Node2D.new()
	_bob.name = "Bob"
	add_child(_bob)
	_body = Sprite2D.new()
	_body.name = "Body"
	_body.centered = true
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_bob.add_child(_body)
	_arm = Node2D.new()
	_arm.name = "Arm"
	_arm.z_index = 2
	_bob.add_child(_arm)
	_weapon = Sprite2D.new()
	_weapon.name = "Weapon"
	_weapon.centered = true
	_weapon.z_index = 1
	_weapon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_arm.add_child(_weapon)
	_hand = Sprite2D.new()
	_hand.name = "Hand"
	_hand.centered = true
	_hand.z_index = 2
	_hand.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_arm.add_child(_hand)
	_gem = Polygon2D.new()
	_gem.polygon = PackedVector2Array([
		Vector2(0.0, -0.1),
		Vector2(0.08, 0.0),
		Vector2(0.0, 0.1),
		Vector2(-0.08, 0.0),
	])
	_gem.color = Color(0.75, 0.95, 1.0)
	_gem.position = Vector2(ARM_LEN * 0.72, 0.0)
	_gem.visible = false
	_gem.z_index = 3
	_arm.add_child(_gem)
	_apply_pictures(true)


func _process(delta: float) -> void:
	if _bob == null:
		return
	if not dead and move_blend > 0.05:
		gait += delta * (2.2 + move_blend * 8.0)
	elif not dead and dashing:
		gait += delta * 10.0
	elif not dead and (casting or channeling):
		gait += delta * 6.0
	_apply_pictures(false)
	var view := _sheet_view()
	var shoulder := Vector2(0.15, -0.74)
	if view == "side":
		shoulder = Vector2(0.12, -0.68)
	elif view == "back":
		shoulder = Vector2(0.16, -0.74)
	_bob.scale = Vector2(-1.0 if _facing_view() == "left" else 1.0, 1.0)
	_arm.position = shoulder
	var dir := _arm_dir()
	_arm.rotation = dir.angle()
	var bounce := 0.0
	if dead:
		bounce = 0.22
	elif move_blend > 0.05:
		bounce = sin(gait) * 0.04 * clampf(move_blend, 0.0, 1.0)
	_bob.position = Vector2(0.0, bounce)
	var lean := Vector2.ZERO
	if dashing and not dead:
		lean = Vector2(cos(facing), sin(facing)) * 0.16
	position = lean
	var tint := Color.WHITE
	if dead:
		tint = Color(0.55, 0.56, 0.62, 0.75)
	elif ghost:
		tint = Color(0.75, 0.93, 1.0, 0.72)
	if hit_flash > 0.0:
		tint = tint.lerp(Color.WHITE, 0.7)
	_bob.modulate = tint
	_gem.visible = carrying and not dead
	_weapon.visible = not carrying and not dead and weapon_kind != "none"
	_hand.visible = not dead
	_body.visible = true


func _apply_pictures(force: bool) -> void:
	var view := _sheet_view()
	var who := "male" if gender == "male" else "female"
	var team_i := 0 if team == 0 else 1
	var body_key := "%s-%d-%s" % [who, team_i, view]
	if force or body_key != _body_key:
		_body_key = body_key
		var body_tex := _tex("body-%s.png" % body_key)
		_body.texture = body_tex
		if body_tex != null:
			var s := BODY_H / float(body_tex.get_height())
			_body.scale = Vector2(s, s)
			_body.position = Vector2(0.0, -BODY_H * 0.5)
	var arm_name := "arm-wand.png" if weapon_kind == "wand" else "arm-sword.png"
	var weapon_name := "weapon-wand.png" if weapon_kind == "wand" else "weapon-sword.png"
	var arm_key := arm_name + weapon_name
	if not force and arm_key == _arm_key:
		return
	_arm_key = arm_key
	var hand_tex := _tex(arm_name)
	_hand.texture = hand_tex
	if hand_tex != null:
		var hs := ARM_LEN / float(hand_tex.get_width())
		_hand.scale = Vector2(hs, hs)
		_hand.offset = Vector2(hand_tex.get_width() * 0.5, 0.0)
	var weapon_tex := _tex(weapon_name)
	_weapon.texture = weapon_tex
	if weapon_tex != null:
		var ws := WEAPON_LEN / float(weapon_tex.get_width())
		_weapon.scale = Vector2(ws, ws)
		_weapon.offset = Vector2(weapon_tex.get_width() * 0.5, 0.0)
		_weapon.position = Vector2(0.12, 0.0)


func _sheet_view() -> String:
	var view := _facing_view()
	if view == "left" or view == "right":
		return "side"
	return view


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


func _arm_dir() -> Vector2:
	return Vector2(sin(_arm_angle()), cos(_arm_angle()))


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
		return PI + sin(gait) * 0.1
	if casting:
		return lerpf(1.15, 2.35, 0.5 + 0.5 * sin(gait * 2.0))
	if dashing:
		return 0.35
	return 0.5 + sin(gait) * 0.42 * move_blend


func _tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := ART + name
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_cache[name] = tex
	return tex
