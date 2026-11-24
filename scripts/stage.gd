extends Node
## Visual match. The simulation stays 2D. This draws it as a bright, high-angle
## 3D field in the style of a chunky capture-the-flag game.
## Models are KayKit by Kay Lousberg, CC0. No account was required.

const Balance = preload("res://scripts/balance.gd")
const SkillLook = preload("res://scripts/skill_look.gd")

const KNIGHT = preload("res://assets/models/characters/Knight.glb")
const MAGE = preload("res://assets/models/characters/Mage.glb")
const ROGUE = preload("res://assets/models/characters/Rogue.glb")
const BARBARIAN = preload("res://assets/models/characters/Barbarian.glb")
const HOODED = preload("res://assets/models/characters/Rogue_Hooded.glb")
const WALL = preload("res://assets/models/dungeon/wall.gltf.glb")
const DOORWAY = preload("res://assets/models/dungeon/wall_doorway.glb")
const PILLAR = preload("res://assets/models/dungeon/pillar.gltf.glb")
const COLUMN = preload("res://assets/models/dungeon/column.gltf.glb")
const TILE = preload("res://assets/models/dungeon/floor_tile_large.gltf.glb")
const WOOD = preload("res://assets/models/dungeon/floor_wood_large.gltf.glb")
const BANNER_RED = preload("res://assets/models/dungeon/banner_red.gltf.glb")
const BANNER_BLUE = preload("res://assets/models/dungeon/banner_blue.gltf.glb")
const CHEST = preload("res://assets/models/dungeon/chest.glb")
const BARREL = preload("res://assets/models/dungeon/barrel_small.gltf.glb")
const RUBBLE = preload("res://assets/models/dungeon/rubble_large.gltf.glb")
const TORCH = preload("res://assets/models/dungeon/torch_mounted.gltf.glb")
const DEAD = preload("res://assets/models/forest/tree_dead_large.gltf")
const DEAD_S = preload("res://assets/models/forest/tree_dead_medium.gltf")
const PINE = preload("res://assets/models/forest/tree_pine_yellow_large.gltf")
const PINE_S = preload("res://assets/models/forest/tree_pine_orange_medium.gltf")

# glTF heroes face +Z. Match facing 0 looks along +X, so the yaw is a quarter turn minus facing.
const FACE_OFFSET := PI * 0.5
# Chop contact is about 40% of the 1.067s clip (0.427s). Sword windup is 0.22s, so 0.427/0.22.
const CHOP_SPEED := 1.94
# Punch contact is about 35% of 1.467s. Fist windup is 0.16s. 2.6 stays readable and lands near the hit.
const PUNCH_SPEED := 2.6
# Spellcast_Shoot contact is about 55% of 0.933s. Wand windup is 0.18s.
const CAST_SPEED := 2.4
# Walking_A is 1.067s for a 1.25m stride. Running_A is 0.8s for a 2.3m stride.
const WALK_SCALE := 0.854
const RUN_SCALE := 0.348
# Dodge_Forward is 0.4s and the lightning dash lasts 0.25s. The hop is 0.26s against a 1.167s jump.
const DODGE_SPEED := 1.6
const HOP_SPEED := 3.3
# High oblique, close enough that a hero is readable and a gate still fits on screen.
# 46 degrees down, 20m back, 38 degree vertical view. West stays on the left.
const CAM_PITCH := 46.0
const CAM_DIST := 20.0
const CAM_FOV := 38.0
const CAM_LOOK := 0.95

const HERO := {
	"you": "knight", "crimson": "knight", "nia": "knight", "holt": "knight", "azure": "knight",
	"joss": "rogue", "sable": "hooded", "quinn": "rogue",
	"pico": "barbarian", "vex": "barbarian",
	"bram": "mage", "mira": "mage",
}
const HERO_SCALE := {
	"knight": 0.770, "mage": 0.810, "rogue": 0.815, "barbarian": 0.815, "hooded": 0.792,
}
const LOOPY := {
	"Idle": true, "Unarmed_Idle": true, "Walking_A": true, "Walking_B": true, "Walking_C": true,
	"Running_A": true, "Running_B": true, "Spellcasting": true, "Blocking": true, "Interact": true,
	"2H_Melee_Idle": true,
}
const SWORD_PROPS := ["1H_Sword", "1H_Axe", "Knife"]
const WAND_PROPS := ["1H_Wand", "2H_Staff", "Spellbook_open"]

var layer: CanvasLayer
var box: SubViewportContainer
var view: SubViewport
var world: Node3D
var map_root: Node3D
var cast_root: Node3D
var fx_root: Node3D
var camera: Camera3D
var look = null
var sim = null
var aimed := false
var focus := Vector3.ZERO
var actors := {}
var ghosts: Array = []
var harvest: Array = []
var cover: Array = []
var strikes: Array = []
var chips: Array = []
var chip_i := 0
var thud := 0.0
var doors: Array = []
var forges: Array = []
var flags: Array = []
var gems: Array = []
var mats := {}
var prepped := {}
var beams: Array = []
var discs: Array = []
var shots3: Array = []
var fires3: Array = []
var floaters: Array = []
var drops3: Array = []
var piles3: Array = []
var beam_n := 0
var disc_n := 0
var shot_n := 0
var fire_n := 0


func _ready() -> void:
	_build_view()


func uses_view() -> bool:
	return layer != null and layer.visible and camera != null


func ground_at(screen: Vector2) -> Vector2:
	# Unproject from the camera basis. The 3D camera lives in its own viewport, so a
	# ray built here matches the picture even before that viewport has drawn a frame.
	if camera == null or view == null:
		return Vector2.ZERO
	var vp := Vector2(view.size)
	if vp.x < 2.0 or vp.y < 2.0:
		return Vector2(camera.global_position.x, camera.global_position.z)
	var ndc := Vector2((screen.x / vp.x) * 2.0 - 1.0, 1.0 - (screen.y / vp.y) * 2.0)
	var half := deg_to_rad(camera.fov) * 0.5
	var aspect := vp.x / vp.y
	var right := ndc.x * tan(half) * aspect
	var up := ndc.y * tan(half)
	var dir := (-camera.global_basis.z + camera.global_basis.x * right + camera.global_basis.y * up).normalized()
	var origin := camera.global_position
	if absf(dir.y) < 0.0001:
		return Vector2(origin.x, origin.z)
	var t: float = -origin.y / dir.y
	if t < 0.0:
		return Vector2(origin.x, origin.z)
	var hit := origin + dir * t
	return Vector2(clampf(hit.x, 0.0, Balance.MAP_W), clampf(hit.z, 0.0, Balance.MAP_H))


func rebuild(match_node) -> void:
	sim = match_node
	if _scene("knight") == null or layer == null:
		push_error("Black Forest 3D view did not load")
		return
	var hud = sim.get_node_or_null("HUD")
	if hud is CanvasLayer:
		hud.layer = 20
	layer.visible = true
	_hide_flat()
	_wipe(map_root)
	_wipe(cast_root)
	_wipe(fx_root)
	if look != null:
		look.reset()
	actors.clear()
	ghosts.clear()
	harvest.clear()
	cover.clear()
	strikes.clear()
	chips.clear()
	thud = 0.0
	doors.clear()
	forges.clear()
	flags.clear()
	gems.clear()
	beams.clear()
	discs.clear()
	shots3.clear()
	fires3.clear()
	floaters.clear()
	drops3.clear()
	piles3.clear()
	aimed = false
	_build_map()
	_make_chips()


func present(dt: float) -> void:
	if sim == null or not uses_view():
		return
	if str(sim.phase) != "play":
		return
	_fit()
	_sync_actors()
	_present_world(dt)
	_feel_strikes(dt)
	_aim(dt)
	for id in actors.keys():
		_present_actor(actors[id], dt)
	_present_ghosts()
	_tick_chips(dt)
	_clear_sight(dt)
	_present_fx()
	thud = maxf(0.0, thud - dt * 4.2)


func _build_view() -> void:
	layer = CanvasLayer.new()
	layer.layer = 1
	layer.visible = false
	add_child(layer)
	box = SubViewportContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.stretch = true
	layer.add_child(box)
	view = SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = false
	view.handle_input_locally = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_3d = Viewport.MSAA_2X
	view.size = Vector2i(1280, 720)
	box.add_child(view)
	world = Node3D.new()
	view.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.40, 0.58, 0.74)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.55, 0.5)
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.84
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.50, 0.58, 0.64)
	env.fog_density = 0.002
	env.fog_aerial_perspective = 0.22
	var weather := WorldEnvironment.new()
	weather.environment = env
	world.add_child(weather)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -36, 0)
	sun.light_color = Color(1.0, 0.92, 0.78)
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 0.8
	sun.directional_shadow_max_distance = 52.0
	sun.light_angular_distance = 0.55
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, 140, 0)
	fill.light_color = Color(0.62, 0.7, 0.82)
	fill.light_energy = 0.18
	fill.shadow_enabled = false
	world.add_child(fill)
	camera = Camera3D.new()
	camera.fov = CAM_FOV
	camera.near = 0.15
	camera.far = 180.0
	camera.current = true
	world.add_child(camera)
	map_root = Node3D.new()
	cast_root = Node3D.new()
	fx_root = Node3D.new()
	world.add_child(map_root)
	world.add_child(cast_root)
	world.add_child(fx_root)
	look = SkillLook.new()
	look.setup(fx_root)
	_make_chips()


