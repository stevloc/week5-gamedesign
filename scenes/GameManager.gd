extends Node2D

# --- Tunables ---
const TILE_SIZE := 16.0
const WEAKNESS_BASE := 30.0

@export var depth_goal: int = 100  # tiles down from start

# --- Runtime refs ---
@onready var cursor: Node2D = $Cursor
@onready var tilemap: TileMapLayer = $TileMap/Layer1
@onready var player: Node2D = $Player
@onready var radius: CanvasItem = $Player/Radius

# HUD
@onready var slider: HSlider = $CanvasLayer/HSlider
@onready var coins_label: Label = $CanvasLayer/CoinsLabel
@onready var stone_label: Label = $CanvasLayer/StoneLabel
@onready var iron_label: Label = $CanvasLayer/IronLabel
@onready var gold_label: Label = $CanvasLayer/GoldLabel
@onready var diamond_label: Label = $CanvasLayer/DiamondLabel
@onready var depth_label: Label = $CanvasLayer/DepthLabel
@onready var pickaxe_label: Label = $CanvasLayer/PickaxeLabel

# Shop
@onready var shop_panel: Control = $CanvasLayer/ShopPanel
@onready var ore_select: OptionButton = $CanvasLayer/ShopPanel/VBoxContainer/OreSelect
@onready var sell_amount: SpinBox = $CanvasLayer/ShopPanel/VBoxContainer/SellAmount
@onready var message_label: Label = $CanvasLayer/ShopPanel/VBoxContainer/MessageLabel
@onready var sell_btn: Button = $CanvasLayer/ShopPanel/VBoxContainer/SellRow/SellButton
@onready var close_btn: Button = $CanvasLayer/ShopPanel/VBoxContainer/SellRow/CloseButton
@onready var repair_btn: Button = $CanvasLayer/ShopPanel/VBoxContainer/MaintenanceRow/RepairButton
@onready var upgrade_btn: Button = $CanvasLayer/ShopPanel/VBoxContainer/MaintenanceRow/UpgradeButton

# --- Game state ---
var mine_status := false
var mine_timer := 0.0
var mine_time := 0.5
var tile_coords := Vector2i.ZERO

var durability := 500.0
var weakness := WEAKNESS_BASE

var coins: int = 0
var ore_inventory := {
	"stone": 0,
	"gold": 0,
	"iron": 0,
	"diamond": 0,
}

var pickaxe_level: int = 1
var max_durability_by_level := {
	1: 500.0,
	2: 750.0,
	3: 1200.0,
	4: 2000.0,
}

var start_y := 0.0
var game_over := false
var shop_open := false

# Mining data (atlas coords -> stats)
var mining_dictionary := {
	"(0, 0)": {"time": 0.5, "value": 1, "hardness": 0.5, "ore": "stone"},
	"(1, 0)": {"time": 0.5, "value": 1, "hardness": 0.5, "ore": "stone"},
	"(2, 0)": {"time": 0.8, "value": 3, "hardness": 0.8, "ore": "iron"},
	"(3, 0)": {"time": 1.0, "value": 5, "hardness": 1.0, "ore": "gold"},
	"(4, 0)": {"time": 1.5, "value": 10, "hardness": 1.5, "ore": "diamond"},
}

var mining_scene: PackedScene = preload("res://assets/mining.tscn")
var mining_fx: Node = null

func _ready() -> void:
	start_y = player.position.y

	# Slider setup
	slider.editable = false
	slider.min_value = 0
	_refresh_slider_max()

	# Shop setup
	shop_panel.visible = false
	_connect_shop_signals()
	_populate_ore_select()
	_refresh_sell_amount_limit()

	update_ui()
	show_message("")

