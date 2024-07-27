@tool
extends Node2D

var mesh_library: MeshLibrary

var brush := 0:
	set(x):
		brush = clamp(x, 0, mesh_library.get_last_unused_item_id() - 1)
		update_brush()


func set_mesh_library(ml: MeshLibrary) -> void:
	mesh_library = ml
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
	$Sprite.texture = mesh_library.get_item_preview(brush)
