extends RefCounted
## Four painted layers per skill: glow, body, core, sparks.
## Black in the art adds nothing, so the layers stack as light.

const Balance = preload("res://scripts/balance.gd")

const TEX := {
	"ignite": [
		preload("res://assets/vfx/ignite_0.png"),
		preload("res://assets/vfx/ignite_1.png"),
		preload("res://assets/vfx/ignite_2.png"),
		preload("res://assets/vfx/ignite_3.png"),
	],
	"fireball": [
		preload("res://assets/vfx/fireball_0.png"),
		preload("res://assets/vfx/fireball_1.png"),
		preload("res://assets/vfx/fireball_2.png"),
		preload("res://assets/vfx/fireball_3.png"),
	],
	"ice": [
		preload("res://assets/vfx/ice_0.png"),
		preload("res://assets/vfx/ice_1.png"),
		preload("res://assets/vfx/ice_2.png"),
		preload("res://assets/vfx/ice_3.png"),
	],
	"mega": [
		preload("res://assets/vfx/mega_0.png"),
		preload("res://assets/vfx/mega_1.png"),
		preload("res://assets/vfx/mega_2.png"),
		preload("res://assets/vfx/mega_3.png"),
	],
	"spark": [
		preload("res://assets/vfx/spark_0.png"),
		preload("res://assets/vfx/spark_1.png"),
		preload("res://assets/vfx/spark_2.png"),
		preload("res://assets/vfx/spark_3.png"),
	],
	"ember": [
		preload("res://assets/vfx/ember_0.png"),
		preload("res://assets/vfx/ember_1.png"),
		preload("res://assets/vfx/ember_2.png"),
		preload("res://assets/vfx/ember_3.png"),
	],
}

const MARK := {
	"ignite-prepare": preload("res://assets/art/fighters/game/skill-ignite-prepare.png"),
	"ignite-active": preload("res://assets/art/fighters/game/skill-ignite-active.png"),
	"ignite-left": preload("res://assets/art/fighters/game/skill-ignite-left.png"),
	"spark-prepare": preload("res://assets/art/fighters/game/skill-spark-prepare.png"),
	"spark-active": preload("res://assets/art/fighters/game/skill-spark-active.png"),
	"spark-left": preload("res://assets/art/fighters/game/skill-spark-left.png"),
	"ember-prepare": preload("res://assets/art/fighters/game/skill-ember-prepare.png"),
	"ember-active": preload("res://assets/art/fighters/game/skill-ember-active.png"),
	"ember-left": preload("res://assets/art/fighters/game/skill-ember-left.png"),
	"fireball-prepare": preload("res://assets/art/fighters/game/skill-fireball-prepare.png"),
	"fireball-active": preload("res://assets/art/fighters/game/skill-fireball-active.png"),
	"fireball-left": preload("res://assets/art/fighters/game/skill-fireball-left.png"),
	"ice-prepare": preload("res://assets/art/fighters/game/skill-ice-prepare.png"),
	"ice-active": preload("res://assets/art/fighters/game/skill-ice-active.png"),
	"ice-left": preload("res://assets/art/fighters/game/skill-ice-left.png"),
	"mega-prepare": preload("res://assets/art/fighters/game/skill-mega-prepare.png"),
	"mega-active": preload("res://assets/art/fighters/game/skill-mega-active.png"),
	"mega-left": preload("res://assets/art/fighters/game/skill-mega-left.png"),
}

var root: Node3D
var quads: Array = []
var planes: Array = []
var quad_mesh: QuadMesh
var plane_mesh: PlaneMesh
var nq := 0
var np := 0


func setup(fx_root: Node3D) -> void:
	root = fx_root
	quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2.ONE
	plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2.ONE


func reset() -> void:
	quads.clear()
	planes.clear()
	nq = 0
	np = 0


