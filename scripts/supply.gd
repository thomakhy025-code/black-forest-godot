extends RefCounted
## Wood, hide, and fiber. The host harvests, builds, and drops. Guests only draw
## the snapshot.

const Balance = preload("res://scripts/balance.gd")
const State = preload("res://scripts/state.gd")

const _KEYS: Array = ["wood", "hide", "fiber"]


static func recipe(kind: String) -> Dictionary:
	if kind == "wand":
		return {"wood": 1, "hide": 2, "fiber": 3}
	return {"wood": 4, "hide": 2, "fiber": 0}


static func tick(match_node, dt: float) -> void:
	for n in match_node.nodes:
		if float(n.get("down", 0.0)) > 0.0:
			n["down"] = float(n["down"]) - dt
			if float(n["down"]) <= 0.0:
				n["down"] = 0.0
				n["hp"] = float(n.get("max", 1.0))
				n["pos"] = n.get("home", n.get("pos", Vector2.ZERO))
				_show(n, true)
			continue
		if str(n.get("kind", "")) != "animal":
			continue
		var phase := float(n.get("phase", 0.0)) + dt * 0.7
		n["phase"] = phase
		var home: Vector2 = n.get("home", Vector2.ZERO)
		var pos := home + Vector2(cos(phase), sin(phase * 0.8)) * 1.45
		n["pos"] = pos
		var vis = n.get("visual")
		if vis != null and is_instance_valid(vis):
			vis.position = pos
	var drops: Array = []
	for drop in match_node.weapon_drops:
		drop["t"] = float(drop.get("t", 0.0)) - dt
		if float(drop["t"]) > 0.0:
			drops.append(drop)
		else:
			_free_vis(drop)
	match_node.weapon_drops = drops


static func chop(match_node, u) -> void:
	var shape: Dictionary = u.swing_shape()
	var dmg: float = match_node.weapon_damage(u)
	for n in match_node.nodes:
		if float(n.get("hp", 0.0)) <= 0.0 or float(n.get("down", 0.0)) > 0.0:
			continue
		var pos: Vector2 = n["pos"]
		if not match_node._in_shape(u.global_position, u.facing, pos, float(n.get("r", 0.4)), shape):
			continue
		n["hp"] = float(n["hp"]) - dmg
		if float(n["hp"]) > 0.0:
			continue
		n["hp"] = 0.0
		n["down"] = float(n.get("regrow", 20.0))
		n["pos"] = n.get("home", pos)
		_show(n, false)
		var item := str(n.get("item", "wood"))
		if give(u, item):
			match_node.float_at(u.global_position + Vector2(0, -0.9), item.to_upper(), Color(0.8, 0.95, 0.55))
		else:
			spill(match_node, pos, _one(item))
			match_node.float_at(u.global_position + Vector2(0, -1.3), "BAG FULL", Color(1, 0.86, 0.35))


static func give(u, item: String) -> bool:
	if int(u.get(item)) >= Balance.BAG_CAP:
		return false
	u.set(item, int(u.get(item)) + 1)
	return true


static func drop_bag(match_node, u) -> void:
	if u == null or int(u.wood) + int(u.hide) + int(u.fiber) <= 0:
		return
	spill(match_node, u.global_position, {"wood": int(u.wood), "hide": int(u.hide), "fiber": int(u.fiber)})
	u.wood = 0
	u.hide = 0
	u.fiber = 0
	match_node.float_at(u.global_position + Vector2(0, -0.9), "DROP", Color(0.8, 0.95, 0.55))


static func on_death(match_node, u) -> void:
	drop_bag(match_node, u)
	var kind := str(u.weapon)
	if kind == "sword" or kind == "wand":
		while match_node.weapon_drops.size() >= 4:
			_free_vis(match_node.weapon_drops.pop_front())
		var tint := Color(1.0, 0.72, 0.28) if kind == "sword" else Color(0.55, 0.86, 1.0)
		match_node.weapon_drops.append({
			"pos": u.global_position,
			"kind": kind,
			"t": Balance.WEAPON_DROP_TIME,
			"visual": _marker(match_node, u.global_position, tint, 0.3),
		})
	u.equip_weapon("none", false)


