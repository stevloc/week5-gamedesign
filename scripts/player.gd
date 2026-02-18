extends CharacterBody2D

const SPEED = 200.0
const JUMP_VELOCITY = -400.0

# Get the gravity from the project settings
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var can_mine = true
var facing_direction = Vector2.ZERO  # Track which direction player is facing

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get input direction for left/right movement
	var direction = Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
		facing_direction.x = direction  # Update facing direction
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	# Check for up/down input
	if Input.is_action_pressed("ui_up"):
		facing_direction = Vector2(0, -1)  # Up
	elif Input.is_action_pressed("ui_down"):
		facing_direction = Vector2(0, 1)   # Down

	move_and_slide()
	
	# Handle mining
	#if Input.is_action_just_pressed("mine") and can_mine:
	#	mine_block_in_direction()
	#	can_mine = false
	
	#if not Input.is_key_pressed(KEY_P):
	#	can_mine = true

func mine_block_in_direction():
	# Get the tilemap from the scene
	var game = get_parent()
	if game == null:
		print("Error: No parent found")
		return
	
	var tilemap = game.get_node_or_null("TileMap")
	if tilemap == null:
		print("Error: TileMap not found")
		return
	
	var layer = tilemap.get_node_or_null("Layer1")
	if layer == null:
		print("Error: Layer1 not found")
		return
	
	# If no direction is set, default to down
	var mine_direction = facing_direction
	if mine_direction == Vector2.ZERO:
		mine_direction = Vector2(0, 1)  # Default to down
	
	# Calculate the tile position in the facing direction
	var player_global_pos = global_position
	var offset = mine_direction * 16  # One block in the facing direction
	var target_pos = player_global_pos + offset
	
	# Convert world position to local layer position, then to tile coordinates
	var local_pos = layer.to_local(target_pos)
	var tile_coords = layer.local_to_map(local_pos)
	
	print("Player pos: ", player_global_pos)
	print("Facing direction: ", mine_direction)
	print("Target pos: ", target_pos)
	print("Tile coords: ", tile_coords)
	
	# Check if there's a tile at this position
	var tile_data = layer.get_cell_source_id(tile_coords)
	print("Tile data: ", tile_data)
	
	if tile_data != -1:  # -1 means no tile (already sky)
		# There's a solid block, turn it into sky (erase it)
		layer.erase_cell(tile_coords)
		print("Erased tile at: ", tile_coords)
	else:
		# It's sky, turn it back into a solid block
		# Using tile atlas coords (1, 0) which should be a basic block
		layer.set_cell(tile_coords, 0, Vector2i(1, 0))
		print("Placed tile at: ", tile_coords)
