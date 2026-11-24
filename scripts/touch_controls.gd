extends Control
## Phone controls from the browser match. The stick sits in from the lower-left
## corner. Attack sits large on the lower right, and the three equipped skills
## arc above it. Throw and Defense show beside the skills only while carrying.

const Balance = preload("res://scripts/balance.gd")

signal attack_pressed
signal throw_pressed
signal guard_pressed
signal interact_pressed
signal drop_pressed
signal skill_pressed(id: String)

var wish := Vector2.ZERO

var _stick: Control
var _knob: Control
var _ring: Control
var _cluster: Control
var _slots: Control
var attack_btn: Button
var throw_btn: Button
var guard_btn: Button
var use_btn: Button
var drop_btn: Button
var slot_buttons := {}
var _dragging := false
var _drag_id := -1
var _using_touch := false
var _floated := false
var _shown_for_edit := false
var _editing := false
var _selected := ""
var _edit_drag := -1
var _edit_off := Vector2.ZERO
var _custom := {}
var _bar: PanelContainer
var _hint: Label

const SKILL_ANCHOR := {
	"ignite": Vector2(0.72, 0.66),
	"spark": Vector2(0.50, 0.30),
	"ember": Vector2(0.88, 0.46),
	"fireball": Vector2(0.72, 0.66),
	"ice": Vector2(0.50, 0.30),
	"mega": Vector2(0.88, 0.46),
}
const SKILL_COLOR := {
	"ignite": "#ffb067",
	"spark": "#ffe08a",
	"ember": "#ff8a5b",
	"fireball": "#ffe0cc",
	"ice": "#d7f3ff",
	"mega": "#ffd0d0",
}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grab_nodes()
	visible = OS.has_feature("web") or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	if visible:
		Input.emulate_mouse_from_touch = false
	_style_base()
	_load_layout()
	_build_bar()
	if not resized.is_connected(_layout):
		resized.connect(_layout)
	call_deferred("_layout")


func _grab_nodes() -> void:
	_stick = get_node_or_null("Stick")
	if _stick == null:
		_stick = Control.new()
		_stick.name = "Stick"
		add_child(_stick)
	_knob = _stick.get_node_or_null("Knob")
	if _knob == null:
		_knob = Panel.new()
		_knob.name = "Knob"
		_stick.add_child(_knob)
	_ring = _stick.get_node_or_null("Ring")
	if _ring == null:
		_ring = Panel.new()
		_ring.name = "Ring"
		_stick.add_child(_ring)
	_cluster = get_node_or_null("SkillCluster")
	if _cluster == null:
		_cluster = Control.new()
		_cluster.name = "SkillCluster"
		add_child(_cluster)
	_slots = _cluster.get_node_or_null("Slots")
	if _slots == null:
		_slots = Control.new()
		_slots.name = "Slots"
		_cluster.add_child(_slots)
	attack_btn = _cluster.get_node_or_null("Attack")
	if attack_btn == null:
		attack_btn = Button.new()
		attack_btn.name = "Attack"
		attack_btn.text = "ATK"
		_cluster.add_child(attack_btn)
	throw_btn = _cluster.get_node_or_null("Throw")
	if throw_btn == null:
		throw_btn = Button.new()
		throw_btn.name = "Throw"
		throw_btn.text = "Throw"
		_cluster.add_child(throw_btn)
	guard_btn = _cluster.get_node_or_null("Defense")
	if guard_btn == null:
		guard_btn = Button.new()
		guard_btn.name = "Defense"
		guard_btn.text = "Defense"
		_cluster.add_child(guard_btn)
	use_btn = _cluster.get_node_or_null("Use")
	if use_btn == null:
		use_btn = Button.new()
		use_btn.name = "Use"
		use_btn.text = "Use"
		_cluster.add_child(use_btn)
	drop_btn = _cluster.get_node_or_null("Drop")
	if drop_btn == null:
		drop_btn = Button.new()
		drop_btn.name = "Drop"
		drop_btn.text = "Drop"
		_cluster.add_child(drop_btn)
	_stick.mouse_filter = Control.MOUSE_FILTER_STOP
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slots.set_anchors_preset(Control.PRESET_FULL_RECT)
	if not _stick.gui_input.is_connected(_on_stick_gui):
		_stick.gui_input.connect(_on_stick_gui)
	if not attack_btn.pressed.is_connected(_emit_attack):
		attack_btn.pressed.connect(_emit_attack)
	if not throw_btn.pressed.is_connected(_emit_throw):
		throw_btn.pressed.connect(_emit_throw)
	if not guard_btn.pressed.is_connected(_emit_guard):
		guard_btn.pressed.connect(_emit_guard)
	if not use_btn.pressed.is_connected(_emit_interact):
		use_btn.pressed.connect(_emit_interact)
	if not drop_btn.pressed.is_connected(_emit_drop):
		drop_btn.pressed.connect(_emit_drop)
	attack_btn.focus_mode = Control.FOCUS_NONE
	throw_btn.focus_mode = Control.FOCUS_NONE
	guard_btn.focus_mode = Control.FOCUS_NONE
	use_btn.focus_mode = Control.FOCUS_NONE
	drop_btn.focus_mode = Control.FOCUS_NONE
	attack_btn.text = "ATK"
	use_btn.text = "Use"
	drop_btn.text = "Drop"
	throw_btn.visible = false
	guard_btn.visible = false
	drop_btn.visible = false
	var parent_node := get_parent()
	if parent_node:
		parent_node.move_child.call_deferred(self, parent_node.get_child_count() - 1)


