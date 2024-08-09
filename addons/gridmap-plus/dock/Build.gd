@tool
extends Window

# Changes to this scene will be reflected in the file. So let's construct the scene
# from basic principles.

signal apply_changes

var grid_map: GridMap
var player: Node3D
var camera: Camera3D
var crosshair : AnimatedSprite2D
var interstitial_mesh : MeshInstance3D
var marker_mesh : MeshInstance3D
var toolbar : Node2D
var force_block_timer : Timer
var pause_menu : VBoxContainer

var _trace := { hit = false }
var _animating_interaction := false

# Origin material must remain in memory
var _origin_material : ShaderMaterial


func _ready() -> void:
	# Need valid scenario rid for origin
	world_3d = World3D.new()
	
	camera = Camera3D.new()
	
	player = Node3D.new()
	player.add_child(camera)
	
	var spawn_pos := Vector3i.ZERO
	while grid_map.get_cell_item(spawn_pos) != GridMap.INVALID_CELL_ITEM:
		spawn_pos += Vector3i.UP
	player.position = grid_map.map_to_local(spawn_pos)
	
	add_child(player)
	
	var light = DirectionalLight3D.new()
	add_child(light)
	light.position = Vector3(4.0, 5.0, 3.0)
	light.look_at(Vector3.ZERO)
	
	interstitial_mesh = MeshInstance3D.new()
	interstitial_mesh.visible = false
	add_child(interstitial_mesh)
	
	crosshair = AnimatedSprite2D.new()
	crosshair.sprite_frames = load("res://addons/gridmap-plus/assets/Crosshair.tres")
	crosshair.position = (0.5 * size).floor()
	crosshair.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(crosshair)
	
	# Put a world environment in to reduce the misery
	var sky_material := PanoramaSkyMaterial.new()
	sky_material.panorama = load("res://addons/gridmap-plus/assets/skybox.png")
	
	var sky := Sky.new()
	sky.sky_material = sky_material
	
	var environ := Environment.new()
	environ.background_mode = Environment.BG_SKY
	environ.sky = sky
	
	var world_env := WorldEnvironment.new()
	world_env.environment = environ
	
	add_child(world_env)
	
	force_block_timer = Timer.new()
	force_block_timer.one_shot = true
	force_block_timer.timeout.connect(_on_force_block_placement)
	add_child(force_block_timer)
	
	var save_changes = Button.new()
	save_changes.text = "Save changes"
	save_changes.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	save_changes.pressed.connect(func():
		apply_changes.emit()
		hide()
	)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	
	var discard_changes := Button.new()
	discard_changes.text = "Discard changes"
	discard_changes.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	discard_changes.pressed.connect(func():
		hide()
	)
	
	pause_menu = VBoxContainer.new()
	pause_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.theme = load("res://addons/gridmap-plus/assets/Buttons.tres")
	pause_menu.add_child(save_changes)
	pause_menu.add_child(spacer)
	pause_menu.add_child(discard_changes)
	pause_menu.hide()
	add_child(pause_menu)
	
	title = "GridMap+ Build Mode"
	
	size_changed.connect(_on_size_changed)
	close_requested.connect(_on_close_requested)
	
	init_origin()


