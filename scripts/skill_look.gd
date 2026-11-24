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

## Le Lu's fireball: hollow shell, inverted-fresnel core, wavy ribbon, shrinking sparks.
const FIRE_HEAD := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec4 fire_color : source_color = vec4(2.0, 1.3, 0.6, 1.0);
uniform float flow = 3.0;
uniform float eat = 0.0;
uniform float fade = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float around = UV.x * 6.2831853;
	vec2 p = vec2(cos(around), sin(around)) * 0.85;
	p.x += UV.y * 0.15;
	float along = UV.y * 1.35 - TIME * flow;
	float n = value_noise(vec2(p.x, along));
	n += value_noise(vec2(p.y * 1.7, along * 2.05 + 4.0)) * 0.55;
	n += value_noise(vec2(p.x * 2.4 + 3.0, along * 3.4)) * 0.28;
	n = n * 0.72 + 0.38;
	float g = smoothstep(0.32, 1.12, UV.y + eat);
	float a = clamp(n - g, 0.0, 1.0);
	ALBEDO = fire_color.rgb;
	ALPHA = a * fire_color.a * fade;
}
"""

const FIRE_CORE := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec4 ball_color : source_color = vec4(1.7, 0.38, 0.06, 1.0);
uniform float fresnel_power = 5.0;
uniform float fade = 1.0;

void fragment() {
	float ndv = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float fres = 1.0 - pow(1.0 - ndv, fresnel_power);
	ALBEDO = ball_color.rgb;
	ALPHA = fres * ball_color.a * fade;
}
"""

const FIRE_TRAIL := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec4 head_color : source_color = vec4(3.0, 1.5, 0.2, 1.0);
uniform vec4 tail_color : source_color = vec4(1.5, 0.16, 0.05, 1.0);
uniform float scroll = -1.0;
uniform vec2 uv_scale = vec2(1.0, 0.5);
uniform float fade = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = (UV - vec2(0.5)) * uv_scale + vec2(0.5);
	float x = uv.x * 6.2831853 + TIME * scroll * 4.0;
	float y = uv.y;
	float w0 = y - 0.50 - 0.18 * sin(x);
	float w1 = y - 0.36 - 0.12 * sin(x * 1.65 + 1.7);
	float w2 = y - 0.64 - 0.11 * sin(x * 1.25 + 2.8);
	float a = smoothstep(0.13, 0.0, abs(w0));
	a += smoothstep(0.07, 0.0, abs(w1)) * 0.72;
	a += smoothstep(0.06, 0.0, abs(w2)) * 0.66;
	float bits = hash21(vec2(floor(uv.x * 9.0 - TIME * scroll * 6.0), floor(y * 7.0)));
	a *= 0.7 + 0.3 * bits;
	a *= smoothstep(0.0, 0.05, UV.y) * smoothstep(1.0, 0.95, UV.y);
	a *= 1.0 - smoothstep(0.55, 1.0, UV.x);
	vec3 col = mix(head_color.rgb, tail_color.rgb, smoothstep(0.0, 0.85, UV.x));
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0) * fade;
}
"""

const FIRE_SPARK := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec4 spark_color : source_color = vec4(2.0, 1.3, 0.5, 1.0);
uniform float fade = 1.0;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p);
	float a = smoothstep(0.48, 0.1, d);
	ALBEDO = spark_color.rgb;
	ALPHA = a * spark_color.a * fade;
}
"""

var root: Node3D
var quads: Array = []
var planes: Array = []
var heads: Array = []
var cores: Array = []
var ribbons: Array = []
var spark_nodes: Array = []
var quad_mesh: QuadMesh
var plane_mesh: PlaneMesh
var head_mesh: ArrayMesh
var card_mesh: ArrayMesh
var core_mesh: SphereMesh
var head_shader: Shader
var core_shader: Shader
var trail_shader: Shader
var spark_shader: Shader
var nq := 0
var np := 0
var nh := 0
var nc := 0
var nr := 0
var ns := 0
var impacts: Array = []
var remembered: Array = []


func setup(fx_root: Node3D) -> void:
	root = fx_root
	quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2.ONE
	plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2.ONE
	head_mesh = _make_head_mesh()
	card_mesh = _make_card_mesh()
	core_mesh = SphereMesh.new()
	core_mesh.radius = 0.5
	core_mesh.height = 1.0
	core_mesh.radial_segments = 16
	core_mesh.rings = 8
	head_shader = Shader.new()
	head_shader.code = FIRE_HEAD
	core_shader = Shader.new()
	core_shader.code = FIRE_CORE
	trail_shader = Shader.new()
	trail_shader.code = FIRE_TRAIL
	spark_shader = Shader.new()
	spark_shader.code = FIRE_SPARK


