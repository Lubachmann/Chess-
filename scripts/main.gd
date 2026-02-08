extends Control

# Debug flag - set to false to disable debug prints
const DEBUG_MODE = false

@onready var chess_board = $VBoxContainer/BoardArea/ChessBoard
@onready var turn_label = $VBoxContainer/TopArea/MarginContainer/HBoxContainer/TurnLabel
@onready var status_label = $VBoxContainer/TopArea/MarginContainer/StatusLabel
@onready var hand_display = $VBoxContainer/BottomArea/MarginContainer/VBoxContainer/HandDisplay
@onready var deck_info_label = $VBoxContainer/TopArea/MarginContainer/HBoxContainer/DeckInfo
@onready var network_status_overlay = $NetworkStatusOverlay

# Player decks
var white_deck: Deck
var black_deck: Deck

# Game state (local and multiplayer)
var game_state: GameState
var selected_card: Card = null
var awaiting_target: bool = false
var card_played_this_turn: bool = false

# Swap card needs two targets
var swap_first_piece: ChessPiece = null
var swap_awaiting_second: bool = false

func _ready():
	# Initialize game state
	game_state = GameState.new()
	
	# Check if this is a multiplayer game
	if NetworkManager.is_multiplayer_active():
		game_state.setup_multiplayer_game()
		
		# Connect to network disconnection signals
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
		NetworkManager.server_disconnected.connect(_on_server_disconnected)
	else:
		game_state.setup_local_game()
	
	# Connect to chess board signals
	chess_board.turn_changed.connect(_on_turn_changed)
	chess_board.check_detected.connect(_on_check_detected)
	chess_board.checkmate.connect(_on_checkmate)
	chess_board.stalemate.connect(_on_stalemate)
	chess_board.piece_selected.connect(_on_piece_selected)
	
	# Pass game state to chess board
	chess_board.set_game_state(game_state)
	
	# Pass network status overlay to chess board
	if NetworkManager.is_multiplayer_active():
		chess_board.set_network_status_overlay(network_status_overlay)
		
		# Show waiting for opponent if it's not your turn
		if not game_state.is_local_player_turn():
			network_status_overlay.show_waiting_for_opponent()
	
	# Initialize decks
	white_deck = Deck.new()
	black_deck = Deck.new()
	
	# Draw initial hands
	white_deck.draw_initial_hand(3)
	black_deck.draw_initial_hand(3)
	
	# Connect hand display
	hand_display.card_selected.connect(_on_card_selected)
	
	# Initialize UI
	update_turn_label()
	status_label.text = ""
	update_hand_display()
	update_deck_info()

func update_turn_label():
	"""Update the turn label based on game state"""
	var color = game_state.current_turn
	var player_name = game_state.get_player_name(color)
	
	if game_state.is_multiplayer:
		if game_state.is_local_player_turn():
			turn_label.text = "🟢 Your Turn (%s)" % player_name
			turn_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			turn_label.text = "⏸ %s's Turn (Waiting...)" % player_name
			turn_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		turn_label.text = "%s's Turn" % player_name
		turn_label.remove_theme_color_override("font_color")

func _on_turn_changed(color: ChessPiece.PieceColor):
	game_state.set_current_turn(color)
	update_turn_label()
	status_label.text = ""
	
	# Only draw cards and update modifiers if it's local player's turn or local game
	if not game_state.is_multiplayer or game_state.is_local_player_turn():
		# Draw card at start of turn
		var current_deck = white_deck if color == ChessPiece.PieceColor.WHITE else black_deck
		current_deck.draw_card()
		
		# Reset card played flag
		card_played_this_turn = false
		
		# Tick down modifiers on all pieces
		tick_all_modifiers(color)
		
		update_hand_display()
		update_deck_info()
		
		# Hide waiting overlay when it's your turn
		if game_state.is_multiplayer:
			network_status_overlay.hide_status()
	
	if DEBUG_MODE:
		print("Turn changed to: %s" % game_state.get_player_name(color))

func _on_check_detected(color: ChessPiece.PieceColor):
	var player_name = game_state.get_player_name(color)
	status_label.text = "%s is in CHECK!" % player_name
	status_label.add_theme_color_override("font_color", Color.RED)
	if DEBUG_MODE:
		print("%s is in check!" % player_name)