func _fit() -> void:
	var rect := get_viewport().get_visible_rect()
	var sz := Vector2i(maxi(8, int(rect.size.x)), maxi(8, int(rect.size.y)))
	if view.size != sz:
		view.size = sz


func _hide_flat() -> void:
	var flat: Node = sim.get_node_or_null("World")
	if flat:
		flat.visible = false
	var units: Node = sim.get_node_or_null("Units")
	if units:
		units.visible = false
	var fx: Node = sim.get_node_or_null("Fx")
	if fx:
		fx.visible = false
		fx.set_process(false)
	for u in sim.units:
		var fighter = u.get_node_or_null("Visual/Fighter")
		if fighter:
			fighter.set_process(false)
			fighter.visible = false


func _wipe(node: Node3D) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.free()


func _build_map() -> void:
	_ground()
	_water()
	_road()
	_yards()
	_walls()
	_props()
	_forest()
	_gems()


func _ground() -> void:
	var grass := _mat("grass", Color(0.26, 0.42, 0.17), 1.0)
	var sand := _mat("sand", Color(0.62, 0.52, 0.34), 1.0)
	var meadow := _mat("meadow", Color(0.30, 0.46, 0.2), 1.0)
	_plane(Vector2(Balance.MAP_W, Balance.MAP_H), Vector3(Balance.MAP_W * 0.5, 0.0, Balance.MAP_H * 0.5), grass)
	_plane(Vector2(Balance.MAP_W, 4.2), Vector3(Balance.MAP_W * 0.5, 0.006, 2.1), sand)
	_plane(Vector2(Balance.MAP_W, 4.5), Vector3(Balance.MAP_W * 0.5, 0.006, 47.75), sand)
	_plane(Vector2(54.0, 34.0), Vector3(44.0, 0.012, 25.0), meadow)


func _water() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for poly in sim.water_polys:
		_poly(st, poly, -0.2)
	_sheet(st, _mat("water", Color(0.16, 0.46, 0.78, 0.9), 0.08))
	for isle in sim.isles:
		if isle.has("poly"):
			var shore := SurfaceTool.new()
			shore.begin(Mesh.PRIMITIVE_TRIANGLES)
			_poly(shore, isle["poly"], 0.04)
			_sheet(shore, _mat("isle", Color(0.45, 0.62, 0.3), 1.0))
		else:
			var cyl := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = float(isle["r"])
			mesh.bottom_radius = float(isle["r"])
			mesh.height = 0.16
			cyl.mesh = mesh
			cyl.position = Vector3(isle["pos"].x, 0.08, isle["pos"].y)
			cyl.material_override = _mat("isle", Color(0.45, 0.62, 0.3), 1.0)
			cyl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			map_root.add_child(cyl)


func _road() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x := 20.0
	while x < 68.0:
		var z := 22.0
		while z < 29.0:
			var mid := Vector2(x + 1.0, z + 1.0)
			if not _wet(mid) and not _on_bridge(mid):
				_quad(st, x, z, x + 2.0, z + 2.0, 0.03)
			z += 2.0
		x += 2.0
	_sheet(st, _mat("road", Color(0.62, 0.48, 0.28), 0.95))
	for item in sim.bridges:
		var rect: Rect2 = item
		var c := rect.get_center()
		_box(Vector3(rect.size.x, 0.14, rect.size.y), Vector3(c.x, 0.1, c.y), _mat("plank", Color(0.56, 0.38, 0.2), 0.82))
		_box(Vector3(rect.size.x, 0.28, 0.08), Vector3(c.x, 0.3, rect.position.y + 0.04), _mat("rail", Color(0.4, 0.26, 0.14), 0.9))
		_box(Vector3(rect.size.x, 0.28, 0.08), Vector3(c.x, 0.3, rect.end.y - 0.04), _mat("rail", Color(0.4, 0.26, 0.14), 0.9))


func _yards() -> void:
	var west := Rect2(4.5, 14.5, 15.0, 22.0)
	var east := Rect2(68.5, 14.5, 15.0, 22.0)
	_curb(west, true)
	_curb(east, false)
	_tile_floor(west)
	_tile_floor(east)


func _curb(rect: Rect2, open_east: bool) -> void:
	# Stone lip around the castle, left open on the gate side so the doorway stays clear.
	var mat := _mat("curb", Color(0.5, 0.48, 0.44), 0.92)
	var h := 0.28
	var t := 0.62
	var y := h * 0.5
	var c := rect.get_center()
	_box(Vector3(rect.size.x + t * 2.0, h, t), Vector3(c.x, y, rect.position.y - t * 0.5), mat)
	_box(Vector3(rect.size.x + t * 2.0, h, t), Vector3(c.x, y, rect.end.y + t * 0.5), mat)
	if open_east:
		_box(Vector3(t, h, rect.size.y), Vector3(rect.position.x - t * 0.5, y, c.y), mat)
	else:
		_box(Vector3(t, h, rect.size.y), Vector3(rect.end.x + t * 0.5, y, c.y), mat)


func _tile_floor(rect: Rect2) -> void:
	var nx := 4
	var nz := 5
	var sx := rect.size.x / float(nx)
	var sz := rect.size.y / float(nz)
	for i in nx:
		for j in nz:
			var pos := Vector3(rect.position.x + sx * (float(i) + 0.5), 0.0, rect.position.y + sz * (float(j) + 0.5))
			_put("tile", pos, 0.0, Vector3(sx / 4.0, 1.0, sz / 4.0))


func _walls() -> void:
	for w in sim.walls:
		var rect: Rect2 = w["rect"]
		if str(w.get("kind", "")) == "door":
			_add_door(w, rect)
		else:
			_tile_wall(rect)
	_corners()
	_gate_dressing()


func _tile_wall(rect: Rect2) -> void:
	var along_x := rect.size.x >= rect.size.y
	var length := rect.size.x if along_x else rect.size.y
	var thick := rect.size.y if along_x else rect.size.x
	var count := maxi(1, int(round(length / 2.6)))
	var each := length / float(count)
	var scl := Vector3(each / 4.0, 2.75 / 4.0, thick)
	var center := rect.get_center()
	var start := (rect.position.x if along_x else rect.position.y) + each * 0.5
	var yaw := 0.0 if along_x else -PI * 0.5
	for i in count:
		var at := start + each * float(i)
		var pos := Vector3(at if along_x else center.x, 0.0, center.y if along_x else at)
		_put("wall", pos, yaw, scl)


func _add_door(door, rect: Rect2) -> void:
	var along_x := rect.size.x >= rect.size.y
	var length := rect.size.x if along_x else rect.size.y
	var thick := rect.size.y if along_x else rect.size.x
	var center := rect.get_center()
	var yaw := 0.0 if along_x else -PI * 0.5
	var gate := _put("wall", Vector3(center.x, 0.0, center.y), yaw, Vector3(length / 4.0, 2.75 / 4.0, thick))
	if gate != null:
		var tint := Color(1.0, 0.8, 0.76) if int(door.get("team", 0)) == 0 else Color(0.76, 0.84, 1.0)
		_tint_meshes(gate, tint)
	_box(Vector3(rect.size.x, 0.07, rect.size.y), Vector3(center.x, 0.04, center.y), _mat("sill", Color(0.55, 0.52, 0.48), 0.9))
	var home := Vector3.ZERO
	if gate != null:
		home = gate.position
	doors.append({"door": door, "gate": gate, "hp": float(door.get("hp", 0.0)), "buzz": 0.0, "home": home})


func _corners() -> void:
	for team in [0, 1]:
		var min_x := 1000.0
		var min_y := 1000.0
		var max_x := -1.0
		var max_y := -1.0
		var any := false
		for w in sim.walls:
			if str(w.get("kind", "")) != "wall":
				continue
			var rect: Rect2 = w["rect"]
			if team == 0 and rect.position.x > 30.0:
				continue
			if team == 1 and rect.end.x < 50.0:
				continue
			any = true
			min_x = minf(min_x, rect.position.x)
			min_y = minf(min_y, rect.position.y)
			max_x = maxf(max_x, rect.end.x)
			max_y = maxf(max_y, rect.end.y)
		if not any:
			continue
		for corner in [Vector2(min_x, min_y), Vector2(max_x, min_y), Vector2(min_x, max_y), Vector2(max_x, max_y)]:
			_put("pillar", Vector3(corner.x, 0.0, corner.y), 0.0, Vector3(0.7, 0.72, 0.7))