func draw(sim, camera: Camera3D) -> void:
	nq = 0
	np = 0
	if root == null or camera == null or sim == null:
		_hide()
		return
	var time: float = float(sim.time)
	var client := str(sim.net_role) == "client"
	for u in sim.units:
		if u == null or not is_instance_valid(u):
			continue
		_unit(u, camera, time, client)
	for fx in sim.skill_fx:
		var fade: float = clampf(float(fx.t) / maxf(0.05, float(fx.dur)), 0.0, 1.0)
		_burst(str(fx.kind), fx.pos, float(fx.ang), fade, camera, time)
	for fx2 in sim.saber_fx:
		var fade2: float = clampf(float(fx2.t) / maxf(0.05, float(fx2.dur)), 0.0, 1.0)
		_saber_look(camera, fx2.pos, float(fx2.ang), float(fx2.len), fade2, time)
	for fx3 in sim.mega_fx:
		var fade3: float = clampf(float(fx3.t) / maxf(0.05, float(fx3.dur)), 0.0, 1.0)
		var span: float = float(fx3.r) * 2.0 * (0.7 + 0.3 * fade3)
		_disc("mega", fx3.pos, span, fade3 * 0.55, time)
		var boom: String = "mega-active" if fade3 > 0.4 else "mega-left"
		_flat(MARK[boom], fx3.pos, span * 0.92, 0.0, fade3)
		_face(camera, MARK[boom], Vector3(fx3.pos.x, 2.4, fx3.pos.y), Vector2(span * 0.5, span * 0.5), 0.0, fade3)
	for s in sim.shots:
		if str(s.kind) != "fireball":
			continue
		var vel := Vector2(float(s.vx), float(s.vy))
		var speed: float = vel.length()
		var dir := Vector2.RIGHT
		if speed > 0.05:
			dir = vel / speed
		var shot_ang: float = dir.angle()
		_billboard(camera, "fireball", Vector3(s.pos.x, 0.95, s.pos.y), 1.35, 0.7, time)
		_face(camera, MARK["fireball-active"], Vector3(s.pos.x, 1.15, s.pos.y), Vector2(3.6, 2.3), shot_ang, 1.0)
		for step in 3:
			var back: Vector2 = s.pos - dir * (0.7 * float(step + 1))
			var trail: float = 0.42 - float(step) * 0.1
			_face(camera, MARK["fireball-left"], Vector3(back.x, 0.9, back.y), Vector2(1.8, 1.2), shot_ang, trail)
	for f in sim.fires:
		var life: float = clampf(float(f.t) / 2.4, 0.0, 1.0)
		_disc("ignite", f.pos, float(f.r) * 2.4, life * 0.85, time * 0.6)
	_hide()


func _unit(u, camera: Camera3D, time: float, client: bool) -> void:
	var at: Vector2 = u.global_position
	var facing: float = float(u.facing)
	_swing(u, camera, client)
	if float(u.fire_sword_t) > 0.0 and int(u.fire_sword_hits) > 0:
		var fwd := Vector2(cos(facing), sin(facing)) * 0.45
		_billboard(camera, "ignite", Vector3(at.x + fwd.x, 1.15, at.y + fwd.y), 1.45, 0.8, time)
		_face(camera, MARK["ignite-prepare"], Vector3(at.x + fwd.x, 1.25, at.y + fwd.y), Vector2(1.15, 1.15), facing, 0.9)
	if u.dash != null:
		_ribbon(camera, "spark", u.dash.from_pos, float(u.dash.dir), float(u.dash.dist), 1.7, 1.0, time)
		_lane(u.dash.from_pos, float(u.dash.dir), float(u.dash.dist), 1.35, Color(0.65, 0.92, 1.0, 0.28))
		_face(camera, MARK["spark-active"], Vector3(at.x, 1.2, at.y), Vector2(3.4, 1.05), float(u.dash.dir), 1.0)
	elif client and int(u.net_pose) == 6 and int(u.net_skill) == 2:
		var back := Vector2(cos(facing), sin(facing)) * (Balance.DASH_DIST * 0.5)
		_ribbon(camera, "spark", at - back, facing, Balance.DASH_DIST, 1.7, 1.0, time)
		_lane(at - back, facing, Balance.DASH_DIST, 1.35, Color(0.65, 0.92, 1.0, 0.28))
		_face(camera, MARK["spark-active"], Vector3(at.x, 1.2, at.y), Vector2(3.4, 1.05), facing, 1.0)
	if u.channel != null and str(u.channel.kind) == "saber":
		_saber_look(camera, u.channel.pos, float(u.channel.ang), float(u.channel.len), 1.0, time)
	elif client and int(u.net_pose) == 4 and int(u.net_skill) == 3:
		_saber_look(camera, at, facing, Balance.SABER_LEN, 1.0, time)
	if u.channel != null and str(u.channel.kind) == "mega":
		var pulse := 0.86 + 0.14 * sin(time * 6.0)
		var mega_at: Vector2 = u.channel.pos
		var mega_d: float = float(u.channel.r) * 2.0 * pulse
		_disc("mega", mega_at, mega_d, 0.35, time)
		_flat(MARK["mega-prepare"], mega_at, mega_d, time * 0.4, 0.95)
	elif client and int(u.net_pose) == 4 and int(u.net_skill) == 6:
		var ahead := Vector2(cos(facing), sin(facing)) * Balance.MEGA_AHEAD
		var pulse2 := 0.86 + 0.14 * sin(time * 6.0)
		var mega_at2: Vector2 = at + ahead
		var mega_d2: float = Balance.MEGA_RADIUS * 2.0 * pulse2
		_disc("mega", mega_at2, mega_d2, 0.35, time)
		_flat(MARK["mega-prepare"], mega_at2, mega_d2, time * 0.4, 0.95)
	if u.cast != null:
		_casting(u, at, facing, camera, time)
	var icy := false
	for c in u.clones:
		if not bool(c.alive) or float(c.hp) <= 0.0:
			continue
		icy = true
		var cp: Vector2 = c.pos
		_billboard(camera, "ice", Vector3(cp.x, 0.9, cp.y), 0.85, 0.45, time + float(c.side))
		_face(camera, MARK["ice-active"], Vector3(cp.x, 1.05, cp.y), Vector2(1.55, 1.35), facing + float(c.side), 0.95)
	if icy:
		_disc("ice", at, 2.8, 0.35, time)
		_flat(MARK["ice-prepare"], at, 2.8, time * 0.3, 0.8)