func reset() -> void:
	quads.clear()
	planes.clear()
	heads.clear()
	cores.clear()
	ribbons.clear()
	spark_nodes.clear()
	impacts.clear()
	remembered.clear()
	nq = 0
	np = 0
	nh = 0
	nc = 0
	nr = 0
	ns = 0


func draw(sim, camera: Camera3D) -> void:
	nq = 0
	np = 0
	nh = 0
	nc = 0
	nr = 0
	ns = 0
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
	_watch_booms(sim, time)
	var next_mem: Array = []
	for s in sim.shots:
		if str(s.kind) != "fireball":
			continue
		var vel := Vector2(float(s.vx), float(s.vy))
		var speed: float = vel.length()
		var dir := Vector2.RIGHT
		if speed > 0.05:
			dir = vel / speed
		var phase: float = time + float(s.life)
		_fireball_picture(camera, s.pos, dir, 1.0, 1.0, time, phase, 1.0, 0.0, 10)
		next_mem.append({"pos": s.pos, "dir": dir})
	remembered = next_mem
	_draw_booms(camera, sim, time)
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
		var spark_n := 0
		if along > 0.45:
			spark_n = 4
		_fireball_picture(camera, hand, fwd, 0.52 + along * 0.48, 0.92, time, time, along * 0.35, 0.0, spark_n)
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
		var aim := Vector2(cos(ang), sin(ang))
		_fireball_picture(camera, pos, aim, 1.15 + (1.0 - fade) * 0.7, fade, time, time, fade * 0.4, (1.0 - fade) * 0.85, 6)
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


func _hash01(n: float) -> float:
	var x: float = sin(n * 12.9898 + 78.233) * 43758.5453
	return x - floor(x)


func _make_head_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 13
	var segs := 18
	for ring in rings - 1:
		var t0: float = float(ring) / float(rings - 1)
		var t1: float = float(ring + 1) / float(rings - 1)
		for s in segs:
			var u0: float = float(s) / float(segs)
			var u1: float = float(s + 1) / float(segs)
			_head_tri(st, _head_point(t0, u0), _head_point(t0, u1), _head_point(t1, u0), Vector2(u0, t0), Vector2(u1, t0), Vector2(u0, t1))
			_head_tri(st, _head_point(t0, u1), _head_point(t1, u1), _head_point(t1, u0), Vector2(u1, t0), Vector2(u1, t1), Vector2(u0, t1))
	st.generate_normals()
	return st.commit()


func _head_point(t: float, u: float) -> Vector3:
	var a: float = TAU * u
	var rad: float = sin(pow(t, 0.55) * PI * 0.5) * lerpf(0.78, 0.36, t)
	var z: float = 0.9 - t * 1.85
	var lick: float = pow(t, 1.8) * maxf(sin(a), 0.0) * 0.38
	return Vector3(cos(a) * rad, sin(a) * rad + lick, z)


func _head_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)


func _make_card_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := Vector3(0.0, 0.0, 1.0)
	st.set_normal(n)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(Vector3(-0.5, -0.5, 0.0))
	st.set_normal(n)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(Vector3(0.5, -0.5, 0.0))
	st.set_normal(n)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(Vector3(0.5, 0.5, 0.0))
	st.set_normal(n)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(Vector3(-0.5, -0.5, 0.0))
	st.set_normal(n)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(Vector3(0.5, 0.5, 0.0))
	st.set_normal(n)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(Vector3(-0.5, 0.5, 0.0))
	st.generate_normals()
	return st.commit()


