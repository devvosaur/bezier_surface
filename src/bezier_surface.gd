@tool
class_name BezierSurface extends Resource
## bicubic bezier surface class

## control points are stored as [row0: col0, col1, ...][row1: col0, col1, ...]...
## this allows us to reduce memory usage AND to ensure that patches are automatically C0
## starting row: patch row * 3, starting col: patch col * 3
@export_storage var control_points: PackedVector3Array = []
@export_storage var patch_rows: int = 0 ## number of patches along v
@export_storage var patch_cols: int = 0 ## number of patches along u


signal control_point_changed(row: int, col: int)

static func bernstein(t: float) -> Vector4: 
	var t2: float = t * t;
	var s: = 1. - t;
	var s2: = s * s;
	return Vector4(
		s * s2,
		3. * t * s2,
		3. * t2 * s,
		t * t2
	)

## bernstein derivative
static func d_bernstein(t: float) -> Vector4:
	var t2: float = t * t;
	var s: float = 1. - t;
	var s2: float = s * s;
	return Vector4(
		-3. * s2,
		3. * s2 - 6. * t * s,
		6. * t * s - 3. * t2,
		3. * t2
	)

func evaluate_pos(row: int, col: int, u: float, v: float) -> Vector3:
	var bu: Vector4 = bernstein(u)
	var bv: Vector4 = bernstein(v)
	
	var p: Vector3 = Vector3.ZERO
	
	var cp_cols: int = get_num_cp_cols()
	var cp_start: Vector2i = _patch_to_cp_offsets(row, col)
	for i: int in 4:
		# fetch the current row (including the start offset row) at the current col offset
		var offset: int = cp_cols * (cp_start.x + i) + cp_start.y
		for j: int in 4:
			var cp: Vector3 = control_points[offset + j]
			# v row, u col. i row, j col
			p += bu[j] * bv[i] * cp
	
	return p



func _patch_to_cp_offsets(patch_row: int, patch_col: int) -> Vector2i:
	return Vector2i(patch_row * 3, patch_col * 3)



func get_num_cp_rows() -> int:
	if patch_rows == 0:
		return 0
	return patch_rows * 3 + 1
	


func get_num_cp_cols() -> int:
	if patch_cols == 0:
		return 0
	return patch_cols * 3 + 1


func get_control_point(ci: int, cj: int) -> Vector3:
	return control_points[get_num_cp_cols() * ci + cj]


func eval_tg(row: int, col: int, u: float, v: float) -> Vector3:
	var dbu: Vector4 = d_bernstein(u)
	var bv: Vector4 = bernstein(v)
	
	var tg: Vector3 = Vector3.ZERO
	
	var cp_cols: int = get_num_cp_cols()
	var cp_start: Vector2i = _patch_to_cp_offsets(row, col)
	for i: int in 4:
		# fetch the current row (including the start offset row) at the current col offset
		var offset: int = cp_cols * (cp_start.x + i) + cp_start.y
		for j: int in 4:
			var p: Vector3 = control_points[offset + j]
			# v row, u col. i row, j col
			tg += dbu[j] * bv[i] * p
	return tg


func eval_side(row: int, col: int, u: float, v: float) -> Vector3:
	var bu: Vector4 = bernstein(u)
	var dbv: Vector4 = d_bernstein(v)
	
	var side: Vector3 = Vector3.ZERO
	
	var cp_cols: int = get_num_cp_cols()
	var cp_start: Vector2i = _patch_to_cp_offsets(row, col)
	for i: int in 4:
		# fetch the current row (including the start offset row) at the current col offset
		var offset: int = cp_cols * (cp_start.x + i) + cp_start.y
		for j: int in 4:
			var p: Vector3 = control_points[offset + j]
			# v row, u col. i row, j col
			side += bu[j] * dbv[i] * p
	return side


func set_control_point(row: int, col: int, p: Vector3) -> void:
	control_points[row * get_num_cp_cols() + col] = p
	control_point_changed.emit(row, col)



