@tool
class_name BGCPSelection extends RefCounted

var grid: BezierGrid3D = null : set=_set_grid
var selected_control_points: PackedInt32Array = []


func _set_grid(i_grid: BezierGrid3D) -> void:
	if grid != i_grid:
		unselect_all()
		grid = i_grid


func unselect_all(clear_grid: bool = false) -> void:
	if clear_grid:
		grid = null
	selected_control_points.clear()


func set_selection(i_grid: BezierGrid3D, i_cps: PackedInt32Array) -> void:
	grid = i_grid
	selected_control_points.clear()
	selected_control_points.append_array(i_cps)


func unselect_control_point(cp: int) -> void:
	var idx: int = selected_control_points.find(cp)
	if idx != -1:
		selected_control_points.remove_at(idx)


func select_control_point(cp: int) -> void:
	if !selected_control_points.has(cp):
		selected_control_points.push_back(cp)


func is_selected(cp: int) -> bool:
	return selected_control_points.has(cp)


func is_empty() -> bool:
	return selected_control_points.is_empty()
