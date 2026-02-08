class_name ChessPiece
extends Node2D

enum PieceType { PAWN, ROOK, KNIGHT, BISHOP, QUEEN, KING }
enum PieceColor { WHITE, BLACK }

@export var piece_type: PieceType
@export var piece_color: PieceColor
var board_position: Vector2i
var has_moved: bool = false

# Modifiers applied by cards
var active_modifiers: Array[PieceModifier] = []

# Node references
@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

func _ready():
	update_visual()

func update_visual():
	# Update the label with piece letter
	if label:
		label.text = get_piece_letter()
		# Set label color based on piece color
		if piece_color == PieceColor.WHITE:
			label.add_theme_color_override("font_color", Color.WHITE)
		else:
			label.add_theme_color_override("font_color", Color.BLACK)
	
	# Try to load sprite if available
	update_sprite()

func update_sprite():
	# Load chess piece sprites from assets folder
	# Black pieces: pawn.png, rook.png, etc.
	# White pieces: pawn-3.png, rook-3.png, etc.
	var piece_name = get_piece_name()
	var suffix = "-3" if piece_color == PieceColor.WHITE else ""
	var sprite_path = "res://assets/%s%s.png" % [piece_name, suffix]
	
	if sprite and ResourceLoader.exists(sprite_path):
		sprite.texture = load(sprite_path)
		# Scale the sprite to fit the square nicely (adjust as needed)
		var texture_size = sprite.texture.get_size()
		var target_size = 100.0  # Target size in pixels
		var scale_factor = target_size / max(texture_size.x, texture_size.y)
		sprite.scale = Vector2(scale_factor, scale_factor)
		
		if label:
			label.visible = false  # Hide label if sprite exists
	else:
		# Use label as fallback if sprite not found
		print("Warning: Could not find sprite at path: ", sprite_path)
		if label:
			label.visible = true

func get_piece_name() -> String:
	match piece_type:
		PieceType.PAWN: return "pawn"
		PieceType.ROOK: return "rook"
		PieceType.KNIGHT: return "knight"
		PieceType.BISHOP: return "bishop"
		PieceType.QUEEN: return "queen"
		PieceType.KING: return "king"
		_: return "unknown"

func get_piece_letter() -> String:
	match piece_type:
		PieceType.PAWN: return "P"
		PieceType.ROOK: return "R"
		PieceType.KNIGHT: return "N"
		PieceType.BISHOP: return "B"
		PieceType.QUEEN: return "Q"
		PieceType.KING: return "K"
		_: return "?"

func get_possible_moves(board_state: Array) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	
	match piece_type:
		PieceType.PAWN:
			moves = get_pawn_moves(board_state)
		PieceType.ROOK:
			moves = get_rook_moves(board_state)
		PieceType.KNIGHT:
			moves = get_knight_moves(board_state)
		PieceType.BISHOP:
			moves = get_bishop_moves(board_state)
		PieceType.QUEEN:
			moves = get_queen_moves(board_state)
		PieceType.KING:
			moves = get_king_moves(board_state)
	
	# Apply modifiers from cards
	for modifier in active_modifiers:
		moves = modifier.apply_to_moves(self, moves, board_state)
	
	return moves

func add_modifier(modifier: PieceModifier):
	active_modifiers.append(modifier)
	print("Modifier added to piece at %s: %s (duration: %d)" % [board_position, modifier.modifier_id, modifier.duration])
	update_visual_effects()

func remove_modifier(modifier: PieceModifier):
	active_modifiers.erase(modifier)
	print("Modifier removed from piece at %s: %s" % [board_position, modifier.modifier_id])
	update_visual_effects()

func tick_modifiers():
	# Called at end of turn to update modifier durations
	for modifier in active_modifiers.duplicate():
		modifier.tick_duration()
		if modifier.is_expired():
			print("Modifier expired on piece at %s: %s" % [board_position, modifier.modifier_id])
			remove_modifier(modifier)

func has_modifier(modifier_id: String) -> bool:
	for modifier in active_modifiers:
		if modifier.modifier_id == modifier_id:
			return true
	return false

func update_visual_effects():
	# Visual feedback for active modifiers
	if active_modifiers.size() > 0:
		# Add a colored glow effect
		modulate = Color(1.2, 1.2, 0.8)  # Slight yellow glow
	else:
		modulate = Color(1.0, 1.0, 1.0)  # Normal

func get_pawn_moves(board_state: Array) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var direction = -1 if piece_color == PieceColor.WHITE else 1
	var start_row = 6 if piece_color == PieceColor.WHITE else 1
	
	# Move forward one square
	var forward_one = board_position + Vector2i(0, direction)
	if is_valid_position(forward_one) and board_state[forward_one.y][forward_one.x] == null:
		moves.append(forward_one)
		
		# Move forward two squares from starting position
		if board_position.y == start_row:
			var forward_two = board_position + Vector2i(0, direction * 2)
			if board_state[forward_two.y][forward_two.x] == null:
				moves.append(forward_two)
	
	# Capture diagonally
	for dx in [-1, 1]:
		var capture_pos = board_position + Vector2i(dx, direction)
		if is_valid_position(capture_pos):
			var target = board_state[capture_pos.y][capture_pos.x]
			if target != null and target.piece_color != piece_color:
				moves.append(capture_pos)
	
	return moves

func get_rook_moves(board_state: Array) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var directions = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	
	for direction in directions:
		moves.append_array(get_line_moves(board_state, direction))
	
	return moves

func get_bishop_moves(board_state: Array) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var directions = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	
	for direction in directions:
		moves.append_array(get_line_moves(board_state, direction))
	
	return moves

func get_queen_moves(board_state: Array) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	moves.append_array(get_rook_moves(board_state))
	moves.append_array(get_bishop_moves(board_state))
	return moves

func get_knight_moves(board_state: Array) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var knight_offsets = [
		Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1),
		Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2)
	]
	
	for offset in knight_offsets:
		var target_pos = board_position + offset
		if is_valid_position(target_pos):
			var target = board_state[target_pos.y][target_pos.x]
			if target == null or target.piece_color != piece_color:
				moves.append(target_pos)
	
	return moves

func get_king_moves(board_state: Array) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var king_offsets = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	
	for offset in king_offsets:
		var target_pos = board_position + offset
		if is_valid_position(target_pos):
			var target = board_state[target_pos.y][target_pos.x]
			if target == null or target.piece_color != piece_color:
				moves.append(target_pos)
	
	# TODO: Add castling logic
	
	return moves

func get_line_moves(board_state: Array, direction: Vector2i) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var current_pos = board_position + direction
	
	while is_valid_position(current_pos):
		var target = board_state[current_pos.y][current_pos.x]
		
		if target == null:
			moves.append(current_pos)
		else:
			if target.piece_color != piece_color:
				moves.append(current_pos)
			break
		
		current_pos += direction
	
	return moves

func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8
