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
	_check("wand rect", absf(Balance.WAND_LEN - 3.0) < 0.001 and absf(Balance.WAND_W - 2.0) < 0.001)
	_check("sword kit", Balance.WEAPON_KITS["sword"] == ["ignite", "spark", "ember"])
	_check("wand kit", Balance.WEAPON_KITS["wand"] == ["fireball", "ice", "mega"])
	_check("cdr", absf(Balance.cd_mul({"cdr": 10}) - 0.95) < 0.001)
	_check("max hp", absf(Balance.max_hp({"hp": 10}) - 125.0) < 0.001)
	_check("sword range", absf(Balance.SWORD_RANGE - 0.5) < 0.001)
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
	_check("wild nodes", match_node.nodes.size() == 20)
	_check("dash 4m", absf(Balance.DASH_DIST - 4.0) < 0.001)
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
	var holt = null
	for u in match_node.units:
		if str(u.unit_id) == "holt":
			holt = u
			break
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
	holt.global_position = player.global_position + Vector2(2.0, 1.7)
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
	_check("supply nodes", supply.get("nodes", []).size() == 20)
	player.equip_weapon("none", false)
	player.cds["fireball"] = 0.0
	player.global_position = player_pos
	player.force_update_transform()
	holt.global_position = holt_pos
	holt.hp = holt_hp
	holt.force_update_transform()


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
