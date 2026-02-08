class_name ChessBoard
extends Control

const BOARD_SIZE = 8
const SQUARE_SIZE = 120

# Debug flag - set to false to disable debug prints
const DEBUG_MODE = false

# Color constants for visual feedback
const COLOR_LIGHT_SQUARE = Color(0.93, 0.85, 0.71)
const COLOR_DARK_SQUARE = Color(0.55, 0.42, 0.31)
const COLOR_HIGHLIGHT_MOVE = Color(0.0, 1.0, 0.0, 0.3)  # Semi-transparent green
const COLOR_HIGHLIGHT_TARGET = Color(1.0, 1.0, 0.0, 0.4)  # Semi-transparent yellow
const COLOR_HIGHLIGHT_SELECTED = Color(0.0, 1.0, 0.0, 0.6)  # Bright green
const COLOR_HIGHLIGHT_INVALID = Color(1.0, 0.0, 0.0, 0.5)  # Red

# Timing constants
const FLASH_DURATION = 0.3

# Game constants
const INVALID_POSITION = Vector2i(-1, -1)

# Board state: 2D array of ChessPiece references
var board_state: Array = []
var selected_piece: ChessPiece = null
var possible_moves: Array[Vector2i] = []
var current_turn: ChessPiece.PieceColor = ChessPiece.PieceColor.WHITE

# Multiplayer game state
var game_state: GameState = null

# Card system support
var double_move_piece: ChessPiece = null
var moves_made_this_turn: int = 0

# En passant tracking
var en_passant_target: Vector2i = INVALID_POSITION  # Position where en passant capture is possible
var last_moved_piece: ChessPiece = null

# Visual elements
var highlight_squares: Array[ColorRect] = []
var target_highlight_squares: Array[ColorRect] = []

# Network status overlay (optional)
var network_status_overlay: Control = null

# Move request tracking
var pending_move_from: Vector2i = INVALID_POSITION
var pending_move_to: Vector2i = INVALID_POSITION

signal piece_moved(piece: ChessPiece, from_pos: Vector2i, to_pos: Vector2i)
signal turn_changed(color: ChessPiece.PieceColor)
signal check_detected(color: ChessPiece.PieceColor)
signal checkmate(winner_color: ChessPiece.PieceColor)
signal stalemate()
signal piece_selected(piece: ChessPiece)

@onready var board_container: Node2D = $BoardContainer

func set_game_state(state: GameState):
	"""Set the game state for multiplayer support"""
	game_state = state

func set_network_status_overlay(overlay: Control):
	"""Set the network status overlay for visual feedback"""
	network_status_overlay = overlay

func _ready():
	# Set the size explicitly for input handling
	custom_minimum_size = Vector2(BOARD_SIZE * SQUARE_SIZE, BOARD_SIZE * SQUARE_SIZE)
	size = custom_minimum_size
	
	initialize_board()
	setup_pieces()
	draw_board()
	
	if DEBUG_MODE:
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
		if DEBUG_MODE:
			print("Global input received - mouse position: ", event.position)
		# Check if click is within our bounds
		var local_rect = Rect2(global_position, size)
		if local_rect.has_point(event.position):
			if DEBUG_MODE:
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
	if not is_valid_board_position(pos):
		push_error("Invalid board position for piece creation: %s" % pos)
		return
	
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
				square.color = COLOR_LIGHT_SQUARE
			else:
				square.color = COLOR_DARK_SQUARE
			
			board_container.add_child(square)
			board_container.move_child(square, 0)  # Move to back

func board_to_world_position(board_pos: Vector2i) -> Vector2:
	return Vector2(
		board_pos.x * SQUARE_SIZE + SQUARE_SIZE / 2,
		board_pos.y * SQUARE_SIZE + SQUARE_SIZE / 2
	)

func world_to_board_position(world_pos: Vector2) -> Vector2i:
	if world_pos.x < 0 or world_pos.y < 0:
		return INVALID_POSITION
	
	return Vector2i(
		int(world_pos.x / SQUARE_SIZE),
		int(world_pos.y / SQUARE_SIZE)
	)

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_local_mouse_position()
		if DEBUG_MODE:
			print("Mouse clicked at: ", mouse_pos)
		var board_pos = world_to_board_position(mouse_pos)
		if DEBUG_MODE:
			print("Board position: ", board_pos)
		
		if is_valid_board_position(board_pos):
			if DEBUG_MODE:
				print("Valid board position - handling click")
			handle_square_clicked(board_pos)
		else:
			if DEBUG_MODE:
				print("Invalid board position")