static func on_respawn(u) -> void:
	u.wood = 0
	u.hide = 0
	u.fiber = 0
	u.equip_weapon("none", false)
	u.bot_lock = null
	u.bot_stuck = false
	u.bot_corner = ""
	u.bot_mark_t = 0.0


static func take_drop(match_node, u, drop) -> void:
	if str(u.weapon) != "none":
		return
	u.equip_weapon(str(drop.get("kind", "sword")), true)
	_free_vis(drop)
	match_node.weapon_drops.erase(drop)


static func take_pile(match_node, u, pile) -> void:
	var took := 0
	for key in _KEYS:
		var room := Balance.BAG_CAP - int(u.get(key))
		var have := int(pile.get(key, 0))
		var take := mini(maxi(room, 0), have)
		if take <= 0:
			continue
		u.set(key, int(u.get(key)) + take)
		pile[key] = have - take
		took += take
	var left := int(pile.get("wood", 0)) + int(pile.get("hide", 0)) + int(pile.get("fiber", 0))
	if left <= 0:
		_free_vis(pile)
		match_node.piles.erase(pile)
	if took > 0:
		match_node.float_at(u.global_position + Vector2(0, -0.9), "PICK UP", Color(0.8, 0.95, 0.55))
	else:
		match_node.float_at(u.global_position + Vector2(0, -0.9), "BAG FULL", Color.WHITE)


static func use_forge(match_node, u, forge) -> void:
	var kind := str(forge.get("weapon", "sword"))
	if bool(forge.get("built", false)):
		if str(u.weapon) == kind:
			match_node.float_at(u.global_position + Vector2(0, -0.9), "ALREADY WIELDING", Color.WHITE)
			return
		u.equip_weapon(kind, true)
		return
	if int(forge.get("team", -1)) != int(u.team):
		match_node.float_at(u.global_position + Vector2(0, -0.9), "NOT YOUR MACHINE", Color.WHITE)
		return
	var need := recipe(kind)
	var spent := _pour(u, forge, "wood", int(need["wood"]))
	spent += _pour(u, forge, "hide", int(need["hide"]))
	spent += _pour(u, forge, "fiber", int(need["fiber"]))
	if _met(forge, need):
		forge["built"] = true
		_mark_built(forge)
		if str(u.weapon) != kind:
			u.equip_weapon(kind, true)
		else:
			match_node.float_at(u.global_position + Vector2(0, -0.9), "BUILT", Color(1, 0.82, 0.45))
		return
	if spent > 0:
		match_node.float_at(u.global_position + Vector2(0, -0.9), "DEPOSIT", Color(0.8, 0.95, 0.55))
		return
	match_node.float_at(u.global_position + Vector2(0, -0.9), _need_text(forge, need), Color.WHITE)


static func use_door(match_node, u, door) -> void:
	if float(door.get("hp", 0.0)) <= 0.0:
		var spent := _pour(u, door, "wood", 3)
		spent += _pour(u, door, "fiber", 1)
		if int(door.get("wood", 0)) >= 3 and int(door.get("fiber", 0)) >= 1:
			door["hp"] = float(door.get("max", 70.0))
			door["shape"].disabled = false
			match_node._show_record(door, true)
			match_node.float_at(u.global_position + Vector2(0, -0.9), "DOOR", Color(1, 0.88, 0.54))
		elif spent > 0:
			match_node.float_at(u.global_position + Vector2(0, -0.9), "DEPOSIT", Color(0.8, 0.95, 0.55))
		else:
			match_node.float_at(u.global_position + Vector2(0, -0.9), "NEED 3 WOOD 1 FIBER", Color.WHITE)
		return
	if int(u.wood) < 1:
		match_node.float_at(u.global_position + Vector2(0, -0.9), "NEED WOOD", Color.WHITE)
		return
	var ch := State.new()
	ch.kind = "repair"
	ch.t = 1.1
	ch.src = door
	u.channel = ch
	match_node.float_at(u.global_position + Vector2(0, -0.9), "REPAIR", Color(1, 0.88, 0.54))