func _on_checkmate(winner_color: ChessPiece.PieceColor):
	var winner_name = game_state.get_player_name(winner_color)
	status_label.text = "CHECKMATE! %s WINS!" % winner_name
	status_label.add_theme_color_override("font_color", Color.GOLD)
	if DEBUG_MODE:
		print("Checkmate! %s wins!" % winner_name)

func _on_stalemate():
	status_label.text = "STALEMATE! It's a Draw!"
	status_label.add_theme_color_override("font_color", Color.ORANGE)
	if DEBUG_MODE:
		print("Stalemate! The game is a draw.")

func _on_card_selected(card: Card):
	if DEBUG_MODE:
		print("Main: Card selected - ", card.card_name)
	
	# Check if it's your turn in multiplayer
	if game_state.is_multiplayer and not game_state.is_local_player_turn():
		status_label.text = "Not your turn!"
		return
	
	if card_played_this_turn:
		status_label.text = "Already played a card this turn!"
		if DEBUG_MODE:
			print("Cannot play card - already played this turn")
		return
	
	selected_card = card
	
	if card.requires_target():
		awaiting_target = true
		status_label.text = "Select a %s to target..." % get_target_type_name(card.target_type)
		if DEBUG_MODE:
			print("Waiting for target selection for card: %s" % card.card_name)
		
		# Highlight valid targets on the board
		highlight_valid_targets(card)
	else:
		# Play card immediately
		if DEBUG_MODE:
			print("Playing card without target")
		play_card(card, null)

func highlight_valid_targets(card: Card, exclude_piece: ChessPiece = null):
	# Tell the chess board to highlight valid target pieces
	# Optional exclude_piece parameter for swap card's second selection
	var valid_targets: Array[Vector2i] = []
	
	for y in range(8):
		for x in range(8):
			var piece = chess_board.board_state[y][x]
			if piece != null and piece != exclude_piece and is_valid_target(card, piece):
				valid_targets.append(Vector2i(x, y))
	
	chess_board.show_target_highlights(valid_targets)
	if DEBUG_MODE:
		if exclude_piece:
			print("Highlighting %d valid targets (excluding first piece)" % valid_targets.size())
		else:
			print("Highlighting %d valid targets" % valid_targets.size())

# Deprecated: kept for backward compatibility, now calls highlight_valid_targets with exclude parameter
func highlight_valid_targets_except(card: Card, exclude_piece: ChessPiece):
	highlight_valid_targets(card, exclude_piece)

func _on_piece_selected(piece: ChessPiece):
	if DEBUG_MODE:
		print("Piece selected: ", piece.board_position, " Color: ", piece.piece_color)
	
	if awaiting_target and selected_card:
		if DEBUG_MODE:
			print("Checking if valid target for card: ", selected_card.card_name)
		
		# Special handling for Swap card (needs 2 targets)
		if selected_card.effect_id == "swap":
			if not swap_awaiting_second:
				# First piece selected
				if is_valid_target(selected_card, piece):
					swap_first_piece = piece
					swap_awaiting_second = true
					
					chess_board.show_target_selected(piece.board_position)
					status_label.text = "Now select second piece to swap with..."
					if DEBUG_MODE:
						print("First piece selected for swap: ", piece.board_position)
					
					# Re-highlight valid targets (excluding the first piece)
					highlight_valid_targets_except(selected_card, piece)
				else:
					status_label.text = "Invalid target! Card needs: %s" % get_target_type_name(selected_card.target_type)
					chess_board.flash_invalid_target(piece.board_position)
			else:
				# Second piece selected
				if is_valid_target(selected_card, piece) and piece != swap_first_piece:
					if DEBUG_MODE:
						print("Second piece selected for swap: ", piece.board_position)
					chess_board.show_target_selected(piece.board_position)
					
					await get_tree().create_timer(0.3).timeout
					
					# Perform the swap
					play_swap_card(selected_card, swap_first_piece, piece)
					
					# Reset swap state
					swap_first_piece = null
					swap_awaiting_second = false
					chess_board.clear_target_highlights()
				else:
					if piece == swap_first_piece:
						status_label.text = "Can't swap a piece with itself!"
					else:
						status_label.text = "Invalid target!"
					chess_board.flash_invalid_target(piece.board_position)
		else:
			# Normal single-target cards
			if is_valid_target(selected_card, piece):
				if DEBUG_MODE:
					print("Valid target! Playing card.")
				
				chess_board.show_target_selected(piece.board_position)
				await get_tree().create_timer(0.3).timeout
				
				play_card(selected_card, piece)
				chess_board.clear_target_highlights()
			else:
				status_label.text = "Invalid target! Card needs: %s" % get_target_type_name(selected_card.target_type)
				if DEBUG_MODE:
					print("Invalid target!")
				chess_board.flash_invalid_target(piece.board_position)
	else:
		if DEBUG_MODE:
			if awaiting_target:
				print("Waiting for target but no card selected")
			else:
				print("Not waiting for target")

