@tool
extends Control

@onready var build_button: Button = $VBox/Toolbar/BuildButton
@onready var alignment_mode: OptionButton = $VBox/Panel/FlowContainer/AlignmentMode
@onready var hotbar_mode: OptionButton = $VBox/Panel/FlowContainer/HotbarMode

var grid_map : GridMap = null

var _selected : int = -1
var _mesh_palette : ItemList

func _ready() -> void:
	var grid_map_editor = EditorInterface.get_base_control().find_children("*", "GridMapEditor", true, false)
	if grid_map_editor.size() != 1:
		return
	
	_mesh_palette = grid_map_editor[0].get_children()[-1]
	_mesh_palette.item_selected.connect(_on_palette_item_selected)


func _on_build_button_pressed() -> void:
	build_button.disabled = true
	
	# The build window exists only as a script
	# This is because, if it were a scene, it would fail to call its process function
	# if the scene were open in the editor, generating a huge amount of error spam.
	# However, it specifically needs to be run in the editor, so the best way to
	# approach this is to manually build the scene when the editor is opened.
	var window = Window.new()
	window.set_script(load("res://addons/gridmap-plus/dock/Build.gd"))
	window.set_grid_map(grid_map)
	window.size = get_window().size - 100 * Vector2i.ONE
	window.apply_changes.connect(func():
		window.write_changes(grid_map)
		EditorInterface.mark_scene_as_unsaved()
	)
	EditorInterface.popup_dialog_centered(window)
	
	await window.visibility_changed
	build_button.disabled = false


func _on_palette_item_selected(item: int) -> void:
	# Prevent access from dock.tscn
	if !grid_map:
		return
	
	_selected = _mesh_palette.get_item_metadata(item)
	var placement = GridMapPlus.get_placement_mode(grid_map.mesh_library, _selected)
	alignment_mode.selected = placement
	
	var hotbar = GridMapPlus.get_hotbar(grid_map.mesh_library, _selected)
	match hotbar:
		-1: hotbar_mode.selected = 0
		0: hotbar_mode.selected = 10
		_: hotbar_mode.selected = hotbar


func _on_alignment_mode_item_selected(index: int) -> void:
	GridMapPlus.set_placement_mode(grid_map.mesh_library, _selected, index)
	grid_map.mesh_library.emit_changed()


func _on_hotbar_mode_item_selected(index: int) -> void:
	var hotbar: int
	match index:
		0: hotbar = -1
		10: hotbar = 0
		_: hotbar = index
	GridMapPlus.set_hotbar(grid_map.mesh_library, _selected, hotbar)
