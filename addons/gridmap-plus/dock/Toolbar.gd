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


func update_brush() -> void:
	$Sprite.texture = mesh_library.get_item_preview(brush)