func _gate_dressing() -> void:
	for team in [0, 1]:
		var min_y := 1000.0
		var max_y := -1.0
		var x := 0.0
		var any := false
		for w in sim.walls:
			if str(w.get("kind", "")) != "door" or int(w.get("team", -1)) != team:
				continue
			var rect: Rect2 = w["rect"]
			any = true
			min_y = minf(min_y, rect.position.y)
			max_y = maxf(max_y, rect.end.y)
			x = rect.get_center().x
		if not any:
			continue
		_put("pillar", Vector3(x, 0.0, min_y), 0.0, Vector3(0.58, 0.66, 0.58))
		_put("pillar", Vector3(x, 0.0, max_y), 0.0, Vector3(0.58, 0.66, 0.58))
		var side := -1.0 if team == 0 else 1.0
		var yaw := -PI * 0.5 if team == 0 else PI * 0.5
		_put("torch", Vector3(x + side * 0.95, 1.55, min_y - 0.45), yaw, Vector3(1.15, 1.15, 1.15))
		_put("torch", Vector3(x + side * 0.95, 1.55, max_y + 0.45), yaw, Vector3(1.15, 1.15, 1.15))
		var banner := "banner_red" if team == 0 else "banner_blue"
		_put(banner, Vector3(x + side * 2.6, -0.42, (min_y + max_y) * 0.5), yaw, Vector3(0.82, 0.82, 0.82))
		var cloth := Color(0.82, 0.16, 0.24) if team == 0 else Color(0.18, 0.38, 0.82)
		_box(Vector3(6.2, 0.045, 0.7), Vector3(x + side * 5.2, 0.07, (min_y + max_y) * 0.5), _mat("carpet" + str(team), cloth, 0.7))


func _props() -> void:
	for k in sim.keeps:
		var p: Vector2 = k["pos"]
		_put("pillar", Vector3(p.x, 0.0, p.y), float(k.get("door", 0.0)), Vector3(0.5, 0.55, 0.5))
		_flag(p + Vector2(0.55, 0.0), k)
	for tower in sim.towers:
		var p2: Vector2 = tower["pos"]
		_put("pillar", Vector3(p2.x, 0.0, p2.y), 0.0, Vector3(0.72, 0.8, 0.72))
		_flag(p2 + Vector2(0.7, 0.0), tower)
	if sim.outpost != null:
		var op: Vector2 = sim.outpost["pos"]
		_put("wood", Vector3(op.x, 0.0, op.y), 0.0, Vector3(0.85, 1.0, 0.85))
		_put("column", Vector3(op.x, 0.05, op.y), 0.0, Vector3(1.3, 2.2, 1.3))
		_flag(op + Vector2(0.9, 0.0), sim.outpost)
	for forge in sim.forges:
		var fp: Vector2 = forge["pos"]
		var chest := _put("chest", Vector3(fp.x, 0.12, fp.y), 0.4, Vector3(0.72, 0.72, 0.72))
		var pile := _put("rubble", Vector3(fp.x, 0.0, fp.y), 0.3, Vector3(0.2, 0.2, 0.2))
		_put("barrel", Vector3(fp.x + 0.85, 0.0, fp.y + 0.15), 0.6, Vector3(0.65, 0.65, 0.65))
		forges.append({"src": forge, "chest": chest, "pile": pile})
	for cat in sim.catapults:
		_catapult(cat["pos"], int(cat["team"]))
	for ladder in sim.ladders:
		_plank(ladder["pos"], ladder["to"])
	for spring in sim.springs:
		var sp: Vector2 = spring["pos"]
		_cyl(0.4, 0.08, Vector3(sp.x, 0.05, sp.y), _mat("spring", Color(0.4, 0.9, 0.55, 0.9), 0.2))
	for sewer in sim.sewers:
		var sv: Vector2 = sewer["pos"]
		var mouth := _put("doorway", Vector3(sv.x, 0.0, sv.y), PI, Vector3(0.4, 0.4, 0.4))
		strikes.append({
			"src": sewer, "root": mouth, "hp": float(sewer.get("hp", 0.0)),
			"buzz": 0.0, "kind": "sewer", "at": sv, "scale": Vector3(0.4, 0.4, 0.4),
		})
	for vault in sim.vaults:
		var vp: Vector2 = vault["pos"]
		var vr := float(vault["r"])
		for i in 6:
			var a := TAU * float(i) / 6.0
			var ring := vp + Vector2(cos(a), sin(a)) * vr
			_put("column", Vector3(ring.x, 0.0, ring.y), 0.0, Vector3(1.05, 1.15, 1.05))
	for cake in sim.cakes:
		_cake(cake["pos"])
	for rock in sim.rocks:
		var rp: Vector2 = rock["pos"]
		var rock_s: float = float(rock["r"]) * 2.3 / 8.1
		var rock_scale := Vector3(rock_s, rock_s * 0.85, rock_s)
		var stone := _put("rubble", Vector3(rp.x, 0.0, rp.y), float(_hash2(rp.x, rp.y)) * 0.4, rock_scale)
		strikes.append({
			"src": rock, "root": stone, "hp": float(rock.get("hp", 0.0)),
			"buzz": 0.0, "kind": "rock", "at": rp, "scale": rock_scale,
		})
	for bank in [Vector2(23.4, 21.5), Vector2(27.2, 27.5), Vector2(64.6, 21.5), Vector2(60.8, 27.5)]:
		_put("rubble", Vector3(bank.x, 0.0, bank.y), float(_hash2(bank.x, bank.y)) * 0.5, Vector3(0.16, 0.14, 0.16))


func _flag(pos: Vector2, src) -> void:
	_box(Vector3(0.06, 2.15, 0.06), Vector3(pos.x, 1.08, pos.y), _mat("pole", Color(0.42, 0.3, 0.16), 0.8))
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.55
	mat.albedo_color = Color(0.9, 0.78, 0.35)
	_box(Vector3(0.06, 0.62, 0.46), Vector3(pos.x, 1.85, pos.y + 0.2), mat)
	flags.append({"mat": mat, "src": src})


func _catapult(pos: Vector2, team: int) -> void:
	var stripe := Color(0.75, 0.2, 0.24) if team == 0 else Color(0.2, 0.4, 0.78)
	_box(Vector3(1.2, 0.22, 0.72), Vector3(pos.x, 0.12, pos.y), _mat("cat", Color(0.5, 0.33, 0.18), 0.85))
	_box(Vector3(0.85, 0.06, 0.72), Vector3(pos.x, 0.26, pos.y), _mat("cat" + str(team), stripe, 0.55))
	var arm := _box(Vector3(0.82, 0.08, 0.16), Vector3(pos.x + 0.2, 0.48, pos.y), _mat("arm", Color(0.38, 0.24, 0.12), 0.8))
	if arm:
		arm.rotation.z = -0.55


func _plank(a: Vector2, b: Vector2) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 0.2:
		return
	var mid := (a + b) * 0.5
	var node := _box(Vector3(length, 0.08, 0.22), Vector3(mid.x, 0.08, mid.y), _mat("ladder", Color(0.62, 0.46, 0.24), 0.85))
	if node:
		node.rotation.y = -delta.angle()


func _cake(pos: Vector2) -> void:
	_cyl(0.42, 0.16, Vector3(pos.x, 0.22, pos.y), _mat("icing", Color(0.96, 0.46, 0.62), 0.35))
	_cyl(0.32, 0.12, Vector3(pos.x, 0.36, pos.y), _mat("cream", Color(0.98, 0.94, 0.86), 0.3))
	_cyl(0.24, 0.1, Vector3(pos.x, 0.48, pos.y), _mat("icing", Color(0.96, 0.46, 0.62), 0.35))
	_sphere(0.07, Vector3(pos.x, 0.6, pos.y), _mat("cherry", Color(0.82, 0.12, 0.18), 0.25))