func init_grid(i_patch_rows: int, i_patch_cols: int, delta: float) -> void:
	patch_rows = i_patch_rows
	patch_cols = i_patch_cols
	var cp_rows: int = get_num_cp_rows()
	var cp_cols: int = get_num_cp_cols()
	control_points.resize(cp_rows * cp_cols)
	for i: int in cp_rows:
		var offset: int = i * cp_cols
		var u: float = delta * i
		for j: int in cp_cols:
			control_points[offset + j] = Vector3(u, 0., delta * j)
	

func is_empty() -> bool:
	return control_points.is_empty()


# extrude this surface prepending and appending the desired amount of patch rows and/or cols
func extrude(prepend_patch_rows: int, append_patch_rows: int, prepend_patch_cols: int, append_patch_cols: int, delta: float) -> void:
	if patch_cols == 0 || patch_rows == 0:
		push_error("cannot extrude from empty grid")
		return
	
	if prepend_patch_cols < 0 || prepend_patch_rows < 0 || append_patch_cols < 0 || append_patch_rows < 0:
		push_error("cannot extrude with negative row/col deltas")
		return
	
	# compute the new number of patches along rows/cols
	var n: int = prepend_patch_rows + patch_rows + append_patch_rows
	var m: int = prepend_patch_cols + patch_cols + append_patch_cols
	if n == 0 || m == 0:
		push_error("invalid size: cannot have 0 patches along row/col")
		return
	
	# number of cps in the (new) shared grid
	var cp_n: int = n * 3 + 1
	var cp_m: int = m * 3 + 1
	var arr: PackedVector3Array = []
	arr.resize(cp_n * cp_m)
	
	# copy cps
	var dst_cp_col_offset: int = prepend_patch_cols * 3
	var dst_cp_row_offset: int = prepend_patch_rows * 3
	for i: int in get_num_cp_rows():
		var dst_offset: int = (dst_cp_row_offset + i) * cp_m + dst_cp_col_offset
		for j: int in get_num_cp_cols():
			arr[dst_offset + j] = get_control_point(i, j)
	
	# store refs to compute extrusion data
	# these are the first indices in the corresponding zones
	var src_count: Vector2i = Vector2i(get_num_cp_rows(), get_num_cp_cols())
	var top_left: Vector2i = Vector2i(prepend_patch_rows * 3, prepend_patch_cols * 3)
	var bottom_left: Vector2i = top_left + Vector2i(src_count.x, 0)
	var top_right: Vector2i = top_left + Vector2i(0, src_count.y)
	var bottom_right: Vector2i = bottom_left + Vector2i(0, src_count.y)
	
	# replace data
	patch_rows = n
	patch_cols = m
	control_points = arr
	
	# produce extrusion data in a few passes
	if prepend_patch_rows > 0:
		# prepend rows, from start row
		for j: int in src_count.y:
			var col: int = j + top_left.y
			var row: int = top_left.x
			var src: Vector3 = get_control_point(row, col)
			var dir: Vector3 = (src - get_control_point(row + 1, col)).normalized()
			for i: int in top_left.x:
				var distance: int = top_left.x - i
				set_control_point(i, col, src + dir * distance * delta)
	
	if append_patch_rows > 0:
		# fill append rows, from last known patch row
		var count: int = append_patch_rows * 3
		for j: int in src_count.y:
			var col: int = j + bottom_left.y
			var row: int = bottom_left.x - 1
			var src: Vector3 = get_control_point(row, col)
			var dir: Vector3 = (src - get_control_point(row - 1, col)).normalized()
			# updating only the new elements (i.e. exclude row shared row)
			for i: int in count:
				var distance: int = i + 1
				set_control_point(i + row + 1, col, src + dir * distance * delta)
	
	if prepend_patch_cols > 0:
		# fill prepend columns
		for i: int in cp_n:
			var col: int = top_left.y
			var src: Vector3 = get_control_point(i, col)
			var dir: Vector3 = (src - get_control_point(i, col + 1)).normalized()
			for j: int in col:
				var distance: int = col - j
				set_control_point(i, j, src + dir * distance * delta)
	
	if append_patch_cols > 0:
		# fill append columns
		var count: int = append_patch_cols * 3
		for i: int in cp_n:
			# top_right.y is the first added control point column, so top_right.y - 1 is the shared control point
			var col: int = top_right.y - 1
			var src: Vector3 = get_control_point(i, col)
			var dir: Vector3 = (src - get_control_point(i, col - 1)).normalized()
			for j: int in count:
				var distance: int = j + 1
				set_control_point(i, j + 1 + col, src + dir * distance * delta)