static func machines_ready(match_node, team: int) -> bool:
	var sword = _forge_for(match_node, team, "sword")
	var wand = _forge_for(match_node, team, "wand")
	if sword == null or wand == null:
		return false
	return bool(sword.get("built", false)) and bool(wand.get("built", false))


static func bot_goal(match_node, u) -> Dictionary:
	if u.dead or u.carrying != null:
		return {}
	if not machines_ready(match_node, int(u.team)):
		return _team_supply(match_node, u)
	if str(u.weapon) == "none":
		var drop = _nearest_drop(match_node, u.global_position, 18.0)
		if drop != null:
			return {"pos": drop["pos"], "unit": null, "kind": "drop", "ref": drop}
	var own = _forge_for(match_node, int(u.team), _wanted(u))
	var foe = _forge_for(match_node, 1 - int(u.team), _wanted(u))
	if str(u.weapon) == "none" and own != null:
		var own_d: float = u.global_position.distance_to(own["pos"])
		if foe != null and bool(foe.get("built", false)):
			var foe_d: float = u.global_position.distance_to(foe["pos"])
			if foe_d + 0.5 < own_d:
				return {"pos": foe["pos"], "unit": null, "kind": "forge", "ref": foe}
		if bool(own.get("built", false)):
			return {"pos": own["pos"], "unit": null, "kind": "forge", "ref": own}
		return _carry_job(match_node, u, own)
	return _door_job(match_node, u)


static func lock_ok(match_node, u, lock: Dictionary) -> bool:
	var kind := str(lock.get("kind", ""))
	var ref = lock.get("ref")
	if kind == "node":
		if ref == null or float(ref.get("hp", 0.0)) <= 0.0:
			return false
		if not _wants_item(match_node, u, str(ref.get("item", ""))):
			return false
		lock["pos"] = ref["pos"]
		return true
	if kind == "pile":
		if not match_node.piles.has(ref):
			return false
		if int(ref.get("wood", 0)) + int(ref.get("hide", 0)) + int(ref.get("fiber", 0)) <= 0:
			return false
		lock["pos"] = ref["pos"]
		return true
	if kind == "forge":
		if ref == null:
			return false
		if bool(ref.get("built", false)):
			if str(u.weapon) != "none" or not machines_ready(match_node, int(u.team)):
				return false
		elif not _holding_for(u, ref):
			return false
		lock["pos"] = ref["pos"]
		return true
	if kind == "door":
		if ref == null:
			return false
		var hp := float(ref.get("hp", 0.0))
		var mx := float(ref.get("max", 1.0))
		if hp >= mx and hp > 0.0:
			return false
		var rect: Rect2 = ref["rect"]
		lock["pos"] = rect.get_center()
		return true
	if kind == "drop":
		if not match_node.weapon_drops.has(ref):
			return false
		lock["pos"] = ref["pos"]
		return true
	return false


static func _holding_for(u, forge) -> bool:
	var need := _remaining(forge)
	for key in _KEYS:
		if int(need.get(key, 0)) > 0 and int(u.get(key)) > 0:
			return true
	return false


static func _team_supply(match_node, u) -> Dictionary:
	var forge = _open_machine(match_node, u)
	if forge == null:
		return {}
	return _carry_job(match_node, u, forge)


static func _open_machine(match_node, u):
	var first := "sword"
	var second := "wand"
	if _wanted(u) == "wand":
		first = "wand"
		second = "sword"
	var forge = _forge_for(match_node, int(u.team), first)
	if forge != null and not bool(forge.get("built", false)):
		return forge
	var other = _forge_for(match_node, int(u.team), second)
	if other != null and not bool(other.get("built", false)):
		return other
	return null


static func bot_act(match_node, u) -> void:
	if u.dead or u.carrying != null or u.channel != null or u.cast != null:
		return
	if machines_ready(match_node, int(u.team)) and match_node.nearest_enemy(u, 2.5) != null:
		return
	if u.attack_cd <= 0.0:
		var shape: Dictionary = u.swing_shape()
		var reach := float(shape.get("range", 0.7))
		for n in match_node.nodes:
			if float(n.get("hp", 0.0)) <= 0.0:
				continue
			var item := str(n.get("item", ""))
			if not _wants_item(match_node, u, item):
				continue
			var pos: Vector2 = n["pos"]
			if u.global_position.distance_to(pos) > reach + float(n.get("r", 0.4)) + 0.15:
				continue
			u.facing = (pos - u.global_position).angle()
			if match_node._in_shape(u.global_position, u.facing, pos, float(n.get("r", 0.4)), u.swing_shape()):
				u.try_swing()
				return
	if _useful(match_node, u):
		match_node.interact(u)


