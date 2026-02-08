class_name ChessBoard
extends Control

const BOARD_SIZE = 8
const SQUARE_SIZE = 120

# Board state: 2D array of ChessPiece references
var board_state: Array = []
var selected_piece: ChessPiece = null
var possible_moves: Array[Vector2i] = []
var current_turn: ChessPiece.PieceColor = ChessPiece.PieceColor.WHITE

# Card system support
var double_move_piece: ChessPiece = null
var moves_made_this_turn: int = 0

# Visual elements
var highlight_squares: Array[ColorRect] = []
var target_highlight_squares: Array[ColorRect] = []

signal piece_moved(piece: ChessPiece, from_pos: Vector2i, to_pos: Vector2i)
signal turn_changed(color: ChessPiece.PieceColor)
signal check_detected(color: ChessPiece.PieceColor)
signal checkmate(winner_color: ChessPiece.PieceColor)
signal piece_selected(piece: ChessPiece)

@onready var board_container: Node2D = $BoardContainer

func _ready():
	# Set the size explicitly for input handling
	custom_minimum_size = Vector2(BOARD_SIZE * SQUARE_SIZE, BOARD_SIZE * SQUARE_SIZE)
	size = custom_minimum_size
	
	initialize_board()
	setup_pieces()
	draw_board()
	
	print("=== ChessBoard _ready() called ===")
	print("Size: ", size)
	print("Position: ", position)
	print("Global position: ", global_position)
	print("Minimum size: ", custom_minimum_size)
	print("Mouse filter: ", mouse_filter)
	print("=================================")

func _input(event):
	# Try using global _input as a fallback
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Global input received - mouse position: ", event.position)
		# Check if click is within our bounds
		var local_rect = Rect2(global_position, size)
		if local_rect.has_point(event.position):
			print("Click is within ChessBoard bounds!")
			var local_pos = event.position - global_position
			var board_pos = world_to_board_position(local_pos)
			if is_valid_board_position(board_pos):
				handle_square_clicked(board_pos)
				get_viewport().set_input_as_handled()

func initialize_board():
	# Initialize 8x8 board with nulls
	board_state.clear()
	for y in range(BOARD_SIZE):
		var row = []
		for x in range(BOARD_SIZE):
			row.append(null)
		board_state.append(row)

func setup_pieces():
	# Setup black pieces (top of board)
	create_piece(ChessPiece.PieceType.ROOK, ChessPiece.PieceColor.BLACK, Vector2i(0, 0))
	create_piece(ChessPiece.PieceType.KNIGHT, ChessPiece.PieceColor.BLACK, Vector2i(1, 0))
	create_piece(ChessPiece.PieceType.BISHOP, ChessPiece.PieceColor.BLACK, Vector2i(2, 0))
	create_piece(ChessPiece.PieceType.QUEEN, ChessPiece.PieceColor.BLACK, Vector2i(3, 0))
	create_piece(ChessPiece.PieceType.KING, ChessPiece.PieceColor.BLACK, Vector2i(4, 0))
	create_piece(ChessPiece.PieceType.BISHOP, ChessPiece.PieceColor.BLACK, Vector2i(5, 0))
	create_piece(ChessPiece.PieceType.KNIGHT, ChessPiece.PieceColor.BLACK, Vector2i(6, 0))
	create_piece(ChessPiece.PieceType.ROOK, ChessPiece.PieceColor.BLACK, Vector2i(7, 0))
	
	# Black pawns
	for x in range(BOARD_SIZE):
		create_piece(ChessPiece.PieceType.PAWN, ChessPiece.PieceColor.BLACK, Vector2i(x, 1))
	
	# Setup white pieces (bottom of board)
	create_piece(ChessPiece.PieceType.ROOK, ChessPiece.PieceColor.WHITE, Vector2i(0, 7))
	create_piece(ChessPiece.PieceType.KNIGHT, ChessPiece.PieceColor.WHITE, Vector2i(1, 7))
	create_piece(ChessPiece.PieceType.BISHOP, ChessPiece.PieceColor.WHITE, Vector2i(2, 7))
	create_piece(ChessPiece.PieceType.QUEEN, ChessPiece.PieceColor.WHITE, Vector2i(3, 7))
	create_piece(ChessPiece.PieceType.KING, ChessPiece.PieceColor.WHITE, Vector2i(4, 7))
	create_piece(ChessPiece.PieceType.BISHOP, ChessPiece.PieceColor.WHITE, Vector2i(5, 7))
	create_piece(ChessPiece.PieceType.KNIGHT, ChessPiece.PieceColor.WHITE, Vector2i(6, 7))
	create_piece(ChessPiece.PieceType.ROOK, ChessPiece.PieceColor.WHITE, Vector2i(7, 7))
	
	# White pawns
	for x in range(BOARD_SIZE):
		create_piece(ChessPiece.PieceType.PAWN, ChessPiece.PieceColor.WHITE, Vector2i(x, 6))