func _style_base() -> void:
	var stick_fill := Color(0.078, 0.039, 0.125, 0.46)
	var stick_edge := Color(1.0, 0.965, 0.894, 0.78)
	if _stick is Panel:
		_paint_panel(_stick, stick_fill, stick_edge, 3)
	else:
		var base := _stick.get_node_or_null("Base")
		if base == null:
			base = Panel.new()
			base.name = "Base"
			base.mouse_filter = Control.MOUSE_FILTER_IGNORE
			base.set_anchors_preset(Control.PRESET_FULL_RECT)
			_stick.add_child(base)
			_stick.move_child(base, 0)
		_paint_panel(base, stick_fill, stick_edge, 3)
	_paint_panel(_ring, Color(0, 0, 0, 0), Color(1.0, 0.965, 0.894, 0.4), 2)
	_paint_panel(_knob, Color.html("#ffc44d"), Color.html("#1b1428"), 3)
	_paint_button(attack_btn, Color.html("#ffc44d"), 16)
	_paint_button(throw_btn, Color.html("#7ad7ff"), 13)
	_paint_button(guard_btn, Color.html("#9fd7ff"), 11)
	_paint_button(use_btn, Color.html("#e7d3a1"), 13)
	_paint_button(drop_btn, Color.html("#d7e38a"), 13)
	attack_btn.add_theme_color_override("font_color", Color.html("#1b1428"))
	throw_btn.add_theme_color_override("font_color", Color.html("#1b1428"))
	guard_btn.add_theme_color_override("font_color", Color.html("#1b1428"))
	use_btn.add_theme_color_override("font_color", Color.html("#1b1428"))
	drop_btn.add_theme_color_override("font_color", Color.html("#1b1428"))


func set_skills(ids: Array) -> void:
	if _slots == null:
		return
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.free()
	slot_buttons.clear()
	for id in ids:
		var skill_id := str(id)
		if not SKILL_ANCHOR.has(skill_id):
			continue
		var btn := Button.new()
		btn.name = skill_id
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.text = str(Balance.SHORT.get(skill_id, skill_id))
		_paint_button(btn, Color.html(str(SKILL_COLOR[skill_id])), 12)
		btn.add_theme_color_override("font_color", Color.html("#1b1428"))
		btn.pressed.connect(_emit_skill.bind(skill_id))
		_slots.add_child(btn)
		slot_buttons[skill_id] = btn
	_layout()


func set_carrying(on: bool) -> void:
	if _editing:
		throw_btn.visible = true
		guard_btn.visible = true
		return
	if throw_btn:
		throw_btn.visible = on
	if guard_btn:
		guard_btn.visible = on


func set_bag(on: bool) -> void:
	if _editing:
		drop_btn.visible = true
		return
	if drop_btn:
		drop_btn.visible = on


func set_guard_on(on: bool) -> void:
	if guard_btn == null:
		return
	guard_btn.text = "Defense\nON" if on else "Defense"
	var fill := Color.html("#7ef0ff") if on else Color.html("#9fd7ff")
	_paint_button(guard_btn, fill, 11)
	guard_btn.add_theme_color_override("font_color", Color.html("#083044") if on else Color.html("#1b1428"))