static func pack(match_node, buf: StreamPeerBuffer) -> void:
	for u in match_node.units:
		buf.put_u8(clampi(int(u.wood), 0, 9))
		buf.put_u8(clampi(int(u.hide), 0, 9))
		buf.put_u8(clampi(int(u.fiber), 0, 9))
	buf.put_u8(mini(match_node.forges.size(), 8))
	var forge_n := 0
	for forge in match_node.forges:
		if forge_n >= 8:
			break
		buf.put_u8(1 if bool(forge.get("built", false)) else 0)
		buf.put_u8(clampi(int(forge.get("wood", 0)), 0, 9))
		buf.put_u8(clampi(int(forge.get("hide", 0)), 0, 9))
		buf.put_u8(clampi(int(forge.get("fiber", 0)), 0, 9))
		forge_n += 1
	var doors: Array = []
	for w in match_node.walls:
		if str(w.get("kind", "")) == "door":
			doors.append(w)
	buf.put_u8(mini(doors.size(), 8))
	var door_n := 0
	for door in doors:
		if door_n >= 8:
			break
		buf.put_u8(clampi(int(door.get("wood", 0)), 0, 9))
		buf.put_u8(clampi(int(door.get("fiber", 0)), 0, 9))
		door_n += 1
	buf.put_u8(mini(match_node.nodes.size(), 48))
	var node_n := 0
	for n in match_node.nodes:
		if node_n >= 48:
			break
		var kind_i := _kind_id(str(n.get("kind", "tree")))
		buf.put_u8(kind_i)
		buf.put_u8(clampi(int(round(float(n.get("hp", 0.0)))), 0, 255))
		if kind_i == 2:
			var pos: Vector2 = n.get("pos", Vector2.ZERO)
			buf.put_float(pos.x)
			buf.put_float(pos.y)
		node_n += 1
	var pile_n := mini(match_node.piles.size(), 6)
	buf.put_u8(pile_n)
	var sent_p := 0
	for pile in match_node.piles:
		if sent_p >= pile_n:
			break
		var pp: Vector2 = pile.get("pos", Vector2.ZERO)
		buf.put_float(pp.x)
		buf.put_float(pp.y)
		buf.put_u8(clampi(int(pile.get("wood", 0)), 0, 255))
		buf.put_u8(clampi(int(pile.get("hide", 0)), 0, 255))
		buf.put_u8(clampi(int(pile.get("fiber", 0)), 0, 255))
		sent_p += 1
	var drop_n := mini(match_node.weapon_drops.size(), 4)
	buf.put_u8(drop_n)
	var sent_d := 0
	for drop in match_node.weapon_drops:
		if sent_d >= drop_n:
			break
		var dp: Vector2 = drop.get("pos", Vector2.ZERO)
		buf.put_float(dp.x)
		buf.put_float(dp.y)
		buf.put_u8(1 if str(drop.get("kind", "")) == "sword" else 2)
		buf.put_float(float(drop.get("t", 0.0)))
		sent_d += 1


static func read(buf: StreamPeerBuffer, unit_count: int) -> Dictionary:
	var bags: Array = []
	for _i in unit_count:
		bags.append([int(buf.get_u8()), int(buf.get_u8()), int(buf.get_u8())])
	var forges: Array = []
	for _f in buf.get_u8():
		forges.append([int(buf.get_u8()), int(buf.get_u8()), int(buf.get_u8()), int(buf.get_u8())])
	var doors: Array = []
	for _d in buf.get_u8():
		doors.append([int(buf.get_u8()), int(buf.get_u8())])
	var nodes: Array = []
	for _n in buf.get_u8():
		var kind_i := int(buf.get_u8())
		var hp := int(buf.get_u8())
		if kind_i == 2:
			nodes.append([kind_i, hp, buf.get_float(), buf.get_float()])
		else:
			nodes.append([kind_i, hp])
	var piles: Array = []
	for _p in buf.get_u8():
		piles.append([buf.get_float(), buf.get_float(), int(buf.get_u8()), int(buf.get_u8()), int(buf.get_u8())])
	var drops: Array = []
	for _w in buf.get_u8():
		var x := buf.get_float()
		var y := buf.get_float()
		var kind_b := int(buf.get_u8())
		drops.append([x, y, "sword" if kind_b == 1 else "wand", buf.get_float()])
	return {"bags": bags, "forges": forges, "doors": doors, "nodes": nodes, "piles": piles, "drops": drops}