func handle_square_clicked(board_pos: Vector2i):
	# Handles user clicks on the chess board
	# Manages piece selection, moves, and double-move card logic
	
	# === MULTIPLAYER CHECK: Only allow interaction on your turn ===
	if game_state and game_state.is_multiplayer and not game_state.is_local_player_turn():
		if DEBUG_MODE:
			print("Not your turn - ignoring click")
		return
	
	if not is_valid_board_position(board_pos):
		push_error("Invalid board position clicked: %s" % board_pos)
		return
	
	var clicked_piece = board_state[board_pos.y][board_pos.x]
	
	# === CASE 1: Making a move with selected piece ===
	if selected_piece != null and board_pos in possible_moves:
		# In multiplayer, send move to host for validation
		if game_state and game_state.is_multiplayer:
			request_move(selected_piece.board_position, board_pos)
		else:
			# Local game - execute immediately
			execute_move(selected_piece.board_position, board_pos)
	
	# === CASE 2: Selecting a piece ===
	elif clicked_piece != null and clicked_piece.piece_color == current_turn:
		# === MULTIPLAYER CHECK: Can only select your own pieces ===
		if game_state and game_state.is_multiplayer:
			if not game_state.can_interact_with_piece(clicked_piece):
				if DEBUG_MODE:
					print("Cannot interact with opponent's pieces")
				return
		
		# Don't allow selecting a new piece during double move
		if double_move_piece != null and moves_made_this_turn == 1:
			# Must use the double move piece for second move
			if clicked_piece != double_move_piece:
				return
		select_piece(clicked_piece)
	
	# === CASE 3: Clicking empty square or opponent piece (deselect) ===
	else:
		deselect_piece()

func select_piece(piece: ChessPiece):
	deselect_piece()
	
	selected_piece = piece
	possible_moves = piece.get_possible_moves(board_state, en_passant_target)
	
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
		highlight.color = COLOR_HIGHLIGHT_MOVE
		
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
		highlight.color = COLOR_HIGHLIGHT_TARGET
		
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
	highlight.color = COLOR_HIGHLIGHT_SELECTED
	
	board_container.add_child(highlight)
	target_highlight_squares.append(highlight)

func flash_invalid_target(pos: Vector2i):
	# Flash red to show invalid selection
	var highlight = ColorRect.new()
	highlight.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
	highlight.position = Vector2(pos.x * SQUARE_SIZE, pos.y * SQUARE_SIZE)
	highlight.color = COLOR_HIGHLIGHT_INVALID
	
	board_container.add_child(highlight)
	
	# Remove after brief flash
	await get_tree().create_timer(FLASH_DURATION).timeout
	if is_instance_valid(highlight):  # Check if node still exists
		highlight.queue_free()

func move_piece(piece: ChessPiece, to_pos: Vector2i):
	# Executes a piece move, handling special cases like castling, en passant, and captures
	# This is the core function for moving pieces on the board
	
	if not is_valid_board_position(to_pos):
		push_error("Invalid destination position for move: %s" % to_pos)
		return
	
	var from_pos = piece.board_position
	if not is_valid_board_position(from_pos):
		push_error("Invalid source position for move: %s" % from_pos)
		return
	
	# === SPECIAL MOVE: Castling ===
	# Castling is detected by king moving 2 squares horizontally
	if piece.piece_type == ChessPiece.PieceType.KING and abs(to_pos.x - from_pos.x) == 2:
		perform_castling(piece, from_pos, to_pos)
		return
	
	# === SPECIAL CAPTURE: En Passant ===
	# En passant allows a pawn to capture an enemy pawn that just moved 2 squares
	var is_en_passant = false
	if piece.piece_type == ChessPiece.PieceType.PAWN and to_pos == en_passant_target:
		is_en_passant = true
		# Remove the captured pawn (it's beside the landing square, not on it)
		var captured_pawn_y = from_pos.y  # Same row as moving pawn
		var captured_pawn = board_state[captured_pawn_y][to_pos.x]
		if captured_pawn != null:
			captured_pawn.queue_free()
			board_state[captured_pawn_y][to_pos.x] = null
	
	# Reset en passant opportunity (will be set again if applicable)
	en_passant_target = INVALID_POSITION
	
	# === NORMAL CAPTURE ===
	var captured_piece = board_state[to_pos.y][to_pos.x]
	if captured_piece != null:
		# Check if piece has shield protection
		if captured_piece.has_modifier("shield"):
			if DEBUG_MODE:
				print("Cannot capture piece with shield at %s!" % to_pos)
			return  # Cancel the move
		captured_piece.queue_free()
	
	# === SET UP EN PASSANT for next turn ===
	# Check if pawn moved 2 squares (enable en passant for opponent)
	if piece.piece_type == ChessPiece.PieceType.PAWN and abs(to_pos.y - from_pos.y) == 2:
		# Set en passant target to the square the pawn passed over
		en_passant_target = Vector2i(from_pos.x, (from_pos.y + to_pos.y) / 2)
	
	# === UPDATE BOARD STATE ===
	board_state[from_pos.y][from_pos.x] = null
	board_state[to_pos.y][to_pos.x] = piece
	
	# === UPDATE PIECE ===
	piece.board_position = to_pos
	piece.position = board_to_world_position(to_pos)
	piece.has_moved = true
	last_moved_piece = piece
	
	piece_moved.emit(piece, from_pos, to_pos)
	
	# === CHECK FOR PAWN PROMOTION ===
	if piece.piece_type == ChessPiece.PieceType.PAWN:
		if (piece.piece_color == ChessPiece.PieceColor.WHITE and to_pos.y == 0) or \
		   (piece.piece_color == ChessPiece.PieceColor.BLACK and to_pos.y == 7):
			promote_pawn(piece)

