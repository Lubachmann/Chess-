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

func tick_duration():
	if duration > 0:
		duration -= 1

func is_expired() -> bool:
	return duration == 0
