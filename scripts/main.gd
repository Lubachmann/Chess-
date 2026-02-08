extends Control

@onready var chess_board = $VBoxContainer/BoardArea/ChessBoard
@onready var turn_label = $VBoxContainer/TopArea/MarginContainer/HBoxContainer/TurnLabel
@onready var status_label = $VBoxContainer/TopArea/MarginContainer/StatusLabel
@onready var hand_display = $VBoxContainer/BottomArea/MarginContainer/VBoxContainer/HandDisplay
@onready var deck_info_label = $VBoxContainer/TopArea/MarginContainer/HBoxContainer/DeckInfo

# Player decks
var white_deck: Deck
var black_deck: Deck

# Game state
var selected_card: Card = null
var awaiting_target: bool = false
var card_played_this_turn: bool = false

# Swap card needs two targets
var swap_first_piece: ChessPiece = null
var swap_awaiting_second: bool = false

func _ready():
	# Connect to chess board signals
	chess_board.turn_changed.connect(_on_turn_changed)
	chess_board.check_detected.connect(_on_check_detected)
	chess_board.checkmate.connect(_on_checkmate)
	chess_board.piece_selected.connect(_on_piece_selected)
	
	# Initialize decks
	white_deck = Deck.new()
	black_deck = Deck.new()
	
	# Draw initial hands
	white_deck.draw_initial_hand(3)
	black_deck.draw_initial_hand(3)
	
	# Connect hand display
	hand_display.card_selected.connect(_on_card_selected)
	
	# Initialize UI
	turn_label.text = "White's Turn"
	status_label.text = ""
	update_hand_display()
	update_deck_info()

func _on_turn_changed(color: ChessPiece.PieceColor):
	var color_name = "White" if color == ChessPiece.PieceColor.WHITE else "Black"
	turn_label.text = "%s's Turn" % color_name
	status_label.text = ""
	
	# Draw card at start of turn
	var current_deck = white_deck if color == ChessPiece.PieceColor.WHITE else black_deck
	current_deck.draw_card()
	
	# Reset card played flag
	card_played_this_turn = false
	
	# Tick down modifiers on all pieces
	tick_all_modifiers(color)
	
	update_hand_display()
	update_deck_info()
	print("%s's turn" % color_name)

func _on_check_detected(color: ChessPiece.PieceColor):
	var color_name = "White" if color == ChessPiece.PieceColor.WHITE else "Black"
	status_label.text = "%s is in CHECK!" % color_name
	status_label.add_theme_color_override("font_color", Color.RED)
	print("%s is in check!" % color_name)

func _on_checkmate(winner_color: ChessPiece.PieceColor):
	var winner_name = "White" if winner_color == ChessPiece.PieceColor.WHITE else "Black"
	status_label.text = "CHECKMATE! %s WINS!" % winner_name
	status_label.add_theme_color_override("font_color", Color.GOLD)
	print("Checkmate! %s wins!" % winner_name)

func _on_card_selected(card: Card):
	print("Main: Card selected - ", card.card_name)
	
	if card_played_this_turn:
		status_label.text = "Already played a card this turn!"
		print("Cannot play card - already played this turn")
		return
	
	selected_card = card
	
	if card.requires_target():
		awaiting_target = true
		status_label.text = "Select a %s to target..." % get_target_type_name(card.target_type)
		print("Waiting for target selection for card: %s" % card.card_name)
		
		# Highlight valid targets on the board
		highlight_valid_targets(card)
	else:
		# Play card immediately
		print("Playing card without target")
		play_card(card, null)

func highlight_valid_targets(card: Card):
	# Tell the chess board to highlight valid target pieces
	var valid_targets: Array[Vector2i] = []
	
	for y in range(8):
		for x in range(8):
			var piece = chess_board.board_state[y][x]
			if piece != null and is_valid_target(card, piece):
				valid_targets.append(Vector2i(x, y))
	
	chess_board.show_target_highlights(valid_targets)
	print("Highlighting %d valid targets" % valid_targets.size())

func highlight_valid_targets_except(card: Card, exclude_piece: ChessPiece):
	# Highlight valid targets, excluding a specific piece (for swap's second selection)
	var valid_targets: Array[Vector2i] = []
	
	for y in range(8):
		for x in range(8):
			var piece = chess_board.board_state[y][x]
			if piece != null and piece != exclude_piece and is_valid_target(card, piece):
				valid_targets.append(Vector2i(x, y))
	
	chess_board.show_target_highlights(valid_targets)
	print("Highlighting %d valid targets (excluding first piece)" % valid_targets.size())