func create_piece(type: ChessPiece.PieceType, color: ChessPiece.PieceColor, pos: Vector2i):
	var piece_scene = preload("res://scenes/chess_piece.tscn")
	var piece = piece_scene.instantiate()
	piece.piece_type = type
	piece.piece_color = color
	piece.board_position = pos
	piece.position = board_to_world_position(pos)
	
	board_container.add_child(piece)
	board_state[pos.y][pos.x] = piece

func draw_board():
	# Draw checkerboard pattern
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var square = ColorRect.new()
			square.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
			square.position = Vector2(x * SQUARE_SIZE, y * SQUARE_SIZE)
			
			# Alternate colors
			if (x + y) % 2 == 0:
				square.color = Color(0.93, 0.85, 0.71)  # Light square
			else:
				square.color = Color(0.55, 0.42, 0.31)  # Dark square
			
			board_container.add_child(square)
			board_container.move_child(square, 0)  # Move to back

func board_to_world_position(board_pos: Vector2i) -> Vector2:
	return Vector2(
		board_pos.x * SQUARE_SIZE + SQUARE_SIZE / 2,
		board_pos.y * SQUARE_SIZE + SQUARE_SIZE / 2
	)

func world_to_board_position(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / SQUARE_SIZE),
		int(world_pos.y / SQUARE_SIZE)
	)

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_local_mouse_position()
		print("Mouse clicked at: ", mouse_pos)
		var board_pos = world_to_board_position(mouse_pos)
		print("Board position: ", board_pos)
		
		if is_valid_board_position(board_pos):
			print("Valid board position - handling click")
			handle_square_clicked(board_pos)
		else:
			print("Invalid board position")

func handle_square_clicked(board_pos: Vector2i):
	var clicked_piece = board_state[board_pos.y][board_pos.x]
	
	# If a piece is selected and we clicked a valid move square
	if selected_piece != null and board_pos in possible_moves:
		move_piece(selected_piece, board_pos)
		moves_made_this_turn += 1
		
		# Check if piece can move again (double move effect)
		if double_move_piece == selected_piece and moves_made_this_turn < 2:
			# Keep piece selected for second move
			select_piece(selected_piece)
		else:
			deselect_piece()
			switch_turn()
	# If we clicked on a piece of the current player's color
	elif clicked_piece != null and clicked_piece.piece_color == current_turn:
		select_piece(clicked_piece)
	# Otherwise deselect
	else:
		deselect_piece()

func select_piece(piece: ChessPiece):
	deselect_piece()
	
	selected_piece = piece
	possible_moves = piece.get_possible_moves(board_state)
	
	# Filter out moves that would put own king in check
	possible_moves = filter_moves_for_check(piece, possible_moves)
	
	show_possible_moves()
	
	# Emit signal for card targeting
	piece_selected.emit(piece)

func deselect_piece():
	selected_piece = null
	possible_moves.clear()
	clear_highlights()

func show_possible_moves():
	clear_highlights()
	
	for move_pos in possible_moves:
		var highlight = ColorRect.new()
		highlight.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
		highlight.position = Vector2(move_pos.x * SQUARE_SIZE, move_pos.y * SQUARE_SIZE)
		highlight.color = Color(0.0, 1.0, 0.0, 0.3)  # Semi-transparent green
		
		board_container.add_child(highlight)
		highlight_squares.append(highlight)

func clear_highlights():
	for highlight in highlight_squares:
		highlight.queue_free()
	highlight_squares.clear()

# Card targeting visual feedback functions
func show_target_highlights(target_positions: Array[Vector2i]):
	clear_target_highlights()
	
	for pos in target_positions:
		var highlight = ColorRect.new()
		highlight.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
		highlight.position = Vector2(pos.x * SQUARE_SIZE, pos.y * SQUARE_SIZE)
		highlight.color = Color(1.0, 1.0, 0.0, 0.4)  # Semi-transparent yellow
		
		board_container.add_child(highlight)
		target_highlight_squares.append(highlight)

func clear_target_highlights():
	for highlight in target_highlight_squares:
		highlight.queue_free()
	target_highlight_squares.clear()

func show_target_selected(pos: Vector2i):
	# Add a bright highlight to show the selected target
	var highlight = ColorRect.new()
	highlight.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
	highlight.position = Vector2(pos.x * SQUARE_SIZE, pos.y * SQUARE_SIZE)
	highlight.color = Color(0.0, 1.0, 0.0, 0.6)  # Bright green
	
	board_container.add_child(highlight)
	target_highlight_squares.append(highlight)