func _casting(u, at: Vector2, facing: float, camera: Camera3D, time: float) -> void:
	var name := str(u.cast.name)
	var dur: float = maxf(0.05, float(u.cast.dur))
	var along: float = clampf(1.0 - float(u.cast.t) / dur, 0.0, 1.0)
	var fwd := Vector2(cos(facing), sin(facing))
	if name == "ignite":
		_billboard(camera, "ignite", Vector3(at.x, 1.2, at.y), 1.1 + along * 0.4, 0.55, time)
		_face(camera, MARK["ignite-prepare"], Vector3(at.x, 1.3, at.y), Vector2(1.5 + along * 0.6, 1.5 + along * 0.6), facing, 0.95)
	elif name == "spark":
		_ribbon(camera, "spark", at, facing, Balance.DASH_DIST, 1.35, 0.35 + along * 0.45, time)
		_lane(at, facing, Balance.DASH_DIST, 1.2, Color(0.62, 0.9, 1.0, 0.16 + along * 0.22))
		_face(camera, MARK["spark-prepare"], Vector3(at.x, 1.15, at.y), Vector2(2.4 + along, 0.8), facing, 0.9)
	elif name == "ember":
		_saber_look(camera, at, facing, Balance.SABER_LEN, 0.45 + along * 0.4, time)
	elif name == "fireball":
		var hand: Vector2 = at + fwd * 0.7
		_billboard(camera, "fireball", Vector3(hand.x, 1.05, hand.y), 0.7 + along * 0.35, 0.55, time)
		_face(camera, MARK["fireball-prepare"], Vector3(hand.x, 1.15, hand.y), Vector2(1.5 + along * 0.7, 1.15 + along * 0.4), facing, 0.95)
	elif name == "ice":
		_disc("ice", at + fwd * 0.4, 1.6 + along * 1.2, 0.4, time)
		_flat(MARK["ice-prepare"], at + fwd * 0.4, 1.8 + along * 1.4, facing, 0.92)
	elif name == "mega":
		var spot: Vector2 = at + fwd * Balance.MEGA_AHEAD
		var grow: float = Balance.MEGA_RADIUS * 2.0 * (0.35 + along * 0.65)
		_disc("mega", spot, grow, 0.3, time)
		_flat(MARK["mega-prepare"], spot, grow, time * 0.5, 0.9)


func _burst(kind: String, pos: Vector2, ang: float, fade: float, camera: Camera3D, time: float) -> void:
	if kind == "ignite":
		_billboard(camera, "ignite", Vector3(pos.x, 1.2, pos.y), 2.3, fade * 0.6, time)
		_face(camera, MARK["ignite-active"], Vector3(pos.x, 1.25, pos.y), Vector2(2.6, 2.6), ang, fade)
	elif kind == "spark":
		_ribbon(camera, "spark", pos, ang, Balance.DASH_DIST, 1.55, fade, time)
		_face(camera, MARK["spark-active"], Vector3(pos.x, 1.2, pos.y), Vector2(3.8, 1.15), ang, fade)
	elif kind == "ice":
		_disc("ice", pos, 3.4, fade * 0.55, time)
		_flat(MARK["ice-active"], pos, 3.6, ang, fade)
	elif kind == "ember":
		_billboard(camera, "ember", Vector3(pos.x, 1.1, pos.y), 1.6, fade * 0.5, time)
		_face(camera, MARK["ember-active"], Vector3(pos.x, 1.3, pos.y), Vector2(2.4, 1.8), ang, fade)
	elif kind == "fireball":
		_face(camera, MARK["fireball-left"], Vector3(pos.x, 1.2, pos.y), Vector2(2.8, 1.8), ang, fade)
	elif kind == "mega":
		_flat(MARK["mega-active"], pos, 4.5, ang, fade)


