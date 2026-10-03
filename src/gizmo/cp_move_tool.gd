@tool 
class_name CPMoveTool extends CPTransformTool

const TOOL_NAME: StringName = &"MoveTool"
const UNDO_REDO_ACTION_NAME: String = "MOVE CONTROL POINT(S)"


func get_name() -> StringName:
	return TOOL_NAME


func get_undo_redo_action_name() -> String:
	return UNDO_REDO_ACTION_NAME


func _update() -> void:
	var delta: Vector3 = dir * amount
	for i: int in control_points.size():
		var v: Vector4 = src_data[i]
		var pt: Vector3 = Vector3(v.x, v.y, v.z)
		_set_cp_value(cur_grid, control_points[i], pt + v.w * delta)
	
	cur_grid.update_gizmos()
