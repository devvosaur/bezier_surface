@tool
class_name BezierGrid3DGizmoPlugin extends EditorNode3DGizmoPlugin

const CONTROL_POINT_HANDLE_MASK: int = 1 << 30
const EXTRUDE_HANDLE_MASK: int = 1 << 29

const GIZMO_NAME: String = "Bezier Grid Gizmo"
const HANDLE_MATERIAL_NAME: String = "handle_mat"
const LINE_MAT_NAME: String = "line_mat"
const EXTRUDE_MAT_NAME: String = "extrude_mat"
const MAX_PATCH_SAMPLE_STEP: int = 16
const PROP_EDIT_RADIUS_STEP: float = 2e-1


enum ExtrusionType
{
	ABOVE, BELOW, LEFT, RIGHT
}

var use_proportional_editing: bool = false
@export_range(1e-3, 100, 1e-3, "or_greater") var prop_editing_radius: float = 2.
var extrusion_data: Array[ExtrusionType] = []


var selection: BGCPSelection = null
var edit_set: BGEditSet = null
var tools: Array[BezierGrid3DGizmoTool] = []
var active_tool: BezierGrid3DGizmoTool = null

func _init() -> void:
	create_handle_material(HANDLE_MATERIAL_NAME)
	create_material(LINE_MAT_NAME, Color.WHITE, false, false, true)
	create_handle_material(EXTRUDE_MAT_NAME, false, preload("res://addons/bezier_surface/icons/add.svg"))
	
	# create objects
	selection = BGCPSelection.new()
	edit_set = BGEditSet.new()
	tools.push_back(CPMoveTool.new())
	tools.push_back(CPScaleTool.new())
	tools.push_back(CPRotateTool.new())
	# active tool is null at the beginning
	active_tool = null


func _set_active_tool(tool_name: StringName) -> void:
	if active_tool:
		if active_tool.get_name() == tool_name:
			# nothing to do
			return
		active_tool.revert_pending_changes()
		active_tool.clear()
		active_tool = null
		
	for tool: BezierGrid3DGizmoTool in tools:
		if tool.get_name() == tool_name:
			active_tool = tool
			# rebuild edit_set before activating: this ensures that the edit_set is always fresh
			edit_set.grid = selection.grid
			edit_set.build_from(_eval_for_edit_set)
			active_tool.setup(selection, edit_set)
			return
	
	push_error("tool not found - %s" % tool_name)


func _get_gizmo_name() -> String:
	return GIZMO_NAME
	

func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is BezierGrid3D