func _fireball_picture(camera: Camera3D, pos: Vector2, dir: Vector2, body: float, alpha: float, time: float, phase: float, trail: float, eat: float, spark_n: int) -> void:
	if alpha <= 0.02 or body <= 0.02 or head_mesh == null:
		return
	var forward := Vector3(dir.x, 0.0, dir.y)
	if forward.length_squared() < 0.0001:
		forward = Vector3(1.0, 0.0, 0.0)
	else:
		forward = forward.normalized()
	var side := Vector3(-forward.z, 0.0, forward.x)
	var origin := Vector3(pos.x, 1.02, pos.y)
	var head := _take(heads, nh, head_mesh, head_shader, 12)
	nh += 1
	_place(head, Basis(side * body, Vector3.UP * body, forward * body), origin)
	var head_mat: ShaderMaterial = head.material_override as ShaderMaterial
	head_mat.set_shader_parameter("eat", eat)
	head_mat.set_shader_parameter("fade", alpha)
	var core := _take(cores, nc, core_mesh, core_shader, 11)
	nc += 1
	var core_s: float = body * 0.72
	_place(core, Basis(Vector3(core_s, 0.0, 0.0), Vector3(0.0, core_s, 0.0), Vector3(0.0, 0.0, core_s)), origin + forward * (0.12 * body))
	var core_mat: ShaderMaterial = core.material_override as ShaderMaterial
	core_mat.set_shader_parameter("fade", alpha)
	if trail > 0.04:
		var length: float = 2.25 * trail
		var width: float = 0.78 * clampf(body, 0.6, 1.35)
		_fire_ribbon(camera, origin - forward * (0.28 * body), forward, side, length, width, alpha * 0.58, true)
		_fire_ribbon(camera, origin - forward * (0.22 * body), forward, side, length, width * 0.85, alpha, false)
	_fire_sparks(camera, origin, forward, phase, time, body, alpha, spark_n)


func _fire_ribbon(camera: Camera3D, origin: Vector3, forward: Vector3, side: Vector3, length: float, width: float, alpha: float, flat: bool) -> void:
	if alpha <= 0.02 or card_mesh == null:
		return
	var tail := -forward
	var node := _take(ribbons, nr, card_mesh, trail_shader, 10)
	nr += 1
	var basis: Basis
	var mid: Vector3
	if flat:
		basis = Basis(tail * length, side * width, Vector3.UP)
		mid = origin + tail * (length * 0.5)
		mid.y = 0.86
	else:
		var z_axis: Vector3 = camera.global_basis.z
		var along: Vector3 = tail - z_axis * tail.dot(z_axis)
		if along.length_squared() < 0.0004:
			along = camera.global_basis.y
		else:
			along = along.normalized()
		var wide: Vector3 = z_axis.cross(along)
		if wide.length_squared() < 0.0004:
			wide = camera.global_basis.x
		else:
			wide = wide.normalized()
		basis = Basis(along * length, wide * (width * 0.9), z_axis)
		mid = origin + along * (length * 0.5)
		mid.y = origin.y
	_place(node, basis, mid)
	var mat: ShaderMaterial = node.material_override as ShaderMaterial
	mat.set_shader_parameter("fade", alpha)


func _fire_sparks(camera: Camera3D, origin: Vector3, forward: Vector3, phase: float, time: float, body: float, alpha: float, count: int) -> void:
	if count <= 0 or alpha <= 0.02:
		return
	var back := -forward
	var period := 0.3
	var clock: float = time + _hash01(phase * 2.2) * period
	for i in count:
		var birth: float = pow(_hash01(phase * 1.7 + float(i) * 4.41), 1.67) * period
		var age: float = fmod(clock - birth + period * 2.0, period)
		var life: float = 1.0 - age / period
		if life <= 0.05:
			continue
		var u: float = _hash01(phase * 3.1 + float(i) * 19.17)
		var v: float = _hash01(phase * 5.3 + float(i) * 7.91)
		var theta: float = TAU * u
		var z: float = lerpf(-1.0, 1.0, v)
		var ring: float = sqrt(maxf(0.0, 1.0 - z * z))
		var radial := Vector3(cos(theta) * ring, z, sin(theta) * ring)
		var speed: float = lerpf(3.0, 8.0, _hash01(phase * 8.2 + float(i) * 2.17))
		var push: float = lerpf(1.0, 2.0, _hash01(phase * 6.4 + float(i) * 11.3))
		var vel := back * speed + radial * push
		var at := origin + radial * (0.5 * body) + vel * age
		var base: float = lerpf(0.1, 0.5, _hash01(phase * 4.4 + float(i) * 3.7))
		var scl: float = lerpf(1.0, 1.5, _hash01(phase * 9.1 + float(i) * 6.6)) * life
		_streak(camera, at, vel, base * scl * 1.8, base * scl * 0.55, alpha * life)


