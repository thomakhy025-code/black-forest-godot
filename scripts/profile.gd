extends Node
## Local name, stats, and match record. The old card loadout is not used.

const SAVE_PATH := "user://black-forest-profile.cfg"
const Balance = preload("res://scripts/balance.gd")

var data := {}


func _ready() -> void:
	_bind_inputs()
	load_data()


func _bind_inputs() -> void:
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("attack", [KEY_J])
	_bind("throw", [KEY_F])
	_bind("interact", [KEY_E])
	_bind("hop", [KEY_SPACE])
	_bind("guard", [KEY_G])
	_bind("help", [KEY_H])
	_bind("dismiss", [KEY_ESCAPE, KEY_ENTER])
	_bind("skill1", [KEY_1])
	_bind("skill2", [KEY_2])
	_bind("skill3", [KEY_3])


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).size() > 0:
		return
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key as Key
		InputMap.action_add_event(action, ev)


func blank() -> Dictionary:
	return {
		"name": "You",
		"gender": "",
		"coins": 10000,
		"diamonds": 1000,
		"stats": {"atk": 0, "spd": 0, "hp": 0, "cdr": 0, "mp": 0},
		"tokens": 0,
		"wins": 0,
		"matches": 0,
		"help_seen": false
	}


func load_data() -> void:
	data = blank()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var saved = cfg.get_value("profile", "data", {})
	if typeof(saved) != TYPE_DICTIONARY:
		return
	_merge(data, saved)
	_migrate_stats()
	for key in ["cards", "unlocked", "equipped", "free_unlocks", "pending_draw"]:
		data.erase(key)


func _merge(dst: Dictionary, src: Dictionary) -> void:
	for key in src.keys():
		if dst.has(key) and typeof(dst[key]) == TYPE_DICTIONARY and typeof(src[key]) == TYPE_DICTIONARY:
			for inner in src[key].keys():
				dst[key][inner] = src[key][inner]
		else:
			dst[key] = src[key]


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "data", data)
	cfg.save(SAVE_PATH)


func snapshot() -> Dictionary:
	return data.duplicate(true)


func spent_points() -> int:
	var n := 0
	for key in Balance.STAT_KEYS:
		n += int(data["stats"].get(key, 0))
	return n


func _migrate_stats() -> void:
	var stats: Dictionary = data.get("stats", {})
	var legacy := stats.has("pwr") or stats.has("agi") or stats.has("str") or stats.has("int")
	var clean := Balance.blank_stats()
	if legacy:
		clean["atk"] = int(stats.get("pwr", 0))
		clean["spd"] = int(stats.get("spd", 0))
		clean["hp"] = int(stats.get("str", 0))
		clean["cdr"] = int(stats.get("int", 0))
		clean["mp"] = 0
	else:
		for key in Balance.STAT_KEYS:
			clean[key] = int(stats.get(key, 0))
	data["stats"] = _clamp_stat_spend(clean)


func _clamp_stat_spend(stats: Dictionary) -> Dictionary:
	var clean := Balance.blank_stats()
	var spent := 0
	for key in Balance.STAT_KEYS:
		var value := clampi(int(stats.get(key, 0)), 0, 10)
		if spent + value > 10:
			value = 10 - spent
		spent += value
		clean[key] = value
	return clean


func apply_suggested() -> void:
	data["stats"] = {"atk": 2, "spd": 2, "hp": 2, "cdr": 2, "mp": 2}
	save_data()


func note_match(won: bool, _draw: bool) -> void:
	data["matches"] = int(data["matches"]) + 1
	if won:
		data["coins"] = int(data["coins"]) + 2500
		data["diamonds"] = int(data["diamonds"]) + 100
		data["tokens"] = int(data["tokens"]) + 1
		data["wins"] = int(data["wins"]) + 1
	save_data()