func _swing(u, camera: Camera3D, client: bool) -> void:
	var vis := float(u.swing_vis)
	var posing: bool = client and int(u.net_pose) == 2 and vis <= 0.02
	if vis <= 0.02 and not posing:
		return
	var fade := 0.9 if posing else clampf(vis / 0.26, 0.0, 1.0)
	var at: Vector2 = u.global_position
	var facing: float = float(u.facing)
	var kind := str(u.swing_kind)
	if posing:
		kind = "rect" if str(u.weapon) == "wand" else "arc"
	if kind == "rect":
		var length := float(u.swing_len)
		var width := float(u.swing_width)
		if length < 0.2:
			length = Balance.WAND_LEN
		if width < 0.2:
			width = Balance.WAND_W
		_lane(at, facing, length, width, Color(0.55, 0.86, 1.0, 0.34 * fade))
		var tip: Vector2 = at + Vector2(cos(facing), sin(facing)) * length * 0.62
		_face(camera, MARK["ice-active"], Vector3(tip.x, 1.15, tip.y), Vector2(2.1, 1.8), facing, 0.9 * fade)
		return
	if kind != "arc":
		return
	var reach := float(u.swing_range)
	if reach < 0.2:
		reach = Balance.SWORD_RANGE if str(u.weapon) == "sword" else Balance.FIST_RANGE
	var hot: bool = float(u.fire_sword_t) > 0.0 and int(u.fire_sword_hits) > 0
	var stamp: String = "ignite-active" if str(u.weapon) == "sword" or hot else "spark-active"
	var fwd := Vector2(cos(facing), sin(facing)) * reach * 0.42
	var wide: float = reach * 2.35
	_face(camera, MARK[stamp], Vector3(at.x + fwd.x, 1.1, at.y + fwd.y), Vector2(wide, wide), facing, (1.0 if hot else 0.82) * fade)


func _saber_look(camera: Camera3D, origin: Vector2, ang: float, length: float, alpha: float, time: float) -> void:
	_lane(origin, ang, length, Balance.SABER_W, Color(1.0, 0.9, 0.4, 0.3 * alpha))
	_ribbon(camera, "ember", origin, ang, length, 1.85, 0.95 * alpha, time)
	var mid: Vector2 = origin + Vector2(cos(ang), sin(ang)) * length * 0.5
	_face(camera, MARK["ember-active"], Vector3(mid.x, 1.35, mid.y), Vector2(2.2, 1.7), ang, 0.75 * alpha)


func _face(camera: Camera3D, tex: Texture2D, pos: Vector3, size: Vector2, ang: float, alpha: float) -> void:
	if tex == null or alpha <= 0.02:
		return
	var node := _quad()
	node.global_transform = Transform3D(camera.global_basis, pos)
	node.scale = Vector3(size.x, size.y, 1.0)
	var fwd := Vector3(cos(ang), 0.0, sin(ang))
	var sx: float = fwd.dot(camera.global_basis.x)
	var sy: float = fwd.dot(camera.global_basis.y)
	node.rotate_object_local(Vector3(0, 0, 1), atan2(sy, sx))
	_paint(node, tex, alpha, 0.0, false)


func _flat(tex: Texture2D, pos: Vector2, diameter: float, ang: float, alpha: float) -> void:
	if tex == null or alpha <= 0.02:
		return
	var along := Vector3(cos(ang), 0.0, sin(ang))
	var side := Vector3(-along.z, 0.0, along.x)
	var node := _plane()
	node.scale = Vector3.ONE
	node.global_transform = Transform3D(Basis(side * diameter, Vector3.UP, along * diameter), Vector3(pos.x, 0.08, pos.y))
	_paint(node, tex, alpha, 0.0, false)


func _lane(origin: Vector2, ang: float, length: float, width: float, color: Color) -> void:
	if length < 0.05 or width < 0.05 or color.a <= 0.02:
		return
	var along := Vector3(cos(ang), 0.0, sin(ang))
	var side := Vector3(-along.z, 0.0, along.x)
	var mid := Vector3(origin.x, 0.1, origin.y) + along * (length * 0.5)
	var node := _plane()
	node.scale = Vector3.ONE
	node.global_transform = Transform3D(Basis(side * width, Vector3.UP, along * length), mid)
	_wash(node, color)


