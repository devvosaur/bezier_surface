@tool
class_name CPScaleTool extends CPTransformTool

const TOOL_NAME: StringName = &"ScaleTool"
const UNDO_REDO_ACTION_NAME: String = "SCALE CONTROL POINT(s)"

func get_name() -> StringName:
	return TOOL_NAME


func get_undo_redo_action_name() -> String:
	return UNDO_REDO_ACTION_NAME


func _recalculate_dir_amount(camera: Camera3D, screen_pos: Vector2, constraint: TransformConstraint) -> void:
	super._recalculate_dir_amount(camera, screen_pos, constraint)
	if constraint == TransformConstraint.NONE:
		if !is_zero_approx(amount) && !dir.is_zero_approx():
			var a: int = dir.abs().max_axis_index()
			if dir[a] < 0.:
				amount = -amount
			dir = Vector3.ONE.normalized()


func _update() -> void:
	var scale: Vector3 = dir * amount
	for i: int in control_points.size():
		var v: Vector4 = src_data[i]
		var pt: Vector3 = Vector3(v.x, v.y, v.z)
		var offset: Vector3 = pt - pivot
		offset *= (Vector3.ONE + scale * v.w)
		_set_cp_value(cur_grid, control_points[i], pivot + offset)
	
	cur_grid.update_gizmos()