func set_cooldowns(player) -> void:
	for id in slot_buttons.keys():
		var btn: Button = slot_buttons[id]
		var cd := float(player.cds.get(id, 0.0))
		var short := str(Balance.SHORT.get(id, id))
		btn.text = short if cd <= 0.05 else "%.1f" % cd


func _emit_attack() -> void:
	attack_pressed.emit()


func _emit_throw() -> void:
	throw_pressed.emit()


func _emit_guard() -> void:
	guard_pressed.emit()


func _emit_interact() -> void:
	interact_pressed.emit()


func _emit_drop() -> void:
	drop_pressed.emit()


func _emit_skill(id: String) -> void:
	skill_pressed.emit(id)


func _layout() -> void:
	if _stick == null or _cluster == null:
		return
	var vp := size
	if vp.x < 8.0:
		vp = get_viewport_rect().size
	_pin_top_left(_cluster)
	_cluster.position = Vector2.ZERO
	_cluster.size = vp
	_pin_top_left(_slots)
	_slots.position = Vector2.ZERO
	_slots.size = vp
	if not _dragging and _edit_drag < 0:
		_place_id("stick", _stick, _default_stick(vp), vp)
	_fit_stick_parts()
	_place_id("attack", attack_btn, _default_attack(vp), vp)
	_place_id("use", use_btn, _default_use(vp), vp)
	_place_id("drop", drop_btn, _default_drop(vp), vp)
	_place_id("throw", throw_btn, _default_throw(vp), vp)
	_place_id("guard", guard_btn, _default_guard(vp), vp)
	for id in slot_buttons.keys():
		_place_id(str(id), slot_buttons[id], _default_skill(str(id), vp), vp)
	_refresh_select()


func _place_id(id: String, node: Control, home: Rect2, vp: Vector2) -> void:
	if node == null or (_edit_drag >= 0 and id == _selected):
		return
	var rect := home
	if _custom.has(id):
		var row: Array = _custom[id]
		var scale: float = clampf(float(row[2]), 0.55, 1.85)
		var next := home.size * scale
		var center := Vector2(float(row[0]) * vp.x, float(row[1]) * vp.y)
		rect = Rect2(center - next * 0.5, next)
	_pin_top_left(node)
	node.position = rect.position
	node.size = rect.size
	if node is Button:
		(node as Button).custom_minimum_size = rect.size


func _default_stick(vp: Vector2) -> Rect2:
	var narrow := vp.x < 700.0
	var stick_s := 120.0 if narrow else 132.0
	var left := 44.0 if narrow else 48.0
	var bottom := 56.0 if narrow else 64.0
	return Rect2(left, vp.y - bottom - stick_s, stick_s, stick_s)


func _cluster_box(vp: Vector2) -> Rect2:
	var narrow := vp.x < 700.0
	var cw := 236.0 if narrow else 268.0
	var ch := 196.0 if narrow else 220.0
	var right := 28.0 if narrow else 32.0
	var cbottom := 40.0 if narrow else 48.0
	return Rect2(vp.x - right - cw, vp.y - cbottom - ch, cw, ch)


func _default_attack(vp: Vector2) -> Rect2:
	var narrow := vp.x < 700.0
	var box := _cluster_box(vp)
	var aw := 84.0 if narrow else 96.0
	return Rect2(box.position.x + box.size.x - aw, box.position.y + box.size.y - box.size.y * 0.12 - aw, aw, aw)


func _default_use(vp: Vector2) -> Rect2:
	var narrow := vp.x < 700.0
	var box := _cluster_box(vp)
	var aw := 84.0 if narrow else 96.0
	var uw := 62.0 if narrow else 68.0
	return Rect2(box.position.x + box.size.x - aw - uw - 10.0, box.position.y + box.size.y - box.size.y * 0.12 - uw, uw, uw)


func _default_drop(vp: Vector2) -> Rect2:
	var narrow := vp.x < 700.0
	var box := _cluster_box(vp)
	var aw := 84.0 if narrow else 96.0
	var uw := 62.0 if narrow else 68.0
	var dw := 64.0 if narrow else 70.0
	return Rect2(box.position.x + box.size.x - aw - uw - dw - 18.0, box.position.y + box.size.y - box.size.y * 0.12 - dw, dw, dw)


