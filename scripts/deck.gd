class_name Deck
extends Node

# Manages a player's deck of cards

var draw_pile: Array[Card] = []
var discard_pile: Array[Card] = []
var hand: Array[Card] = []

const MAX_HAND_SIZE = 7

signal card_drawn(card: Card)
signal hand_full()

func _init(starting_cards: Array[Card] = []):
	if starting_cards.is_empty():
		draw_pile = CardLibrary.get_starter_deck()
	else:
		draw_pile = starting_cards.duplicate()
	
	shuffle_deck()

func shuffle_deck():
	# Fisher-Yates shuffle
	for i in range(draw_pile.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = draw_pile[i]
		draw_pile[i] = draw_pile[j]
		draw_pile[j] = temp

func draw_card() -> Card:
	# Check if deck is empty
	if draw_pile.is_empty():
		# Reshuffle discard pile into draw pile
		if discard_pile.is_empty():
			print("No cards left to draw!")
			return null
		draw_pile = discard_pile.duplicate()
		discard_pile.clear()
		shuffle_deck()
	
	# Check hand size
	if hand.size() >= MAX_HAND_SIZE:
		hand_full.emit()
		return null
	
	var card = draw_pile.pop_back()
	hand.append(card)
	card_drawn.emit(card)
	return card

func draw_initial_hand(count: int = 3):
	for i in range(count):
		draw_card()

func play_card(card: Card) -> bool:
	if card in hand:
		hand.erase(card)
		return true
	return false

func discard_card(card: Card):
	if card in hand:
		hand.erase(card)
	discard_pile.append(card)

func return_to_deck(card: Card):
	discard_pile.append(card)

func get_hand_size() -> int:
	return hand.size()

func get_deck_size() -> int:
	return draw_pile.size()

func get_discard_size() -> int:
	return discard_pile.size()
