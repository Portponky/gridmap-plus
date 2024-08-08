@tool
extends Node2D

const SPACING := 72

@onready var icons: Node2D = $Icons
@onready var selection: Sprite2D = $Icons/Selection

var mesh_library: MeshLibrary
var _tween : Tween

var brush := 0:
	set(x):
		brush = clamp(x, 0, mesh_library.get_last_unused_item_id() - 1)
		update_brush()


func _ready() -> void:
	get_window().size_changed.connect(_on_size_changed)
	_on_size_changed()


func set_mesh_library(ml: MeshLibrary) -> void:
	mesh_library = ml
	for n in mesh_library.get_last_unused_item_id():
		var s = Sprite2D.new()
		s.texture = mesh_library.get_item_preview(n)
		s.position.x = 72 * n
		$Icons.add_child(s)
		
		var hb = GridMapPlus.get_hotbar(mesh_library, n)
		if hb > -1:
			var digits = $Digits.duplicate()
			digits.frame = hb
			digits.visible = true
			s.add_child(digits)
		
	$Icons/BG.size.x = SPACING * mesh_library.get_last_unused_item_id()
	
	update_brush()


func _on_size_changed() -> void:
	if !mesh_library:
		return

	var size = get_window().size
	position = Vector2(SPACING, size.y - SPACING)
	update_brush()


func _input(event: InputEvent) -> void:
	var key = event as InputEventKey
	if !key or !key.pressed:
		return
	
	var hb = -1
	if key.keycode >= KEY_0 and key.keycode <= KEY_9:
		hb = key.keycode - KEY_0
	else:
		return
	
	var t = (brush + 1) % mesh_library.get_last_unused_item_id()
	while t != brush:
		if GridMapPlus.get_hotbar(mesh_library, t) == hb:
			brush = t
			return
		
		t = (t + 1) % mesh_library.get_last_unused_item_id()


func update_brush() -> void:
	if !mesh_library:
		return
	
	if _tween:
		_tween.kill()
	
	_tween = create_tween()
	if !_tween or !get_window():
		return # in editor
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_parallel()
	_tween.tween_property(selection, "position", Vector2.RIGHT * SPACING * brush, 0.1)
	
	# calculate toolbar slide
	var end_of_screen = get_window().size.x - 2 * SPACING
	var max_toolbar_size = floor(end_of_screen / SPACING)
	if mesh_library.get_last_unused_item_id() >= max_toolbar_size:
		# slide toolbar so the last position is last pos
		var original_pos = brush * SPACING
		var slide = (end_of_screen * brush) / (mesh_library.get_last_unused_item_id() - 1.0)
		_tween.tween_property(icons, "position:x", floor(slide - original_pos), 0.1)
	else:
		_tween.tween_property(icons, "position:x", 0.0, 0.1)