func _default_throw(vp: Vector2) -> Rect2:
	var narrow := vp.x < 700.0
	var box := _cluster_box(vp)
	var tw := 72.0 if narrow else 80.0
	return Rect2(box.position.x + box.size.x - tw, box.position.y - 14.0 - tw, tw, tw)


func _default_guard(vp: Vector2) -> Rect2:
	var narrow := vp.x < 700.0
	var box := _cluster_box(vp)
	var tw := 72.0 if narrow else 80.0
	var guard_right := 84.0 if narrow else 96.0
	return Rect2(box.position.x + box.size.x - guard_right - tw, box.position.y - 14.0 - tw, tw, tw)


func _default_skill(id: String, vp: Vector2) -> Rect2:
	var narrow := vp.x < 700.0
	var box := _cluster_box(vp)
	var sw := 64.0 if narrow else 70.0
	var anchor: Vector2 = SKILL_ANCHOR.get(id, Vector2(0.5, 0.5))
	var x := box.position.x + box.size.x - box.size.x * anchor.x - sw
	var y := box.position.y + box.size.y - box.size.y * anchor.y - sw
	return Rect2(x, y, sw, sw)


func _home(id: String) -> Rect2:
	var vp := size
	if vp.x < 8.0:
		vp = get_viewport_rect().size
	if id == "stick":
		return _default_stick(vp)
	if id == "attack":
		return _default_attack(vp)
	if id == "use":
		return _default_use(vp)
	if id == "drop":
		return _default_drop(vp)
	if id == "throw":
		return _default_throw(vp)
	if id == "guard":
		return _default_guard(vp)
	return _default_skill(id, vp)


func _fit_stick_parts() -> void:
	if _stick == null or _knob == null or _ring == null:
		return
	var knob_s := _stick.size.x * 0.43
	_pin_top_left(_knob)
	_knob.size = Vector2(knob_s, knob_s)
	_knob.custom_minimum_size = _knob.size
	_pin_top_left(_ring)
	_ring.size = _stick.size * 0.34
	_ring.position = (_stick.size - _ring.size) * 0.5
	if not _dragging:
		_center_knob()


func _pin_top_left(node: Control) -> void:
	if node == null:
		return
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)


func _place_round(btn: Button, x: float, y: float, diameter: float) -> void:
	if btn == null:
		return
	_pin_top_left(btn)
	btn.position = Vector2(x, y)
	btn.size = Vector2(diameter, diameter)
	btn.custom_minimum_size = btn.size


func _center_knob() -> void:
	if _knob == null or _stick == null:
		return
	_knob.position = (_stick.size - _knob.size) * 0.5