func _forest() -> void:
	for spot in [6.0, 16.0, 26.0, 34.0, 54.0, 64.0, 74.0, 84.0]:
		var xf := float(spot)
		_thicket(Vector2(xf, 2.5), 1)
		_thicket(Vector2(xf + 2.3, 3.5), 2)
		_thicket(Vector2(xf, 47.3), 3)
		_thicket(Vector2(xf - 2.3, 46.4), 4)
	for node in sim.nodes:
		var pos: Vector2 = node["pos"]
		var kind := str(node.get("kind", "tree"))
		var root: Node3D = null
		var scl := Vector3.ONE
		if kind == "animal":
			root = _animal(pos)
			scl = Vector3.ONE
		elif kind == "plant":
			var bush := 0.15
			root = _tree(pos, "pine_s", bush, float(_hash2(pos.x, pos.y)))
			scl = Vector3(bush, bush, bush)
		else:
			var pick := "pine" if _hash2(pos.x, pos.y) % 2 == 0 else "dead"
			var tall := 0.62 + float(_hash2(pos.x, pos.y) % 3) * 0.08
			root = _tree(pos, pick, tall, float(_hash2(pos.y, pos.x)) * 0.7)
			scl = Vector3(tall, tall, tall)
		if root == null:
			continue
		var bits: Array = []
		if kind == "tree":
			bits = _splinters(root)
		harvest.append({
			"src": node, "root": root, "scale": scl, "kind": kind,
			"phase": float(_hash2(pos.x, pos.y)), "yaw": root.rotation.y,
			"hp": float(node.get("hp", 0.0)), "buzz": 0.0, "bits": bits,
		})


func _thicket(pos: Vector2, salt: int) -> void:
	var pick := "dead" if (salt + _hash2(pos.x, pos.y)) % 3 != 0 else "pine"
	var tall := 0.7 + float(salt % 3) * 0.08
	_tree(pos, pick, tall, float(salt) * 0.8)


func _animal(pos: Vector2) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(pos.x, 0.0, pos.y)
	root.rotation.y = float(_hash2(pos.x, pos.y)) * 0.9
	map_root.add_child(root)
	var body := _sphere(0.28, Vector3(0.0, 0.3, 0.0), _mat("boar", Color(0.46, 0.28, 0.18), 0.85))
	body.reparent(root, false)
	body.scale = Vector3(1.35, 0.82, 0.95)
	var head := _sphere(0.16, Vector3(0.34, 0.34, 0.0), _mat("boar", Color(0.5, 0.32, 0.2), 0.8))
	head.reparent(root, false)
	var snout := _sphere(0.07, Vector3(0.48, 0.3, 0.0), _mat("snout", Color(0.72, 0.48, 0.42), 0.6))
	snout.reparent(root, false)
	for side in [-1.0, 1.0]:
		for step in [-0.12, 0.14]:
			var leg := _sphere(0.07, Vector3(step, 0.08, side * 0.16), _mat("hoof", Color(0.28, 0.16, 0.1), 0.9))
			leg.reparent(root, false)
	return root


func _gems() -> void:
	var mesh := _gem_mesh()
	for d in sim.diamonds:
		var node := MeshInstance3D.new()
		node.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.12
		mat.emission_enabled = true
		mat.emission_energy_multiplier = 0.7
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if int(d.team) == 0:
			mat.albedo_color = Color(1.0, 0.28, 0.34)
			mat.emission = Color(0.65, 0.08, 0.1)
		else:
			mat.albedo_color = Color(0.35, 0.78, 1.0)
			mat.emission = Color(0.08, 0.28, 0.55)
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx_root.add_child(node)
		gems.append(node)


func _present_world(dt: float) -> void:
	for row in doors:
		var gate: Node3D = row["gate"]
		if gate == null:
			continue
		gate.visible = float(row["door"].get("hp", 0.0)) > 0.0
	for row in forges:
		var built := bool(row["src"].get("built", false))
		var chest: Node3D = row["chest"]
		var pile: Node3D = row["pile"]
		if chest:
			chest.visible = built
		if pile:
			pile.visible = not built
	for row in harvest:
		var src = row["src"]
		var root: Node3D = row["root"]
		var hp := float(src.get("hp", 0.0))
		var prev_hp := float(row["hp"])
		row["hp"] = hp
		var buzz := float(row["buzz"])
		if hp < prev_hp - 0.05:
			buzz = 1.0
			_thump(src["pos"], hp <= 0.0)
		buzz = maxf(0.0, buzz - dt * 3.4)
		row["buzz"] = buzz
		var up := hp > 0.0
		var base: Vector3 = row["scale"]
		var yaw := float(row["yaw"])
		var kind := str(row["kind"])
		if kind == "animal":
			root.visible = up
			if up:
				var at: Vector2 = src["pos"]
				var hop := sin(float(sim.time) * 2.2 + float(row["phase"])) * 0.035
				var flinch := sin(float(sim.time) * 48.0) * buzz * 0.14
				root.position = Vector3(at.x + flinch, hop, at.y)
				root.rotation = Vector3(0.0, yaw, sin(float(sim.time) * 42.0) * buzz * 0.25)
		else:
			root.visible = true
			var at2: Vector2 = src["pos"]
			var max_hp := maxf(1.0, float(src.get("max", hp)))
			var ratio := clampf(hp / max_hp, 0.0, 1.0)
			if up:
				var lean := (1.0 - ratio) * 0.42
				var jx := sin(float(sim.time) * 54.0) * buzz * 0.1
				var jz := cos(float(sim.time) * 46.0) * buzz * 0.08
				root.position = Vector3(at2.x, 0.0, at2.y)
				root.rotation = Vector3(lean * 0.4 + jx, yaw, lean + jz)
				root.scale = Vector3(base.x * (1.0 + (1.0 - ratio) * 0.1), base.y * lerpf(0.58, 1.0, ratio), base.z)
			else:
				root.position = Vector3(at2.x, 0.08, at2.y)
				root.rotation = Vector3(1.35, yaw, 0.22)
				root.scale = base * 0.7
			for bit in row["bits"]:
				var chip: MeshInstance3D = bit
				chip.visible = up and ratio < 0.9
	for row in flags:
		var owner := int(row["src"].get("owner", -1))
		var mat: StandardMaterial3D = row["mat"]
		if owner == 0:
			mat.albedo_color = Color(0.86, 0.16, 0.22)
		elif owner == 1:
			mat.albedo_color = Color(0.18, 0.4, 0.86)
		else:
			mat.albedo_color = Color(0.9, 0.78, 0.35)
	var i := 0
	for d in sim.diamonds:
		if i >= gems.size():
			break
		var node: MeshInstance3D = gems[i]
		i += 1
		var pos := Vector3(d.pos.x, 0.48, d.pos.y)
		if d.carrier != null and is_instance_valid(d.carrier):
			var face: float = d.carrier.facing
			var at: Vector2 = d.carrier.global_position
			pos = Vector3(at.x + cos(face) * 0.32, 1.18, at.y + sin(face) * 0.32)
		elif d.in_flight:
			pos.y = 0.95
		pos.y += sin(float(sim.time) * 3.0 + float(i)) * 0.05
		node.position = pos
		node.rotation.y = float(sim.time) * 1.7


func _sync_actors() -> void:
	var live := {}
	for u in sim.units:
		if not is_instance_valid(u):
			continue
		var id := str(u.unit_id)
		live[id] = true
		if not actors.has(id):
			var made := _make_actor(u)
			if not made.is_empty():
				actors[id] = made
	var drop: Array = []
	for id in actors.keys():
		if not live.has(id):
			drop.append(id)
	for id in drop:
		var old = actors[id]
		var root: Node = old["root"]
		if is_instance_valid(root):
			root.free()
		actors.erase(id)


