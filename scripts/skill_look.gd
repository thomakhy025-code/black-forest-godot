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
		_ribbon(camera, "ember", fx2.pos, float(fx2.ang), float(fx2.len), 1.7, fade2, time)
	for fx3 in sim.mega_fx:
		var fade3: float = clampf(float(fx3.t) / maxf(0.05, float(fx3.dur)), 0.0, 1.0)
		var span: float = float(fx3.r) * 2.0 * (0.7 + 0.3 * fade3)
		_disc("mega", fx3.pos, span, fade3, time)
	for s in sim.shots:
		if str(s.kind) != "fireball":
			continue
		_billboard(camera, "fireball", Vector3(s.pos.x, 0.95, s.pos.y), 1.7, 1.0, time)
	for f in sim.fires:
		var life: float = clampf(float(f.t) / 2.4, 0.0, 1.0)
		_disc("ignite", f.pos, float(f.r) * 2.4, life * 0.85, time * 0.6)
	_hide()


func _unit(u, camera: Camera3D, time: float, client: bool) -> void:
	var at: Vector2 = u.global_position
	var facing: float = float(u.facing)
	if float(u.fire_sword_t) > 0.0 and int(u.fire_sword_hits) > 0:
		var fwd := Vector2(cos(facing), sin(facing)) * 0.35
		_billboard(camera, "ignite", Vector3(at.x + fwd.x, 1.15, at.y + fwd.y), 1.45, 0.8, time)
	if u.dash != null:
		_ribbon(camera, "spark", u.dash.from_pos, float(u.dash.dir), float(u.dash.dist), 1.35, 0.95, time)
	elif client and int(u.net_pose) == 6 and int(u.net_skill) == 2:
		var back := Vector2(cos(facing), sin(facing)) * (Balance.DASH_DIST * 0.5)
		_ribbon(camera, "spark", at - back, facing, Balance.DASH_DIST, 1.35, 0.9, time)
	if u.channel != null and str(u.channel.kind) == "saber":
		_ribbon(camera, "ember", u.channel.pos, float(u.channel.ang), float(u.channel.len), 1.65, 0.92, time)
	elif client and int(u.net_pose) == 4 and int(u.net_skill) == 3:
		_ribbon(camera, "ember", at, facing, Balance.SABER_LEN, 1.65, 0.92, time)
	if u.channel != null and str(u.channel.kind) == "mega":
		var pulse := 0.86 + 0.14 * sin(time * 6.0)
		_disc("mega", u.channel.pos, float(u.channel.r) * 2.0 * pulse, 0.72, time)
	elif client and int(u.net_pose) == 4 and int(u.net_skill) == 6:
		var ahead := Vector2(cos(facing), sin(facing)) * Balance.MEGA_AHEAD
		var pulse2 := 0.86 + 0.14 * sin(time * 6.0)
		_disc("mega", at + ahead, Balance.MEGA_RADIUS * 2.0 * pulse2, 0.72, time)
	if u.cast != null:
		_casting(u, at, facing, camera, time)
	var icy := false
	for c in u.clones:
		if not bool(c.alive) or float(c.hp) <= 0.0:
			continue
		icy = true
		var cp: Vector2 = c.pos
		_billboard(camera, "ice", Vector3(cp.x, 0.85, cp.y), 0.9, 0.55, time + float(c.side))
	if icy:
		_disc("ice", at, 2.6, 0.4, time)


func _casting(u, at: Vector2, facing: float, camera: Camera3D, time: float) -> void:
	var name := str(u.cast.name)
	var dur: float = maxf(0.05, float(u.cast.dur))
	var along: float = clampf(1.0 - float(u.cast.t) / dur, 0.0, 1.0)
	var fwd := Vector2(cos(facing), sin(facing))
	if name == "ignite":
		_billboard(camera, "ignite", Vector3(at.x, 1.2, at.y), 1.1 + along * 0.4, 0.7, time)
	elif name == "spark":
		_ribbon(camera, "spark", at, facing, Balance.DASH_DIST, 1.1, 0.28 + along * 0.35, time)
	elif name == "fireball":
		var hand: Vector2 = at + fwd * 0.7
		_billboard(camera, "fireball", Vector3(hand.x, 1.05, hand.y), 0.8 + along * 0.5, 0.85, time)
	elif name == "ice":
		_disc("ice", at + fwd * 0.4, 1.6 + along * 1.2, 0.65, time)


func _burst(kind: String, pos: Vector2, ang: float, fade: float, camera: Camera3D, time: float) -> void:
	if kind == "ignite":
		_billboard(camera, "ignite", Vector3(pos.x, 1.2, pos.y), 2.3, fade, time)
	elif kind == "spark":
		_ribbon(camera, "spark", pos, ang, Balance.DASH_DIST, 1.45, fade, time)
	elif kind == "ice":
		_disc("ice", pos, 3.4, fade, time)
	elif kind == "ember":
		_billboard(camera, "ember", Vector3(pos.x, 1.1, pos.y), 1.6, fade, time)


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
		node.global_transform = Transform3D(basis, mid + normal * (0.02 * float(i)))
		node.scale = Vector3.ONE
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
	mat.render_priority = 2
	return mat


func _paint(node: MeshInstance3D, tex: Texture2D, alpha: float, scroll: float) -> void:
	var mat: StandardMaterial3D = node.material_override
	mat.albedo_texture = tex
	mat.albedo_color = Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))
	mat.uv1_offset = Vector3(0.0, scroll, 0.0)


func _hide() -> void:
	for i in quads.size():
		if i >= nq:
			(quads[i] as MeshInstance3D).visible = false
	for j in planes.size():
		if j >= np:
			(planes[j] as MeshInstance3D).visible = false
