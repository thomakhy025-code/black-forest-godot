extends CharacterBody2D
## One hero. Movement uses Godot's physics motion test against walls, trees,
## rocks, and gates. Bridge-tower solidity stays in the match keep rule.

const Balance = preload("res://scripts/balance.gd")
const State = preload("res://scripts/state.gd")

var sim: Node
var unit_id := ""
var unit_name := "You"
var team := 0
var gender := "female"
var is_player := false
var is_remote := false
var net_controlled := false
var peer_id := 0
var net_pose := 0
var net_skill := 0
var role := "fight"
var radius := 0.48
var facing := 0.0
var stats := {"atk": 0, "spd": 0, "hp": 0, "cdr": 0, "mp": 0}
var hp := 100.0
var max_hp := 100.0
var mp := 100.0
var max_mp := 100.0
var weapon := "none"
var shock := 0.0
var slow_cast := 0.0
var skills := {}
var cds := {}
var cast = null
var attack_wind := 0.0
var attack_cd := 0.0
var swing_vis := 0.0
var swing_kind := "none"
var swing_arc := Balance.SWORD_ARC
var swing_range := Balance.SWORD_RANGE
var swing_len := 0.0
var swing_width := 0.0
var fire_sword_t := 0.0
var fire_sword_hits := 0
var burn = null
var clones: Array = []
var dash = null
var hop = null
var hop_cd := 0.0
var flight = null
var channel = null
var invuln := 0.0
var respawn_t := 0.0
var dead := false
var hit_flash := 0.0
var carrying = null
var wood := 0
var hide := 0
var fiber := 0
var guard := false
var guard_block := false
var wish := Vector2.ZERO
var click_target = null
var warp_cd := 0.0
var move_blend := 0.0
var cast_face := 0.0
var has_cast_face := false
var kills := 0
var active := false
var _font: Font

@onready var sprite: Sprite2D = $Visual/Sprite2D
@onready var fighter: Node2D = $Visual/Fighter
@onready var visual: Node2D = $Visual
@onready var blade: Polygon2D = $Visual/WeaponPivot/Blade
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sensor: Area2D = $Sensor
@onready var body_col: CollisionShape2D = $CollisionShape2D

var _draw_key := -1
var _fade := 1.0
var _quiet := false
var _motion := PhysicsTestMotionParameters2D.new()
var _motion_hit := PhysicsTestMotionResult2D.new()


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	safe_margin = 0.02
	collision_layer = Balance.LAYER_UNIT
	collision_mask = Balance.LAYER_WALL
	var shape := CircleShape2D.new()
	shape.radius = radius
	body_col.shape = shape
	var sensor_shape := CircleShape2D.new()
	sensor_shape.radius = 0.08
	$Sensor/CollisionShape2D.shape = sensor_shape
	sensor.monitoring = false
	sensor.monitorable = false
	sensor.collision_layer = 0
	sensor.collision_mask = Balance.LAYER_WATER | Balance.LAYER_BRIDGE | Balance.LAYER_ISLAND
	sprite.visible = false
	blade.visible = false
	_font = ThemeDB.fallback_font
	_quiet = _under_server_room()
	if _quiet:
		set_process(false)
		visible = false
		if fighter:
			fighter.set_process(false)
			fighter.visible = false
		if visual:
			visual.visible = false
		if anim:
			anim.active = false
	if anim:
		anim.active = false
	set_physics_process(false)


func _under_server_room() -> bool:
	var node: Node = self
	while node != null:
		if node is SubViewport:
			return true
		node = node.get_parent()
	return false


func _sfx(id: String) -> void:
	if _quiet:
		return
	Sfx.play(id)


func setup(def: Dictionary, sim_node: Node) -> void:
	sim = sim_node
	unit_id = str(def["id"])
	unit_name = str(def["name"])
	name = unit_id
	team = int(def["team"])
	var raw_gender := str(def.get("gender", "female"))
	gender = raw_gender if raw_gender == "male" or raw_gender == "female" else "female"
	is_player = bool(def.get("is_player", false))
	is_remote = bool(def.get("is_remote", false))
	net_controlled = bool(def.get("net_controlled", false))
	peer_id = int(def.get("peer_id", 0))
	role = str(def.get("role", "fight"))
	global_position = def["pos"]
	facing = float(def.get("facing", 0.0))
	stats = (def["stats"] as Dictionary).duplicate(true)
	max_hp = Balance.max_hp(stats)
	hp = max_hp
	max_mp = Balance.max_mp(stats)
	mp = max_mp
	skills = {}
	cds = {}
	weapon = ""
	wood = 0
	hide = 0
	fiber = 0
	equip_weapon(str(def.get("weapon", "none")), false)
	invuln = float(def.get("invuln", 0.0))
	collision_mask = sim.mask_for(team)
	active = true