func _make_actor(u) -> Dictionary:
	var hero := _hero_key(str(u.unit_id))
	var root := Node3D.new()
	root.name = str(u.unit_id)
	cast_root.add_child(root)
	var model := _instance(hero)
	if model == null:
		root.free()
		return {}
	var scl: float = float(HERO_SCALE.get(hero, 0.68))
	model.scale = Vector3(scl, scl, scl)
	root.add_child(model)
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_prep(anim)
	var props: Array = []
	var by := {}
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		if mi == null:
			continue
		if _is_prop(str(mi.name)):
			mi.visible = false
			props.append(mi)
			by[str(mi.name)] = mi
	var team := int(u.team)
	var tint := Color(1.0, 0.48, 0.5) if team == 0 else Color(0.48, 0.64, 1.0)
	for mesh2 in model.find_children("*", "MeshInstance3D", true, false):
		var part := mesh2 as MeshInstance3D
		if part == null:
			continue
		var pname := str(part.name)
		if _team_part(pname):
			_tint_meshes(part, tint)
	var shade := _cyl_node(0.58, 0.03, _fx_mat("shade", Color(0, 0, 0, 0.3)))
	shade.position = Vector3(0, 0.02, 0)
	root.add_child(shade)
	var ring_col := Color(0.9, 0.18, 0.24, 0.9) if team == 0 else Color(0.2, 0.45, 0.95, 0.9)
	var ring := _cyl_node(0.74, 0.035, _fx_mat("ring" + str(team), ring_col))
	ring.position = Vector3(0, 0.035, 0)
	root.add_child(ring)
	var bar := Node3D.new()
	bar.position = Vector3(0, 2.08, 0)
	root.add_child(bar)
	var back := MeshInstance3D.new()
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(0.72, 0.09, 0.02)
	back.mesh = back_mesh
	back.material_override = _fx_mat("hpback", Color(0.08, 0.06, 0.05, 0.85))
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar.add_child(back)
	var fill := MeshInstance3D.new()
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(0.68, 0.06, 0.025)
	fill.mesh = fill_mesh
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color(0.3, 0.75, 0.25)
	fill.material_override = fill_mat
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar.add_child(fill)
	var label := Label3D.new()
	label.text = str(u.unit_name)
	label.font_size = 42
	label.pixel_size = 0.011
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	label.outline_modulate = Color(0.06, 0.04, 0.03)
	label.modulate = Color(1.0, 0.92, 0.9) if team == 0 else Color(0.9, 0.94, 1.0)
	label.position = Vector3(0, 2.32, 0)
	root.add_child(label)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.12)
	light.light_energy = 0.65
	light.omni_range = 3.2
	light.shadow_enabled = false
	light.position = Vector3(0, 0.9, 0)
	light.visible = false
	root.add_child(light)
	return {
		"root": root, "model": model, "anim": anim, "unit": u, "props": props, "by": by,
		"gear": "", "shown": null, "light": light, "fill": fill, "fill_mat": fill_mat,
		"bar": bar, "clip": "", "prev": u.global_position, "wind": 0.0, "swing": 0.0,
		"pose": -1, "hp": float(u.hp), "react": 0.0,
		"trail": 0.0, "trail_t": 0.0, "speed": 0.0, "loco": "",
	}


func _present_actor(actor: Dictionary, dt: float) -> void:
	var u = actor["unit"]
	if u == null or not is_instance_valid(u):
		return
	var root: Node3D = actor["root"]
	var prev: Vector2 = actor["prev"]
	var p: Vector2 = u.global_position
	# The body only moves on a physics tick. A render frame in between has no
	# delta, and treating that as a stop restarted the clip every other frame.
	# That snap is the head and body shake. Average the real travel instead.
	var moved: float = prev.distance_to(p)
	actor["prev"] = p
	actor["trail"] = float(actor["trail"]) + moved
	actor["trail_t"] = float(actor["trail_t"]) + dt
	var speed: float = float(actor["speed"])
	if float(actor["trail_t"]) >= 0.12:
		speed = float(actor["trail"]) / float(actor["trail_t"])
		actor["speed"] = speed
		actor["trail"] = 0.0
		actor["trail_t"] = 0.0
	var y := 0.04
	if _on_bridge(p):
		y = 0.2
	elif sim.in_water(p):
		y = -0.28
	if u.hop != null:
		var dur := maxf(0.05, float(u.hop.dur))
		var along := clampf(1.0 - float(u.hop.t) / dur, 0.0, 1.0)
		y += sin(along * PI) * 0.55
	elif u.dash != null:
		y += 0.06
	root.position = Vector3(p.x, y, p.y)
	var model: Node3D = actor["model"]
	if model != null:
		model.rotation.y = FACE_OFFSET - float(u.facing)
		var show := true
		if float(u.invuln) > 0.0 and not bool(u.dead):
			show = sin(float(sim.time) * 30.0) > 0.0
		model.visible = show
	var client := str(sim.net_role) == "client"
	if client and float(u.hp) < float(actor["hp"]) - 0.5 and int(u.net_pose) == 0:
		actor["react"] = 0.32
	actor["react"] = maxf(0.0, float(actor["react"]) - dt)
	actor["hp"] = float(u.hp)
	var picked := _choose(u, actor, speed, client)
	var clip := str(picked["clip"])
	var spd: float = float(picked["speed"])
	var restart := clip != str(actor["clip"])
	var wind := float(u.attack_wind)
	var swing := float(u.swing_vis)
	if wind > float(actor["wind"]) + 0.01 or (swing > 0.05 and float(actor["swing"]) <= 0.01):
		if clip == "1H_Melee_Attack_Chop" or clip == "Unarmed_Melee_Attack_Punch_A" or clip == "Spellcast_Shoot":
			restart = true
	if int(u.net_pose) == 2 and int(actor["pose"]) != 2:
		restart = true
	actor["wind"] = wind
	actor["swing"] = swing
	actor["pose"] = int(u.net_pose)
	_play(actor, clip, spd, restart)
	_gear(actor, str(u.weapon), float(u.fire_sword_t) > 0.0 and int(u.fire_sword_hits) > 0)
	var ratio := 0.0
	if float(u.max_hp) > 0.01:
		ratio = clampf(float(u.hp) / float(u.max_hp), 0.0, 1.0)
	var fill: MeshInstance3D = actor["fill"]
	fill.scale.x = maxf(ratio, 0.001)
	fill.position.x = -0.34 * (1.0 - ratio)
	var fill_mat: StandardMaterial3D = actor["fill_mat"]
	fill_mat.albedo_color = Color(0.82 * (1.0 - ratio) + 0.16, 0.72 * ratio + 0.14, 0.16)
	var bar: Node3D = actor["bar"]
	bar.visible = not bool(u.dead)
	if camera != null:
		bar.global_basis = camera.global_basis


func _choose(u, actor: Dictionary, speed: float, client: bool) -> Dictionary:
	var weapon := str(u.weapon)
	var clip := "Idle"
	var spd := 1.0
	if bool(u.dead) or (client and int(u.net_pose) == 5):
		return {"clip": "Death_A", "speed": 1.0}
	if client:
		var pose := int(u.net_pose)
		if pose == 6:
			if speed > 5.5:
				return {"clip": "Dodge_Forward", "speed": DODGE_SPEED}
			return {"clip": "Jump_Full_Short", "speed": HOP_SPEED}
		if pose == 4:
			var skill := int(u.net_skill)
			if skill == 3 or skill == 6:
				return {"clip": "Spellcasting", "speed": 1.0}
			return {"clip": "Use_Item", "speed": 1.45}
		if pose == 3:
			return {"clip": "Spellcast_Shoot", "speed": CAST_SPEED}
		if pose == 2:
			return {"clip": _attack_clip(weapon), "speed": _attack_speed(weapon)}
		if float(actor["react"]) > 0.0 and pose == 0:
			return {"clip": "Hit_A", "speed": 1.5}
	else:
		if u.dash != null:
			return {"clip": "Dodge_Forward", "speed": DODGE_SPEED}
		if u.hop != null or u.flight != null:
			var hop_speed: float = HOP_SPEED if u.hop != null else 1.4
			return {"clip": "Jump_Full_Short", "speed": hop_speed}
		if u.channel != null:
			var kind := str(u.channel.kind)
			if kind == "mega" or kind == "saber":
				return {"clip": "Spellcasting", "speed": 1.0}
			return {"clip": "Use_Item", "speed": 1.45}
		if u.cast != null:
			return {"clip": "Spellcast_Shoot", "speed": CAST_SPEED}
		if float(u.attack_wind) > 0.0 or float(u.swing_vis) > 0.0:
			return {"clip": _attack_clip(weapon), "speed": _attack_speed(weapon)}
		if float(u.hit_flash) > 0.04:
			return {"clip": "Hit_A", "speed": 1.5}
	var had := str(actor.get("loco", ""))
	if speed > 5.0 or (had == "Running_A" and speed > 3.8):
		clip = "Running_A"
		spd = clampf(speed * RUN_SCALE, 0.85, 2.8)
	elif speed > 0.65 or ((had == "Walking_A" or had == "Running_A") and speed > 0.28):
		clip = "Walking_A"
		spd = clampf(speed * WALK_SCALE, 0.7, 1.7)
	elif not client and bool(u.guard):
		clip = "Blocking"
	elif not client and _working(u):
		clip = "Interact"
	elif weapon == "none":
		clip = "Unarmed_Idle"
	else:
		clip = "Idle"
	if clip == "Walking_A" or clip == "Running_A":
		actor["loco"] = clip
	else:
		actor["loco"] = ""
	return {"clip": clip, "speed": spd}


func _working(u) -> bool:
	if bool(u.dead):
		return false
	var order := str(sim.bot_order(u))
	if order != "door" and order != "supply":
		return false
	return u.wish.length_squared() < 0.04 and (int(u.wood) > 0 or int(u.fiber) > 0 or int(u.hide) > 0)


func _attack_clip(weapon: String) -> String:
	if weapon == "sword":
		return "1H_Melee_Attack_Chop"
	if weapon == "wand":
		return "Spellcast_Shoot"
	return "Unarmed_Melee_Attack_Punch_A"


