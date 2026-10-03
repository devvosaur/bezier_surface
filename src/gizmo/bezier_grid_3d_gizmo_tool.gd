@tool @abstract
class_name BezierGrid3DGizmoTool extends RefCounted


var cur_grid: BezierGrid3D = null
var pivot: Vector3 = Vector3.ZERO
var control_points: PackedInt32Array = []
var src_data: PackedVector4Array = []

## get tool name
@abstract func get_name() -> StringName

## get action name, used by undo/redo manager
@abstract func get_undo_redo_action_name() -> String

## update the tool - this should update the control points to their expected position without committing them
@abstract func _update() -> void

func setup(selection: BGCPSelection, edit_set: BGEditSet) -> void:
	_copy_edit_set(edit_set)
	# calculate pivot
	pivot = Vector3.ZERO
	if selection.grid != cur_grid:
		# this should never happen
		push_error("grid selection mismatch") 
		return
	
	var count: int = selection.selected_control_points.size()
	if count <= 0:
		# this should never happen
		push_error("no selection")
		return
	
	var normalization_factor: float = 1. / max(count, 1)
	for cp: int in selection.selected_control_points:
		pivot += cur_grid.surface.control_points[cp]
	pivot *= normalization_factor


func _copy_edit_set(edit_set: BGEditSet) -> void:
	control_points.clear()
	src_data.clear()
	
	cur_grid = edit_set.grid
	# full copy to avoid changes due to references: arrays are passed by ref in gdscript
	control_points.append_array(edit_set.control_points)
	src_data.append_array(edit_set.src_data)


# this is like this to be used by undo/redo manager as well
func _set_cp_value(grid: BezierGrid3D, cp: int, p: Vector3) -> void:
	grid.surface.control_points[cp] = p

func _update_gizmos(grid: BezierGrid3D) -> void:
	grid.update_gizmos()

func commit() -> void:
	var urm: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	urm.create_action(get_undo_redo_action_name())
	const method_name: StringName = &"_set_cp_value"
	for i: int in control_points.size():
		var cp: int = control_points[i]
		var v: Vector4 = src_data[i]
		# restore old value
		urm.add_undo_method(self, method_name, cur_grid, cp, Vector3(v.x, v.y, v.z))
		# current value is already edited - do method should use it
		urm.add_do_method(self, method_name, cur_grid, cp, cur_grid.surface.control_points[cp])
	
	urm.add_undo_method(self, &"_update_gizmos", cur_grid)
	urm.add_do_method(self, &"_update_gizmos", cur_grid)
	urm.commit_action()
	
	# ok, done: clear everything
	clear()


func cancel() -> void:
	revert_pending_changes()
	clear()


## called from the owner whenever the edit set changes
func notify_edit_set_changed(edit_set: BGEditSet) -> void:
	revert_pending_changes()
	_copy_edit_set(edit_set)
	_update()


## revert pending changes without clearing the edit set
func revert_pending_changes() -> void:
	if !cur_grid:
		return
	
	for i: int in control_points.size():
		var cp: int = control_points[i]
		var v: Vector4 = src_data[i]
		_set_cp_value(cur_grid, cp, Vector3(v.x, v.y, v.z))
	
	cur_grid.update_gizmos()


func clear() -> void:
	cur_grid = null
	control_points.clear()
	src_data.clear()


func get_depth(cam: Camera3D, p: Vector3) -> float:
	var screen_pos: Vector2 = cam.unproject_position(p)
	var ray_normal: Vector3 = cam.project_ray_normal(screen_pos)
	var cam_proj: Projection = cam.get_camera_projection()
	var zfar: float = cam_proj.get_z_far()
	var znear: float = cam_proj.get_z_near()
	var p_from: Vector3 = cam.project_position(screen_pos, znear)
	#var p_to: Vector3 = cam.project_position(screen_pos, zfar)
	var z: float = (p - p_from).dot(ray_normal) # / (p_to - p_from).dot(ray_normal)
	return z


func handle_input(viewport_camera: Camera3D, evt: InputEvent) -> bool:
	return false


func draw_overlay(overlay: Control, camera: Camera3D) -> void:
	pass
