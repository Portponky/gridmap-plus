@tool
extends Control

@onready var build_button: Button = $BuildButton
var grid_map : GridMap = null


func _on_build_button_pressed() -> void:
	build_button.disabled = true
	
	var window = Window.new()
	window.set_script(load("res://addons/gridmap-plus/dock/Build.gd"))
	window.set_grid_map(grid_map)
	window.size = get_window().size - 100 * Vector2i.ONE
	EditorInterface.popup_dialog_centered(window)
	
	await window.visibility_changed
	window.write_changes(grid_map)
	EditorInterface.mark_scene_as_unsaved()
	
	build_button.disabled = false
