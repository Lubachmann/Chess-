extends Node

# GameState - Manages multiplayer game state
# Tracks which player controls which color, current turn, etc.

class_name GameState

# Player assignments
var white_player_id: int = -1
var black_player_id: int = -1

# Game state
var is_multiplayer: bool = false
var local_player_color: ChessPiece.PieceColor = ChessPiece.PieceColor.WHITE
var current_turn: ChessPiece.PieceColor = ChessPiece.PieceColor.WHITE

# Signals
signal player_assignments_set(white_id: int, black_id: int)
signal game_started()

func _init():
	pass

# === SETUP FUNCTIONS ===

func setup_local_game():
	"""Setup for local (non-multiplayer) game"""
	is_multiplayer = false
	white_player_id = -1
	black_player_id = -1
	local_player_color = ChessPiece.PieceColor.WHITE
	current_turn = ChessPiece.PieceColor.WHITE
	print("GameState: Local game setup")

func setup_multiplayer_game():
	"""Setup for multiplayer game"""
	is_multiplayer = true
	
	# Assign colors based on peer IDs
	# Host (peer_id = 1) is always White
	# Client (peer_id != 1) is always Black
	var local_peer_id = NetworkManager.get_local_peer_id()
	
	if NetworkManager.is_server():
		# Host setup
		white_player_id = 1  # Host is always peer 1
		
		# Find the client's peer ID
		for peer_id in NetworkManager.connected_peers:
			if peer_id != 1:
				black_player_id = peer_id
				break
		
		local_player_color = ChessPiece.PieceColor.WHITE
		print("GameState: Host plays as WHITE, Client (ID: %d) plays as BLACK" % black_player_id)
	else:
		# Client setup
		white_player_id = 1  # Host
		black_player_id = local_peer_id
		local_player_color = ChessPiece.PieceColor.BLACK
		print("GameState: Client plays as BLACK, Host plays as WHITE")
	
	current_turn = ChessPiece.PieceColor.WHITE
	player_assignments_set.emit(white_player_id, black_player_id)

# === QUERY FUNCTIONS ===

func is_local_player_turn() -> bool:
	"""Check if it's the local player's turn"""
	if not is_multiplayer:
		return true  # In local game, always your turn
	
	return local_player_color == current_turn

func get_local_player_color() -> ChessPiece.PieceColor:
	"""Get the local player's color"""
	return local_player_color

func get_opponent_color() -> ChessPiece.PieceColor:
	"""Get the opponent's color"""
	if local_player_color == ChessPiece.PieceColor.WHITE:
		return ChessPiece.PieceColor.BLACK
	else:
		return ChessPiece.PieceColor.WHITE

func get_player_name(color: ChessPiece.PieceColor) -> String:
	"""Get player name by color"""
	if not is_multiplayer:
		return "White" if color == ChessPiece.PieceColor.WHITE else "Black"
	
	var peer_id = white_player_id if color == ChessPiece.PieceColor.WHITE else black_player_id
	return NetworkManager.get_player_name(peer_id)

func get_peer_id_for_color(color: ChessPiece.PieceColor) -> int:
	"""Get peer ID for a color"""
	if color == ChessPiece.PieceColor.WHITE:
		return white_player_id
	else:
		return black_player_id

# === STATE FUNCTIONS ===

func set_current_turn(color: ChessPiece.PieceColor):
	"""Set the current turn"""
	current_turn = color

func switch_turn():
	"""Switch to the other player's turn"""
	if current_turn == ChessPiece.PieceColor.WHITE:
		current_turn = ChessPiece.PieceColor.BLACK
	else:
		current_turn = ChessPiece.PieceColor.WHITE

# === VALIDATION FUNCTIONS ===

func can_interact_with_piece(piece: ChessPiece) -> bool:
	"""Check if local player can interact with a piece"""
	if not is_multiplayer:
		return true  # Local game - can interact with all pieces
	
	# In multiplayer, can only interact with own color
	return piece.piece_color == local_player_color

func is_valid_turn_for_piece(piece: ChessPiece) -> bool:
	"""Check if it's the correct turn for a piece"""
	return piece.piece_color == current_turn

# === UTILITY FUNCTIONS ===

func reset():
	"""Reset game state"""
	white_player_id = -1
	black_player_id = -1
	is_multiplayer = false
	local_player_color = ChessPiece.PieceColor.WHITE
	current_turn = ChessPiece.PieceColor.WHITE
