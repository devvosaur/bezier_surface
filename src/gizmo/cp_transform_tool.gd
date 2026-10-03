@tool @abstract
class_name CPTransformTool extends BezierGrid3DGizmoTool

enum TransformConstraint
{
	NONE,
	AXIS_X,
	AXIS_Y,
	AXIS_Z,
	PLANE_XY,
	PLANE_YZ,
	PLANE_XZ
}

var transf_constraint: TransformConstraint = TransformConstraint.NONE
var dir: Vector3 = Vector3.ZERO
var amount: float = 0.
var screen_pos_origin: Vector2 = Vector2.ZERO

func setup(selection: BGCPSelection, edit_set: BGEditSet) -> void:
	super.setup(selection, edit_set)
	screen_pos_origin = EditorInterface.get_editor_viewport_3d().get_mouse_position()
	
	
	

# override this to change the calculations for the dir/amount
func _recalculate_dir_amount(camera: Camera3D, screen_pos: Vector2, constraint: TransformConstraint) -> void:
	var delta_sp: Vector2 = screen_pos - screen_pos_origin
	var depth := get_depth(camera, pivot)
	
	var proj: Projection = camera.get_camera_projection()

	if !proj.is_orthogonal():
		# this is to produce meaningful edit amount in world unit
		var vs: Vector2 = camera.get_viewport().size
		var proj_scale: Vector2 = Vector2(
			2. * depth / (proj.x.x * vs.x),
			2. * depth / (proj.y.y * vs.y)
		)
		delta_sp *= proj_scale
	
	var dp := Vector3(
		delta_sp.x,
		-delta_sp.y,
		0.0
	)
	var cam_b: Basis = camera.global_basis
	# to world delta
	var delta: Vector3 = cam_b * dp
	var inv_b: Basis = cur_grid.global_transform.basis.inverse()
	
	if constraint != TransformConstraint.NONE:
		# relative
		delta = inv_b * delta
	match constraint:
		TransformConstraint.AXIS_X:
			delta.y = 0.
			delta.z = 0.
		TransformConstraint.AXIS_Y:
			delta.x = 0.
			delta.z = 0.
		TransformConstraint.AXIS_Z:
			delta.x = 0.
			delta.y = 0.
		TransformConstraint.PLANE_XY:
			delta.z = 0.
		TransformConstraint.PLANE_YZ:
			delta.x = 0.
		TransformConstraint.PLANE_XZ:
			delta.y = 0.
	amount = delta.length() 
	dir = delta.normalized()


func clear() -> void:
	super.clear()
	# reset data
	transf_constraint = TransformConstraint.NONE
	dir = Vector3.ZERO
	amount = 0.


func handle_input(camera: Camera3D, evt: InputEvent) -> bool:
	var handled: bool = false
	var screen_pos: Vector2 = camera.get_viewport().get_mouse_position()
	var new_constraint: TransformConstraint = TransformConstraint.NONE
	var k_evt: InputEventKey = evt as InputEventKey
	
	if k_evt && k_evt.pressed:
		match k_evt.keycode:
			KEY_X:
				new_constraint = TransformConstraint.PLANE_YZ if k_evt.shift_pressed else TransformConstraint.AXIS_X 
				handled = true
			KEY_Y:
				new_constraint = TransformConstraint.PLANE_XZ if k_evt.shift_pressed else TransformConstraint.AXIS_Y 
				handled = true
			KEY_Z:
				new_constraint = TransformConstraint.PLANE_XY if k_evt.shift_pressed else TransformConstraint.AXIS_Z 
				handled = true
		
		if transf_constraint == new_constraint:
			transf_constraint = TransformConstraint.NONE
		else:
			transf_constraint = new_constraint
	
	_recalculate_dir_amount(camera, screen_pos, transf_constraint)
	_update()
	return handled


# draw line that passes through pivot and follows ray_dir (ray_dir is in global space)
func _draw_line(overlay: Control, camera: Camera3D, ray_dir: Vector3, color: Color, width: float = 2.) -> void:
	var gpivot: Vector3 = cur_grid.global_transform * pivot
	ray_dir = ray_dir.normalized()
	var frustum: Array[Plane] = camera.get_frustum()

	var tmin: float = -1e30
	var tmax: float = 1e30
	for plane: Plane in frustum:
		var k: float = plane.normal.dot(ray_dir)
		if is_zero_approx(k):
			# parallel, ignore plane
			continue
		# negate result since distance_to is signed and we want the direction toward the plane from gpivot
		# k is the denominator since we need to invert the rate: if dot is .1, 
		# it means that for every 10 units along ray_dir, we get closed to the plane by 1 unit.
		# Therefore, we need to scale by 1. / k
		var t: float = - plane.distance_to(gpivot) / k
		if k < 0.0:
			tmin = maxf(t, tmin)
		else:
			tmax = minf(t, tmax)
	
	var p0: Vector2 = camera.unproject_position(gpivot + tmin * ray_dir)
	var p1: Vector2 = camera.unproject_position(gpivot + tmax * ray_dir)
	
	overlay.draw_line(p0, p1, color, width, true)


func draw_overlay(overlay: Control, camera: Camera3D) -> void:
	if transf_constraint == TransformConstraint.NONE:
		return
	
	match transf_constraint:
		TransformConstraint.AXIS_X:
			_draw_line(overlay, camera, Vector3.RIGHT, Color.RED)
		TransformConstraint.AXIS_Y:
			_draw_line(overlay, camera, Vector3.UP, Color.GREEN_YELLOW)
		TransformConstraint.AXIS_Z:
			_draw_line(overlay, camera, Vector3.FORWARD, Color.CYAN)
		TransformConstraint.PLANE_XY:
			_draw_line(overlay, camera, Vector3.RIGHT, Color.RED)
			_draw_line(overlay, camera, Vector3.UP, Color.GREEN_YELLOW)
		TransformConstraint.PLANE_YZ:
			_draw_line(overlay, camera, Vector3.UP, Color.GREEN_YELLOW)
			_draw_line(overlay, camera, Vector3.FORWARD, Color.CYAN)
		TransformConstraint.PLANE_XZ:
			_draw_line(overlay, camera, Vector3.RIGHT, Color.RED)
			_draw_line(overlay, camera, Vector3.FORWARD, Color.CYAN)