func _process(_delta: float) -> void:
	if not active:
		return
	_sync_visual()


func tick(dt: float) -> void:
	if not active:
		return
	if body_col != null and body_col.disabled != dead:
		body_col.disabled = dead
	collision_mask = sim.mask_for(team)
	if dead:
		respawn_t -= dt
		if respawn_t <= 0.0:
			sim.respawn_unit(self)
		return
	for id in cds.keys():
		if float(cds[id]) > 0.0:
			cds[id] = maxf(0.0, float(cds[id]) - dt)
	shock = maxf(0.0, shock - dt)
	slow_cast = maxf(0.0, slow_cast - dt)
	if guard and carrying == null:
		guard = false
		guard_block = false
	if guard and carrying != null:
		mp = maxf(0.0, mp - Balance.GUARD_DRAIN * dt)
		if mp <= 0.0:
			mp = 0.0
			guard = false
			guard_block = true
			if is_player:
				sim.float_at(global_position + Vector2(0, -0.9), "DEFENSE DOWN", Color(0.75, 0.96, 1))
	else:
		mp = minf(max_mp, mp + 1.0 * dt)
	invuln = maxf(0.0, invuln - dt)
	hop_cd = maxf(0.0, hop_cd - dt)
	warp_cd = maxf(0.0, warp_cd - dt)
	attack_cd = maxf(0.0, attack_cd - dt)
	hit_flash = maxf(0.0, hit_flash - dt)
	swing_vis = maxf(0.0, swing_vis - dt)
	if fire_sword_t > 0.0:
		fire_sword_t -= dt
		if fire_sword_t <= 0.0 or fire_sword_hits <= 0:
			fire_sword_t = 0.0
			fire_sword_hits = 0
	if burn != null and float(burn.t) > 0.0:
		if invuln <= 0.0:
			hp -= sim.mitigated(self, float(burn.dps) * dt)
		burn.t = float(burn.t) - dt
		if hp <= 0.0:
			sim.kill_unit(self, burn.src)
			return
		if float(burn.t) <= 0.0:
			burn = null
	if cast != null:
		if carrying != null:
			cast = null
		else:
			cast.t = float(cast.t) - dt
			if float(cast.t) <= 0.0:
				sim.finish_cast(self)
	if attack_wind > 0.0:
		if carrying != null or dead:
			attack_wind = 0.0
		else:
			attack_wind -= dt
			if attack_wind <= 0.0:
				sim.resolve_swing(self)
	if channel != null:
		channel.t = float(channel.t) - dt
		if float(channel.t) <= 0.0:
			sim.finish_channel(self)
		if channel != null:
			wish = Vector2.ZERO
			if channel.kind == "mega" or channel.kind == "saber":
				click_target = null
				attack_wind = 0.0
				hop = null
				dash = null
				cast = null
	if flight != null:
		flight.t = float(flight.t) + dt
		var k := clampf(float(flight.t) / float(flight.dur), 0.0, 1.0)
		global_position = Vector2(lerpf(flight.x0, flight.x1, k), lerpf(flight.y0, flight.y1, k))
		force_update_transform()
		if k >= 1.0:
			flight = null
			sim.float_at(global_position + Vector2(0, -0.9), "LAND", Color.WHITE)
	elif dash != null:
		var step := (float(dash.dist) / float(dash.dur)) * dt
		var before := global_position
		try_step(cos(dash.dir) * step, sin(dash.dir) * step)
		dash.traveled = float(dash.traveled) + global_position.distance_to(before)
		dash.from_pos = before
		sim.strike_dash(self)
		dash.t = float(dash.t) - dt
		if float(dash.t) <= 0.0 or float(dash.traveled) >= float(dash.dist) - 0.05:
			dash = null
	elif hop != null:
		if shock > 0.0:
			hop = null
		else:
			var hop_step := (float(hop.dist) / float(hop.dur)) * dt
			try_step(cos(hop.dir) * hop_step, sin(hop.dir) * hop_step)
			hop.t = float(hop.t) - dt
			if float(hop.t) <= 0.0:
				hop = null
	elif root_locked():
		wish = Vector2.ZERO
		click_target = null
	else:
		if net_controlled:
			if wish.length_squared() > 0.0:
				facing = wish.angle()
		elif is_player:
			read_player()
		else:
			tick_bot(dt)
		predict_move(dt)
	if dash != null:
		move_blend = 1.0
	elif wish == Vector2.ZERO:
		move_blend = maxf(0.0, move_blend - dt / 0.24)
	sim.eject_keep(self)
	if invuln <= 0.0 and sim.standing_in_fire(self):
		hp -= sim.mitigated(self, 5.0 * dt)
		if hp <= 0.0:
			sim.kill_unit(self, null)
			return
	_follow_clones(dt)
	if carrying != null:
		carrying.pos = global_position + Vector2(0, -0.2)