func _wash(node: MeshInstance3D, color: Color) -> void:
	var mat: StandardMaterial3D = node.material_override
	mat.albedo_texture = null
	mat.albedo_color = color
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.uv1_offset = Vector3.ZERO


func _billboard(camera: Camera3D, key: String, pos: Vector3, size: float, alpha: float, time: float) -> void:
	var scales := [1.28, 1.0, 0.58, 1.1]
	var amounts := [0.48, 0.9, 1.0, 0.72]
	var spins := [0.2, 0.65, -0.9, 1.7]
	for i in 4:
		var node := _quad()
		var s: float = size * float(scales[i])
		node.global_transform = Transform3D(camera.global_basis, pos + camera.global_basis.z * (0.015 * float(i)))
		node.scale = Vector3(s, s, 1.0)
		node.rotate_object_local(Vector3(0, 0, 1), time * float(spins[i]))
		var a: float = alpha * float(amounts[i])
		if i == 0:
			a *= 0.78 + 0.22 * sin(time * 4.0)
		elif i == 3:
			a *= 0.55 + 0.45 * absf(sin(time * 11.0))
		_paint(node, TEX[key][i], a, 0.0)


func _disc(key: String, pos: Vector2, diameter: float, alpha: float, time: float) -> void:
	var scales := [1.32, 1.0, 0.52, 1.16]
	var amounts := [0.4, 0.82, 0.95, 0.7]
	var spins := [0.15, 0.4, -0.7, 1.15]
	for i in 4:
		var node := _plane()
		var d: float = diameter * float(scales[i])
		node.rotation = Vector3(0.0, time * float(spins[i]), 0.0)
		node.scale = Vector3(d, 1.0, d)
		node.position = Vector3(pos.x, 0.06 + float(i) * 0.018, pos.y)
		var a: float = alpha * float(amounts[i])
		if i == 3:
			a *= 0.6 + 0.4 * absf(sin(time * 8.0))
		_paint(node, TEX[key][i], a, 0.0)


func _ribbon(camera: Camera3D, key: String, origin: Vector2, ang: float, length: float, thick: float, alpha: float, time: float) -> void:
	var along := Vector3(cos(ang), 0.0, sin(ang))
	var mid := Vector3(origin.x, 0.85, origin.y) + along * (length * 0.5)
	var normal := along.cross(Vector3.UP)
	if normal.length_squared() < 0.0001:
		normal = Vector3(0.0, 0.0, 1.0)
	else:
		normal = normal.normalized()
	var to := Vector3(camera.global_position.x - mid.x, 0.0, camera.global_position.z - mid.z)
	if normal.dot(to) < 0.0:
		normal = -normal
	var heights := [thick * 1.65, thick, thick * 0.36, thick * 1.2]
	var amounts := [0.4, 0.9, 1.0, 0.68]
	var scrolls := [0.0, 0.45, 0.2, 1.1]
	for i in 4:
		var node := _quad()
		var basis := Basis(Vector3.UP * float(heights[i]), along * length, normal)
		node.scale = Vector3.ONE
		node.global_transform = Transform3D(basis, mid + normal * (0.02 * float(i)))
		var a: float = alpha * float(amounts[i])
		if i == 0:
			a *= 0.8 + 0.2 * sin(time * 7.0)
		elif i == 3:
			a *= 0.5 + 0.5 * absf(sin(time * 16.0))
		_paint(node, TEX[key][i], a, -time * float(scrolls[i]))


func _quad() -> MeshInstance3D:
	var node: MeshInstance3D
	if nq < quads.size():
		node = quads[nq]
	else:
		node = MeshInstance3D.new()
		node.mesh = quad_mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.material_override = _mat()
		root.add_child(node)
		quads.append(node)
	nq += 1
	node.visible = true
	return node


func _plane() -> MeshInstance3D:
	var node: MeshInstance3D
	if np < planes.size():
		node = planes[np]
	else:
		node = MeshInstance3D.new()
		node.mesh = plane_mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.material_override = _mat()
		root.add_child(node)
		planes.append(node)
	np += 1
	node.visible = true
	return node


func _mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.render_priority = 10
	return mat


func _paint(node: MeshInstance3D, tex: Texture2D, alpha: float, scroll: float, add: bool = true) -> void:
	var mat: StandardMaterial3D = node.material_override
	mat.albedo_texture = tex
	mat.albedo_color = Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	mat.uv1_offset = Vector3(0.0, scroll, 0.0)


func _hide() -> void:
	for i in quads.size():
		if i >= nq:
			(quads[i] as MeshInstance3D).visible = false
	for j in planes.size():
		if j >= np:
			(planes[j] as MeshInstance3D).visible = false
