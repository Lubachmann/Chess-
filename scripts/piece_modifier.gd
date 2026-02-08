class_name PieceModifier
extends Resource

# Modifier that can be applied to chess pieces to change their behavior

var modifier_id: String
var duration: int  # Turns remaining (-1 = permanent, 0 = expired)
var source_card: Card  # Reference to the card that created this modifier
var effect_data: Dictionary = {}

func _init(p_id: String, p_duration: int, p_card: Card = null, p_data: Dictionary = {}):
	modifier_id = p_id
	duration = p_duration
	source_card = p_card
	effect_data = p_data

func apply_to_moves(piece: ChessPiece, base_moves: Array[Vector2i], board_state: Array) -> Array[Vector2i]:
	# Override this in specific implementations or handle via effect_id
	match modifier_id:
		"forward_strike":
			return add_forward_strike(piece, base_moves, board_state)
		"double_move":
			# This is handled differently (allows two moves)
			return base_moves
		"freeze":
			# Frozen pieces can't move
			return []
		"knight_leap":
			return add_knight_moves(piece, base_moves, board_state)
		"long_range":
			return add_long_range(piece, base_moves, board_state)
		"backstep":
			return add_tactical_retreat(piece, base_moves, board_state)
		"shield":
			# Shield doesn't modify moves, it's checked during capture
			return base_moves
		_:
			return base_moves

func add_forward_strike(piece: ChessPiece, base_moves: Array[Vector2i], board_state: Array) -> Array[Vector2i]:
	# Pawn can capture forward
	if piece.piece_type != ChessPiece.PieceType.PAWN:
		return base_moves
	
	var moves = base_moves.duplicate()
	var direction = -1 if piece.piece_color == ChessPiece.PieceColor.WHITE else 1
	var forward_pos = piece.board_position + Vector2i(0, direction)
	
	if piece.is_valid_position(forward_pos):
		var target = board_state[forward_pos.y][forward_pos.x]
		if target != null and target.piece_color != piece.piece_color:
			moves.append(forward_pos)
	
	return moves

func add_knight_moves(piece: ChessPiece, base_moves: Array[Vector2i], board_state: Array) -> Array[Vector2i]:
	# Any piece can also move like a knight once
	var moves = base_moves.duplicate()
	var knight_offsets = [
		Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1),
		Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2)
	]
	
	for offset in knight_offsets:
		var target_pos = piece.board_position + offset
		if piece.is_valid_position(target_pos):
			var target = board_state[target_pos.y][target_pos.x]
			if target == null or target.piece_color != piece.piece_color:
				if target_pos not in moves:
					moves.append(target_pos)
	
	return moves

func add_long_range(piece: ChessPiece, base_moves: Array[Vector2i], board_state: Array) -> Array[Vector2i]:
	# Piece can move 2 extra squares in any direction it can already move
	var moves = base_moves.duplicate()
	
	# For each base move, try to extend it further in the same direction
	for base_move in base_moves:
		var direction = base_move - piece.board_position
		var distance = max(abs(direction.x), abs(direction.y))
		
		if distance > 0:
			# Normalize direction (get unit vector in that direction)
			var unit_dir = Vector2i(
				sign(direction.x) if direction.x != 0 else 0,
				sign(direction.y) if direction.y != 0 else 0
			)
			
			# Try adding 1 and 2 more squares
			for extra in [1, 2]:
				var extended_pos = base_move + (unit_dir * extra)
				if piece.is_valid_position(extended_pos):
					var target = board_state[extended_pos.y][extended_pos.x]
					if target == null:
						if extended_pos not in moves:
							moves.append(extended_pos)
					elif target.piece_color != piece.piece_color:
						# Can capture but can't go further
						if extended_pos not in moves:
							moves.append(extended_pos)
						break
					else:
						# Friendly piece blocks
						break
	
	return moves

func add_tactical_retreat(piece: ChessPiece, base_moves: Array[Vector2i], board_state: Array) -> Array[Vector2i]:
	# Piece can move backwards (relative to its forward direction)
	var moves = base_moves.duplicate()
	
	# Determine "backwards" based on piece color
	var backward_direction = 1 if piece.piece_color == ChessPiece.PieceColor.WHITE else -1
	
	# Add backward moves based on piece type
	match piece.piece_type:
		ChessPiece.PieceType.PAWN:
			# Pawn can move backwards 1-2 squares
			for dist in [1, 2]:
				var backward_pos = piece.board_position + Vector2i(0, backward_direction * dist)
				if piece.is_valid_position(backward_pos):
					var target = board_state[backward_pos.y][backward_pos.x]
					if target == null and backward_pos not in moves:
						moves.append(backward_pos)
					elif dist == 1:
						break  # Can't jump over pieces
		
		ChessPiece.PieceType.KING, ChessPiece.PieceType.QUEEN:
			# Add backwards line moves (like a rook backwards)
			var backward_pos = piece.board_position + Vector2i(0, backward_direction)
			while piece.is_valid_position(backward_pos):
				var target = board_state[backward_pos.y][backward_pos.x]
				if target == null:
					if backward_pos not in moves:
						moves.append(backward_pos)
				else:
					if target.piece_color != piece.piece_color and backward_pos not in moves:
						moves.append(backward_pos)
					break
				backward_pos += Vector2i(0, backward_direction)
		
		_:
			# Other pieces get a single backward move
			var backward_pos = piece.board_position + Vector2i(0, backward_direction)
			if piece.is_valid_position(backward_pos):
				var target = board_state[backward_pos.y][backward_pos.x]
				if (target == null or target.piece_color != piece.piece_color) and backward_pos not in moves:
					moves.append(backward_pos)
	
	return moves

func tick_duration():
	if duration > 0:
		duration -= 1

func is_expired() -> bool:
	return duration == 0