func _connect_shop_signals() -> void:
	# Connect (safe if already connected)
	var c_sell: Callable = Callable(self, "_on_SellButton_pressed")
	if not sell_btn.pressed.is_connected(c_sell):
		sell_btn.pressed.connect(c_sell)

	var c_close: Callable = Callable(self, "_on_CloseButton_pressed")
	if not close_btn.pressed.is_connected(c_close):
		close_btn.pressed.connect(c_close)

	var c_repair: Callable = Callable(self, "_on_RepairButton_pressed")
	if not repair_btn.pressed.is_connected(c_repair):
		repair_btn.pressed.connect(c_repair)

	var c_upgrade: Callable = Callable(self, "_on_UpgradeButton_pressed")
	if not upgrade_btn.pressed.is_connected(c_upgrade):
		upgrade_btn.pressed.connect(c_upgrade)

	var c_select: Callable = Callable(self, "_on_OreSelect_item_selected")
	if not ore_select.item_selected.is_connected(c_select):
		ore_select.item_selected.connect(c_select)

func _populate_ore_select() -> void:
	ore_select.clear()
	for ore_name in ore_inventory.keys():
		ore_select.add_item(ore_name)
	if ore_select.item_count > 0:
		ore_select.select(0)

func _on_OreSelect_item_selected(_idx: int) -> void:
	_refresh_sell_amount_limit()

func _refresh_sell_amount_limit() -> void:
	if ore_select.item_count <= 0:
		return
	var ore_name: String = ore_select.get_item_text(ore_select.selected)
	var available: int = ore_inventory.get(ore_name, 0)
	sell_amount.min_value = 0
	sell_amount.max_value = available
	sell_amount.value = clamp(sell_amount.value, 0, available)

func _refresh_slider_max() -> void:
	var max_dur: float = max_durability_by_level.get(pickaxe_level, 500.0)
	slider.max_value = max_dur
	durability = clamp(durability, 0.0, max_dur)

func get_depth() -> int:
	return int(max(0.0, floor((player.position.y - start_y) / TILE_SIZE)))

func update_ui() -> void:
	if game_over:
		return
	coins_label.text = "Coins: %d" % coins
	stone_label.text = "Stone: %d" % ore_inventory.get("stone", 0)
	iron_label.text = "Iron: %d" % ore_inventory.get("iron", 0)
	gold_label.text = "Gold: %d" % ore_inventory.get("gold", 0)
	diamond_label.text = "Diamonds: %d" % ore_inventory.get("diamond", 0)
	depth_label.text = "Depth: %d" % get_depth()
	pickaxe_label.text = "Pickaxe Lv %d" % pickaxe_level
	slider.value = durability

func show_message(text: String) -> void:
	if message_label:
		message_label.text = text

func toggle_shop() -> void:
	if game_over:
		return
	shop_open = not shop_open
	shop_panel.visible = shop_open
	_refresh_sell_amount_limit()
	show_message("" if not shop_open else "Shop open")