func _get_handle_name(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> String:
	var hname: String = "" 
	if _is_control_point_handle(handle_id):
		var surf: BezierSurface = _get_grid(gizmo).surface
		var idx: int = _cp_from_handle(handle_id)
		if surf && surf.control_points.size() > idx:
			hname = "Control Point #%d" % idx
	if _is_extrusion_handle(handle_id):
		hname = "Extrusion Handle #%d" % (handle_id & (~EXTRUDE_HANDLE_MASK))
	return hname


func _cp_from_handle(handle_id: int) -> int:
	if !_is_control_point_handle(handle_id):
		return -1
	return handle_id & (~CONTROL_POINT_HANDLE_MASK)

func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> Variant:
	if _is_control_point_handle(handle_id):
		var surf: BezierSurface = _get_grid(gizmo).surface
		var idx: int = _cp_from_handle(handle_id)
		if surf && surf.control_points.size() > idx:
			return surf.control_points[idx]
	if _is_extrusion_handle(handle_id):
		var t: ExtrusionType = _get_extrusion_type(handle_id)
		return ExtrusionType.find_key(t)
	return null

func _can_be_hidden() -> bool:
	return true


func _estimate_patch_sample_step(control_point_count: int) -> int:
	const THRESHOLDS: PackedInt32Array = [
		1 << 8,
		1 << 9,
		1 << 10,
		1 << 11,
		1 << 12
	]
	var i: int = 0
	var n: int = THRESHOLDS.size()
	while i < n && THRESHOLDS[i] < control_point_count:
		i += 1
	
	if i == n:
		return 2
	
	var step: int = 0
	@warning_ignore_start("integer_division")
	step = min(1 + (n - i) * MAX_PATCH_SAMPLE_STEP / n, MAX_PATCH_SAMPLE_STEP)
	@warning_ignore_restore("integer_division")
	return step


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	
	var grid: BezierGrid3D = gizmo.get_node_3d() as BezierGrid3D
	if grid != selection.grid:
		selection.unselect_all(true)
	
	if !grid || !grid.surface || grid.surface.is_empty():
		return 
	
	var ids: PackedInt32Array = []
	for i: int in grid.surface.control_points.size():
		ids.push_back(i | CONTROL_POINT_HANDLE_MASK)
	
	gizmo.add_handles(grid.surface.control_points, get_material(HANDLE_MATERIAL_NAME, gizmo), ids)
	
	var lines: PackedVector3Array = []
	var cp_cols: int = grid.surface.get_num_cp_cols()
	var cp_rows: int = grid.surface.get_num_cp_rows()

	for i: int in cp_rows:
		for j: int in cp_cols:
			var p0: Vector3 = grid.surface.get_control_point(i, j)
			if j < cp_cols - 1:
				lines.push_back(p0)
				lines.push_back(grid.surface.get_control_point(i, j + 1))
			if i < cp_rows - 1:
				lines.push_back(p0)
				lines.push_back(grid.surface.get_control_point(i+1, j))
	
	var line_mat: Material = get_material(LINE_MAT_NAME, gizmo)
	gizmo.add_lines(lines, line_mat)
	gizmo.add_collision_segments(lines)
	lines.clear()
	
	var patch_sample_step: int = _estimate_patch_sample_step(grid.surface.control_points.size())
	var inv_sample_step: float = 1. / (patch_sample_step - 1)
	for i: int in grid.surface.patch_rows:
		for j: int in grid.surface.patch_cols:
			
			for a: int in patch_sample_step:
				var u_cur: float = a * inv_sample_step
				var u_next: float = (a + 1) * inv_sample_step
				for b: int in patch_sample_step:
					var v_cur: float = b * inv_sample_step
					var v_next: float = (b + 1) * inv_sample_step
					
					var p: Vector3 = grid.surface.evaluate_pos(i, j, u_cur, v_cur)
					if b < patch_sample_step - 1:
						lines.push_back(p)
						lines.push_back(grid.surface.evaluate_pos(i, j, u_cur, v_next))
					if a < patch_sample_step - 1:
						lines.push_back(p)
						lines.push_back(grid.surface.evaluate_pos(i, j, u_next, v_cur))
	
	gizmo.add_lines(lines, line_mat, false, Color.BLACK)
	
	# extrusion handles
	var extrusion_pos: PackedVector3Array = [
		_estimate_center_along_row(grid.surface, 0, 0, cp_cols), # above
		_estimate_center_along_row(grid.surface, cp_rows - 1, 0, cp_cols), # below
		_estimate_center_along_col(grid.surface, 0, cp_rows, 0), # left
		_estimate_center_along_col(grid.surface, 0, cp_rows, cp_cols - 1) # right
	]
	var up2down_dir: Vector3 = (extrusion_pos[1] - extrusion_pos[0]).normalized()
	var left2right_dir: Vector3 = (extrusion_pos[3] - extrusion_pos[2]).normalized()
	extrusion_pos[0] -= up2down_dir
	extrusion_pos[1] += up2down_dir
	extrusion_pos[2] -= left2right_dir
	extrusion_pos[3] += left2right_dir
	ids.clear()
	var extrude_mat: Material = get_material(EXTRUDE_MAT_NAME, gizmo)
	for i: int in 4:
		ids.push_back(i | EXTRUDE_HANDLE_MASK)
		
	extrusion_data = [
		ExtrusionType.ABOVE, ExtrusionType.BELOW, ExtrusionType.LEFT, ExtrusionType.RIGHT
	]
	gizmo.add_handles(extrusion_pos, extrude_mat, ids)


func _estimate_center_along_row(surf: BezierSurface, row: int, col_start: int, col_end: int) -> Vector3:
	# above
	var p: Vector3 = Vector3.ZERO
	var col_count: int = col_end - col_start
	for i: int in col_count:
		p += surf.get_control_point(row, i + col_start)
	p /= col_count
	return p


func _estimate_center_along_col(surf: BezierSurface, row_start: int, row_end: int, col: int) -> Vector3:
	var row_count: int = row_end - row_start
	var p: Vector3 = Vector3.ZERO
	for i: int in row_count:
		p += surf.get_control_point(i + row_start, col)
	p /= row_count
	return p


func _is_control_point_handle(handle_id: int) -> bool:
	return handle_id & CONTROL_POINT_HANDLE_MASK


func _is_extrusion_handle(handle_id: int) -> bool:
	return handle_id & EXTRUDE_HANDLE_MASK


func _get_extrusion_type(handle_id: int) -> ExtrusionType:
	return extrusion_data[handle_id & (~EXTRUDE_HANDLE_MASK)]


func _eval_for_edit_set(grid: BezierGrid3D, cp: int) -> float:
	if selection.grid != grid:
		return -1.
	
	if selection.is_selected(cp):
		return 1.
	
	if !use_proportional_editing:
		return -1.

	var rsq: float = prop_editing_radius * prop_editing_radius
	var inv_r: float = 1. / prop_editing_radius
	var test_p: Vector3 = grid.surface.control_points[cp]
	for i: int in selection.selected_control_points:
		var src_p: Vector3 = grid.surface.control_points[i]
		var dist_sq: float = test_p.distance_squared_to(src_p)
		if dist_sq <= rsq:
			var t: float = sqrt(dist_sq) * inv_r # how far are we from the center? 
			# weight falloff: 1. - (3t^2 - 2t^3) = 1. - smoothstep(0, 1,t)
			var weight: float = 1. - smoothstep(0., 1.,  t)
			return weight
	
	# too far from all selected control points, ignore
	return -1.


func _begin_handle_action(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> void:
	# a bit hacky. This is here to detect selection "for free" 
	
	if _is_control_point_handle(handle_id):
		var cp: int = _cp_from_handle(handle_id)
		if Input.is_key_pressed(KEY_SHIFT):
			if selection.is_selected(cp):
				selection.unselect_control_point(cp)
			else:
				selection.select_control_point(cp)
		else:
			selection.unselect_all()
			selection.grid = _get_grid(gizmo)
			selection.select_control_point(cp)
	else:
		selection.unselect_all()


func _set_cp_value(grid: BezierGrid3D, cp: int, p: Vector3) -> void:
	grid.surface.control_points[cp] = p
	grid.update_gizmos()


func _get_grid(gizmo: EditorNode3DGizmo) -> BezierGrid3D:
	return gizmo.get_node_3d() as BezierGrid3D


func _is_handle_highlighted(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool)  -> bool:
	if _is_control_point_handle(handle_id):
		var cp: int = _cp_from_handle(handle_id)
		return selection.is_selected(cp)
	return false


func _can_commit_handle_on_click() -> bool:
	return true

func _remove_patch_row_col(grid: BezierGrid3D, prepend_rows: int, append_rows: int, prepend_cols: int, append_cols: int) -> void:
	if prepend_rows > 0:
		grid.surface.erase_patch_rows(0, prepend_rows)
	if append_rows > 0:
		grid.surface.erase_patch_rows(grid.surface.patch_rows - append_rows, append_rows)
	if prepend_cols > 0:
		grid.surface.erase_patch_cols(0, prepend_cols)
	if append_cols > 0:
		grid.surface.erase_patch_cols(grid.surface.patch_cols - append_cols, append_cols)
	grid.update_gizmos()


func _extrude_grid(grid: BezierGrid3D, prepend_rows: int, append_rows: int, prepend_cols: int, append_cols: int, amount: float = 1.) -> void:
	grid.surface.extrude(prepend_rows, append_rows, prepend_cols, append_cols, amount)
	grid.update_gizmos()


func _commit_extrude(grid: BezierGrid3D, extrusion_type: ExtrusionType, cancel: bool) -> void:
	var prepend_rows: int = 0
	var append_rows: int = 0
	var prepend_cols: int = 0
	var append_cols: int = 0
	
	match extrusion_type:
		ExtrusionType.ABOVE:
			prepend_rows += 1
		ExtrusionType.BELOW:
			append_rows += 1
		ExtrusionType.LEFT:
			prepend_cols += 1
		ExtrusionType.RIGHT:
			append_cols += 1
	
	if cancel:
		_remove_patch_row_col(grid, prepend_rows, append_rows, prepend_cols, append_cols)
	else:
		var urm: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
		urm.create_action("EXTRUDE %s" % ExtrusionType.find_key(extrusion_type))
		urm.add_undo_method(self, &"_remove_patch_row_col", grid, prepend_rows, append_rows, prepend_cols, append_cols)
		urm.add_do_method(self, &"_extrude_grid", grid, prepend_rows, append_rows, prepend_cols, append_cols, 1.)
		urm.commit_action(true)


func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, restore: Variant, cancel: bool) -> void:
	
	var grid: BezierGrid3D = _get_grid(gizmo)
	if !grid:
		push_error("no grid!")
		return
	
	if _is_extrusion_handle(handle_id):
		var extrusion_type: ExtrusionType = _get_extrusion_type(handle_id)
		_commit_extrude(grid, extrusion_type, cancel)


func draw_overlay(overlay: Control) -> void:
	if active_tool:
		# a bit hacky way to get the camera. This gets the camera used by the first viewport, 
		# which is generally good enough, unless editing with split viewports
		var camera: Camera3D = EditorInterface.get_editor_viewport_3d().get_camera_3d()
		active_tool.draw_overlay(overlay, camera)
		if use_proportional_editing:
			# estimate the screen space circle center
			var pivot: Vector3 = active_tool.pivot
			var screen_pos: Vector2 = camera.unproject_position(pivot)
			# estimate the screen space radius: get a sphere point that intersects the plane and then go back to screen coordinates
			var ray_n: Vector3 = camera.project_ray_normal(screen_pos)
			var plane: Plane = Plane(ray_n, pivot)
			var dir: Vector3 = Vector3.RIGHT # guess a vector
			if dir.dot(ray_n) < 1e-3: # if parallel, use a vector that is perpendicular to the one we just used
				dir = Vector3.UP
			dir = (plane.project(pivot + dir) - pivot).normalized()
			var p: Vector3 = pivot + dir * prop_editing_radius
			var target: Vector2 = camera.unproject_position(p)
			var screen_radius: float = screen_pos.distance_to(target)
			# draw
			overlay.draw_circle(screen_pos, screen_radius, Color.DIM_GRAY, false, 3.)


# returns true if handled and false if the input was not handled and must be passed to others
func handle_input(viewport_camera: Camera3D, evt: InputEvent) -> bool:
	# if there is no active tool, choose the right tool
	var k_evt: InputEventKey = evt as InputEventKey
	var mb_evt: InputEventMouseButton = evt as InputEventMouseButton
	if !active_tool:
		if !selection.is_empty():
			if k_evt && k_evt.pressed:
				match k_evt.keycode:
					KEY_G:
						_set_active_tool(CPMoveTool.TOOL_NAME)
						return true
					KEY_S:
						_set_active_tool(CPScaleTool.TOOL_NAME)
						return true
					KEY_R:
						_set_active_tool(CPRotateTool.TOOL_NAME)
					KEY_ESCAPE:
						# if there is a selection, clear it
						if !selection.is_empty():
							selection.unselect_all()
							selection.grid.update_gizmos()
							return true
		# no other option if there is no active tool
		return false
	
	# here we have an active tool
	if k_evt && k_evt.pressed && k_evt.keycode == KEY_ESCAPE:
		active_tool.cancel()
		active_tool = null
		return true
	
	if mb_evt:
		# first detect prop.editing changes
		if use_proportional_editing:
			var post_radius_changed_cb: Callable = func() -> void:
				# force restore initial state - edit set would have wrong data otherwise
				active_tool.revert_pending_changes()
				edit_set.build_from(_eval_for_edit_set)
				# notify changes
				active_tool.notify_edit_set_changed(edit_set)

			var handled: bool = false
			match mb_evt.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					if mb_evt.pressed:
						prop_editing_radius += PROP_EDIT_RADIUS_STEP
						post_radius_changed_cb.call()
					# TODO: rebuild edit move data. This requires keeping track of delta, restoring all surface data to the origin
					# recomputing the affected control points and their falloff weights and re-applying the delta
					handled = true
				MOUSE_BUTTON_WHEEL_DOWN:
					if mb_evt.pressed:
						prop_editing_radius = max(prop_editing_radius -PROP_EDIT_RADIUS_STEP, 1e-3) # force minimum to prop editing. This avoids non-negative or zero values
						post_radius_changed_cb.call()
					handled = true
			if handled: 
				return true
		
		if mb_evt.pressed:
			match mb_evt.button_index:
				MOUSE_BUTTON_LEFT:
					active_tool.commit()
					active_tool = null
					return true
				MOUSE_BUTTON_RIGHT:
					active_tool.cancel()
					active_tool = null
					return true
	
	# if the gizmo has not consumed the input, forward it to the active tool
	return active_tool.handle_input(viewport_camera, evt)