func predict_move(dt: float) -> void:
	if dead:
		return
	if shock > 0.0:
		wish = Vector2.ZERO
		click_target = null
	var sp := move_speed() * dt
	if sp > 0.0 and wish.length_squared() > 0.0:
		var before2 := global_position
		try_step(wish.x * sp, wish.y * sp)
		if global_position.distance_to(before2) < sp * 0.25:
			var base: float = wish.angle()
			for off in [0.7, -0.7, 1.3, -1.3]:
				try_step(cos(base + off) * sp, sin(base + off) * sp)
				if global_position.distance_to(before2) > sp * 0.25:
					break
		if global_position.distance_to(before2) > 0.004:
			move_blend = minf(1.0, move_blend + dt / 0.18)


func read_player() -> void:
	var mx := 0.0
	var my := 0.0
	if Input.is_action_pressed("move_up"):
		my -= 1.0
	if Input.is_action_pressed("move_down"):
		my += 1.0
	if Input.is_action_pressed("move_left"):
		mx -= 1.0
	if Input.is_action_pressed("move_right"):
		mx += 1.0
	if mx != 0.0 or my != 0.0:
		wish = Vector2(mx, my).normalized()
		click_target = null
	else:
		var stick := _stick_wish()
		if stick.length() > 0.18:
			wish = stick.normalized()
			click_target = null
		elif click_target != null:
			var delta: Vector2 = click_target - global_position
			if delta.length() < 0.35:
				wish = Vector2.ZERO
				click_target = null
			else:
				wish = delta.normalized()
		else:
			wish = Vector2.ZERO
	if wish != Vector2.ZERO:
		facing = wish.angle()


func tick_bot(_dt: float) -> void:
	var foe = null if carrying != null else sim.nearest_enemy(self, 2.1)
	var door = null if carrying != null else sim.enemy_door(self)
	if carrying == null and cast == null and dash == null:
		var acted := false
		if skills.get("fireball", false) and float(cds.get("fireball", 0.0)) <= 0.0 and foe == null:
			var shot = sim.nearest_enemy(self, 12.0)
			if shot != null and global_position.distance_to(shot.global_position) > 4.0 and sim.los(global_position, shot.global_position, team):
				cast_face = (shot.global_position - global_position).angle()
				has_cast_face = true
				facing = cast_face
				acted = try_cast("fireball")
		if not acted and skills.get("spark", false) and float(cds.get("spark", 0.0)) <= 0.0:
			var slash = sim.nearest_enemy(self, 5.0)
			if slash != null and global_position.distance_to(slash.global_position) > 1.2 and sim.los(global_position, slash.global_position, team):
				facing = (slash.global_position - global_position).angle()
				acted = try_cast("spark")
		if not acted and foe != null and skills.get("ignite", false) and float(cds.get("ignite", 0.0)) <= 0.0:
			acted = try_cast("ignite")
		if not acted and foe != null and skills.get("ember", false) and float(cds.get("ember", 0.0)) <= 0.0:
			acted = try_cast("ember")
		if not acted and foe != null and attack_cd <= 0.0:
			try_swing()
		elif not acted and door != null and attack_cd <= 0.0:
			try_swing()
	if role == "defend":
		sim.maybe_repair(self)
	sim.bot_supply(self)
	if warp_cd <= 0.0:
		sim.bot_use_map(self)
	var goal: Dictionary = sim.bot_goal(self)
	var goal_pos: Vector2 = goal["pos"]
	var goal_unit = goal["unit"]
	if goal_unit != null and goal_unit != self and goal_unit.team == team and goal_unit.carrying != null:
		var away: Vector2 = global_position - goal_unit.global_position
		if away.length() < 1.7:
			var n := away.normalized() if away.length() > 0.05 else Vector2(cos(float(unit_id.length())), sin(float(unit_id.length())))
			goal_pos = goal_unit.global_position + n * 1.7
	var wp: Vector2 = sim.steer_point(self, goal_pos)
	var delta := wp - global_position
	var length := delta.length()
	if length < 0.6 and role == "defend" and sim.nearest_enemy(self, 9.0) == null:
		wish = Vector2.ZERO
	elif length > 0.001:
		wish = delta / length
	else:
		wish = Vector2.ZERO
	if cast != null and str(cast.name) == "fireball" and has_cast_face:
		facing = cast_face
	elif wish != Vector2.ZERO:
		facing = wish.angle()