func _physics_process(delta: float) -> void:
	if game_over:
		return

	# Allow opening/closing shop any time
	if Input.is_action_just_pressed("shop"):
		toggle_shop()

	# Keep HUD fresh
	update_ui()

	# Don't allow mining while shop is open
	if shop_open:
		_stop_mining_fx()
		mine_status = false
		radius.visible = false
		return

	# Cursor follows mouse
	cursor.position = Vector2(
		floor(get_global_mouse_position().x / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2.0,
		floor(get_global_mouse_position().y / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2.0
	)

	# Start mining
	if Input.is_action_just_pressed("mine"):
		_try_start_mine()

	# Hold mining
	if Input.is_action_pressed("mine") and mine_status:
		mine_timer += delta
		if mine_timer >= mine_time:
			_finish_mine()

	# Cancel mining
	if Input.is_action_just_released("mine"):
		mine_status = false
		radius.visible = false
		_stop_mining_fx()

func _try_start_mine() -> void:
	# Early safety checks
	if game_over:
		return
	
	if durability <= 0.0:
		show_message("Your pickaxe is broken! Repair it in the shop (Q).")
		# Don't call check_win_lose here - just prevent mining
		return
	
	var local_pos: Vector2 = tilemap.to_local(cursor.position)
	tile_coords = tilemap.local_to_map(local_pos)

	# Must be within range
	if abs(player.position.x - cursor.position.x) >= TILE_SIZE * 3.0 or abs(player.position.y - cursor.position.y) >= TILE_SIZE * 3.0:
		radius.visible = true
		return

	if not check_all_surrounding_tiles(cursor.position):
		return

	var tile_data: int = tilemap.get_cell_source_id(tile_coords)
	if tile_data == -1:
		# No tile here, nothing to mine
		return

	var atlas_coords: Vector2i = tilemap.get_cell_atlas_coords(tile_coords)
	var key: String = str(atlas_coords)
	
	# Safe lookup with fallback
	var data: Dictionary = mining_dictionary.get(key, {})
	if data.is_empty():
		# Unknown block type - use generic defaults
		print("Warning: Unknown tile type at ", key, " - using default values")
		data = {
			"time": 0.6, 
			"value": 1, 
			"hardness": 1.0, 
			"ore": "stone"
		}

	mine_status = true
	mine_timer = 0.0
	mine_time = float(data.get("time", 0.6))

	_start_mining_fx(mine_time)

func _start_mining_fx(time_to_mine: float) -> void:
	if game_over:
		return
		
	_stop_mining_fx()
	
	# Safe instantiation
	if not mining_scene:
		print("Warning: mining scene not loaded")
		return
		
	mining_fx = mining_scene.instantiate()
	if not mining_fx:
		print("Warning: failed to instantiate mining fx")
		return
		
	mining_fx.position = cursor.position
	
	# Safely set animation speed
	if mining_fx.has_method("get_sprite_frames"):
		var frames = mining_fx.get_sprite_frames()
		if frames and frames.has_animation("default"):
			var speed: float = max(1.0, floor(10.0 - (time_to_mine * 5.0)))
			frames.set_animation_speed("default", speed)
	
	add_child(mining_fx)

func _stop_mining_fx() -> void:
	if mining_fx and is_instance_valid(mining_fx):
		mining_fx.queue_free()
	mining_fx = null

func _finish_mine() -> void:
	if game_over:
		_stop_mining_fx()
		mine_status = false
		return
	
	var atlas_coords: Vector2i = tilemap.get_cell_atlas_coords(tile_coords)
	var key: String = str(atlas_coords)
	
	# Safe lookup with fallback
	var data: Dictionary = mining_dictionary.get(key, {})
	if data.is_empty():
		print("Warning: Unknown tile type at ", key, " during finish_mine")
		data = {
			"hardness": 1.0, 
			"ore": "stone"
		}

	# Deduct durability
	var hardness: float = float(data.get("hardness", 1.0))
	durability -= hardness * weakness
	durability = max(durability, 0.0)

	# Add ore to inventory
	var ore_name: String = str(data.get("ore", ""))
	if ore_name != "" and ore_name != "null":
		add_ore(ore_name)

	# Remove the tile
	tilemap.erase_cell(tile_coords)
	mine_status = false
	_stop_mining_fx()

	# Check win/lose conditions AFTER everything else is done
	check_win_lose()

func add_ore(ore_name: String) -> void:
	if game_over:
		return
		
	if not ore_inventory.has(ore_name):
		ore_inventory[ore_name] = 0
		_populate_ore_select()
	ore_inventory[ore_name] += 1
	_refresh_sell_amount_limit()

func get_ore_price(ore_name: String) -> int:
	for k in mining_dictionary.keys():
		var d: Dictionary = mining_dictionary[k]
		if d.get("ore", "") == ore_name:
			return int(d.get("value", 1))
	return 1

func check_win_lose() -> void:
	if game_over:
		return
	
	# Check lose condition (durability)
	if durability <= 0.0:
		game_over = true
		_stop_mining_fx()
		mine_status = false
		show_message("Your pickaxe broke. Game over.")
		# Defer the pause to next frame to avoid crash
		call_deferred("_pause_game")
		return
	
	# Check win condition (depth)
	if get_depth() >= depth_goal:
		game_over = true
		_stop_mining_fx()
		mine_status = false
		show_message("You reached the goal depth. You win!")
		call_deferred("_pause_game")

func _pause_game() -> void:
	get_tree().paused = true

# --- Shop actions ---
func _on_SellButton_pressed() -> void:
	if game_over:
		return
		
	if ore_select.item_count <= 0:
		show_message("No ores to sell.")
		return

	var ore_name: String = ore_select.get_item_text(ore_select.selected)
	var available: int = ore_inventory.get(ore_name, 0)
	var amount: int = int(clamp(sell_amount.value, 0, available))

	if amount <= 0:
		show_message("Nothing to sell.")
		return

	var gained: int = amount * get_ore_price(ore_name)
	ore_inventory[ore_name] = available - amount
	coins += gained
	_refresh_sell_amount_limit()
	update_ui()
	show_message("Sold %d %s for %d coins." % [amount, ore_name, gained])

func _on_CloseButton_pressed() -> void:
	shop_open = false
	shop_panel.visible = false
	show_message("")

func _on_RepairButton_pressed() -> void:
	if game_over:
		return
		
	var max_dur: float = max_durability_by_level.get(pickaxe_level, 500.0)
	var missing: float = max_dur - durability
	if missing <= 0.0:
		show_message("Pickaxe is already at full durability.")
		return

	var ore_tier: Array = ["stone", "iron", "gold", "diamond"]
	var cost_ore_name: String = ore_tier[pickaxe_level - 1] if pickaxe_level <= 4 else "diamond"
	# Nerfed: 1 ore per 50 durability (was 20), coins reduced from 10*level to 5*level
	var cost_ore_amount: int = max(1, int(missing / 50.0))
	var cost_coins: int = 5 * pickaxe_level

	if coins < cost_coins or ore_inventory.get(cost_ore_name, 0) < cost_ore_amount:
		show_message("Need %d %s and %d coins to repair." % [cost_ore_amount, cost_ore_name, cost_coins])
		return

	coins -= cost_coins
	ore_inventory[cost_ore_name] -= cost_ore_amount
	durability = max_dur
	
	# If pickaxe was broken, clear game over state
	if game_over:
		game_over = false
		get_tree().paused = false
	
	_refresh_slider_max()
	_refresh_sell_amount_limit()
	update_ui()
	show_message("Pickaxe repaired.")

func _on_UpgradeButton_pressed() -> void:
	if game_over:
		return
		
	if pickaxe_level >= 4:
		show_message("Pickaxe already max level.")
		return

	var ore_tier: Array = ["iron", "gold", "diamond"]
	var cost_ore_name: String = ore_tier[pickaxe_level - 1]
	# Nerfed: reduced ore cost from (5 + level*3) to (3 + level*2), coins from 50*level to 20*level
	var cost_ore_amount: int = 3 + (pickaxe_level * 2)
	var cost_coins: int = 20 * pickaxe_level

	if coins < cost_coins or ore_inventory.get(cost_ore_name, 0) < cost_ore_amount:
		show_message("Need %d %s and %d coins to upgrade." % [cost_ore_amount, cost_ore_name, cost_coins])
		return

	coins -= cost_coins
	ore_inventory[cost_ore_name] -= cost_ore_amount
	pickaxe_level += 1
	weakness *= 0.8
	_refresh_slider_max()
	_refresh_sell_amount_limit()
	update_ui()
	show_message("Pickaxe upgraded to level %d." % pickaxe_level)

# --- Tile checking helpers ---
func check_tile_status(position: Vector2) -> int:
	var local_pos: Vector2 = tilemap.to_local(position)
	var coords: Vector2i = tilemap.local_to_map(local_pos)
	return tilemap.get_cell_source_id(coords)

func check_all_surrounding_tiles(position: Vector2) -> bool:
	var p: Vector2 = position
	p.x += TILE_SIZE
	if check_tile_status(p) == -1: return true
	p.x -= TILE_SIZE * 2.0
	if check_tile_status(p) == -1: return true
	p.x += TILE_SIZE
	p.y += TILE_SIZE
	if check_tile_status(p) == -1: return true
	p.y -= TILE_SIZE * 2.0
	if check_tile_status(p) == -1: return true
	return false
