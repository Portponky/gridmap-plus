@tool
extends VBoxContainer

@onready var build_button: Button = %BuildButton
@onready var alignment_mode: OptionButton = %AlignmentMode
@onready var hotbar_mode: OptionButton = %HotbarMode

@onready var light_position: LineEdit = %LightPosition
@onready var light_rotation: LineEdit = %LightRotation
@onready var light_energy: HSlider = %LightEnergy
@onready var light_indirect_energy: HSlider = %LightIndirectEnergy
@onready var light_angular_distance: HSlider = %LightAngularDistance

var light_type = "directional"
var directional_light = {}
var omni_light = {}

var window = null

var grid_map : GridMap = null:
	set(x):
		grid_map = x
		%MeshOptions.hide()

var _selected : int = -1
var _mesh_palette : ItemList


func _ready() -> void:
	
	var grid_map_editor = EditorInterface.get_base_control().find_children("*", "GridMapEditor", true, false)
	if grid_map_editor.size() != 1:
		return
	
	_mesh_palette = grid_map_editor[0].get_children()[-1]
	_mesh_palette.item_selected.connect(_on_palette_item_selected)
	
	# These values are used to restore the previous input field value in case of bad user input
	directional_light["last_valid_position_value"] = light_position.text
	directional_light["last_valid_rotation_value"] = light_rotation.text
	omni_light["last_valid_position_value"] = light_position.text
	omni_light["last_valid_rotation_value"] = light_rotation.text
	
	# We initialize the values for each of the light types
	var light_initial_position = parse_vector3(light_position.text)[1]
	var light_initial_rotation = parse_vector3(light_rotation.text)[1]
	
	directional_light["chosen_position"] = light_initial_position
	directional_light["chosen_rotation"] = light_initial_rotation
	directional_light["chosen_energy"] = light_energy.value
	directional_light["chosen_indirect_energy"] = light_indirect_energy.value
	directional_light["chosen_angular_distance"] = light_angular_distance.value
	
	omni_light["chosen_position"] = light_initial_position
	omni_light["chosen_rotation"] = light_initial_rotation
	omni_light["chosen_energy"] = light_energy.value
	omni_light["chosen_indirect_energy"] = light_indirect_energy.value


func _on_build_button_pressed() -> void:
	build_button.disabled = true
	
	# The build window exists only as a script
	# This is because, if it were a scene, it would fail to call its process function
	# if the scene were open in the editor, generating a huge amount of error spam.
	# However, it specifically needs to be run in the editor, so the best way to
	# approach this is to manually build the scene when the editor is opened.
	window = Window.new()
	window.set_script(load("res://addons/gridmap-plus/dock/Build.gd"))
	window.set_grid_map(grid_map)
	window.size = get_window().size - 100 * Vector2i.ONE
	window.apply_changes.connect(func():
		window.write_changes(grid_map)
		EditorInterface.mark_scene_as_unsaved()
	)
	
	window.builder_ready.connect(_on_builder_window_ready)
	
	EditorInterface.popup_dialog_centered(window)
		
	await window.visibility_changed
	build_button.disabled = false


func _on_builder_window_ready() -> void:
	
	_set_builder_light_parameters()
	
	# Disconnect the signal to avoid multiple calls
	window.builder_ready.disconnect(_on_builder_window_ready)


func _set_builder_light_parameters() -> void:
	
	if window == null:
		return
	
		# Set the light parameters after the builder window is ready
	if light_type == "directional":
		window.set_light_parameters(
			"directional",
			directional_light["chosen_position"],
			directional_light["chosen_rotation"],
			directional_light["chosen_energy"],
			directional_light["chosen_indirect_energy"],
			directional_light["chosen_angular_distance"])
	elif light_type == "omni":
		window.set_light_parameters(
			"omni",
			omni_light["chosen_position"],
			omni_light["chosen_rotation"],
			omni_light["chosen_energy"],
			omni_light["chosen_indirect_energy"],
			0.0)


func _on_palette_item_selected(item: int) -> void:
	# Prevent access from dock.tscn
	if !grid_map:
		return
	
	%MeshOptions.show()
	%ItemImage.texture = _mesh_palette.get_item_icon(item)
	%ItemName.text = _mesh_palette.get_item_text(item)
	
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