func _attack_speed(weapon: String) -> float:
	if weapon == "sword":
		return CHOP_SPEED
	if weapon == "wand":
		return CAST_SPEED
	return PUNCH_SPEED


func _play(actor: Dictionary, clip: String, speed: float, restart: bool) -> void:
	var anim: AnimationPlayer = actor["anim"]
	if anim == null:
		return
	if clip == "" or not anim.has_animation(clip):
		clip = "Idle" if anim.has_animation("Idle") else ""
	if clip == "":
		return
	var same := clip == str(actor["clip"])
	# Replay only when the action actually changes. A matching name that the
	# player reports as blank must not seek back to frame zero every draw.
	if restart or not same or (not anim.is_playing() and LOOPY.has(clip)):
		anim.play(clip)
	anim.speed_scale = maxf(speed, 0.05)
	actor["clip"] = clip


func _gear(actor: Dictionary, weapon: String, burning: bool) -> void:
	var key := weapon + ("1" if burning else "0")
	if str(actor["gear"]) == key:
		return
	actor["gear"] = key
	for node in actor["props"]:
		var prop := node as MeshInstance3D
		if prop == null:
			continue
		prop.visible = false
		prop.set_surface_override_material(0, null)
	var names: Array = []
	if weapon == "sword":
		names = SWORD_PROPS
	elif weapon == "wand":
		names = WAND_PROPS
	var shown: MeshInstance3D = null
	var by: Dictionary = actor["by"]
	for want in names:
		if by.has(str(want)):
			shown = by[str(want)]
			shown.visible = true
			break
	actor["shown"] = shown
	if burning and shown != null:
		var mat := StandardMaterial3D.new()
		var base = shown.get_active_material(0)
		if base is StandardMaterial3D:
			mat.albedo_texture = (base as StandardMaterial3D).albedo_texture
		mat.albedo_color = Color(1.0, 0.58, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.32, 0.05)
		mat.emission_energy_multiplier = 1.5
		shown.set_surface_override_material(0, mat)
	var light: OmniLight3D = actor["light"]
	if light:
		light.visible = burning


func _present_ghosts() -> void:
	var need: Array = []
	for u in sim.units:
		if not is_instance_valid(u):
			continue
		for c in u.clones:
			if bool(c.alive) and float(c.hp) > 0.0:
				need.append({"unit": u, "clone": c})
	while ghosts.size() < need.size():
		var made = _make_ghost()
		if made.is_empty():
			break
		ghosts.append(made)
	for i in ghosts.size():
		var g = ghosts[i]
		var root: Node3D = g["root"]
		if i >= need.size():
			root.visible = false
			continue
		root.visible = true
		var u = need[i]["unit"]
		var c = need[i]["clone"]
		var gp: Vector2 = c.pos
		root.position = Vector3(gp.x, 0.04, gp.y)
		var model: Node3D = g["model"]
		if model:
			model.rotation.y = FACE_OFFSET - float(u.facing)
		var owner = actors.get(str(u.unit_id), {})
		var clip := str(owner.get("clip", "Idle"))
		_play(g, clip, 1.0, false)


func _make_ghost() -> Dictionary:
	var root := Node3D.new()
	cast_root.add_child(root)
	var model := _instance("mage")
	if model == null:
		root.free()
		return {}
	var scl: float = float(HERO_SCALE["mage"])
	model.scale = Vector3(scl, scl, scl)
	root.add_child(model)
	_tint_meshes(model, Color(0.7, 0.88, 1.0), 0.45)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		if mi and _is_prop(str(mi.name)):
			mi.visible = false
		if mi:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_prep(anim)
	return {"root": root, "model": model, "anim": anim, "clip": ""}


func _present_fx() -> void:
	if look != null:
		look.draw(sim, camera)
	_present_floats()
	_present_drops()
	_present_piles()


func _beam(pos: Vector2, ang: float, length: float, width: float, color: Color = Color(1, 0.95, 0.45, 0.42)) -> void:
	var node: MeshInstance3D
	if beam_n < beams.size():
		node = beams[beam_n]
	else:
		node = MeshInstance3D.new()
		node.mesh = PlaneMesh.new()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx_root.add_child(node)
		beams.append(node)
	beam_n += 1
	node.visible = true
	var plane: PlaneMesh = node.mesh
	plane.size = Vector2(width, length)
	var fwd := Vector3(cos(ang), 0.0, sin(ang))
	node.position = Vector3(pos.x, 0.1, pos.y) + fwd * (length * 0.5)
	node.rotation = Vector3(0.0, -ang - PI * 0.5, 0.0)
	_paint(node, color)


func _disc(radius: float, y: float, pos: Vector2, mat: Material) -> void:
	var node: MeshInstance3D
	if disc_n < discs.size():
		node = discs[disc_n]
	else:
		node = MeshInstance3D.new()
		node.mesh = CylinderMesh.new()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx_root.add_child(node)
		discs.append(node)
	disc_n += 1
	node.visible = true
	var cyl: CylinderMesh = node.mesh
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.1
	node.position = Vector3(pos.x, y, pos.y)
	node.material_override = mat


func _shot(pos: Vector2) -> void:
	var node: MeshInstance3D
	if shot_n < shots3.size():
		node = shots3[shot_n]
	else:
		node = MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.34
		mesh.height = 0.68
		node.mesh = mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.material_override = _fx_mat("fireball", Color(1.0, 0.55, 0.16, 1.0))
		fx_root.add_child(node)
		shots3.append(node)
	shot_n += 1
	node.visible = true
	node.position = Vector3(pos.x, 0.7, pos.y)


func _fire(pos: Vector2, radius: float, fade: float) -> void:
	var node: MeshInstance3D
	if fire_n < fires3.size():
		node = fires3[fire_n]
	else:
		node = MeshInstance3D.new()
		node.mesh = CylinderMesh.new()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx_root.add_child(node)
		fires3.append(node)
	fire_n += 1
	node.visible = true
	var cyl: CylinderMesh = node.mesh
	cyl.top_radius = radius
	cyl.bottom_radius = radius * 0.72
	cyl.height = 0.08
	node.position = Vector3(pos.x, 0.05, pos.y)
	_paint(node, Color(1.0, 0.42, 0.1, 0.55 * fade))


func _present_floats() -> void:
	var rows: Array = sim.floats
	var start := maxi(0, rows.size() - 16)
	var shown := 0
	for i in range(start, rows.size()):
		var f = rows[i]
		var label: Label3D
		if shown < floaters.size():
			label = floaters[shown]
		else:
			label = Label3D.new()
			label.font_size = 46
			label.pixel_size = 0.012
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.outline_size = 8
			label.outline_modulate = Color(0.05, 0.03, 0.02)
			fx_root.add_child(label)
			floaters.append(label)
		shown += 1
		label.visible = true
		label.text = str(f.text)
		label.modulate = f.color
		var rise := (0.85 - float(f.t)) * 1.5
		label.position = Vector3(f.pos.x, 1.45 + rise, f.pos.y)
	for j in range(shown, floaters.size()):
		(floaters[j] as Node3D).visible = false


func _present_drops() -> void:
	var n: int = sim.weapon_drops.size()
	while drops3.size() < n:
		var node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.72, 0.08, 0.12)
		node.mesh = mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.emission_enabled = true
		mat.emission_energy_multiplier = 0.45
		node.material_override = mat
		fx_root.add_child(node)
		drops3.append(node)
	for i in drops3.size():
		var node2: MeshInstance3D = drops3[i]
		if i >= n:
			node2.visible = false
			continue
		var drop = sim.weapon_drops[i]
		var p: Vector2 = drop["pos"]
		node2.visible = true
		node2.position = Vector3(p.x, 0.48 + sin(float(sim.time) * 3.0 + float(i)) * 0.05, p.y)
		node2.rotation.y = float(sim.time)
		var mat2: StandardMaterial3D = node2.material_override
		if str(drop.get("kind", "")) == "wand":
			mat2.albedo_color = Color(0.45, 0.78, 1.0)
			mat2.emission = Color(0.1, 0.3, 0.55)
		else:
			mat2.albedo_color = Color(1.0, 0.72, 0.28)
			mat2.emission = Color(0.45, 0.22, 0.04)