func get_target_type_name(target_type: Card.TargetType) -> String:
	match target_type:
		Card.TargetType.OWN_PIECE:
			return "Your own piece"
		Card.TargetType.ENEMY_PIECE:
			return "Enemy piece"
		Card.TargetType.ANY_PIECE:
			return "Any piece"
		_:
			return "Unknown"

func is_valid_target(card: Card, piece: ChessPiece) -> bool:
	if card == null or piece == null:
		return false
	
	var current_color = chess_board.current_turn
	
	match card.target_type:
		Card.TargetType.OWN_PIECE:
			return piece.piece_color == current_color
		Card.TargetType.ENEMY_PIECE:
			return piece.piece_color != current_color
		Card.TargetType.ANY_PIECE:
			return true
		_:
			return false

func play_card(card: Card, target: ChessPiece):
	if card == null:
		push_error("Cannot play card: card is null")
		return
	
	var current_deck = white_deck if chess_board.current_turn == ChessPiece.PieceColor.WHITE else black_deck
	
	if not current_deck.play_card(card):
		if DEBUG_MODE:
			print("Failed to play card!")
		status_label.text = "Failed to play card!"
		return
	
	if DEBUG_MODE:
		print("Playing card: %s" % card.card_name)
	
	# Get target position (null target if no targeting)
	var target_pos = target.board_position if target else Vector2i(-1, -1)
	
	# In multiplayer, broadcast card play to all
	if game_state.is_multiplayer:
		# Apply locally first
		apply_card_effect(card, target)
		# Broadcast to others
		rpc_play_card.rpc(card.effect_id, target_pos)
	else:
		# Local game - just apply
		apply_card_effect(card, target)
	
	# Reset selection
	selected_card = null
	awaiting_target = false
	card_played_this_turn = true
	
	# Clear target highlights
	chess_board.clear_target_highlights()
	
	# Discard the card
	current_deck.return_to_deck(card)
	
	# Update display
	update_hand_display()
	status_label.text = "Played: %s" % card.card_name

func play_swap_card(card: Card, piece1: ChessPiece, piece2: ChessPiece):
	if card == null or piece1 == null or piece2 == null:
		push_error("Cannot play swap card: invalid parameters")
		return
	
	if piece1 == piece2:
		push_error("Cannot swap a piece with itself")
		return
	
	var current_deck = white_deck if chess_board.current_turn == ChessPiece.PieceColor.WHITE else black_deck
	
	if not current_deck.play_card(card):
		if DEBUG_MODE:
			print("Failed to play card!")
		status_label.text = "Failed to play card!"
		return
	
	if DEBUG_MODE:
		print("Swapping pieces at %s and %s" % [piece1.board_position, piece2.board_position])
	
	# Save positions for RPC
	var pos1 = piece1.board_position
	var pos2 = piece2.board_position
	
	# Perform swap locally
	perform_swap(piece1, piece2)
	
	# In multiplayer, broadcast swap to all
	if game_state.is_multiplayer:
		rpc_play_swap.rpc(pos1, pos2)
	
	# Reset selection
	selected_card = null
	awaiting_target = false
	card_played_this_turn = true
	
	# Discard the card
	current_deck.return_to_deck(card)
	
	# Update display
	update_hand_display()
	status_label.text = "Swapped pieces!"
	
	if DEBUG_MODE:
		print("Swap complete!")

func perform_swap(piece1: ChessPiece, piece2: ChessPiece):
	"""Perform the actual swap operation"""
	# Save original positions
	var pos1 = piece1.board_position
	var pos2 = piece2.board_position
	var temp_world_pos = piece1.position
	
	# Update board state FIRST using original positions
	chess_board.board_state[pos1.y][pos1.x] = piece2
	chess_board.board_state[pos2.y][pos2.x] = piece1
	
	# Then update the pieces' positions
	piece1.board_position = pos2
	piece1.position = chess_board.board_to_world_position(pos2)
	
	piece2.board_position = pos1
	piece2.position = temp_world_pos