func _on_light_type_item_selected(index: int) -> void:
	if index == 0:
		light_type = "directional"
		%LightAngularDistanceLabel.visible = true
		%LightAngularDistance.visible = true
		light_position.text = directional_light["last_valid_position_value"]
		light_rotation.text = directional_light["last_valid_rotation_value"]
		light_energy.value = directional_light["chosen_energy"]
		light_indirect_energy.value = directional_light["chosen_indirect_energy"]
		light_angular_distance.value = directional_light["chosen_angular_distance"]
		
	elif index == 1:
		light_type = "omni"
		%LightAngularDistanceLabel.visible = false
		%LightAngularDistance.visible = false
		light_position.text = omni_light["last_valid_position_value"]
		light_rotation.text = omni_light["last_valid_rotation_value"]
		light_energy.value = omni_light["chosen_energy"]
		light_indirect_energy.value = omni_light["chosen_indirect_energy"]
		
	_set_builder_light_parameters()


func _on_light_position_focus_exited() -> void:
	
	_check_and_change_light_position(light_position.text)


func _on_light_rotation_focus_exited() -> void:
	
	_check_and_change_light_rotation(light_rotation.text)


func _on_light_position_text_submitted(new_text: String) -> void:
	
	_check_and_change_light_position(new_text)

	

func _on_light_rotation_text_submitted(new_text: String) -> void:
	
	_check_and_change_light_rotation(new_text)


func _check_and_change_light_position(new_text: String) -> void:
	var result = parse_vector3(new_text)
	
	if result[0]:# If parsing was successful
		var parsed_vector: Vector3 = result[1]
		if light_type == "directional":
			directional_light["last_valid_position_value"] = new_text
			directional_light["chosen_position"] = parsed_vector
		elif light_type == "omni":
			omni_light["last_valid_position_value"] = new_text
			omni_light["chosen_position"] = parsed_vector
		light_position.release_focus()
		_set_builder_light_parameters()
	else:
		# Invalid input
		if light_type == "directional":
			light_position.text = directional_light["last_valid_position_value"]
		elif light_type == "omni":
			light_position.text = omni_light["last_valid_position_value"]


func _check_and_change_light_rotation(new_text: String) -> void:
	var result = parse_vector3(new_text)
	
	if result[0]:# If parsing was successful
		var parsed_vector: Vector3 = result[1]
		if light_type == "directional":
			directional_light["last_valid_rotation_value"] = new_text
			directional_light["chosen_rotation"] = parsed_vector
		elif light_type == "omni":
			omni_light["last_valid_rotation_value"] = new_text
			omni_light["chosen_rotation"] = parsed_vector
		light_rotation.release_focus()
		_set_builder_light_parameters()
	else:
		# Invalid input
		if light_type == "directional":
			light_rotation.text = directional_light["last_valid_rotation_value"]
		elif light_type == "omni":
			light_rotation.text = omni_light["last_valid_rotation_value"]


func _on_light_energy_drag_ended(value_changed: bool) -> void:
	if value_changed:
		if light_type == "directional":
			directional_light["chosen_energy"] = light_energy.value
		elif light_type == "omni":
			omni_light["chosen_energy"] = light_energy.value
	_set_builder_light_parameters()
	

func _on_light_indirect_energy_drag_ended(value_changed: bool) -> void:
	pass # Replace with function body.
	if value_changed:
		if light_type == "directional":
			directional_light["chosen_indirect_energy"] = light_indirect_energy.value
		elif light_type == "omni":
			omni_light["chosen_indirect_energy"] = light_indirect_energy.value
	_set_builder_light_parameters()
	

func _on_light_angular_distance_drag_ended(value_changed: bool) -> void:
	if value_changed:
		directional_light["chosen_angular_distance"] = light_angular_distance.value
	_set_builder_light_parameters()
	

func parse_vector3(input: String) -> Array:
	# Remove parentheses if present
	input = input.strip_edges().trim_prefix("(").trim_suffix(")")
	
	# Split the string by comma or space
	var parts = input.split(",")
	if parts.size() != 3:
		parts = input.split(" ")
		
	if parts.size() != 3:
		return [false, Vector3.ZERO]
	
	for i in parts:
		i = i.strip_edges()
		if not i.is_valid_float():
			return [false, Vector3.ZERO]
	
	var x = parts[0].to_float()
	var y = parts[1].to_float()
	var z = parts[2].to_float()
	
	return [true, Vector3(x,y,z)]
	