func erase_patch_rows(patch_offset: int, count: int) -> void:
	if count <= 0:
		push_error("meaningless input: count must be positive. It was %d" % count)
		return
	if patch_offset >= patch_rows || patch_offset < 0:
		push_error("patch row offset %d is out of bounds. Row count is %d" % [patch_offset, patch_rows])
		return
	if patch_offset + count > patch_rows:
		push_error("deletion range is out of bounds. Requested [%d, %d). Upper bound is %d" %[patch_offset, patch_offset + count, patch_rows])
		return
	
	if patch_offset + count == patch_rows:
		patch_rows = patch_rows - count
		if patch_rows == 0:
			patch_cols = 0
			control_points.clear()
		else:
			control_points.resize(get_num_cp_cols() * get_num_cp_rows())
		return
	
	var cp_cols: int = get_num_cp_cols()
	var cp_src_offset: int = (patch_offset + count) * 3
	var cp_dst_offset: int = patch_offset * 3
	var cp_row_count: int = get_num_cp_rows() - cp_src_offset
	# relocate rows from patch_offset+ count into patch_offset and following rows
	for i: int in cp_row_count:
		var src_idx_offset: int = (cp_src_offset + i) * cp_cols
		var dst_idx_offset: int = (cp_dst_offset + i) * cp_cols
		for j: int in cp_cols:
			control_points[dst_idx_offset + j] = control_points[src_idx_offset + j]
	
	# update patch row count and resize
	patch_rows -= count
	control_points.resize(get_num_cp_cols() * get_num_cp_rows())



func erase_patch_cols(patch_offset: int, count: int) -> void:
	if count <= 0:
		push_error("meaningless input: count must be positive. It was %d" % count)
		return
	if patch_offset >= patch_cols:
		push_error("patch col offset %d is out of bounds. Col count is %d" % [patch_offset, patch_cols])
		return
	if patch_offset + count > patch_cols:
		push_error("deletion range is out of bounds. Requested [%d, %d). Upper bound is %d" %[patch_offset, patch_offset + count, patch_cols])
		return
	
	if count == patch_cols:
		patch_cols = 0
		patch_rows = 0
		control_points.clear()
		return
	
	var cp_rows: int = get_num_cp_rows()
	var col_skip_start: int = patch_offset * 3 + 1 if patch_offset > 0 else 0 # if this is the first patch, start from the first index. Otherwise start from the first non shared index
	var col_skip_end: int = col_skip_start + count * 3
	var cp_cols: int = get_num_cp_cols()
	var after_skip_count: int = cp_cols - col_skip_end
	
	var dst_offset: int = 0
	for i: int in cp_rows:
		# copy columns before skip zone
		var src_offset: int = cp_cols * i
		for j: int in col_skip_start:
			control_points[dst_offset] = control_points[src_offset + j]
			dst_offset += 1
		
		src_offset += col_skip_end
		for j: int in after_skip_count:
			control_points[dst_offset] = control_points[src_offset + j]
			dst_offset += 1
		
	# update patch row count and resize
	patch_cols -= count
	control_points.resize(get_num_cp_cols() * get_num_cp_rows())