static func apply(match_node, data: Dictionary) -> void:
	if data.is_empty():
		return
	var bags: Array = data.get("bags", [])
	for i in bags.size():
		if i >= match_node.units.size():
			break
		var row: Array = bags[i]
		var u = match_node.units[i]
		u.wood = int(row[0])
		u.hide = int(row[1])
		u.fiber = int(row[2])
	var forge_rows: Array = data.get("forges", [])
	for i in forge_rows.size():
		if i >= match_node.forges.size():
			break
		var forge = match_node.forges[i]
		var frow: Array = forge_rows[i]
		forge["built"] = int(frow[0]) != 0
		forge["wood"] = int(frow[1])
		forge["hide"] = int(frow[2])
		forge["fiber"] = int(frow[3])
		if bool(forge["built"]):
			_mark_built(forge)
	var door_i := 0
	var door_rows: Array = data.get("doors", [])
	for w in match_node.walls:
		if str(w.get("kind", "")) != "door":
			continue
		if door_i >= door_rows.size():
			break
		var drow: Array = door_rows[door_i]
		door_i += 1
		w["wood"] = int(drow[0])
		w["fiber"] = int(drow[1])
	var node_rows: Array = data.get("nodes", [])
	for i in node_rows.size():
		if i >= match_node.nodes.size():
			break
		var n = match_node.nodes[i]
		var nrow: Array = node_rows[i]
		n["hp"] = float(nrow[1])
		var alive := float(n["hp"]) > 0.0
		n["down"] = 0.0 if alive else 1.0
		if nrow.size() >= 4:
			n["pos"] = Vector2(float(nrow[2]), float(nrow[3]))
		_show(n, alive)
		var vis = n.get("visual")
		if alive and vis != null and is_instance_valid(vis):
			vis.position = n["pos"]
	_apply_piles(match_node, data.get("piles", []))
	_apply_drops(match_node, data.get("drops", []))


static func _apply_piles(match_node, rows: Array) -> void:
	while match_node.piles.size() > rows.size():
		_free_vis(match_node.piles.pop_back())
	for i in rows.size():
		var row: Array = rows[i]
		var pos := Vector2(float(row[0]), float(row[1]))
		if i < match_node.piles.size():
			var pile = match_node.piles[i]
			pile["pos"] = pos
			pile["wood"] = int(row[2])
			pile["hide"] = int(row[3])
			pile["fiber"] = int(row[4])
			var vis = pile.get("visual")
			if vis != null and is_instance_valid(vis):
				vis.position = pos
			else:
				pile["visual"] = _marker(match_node, pos, _pile_color(pile), 0.22)
		else:
			var made := {
				"pos": pos,
				"wood": int(row[2]),
				"hide": int(row[3]),
				"fiber": int(row[4]),
			}
			made["visual"] = _marker(match_node, pos, _pile_color(made), 0.22)
			match_node.piles.append(made)


static func _apply_drops(match_node, rows: Array) -> void:
	while match_node.weapon_drops.size() > rows.size():
		_free_vis(match_node.weapon_drops.pop_back())
	for i in rows.size():
		var row: Array = rows[i]
		var pos := Vector2(float(row[0]), float(row[1]))
		var kind := str(row[2])
		var tint := Color(1.0, 0.72, 0.28) if kind == "sword" else Color(0.55, 0.86, 1.0)
		if i < match_node.weapon_drops.size():
			var drop = match_node.weapon_drops[i]
			drop["pos"] = pos
			drop["kind"] = kind
			drop["t"] = float(row[3])
			var vis = drop.get("visual")
			if vis != null and is_instance_valid(vis):
				vis.position = pos
			else:
				drop["visual"] = _marker(match_node, pos, tint, 0.3)
		else:
			match_node.weapon_drops.append({
				"pos": pos,
				"kind": kind,
				"t": float(row[3]),
				"visual": _marker(match_node, pos, tint, 0.3),
			})


