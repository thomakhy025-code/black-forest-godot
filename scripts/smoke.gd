extends Node
## Headless check for the Versus Robots match. Quits 0 when the rules hold.

const Balance = preload("res://scripts/balance.gd")
const State = preload("res://scripts/state.gd")
const MatchScene = preload("res://scenes/match.tscn")

var match_node: Node
var failed: Array = []
var start_pos := {}
var done := false


func _ready() -> void:
	match_node = MatchScene.instantiate()
	add_child(match_node)
	match_node.start_match({
		"name": "You",
		"gender": "female",
		"stats": Balance.blank_stats(),
	}, false, false)
	_check("10 units", match_node.units.size() == 10)
	var crimson := 0
	var azure := 0
	for u in match_node.units:
		if u.team == 0:
			crimson += 1
		else:
			azure += 1
		if not u.is_player:
			start_pos[u.unit_id] = u.global_position
	_check("5v5", crimson == 5 and azure == 5)
	_check("4 keeps", match_node.keeps.size() == 4)
	for k in match_node.keeps:
		_check("keep radius 1", absf(float(k["r"]) - 1.0) < 0.01)
	_check("2 bridges", match_node.bridges.size() == 2)
	_check("2 islands", match_node.isles.size() == 2)
	_check("3 water polys", match_node.water_polys.size() == 3)
	var doors := 0
	for w in match_node.walls:
		if w["kind"] == "door":
			doors += 1
	_check("4 doors", doors == 4)
	_check("throw 1m", absf(Balance.THROW_METERS - 1.0) < 0.001)
	_check("fireball cd", absf(float(Balance.SKILLS["fireball"]["cd"]) - 8.0) < 0.001)
	_check("mega mp", absf(float(Balance.SKILLS["mega"]["mp_flat"]) - 70.0) < 0.001)
	_check("sword damage", absf(Balance.SWORD_DAMAGE - 15.0) < 0.001)
	_check("wand damage", absf(Balance.WAND_DAMAGE - 10.0) < 0.001)
	_check("attack interval", absf(Balance.ATTACK_INTERVAL - 1.0) < 0.001)
	_check("wand rect", absf(Balance.WAND_LEN - 6.0) < 0.001 and absf(Balance.WAND_W - 4.0) < 0.001)
	_check("sword kit", Balance.WEAPON_KITS["sword"] == ["ignite", "spark", "ember"])
	_check("wand kit", Balance.WEAPON_KITS["wand"] == ["fireball", "ice", "mega"])
	_check("cdr", absf(Balance.cd_mul({"cdr": 10}) - 0.95) < 0.001)
	_check("max hp", absf(Balance.max_hp({"hp": 10}) - 125.0) < 0.001)
	_check("sword range", absf(Balance.SWORD_RANGE - 1.0) < 0.001)
	_check("4 forges", match_node.forges.size() == 4)
	var open_doors := 0
	for w in match_node.walls:
		if w["kind"] == "door" and float(w["hp"]) <= 0.0 and bool(w["shape"].disabled):
			open_doors += 1
	_check("doors start open", open_doors == 4)
	var animals := 0
	for n in match_node.nodes:
		if str(n.get("kind", "")) == "animal":
			animals += 1
	_check("6 animals", animals == 6)
	var node_count: int = match_node.nodes.size()
	_check("wild nodes %d" % node_count, node_count == 33)
	var castle_trees := 0
	var west_yard := Rect2(4.2, 14.0, 17.0, 23.5)
	var east_yard := Rect2(66.8, 14.0, 17.2, 23.5)
	for node in match_node.nodes:
		if str(node.get("kind", "")) != "tree":
			continue
		var tree_at: Vector2 = node["pos"]
		if west_yard.has_point(tree_at) or east_yard.has_point(tree_at):
			castle_trees += 1
	_check("no castle trees", castle_trees == 0)
	var nia = null
	for unit in match_node.units:
		if str(unit.unit_id) == "nia":
			nia = unit
	_check("bot leaves the yard", nia != null and match_node.steer_point(nia, Vector2(18, 8)).x > 21.0)
	var joss = null
	for unit in match_node.units:
		if str(unit.unit_id) == "joss":
			joss = unit
	var job_a: Dictionary = match_node.bot_goal(joss)
	var job_b: Dictionary = match_node.bot_goal(joss)
	var job_pos: Vector2 = job_a.get("pos", Vector2.ZERO)
	var job_kind := str(job_a.get("kind", ""))
	_check("gather before the diamond", job_kind == "node" or job_kind == "pile" or job_kind == "forge")
	_check("job stays put", job_pos.distance_to(job_b.get("pos", Vector2.ZERO)) < 0.25)
	var nia_job: Dictionary = match_node.bot_goal(nia)
	if job_kind == "node" and str(nia_job.get("kind", "")) == "node":
		_check("separate trees", nia_job.get("ref") != job_a.get("ref"))
	var holt = null
	for unit in match_node.units:
		if str(unit.unit_id) == "holt":
			holt = unit
	var holt_at: Vector2 = holt.global_position
	holt.global_position = joss.global_position + Vector2(1.5, 0)
	holt.force_update_transform()
	var job_c: Dictionary = match_node.bot_goal(joss)
	_check("gather through a nearby enemy", job_pos.distance_to(job_c.get("pos", Vector2.ZERO)) < 0.25)
	holt.global_position = holt_at
	holt.force_update_transform()
	var sword_pad = null
	for forge in match_node.forges:
		if int(forge.get("team", -1)) == 0 and str(forge.get("weapon", "")) == "sword":
			sword_pad = forge
	joss.wood = 0
	joss.hide = 0
	joss.fiber = 0
	joss.bot_lock = {"pos": sword_pad["pos"], "unit": null, "kind": "forge", "ref": sword_pad}
	var left_forge: Dictionary = match_node.bot_goal(joss)
	_check("leaves the forge", str(left_forge.get("kind", "")) != "forge")
	var outside: Vector2 = nia.global_position
	nia.global_position = Vector2(12, 12)
	nia.force_update_transform()
	nia.bot_corner = ""
	var around: Vector2 = match_node.steer_point(nia, Vector2(7.5, 17.2))
	var around_again: Vector2 = match_node.steer_point(nia, Vector2(7.5, 17.2))
	_check("around the wall", around.y < 13.2 or around.x > 21.0)
	_check("route stays", around.distance_to(around_again) < 0.2)
	nia.global_position = outside
	nia.bot_corner = ""
	match_node.drop_route(nia)
	nia.force_update_transform()
	for forge in match_node.forges:
		if int(forge.get("team", -1)) == 0:
			forge["built"] = true
	for w in match_node.walls:
		if str(w.get("kind", "")) == "door" and int(w.get("team", -1)) == 0:
			w["hp"] = float(w.get("max", 70.0))
	joss.equip_weapon("sword", false)
	joss.bot_lock = null
	var raid: Dictionary = match_node.bot_goal(joss)
	var raid_at: Vector2 = raid.get("pos", Vector2.ZERO)
	_check("steals the diamond", raid_at.x > 60.0)
	joss.equip_weapon("none", false)
	joss.bot_lock = null
	for forge2 in match_node.forges:
		if int(forge2.get("team", -1)) == 0:
			forge2["built"] = false
	for w2 in match_node.walls:
		if str(w2.get("kind", "")) == "door" and int(w2.get("team", -1)) == 0:
			w2["hp"] = 0.0
	if job_kind == "node":
		var stand: Vector2 = match_node.stand_point(joss, job_pos)
		_check("stands off the trunk", stand.distance_to(job_pos) > 0.45)
	var quinn = null
	for unit3 in match_node.units:
		if str(unit3.unit_id) == "quinn":
			quinn = unit3
	if holt != null and quinn != null:
		var holt_lane: Vector2 = match_node._door_lane(holt, Vector2(65.2, 25.5))
		var quinn_lane: Vector2 = match_node._door_lane(quinn, Vector2(65.2, 25.5))
		_check("door lanes differ", holt_lane.distance_to(quinn_lane) > 0.9)
		var quinn_at: Vector2 = quinn.global_position
		var holt_saved: Vector2 = holt.global_position
		quinn.global_position = Vector2(71.5, 17.2)
		holt.global_position = Vector2(70.6, 17.2)
		quinn.force_update_transform()
		holt.force_update_transform()
		var beside: Vector2 = match_node.crowd_slot(holt, Vector2(71.5, 17.2))
		_check("stands beside a teammate", beside.distance_to(Vector2(71.5, 17.2)) > 0.8)
		quinn.global_position = quinn_at
		holt.global_position = holt_saved
		quinn.force_update_transform()
		holt.force_update_transform()
	var saved: Vector2 = nia.global_position
	nia.global_position = Vector2(10, 15.1)
	nia.force_update_transform()
	nia.wish = Vector2(0, -1)
	nia.bot_slide = 1.0
	nia.bot_slide_wait = 0.0
	var x0: float = nia.global_position.x
	for _slide in 12:
		nia.predict_move(0.05)
	_check("bot slides along the wall", absf(nia.global_position.x - x0) > 0.2 and nia.global_position.y > 14.6)
	nia.global_position = saved
	nia.wish = Vector2.ZERO
	nia.force_update_transform()
	_check_sword_skills()
	_check("river water", match_node.in_water(Vector2(25, 25.5)))
	_check("pond water", match_node.in_water(Vector2(44, 18)))
	_check("castle dry", not match_node.in_water(Vector2(12, 25)))
	var bridge: Rect2 = match_node.bridges[0]
	_check("bridge dry", not match_node.in_water(bridge.position + bridge.size * 0.5))
	var player = match_node.player
	_check("player unarmed", player.weapon == "none" and not bool(player.skills.get("fireball", false)))
	for u in match_node.units:
		if str(u.unit_id) == "bram":
			_check("bram unarmed", u.weapon == "none" and not bool(u.skills.get("fireball", false)))
		elif str(u.unit_id) == "quinn":
			_check("quinn unarmed", u.weapon == "none" and not bool(u.skills.get("ignite", false)))
	var base: float = player.move_speed()
	player.carrying = State.new()
	var half: float = player.move_speed()
	player.carrying = null
	_check("carry half speed", absf(half - base * Balance.CARRY_SPEED) < 0.02)
	player.carrying = State.new()
	player.guard = true
	_check("guard halves", absf(match_node.mitigated(player, 10.0) - 5.0) < 0.01)
	player.guard = false
	player.carrying = null
	player.clear_guard()
	player.wood = 3
	player.hide = 3
	player.fiber = 3
	var loaded: float = player.move_speed()
	_check("full bag moves", absf(loaded - base * Balance.BAG_FLOOR) < 0.05)
	player.wood = 0
	player.hide = 0
	player.fiber = 0
	var player_pos: Vector2 = player.global_position
	var holt_pos: Vector2 = holt.global_position
	var holt_hp: float = holt.hp
	player.global_position = Vector2(30, 20)
	player.facing = 0.0
	player.equip_weapon("none", false)
	holt.global_position = player.global_position + Vector2(0.55, 0.0)
	var fist_before: float = holt.hp
	match_node.resolve_swing(player)
	_check("fist hit 5", holt.hp < fist_before - 4.5 and holt.hp > fist_before - 5.5)
	holt.hp = holt.max_hp
	player.wood = 2
	player.equip_weapon("sword", false)
	_check("bag still casts", player.try_cast("ignite"))
	player.cast = null
	player.wood = 0
	player.equip_weapon("sword", false)
	holt.global_position = player.global_position + Vector2(0.7, 0.0)
	match_node.resolve_swing(player)
	_check("sword hit 15", holt.hp < holt_hp - 14.0)
	holt.hp = holt.max_hp
	player.equip_weapon("wand", false)
	holt.global_position = player.global_position + Vector2(2.0, 0.0)
	var wand_before: float = holt.hp
	match_node.resolve_swing(player)
	_check("wand hit 10", holt.hp < wand_before - 9.0)
	holt.hp = holt.max_hp
	holt.global_position = player.global_position + Vector2(2.0, 2.3)
	var miss_before: float = holt.hp
	match_node.resolve_swing(player)
	_check("wand misses wide", absf(holt.hp - miss_before) < 0.01)
	player.cds["fireball"] = 4.0
	player.equip_weapon("sword", false)
	player.equip_weapon("wand", false)
	_check("swap keeps cooldown", absf(float(player.cds["fireball"]) - 4.0) < 0.01)
	_check("wand skills after swap", bool(player.skills.get("fireball", false)) and bool(player.skills.get("ice", false)) and bool(player.skills.get("mega", false)) and not bool(player.skills.get("ignite", false)))
	var enemy_forge := {}
	for forge in match_node.forges:
		if int(forge["team"]) == 1 and str(forge["weapon"]) == "sword":
			enemy_forge = forge
	enemy_forge["built"] = true
	player.wood = 2
	player.hide = 1
	player.fiber = 3
	player.equip_weapon("none", false)
	player.global_position = enemy_forge["pos"]
	match_node.interact(player)
	_check("stole enemy sword", player.weapon == "sword" and bool(player.skills.get("spark", false)))
	_check("enemy pad keeps the bag", player.wood == 2 and player.hide == 1 and player.fiber == 3)
	_check("enemy stock stays empty", int(enemy_forge["wood"]) == 0 and int(enemy_forge["hide"]) == 0 and int(enemy_forge["fiber"]) == 0)
	match_node.interact(player)
	_check("forge again", player.weapon == "sword")
	enemy_forge["built"] = false
	player.equip_weapon("none", false)
	match_node.interact(player)
	_check("unbuilt enemy stays shut", player.weapon == "none" and player.wood == 2 and int(enemy_forge["wood"]) == 0)
	player.wood = 0
	player.hide = 0
	player.fiber = 0
	var grove = null
	for n in match_node.nodes:
		if str(n.get("kind", "")) == "tree":
			grove = n
			break
	player.global_position = grove["pos"] + Vector2(-0.8, 0.0)
	player.facing = 0.0
	for _chop in 3:
		match_node.resolve_swing(player)
	_check("tree drops wood", player.wood == 1 and float(grove["hp"]) <= 0.0)
	match_node.drop_bag(player)
	_check("drop bag", player.wood == 0 and match_node.piles.size() == 1)
	player.equip_weapon("sword", false)
	var fell_at: Vector2 = player.global_position
	match_node.kill_unit(player, holt)
	_check("death drops weapon", player.weapon == "none" and match_node.weapon_drops.size() == 1)
	match_node.respawn_unit(player)
	_check("respawn bare", not player.dead and player.weapon == "none")
	player.global_position = fell_at
	match_node.interact(player)
	_check("pickup dropped sword", player.weapon == "sword" and match_node.weapon_drops.is_empty())
	player.equip_weapon("none", false)
	var raw: PackedByteArray = match_node.pack_net_bytes({})
	var blob: Dictionary = match_node._decode_net_bytes(raw)
	var supply: Dictionary = blob.get("supply", {})
	_check("supply forges", supply.get("forges", []).size() == 4)
	_check("supply nodes", supply.get("nodes", []).size() == match_node.nodes.size())
	player.equip_weapon("none", false)
	player.cds["fireball"] = 0.0
	player.global_position = player_pos
	player.force_update_transform()
	holt.global_position = holt_pos
	holt.hp = holt_hp
	holt.force_update_transform()
	for forge3 in match_node.forges:
		if int(forge3.get("team", -1)) == 0:
			forge3["built"] = false
	_check("one job, gather", match_node.bot_order(nia) == "supply")
	for forge4 in match_node.forges:
		if int(forge4.get("team", -1)) == 0:
			forge4["built"] = true
	_check("one job, build the gate", match_node.bot_order(nia) == "door")
	for w3 in match_node.walls:
		if str(w3.get("kind", "")) == "door" and int(w3.get("team", -1)) == 0:
			w3["hp"] = float(w3["max"])
			w3["shape"].disabled = false
	_check("one job, take a weapon", match_node.bot_order(nia) == "arm")
	var through_own: bool = match_node._segment_clear(Vector2(23.2, 25.5), Vector2(14.0, 25.5), 0.48, 0)
	var through_enemy: bool = match_node._segment_clear(Vector2(23.2, 25.5), Vector2(14.0, 25.5), 0.48, 1)
	_check("own closed gate can be crossed", through_own)
	_check("enemy closed gate stays shut", not through_enemy)
	var nia_at: Vector2 = nia.global_position
	nia.global_position = Vector2(23.5, 25.5)
	nia.force_update_transform()
	nia.bot_lock = null
	nia.bot_corner = ""
	nia.wish = Vector2.ZERO
	match_node.drop_route(nia)
	for _gate in 70:
		nia.tick_bot(1.0 / 30.0)
		nia.predict_move(1.0 / 30.0)
	_check("leaves the finished gate", nia.global_position.x < 21.0)
	nia.global_position = nia_at
	nia.bot_lock = null
	nia.bot_corner = ""
	nia.wish = Vector2.ZERO
	match_node.drop_route(nia)
	nia.force_update_transform()
	for w4 in match_node.walls:
		if str(w4.get("kind", "")) == "door" and int(w4.get("team", -1)) == 0:
			w4["hp"] = 0.0
			w4["shape"].disabled = true
	for forge5 in match_node.forges:
		if int(forge5.get("team", -1)) == 0:
			forge5["built"] = false