func move_speed() -> float:
	var s := (Balance.PLAYER_SPEED if is_player or is_remote else Balance.BOT_SPEED) * Balance.spd_mul(stats)
	var load := bag_total()
	if load > 0:
		s *= maxf(Balance.BAG_FLOOR, 1.0 - Balance.BAG_SLOW * float(load))
	if carrying != null:
		s *= Balance.CARRY_SPEED
	if sim.in_water(global_position) and hop == null and dash == null and flight == null:
		s *= 0.5
	if cast != null and cast.root:
		return 0.0
	if cast != null and cast.slow:
		s *= 0.5
	if channel != null:
		return 0.0
	if attack_wind > 0.0:
		s *= 0.82
	return s


func try_step(dx: float, dy: float) -> void:
	collision_mask = sim.mask_for(team)
	if absf(dx) > 0.00001:
		var nx := global_position.x + dx
		if not _motion_hits(Vector2(dx, 0.0)) and not sim.keep_blocks(Vector2(nx, global_position.y), team):
			global_position.x = nx
			force_update_transform()
	if absf(dy) > 0.00001:
		var ny := global_position.y + dy
		if not _motion_hits(Vector2(0.0, dy)) and not sim.keep_blocks(Vector2(global_position.x, ny), team):
			global_position.y = ny
			force_update_transform()


func _motion_hits(motion: Vector2) -> bool:
	_motion.from = global_transform
	_motion.motion = motion
	_motion.margin = 0.01
	return PhysicsServer2D.body_test_motion(get_rid(), _motion, _motion_hit)


func root_locked() -> bool:
	return channel != null and (channel.kind == "mega" or channel.kind == "saber")


func try_cast(skill_name: String) -> bool:
	if dead or cast != null or dash != null or flight != null:
		return false
	if channel != null:
		if is_player and root_locked():
			sim.float_at(global_position + Vector2(0, -0.9), "CHANNELING", Color(1, 0.69, 0.69))
		return false
	if carrying != null:
		if is_player:
			sim.float_at(global_position + Vector2(0, -0.9), "CAN'T CAST", Color.WHITE)
		return false
	if shock > 0.0 and skill_name != "fireball":
		if is_player:
			sim.float_at(global_position + Vector2(0, -0.9), "SHOCKED", Color(1, 0.96, 0.66))
		return false
	if not skills.get(skill_name, false):
		if is_player:
			sim.float_at(global_position + Vector2(0, -0.9), "LOCKED", Color(0.87, 0.87, 0.87))
		return false
	var def: Dictionary = Balance.SKILLS[skill_name]
	if float(cds.get(skill_name, 0.0)) > 0.0:
		if is_player:
			sim.float_at(global_position + Vector2(0, -0.9), "COOLDOWN", Color(1, 0.82, 0.66))
		return false
	var cost := Balance.skill_cost(def, max_mp)
	if mp + 0.001 < cost:
		if is_player:
			sim.float_at(global_position + Vector2(0, -0.9), "NO MP", Color(0.73, 0.86, 1))
		return false
	if skill_name == "mega":
		mp -= cost
		cds[skill_name] = float(def["cd"]) * Balance.cd_mul(stats)
		sim.begin_mega(self)
		_sfx("mega")
		return true
	mp -= cost
	var dur := cast_duration(skill_name)
	cds[skill_name] = float(def["cd"]) * Balance.cd_mul(stats)
	var rooted := skill_name == "ignite" or skill_name == "spark"
	cast = State.new()
	cast.name = skill_name
	cast.t = dur
	cast.dur = dur
	cast.root = rooted
	cast.slow = not rooted
	if skill_name == "fireball":
		_sfx("fireball")
	elif skill_name == "ignite" or skill_name == "ember":
		_sfx("firesword")
	elif skill_name == "spark":
		_sfx("swing_fire")
	return true