static func spill(match_node, pos: Vector2, goods: Dictionary) -> void:
	var wood := int(goods.get("wood", 0))
	var hide := int(goods.get("hide", 0))
	var fiber := int(goods.get("fiber", 0))
	if wood + hide + fiber <= 0:
		return
	for pile in match_node.piles:
		var at: Vector2 = pile.get("pos", Vector2.ZERO)
		if at.distance_to(pos) <= 1.2:
			pile["wood"] = int(pile.get("wood", 0)) + wood
			pile["hide"] = int(pile.get("hide", 0)) + hide
			pile["fiber"] = int(pile.get("fiber", 0)) + fiber
			return
	while match_node.piles.size() >= 6:
		_free_vis(match_node.piles.pop_front())
	var made := {"pos": pos, "wood": wood, "hide": hide, "fiber": fiber}
	made["visual"] = _marker(match_node, pos, _pile_color(made), 0.22)
	match_node.piles.append(made)


static func _one(item: String) -> Dictionary:
	return {"wood": 1 if item == "wood" else 0, "hide": 1 if item == "hide" else 0, "fiber": 1 if item == "fiber" else 0}


static func _pour(u, dest, key: String, want: int) -> int:
	var have := int(u.get(key))
	var room := want - int(dest.get(key, 0))
	var take := mini(have, maxi(room, 0))
	if take <= 0:
		return 0
	u.set(key, have - take)
	dest[key] = int(dest.get(key, 0)) + take
	return take


static func _met(dest, need: Dictionary) -> bool:
	for key in _KEYS:
		if int(dest.get(key, 0)) < int(need.get(key, 0)):
			return false
	return true


static func _need_text(dest, need: Dictionary) -> String:
	var bits := PackedStringArray()
	for key in _KEYS:
		var left := int(need.get(key, 0)) - int(dest.get(key, 0))
		if left > 0:
			bits.append("%d %s" % [left, key.to_upper()])
	if bits.is_empty():
		return "NEED MORE"
	return "NEED " + " ".join(bits)


static func _carry_job(match_node, u, forge) -> Dictionary:
	var need := _remaining(forge)
	var useful := false
	var missing: Array = []
	for key in _KEYS:
		if int(need[key]) <= 0:
			continue
		if int(u.get(key)) > 0:
			useful = true
		if int(need[key]) > int(u.get(key)):
			missing.append(key)
	if useful or missing.is_empty():
		return {"pos": forge["pos"], "unit": null, "kind": "forge", "ref": forge}
	return _fetch(match_node, u, missing, forge["pos"])


static func _door_job(match_node, u) -> Dictionary:
	var door = null
	var best := 100000.0
	var origin: Vector2 = u.global_position
	for w in match_node.walls:
		if str(w.get("kind", "")) != "door" or int(w.get("team", -1)) != int(u.team):
			continue
		var hp := float(w.get("hp", 0.0))
		var mx := float(w.get("max", 1.0))
		if hp >= mx and hp > 0.0:
			continue
		var center: Vector2 = (w["rect"] as Rect2).get_center()
		var dist := origin.distance_to(center)
		if dist < best:
			best = dist
			door = w
	if door == null:
		return {}
	var center2: Vector2 = (door["rect"] as Rect2).get_center()
	if float(door.get("hp", 0.0)) <= 0.0:
		var need_wood := int(door.get("wood", 0)) < 3
		var need_fiber := int(door.get("fiber", 0)) < 1
		if (need_wood and int(u.wood) > 0) or (need_fiber and int(u.fiber) > 0):
			return {"pos": center2, "unit": null, "kind": "door", "ref": door}
		var missing: Array = []
		if need_wood and int(u.wood) < 3:
			missing.append("wood")
		if need_fiber and int(u.fiber) < 1:
			missing.append("fiber")
		if missing.is_empty():
			return {"pos": center2, "unit": null, "kind": "door", "ref": door}
		var job := _fetch(match_node, u, missing, center2)
		if job.is_empty():
			return {}
		return job
	if int(u.wood) > 0:
		return {"pos": center2, "unit": null, "kind": "door", "ref": door}
	var tree = _nearest_node(match_node, origin, ["wood"], _taken_nodes(match_node, u))
	if tree == null:
		tree = _nearest_node(match_node, origin, ["wood"], [])
	if tree != null:
		return {"pos": tree["pos"], "unit": null, "kind": "node", "ref": tree}
	return {}