func promote_pawn(pawn: ChessPiece):
	# Validate that the piece is actually a pawn
	if pawn == null:
		push_error("Cannot promote: pawn is null")
		return
	
	if pawn.piece_type != ChessPiece.PieceType.PAWN:
		push_error("Cannot promote: piece is not a pawn")
		return
	
	# For now, automatically promote to queen
	# TODO: Add UI for player to choose promotion piece
	pawn.piece_type = ChessPiece.PieceType.QUEEN
	pawn.update_sprite()

func perform_castling(king: ChessPiece, from_pos: Vector2i, to_pos: Vector2i):
	# Executes castling move, moving both king and rook
	# Castling is a special move where the king moves 2 squares and the rook jumps over it
	
	# Validate inputs
	if king == null:
		push_error("Castling failed: king is null")
		return
	
	if not is_valid_board_position(from_pos) or not is_valid_board_position(to_pos):
		push_error("Castling failed: invalid positions")
		return
	
	# Determine if kingside (O-O) or queenside (O-O-O) castling
	var is_kingside = to_pos.x > from_pos.x
	
	# Calculate positions
	# Kingside:  Rook at x=7, moves to x=5, King moves to x=6
	# Queenside: Rook at x=0, moves to x=3, King moves to x=2
	var rook_x = 7 if is_kingside else 0
	var rook_new_x = 5 if is_kingside else 3
	var king_new_x = 6 if is_kingside else 2
	
	# Get the rook
	var rook = board_state[from_pos.y][rook_x]
	if rook == null:
		push_error("Castling failed: Rook not found")
		return
	
	if rook.piece_type != ChessPiece.PieceType.ROOK:
		push_error("Castling failed: Piece at rook position is not a rook")
		return
	
	# === MOVE KING ===
	board_state[from_pos.y][from_pos.x] = null
	board_state[from_pos.y][king_new_x] = king
	king.board_position = Vector2i(king_new_x, from_pos.y)
	king.position = board_to_world_position(king.board_position)
	king.has_moved = true
	
	# === MOVE ROOK ===
	board_state[from_pos.y][rook_x] = null
	board_state[from_pos.y][rook_new_x] = rook
	rook.board_position = Vector2i(rook_new_x, from_pos.y)
	rook.position = board_to_world_position(rook.board_position)
	rook.has_moved = true
	
	last_moved_piece = king
	piece_moved.emit(king, from_pos, king.board_position)
	if DEBUG_MODE:
		print("Castling performed: %s" % ("Kingside" if is_kingside else "Queenside"))

func switch_turn():
	# Reset double move tracking
	double_move_piece = null
	moves_made_this_turn = 0
	
	# Check for check/checkmate on the opponent BEFORE switching turns
	# This ensures we're checking if the move that was just made put the opponent in check
	var opponent_color = ChessPiece.PieceColor.BLACK if current_turn == ChessPiece.PieceColor.WHITE else ChessPiece.PieceColor.WHITE
	
	if is_in_check(opponent_color):
		check_detected.emit(opponent_color)
		
		if is_checkmate(opponent_color):
			checkmate.emit(current_turn)  # Current player wins
			current_turn = opponent_color  # Still switch turn for UI consistency
			turn_changed.emit(current_turn)
			return
	
	# Check for stalemate
	if is_stalemate(opponent_color):
		stalemate.emit()
		current_turn = opponent_color  # Still switch turn for UI consistency
		turn_changed.emit(current_turn)
		return
	
	# Switch to next player's turn
	current_turn = opponent_color
	turn_changed.emit(current_turn)