func init_origin() -> void:
	# This is a port from Node3DEditor::_init_indicators
	# Godot doesn't supply its individual editor components as components,
	# so I've pulled the code for the origin out and ported it here.
	# Therefore, the software license for the this function is that of the Godot Engine.

	_origin_material = ShaderMaterial.new()
	_origin_material.shader = load("res://addons/gridmap-plus/dock/Origin.gdshader")

	# might need to be a packed vector
	var origin_points : PackedVector3Array = [
		Vector3(0.0, -0.5, 0.0),
		Vector3(0.0, -0.5, 1.0),
		Vector3(0.0, 0.5, 1.0),
		Vector3(0.0, -0.5, 0.0),
		Vector3(0.0, 0.5, 1.0),
		Vector3(0.0, 0.5, 0.0)
	]

	var d = []
	d.resize(RenderingServer.ARRAY_MAX)
	d[RenderingServer.ARRAY_VERTEX] = origin_points

	var origin_mesh := RenderingServer.mesh_create()
	RenderingServer.mesh_add_surface_from_arrays(origin_mesh, RenderingServer.PRIMITIVE_TRIANGLES, d)
	RenderingServer.mesh_surface_set_material(origin_mesh, 0, _origin_material.get_rid())
	
	var origin_multimesh := RenderingServer.multimesh_create()
	RenderingServer.multimesh_set_mesh(origin_multimesh, origin_mesh)
	RenderingServer.multimesh_allocate_data(origin_multimesh, 12, RenderingServer.MULTIMESH_TRANSFORM_3D, true, false)
	RenderingServer.multimesh_set_visible_instances(origin_multimesh, -1)
	
	var distances = [
		-1000000.0,
		-1000.0,
		0.0,
		1000.0,
		1000000.0
	]

	for i in 3:
		var origin_color : Color
		match i:
			0: origin_color = get_theme_color(&"axis_x_color", &"Editor")
			1: origin_color = get_theme_color(&"axis_y_color", &"Editor")
			2: origin_color = get_theme_color(&"axis_z_color", &"Editor")
		
		var axis := Vector3.ZERO
		axis[i] = 1.0
		
		for j in 4:
			var t = Transform3D()
			if distances[j] > 0.0:
				t = t.scaled(axis * distances[j + 1])
				t = t.translated((axis * distances[j]))
			else:
				t = t.scaled(axis * distances[j])
				t = t.translated(axis * distances[j + 1])
			
			RenderingServer.multimesh_instance_set_transform(origin_multimesh, i * 4 + j, t)
			RenderingServer.multimesh_instance_set_color(origin_multimesh, i * 4 + j, origin_color)
	
	var origin_instance := RenderingServer.instance_create2(origin_multimesh, world_3d.scenario)
	RenderingServer.instance_geometry_set_flag(origin_instance, RenderingServer.INSTANCE_FLAG_IGNORE_OCCLUSION_CULLING, true)
	RenderingServer.instance_geometry_set_flag(origin_instance, RenderingServer.INSTANCE_FLAG_USE_BAKED_LIGHT, false)
	RenderingServer.instance_geometry_set_cast_shadows_setting(origin_instance, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	
	tree_exited.connect(func():
		RenderingServer.free_rid(origin_instance)
		RenderingServer.free_rid(origin_multimesh)
		RenderingServer.free_rid(origin_mesh)
	)


func _on_size_changed() -> void:
	crosshair.position = (0.5 * size).floor()


func _on_close_requested() -> void:
	hide()


func set_grid_map(g: GridMap) -> void:
	grid_map = g.duplicate()
	add_child(grid_map)
	
	# now we know the grid map size, set up the marker
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color("ffff0060")
	
	var box_mesh := BoxMesh.new()
	box_mesh.size = grid_map.cell_size + 0.05 * Vector3.ONE
	box_mesh.material = material
	
	marker_mesh = MeshInstance3D.new()
	marker_mesh.mesh = box_mesh
	marker_mesh.visible = false
	add_child(marker_mesh)
	
	toolbar = load("res://addons/gridmap-plus/dock/Toolbar.tscn").instantiate()
	add_child(toolbar)
	toolbar.set_mesh_library(grid_map.mesh_library)
	
	# start control
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED



func write_changes(g: GridMap) -> void:
	var filled = {}
	for c in g.get_used_cells():
		filled[c] = true
	
	for c in grid_map.get_used_cells():
		g.set_cell_item(c, grid_map.get_cell_item(c), grid_map.get_cell_item_orientation(c))
		filled.erase(c)
	
	for c in filled:
		g.set_cell_item(c, GridMap.INVALID_CELL_ITEM)


# Animate a block rotation
func perform_target_block_rotation(axis: Vector3, rotation: float) -> void:
	if _animating_interaction:
		return
	
	var coord = _trace.coord
	_animating_interaction = true
	
	var item = grid_map.get_cell_item(coord)
	var orientation = grid_map.get_cell_item_orientation(coord)
	grid_map.set_cell_item(_trace.coord, GridMap.INVALID_CELL_ITEM)
	
	interstitial_mesh.mesh = grid_map.mesh_library.get_item_mesh(item)
	interstitial_mesh.visible = true
	
	var offset = Transform3D(grid_map.get_basis_with_orthogonal_index(orientation), grid_map.map_to_local(coord))
	var steps = 10
	for n in steps:
		interstitial_mesh.transform = offset
		interstitial_mesh.rotate(axis, (n * rotation) / steps)
		interstitial_mesh.transform *= grid_map.mesh_library.get_item_mesh_transform(item)
		await get_tree().process_frame
		
	interstitial_mesh.visible = false
	
	# replace with original block and rotate
	grid_map.set_cell_item(coord, item, orientation)
	GridMapPlus.rotate_grid_map_cell(grid_map, coord, axis, rotation)
	
	_animating_interaction = false


func get_placement_basis() -> Basis:
	var placement := GridMapPlus.get_placement_mode(grid_map.mesh_library, toolbar.brush)
	
	# deal with this one easily
	if placement == GridMapPlus.PlacementMode.FULL_RANDOM:
		return grid_map.get_basis_with_orthogonal_index(randi() % 24)
	
	var upwards = _trace.normal
	if placement in [GridMapPlus.PlacementMode.UPWARDS, GridMapPlus.PlacementMode.UPWARDS_RANDOM]:
		upwards = Vector3.UP
	
	# is this being built outwards but is placed on the y axis, degrade to upwards
	if _trace.normal in [Vector3.UP, Vector3.DOWN]:
		if placement == GridMapPlus.PlacementMode.OUTWARDS:
			placement = GridMapPlus.PlacementMode.UPWARDS
		if placement == GridMapPlus.PlacementMode.OUTWARDS_RANDOM:
			placement = GridMapPlus.PlacementMode.UPWARDS_RANDOM
	
	# outwards facing blocks default to z down (facing up)
	var facing = Vector3.DOWN
	
	if placement == GridMapPlus.PlacementMode.UPWARDS:
		# find horizontal view direction
		var look := -player.global_basis.z
		var look_axis := look.abs().max_axis_index()
		facing = Vector3.ZERO
		facing[look_axis] = -look.sign()[look_axis]
	elif placement == GridMapPlus.PlacementMode.UPWARDS_RANDOM:
		facing = Vector3.RIGHT.rotated(Vector3.UP, (randi() % 4) * 0.5 * PI)
	elif placement == GridMapPlus.PlacementMode.OUTWARDS_RANDOM:
		facing = Vector3.UP.rotated(_trace.normal, (randi() % 4) * 0.5 * PI)
	
	return Basis(upwards.cross(facing), upwards, facing)


func _unhandled_input(event: InputEvent) -> void:
	var click = event as InputEventMouseButton
	var key = event as InputEventKey
	
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if click and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			pause_menu.hide()
		return
	
	if key and key.keycode == KEY_ESCAPE and key.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pause_menu.show()
		return



func _input(event: InputEvent) -> void:
	const sensitivity = 0.002
	
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	
	var motion = event as InputEventMouseMotion
	var click = event as InputEventMouseButton
	var key = event as InputEventKey
	
	if key and key.pressed and !key.shift_pressed:
		match key.keycode:
			KEY_Q: toolbar.brush -= 1
			KEY_E: toolbar.brush += 1
	
	if motion:
		player.rotate_y(-motion.relative.x * sensitivity)
		camera.rotate_x(-motion.relative.y * sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -deg_to_rad(85), deg_to_rad(85))
	
	if !_trace.hit:
		if click and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
			crosshair.play(&"place")
			force_block_timer.start()
	
	if click and click.button_index == MOUSE_BUTTON_LEFT and !click.pressed:
		crosshair.play(&"default")
		force_block_timer.stop()
	
	if _trace.hit:
		if click and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
			var basis = get_placement_basis()
			var orientation = grid_map.get_orthogonal_index_from_basis(basis)
			grid_map.set_cell_item(_trace.coord + _trace.inormal, toolbar.brush, orientation)
		
		if click and click.button_index == MOUSE_BUTTON_MIDDLE and click.pressed:
			toolbar.brush = grid_map.get_cell_item(_trace.coord)
		
		if click and click.button_index == MOUSE_BUTTON_RIGHT and click.pressed:
			grid_map.set_cell_item(_trace.coord, GridMap.INVALID_CELL_ITEM)
		
		if key and key.pressed and key.shift_pressed:
			var relative_up : Vector3 = _trace.normal.cross(camera.global_basis.x)
			relative_up = relative_up.normalized()
			var n := relative_up.abs().max_axis_index()
			var ortho_up := Vector3.ZERO
			ortho_up[n] = relative_up.sign()[n]
			var ortho_right = ortho_up.cross(_trace.normal)
			
			match key.keycode:
				KEY_Q: perform_target_block_rotation(_trace.normal, 0.5 * PI)
				KEY_E: perform_target_block_rotation(_trace.normal, -0.5 * PI)
				KEY_W: perform_target_block_rotation(ortho_right, -0.5 * PI)
				KEY_S: perform_target_block_rotation(ortho_right, 0.5 * PI)
				KEY_A: perform_target_block_rotation(ortho_up, -0.5 * PI)
				KEY_D: perform_target_block_rotation(ortho_up, 0.5 * PI)
		


func _process(delta: float) -> void:
	const speed = 0.1
	
	var forward := -player.global_basis.z
	var right := player.global_basis.x
	if !Input.is_key_pressed(KEY_SHIFT):
		if Input.is_key_pressed(KEY_W):
			player.position += speed * forward
		if Input.is_key_pressed(KEY_S):
			player.position -= speed * forward
		if Input.is_key_pressed(KEY_D):
			player.position += speed * right
		if Input.is_key_pressed(KEY_A):
			player.position -= speed * right
		if Input.is_key_pressed(KEY_SPACE):
			player.position.y += speed
		if Input.is_key_pressed(KEY_CTRL):
			player.position.y -= speed
	
	if _animating_interaction:
		return
	
	var look := -camera.global_basis.z
	_trace = GridMapPlus.trace(grid_map, player.position, 30.0 * look)
	marker_mesh.visible = _trace.hit
	if marker_mesh.visible:
		marker_mesh.position = grid_map.map_to_local(_trace.coord)


func _on_force_block_placement() -> void:
	_trace.normal = Vector3.UP # Hack to ensure basis is found
	var basis = get_placement_basis()
	var orientation = grid_map.get_orthogonal_index_from_basis(basis)
	grid_map.set_cell_item(grid_map.local_to_map(player.position), toolbar.brush, orientation)
