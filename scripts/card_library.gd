class_name CardLibrary
extends Node

# Static library of all available cards

static func create_all_cards() -> Array[Card]:
	var cards: Array[Card] = []
	
	# 1. Forward Strike - Pawn can capture forward
	var forward_strike = Card.new(
		"Forward Strike",
		"Target pawn can capture forward for 1 turn",
		Card.CardType.PIECE_MODIFIER,
		Card.TargetType.OWN_PIECE,
		"forward_strike",
		1
	)
	cards.append(forward_strike)
	
	# 2. Knight's Leap - Any piece can jump like a knight once
	var knight_leap = Card.new(
		"Knight's Leap",
		"Target piece can also move like a knight this turn",
		Card.CardType.PIECE_MODIFIER,
		Card.TargetType.OWN_PIECE,
		"knight_leap",
		1
	)
	cards.append(knight_leap)
	
	# 3. Freeze - Lock opponent's piece for 1 turn
	var freeze = Card.new(
		"Freeze",
		"Target enemy piece cannot move next turn",
		Card.CardType.PIECE_MODIFIER,
		Card.TargetType.ENEMY_PIECE,
		"freeze",
		1
	)
	cards.append(freeze)
	
	# 4. Shield - Piece can't be captured
	var shield = Card.new(
		"Shield",
		"Target piece cannot be captured for 1 turn",
		Card.CardType.PIECE_MODIFIER,
		Card.TargetType.OWN_PIECE,
		"shield",
		1
	)
	cards.append(shield)
	
	# 5. Extra Move - Move a piece twice
	var extra_move = Card.new(
		"Double Time",
		"Move target piece twice this turn",
		Card.CardType.PIECE_MODIFIER,
		Card.TargetType.OWN_PIECE,
		"double_move",
		0  # Instant - used this turn only
	)
	cards.append(extra_move)
	
	# 6. Swap - Exchange positions of two friendly pieces
	var swap = Card.new(
		"Swap",
		"Exchange positions of two friendly pieces",
		Card.CardType.BOARD_EFFECT,
		Card.TargetType.OWN_PIECE,  # Will need 2 targets
		"swap",
		0
	)
	cards.append(swap)
	
	# 7. Long Range - Piece can move 2 extra squares
	var long_range = Card.new(
		"Long Range",
		"Target piece can move 2 extra squares this turn",
		Card.CardType.PIECE_MODIFIER,
		Card.TargetType.OWN_PIECE,
		"long_range",
		1
	)
	cards.append(long_range)
	
	# 8. Backstep - King or Queen can move backwards multiple squares
	var backstep = Card.new(
		"Tactical Retreat",
		"Target piece can move backwards this turn",
		Card.CardType.PIECE_MODIFIER,
		Card.TargetType.OWN_PIECE,
		"backstep",
		1
	)
	cards.append(backstep)
	
	return cards

static func get_starter_deck() -> Array[Card]:
	# Returns a balanced starting deck
	var all_cards = create_all_cards()
	var deck: Array[Card] = []
	
	# Add 3 copies of each card for variety (24 cards total)
	for card in all_cards:
		for i in range(3):
			deck.append(card.duplicate())
	
	return deck