static func _fetch(match_node, u, missing: Array, fallback: Vector2) -> Dictionary:
	var origin: Vector2 = u.global_position
	var skip: Array = _taken_nodes(match_node, u)
	var pile = _nearest_pile(match_node, origin, missing, 18.0)
	var node = _nearest_node(match_node, origin, missing, skip)
	if node == null and not skip.is_empty():
		node = _nearest_node(match_node, origin, missing, [])
	if pile != null and (node == null or origin.distance_to(pile["pos"]) <= origin.distance_to(node["pos"])):
		return {"pos": pile["pos"], "unit": null, "kind": "pile", "ref": pile}
	if node != null:
		return {"pos": node["pos"], "unit": null, "kind": "node", "ref": node}
	if missing.is_empty():
		return {"pos": fallback, "unit": null, "kind": "move"}
	return {}


static func _taken_nodes(match_node, u) -> Array:
	var out: Array = []
	for other in match_node.units:
		if other == u or int(other.team) != int(u.team) or other.dead:
			continue
		var lock = other.bot_lock
		if lock is Dictionary and str(lock.get("kind", "")) == "node" and lock.get("ref") != null:
			out.append(lock.get("ref"))
	return out


static func _useful(match_node, u) -> bool:
	var origin: Vector2 = u.global_position
	if str(u.weapon) == "none":
		if _nearest_drop(match_node, origin, 1.45) != null:
			return true
	if _pile_useful(match_node, u, 1.45):
		return true
	for forge in match_node.forges:
		if origin.distance_to(forge["pos"]) > 1.75:
			continue
		if bool(forge.get("built", false)):
			if str(u.weapon) != str(forge.get("weapon", "")):
				return true
		elif int(forge.get("team", -1)) == int(u.team):
			var need := _remaining(forge)
			for key in _KEYS:
				if int(need[key]) > 0 and int(u.get(key)) > 0:
					return true
	for w in match_node.walls:
		if str(w.get("kind", "")) != "door" or int(w.get("team", -1)) != int(u.team):
			continue
		if float(match_node._rect_hit(origin, w["rect"])["d"]) > 1.6:
			continue
		var hp := float(w.get("hp", 0.0))
		var mx := float(w.get("max", 1.0))
		if hp >= mx:
			continue
		if hp <= 0.0:
			if (int(w.get("wood", 0)) < 3 and int(u.wood) > 0) or (int(w.get("fiber", 0)) < 1 and int(u.fiber) > 0):
				return true
		elif int(u.wood) > 0:
			return true
	return false


static func _pile_useful(match_node, u, reach: float) -> bool:
	for pile in match_node.piles:
		var pos: Vector2 = pile.get("pos", Vector2.ZERO)
		if u.global_position.distance_to(pos) > reach:
			continue
		for key in _KEYS:
			if int(pile.get(key, 0)) > 0 and _wants_item(match_node, u, key):
				return true
	return false


static func _wants_item(match_node, u, item: String) -> bool:
	if int(u.get(item)) >= Balance.BAG_CAP:
		return false
	for machine in ["sword", "wand"]:
		var forge = _forge_for(match_node, int(u.team), machine)
		if forge == null or bool(forge.get("built", false)):
			continue
		var need := _remaining(forge)
		if int(need.get(item, 0)) > int(u.get(item)):
			return true
	if not machines_ready(match_node, int(u.team)):
		return false
	for w in match_node.walls:
		if str(w.get("kind", "")) != "door" or int(w.get("team", -1)) != int(u.team):
			continue
		var hp := float(w.get("hp", 0.0))
		var mx := float(w.get("max", 1.0))
		if hp <= 0.0:
			if item == "wood" and int(w.get("wood", 0)) + int(u.wood) < 3:
				return true
			if item == "fiber" and int(w.get("fiber", 0)) + int(u.fiber) < 1:
				return true
		elif hp < mx and item == "wood" and int(u.wood) < 1:
			return true
	return false


