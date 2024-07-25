@tool
class_name GridMapPlus
extends Node

const MESH_LIB_META = &"_gridmap_plus"

enum PlacementMode {
	UPWARDS,
	OUTWARDS,
	UPWARDS_RANDOM,
	OUTWARDS_RANDOM,
	FULL_RANDOM
}

static func set_placement_mode(ml: MeshLibrary, item: int, placement: PlacementMode) -> void:
	var meta = ml.get_meta(MESH_LIB_META, {})
	if !meta.has(item):
		meta[item] = {}
	meta[item].placement = placement
	ml.set_meta(MESH_LIB_META, meta)


static func get_placement_mode(ml: MeshLibrary, item: int) -> PlacementMode:
	var meta = ml.get_meta(MESH_LIB_META, {})
	if meta.has(item):
		return meta[item].placement
	return PlacementMode.UPWARDS


# Traces from pos to pos+line in the gridmap and returns the first non-empty cell
# return a dictionary with the following entries
# hit -> boolean, if the trace hit something
# t -> parameter of line followed, between 0.0 and 1.0
# coord -> ending cell
# normal -> vector3 normal vector of cell hit (will match an axis) (only if hit)
# inormal -> same as normal but vector3i (only if hit)
static func trace(gridmap: GridMap, pos: Vector3, line: Vector3) -> Dictionary:
	# Find the origin point of the models within the gridmap cell
	var model_origin := 0.5 * gridmap.cell_size * Vector3(gridmap.cell_center_x, gridmap.cell_center_y, gridmap.cell_center_z)
	
	# Correct position to take account of non-centered axes
	pos += 0.5 * gridmap.cell_size - model_origin
	
	var coord := gridmap.local_to_map(pos)
	var origin := gridmap.map_to_local(coord) - model_origin
	var offset := pos - origin
	
	var step := line.sign()
	var rate := gridmap.cell_size / line.abs()
	var edge := (0.5 * Vector3.ONE + 0.5 * step) * gridmap.cell_size
	var next := (edge - offset).abs() / line.abs()
	
	const invalid_next = 10.0
	if step.x == 0.0: next.x = invalid_next
	if step.y == 0.0: next.y = invalid_next
	if step.z == 0.0: next.z = invalid_next
	
	var normal := Vector3.ZERO
	var t = 0.0
	while t < 1.0:
		var n = 2
		if step.x != 0.0 and next.x < next.y and next.x < next.z:
			n = 0
		elif step.y != 0.0 and next.y < next.z:
			n = 1
		
		t = next[n];
		normal = Vector3.ZERO
		normal[n] = -step[n]
		coord[n] += step[n];
		next[n] += rate[n];
		
		if gridmap.get_cell_item(coord) != GridMap.INVALID_CELL_ITEM:
			return {
				hit = true,
				t = t,
				coord = coord,
				normal = normal,
				inormal = Vector3i(normal)
			}
	
	return {
		hit  = false,
		t = 1.0,
		coord = coord,
	}


# Rotates a grid map cell in situ
# Axis should be an ortho vector in a cardinal direction
static func rotate_grid_map_cell(gridmap: GridMap, coord: Vector3i, axis: Vector3, rotation: float) -> void:
	var item := gridmap.get_cell_item(coord)
	if item == GridMap.INVALID_CELL_ITEM:
		return
	
	var i := gridmap.get_cell_item_orientation(coord)
	var b := gridmap.get_basis_with_orthogonal_index(i)
	b = b.rotated(axis, rotation)
	i = gridmap.get_orthogonal_index_from_basis(b)
	gridmap.set_cell_item(coord, item, i)
