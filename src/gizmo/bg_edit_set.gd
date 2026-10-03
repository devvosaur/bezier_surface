@tool
class_name BGEditSet extends RefCounted

var grid: BezierGrid3D = null : set=_set_grid
var control_points: PackedInt32Array = []
## pos: (x, y, z), weight: w
var src_data: PackedVector4Array = []

func clear() -> void:
	control_points.clear()
	src_data.clear()


func _set_grid(i_grid: BezierGrid3D) -> void: 
	if grid != i_grid:
		clear()
		grid = i_grid

func add(cp: int, w: float) -> void:
	if w <= 0.:
		push_error("cannot add cps that have negative influence")
		return
	
	var idx: int = control_points.find(cp)
	if idx != -1:
		src_data[idx].w = w
	else:
		var p: Vector3 = grid.surface.control_points[cp]
		src_data.push_back(Vector4(p.x, p.y, p.z, clampf(w, 0., 1.)))

func remove(cp: int) -> void:
	var idx: int = control_points.find(cp)
	if idx != -1:
		control_points.remove_at(idx)
		src_data.remove_at(idx)


## build edit data from a callback that takes the current grid and the control point id and returns its weight
## only points whose weight is > 0 will be kept. Weight is then clamped to [0,1]
func build_from(cb: Callable) -> void:
	clear()
	for i: int in grid.surface.control_points.size():
		var w: float = cb.call(grid, i)
		if w > 0.:
			control_points.push_back(i)
			var p: Vector3 = grid.surface.control_points[i]
			src_data.push_back(Vector4(p.x, p.y, p.z, clampf(w, 0., 1.)))


func is_empty() -> bool:
	return control_points.is_empty()
