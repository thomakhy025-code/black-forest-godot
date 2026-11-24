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

## Thane's cut: one thick crescent, red outside and white-gold inside.
## UV.x runs from the tail of the swing to the tip. UV.y is 0 on the inner edge.
const SLASH_ARC0 := 2.85
const SLASH_ARC1 := -0.45
const SLASH_MID_R := 2.45
const SLASH_HALF := 0.58
const SLASH_SIDE := 0.42
const SLASH_CX := 0.35
const SLASH_CY := 1.35

const SLASH_ARC := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform float sweep = 1.0;
uniform float fade = 1.0;
uniform float heat = 0.0;

void fragment() {
	float x = UV.x;
	float y = UV.y;
	float reveal = clamp((sweep * 1.22 - x) / 0.18, 0.0, 1.0);
	float tail = smoothstep(0.0, 0.06, x);
	float tooth = abs(fract(x * 8.0) - 0.5);
	float facet = smoothstep(0.02, 0.22, y + tooth * 0.28);
	float rim = 1.0 - smoothstep(0.0, 0.22, abs(y - 0.16));
	float outer = smoothstep(0.5, 1.0, y);
	vec3 hot = vec3(3.15, 2.45, 1.12);
	vec3 gold = vec3(2.55, 0.9, 0.12);
	vec3 red = vec3(1.45, 0.18, 0.02);
	vec3 col = mix(hot, gold, smoothstep(0.0, 0.4, y));
	col = mix(col, red, smoothstep(0.34, 0.95, y));
	col += hot * rim * (0.5 + 0.5 * sin(x * 24.0 + TIME * 6.5));
	float block = step(0.4, fract(x * 7.0));
	col += hot * block * smoothstep(0.34, 0.08, y) * 0.55;
	float lead = clamp((x - (sweep * 1.22 - 0.22)) / 0.18, 0.0, 1.0);
	col += vec3(1.5, 0.9, 0.28) * lead * (1.0 - smoothstep(0.92, 1.0, sweep));
	col = mix(col, red, heat * 0.7);
	float pulse = 0.88 + 0.12 * sin(TIME * 5.2);
	float a = reveal * tail * max(facet, rim * 0.9) * fade * pulse;
	a *= 1.0 - outer * 0.22;
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

const SLASH_SHARD := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform float fade = 1.0;

void fragment() {
	float y = UV.y;
	float x = abs(UV.x - 0.5) * 2.0;
	float a = smoothstep(1.0, 0.04, x) * smoothstep(0.0, 0.14, y);
	vec3 col = mix(vec3(1.6, 0.2, 0.03), vec3(3.15, 2.2, 0.75), smoothstep(0.1, 0.95, y));
	ALBEDO = col;
	ALPHA = a * fade;
}
"""

const SLASH_FLASH := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform float fade = 1.0;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p);
	float a = smoothstep(0.5, 0.06, d);
	float core = smoothstep(0.26, 0.0, d);
	vec3 col = mix(vec3(1.75, 0.32, 0.04), vec3(3.35, 2.65, 1.25), core);
	ALBEDO = col;
	ALPHA = a * fade;
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
var slash_mesh: ArrayMesh
var shard_mesh: ArrayMesh
var slash_shader: Shader
var shard_shader: Shader
var flash_shader: Shader
var slashes: Array = []
var shards: Array = []
var flashes: Array = []
var nq := 0
var np := 0
var nh := 0
var nc := 0
var nr := 0
var ns := 0
var nslash := 0
var nshard := 0
var nflash := 0
var impacts: Array = []
var remembered: Array = []
## Slash spends most of the channel raised. The last fifth is the downward cut.
const SLASH_CHARGE := 0.80
const SLASH_RAISED := 5.8
var host = null
var charge_at: Dictionary = {}


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
	slash_mesh = _make_slash_mesh()
	shard_mesh = _make_shard_mesh()
	slash_shader = Shader.new()
	slash_shader.code = SLASH_ARC
	shard_shader = Shader.new()
	shard_shader.code = SLASH_SHARD
	flash_shader = Shader.new()
	flash_shader.code = SLASH_FLASH


func reset() -> void:
	quads.clear()
	planes.clear()
	heads.clear()
	cores.clear()
	ribbons.clear()
	spark_nodes.clear()
	slashes.clear()
	shards.clear()
	flashes.clear()
	impacts.clear()
	remembered.clear()
	charge_at.clear()
	host = null
	nq = 0
	np = 0
	nh = 0
	nc = 0
	nr = 0
	ns = 0
	nslash = 0
	nshard = 0
	nflash = 0


func draw(sim, camera: Camera3D) -> void:
	nq = 0
	np = 0
	nh = 0
	nc = 0
	nr = 0
	ns = 0
	nslash = 0
	nshard = 0
	nflash = 0
	host = sim
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
		_saber_look(camera, fx2.pos, float(fx2.ang), float(fx2.len), fade2, time, 1.0, 1.0)
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
		var saber_along: float = saber_progress(u, time)
		_saber_look(camera, u.channel.pos, float(u.channel.ang), float(u.channel.len), 1.0, time, saber_along, 0.0)
	elif client and int(u.net_pose) == 4 and int(u.net_skill) == 3:
		var remote_along: float = saber_progress(u, time)
		_saber_look(camera, at, facing, Balance.SABER_LEN, 1.0, time, remote_along, 0.0)
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
		_saber_look(camera, pos, ang, Balance.SABER_LEN, fade, time, 1.0, 1.0)
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


func saber_progress(u, _time: float) -> float:
	var id := str(u.unit_id)
	if u.channel != null and str(u.channel.kind) == "saber":
		var dur: float = maxf(0.05, float(u.channel.dur))
		return clampf(1.0 - float(u.channel.t) / dur, 0.0, 1.0)
	# The snapshot has no channel clock. A remote pose keeps its own 3s charge.
	if int(u.net_pose) == 4 and int(u.net_skill) == 3:
		var now := Time.get_ticks_msec()
		if not charge_at.has(id):
			charge_at[id] = now
		var elapsed := float(now - int(charge_at[id])) / 1000.0
		return clampf(elapsed / Balance.SABER_TIME, 0.0, 1.0)
	charge_at.erase(id)
	return -1.0


func blade_frame(origin: Vector2, ang: float, along: float, reach: float) -> Dictionary:
	var forward := Vector3(cos(ang), 0.0, sin(ang))
	var side := Vector3(-forward.z, 0.0, forward.x)
	var up := Vector3.UP
	var ground := _feet(origin)
	var g: float = clampf(along / SLASH_CHARGE, 0.0, 1.0)
	var grow: float = g * g * (3.0 - 2.0 * g)
	var swing := 0.0
	if along > SLASH_CHARGE:
		var s: float = clampf((along - SLASH_CHARGE) / (1.0 - SLASH_CHARGE), 0.0, 1.0)
		swing = s * s * (3.0 - 2.0 * s)
	var raised: float = SLASH_RAISED
	var full: float = maxf(reach, raised)
	var length: float = lerpf(2.2, raised, grow)
	var stretch := 0.0
	if swing > 0.25:
		var k: float = clampf((swing - 0.25) / 0.75, 0.0, 1.0)
		stretch = k * k
	if swing > 0.0:
		length = lerpf(raised, full, stretch)
	var pitch: float = swing * PI * 0.5
	var tip_dir := (up * cos(pitch) + forward * sin(pitch)).normalized()
	var grip_y: float = lerpf(2.05, 0.1, swing)
	var grip_fwd: float = lerpf(0.08, 0.15, swing)
	var grip := Vector3(origin.x, ground + grip_y, origin.y) + forward * grip_fwd + side * (-0.22)
	var width: float = lerpf(0.5, 1.35, grow)
	var thick: float = lerpf(0.28, 0.62, grow)
	if swing > 0.0:
		width = lerpf(1.35, 1.55, swing)
		thick = lerpf(0.62, 0.75, swing)
	return {
		"grip": grip,
		"tip": grip + tip_dir * length,
		"tip_dir": tip_dir,
		"side": side,
		"forward": forward,
		"length": length,
		"width": width,
		"thick": thick,
		"grow": grow,
		"swing": swing,
		"ground": ground,
		"reach": full,
	}


func _saber_look(camera: Camera3D, origin: Vector2, ang: float, length: float, alpha: float, time: float, along: float = 1.0, hit: float = 0.0) -> void:
	if alpha <= 0.02:
		return
	var frame := blade_frame(origin, ang, along, length)
	var swing: float = float(frame["swing"])
	if hit > 0.5:
		_ground_scar(origin, ang, length, clampf(alpha / 0.25, 0.0, 1.0), float(frame["ground"]))
		if alpha > 0.45:
			_split_sparks(camera, origin, ang, length, time, alpha, float(frame["ground"]))
		return
	if swing < 0.08:
		_gather(camera, frame, origin, time, ang, alpha)
	else:
		_cling(camera, frame, time, alpha)
	_blade_sheen(frame, alpha)
	if swing > 0.72:
		var scar_a: float = clampf((swing - 0.72) / 0.28, 0.0, 1.0) * alpha
		_ground_scar(origin, ang, length, scar_a, float(frame["ground"]))
		_split_sparks(camera, origin, ang, length, time, scar_a, float(frame["ground"]))


func _gather(camera: Camera3D, frame: Dictionary, origin: Vector2, time: float, ang: float, alpha: float) -> void:
	var grip: Vector3 = frame["grip"]
	var tip: Vector3 = frame["tip"]
	var forward: Vector3 = frame["forward"]
	var side: Vector3 = frame["side"]
	var ground: float = float(frame["ground"])
	var feet := Vector3(origin.x, ground, origin.y)
	for i in 20:
		var seed: float = ang * 1.7 + float(i) * 6.13
		var period := 0.62
		var travel: float = fmod(time * 1.05 + _hash01(seed) * period, period) / period
		var around: float = _hash01(seed + 2.2) * TAU
		var radius: float = lerpf(1.5, 4.0, _hash01(seed + 1.1))
		var height: float = lerpf(0.25, 3.6, _hash01(seed + 4.4))
		var src := feet + forward * cos(around) * radius + side * sin(around) * radius + Vector3.UP * height
		var dst: Vector3 = grip.lerp(tip, lerpf(0.12, 0.96, _hash01(seed + 8.2)))
		var at: Vector3 = src.lerp(dst, travel)
		var life: float = 1.0 - travel * 0.25
		var size: float = lerpf(0.16, 0.48, _hash01(seed + 5.5)) * life
		_mote(camera, at, size, alpha * life, _hash01(seed + 3.3) > 0.62)
	for j in 7:
		var u: float = _hash01(ang * 3.1 + float(j) * 4.7)
		var at2: Vector3 = grip.lerp(tip, lerpf(0.15, 0.95, u))
		at2 += side * sin(time * 5.0 + float(j) * 1.4) * 0.18
		_mote(camera, at2, lerpf(0.22, 0.4, u), alpha * 0.9, true)


func _cling(camera: Camera3D, frame: Dictionary, time: float, alpha: float) -> void:
	var grip: Vector3 = frame["grip"]
	var tip: Vector3 = frame["tip"]
	var side: Vector3 = frame["side"]
	var tip_dir: Vector3 = frame["tip_dir"]
	var normal := side.cross(tip_dir)
	if normal.length_squared() < 0.0001:
		normal = Vector3.UP
	else:
		normal = normal.normalized()
	for i in 16:
		var seed: float = float(frame["reach"]) * 0.2 + float(i) * 5.17
		var u: float = _hash01(seed + 1.7)
		var at: Vector3 = grip.lerp(tip, lerpf(0.06, 0.98, u))
		at += side * sin(time * 8.0 + float(i) * 1.2) * 0.16
		at += normal * sin(time * 6.0 + float(i) * 0.7) * 0.1
		_mote(camera, at, lerpf(0.18, 0.46, _hash01(seed + 2.4)), alpha, _hash01(seed) > 0.5)


func _split_sparks(camera: Camera3D, origin: Vector2, ang: float, length: float, time: float, alpha: float, ground: float) -> void:
	var forward := Vector3(cos(ang), 0.0, sin(ang))
	var side := Vector3(-forward.z, 0.0, forward.x)
	for i in 10:
		var seed: float = ang * 2.4 + float(i) * 3.9
		var along: float = _hash01(seed) * length
		var period := 0.48
		var travel: float = fmod(time * 1.35 + _hash01(seed + 1.8) * period, period) / period
		var dir := 1.0 if (i % 2) == 0 else -1.0
		var at := Vector3(origin.x, ground, origin.y) + forward * along
		at += side * dir * lerpf(0.15, 1.7, travel)
		at.y += lerpf(0.12, 0.85, travel)
		_mote(camera, at, lerpf(0.14, 0.32, _hash01(seed + 4.0)) * (1.0 - travel * 0.4), alpha * (1.0 - travel), true)


func _blade_sheen(frame: Dictionary, alpha: float) -> void:
	var grip: Vector3 = frame["grip"]
	var tip: Vector3 = frame["tip"]
	var side: Vector3 = frame["side"]
	var tip_dir: Vector3 = frame["tip_dir"]
	var span: float = maxf(grip.distance_to(tip), 0.2)
	var mid: Vector3 = grip.lerp(tip, 0.55)
	var normal := side.cross(tip_dir)
	if normal.length_squared() < 0.0001:
		normal = Vector3.UP
	else:
		normal = normal.normalized()
	var wide: float = float(frame["width"]) * 0.72
	var node := _quad()
	node.scale = Vector3.ONE
	node.global_transform = Transform3D(Basis(side * wide, tip_dir * span, normal), mid + normal * 0.04)
	_glow(node, Color(1.0, 0.72, 0.28, 0.42 * alpha))
	var core := _quad()
	core.scale = Vector3.ONE
	core.global_transform = Transform3D(Basis(side * wide * 0.28, tip_dir * span, normal), mid + normal * 0.06)
	_glow(core, Color(1.0, 0.94, 0.72, 0.7 * alpha))


func _ground_scar(origin: Vector2, ang: float, length: float, alpha: float, ground: float) -> void:
	if alpha <= 0.02 or length < 0.2:
		return
	var forward := Vector3(cos(ang), 0.0, sin(ang))
	var side := Vector3(-forward.z, 0.0, forward.x)
	var y: float = _scar_y(origin, ground)
	var mid := Vector3(origin.x, y, origin.y) + forward * (length * 0.5)
	_flat_decal(mid + Vector3(0.0, 0.02, 0.0), forward, side, length, 0.62, Color(0.03, 0.02, 0.015, 0.94 * alpha))
	var flap_l := (Vector3.UP - side * 0.55).normalized()
	var flap_r := (Vector3.UP + side * 0.55).normalized()
	_flat_decal(mid - side * 0.52 + Vector3.UP * 0.05, forward, side, length, 0.58, Color(0.5, 0.32, 0.16, 0.9 * alpha), flap_l)
	_flat_decal(mid + side * 0.52 + Vector3.UP * 0.05, forward, side, length, 0.58, Color(0.46, 0.3, 0.15, 0.9 * alpha), flap_r)
	var trench := _quad()
	trench.scale = Vector3.ONE
	trench.global_transform = Transform3D(Basis(forward * length, Vector3.UP * 0.42, side), mid + Vector3.UP * 0.2)
	_wash(trench, Color(0.05, 0.03, 0.02, 0.88 * alpha))
	_flat_decal(mid + Vector3.UP * 0.08, forward, side, length, 0.12, Color(1.0, 0.78, 0.34, 0.95 * alpha), Vector3.UP, true)


func _mote(camera: Camera3D, pos: Vector3, size: float, alpha: float, hot: bool) -> void:
	if alpha <= 0.02 or size <= 0.02 or card_mesh == null:
		return
	var node := _take(spark_nodes, ns, card_mesh, spark_shader, 12)
	ns += 1
	node.global_transform = Transform3D(camera.global_basis, pos)
	node.scale = Vector3(size, size, 1.0)
	var mat: ShaderMaterial = node.material_override as ShaderMaterial
	mat.set_shader_parameter("fade", alpha)
	if hot:
		mat.set_shader_parameter("spark_color", Color(2.6, 2.15, 1.15, 1.0))
	else:
		mat.set_shader_parameter("spark_color", Color(2.1, 1.15, 0.4, 1.0))


func _glow(node: MeshInstance3D, color: Color) -> void:
	var mat: StandardMaterial3D = node.material_override
	mat.albedo_texture = null
	mat.albedo_color = Color(color.r, color.g, color.b, color.a)
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.uv1_offset = Vector3.ZERO


func _flat_decal(mid: Vector3, forward: Vector3, side: Vector3, length: float, width: float, color: Color, normal: Vector3 = Vector3.UP, add: bool = false) -> void:
	var y_axis := normal.normalized()
	var x_axis := y_axis.cross(forward)
	if x_axis.length_squared() < 0.0001:
		x_axis = side.normalized()
	else:
		x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis)
	if z_axis.length_squared() < 0.0001:
		z_axis = forward.normalized()
	else:
		z_axis = z_axis.normalized()
	var node := _plane()
	node.scale = Vector3.ONE
	node.global_transform = Transform3D(Basis(x_axis * width, y_axis, z_axis * length), mid)
	if add:
		_glow(node, color)
	else:
		_wash(node, color)


func _feet(p: Vector2) -> float:
	var y := 0.04
	if host == null:
		return y
	var stage_node = host.get("stage")
	if stage_node != null and stage_node.has_method("_feet_y"):
		y = float(stage_node.call("_feet_y", p))
	return y


func _scar_y(p: Vector2, ground: float) -> float:
	var y := ground + 0.07
	if host == null:
		return y
	var stage_node = host.get("stage")
	if stage_node != null and stage_node.has_method("_wet") and bool(stage_node.call("_wet", p)):
		y = maxf(y, 0.54)
	return y


func _slash_band(at: Vector3, forward: Vector3, up: Vector3, side: Vector3, radial_scale: float, side_scale: float, sweep: float, fade: float, heat: float) -> void:
	if fade <= 0.02 or sweep <= 0.01:
		return
	var priority := 11
	if heat > 0.2:
		priority = 10
	var node := _take(slashes, nslash, slash_mesh, slash_shader, priority)
	nslash += 1
	var basis := Basis(forward * radial_scale, up * radial_scale, side * side_scale)
	_place(node, basis, at)
	var mat: ShaderMaterial = node.material_override as ShaderMaterial
	mat.set_shader_parameter("sweep", sweep)
	mat.set_shader_parameter("fade", fade)
	mat.set_shader_parameter("heat", heat)


func _slash_world(at: Vector3, forward: Vector3, up: Vector3, side: Vector3, radial: float, zsign: float, t: float) -> Vector3:
	var local := _slash_corner(t, radial, zsign)
	return at + forward * local.x + up * local.y + side * local.z


func _slash_flash(camera: Camera3D, pos: Vector3, size: float, alpha: float) -> void:
	if alpha <= 0.02 or size <= 0.02 or card_mesh == null:
		return
	var node := _take(flashes, nflash, card_mesh, flash_shader, 12)
	nflash += 1
	var b := camera.global_basis
	_place(node, Basis(b.x * size, b.y * size, b.z), pos)
	var mat: ShaderMaterial = node.material_override as ShaderMaterial
	mat.set_shader_parameter("fade", alpha)


func _slash_shards(camera: Camera3D, tip: Vector3, forward: Vector3, up: Vector3, side: Vector3, radial: Vector3, swing: Vector3, alpha: float, time: float, ang: float, sweep: float, hit: float) -> void:
	var arrive: float = clampf((sweep - 0.5) / 0.28, 0.0, 1.0)
	if arrive <= 0.02:
		return
	var reach := 1.15
	var spark := 0.7
	if hit > 0.5:
		reach = 1.9
		spark = 1.0
	for i in 9:
		var seed: float = ang * 1.7 + float(i) * 5.17
		var u: float = _hash01(seed)
		var v: float = _hash01(seed + 3.7)
		var w: float = _hash01(seed + 9.2)
		var lift: float = _hash01(seed + 2.2)
		var dir := radial * lerpf(0.15, 1.0, u) + swing * lerpf(-0.15, 1.15, v) + side * lerpf(-1.0, 1.0, w) + up * lerpf(0.05, 0.9, lift)
		if dir.y < 0.05:
			dir.y = 0.2 + lift * 0.45
		if dir.length_squared() < 0.0004:
			dir = forward
		else:
			dir = dir.normalized()
		var travel := 0.0
		var life := 0.0
		if hit > 0.5:
			travel = clampf((1.0 - alpha) * 1.2 - u * 0.28, 0.0, 1.0)
			life = (1.0 - travel) * alpha
		else:
			var period := 0.62
			travel = fmod(time * 0.85 + v * period, period) / period
			life = 1.0 - travel
		if life <= 0.05:
			continue
		var big := 1.0
		if i < 3:
			big = 1.55
		var span: float = lerpf(0.42, 1.25, u) * big * lerpf(0.45, 1.0, life)
		var wide: float = lerpf(0.07, 0.24, v) * big * life
		var at := tip + dir * lerpf(0.08, reach, travel) * big
		_slash_shard(camera, at, dir, span, wide, alpha * life * arrive * spark)


func _slash_shard(camera: Camera3D, pos: Vector3, travel: Vector3, span: float, wide: float, alpha: float) -> void:
	if alpha <= 0.02 or span < 0.02 or shard_mesh == null:
		return
	var node := _take(shards, nshard, shard_mesh, shard_shader, 13)
	nshard += 1
	var z_axis: Vector3 = camera.global_basis.z
	var along: Vector3 = travel - z_axis * travel.dot(z_axis)
	if along.length_squared() < 0.0004:
		along = camera.global_basis.y
	else:
		along = along.normalized()
	var flank: Vector3 = z_axis.cross(along)
	if flank.length_squared() < 0.0004:
		flank = camera.global_basis.x
	else:
		flank = flank.normalized()
	_place(node, Basis(flank * wide, along * span, z_axis), pos)
	var mat: ShaderMaterial = node.material_override as ShaderMaterial
	mat.set_shader_parameter("fade", alpha)


func _make_slash_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 24
	for i in steps:
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		_slash_ring(st, t0, t1)
	st.generate_normals()
	return st.commit()


func _slash_ring(st: SurfaceTool, t0: float, t1: float) -> void:
	var inn0n := _slash_corner(t0, -1.0, -1.0)
	var inn0p := _slash_corner(t0, -1.0, 1.0)
	var out0n := _slash_corner(t0, 1.0, -1.0)
	var out0p := _slash_corner(t0, 1.0, 1.0)
	var inn1n := _slash_corner(t1, -1.0, -1.0)
	var inn1p := _slash_corner(t1, -1.0, 1.0)
	var out1n := _slash_corner(t1, 1.0, -1.0)
	var out1p := _slash_corner(t1, 1.0, 1.0)
	var u0 := Vector2(t0, 0.0)
	var u0o := Vector2(t0, 1.0)
	var u0i := Vector2(t0, 0.14)
	var u1 := Vector2(t1, 0.0)
	var u1o := Vector2(t1, 1.0)
	var u1i := Vector2(t1, 0.14)
	_head_tri(st, inn0p, out0p, inn1p, u0, u0o, u1)
	_head_tri(st, out0p, out1p, inn1p, u0o, u1o, u1)
	_head_tri(st, out0n, inn0n, out1n, u0o, u0, u1o)
	_head_tri(st, inn0n, inn1n, out1n, u0, u1, u1o)
	_head_tri(st, out0n, out0p, out1n, u0o, u0o, u1o)
	_head_tri(st, out0p, out1p, out1n, u0o, u1o, u1o)
	_head_tri(st, inn0p, inn0n, inn1p, u0i, u0i, u1i)
	_head_tri(st, inn0n, inn1n, inn1p, u0i, u1i, u1i)


func _slash_corner(t: float, radial: float, zsign: float) -> Vector3:
	var a := lerpf(SLASH_ARC0, SLASH_ARC1, t)
	var bell := sin(t * PI)
	var taper := lerpf(0.32, 1.0, pow(maxf(bell, 0.0), 0.6))
	var r := SLASH_MID_R + radial * SLASH_HALF * taper
	return Vector3(SLASH_CX + cos(a) * r, SLASH_CY + sin(a) * r, zsign * SLASH_SIDE * taper)


func _make_shard_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := Vector3(0.0, 0.0, 1.0)
	st.set_normal(n)
	st.set_uv(Vector2(0.5, 1.0))
	st.add_vertex(Vector3(0.0, 0.5, 0.0))
	st.set_normal(n)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(Vector3(-0.5, -0.5, 0.0))
	st.set_normal(n)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(Vector3(0.5, -0.5, 0.0))
	return st.commit()


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
	_hide_from(slashes, nslash)
	_hide_from(shards, nshard)
	_hide_from(flashes, nflash)


func _hide_from(pool: Array, used: int) -> void:
	for i in pool.size():
		if i >= used:
			(pool[i] as MeshInstance3D).visible = false