func _check_sword_skills() -> void:
	_check("lightning dash 8m", absf(Balance.DASH_DIST - 8.0) < 0.001 and absf(Balance.DASH_TIME - 0.25) < 0.001)
	_check("saber 15 by 4", absf(Balance.SABER_LEN - 15.0) < 0.001 and absf(Balance.SABER_W - 4.0) < 0.001)
	_check("saber 75 in 3s", absf(Balance.SABER_DAMAGE - 75.0) < 0.001 and absf(Balance.SABER_TIME - 3.0) < 0.001)
	var sword: Dictionary = Balance.SKILLS["ignite"]
	var bolt: Dictionary = Balance.SKILLS["spark"]
	var beam: Dictionary = Balance.SKILLS["ember"]
	_check("fire sword cost", absf(float(sword["cast"]) - 0.1) < 0.001 and absf(float(sword["cd"]) - 15.0) < 0.001 and absf(float(sword["mp"]) - 0.3) < 0.001)
	_check("lightning cost", absf(float(bolt["cast"]) - 0.5) < 0.001 and absf(float(bolt["cd"]) - 5.0) < 0.001 and absf(float(bolt["mp"]) - 0.1) < 0.001)
	_check("saber cost", absf(float(beam["cd"]) - 24.0) < 0.001 and absf(float(beam["mp_flat"]) - 50.0) < 0.001)
	var player = match_node.player
	var foe = null
	var mate = null
	var rows: Array = []
	for u in match_node.units:
		rows.append({
			"u": u,
			"pos": u.global_position,
			"hp": u.hp,
			"inv": u.invuln,
			"shock": u.shock,
			"burn": u.burn,
			"facing": u.facing,
			"dead": u.dead,
			"mp": u.mp,
		})
		if u == player or u.dead:
			continue
		if int(u.team) != int(player.team) and foe == null:
			foe = u
		elif int(u.team) == int(player.team) and mate == null:
			mate = u
	var mp0: float = player.mp
	player.equip_weapon("sword")
	player.mp = player.max_mp
	player.global_position = Vector2(44, 25)
	player.facing = 0.0
	player.wish = Vector2.ZERO
	player.invuln = 0.0
	player.force_update_transform()
	if foe != null and mate != null:
		foe.global_position = Vector2(45.7, 25)
		foe.hp = 100.0
		foe.invuln = 0.0
		foe.shock = 0.0
		foe.burn = null
		foe.force_update_transform()
		match_node.resolve_swing(player)
		_check("plain sword misses past 1m", absf(foe.hp - 100.0) < 0.05)
		player.cds["ignite"] = 0.0
		var fired: bool = player.try_cast("ignite")
		var free_cast := false
		var cast_t := 0.0
		if player.cast != null:
			free_cast = not player.cast.root and not player.cast.slow
			cast_t = float(player.cast.dur)
			player.cast.t = 0.0
			match_node.finish_cast(player)
		_check("fire sword casts", fired and free_cast and absf(cast_t - 0.1) < 0.02)
		_check("fire sword buff", player.fire_sword_hits == 5 and player.fire_sword_t > 7.5)
		var shape: Dictionary = player.swing_shape()
		_check("fire sword reach", absf(float(shape["range"]) - 1.5) < 0.001 and absf(float(shape["arc"]) - PI) < 0.001)
		match_node.resolve_swing(player)
		_check("fire sword doubles", absf(foe.hp - 70.0) < 0.6)
		_check("fire sword burn", foe.burn != null and absf(float(foe.burn.dps) - 5.0) < 0.05 and absf(float(foe.burn.t) - 3.0) < 0.05)
		_check("fire sword charge spent", player.fire_sword_hits == 4)
		foe.global_position = Vector2(60, 25)
		foe.force_update_transform()
		match_node.resolve_swing(player)
		_check("fire sword whiff keeps charge", player.fire_sword_hits == 4)
		foe.global_position = Vector2(45.7, 25)
		foe.hp = 500.0
		foe.invuln = 0.0
		foe.force_update_transform()
		for _hit in 4:
			match_node.resolve_swing(player)
		_check("fire sword ends after 5 hits", player.fire_sword_hits == 0 and player.fire_sword_t <= 0.0)
		_check("fifth hit still empowered", absf(foe.hp - 380.0) < 1.0)
		player.mp = player.max_mp
		player.cds["spark"] = 0.0
		player.cast = null
		player.dash = null
		player.invuln = 0.0
		player.facing = 0.0
		foe.global_position = Vector2(47, 25)
		foe.hp = 100.0
		foe.shock = 0.0
		foe.invuln = 0.0
		foe.force_update_transform()
		var sparked: bool = player.try_cast("spark")
		var wind_ok := false
		if player.cast != null:
			wind_ok = not player.cast.root and not player.cast.slow and absf(float(player.cast.dur) - 0.5) < 0.02
			player.facing = 0.0
			player.cast.t = 0.0
			match_node.finish_cast(player)
		var dashed: bool = player.dash != null
		var dash_dist := 0.0
		var dash_dur := 0.0
		if dashed:
			dash_dist = float(player.dash.dist)
			dash_dur = float(player.dash.dur)
			player.dash.from_pos = Vector2(46.2, 25)
			player.global_position = Vector2(47.8, 25)
			player.force_update_transform()
			player.dash.hit = {}
			var hp_before: float = foe.hp
			match_node.strike_dash(player)
			_check("lightning hits 10", absf(foe.hp - (hp_before - 10.0)) < 0.6)
			_check("lightning no shock", foe.shock <= 0.01)
		else:
			_check("lightning hits 10", false)
			_check("lightning no shock", false)
		_check("lightning windup", sparked and wind_ok)
		_check("lightning dash", dashed and absf(dash_dist - 8.0) < 0.001 and absf(dash_dur - 0.25) < 0.001 and player.invuln >= 0.24 and player.invuln <= 0.26)
		player.dash = null
		player.cast = null
		player.channel = null
		player.global_position = Vector2(44, 25)
		player.facing = 0.0
		player.mp = 100.0
		player.cds["ember"] = 0.0
		player.force_update_transform()
		foe.global_position = Vector2(52, 25)
		foe.hp = 100.0
		foe.invuln = 0.0
		foe.burn = null
		foe.force_update_transform()
		mate.global_position = Vector2(50, 26)
		mate.hp = 100.0
		mate.invuln = 0.0
		mate.force_update_transform()
		_check("saber holds for a teammate", not match_node.saber_worth(player))
		mate.global_position = Vector2(44, 40)
		mate.force_update_transform()
		_check("saber fires on a clear lane", match_node.saber_worth(player))
		mate.global_position = Vector2(50, 26)
		mate.force_update_transform()
		var beamed: bool = player.try_cast("ember")
		var ch_ok: bool = player.channel != null and str(player.channel.kind) == "saber"
		var ch_t := 0.0
		var ch_len := 0.0
		var ch_w := 0.0
		if ch_ok:
			ch_t = float(player.channel.t)
			ch_len = float(player.channel.len)
			ch_w = float(player.channel.w)
			player.channel.t = 0.0
			match_node.finish_channel(player)
		_check("saber channels", beamed and ch_ok and absf(ch_t - 3.0) < 0.05 and absf(ch_len - 15.0) < 0.001 and absf(ch_w - 4.0) < 0.001)
		_check("saber spent 50", absf(player.mp - 50.0) < 0.5)
		_check("saber hits enemy", absf(foe.hp - 25.0) < 1.0)
		_check("saber hits teammate", absf(mate.hp - 25.0) < 1.0)
		_check("saber spares caster", player.hp > 90.0)
	else:
		_check("sword skill targets", false)
	for row in rows:
		var u2 = row["u"]
		u2.global_position = row["pos"]
		u2.hp = row["hp"]
		u2.invuln = row["inv"]
		u2.shock = row["shock"]
		u2.burn = row["burn"]
		u2.facing = row["facing"]
		u2.dead = row["dead"]
		u2.mp = row["mp"]
		if u2.body_col:
			u2.body_col.disabled = bool(u2.dead)
		u2.force_update_transform()
	player.cast = null
	player.dash = null
	player.channel = null
	player.wish = Vector2.ZERO
	player.fire_sword_t = 0.0
	player.fire_sword_hits = 0
	player.equip_weapon("none")
	player.mp = mp0
	player.cds["ignite"] = 0.0
	player.cds["spark"] = 0.0
	player.cds["ember"] = 0.0