func cast_duration(skill_name: String) -> float:
	var def: Dictionary = Balance.SKILLS[skill_name]
	var t := float(def["cast"])
	if slow_cast > 0.0:
		t *= 2.0
	return t


func try_swing() -> bool:
	if dead or carrying != null or cast != null or dash != null or flight != null or attack_cd > 0.0 or attack_wind > 0.0:
		return false
	if root_locked():
		if is_player:
			sim.float_at(global_position + Vector2(0, -0.9), "CHANNELING", Color(1, 0.69, 0.69))
		return false
	if shock > 0.0:
		if is_player:
			sim.float_at(global_position + Vector2(0, -0.9), "SHOCKED", Color(1, 0.96, 0.66))
		return false
	if weapon == "wand":
		attack_wind = 0.18
	elif weapon == "sword":
		attack_wind = 0.22
	else:
		attack_wind = 0.16
	attack_cd = Balance.ATTACK_INTERVAL
	return true


func try_hop() -> void:
	if dead or dash != null or flight != null or hop != null or hop_cd > 0.0 or shock > 0.0:
		return
	if cast != null and cast.root:
		return
	if root_locked():
		return
	if channel != null:
		channel = null
	var dir := wish.angle() if wish != Vector2.ZERO else facing
	var dur := 0.26 * (1.0 - 0.005 * float(stats.get("spd", 0)))
	hop = State.new()
	hop.t = dur
	hop.dur = dur
	hop.dir = dir
	hop.dist = 1.25
	hop_cd = 0.85 * (1.0 - 0.005 * float(stats.get("spd", 0)))
	_sfx("hop")


func equip_weapon(kind: String, announce: bool = false) -> bool:
	if kind != "sword" and kind != "wand":
		kind = "none"
	if weapon == kind and _kit_matches(kind):
		return false
	weapon = kind
	var kit: Array = Balance.WEAPON_KITS.get(weapon, [])
	for id in Balance.SKILL_ORDER:
		skills[id] = kit.has(id)
		if not cds.has(id):
			cds[id] = 0.0
	apply_swing_fields(swing_shape())
	if announce and sim != null:
		var text := "UNARMED"
		if weapon == "sword":
			text = "FIERY SWORD"
		elif weapon == "wand":
			text = "MAGIC WAND"
		sim.float_at(global_position + Vector2(0, -0.9), text, Color(1, 0.82, 0.45))
		if is_player and sim.hud and sim.hud.has_method("note_weapon"):
			sim.hud.note_weapon()
	return true


func _kit_matches(kind: String) -> bool:
	var kit: Array = Balance.WEAPON_KITS.get(kind, [])
	for id in Balance.SKILL_ORDER:
		if bool(skills.get(id, false)) != kit.has(id):
			return false
	return true


func apply_swing_fields(shape: Dictionary) -> void:
	swing_kind = str(shape.get("kind", "none"))
	swing_arc = float(shape.get("arc", 0.0))
	swing_range = float(shape.get("range", 0.0))
	swing_len = float(shape.get("len", 0.0))
	swing_width = float(shape.get("w", 0.0))


func toggle_guard() -> void:
	if dead or carrying == null:
		return
	if guard:
		guard = false
		guard_block = false
		sim.float_at(global_position + Vector2(0, -0.9), "DEFENSE OFF", Color(0.75, 0.96, 1))
		return
	if mp <= 0.0:
		sim.float_at(global_position + Vector2(0, -0.9), "NO MP", Color(0.73, 0.86, 1))
		return
	guard = true
	guard_block = false
	sim.float_at(global_position + Vector2(0, -0.9), "DEFENSE", Color(0.75, 0.96, 1))


func clear_guard() -> void:
	guard = false
	guard_block = false


func bag_total() -> int:
	return wood + hide + fiber


func swing_shape() -> Dictionary:
	if weapon == "wand":
		return {"kind": "rect", "range": Balance.WAND_LEN, "arc": 0.0, "len": Balance.WAND_LEN, "w": Balance.WAND_W}
	if weapon == "sword":
		return {"kind": "arc", "range": Balance.SWORD_RANGE, "arc": Balance.SWORD_ARC, "len": Balance.SWORD_RANGE, "w": 0.0}
	return {"kind": "arc", "range": Balance.FIST_RANGE, "arc": Balance.FIST_ARC, "len": Balance.FIST_RANGE, "w": 0.0}


