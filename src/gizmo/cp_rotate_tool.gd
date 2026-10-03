@tool
class_name CPRotateTool extends CPTransformTool

const TOOL_NAME: StringName = &"RotateTool"
const UNDO_REDO_ACTION_NAME: String = "RORATE CONTROL POINT(S)"

func get_name() -> StringName:
	return TOOL_NAME

func get_undo_redo_action_name() -> String: 
	return UNDO_REDO_ACTION_NAME


func _recalculate_dir_amount(camera: Camera3D, screen_pos: Vector2, constraint: TransformConstraint) -> void:
	# remap -> restricting motion on a plane is like rotating around its normal
	match constraint:
		TransformConstraint.PLANE_XY:
			constraint = TransformConstraint.AXIS_Z
		TransformConstraint.PLANE_YZ:
			constraint = TransformConstraint.AXIS_X
		TransformConstraint.PLANE_XZ:
			constraint = TransformConstraint.AXIS_Y
	
	super._recalculate_dir_amount(camera, screen_pos, constraint)
	if dir.is_zero_approx():
		dir = camera.global_basis.z


func _update() -> void:
	for i: int in control_points.size():
		var v: Vector4 = src_data[i]
		var p0: Vector3 = Vector3(v.x, v.y, v.z)
		# local offset w.r.t. pivot
		var dp: Vector3 = p0 - pivot
		var basis: Basis = Basis(dir, amount * v.w)
		# rotate local offset around dir by amount * weight and then add it to pivot
		_set_cp_value(cur_grid, control_points[i], pivot + basis * dp)
	
	cur_grid.update_gizmos()