func _on_piece_selected(piece: ChessPiece):
	print("Piece selected: ", piece.board_position, " Color: ", piece.piece_color)
	
	if awaiting_target and selected_card:
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
					print("First piece selected for swap: ", piece.board_position)
					
					# Re-highlight valid targets (excluding the first piece)
					highlight_valid_targets_except(selected_card, piece)
				else:
					status_label.text = "Invalid target! Card needs: %s" % get_target_type_name(selected_card.target_type)
					chess_board.flash_invalid_target(piece.board_position)
			else:
				# Second piece selected
				if is_valid_target(selected_card, piece) and piece != swap_first_piece:
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
				print("Valid target! Playing card.")
				
				chess_board.show_target_selected(piece.board_position)
				await get_tree().create_timer(0.3).timeout
				
				play_card(selected_card, piece)
				chess_board.clear_target_highlights()
			else:
				status_label.text = "Invalid target! Card needs: %s" % get_target_type_name(selected_card.target_type)
				print("Invalid target!")
				chess_board.flash_invalid_target(piece.board_position)
	else:
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
	var current_deck = white_deck if chess_board.current_turn == ChessPiece.PieceColor.WHITE else black_deck
	
	if not current_deck.play_card(card):
		print("Failed to play card!")
		return
	
	print("Playing card: %s" % card.card_name)
	
	# Apply card effect
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
	var current_deck = white_deck if chess_board.current_turn == ChessPiece.PieceColor.WHITE else black_deck
	
	if not current_deck.play_card(card):
		print("Failed to play card!")
		return
	
	print("Swapping pieces at %s and %s" % [piece1.board_position, piece2.board_position])
	
	# Swap the pieces' positions
	var temp_pos = piece1.board_position
	var temp_world_pos = piece1.position
	
	# Update piece 1
	piece1.board_position = piece2.board_position
	piece1.position = chess_board.board_to_world_position(piece2.board_position)
	
	# Update piece 2
	piece2.board_position = temp_pos
	piece2.position = temp_world_pos
	
	# Update board state
	chess_board.board_state[piece1.board_position.y][piece1.board_position.x] = piece1
	chess_board.board_state[piece2.board_position.y][piece2.board_position.x] = piece2
	
	# Reset selection
	selected_card = null
	awaiting_target = false
	card_played_this_turn = true
	
	# Discard the card
	current_deck.return_to_deck(card)
	
	# Update display
	update_hand_display()
	status_label.text = "Swapped pieces!"
	
	print("Swap complete!")

func apply_card_effect(card: Card, target: ChessPiece):
	print("=== Applying card effect: %s ===" % card.effect_id)
	
	match card.effect_id:
		"forward_strike", "knight_leap", "freeze", "shield", "long_range", "backstep":
			# These are piece modifiers
			if target:
				var modifier = PieceModifier.new(card.effect_id, card.duration, card)
				target.add_modifier(modifier)
				print("✓ Applied modifier '%s' to piece at %s (duration: %d turns)" % [card.card_name, target.board_position, card.duration])
				status_label.text = "Applied %s! Duration: %d turns" % [card.card_name, card.duration]
			else:
				print("✗ No target provided for piece modifier card!")
		
		"double_move":
			# Mark piece for double move
			if target:
				var modifier = PieceModifier.new(card.effect_id, 1, card)
				target.add_modifier(modifier)
				chess_board.set_double_move_piece(target)
				print("✓ Applied Double Move to piece at %s" % target.board_position)
				status_label.text = "Move this piece twice!"
			else:
				print("✗ No target provided for double move!")
		
		"swap":
			# Swap is handled by play_swap_card() - this shouldn't be reached
			print("Swap handled separately")
			status_label.text = "Swap complete!"
	
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
	var current_deck = white_deck if chess_board.current_turn == ChessPiece.PieceColor.WHITE else black_deck
	hand_display.display_hand(current_deck.hand)

func update_deck_info():
	var current_deck = white_deck if chess_board.current_turn == ChessPiece.PieceColor.WHITE else black_deck
	deck_info_label.text = "Deck: %d | Hand: %d" % [current_deck.get_deck_size(), current_deck.get_hand_size()]