func set_double_move_piece(piece: ChessPiece):
	if piece == null:
		push_error("Cannot set double move piece: piece is null")
		return
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
				var moves = piece.get_possible_moves(board_state, en_passant_target)
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
				var moves = piece.get_possible_moves(board_state, en_passant_target)
				var legal_moves = filter_moves_for_check(piece, moves)
				if legal_moves.size() > 0:
					return false
	
	return true

func is_stalemate(color: ChessPiece.PieceColor) -> bool:
	# Stalemate: player is not in check but has no legal moves
	if is_in_check(color):
		return false
	
	# Check if any piece of this color has a legal move
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var piece = board_state[y][x]
			if piece != null and piece.piece_color == color:
				var moves = piece.get_possible_moves(board_state, en_passant_target)
				var legal_moves = filter_moves_for_check(piece, moves)
				if legal_moves.size() > 0:
					return false
	
	return true

func filter_moves_for_check(piece: ChessPiece, moves: Array[Vector2i]) -> Array[Vector2i]:
	# Filters out moves that would leave the king in check
	# This is critical for chess rules - you cannot make a move that puts your own king in check
	var legal_moves: Array[Vector2i] = []
	
	for move in moves:
		# Check if target has shield (cannot capture shielded pieces)
		if is_valid_board_position(move):
			var target = board_state[move.y][move.x]
			if target != null and target.piece_color != piece.piece_color and target.has_modifier("shield"):
				continue  # Skip this move - can't capture shielded pieces
		
		if is_move_legal(piece, move):
			legal_moves.append(move)
	
	return legal_moves

func is_move_legal(piece: ChessPiece, to_pos: Vector2i) -> bool:
	# Checks if a move is legal by simulating it and checking if it leaves the king in check
	# Uses a simulate -> check -> undo pattern to avoid actually changing the game state
	
	# Validate positions before simulating
	if not is_valid_board_position(to_pos):
		return false
	
	var from_pos = piece.board_position
	if not is_valid_board_position(from_pos):
		return false
	
	# === SIMULATE THE MOVE ===
	var captured_piece = board_state[to_pos.y][to_pos.x]
	
	# Temporarily make the move on the board
	board_state[from_pos.y][from_pos.x] = null
	board_state[to_pos.y][to_pos.x] = piece
	var old_pos = piece.board_position
	piece.board_position = to_pos
	
	# === CHECK GAME STATE ===
	# Check if this puts/leaves the king in check
	var in_check = is_in_check(piece.piece_color)
	
	# === UNDO THE MOVE ===
	# Restore the board to its original state
	piece.board_position = old_pos
	board_state[from_pos.y][from_pos.x] = piece
	board_state[to_pos.y][to_pos.x] = captured_piece
	
	# Move is legal only if it doesn't leave the king in check
	return not in_check

# === MULTIPLAYER RPC FUNCTIONS ===

