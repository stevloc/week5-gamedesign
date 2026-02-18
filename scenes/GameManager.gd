extends Node2D

var cursor
var tilemap
var player

var mine_status = false
var mine_timer = 0.0
var mine_time = 0.5
var mine_value = 1

var tile_size = 16.0
var radius

var tile_coords

var durability = 100.0
var weakness = 30.0

var slider

#DICTIONARY FOR MINING: MINING TIMES + VALUES
#MAPPED TO ATLAS OF TILEMAP SPRITE SHEET
var mining_dictionary = {
	"(0, 0)": {"time": 0.5, "value": 0, "hardness": 0.5},
	"(1, 0)": {"time": 0.5, "value": 1, "hardness": 0.5},
	"(3, 0)": {"time": 1, "value": 2, "hardness": 1.0},
}

var mining = preload("res://assets/mining.tscn")

func _ready():
	cursor = get_node("Cursor")
	tilemap = get_node("TileMap/Layer1")
	player = get_node("Player")
	radius = get_node("Player/Radius")
	slider = get_node("CanvasLayer/HSlider")

func _physics_process(delta):
	slider.value = durability
	cursor.position = Vector2(floor(get_global_mouse_position().x/tile_size) * tile_size + tile_size/2.0,
	floor(get_global_mouse_position().y/tile_size) * tile_size + tile_size/2.0)
	if Input.is_action_just_pressed("mine"):
		var local_pos = tilemap.to_local(cursor.position)
		tile_coords = tilemap.local_to_map(local_pos)
		
		# Check if there's a tile at this position
		var tile_data = tilemap.get_cell_source_id(tile_coords)
		#print("Tile data: ", tile_data)
		if abs(player.position.x - cursor.position.x) < tile_size * 3 and abs(player.position.y - cursor.position.y) < tile_size * 3:
			if check_all_surrounding_tiles(cursor.position):
				if tile_data != -1:  # -1 means no tile (already sky)
					# There's a solid block, turn it into sky (erase it)
					if durability > 0:
						mine_status = true
						mine_timer = 0.0
						var atlas_coords = tilemap.get_cell_atlas_coords(tile_coords)
						mine_time = mining_dictionary[str(atlas_coords)]["time"]
						mine_value = mining_dictionary[str(atlas_coords)]["value"]
						var inst = mining.instantiate()
						inst.position = cursor.position
						inst.get_sprite_frames().set_animation_speed("default", floor(10.0 - (mine_time * 5.0)))
						print("mine time set to ", floor(10.0 - (mine_time * 5.0)))
						add_child(inst)
					#tilemap.erase_cell(tile_coords)
				else:
					# It's sky, turn it back into a solid block
					# Using tile atlas coords (1, 0) which should be a basic block
					tilemap.set_cell(tile_coords, 0, Vector2i(1, 0))
					print("Placed tile at: ", tile_coords)
					mine_status = false
		else:
			radius.visible = true
	if Input.is_action_pressed("mine"):
		if mine_status:
			mine_timer += delta
			if mine_timer >= mine_time:
				var atlas_coords = tilemap.get_cell_atlas_coords(tile_coords)
				durability -= mining_dictionary[str(atlas_coords)]["hardness"] * weakness
				print("Durability now ", durability)
				tilemap.erase_cell(tile_coords)
				mine_status = false
				print("Erased tile at: ", tile_coords)
				print("Gained value ", mine_value)
				var mining_inst = get_node("Mining")
				if mining_inst:
					mining_inst.queue_free()
	if Input.is_action_just_released("mine"):
		var mining_inst = get_node("Mining")
		if mining_inst:
			mining_inst.queue_free()
		mine_status = false
		radius.visible = false
					
				
func check_tile_status(position):
	var local_pos = tilemap.to_local(position)
	var tile_coords = tilemap.local_to_map(local_pos)
	
	# Check if there's a tile at this position
	var tile_data = tilemap.get_cell_source_id(tile_coords)
	print("Tile data: ", tile_data)
	print("Position at ", position)
	return tile_data

func check_all_surrounding_tiles(position):
	print("Start position at", position)
	position.x += tile_size
	if check_tile_status(position) == -1:
		print("Opening right")
		return true
	position.x -= tile_size * 2.0
	if check_tile_status(position) == -1:
		print("Opening left")
		return true
	position.x += tile_size
	position.y += tile_size
	if check_tile_status(position) == -1:
		print("Opening down")
		return true
	position.y -= tile_size * 2.0
	if check_tile_status(position) == -1:
		print("Opening up")
		return true
	print("no openings")
	return false
	