func _physics_process(_dt: float) -> void:
	if done or match_node == null or match_node.phase != "play":
		return
	if match_node.shots.is_empty() and match_node.time < 0.05:
		var player = match_node.player
		player.global_position = Vector2(30, 20)
		player.facing = 0.0
		var gem = match_node.diamonds[1]
		gem.carrier = null
		gem.at_home = false
		player.carrying = gem
		match_node.throw_diamond(player)
		if match_node.shots.is_empty():
			_check("throw shot", false)
		else:
			var shot = match_node.shots[match_node.shots.size() - 1]
			var dist: float = shot.dest.distance_to(Vector2(30, 20))
			_check("throw lands 1m", absf(dist - 1.0) < 0.05)
	if match_node.time < 2.4:
		return
	done = true
	var moved := false
	for u in match_node.units:
		if u.is_player or not start_pos.has(u.unit_id):
			continue
		if u.global_position.distance_to(start_pos[u.unit_id]) > 0.2:
			moved = true
	_check("a bot moved", moved)
	var victim = null
	for u in match_node.units:
		if u.team == 1 and not u.dead:
			victim = u
			break
	match_node.kill_unit(victim, match_node.player)
	var text := ""
	if match_node.kill_call != null:
		text = str(match_node.kill_call["text"])
	_check("kill banner", text.find(" kill ") >= 0)
	if failed.is_empty():
		print("SMOKE OK")
		get_tree().quit(0)
	else:
		for item in failed:
			print("SMOKE FAIL: ", item)
		get_tree().quit(1)


func _check(label: String, ok: bool) -> void:
	if not ok:
		failed.append(label)
		print("FAIL ", label)