func request_move(from_pos: Vector2i, to_pos: Vector2i):
	"""Client requests to make a move"""
	if DEBUG_MODE:
		print("Requesting move: %s -> %s" % [from_pos, to_pos])
	
	# Store pending move
	pending_move_from = from_pos
	pending_move_to = to_pos
	
	if NetworkManager.is_server():
		# Host can execute directly
		execute_move(from_pos, to_pos)
	else:
		# Client sends request to host
		# Show validating feedback
		if network_status_overlay:
			network_status_overlay.show_move_validating()
		
		rpc_request_move.rpc_id(1, from_pos, to_pos)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_move(from_pos: Vector2i, to_pos: Vector2i):
	"""Host receives move request from client"""
	if not NetworkManager.is_server():
		return  # Only host processes this
	
	var sender_id = multiplayer.get_remote_sender_id()
	
	if DEBUG_MODE:
		print("Host received move request from peer %d: %s -> %s" % [sender_id, from_pos, to_pos])
	
	# Validate the move
	if not is_valid_board_position(from_pos) or not is_valid_board_position(to_pos):
		if DEBUG_MODE:
			print("Invalid positions - rejecting move")
		rpc_move_rejected.rpc_id(sender_id, "Invalid board position", from_pos)
		return
	
	var piece = board_state[from_pos.y][from_pos.x]
	if piece == null:
		if DEBUG_MODE:
			print("No piece at source position - rejecting move")
		rpc_move_rejected.rpc_id(sender_id, "No piece at source position", from_pos)
		return
	
	# Check if it's the correct turn
	if piece.piece_color != current_turn:
		if DEBUG_MODE:
			print("Not the piece's turn - rejecting move")
		rpc_move_rejected.rpc_id(sender_id, "Not your turn", from_pos)
		return
	
	# Check if sender controls this piece
	var piece_owner_id = game_state.get_peer_id_for_color(piece.piece_color)
	if sender_id != piece_owner_id:
		if DEBUG_MODE:
			print("Sender doesn't control this piece - rejecting move")
		rpc_move_rejected.rpc_id(sender_id, "Not your piece", from_pos)
		return
	
	# Validate move is in possible moves
	var moves = piece.get_possible_moves(board_state, en_passant_target)
	var legal_moves = filter_moves_for_check(piece, moves)
	
	if to_pos not in legal_moves:
		if DEBUG_MODE:
			print("Move not in legal moves - rejecting")
		rpc_move_rejected.rpc_id(sender_id, "Illegal move", from_pos)
		return
	
	# Move is valid - execute and broadcast
	execute_move(from_pos, to_pos)

func execute_move(from_pos: Vector2i, to_pos: Vector2i):
	"""Execute a move (local or after validation in multiplayer)"""
	var piece = board_state[from_pos.y][from_pos.x]
	if piece == null:
		if DEBUG_MODE:
			print("ERROR: No piece to move at %s" % from_pos)
		return
	
	if DEBUG_MODE:
		print("Executing move: %s -> %s" % [from_pos, to_pos])
	
	# Show move accepted feedback for clients
	if game_state and game_state.is_multiplayer and not NetworkManager.is_server():
		if network_status_overlay:
			network_status_overlay.show_move_accepted()
	
	# Clear pending move
	pending_move_from = INVALID_POSITION
	pending_move_to = INVALID_POSITION
	
	# Execute the move locally
	move_piece(piece, to_pos)
	moves_made_this_turn += 1
	
	# Broadcast to all clients (if multiplayer)
	if game_state and game_state.is_multiplayer:
		rpc_execute_move.rpc(from_pos, to_pos)
	
	# Handle double move or turn switch
	if double_move_piece == piece and moves_made_this_turn == 1:
		# Keep piece selected for second move
		select_piece(piece)
	else:
		# Either not a double move piece, or already made 2 moves
		deselect_piece()
		switch_turn()
		
		# Show waiting for opponent if it's not your turn
		if game_state and game_state.is_multiplayer and not game_state.is_local_player_turn():
			if network_status_overlay:
				network_status_overlay.show_waiting_for_opponent()

@rpc("authority", "call_remote", "reliable")
func rpc_execute_move(from_pos: Vector2i, to_pos: Vector2i):
	"""All clients execute the validated move"""
	if DEBUG_MODE:
		print("Received execute_move RPC: %s -> %s" % [from_pos, to_pos])
	
	var piece = board_state[from_pos.y][from_pos.x]
	if piece == null:
		push_error("RPC execute_move: No piece at source position")
		return
	
	# Hide status overlay
	if network_status_overlay:
		network_status_overlay.hide_status()
	
	# Execute the move
	move_piece(piece, to_pos)
	moves_made_this_turn += 1
	
	# Handle double move or turn switch
	if double_move_piece == piece and moves_made_this_turn == 1:
		select_piece(piece)
	else:
		deselect_piece()
		switch_turn()
		
		# Show waiting for opponent if it's not your turn
		if game_state and game_state.is_multiplayer and not game_state.is_local_player_turn():
			if network_status_overlay:
				network_status_overlay.show_waiting_for_opponent()

@rpc("authority", "call_remote", "reliable")
func rpc_move_rejected(reason: String, from_pos: Vector2i):
	"""Client receives move rejection from host"""
	if DEBUG_MODE:
		print("Move rejected: %s" % reason)
	
	# Show rejection feedback
	if network_status_overlay:
		network_status_overlay.show_move_rejected(reason)
	
	# Clear pending move
	pending_move_from = INVALID_POSITION
	pending_move_to = INVALID_POSITION
	
	# Deselect piece to reset state
	deselect_piece()