func apply_card_effect(card: Card, target: ChessPiece):
	if DEBUG_MODE:
		print("=== Applying card effect: %s ===" % card.effect_id)
	
	match card.effect_id:
		"forward_strike", "knight_leap", "freeze", "shield", "long_range", "backstep":
			# These are piece modifiers
			if target:
				var modifier = PieceModifier.new(card.effect_id, card.duration, card)
				target.add_modifier(modifier)
				if DEBUG_MODE:
					print("✓ Applied modifier '%s' to piece at %s (duration: %d turns)" % [card.card_name, target.board_position, card.duration])
				status_label.text = "Applied %s! Duration: %d turns" % [card.card_name, card.duration]
			else:
				if DEBUG_MODE:
					print("✗ No target provided for piece modifier card!")
		
		"double_move":
			# Mark piece for double move
			if target:
				var modifier = PieceModifier.new(card.effect_id, 1, card)
				target.add_modifier(modifier)
				chess_board.set_double_move_piece(target)
				if DEBUG_MODE:
					print("✓ Applied Double Move to piece at %s" % target.board_position)
				status_label.text = "Move this piece twice!"
			else:
				if DEBUG_MODE:
					print("✗ No target provided for double move!")
		
		"swap":
			# Swap is handled by play_swap_card() - this shouldn't be reached
			if DEBUG_MODE:
				print("Swap handled separately")
			status_label.text = "Swap complete!"
	
	if DEBUG_MODE:
		print("=== Card effect application complete ===")

func tick_all_modifiers(for_color: ChessPiece.PieceColor):
	# Tick modifiers on the player's pieces whose turn just ended
	var opponent_color = ChessPiece.PieceColor.BLACK if for_color == ChessPiece.PieceColor.WHITE else ChessPiece.PieceColor.WHITE
	
	for y in range(8):
		for x in range(8):
			var piece = chess_board.board_state[y][x]
			if piece != null and piece.piece_color == opponent_color:
				piece.tick_modifiers()

func update_hand_display():
	# In multiplayer, only show YOUR hand (based on your color)
	if game_state.is_multiplayer:
		var your_deck = white_deck if game_state.local_player_color == ChessPiece.PieceColor.WHITE else black_deck
		hand_display.display_hand(your_deck.hand)
	else:
		# Local game - show current player's hand
		var current_deck = white_deck if chess_board.current_turn == ChessPiece.PieceColor.WHITE else black_deck
		hand_display.display_hand(current_deck.hand)

func update_deck_info():
	# In multiplayer, show YOUR deck info
	if game_state.is_multiplayer:
		var your_deck = white_deck if game_state.local_player_color == ChessPiece.PieceColor.WHITE else black_deck
		deck_info_label.text = "Your Deck: %d | Hand: %d" % [your_deck.get_deck_size(), your_deck.get_hand_size()]
	else:
		# Local game - show current player's deck
		var current_deck = white_deck if chess_board.current_turn == ChessPiece.PieceColor.WHITE else black_deck
		deck_info_label.text = "Deck: %d | Hand: %d" % [current_deck.get_deck_size(), current_deck.get_hand_size()]

# === NETWORK DISCONNECT HANDLERS ===

func _on_player_disconnected(peer_id: int):
	"""Handle opponent disconnection"""
	var player_name = NetworkManager.get_player_name(peer_id)
	status_label.text = "%s disconnected! You win by forfeit." % player_name
	status_label.add_theme_color_override("font_color", Color.ORANGE)
	
	# Disable further input
	chess_board.set_process_input(false)
	
	# Show dialog after a moment
	await get_tree().create_timer(2.0).timeout
	_show_disconnect_dialog()

func _on_server_disconnected():
	"""Handle server/host disconnection"""
	status_label.text = "Host disconnected! Returning to menu..."
	status_label.add_theme_color_override("font_color", Color.RED)
	
	# Disable further input
	chess_board.set_process_input(false)
	
	# Return to menu after a moment
	await get_tree().create_timer(2.0).timeout
	NetworkManager.disconnect_from_server()
	SceneManager.goto_multiplayer_menu()