func _on_stick_gui(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_using_touch = true
			_dragging = true
			_drag_id = touch.index
			_move_knob(touch.position)
		elif _drag_id == touch.index:
			_end_drag()
		_stick.accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _dragging and drag.index == _drag_id:
			_move_knob(drag.position)
		_stick.accept_event()
	elif event is InputEventMouseButton and not _using_touch:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_dragging = true
			_drag_id = -2
			_move_knob(button.position)
		elif _drag_id == -2:
			_end_drag()
		_stick.accept_event()
	elif event is InputEventMouseMotion and _dragging and _drag_id == -2 and not _using_touch:
		_move_knob((event as InputEventMouseMotion).position)
		_stick.accept_event()


func _input(event: InputEvent) -> void:
	if _editing:
		_edit_input(event)
		return
	if not visible or not _dragging:
		return
	if event is InputEventScreenDrag and _drag_id == (event as InputEventScreenDrag).index:
		_move_knob(_stick_local((event as InputEventScreenDrag).position))
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed and _drag_id == (event as InputEventScreenTouch).index:
		_end_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drag_id == -2 and not _using_touch:
		_move_knob(_stick_local((event as InputEventMouseMotion).position))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and _drag_id == -2 and not (event as InputEventMouseButton).pressed and not _using_touch:
		_end_drag()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _editing or _dragging:
		return
	if not (event is InputEventScreenTouch):
		return
	var touch := event as InputEventScreenTouch
	if not touch.pressed:
		return
	if _hit_control(touch.position) != "":
		return
	_floated = true
	_using_touch = true
	_dragging = true
	_drag_id = touch.index
	_move_stick_to(touch.position)
	_move_knob(_stick_local(touch.position))
	get_viewport().set_input_as_handled()


func _stick_local(screen_pos: Vector2) -> Vector2:
	return _stick.get_global_transform_with_canvas().affine_inverse() * screen_pos


func _move_knob(local: Vector2) -> void:
	var center := _stick.size * 0.5
	var delta := local - center
	var max_r := _stick.size.x * 0.36
	var length := delta.length()
	var mag := 0.0
	if length > 0.001 and max_r > 0.001:
		mag = minf(1.0, length / max_r)
		delta = delta / length * mag
	else:
		delta = Vector2.ZERO
	wish = delta
	_knob.position = center + delta * max_r - _knob.size * 0.5


func _end_drag() -> void:
	_dragging = false
	_floated = false
	_drag_id = -1
	_using_touch = false
	wish = Vector2.ZERO
	_layout()


func _move_stick_to(screen: Vector2) -> void:
	var local := _local_point(screen)
	var half := _stick.size * 0.5
	local.x = clampf(local.x, half.x + 6.0, size.x - half.x - 6.0)
	local.y = clampf(local.y, half.y + 6.0, size.y - half.y - 6.0)
	_stick.position = local - half


func _local_point(screen: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen


func toggle_layout() -> void:
	if _dragging:
		_end_drag()
	_editing = not _editing
	if _editing:
		if not visible:
			_shown_for_edit = true
			visible = true
		_selected = ""
		_edit_drag = -1
		throw_btn.visible = true
		guard_btn.visible = true
		drop_btn.visible = true
		_play_filter(Control.MOUSE_FILTER_IGNORE)
		_bar.visible = true
		_hint.text = "Drag a button to move it. Smaller and Bigger change the selected one."
	else:
		_save_layout()
		_play_filter(Control.MOUSE_FILTER_STOP)
		_bar.visible = false
		_selected = ""
		if _shown_for_edit:
			visible = false
			_shown_for_edit = false
	_refresh_select()
	_layout()


func _play_filter(filter: Control.MouseFilter) -> void:
	_stick.mouse_filter = filter
	for id in _control_ids():
		var node := _node(id)
		if node is Button:
			node.mouse_filter = filter


func _build_bar() -> void:
	_bar = PanelContainer.new()
	_bar.visible = false
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_bar.offset_left = -280.0
	_bar.offset_right = 280.0
	_bar.offset_top = 108.0
	_bar.offset_bottom = 176.0
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.07, 0.14, 0.92)
	box.set_corner_radius_all(10)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	_bar.add_theme_stylebox_override("panel", box)
	add_child(_bar)
	var col := VBoxContainer.new()
	_bar.add_child(col)
	_hint = Label.new()
	_hint.text = "Drag a button to move it."
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
	col.add_child(_hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	row.add_child(_bar_button("Smaller", _shrink))
	row.add_child(_bar_button("Bigger", _grow))
	row.add_child(_bar_button("Reset", _reset_layout))
	row.add_child(_bar_button("Done", toggle_layout))


func _bar_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(callback)
	return btn


func _shrink() -> void:
	_scale_selected(0.88)


func _grow() -> void:
	_scale_selected(1.14)


func _scale_selected(mult: float) -> void:
	if _selected == "":
		_hint.text = "Tap a button first, then change its size."
		return
	var node := _node(_selected)
	if node == null:
		return
	var home := _home(_selected)
	var scale := clampf(node.size.x / maxf(home.size.x, 1.0) * mult, 0.55, 1.85)
	var center := node.position + node.size * 0.5
	var next := home.size * scale
	node.position = center - next * 0.5
	node.size = next
	if node is Button:
		(node as Button).custom_minimum_size = next
	_keep_inside(node)
	if _selected == "stick":
		_fit_stick_parts()
	_capture(_selected)
	_hint.text = "Size saved for that button. Drag it if you want it somewhere else."


func _edit_input(event: InputEvent) -> void:
	var screen := Vector2.ZERO
	var index := -1
	var pressed := false
	var released := false
	var moving := false
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		screen = touch.position
		index = touch.index
		pressed = touch.pressed
		released = not touch.pressed
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		screen = drag.position
		index = drag.index
		moving = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		screen = button.position
		index = -2
		pressed = button.pressed
		released = not button.pressed
	elif event is InputEventMouseMotion and _edit_drag == -2:
		screen = (event as InputEventMouseMotion).position
		index = -2
		moving = true
	else:
		return
	if _bar_has(screen) and pressed:
		return
	if pressed:
		var id := _hit_control(screen)
		if id == "":
			get_viewport().set_input_as_handled()
			return
		_selected = id
		_refresh_select()
		_edit_drag = index
		var node := _node(id)
		_edit_off = _local_point(screen) - node.position
		_hint.text = "Dragging. Smaller and Bigger change this button."
		get_viewport().set_input_as_handled()
	elif moving and index == _edit_drag and _selected != "":
		var node2 := _node(_selected)
		if node2:
			node2.position = _local_point(screen) - _edit_off
			_keep_inside(node2)
		get_viewport().set_input_as_handled()
	elif released and index == _edit_drag:
		_edit_drag = -1
		if _selected != "":
			_capture(_selected)
		get_viewport().set_input_as_handled()


func _bar_has(screen: Vector2) -> bool:
	return _bar != null and _bar.visible and _bar.get_global_rect().has_point(screen)


func _hit_control(screen: Vector2) -> String:
	var best := ""
	var best_area := 100000000.0
	for id in _control_ids():
		var node := _node(id)
		if node == null or not node.visible:
			continue
		var rect := node.get_global_rect()
		if not rect.has_point(screen):
			continue
		var area := rect.size.x * rect.size.y
		if area < best_area:
			best_area = area
			best = id
	return best


func _control_ids() -> Array:
	var ids: Array = ["stick", "attack", "use", "drop", "throw", "guard"]
	for id in slot_buttons.keys():
		ids.append(str(id))
	return ids


func _node(id: String) -> Control:
	if id == "stick":
		return _stick
	if id == "attack":
		return attack_btn
	if id == "use":
		return use_btn
	if id == "drop":
		return drop_btn
	if id == "throw":
		return throw_btn
	if id == "guard":
		return guard_btn
	return slot_buttons.get(id) as Control


func _keep_inside(node: Control) -> void:
	var limit := size
	if limit.x < 8.0:
		limit = get_viewport_rect().size
	node.position.x = clampf(node.position.x, 0.0, maxf(0.0, limit.x - node.size.x))
	node.position.y = clampf(node.position.y, 0.0, maxf(0.0, limit.y - node.size.y))


func _capture(id: String) -> void:
	var node := _node(id)
	if node == null:
		return
	var vp := size
	if vp.x < 8.0:
		vp = get_viewport_rect().size
	var home := _home(id)
	var center := node.position + node.size * 0.5
	var scale := node.size.x / maxf(home.size.x, 1.0)
	_custom[id] = [center.x / vp.x, center.y / vp.y, scale]


func _refresh_select() -> void:
	for id in _control_ids():
		var node := _node(id)
		if node == null:
			continue
		node.modulate = Color(1.0, 0.92, 0.55) if id == _selected and _editing else Color.WHITE


func _load_layout() -> void:
	_custom = {}
	var saved = Profile.data.get("touch_layout", {})
	if typeof(saved) != TYPE_DICTIONARY:
		return
	for key in saved.keys():
		var row = saved[key]
		if typeof(row) == TYPE_ARRAY and row.size() >= 3:
			_custom[str(key)] = [float(row[0]), float(row[1]), float(row[2])]


func _save_layout() -> void:
	Profile.data["touch_layout"] = _custom.duplicate(true)
	Profile.save_data()


func _reset_layout() -> void:
	_custom.clear()
	_selected = ""
	_save_layout()
	_layout()
	_hint.text = "Buttons are back in their starting places."


func _paint_panel(node: Control, fill: Color, edge: Color, border: int) -> void:
	var box := _circle_style(fill, edge, border)
	node.add_theme_stylebox_override("panel", box)


func _paint_button(btn: Button, fill: Color, font_size: int) -> void:
	var edge := Color.html("#1b1428")
	var normal := _circle_style(fill, edge, 3)
	var pressed := _circle_style(fill.darkened(0.12), edge, 3)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_stylebox_override("disabled", normal)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER


func _circle_style(fill: Color, edge: Color, border: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(80)
	box.set_border_width_all(border)
	box.border_color = edge
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box
