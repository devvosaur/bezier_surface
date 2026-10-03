@tool
class_name BezierGrid3D extends Node3D

@export var surface: BezierSurface = null

func _init() -> void:
	surface = BezierSurface.new()
	surface.init_grid(1, 1, 1.)
	set_notify_local_transform(true)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			var axis: int = -1
			var best: float = 0
			for i: int in 3:
				var score: float = abs(scale[i])
				if score >= best:
					best = score
					axis = i
			# temporarily disable notifications to avoid infinite recursion...
			set_notify_local_transform(false)
			scale = Vector3.ONE * scale[axis]
			set_notify_local_transform(true)
	