func _show_disconnect_dialog():
	"""Show disconnect dialog with option to return to menu"""
	# For now, just return to menu
	# TODO: Add proper dialog UI
	NetworkManager.disconnect_from_server()
	SceneManager.goto_multiplayer_menu()

# === CARD SYNCHRONIZATION RPCs ===

@rpc("any_peer", "call_remote", "reliable")
func rpc_play_card(effect_id: String, target_pos: Vector2i):
	"""Broadcast card play to other players"""
	if DEBUG_MODE:
		print("Received card play RPC: %s at %s" % [effect_id, target_pos])
	
	# Find target piece if position is valid
	var target: ChessPiece = null
	if target_pos != Vector2i(-1, -1) and chess_board.is_valid_board_position(target_pos):
		target = chess_board.board_state[target_pos.y][target_pos.x]
	
	# Create a temporary card for the effect (we just need effect_id and duration)
	# Look up card properties from CardLibrary
	var card_data = get_card_data_by_effect_id(effect_id)
	if card_data == null:
		push_error("Unknown card effect_id: %s" % effect_id)
		return
	
	# Apply the effect
	apply_card_effect_by_data(card_data, target)
	
	# Update status
	status_label.text = "Opponent played: %s" % card_data["name"]

@rpc("any_peer", "call_remote", "reliable")
func rpc_play_swap(pos1: Vector2i, pos2: Vector2i):
	"""Broadcast swap card to other players"""
	if DEBUG_MODE:
		print("Received swap RPC: %s <-> %s" % [pos1, pos2])
	
	# Get the pieces
	if not chess_board.is_valid_board_position(pos1) or not chess_board.is_valid_board_position(pos2):
		push_error("Invalid positions for swap RPC")
		return
	
	var piece1 = chess_board.board_state[pos1.y][pos1.x]
	var piece2 = chess_board.board_state[pos2.y][pos2.x]
	
	if piece1 == null or piece2 == null:
		push_error("No pieces at swap positions")
		return
	
	# Perform the swap
	perform_swap(piece1, piece2)
	
	# Update status
	status_label.text = "Opponent swapped pieces!"

func get_card_data_by_effect_id(effect_id: String) -> Dictionary:
	"""Get card data from effect_id for RPC reconstruction"""
	match effect_id:
		"forward_strike":
			return {"name": "Forward Strike", "duration": 1, "effect_id": "forward_strike"}
		"knight_leap":
			return {"name": "Knight's Leap", "duration": 1, "effect_id": "knight_leap"}
		"freeze":
			return {"name": "Freeze", "duration": 1, "effect_id": "freeze"}
		"shield":
			return {"name": "Shield", "duration": 1, "effect_id": "shield"}
		"double_move":
			return {"name": "Double Time", "duration": 0, "effect_id": "double_move"}
		"long_range":
			return {"name": "Long Range", "duration": 1, "effect_id": "long_range"}
		"backstep":
			return {"name": "Tactical Retreat", "duration": 1, "effect_id": "backstep"}
		_:
			return {}

func apply_card_effect_by_data(card_data: Dictionary, target: ChessPiece):
	"""Apply card effect from data dictionary (for RPC)"""
	var effect_id = card_data.get("effect_id", "")
	var duration = card_data.get("duration", 0)
	var card_name = card_data.get("name", "Unknown")
	
	if DEBUG_MODE:
		print("=== Applying card effect from RPC: %s ===" % effect_id)
	
	match effect_id:
		"forward_strike", "knight_leap", "freeze", "shield", "long_range", "backstep":
			# These are piece modifiers
			if target:
				var modifier = PieceModifier.new(effect_id, duration, null)
				target.add_modifier(modifier)
				if DEBUG_MODE:
					print("✓ Applied modifier '%s' to piece at %s (duration: %d turns)" % [card_name, target.board_position, duration])
			else:
				if DEBUG_MODE:
					print("✗ No target provided for piece modifier card!")
		
		"double_move":
			# Mark piece for double move
			if target:
				var modifier = PieceModifier.new(effect_id, 1, null)
				target.add_modifier(modifier)
				chess_board.set_double_move_piece(target)
				if DEBUG_MODE:
					print("✓ Applied Double Move to piece at %s" % target.board_position)
			else:
				if DEBUG_MODE:
					print("✗ No target provided for double move!")
	
	if DEBUG_MODE:
		print("=== Card effect application complete ===")