func _present_piles() -> void:
	var n: int = sim.piles.size()
	while piles3.size() < n:
		var node := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.28
		mesh.bottom_radius = 0.32
		mesh.height = 0.28
		node.mesh = mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.8
		node.material_override = mat
		fx_root.add_child(node)
		piles3.append(node)
	for i in piles3.size():
		var node2: MeshInstance3D = piles3[i]
		if i >= n:
			node2.visible = false
			continue
		var pile = sim.piles[i]
		var p: Vector2 = pile["pos"]
		var wood := int(pile.get("wood", 0))
		var hide := int(pile.get("hide", 0))
		var fiber := int(pile.get("fiber", 0))
		node2.visible = true
		var cyl: CylinderMesh = node2.mesh
		cyl.height = 0.18 + float(mini(6, wood + hide + fiber)) * 0.06
		node2.position = Vector3(p.x, cyl.height * 0.5, p.y)
		var mat2: StandardMaterial3D = node2.material_override
		if fiber > wood and fiber > hide:
			mat2.albedo_color = Color(0.34, 0.62, 0.28)
		elif hide > wood:
			mat2.albedo_color = Color(0.7, 0.56, 0.36)
		else:
			mat2.albedo_color = Color(0.52, 0.34, 0.16)


func _aim(dt: float) -> void:
	if camera == null or sim.player == null or not is_instance_valid(sim.player):
		return
	var p: Vector2 = sim.player.global_position
	var target := Vector3(p.x, CAM_LOOK, p.y)
	if not aimed:
		focus = target
		aimed = true
	else:
		var blend := 1.0 - exp(-5.5 * dt)
		focus = focus.lerp(target, blend)
	var pitch := deg_to_rad(CAM_PITCH)
	var dist := CAM_DIST
	var wobble := 0.0
	if float(sim.shake) > 0.05:
		wobble = sin(float(sim.time) * 47.0) * float(sim.shake) * 0.035
	var buzz_x := 0.0
	var buzz_y := 0.0
	var buzz_z := 0.0
	if thud > 0.02:
		buzz_x = sin(float(sim.time) * 160.0) * thud * 0.12
		buzz_y = sin(float(sim.time) * 128.0) * thud * 0.045
		buzz_z = sin(float(sim.time) * 146.0) * thud * 0.05
	camera.global_position = focus + Vector3(wobble + buzz_x, sin(pitch) * dist + buzz_y, cos(pitch) * dist + buzz_z)
	camera.look_at(focus, Vector3.UP)


func _hide_pool(pool: Array, used: int) -> void:
	for i in pool.size():
		if i >= used:
			(pool[i] as Node3D).visible = false


func _wet(p: Vector2) -> bool:
	for poly in sim.water_polys:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


func _on_bridge(p: Vector2) -> bool:
	for item in sim.bridges:
		var rect: Rect2 = item
		if rect.has_point(p):
			return true
	return false


func _quad(st: SurfaceTool, x0: float, z0: float, x1: float, z1: float, y: float) -> void:
	# Counter-clockwise from above, so the road faces the camera instead of the dirt.
	var n := Vector3.UP
	st.set_normal(n)
	st.set_uv(Vector2(x0, z0))
	st.add_vertex(Vector3(x0, y, z0))
	st.set_normal(n)
	st.set_uv(Vector2(x1, z1))
	st.add_vertex(Vector3(x1, y, z1))
	st.set_normal(n)
	st.set_uv(Vector2(x1, z0))
	st.add_vertex(Vector3(x1, y, z0))
	st.set_normal(n)
	st.set_uv(Vector2(x0, z0))
	st.add_vertex(Vector3(x0, y, z0))
	st.set_normal(n)
	st.set_uv(Vector2(x0, z1))
	st.add_vertex(Vector3(x0, y, z1))
	st.set_normal(n)
	st.set_uv(Vector2(x1, z1))
	st.add_vertex(Vector3(x1, y, z1))


func _poly(st: SurfaceTool, poly: PackedVector2Array, y: float) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	var i := 0
	while i + 2 < idx.size():
		for k in 3:
			var point: Vector2 = poly[idx[i + k]]
			st.set_normal(Vector3.UP)
			st.set_uv(point * 0.08)
			st.add_vertex(Vector3(point.x, y, point.y))
		i += 3


