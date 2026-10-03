@tool
class_name BezierSurfaceEditorPlugin extends EditorPlugin


const PLUGIN_NAME: String = "Bezier Surfaces"
var bezier_grid_gizmo_plugin: BezierGrid3DGizmoPlugin = null
var prop_edit_btn: Button = null
var hbox_toolbar: HBoxContainer = null


func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _get_plugin_name() -> String:
	return PLUGIN_NAME 

func _handles(object: Object) -> bool:
	return object is BezierGrid3D



func _edit(object: Object) -> void:
	if object:
		hbox_toolbar.show()
	else:
		hbox_toolbar.hide()


func _enter_tree() -> void:
	if !bezier_grid_gizmo_plugin:
		bezier_grid_gizmo_plugin = BezierGrid3DGizmoPlugin.new()
	
	add_node_3d_gizmo_plugin(bezier_grid_gizmo_plugin)
	_setup_toolbar()


func _exit_tree() -> void:
	if bezier_grid_gizmo_plugin:
		remove_node_3d_gizmo_plugin(bezier_grid_gizmo_plugin)
		bezier_grid_gizmo_plugin = null
	
	_clear_toolbar()

func _forward_3d_draw_over_viewport(overlay: Control) -> void:
	if bezier_grid_gizmo_plugin:
		bezier_grid_gizmo_plugin.draw_overlay(overlay)


func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if bezier_grid_gizmo_plugin:
		var handled: bool = bezier_grid_gizmo_plugin.handle_input(viewport_camera, event)
		if handled:
			update_overlays() # input was handled. Force update overlays
			return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS



func _on_prop_edit_btn_toggled(toggled: bool) -> void:
	if bezier_grid_gizmo_plugin:
		bezier_grid_gizmo_plugin.use_proportional_editing = toggled


func _setup_toolbar() -> void:
	if !hbox_toolbar:
		hbox_toolbar = HBoxContainer.new()
		prop_edit_btn = Button.new()
		hbox_toolbar.add_child(prop_edit_btn)
		prop_edit_btn.icon = preload("res://addons/bezier_surface/icons/prop_editing.svg")
		prop_edit_btn.tooltip_text = "toggle proportional editing"
		prop_edit_btn.toggle_mode = true
		prop_edit_btn.toggled.connect(_on_prop_edit_btn_toggled)
	
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, hbox_toolbar)


func _clear_toolbar() -> void:
	if hbox_toolbar:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, hbox_toolbar)
		hbox_toolbar.queue_free()
		hbox_toolbar = null
	
	prop_edit_btn = null