func _follow_clones(dt: float) -> void:
	for c in clones:
		if not c.alive:
			continue
		c.t = float(c.t) - dt
		if float(c.t) <= 0.0 or float(c.hp) <= 0.0:
			c.alive = false
			if c.node:
				c.node.visible = false
			sim.burst(c.pos, Color(0.73, 0.96, 1), 8, 2.4)
			continue
		var ang := facing + float(c.side)
		c.pos = global_position + Vector2(cos(ang), sin(ang)) * 0.5
		c.facing = facing
		if c.node:
			c.node.global_position = c.pos
			var rig: Node = c.node.get_node_or_null("Fighter")
			if rig:
				rig.set("facing", facing)
				rig.set("move_blend", move_blend)
				rig.set("swing", swing_vis)
				rig.set("attack_wind", attack_wind)
				rig.set("gender", gender)
				rig.set("team", team)
				rig.set("ghost", true)
				rig.set("weapon_kind", weapon)
				rig.set("dead", false)
				rig.set("carrying", carrying != null)


func _stick_wish() -> Vector2:
	if sim == null or sim.hud == null or not sim.hud.has_method("stick_wish"):
		return Vector2.ZERO
	var value: Vector2 = sim.hud.call("stick_wish")
	return value


func _sync_visual() -> void:
	if fighter and fighter.has_method("sync_from"):
		fighter.sync_from(self)
		var fade := 0.45 if invuln > 0.0 and fmod(sim.time * 12.0, 1.0) < 0.35 else 1.0
		if fade != _fade:
			_fade = fade
			fighter.modulate.a = fade
	if body_col.disabled != dead:
		body_col.disabled = dead
	var key := int(hp)
	key = key * 2 + (1 if swing_vis > 0.0 else 0)
	key = key * 2 + (1 if guard and carrying != null else 0)
	key = key * 2 + (1 if dead else 0)
	key = key * 2 + (1 if cast != null else 0)
	key = key * 4 + (1 if swing_kind == "rect" else 2 if swing_kind == "arc" else 0)
	if key == _draw_key:
		return
	_draw_key = key
	queue_redraw()


func _draw() -> void:
	var ring := Color(0.95, 0.28, 0.42) if team == 0 else Color(0.3, 0.72, 1.0)
	if guard and carrying != null:
		ring = Color(0.7, 0.95, 1.0)
		draw_arc(Vector2.ZERO, radius + 0.12, 0.0, TAU, 24, ring, 0.07, true)
	if not dead:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, ring, 0.055, true)
	if swing_vis > 0.0 and swing_kind == "rect":
		_draw_swing_rect()
	elif swing_vis > 0.0 and swing_kind == "arc":
		var arc_col := Color(1.0, 0.45, 0.1, 0.95) if weapon == "sword" else Color(1.0, 0.92, 0.55, 0.95)
		draw_arc(Vector2.ZERO, swing_range + radius + 0.08, facing - swing_arc * 0.5, facing + swing_arc * 0.5, 18, arc_col, 0.16, true)
		draw_arc(Vector2.ZERO, swing_range + radius, facing - swing_arc * 0.5, facing + swing_arc * 0.5, 14, Color(1, 1, 1, 0.9), 0.05, true)
	elif cast != null:
		draw_arc(Vector2.ZERO, radius + 0.28, 0.0, TAU, 24, Color(1.0, 0.62, 0.2, 0.9), 0.08, true)
	if not dead and _font != null:
		var w := 0.9
		var ratio := clampf(hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(-w * 0.5, -1.78, w, 0.08), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(-w * 0.5, -1.78, w * ratio, 0.08), Color(0.35, 0.85, 0.4) if ratio > 0.35 else Color(0.9, 0.3, 0.25))
		draw_set_transform(Vector2(0, -1.98), 0.0, Vector2(0.02, 0.02))
		var width := _font.get_string_size(unit_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(_font, Vector2(-width * 0.5, 0), unit_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_swing_rect() -> void:
	var fwd := Vector2(cos(facing), sin(facing))
	var side := Vector2(-fwd.y, fwd.x)
	var hw := swing_width * 0.5
	var near := fwd * 0.05
	var far := fwd * swing_len
	var poly := PackedVector2Array([
		near + side * hw,
		far + side * hw,
		far - side * hw,
		near - side * hw,
	])
	draw_colored_polygon(poly, Color(0.55, 0.82, 1.0, 0.38))
	var edge := PackedVector2Array([
		near + side * hw,
		far + side * hw,
		far - side * hw,
		near - side * hw,
		near + side * hw,
	])
	draw_polyline(edge, Color(0.85, 0.95, 1.0, 0.9), 0.06, true)