func _sheet(st: SurfaceTool, mat: Material) -> void:
	var mesh := st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var node := MeshInstance3D.new()
	node.mesh = mesh
	if mat is StandardMaterial3D:
		(mat as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	map_root.add_child(node)


func _plane(size: Vector2, pos: Vector3, mat: Material) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	map_root.add_child(node)


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	map_root.add_child(node)
	return node


func _cyl(radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := _cyl_node(radius, height, mat)
	node.position = pos
	map_root.add_child(node)
	return node


func _cyl_node(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _sphere(radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	map_root.add_child(node)
	return node


func _tree(pos: Vector2, key: String, scl: float, yaw: float) -> Node3D:
	var node := _put(key, Vector3(pos.x, 0.0, pos.y), yaw, Vector3(scl, scl, scl))
	if node != null and (key == "pine" or key == "pine_s"):
		# The source pines are yellow and orange. Dye them a deeper green.
		var dye := Color(0.22, 0.42, 0.16) if key == "pine" else Color(0.32, 0.5, 0.24)
		_tint_meshes(node, dye)
	if node != null:
		_watch_tree(node, key, scl)
	return node


func _put(key: String, pos: Vector3, yaw: float, scl: Vector3) -> Node3D:
	var node := _instance(key)
	if node == null:
		return null
	map_root.add_child(node)
	node.position = pos
	node.rotation.y = yaw
	node.scale = scl
	if key == "torch":
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.58, 0.24)
		lamp.light_energy = 1.35
		lamp.omni_range = 7.5
		lamp.shadow_enabled = false
		lamp.position = Vector3(0.0, 0.55, 0.32)
		node.add_child(lamp)
		var flame := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.07
		ball.height = 0.14
		flame.mesh = ball
		var hot := StandardMaterial3D.new()
		hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hot.albedo_color = Color(1.0, 0.74, 0.28)
		hot.emission_enabled = true
		hot.emission = Color(1.0, 0.42, 0.06)
		hot.emission_energy_multiplier = 2.2
		flame.material_override = hot
		flame.position = Vector3(0.0, 0.55, 0.32)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(flame)
	return node


func _instance(key: String) -> Node3D:
	var packed := _scene(key)
	if packed == null:
		return null
	var node := packed.instantiate()
	if node is Node3D:
		return node
	if node != null:
		node.free()
	return null


func _scene(key: String) -> PackedScene:
	match key:
		"knight":
			return KNIGHT
		"mage":
			return MAGE
		"rogue":
			return ROGUE
		"barbarian":
			return BARBARIAN
		"hooded":
			return HOODED
		"wall":
			return WALL
		"doorway":
			return DOORWAY
		"pillar":
			return PILLAR
		"column":
			return COLUMN
		"tile":
			return TILE
		"wood":
			return WOOD
		"banner_red":
			return BANNER_RED
		"banner_blue":
			return BANNER_BLUE
		"chest":
			return CHEST
		"barrel":
			return BARREL
		"rubble":
			return RUBBLE
		"torch":
			return TORCH
		"dead":
			return DEAD
		"dead_s":
			return DEAD_S
		"pine":
			return PINE
		"pine_s":
			return PINE_S
		_:
			return null


func _mat(key: String, color: Color, rough: float) -> StandardMaterial3D:
	if mats.has(key):
		return mats[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	if color.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats[key] = mat
	return mat


func _paint(node: MeshInstance3D, color: Color) -> void:
	var mat: StandardMaterial3D = node.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		node.material_override = mat
	mat.albedo_color = color


func _fx_mat(key: String, color: Color) -> StandardMaterial3D:
	if mats.has(key):
		var old: StandardMaterial3D = mats[key]
		old.albedo_color = color
		return old
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	mats[key] = mat
	return mat


func _tint_meshes(node: Node, color: Color, alpha: float = 1.0) -> void:
	var meshes: Array = []
	if node is MeshInstance3D:
		meshes.append(node)
	else:
		meshes = node.find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		var mi := mesh as MeshInstance3D
		if mi == null:
			continue
		var mat := StandardMaterial3D.new()
		var base = mi.get_active_material(0)
		if base is StandardMaterial3D:
			mat.albedo_texture = (base as StandardMaterial3D).albedo_texture
		mat.albedo_color = color
		mat.roughness = 0.82
		if alpha < 0.99:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = alpha
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.set_surface_override_material(0, mat)


func _is_prop(node_name: String) -> bool:
	for word in ["Sword", "Shield", "Axe", "Knife", "Crossbow", "Wand", "Staff", "Spellbook", "Throwable", "Mug", "Badge"]:
		if node_name.contains(word):
			return true
	return false


func _team_part(node_name: String) -> bool:
	# Dye the costume, including the hood, and leave the face alone.
	if _is_prop(node_name):
		return false
	if node_name.contains("Head") and not node_name.contains("Hood"):
		return false
	for word in ["Body", "Cape", "Hat", "Helmet", "Arm", "Leg", "Hood"]:
		if node_name.contains(word):
			return true
	return false


func _prep(anim: AnimationPlayer) -> void:
	if anim == null:
		return
	var id := anim.get_instance_id()
	if prepped.has(id):
		return
	prepped[id] = true
	for clip_name in anim.get_animation_list():
		var clip := anim.get_animation(clip_name)
		if clip == null:
			continue
		clip.loop_mode = Animation.LOOP_LINEAR if LOOPY.has(clip_name) else Animation.LOOP_NONE


func _hero_key(id: String) -> String:
	if HERO.has(id):
		return str(HERO[id])
	return "knight"


func _splinters(parent: Node3D) -> Array:
	var bits: Array = []
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.44, 0.22)
	mat.roughness = 0.86
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 4:
		var bit := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.18, 0.05, 0.32)
		bit.mesh = box
		bit.material_override = mat
		bit.position = Vector3((float(i) - 1.5) * 0.12, 0.55 + float(i) * 0.12, 0.22)
		bit.rotation = Vector3(0.5, float(i) * 0.8, 0.4)
		bit.visible = false
		bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(bit)
		bits.append(bit)
	for row in cover:
		if row["root"] == parent:
			row["mats"].append(mat)
			break
	return bits


func _watch_tree(node: Node3D, key: String, scl: float) -> void:
	var tall := 5.0
	var wide := 2.15
	if key == "pine_s" or key == "dead_s":
		tall = 3.2
		wide = 1.3
	cover.append({
		"root": node,
		"mats": _own_fade(node),
		"height": scl * tall,
		"radius": scl * wide,
		"alpha": 1.0,
	})


func _own_fade(node: Node) -> Array:
	var found: Array = []
	var meshes: Array = []
	if node is MeshInstance3D:
		meshes.append(node)
	meshes.append_array(node.find_children("*", "MeshInstance3D", true, false))
	for mesh in meshes:
		var mi := mesh as MeshInstance3D
		if mi == null:
			continue
		var mat := mi.get_surface_override_material(0) as StandardMaterial3D
		if mat == null:
			var base = mi.get_active_material(0)
			if base is StandardMaterial3D:
				mat = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
			else:
				mat = StandardMaterial3D.new()
				mat.albedo_color = Color(0.42, 0.34, 0.2)
			mi.set_surface_override_material(0, mat)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var tint := mat.albedo_color
		if tint.a < 0.05:
			tint.a = 1.0
			mat.albedo_color = tint
		found.append(mat)
	return found


func _clear_sight(dt: float) -> void:
	if camera == null or sim == null:
		return
	var cam := camera.global_position
	var heroes: Array[Vector3] = []
	for u in sim.units:
		if u.dead:
			continue
		heroes.append(Vector3(u.global_position.x, 1.15, u.global_position.y))
	var blend := 1.0 - exp(-12.0 * dt)
	for row in cover:
		var root: Node3D = row["root"]
		if root == null or not is_instance_valid(root) or not root.visible:
			continue
		var origin := root.global_position
		var height: float = float(row["height"])
		var radius: float = float(row["radius"])
		var mid := origin + Vector3(0.0, height * 0.42, 0.0)
		var top := origin + Vector3(0.0, height * 0.75, 0.0)
		var block := false
		for hero in heroes:
			var flat := Vector2(origin.x, origin.z).distance_to(Vector2(hero.x, hero.z))
			if flat < radius * 0.9 or _blocks(cam, hero, mid, radius) or _blocks(cam, hero, top, radius * 0.8):
				block = true
				break
		var goal := 0.2 if block else 1.0
		var alpha := lerpf(float(row["alpha"]), goal, blend)
		row["alpha"] = alpha
		for mat in row["mats"]:
			var painted := mat as StandardMaterial3D
			if painted == null:
				continue
			var color := painted.albedo_color
			if alpha > 0.97:
				painted.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				color.a = 1.0
			else:
				painted.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				color.a = alpha
			painted.albedo_color = color


func _blocks(a: Vector3, b: Vector3, p: Vector3, radius: float) -> bool:
	var ab := b - a
	var den := ab.length_squared()
	if den < 0.01:
		return false
	var along := clampf((p - a).dot(ab) / den, 0.0, 1.0)
	if along > 0.9:
		return false
	return a.lerp(b, along).distance_to(p) <= radius


func _thump(pos: Vector2, broke: bool) -> void:
	if sim == null or sim.player == null or not is_instance_valid(sim.player):
		return
	if sim.player.global_position.distance_to(pos) > 8.5:
		return
	thud = minf(1.0, thud + (1.0 if broke else 0.72))
	Sfx.play("crack" if broke else "chop")
	_fling(Vector3(pos.x, 0.85, pos.y), broke)


func _feel_strikes(dt: float) -> void:
	for row in strikes:
		var src = row["src"]
		var hp := float(src.get("hp", 0.0))
		var prev := float(row["hp"])
		row["hp"] = hp
		var buzz := float(row["buzz"])
		if hp < prev - 0.05:
			buzz = 1.0
			var at: Vector2 = row["at"]
			_thump(at, hp <= 0.0)
		buzz = maxf(0.0, buzz - dt * 3.4)
		row["buzz"] = buzz
		var root: Node3D = row["root"]
		if root == null or not is_instance_valid(root):
			continue
		if str(row["kind"]) == "rock":
			root.visible = hp > 0.0
			var max_hp := maxf(1.0, float(src.get("max", hp)))
			var ratio := clampf(hp / max_hp, 0.0, 1.0)
			var base: Vector3 = row["scale"]
			root.scale = base * lerpf(0.28, 1.0, ratio)
			root.rotation.z = sin(float(sim.time) * 52.0) * buzz * 0.22
		else:
			root.rotation.x = sin(float(sim.time) * 48.0) * buzz * 0.14
			if hp <= 0.0:
				root.rotation.z = 0.4
	for row in doors:
		var door = row["door"]
		var hp2 := float(door.get("hp", 0.0))
		var prev2 := float(row["hp"])
		row["hp"] = hp2
		var buzz2 := float(row["buzz"])
		if hp2 < prev2 - 0.05:
			buzz2 = 1.0
			var rect: Rect2 = door["rect"]
			_thump(rect.get_center(), hp2 <= 0.0)
		buzz2 = maxf(0.0, buzz2 - dt * 3.4)
		row["buzz"] = buzz2
		var gate: Node3D = row["gate"]
		if gate == null:
			continue
		var home: Vector3 = row["home"]
		var kick := sin(float(sim.time) * 62.0) * buzz2 * 0.08
		gate.position = home + Vector3(kick, 0.0, cos(float(sim.time) * 50.0) * buzz2 * 0.05)


func _make_chips() -> void:
	chips.clear()
	chip_i = 0
	if fx_root == null:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.78, 0.56, 0.26)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for _i in 18:
		var node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12, 0.05, 0.2)
		node.mesh = mesh
		node.material_override = mat
		node.visible = false
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx_root.add_child(node)
		chips.append({"node": node, "vel": Vector3.ZERO, "life": 0.0})


func _fling(at: Vector3, broke: bool) -> void:
	if chips.is_empty():
		return
	var n := 7 if broke else 4
	for i in n:
		var row = chips[chip_i]
		chip_i = (chip_i + 1) % chips.size()
		var node: MeshInstance3D = row["node"]
		if not is_instance_valid(node):
			continue
		var dir := float(i) * 1.17 + float(chip_i)
		node.visible = true
		node.position = at
		row["vel"] = Vector3(cos(dir) * 2.1, 2.4 + float(i % 3) * 0.45, sin(dir) * 2.1)
		row["life"] = 0.42 if broke else 0.28


func _tick_chips(dt: float) -> void:
	for row in chips:
		var life := float(row["life"])
		if life <= 0.0:
			continue
		life -= dt
		row["life"] = life
		var node: MeshInstance3D = row["node"]
		if not is_instance_valid(node):
			continue
		if life <= 0.0:
			node.visible = false
			continue
		var vel: Vector3 = row["vel"]
		vel.y -= 9.0 * dt
		row["vel"] = vel
		node.position += vel * dt
		node.rotate_z(9.0 * dt)


func _hash2(x: float, y: float) -> int:
	return int(absf(x * 13.0 + y * 29.0)) % 7


func _gem_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0, 0.42, 0)
	var bot := Vector3(0, -0.16, 0)
	var ring: Array = [
		Vector3(0.18, 0.1, 0), Vector3(0, 0.1, 0.18),
		Vector3(-0.18, 0.1, 0), Vector3(0, 0.1, -0.18),
	]
	for i in 4:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		st.add_vertex(top)
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(a)
		st.add_vertex(bot)
		st.add_vertex(b)
	st.generate_normals()
	return st.commit()