func _watch_booms(sim, time: float) -> void:
	var kept: Array = []
	for boom in impacts:
		if time - float(boom["born"]) < 0.48:
			kept.append(boom)
	impacts = kept
	var spots: Array[Vector2] = []
	for p in sim.bursts:
		var c: Color = p.color
		if absf(c.r - 1.0) > 0.03 or absf(c.g - 0.54) > 0.03 or absf(c.b - 0.24) > 0.03:
			continue
		if float(p.t) < 0.28:
			continue
		spots.append(p.pos)
	var used: Array = []
	used.resize(spots.size())
	for i in spots.size():
		used[i] = false
	for i in spots.size():
		if bool(used[i]):
			continue
		var acc: Vector2 = spots[i]
		var count := 1
		used[i] = true
		for j in range(i + 1, spots.size()):
			if bool(used[j]):
				continue
			if spots[i].distance_to(spots[j]) > 1.2:
				continue
			used[j] = true
			acc += spots[j]
			count += 1
		if count < 4:
			continue
		var at: Vector2 = acc / float(count)
		var seen := false
		for boom in impacts:
			var bp: Vector2 = boom["pos"]
			if bp.distance_to(at) < 3.0:
				seen = true
				break
		if seen:
			continue
		var aim := Vector2.RIGHT
		var best := 6.0
		for mem in remembered:
			var mp: Vector2 = mem["pos"]
			var dist: float = mp.distance_to(at)
			if dist < best:
				best = dist
				aim = mem["dir"]
		impacts.append({"pos": at, "born": time, "dir": aim})


func _draw_booms(camera: Camera3D, sim, time: float) -> void:
	for boom in impacts:
		var age: float = time - float(boom["born"])
		var life: float = clampf(1.0 - age / 0.42, 0.0, 1.0)
		if life <= 0.02:
			continue
		var at: Vector2 = boom["pos"]
		var aim: Vector2 = boom["dir"]
		_fireball_picture(camera, at, aim, 1.05 + age * 1.55, life, time, float(boom["born"]), clampf(1.0 - age / 0.28, 0.0, 1.0) * 0.7, age * 1.15, 0)
	for p in sim.bursts:
		var c: Color = p.color
		if absf(c.r - 1.0) > 0.03 or absf(c.g - 0.54) > 0.03 or absf(c.b - 0.24) > 0.03:
			continue
		var life2: float = clampf(float(p.t) / 0.55, 0.0, 1.0)
		if life2 <= 0.02:
			continue
		var vel: Vector2 = p.vel
		var width: float = lerpf(0.08, 0.22, clampf(float(p.r) / 0.2, 0.0, 1.0)) * life2
		var length: float = maxf(width * 2.4, vel.length() * 0.055) * (0.45 + 0.55 * life2)
		var travel := Vector3(vel.x, 0.15, vel.y)
		_streak(camera, Vector3(p.pos.x, 0.95, p.pos.y), travel, length, width, life2)


func _streak(camera: Camera3D, pos: Vector3, travel: Vector3, length: float, width: float, alpha: float) -> void:
	if alpha <= 0.02 or length < 0.02 or card_mesh == null:
		return
	var node := _take(spark_nodes, ns, card_mesh, spark_shader, 13)
	ns += 1
	var z_axis: Vector3 = camera.global_basis.z
	var along: Vector3 = travel - z_axis * travel.dot(z_axis)
	if along.length_squared() < 0.0004:
		along = camera.global_basis.y
	else:
		along = along.normalized()
	var side: Vector3 = z_axis.cross(along)
	if side.length_squared() < 0.0004:
		side = camera.global_basis.x
	else:
		side = side.normalized()
	_place(node, Basis(side * width, along * length, z_axis), pos)
	var mat: ShaderMaterial = node.material_override as ShaderMaterial
	mat.set_shader_parameter("fade", alpha)


func _place(node: MeshInstance3D, basis: Basis, pos: Vector3) -> void:
	node.scale = Vector3.ONE
	node.global_transform = Transform3D(basis, pos)


func _take(pool: Array, at: int, mesh: Mesh, shader: Shader, priority: int) -> MeshInstance3D:
	var node: MeshInstance3D
	if at < pool.size():
		node = pool[at]
	else:
		node = MeshInstance3D.new()
		node.mesh = mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.render_priority = priority
		node.material_override = mat
		root.add_child(node)
		pool.append(node)
	node.visible = true
	return node


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
	_hide_from(quads, nq)
	_hide_from(planes, np)
	_hide_from(heads, nh)
	_hide_from(cores, nc)
	_hide_from(ribbons, nr)
	_hide_from(spark_nodes, ns)


func _hide_from(pool: Array, used: int) -> void:
	for i in pool.size():
		if i >= used:
			(pool[i] as MeshInstance3D).visible = false
