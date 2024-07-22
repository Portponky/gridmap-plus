@tool
extends Window

# Changes to this scene will be reflected in the file. So let's construct the scene from basic
# principles at all points.

var grid_map: GridMap
var player: Node3D
var camera: Camera3D
var crosshair : Sprite2D
var interstitial_mesh : MeshInstance3D
var marker_mesh : MeshInstance3D
var toolbar : Node2D


var _trace := { hit = false }
var _animating_interaction := false


# replace with basis generation
func normal_to_orientation(normal: Vector3i) -> int:
	match normal:
		Vector3i.UP: return 0
		Vector3i.DOWN: return 2
		Vector3i.LEFT: return 1
		Vector3i.RIGHT: return 3
		Vector3i.FORWARD: return 14 
		Vector3i.BACK: return 6
	return 0


func _ready() -> void:
	own_world_3d = true
	
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
	
	crosshair = Sprite2D.new()
	crosshair.texture = load("res://addons/gridmap-plus/assets/crosshair.png")
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
	
	title = "GridMap+ Build Mode"
	
	size_changed.connect(_on_size_changed)
	close_requested.connect(_on_close_requested)


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


func _input(event) -> void:
	const sensitivity = 0.002
	
	var motion = event as InputEventMouseMotion
	var click = event as InputEventMouseButton
	var key = event as InputEventKey
	
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if click and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	
	if key and key.keycode == KEY_ESCAPE and key.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	
	if key and key.pressed and !key.shift_pressed:
		match key.keycode:
			KEY_Q: toolbar.brush -= 1
			KEY_E: toolbar.brush += 1
	
	if motion:
		player.rotate_y(-motion.relative.x * sensitivity)
		camera.rotate_x(-motion.relative.y * sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -deg_to_rad(90), deg_to_rad(90))
	
	if _trace.hit:
		if click and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
			grid_map.set_cell_item(_trace.coord + _trace.inormal, toolbar.brush, normal_to_orientation(_trace.inormal))
		
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
