@tool
extends EditorPlugin

var dock : Control
var button : Button


func _enter_tree() -> void:
	dock = load("res://addons/gridmap-plus/dock/Dock.tscn").instantiate()
	#dock.undo_manager = get_undo_redo()
	button = add_control_to_bottom_panel(dock, "GridMap+")
	button.visible = false


func _exit_tree() -> void:
	remove_control_from_bottom_panel(dock)
	dock.queue_free()


func _handles(object) -> bool:
	return object is GridMap


func _make_visible(visible) -> void:
	button.visible = visible


func _edit(object) -> void:
	if object is GridMap:
		dock.grid_map = object