func flash_invalid_target(pos: Vector2i):
	# Flash red to show invalid selection
	var highlight = ColorRect.new()
	highlight.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
	highlight.position = Vector2(pos.x * SQUARE_SIZE, pos.y * SQUARE_SIZE)
	highlight.color = Color(1.0, 0.0, 0.0, 0.5)  # Red
	
	board_container.add_child(highlight)
	
	# Remove after brief flash
	await get_tree().create_timer(0.3).timeout
	highlight.queue_free()

func move_piece(piece: ChessPiece, to_pos: Vector2i):
	var from_pos = piece.board_position
	
	# Capture piece if present
	var captured_piece = board_state[to_pos.y][to_pos.x]
	if captured_piece != null:
		captured_piece.queue_free()
	
	# Update board state
	board_state[from_pos.y][from_pos.x] = null
	board_state[to_pos.y][to_pos.x] = piece
	
	# Update piece
	piece.board_position = to_pos
	piece.position = board_to_world_position(to_pos)
	piece.has_moved = true
	
	piece_moved.emit(piece, from_pos, to_pos)
	
	# Check for pawn promotion
	if piece.piece_type == ChessPiece.PieceType.PAWN:
		if (piece.piece_color == ChessPiece.PieceColor.WHITE and to_pos.y == 0) or \
		   (piece.piece_color == ChessPiece.PieceColor.BLACK and to_pos.y == 7):
			promote_pawn(piece)

func promote_pawn(pawn: ChessPiece):
	# For now, automatically promote to queen
	# TODO: Add UI for player to choose promotion piece
	pawn.piece_type = ChessPiece.PieceType.QUEEN
	pawn.update_sprite()

func switch_turn():
	# Reset double move tracking
	double_move_piece = null
	moves_made_this_turn = 0
	
	current_turn = ChessPiece.PieceColor.BLACK if current_turn == ChessPiece.PieceColor.WHITE else ChessPiece.PieceColor.WHITE
	turn_changed.emit(current_turn)
	
	# Check for check/checkmate
	if is_in_check(current_turn):
		check_detected.emit(current_turn)
		
		if is_checkmate(current_turn):
			var winner = ChessPiece.PieceColor.BLACK if current_turn == ChessPiece.PieceColor.WHITE else ChessPiece.PieceColor.WHITE
			checkmate.emit(winner)

func set_double_move_piece(piece: ChessPiece):
	double_move_piece = piece

func is_valid_board_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < BOARD_SIZE and pos.y >= 0 and pos.y < BOARD_SIZE

func find_king(color: ChessPiece.PieceColor) -> ChessPiece:
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var piece = board_state[y][x]
			if piece != null and piece.piece_type == ChessPiece.PieceType.KING and piece.piece_color == color:
				return piece
	return null

func is_in_check(color: ChessPiece.PieceColor) -> bool:
	var king = find_king(color)
	if king == null:
		return false
	
	var king_pos = king.board_position
	
	# Check if any opponent piece can attack the king
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var piece = board_state[y][x]
			if piece != null and piece.piece_color != color:
				var moves = piece.get_possible_moves(board_state)
				if king_pos in moves:
					return true
	
	return false

func is_checkmate(color: ChessPiece.PieceColor) -> bool:
	if not is_in_check(color):
		return false
	
	# Check if any piece of this color has a legal move
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var piece = board_state[y][x]
			if piece != null and piece.piece_color == color:
				var moves = piece.get_possible_moves(board_state)
				var legal_moves = filter_moves_for_check(piece, moves)
				if legal_moves.size() > 0:
					return false
	
	return true

func filter_moves_for_check(piece: ChessPiece, moves: Array[Vector2i]) -> Array[Vector2i]:
	var legal_moves: Array[Vector2i] = []
	
	for move in moves:
		if is_move_legal(piece, move):
			legal_moves.append(move)
	
	return legal_moves

func is_move_legal(piece: ChessPiece, to_pos: Vector2i) -> bool:
	# Simulate the move
	var from_pos = piece.board_position
	var captured_piece = board_state[to_pos.y][to_pos.x]
	
	# Make the move
	board_state[from_pos.y][from_pos.x] = null
	board_state[to_pos.y][to_pos.x] = piece
	var old_pos = piece.board_position
	piece.board_position = to_pos
	
	# Check if this puts/leaves the king in check
	var in_check = is_in_check(piece.piece_color)
	
	# Undo the move
	piece.board_position = old_pos
	board_state[from_pos.y][from_pos.x] = piece
	board_state[to_pos.y][to_pos.x] = captured_piece
	
	return not in_check