static func _remaining(forge) -> Dictionary:
	var need := recipe(str(forge.get("weapon", "sword")))
	return {
		"wood": maxi(0, int(need["wood"]) - int(forge.get("wood", 0))),
		"hide": maxi(0, int(need["hide"]) - int(forge.get("hide", 0))),
		"fiber": maxi(0, int(need["fiber"]) - int(forge.get("fiber", 0))),
	}


static func _wanted(u) -> String:
	var id := str(u.unit_id)
	if id == "bram" or id == "mira":
		return "wand"
	return "sword"


static func _forge_for(match_node, team: int, kind: String):
	for forge in match_node.forges:
		if int(forge.get("team", -1)) == team and str(forge.get("weapon", "")) == kind:
			return forge
	return null


static func _nearest_node(match_node, origin: Vector2, items: Array, skip: Array):
	var best = null
	var bd := 100000000.0
	for n in match_node.nodes:
		if float(n.get("hp", 0.0)) <= 0.0:
			continue
		if not items.has(str(n.get("item", ""))):
			continue
		if skip.has(n):
			continue
		var pos: Vector2 = n["pos"]
		var dist := origin.distance_squared_to(pos)
		if dist < bd:
			bd = dist
			best = n
	return best


static func _nearest_pile(match_node, origin: Vector2, items: Array, reach: float):
	var best = null
	var bd := reach * reach
	for pile in match_node.piles:
		var useful := false
		for key in items:
			if int(pile.get(key, 0)) > 0:
				useful = true
		if not useful:
			continue
		var pos: Vector2 = pile["pos"]
		var dist := origin.distance_squared_to(pos)
		if dist <= bd:
			bd = dist
			best = pile
	return best


static func _nearest_drop(match_node, origin: Vector2, reach: float):
	var best = null
	var bd := reach * reach
	for drop in match_node.weapon_drops:
		var pos: Vector2 = drop["pos"]
		var dist := origin.distance_squared_to(pos)
		if dist <= bd:
			bd = dist
			best = drop
	return best


static func _kind_id(kind: String) -> int:
	if kind == "plant":
		return 1
	if kind == "animal":
		return 2
	return 0


static func _show(n, shown: bool) -> void:
	var vis = n.get("visual")
	if vis != null and is_instance_valid(vis):
		vis.visible = shown


static func _mark_built(forge) -> void:
	var visual = forge.get("visual")
	if visual is Polygon2D:
		var sword := str(forge.get("weapon", "")) == "sword"
		visual.color = Color(1.0, 0.86, 0.42) if sword else Color(0.72, 0.92, 1.0)


static func _pile_color(pile) -> Color:
	if int(pile.get("hide", 0)) >= int(pile.get("wood", 0)) and int(pile.get("hide", 0)) >= int(pile.get("fiber", 0)):
		return Color(0.62, 0.42, 0.24)
	if int(pile.get("fiber", 0)) > int(pile.get("wood", 0)):
		return Color(0.45, 0.72, 0.32)
	return Color(0.55, 0.36, 0.16)


static func _marker(match_node, pos: Vector2, color: Color, radius: float) -> Polygon2D:
	if match_node.headless_server:
		return null
	var parent: Node = match_node.get_node_or_null("World")
	if parent == null:
		return null
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * float(i) / 8.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	poly.polygon = pts
	poly.color = color
	poly.position = pos
	parent.add_child(poly)
	return poly


static func _free_vis(record) -> void:
	if record == null:
		return
	var vis = record.get("visual")
	if vis != null and is_instance_valid(vis):
		vis.queue_free()


static func _world(match_node) -> Node:
	return match_node.get_node_or_null("World")
