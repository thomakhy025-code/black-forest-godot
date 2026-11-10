extends Node2D

var team := 0
var bob := 0.0
var _step := -1
var _gem := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _loop := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _glint := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


func _process(delta: float) -> void:
	bob += delta
	var step := int(bob * 6.0)
	if step == _step:
		return
	_step = step
	queue_redraw()


func _draw() -> void:
	var col := Color(1.0, 0.36, 0.5) if team == 0 else Color(0.35, 0.85, 1.0)
	var y := sin(bob * 3.0) * 0.04
	_gem[0] = Vector2(0, -0.4 + y)
	_gem[1] = Vector2(0.28, -0.05 + y)
	_gem[2] = Vector2(0, 0.42 + y)
	_gem[3] = Vector2(-0.28, -0.05 + y)
	draw_colored_polygon(_gem, col)
	_loop[0] = _gem[0]
	_loop[1] = _gem[1]
	_loop[2] = _gem[2]
	_loop[3] = _gem[3]
	_loop[4] = _gem[0]
	draw_polyline(_loop, Color(1, 1, 1, 0.9), 0.035, true)
	var shift := float((_step & 3) - 1) * 0.035
	_glint[0] = Vector2(-0.08 + shift, -0.16 + y)
	_glint[1] = Vector2(0.08 + shift, -0.16 + y)
	_glint[2] = Vector2(shift, 0.05 + y)
	draw_colored_polygon(_glint, Color(1, 1, 1, 0.8))
