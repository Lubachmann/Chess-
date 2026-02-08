extends HBoxContainer

const CardUIScene = preload("res://scenes/card_ui.tscn")

var card_nodes: Array = []

signal card_selected(card: Card)

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func display_hand(cards: Array[Card]):
	clear_hand()
	
	print("Displaying %d cards in hand" % cards.size())
	
	for card in cards:
		var card_ui = CardUIScene.instantiate()
		add_child(card_ui)
		card_ui.set_card(card)
		card_ui.card_clicked.connect(_on_card_clicked)
		card_nodes.append(card_ui)
		print("Added card to hand: ", card.card_name)

func clear_hand():
	for card_node in card_nodes:
		card_node.queue_free()
	card_nodes.clear()

func _on_card_clicked(card: Card):
	print("Hand display received card click: ", card.card_name)
	card_selected.emit(card)

func remove_card(card: Card):
	for i in range(card_nodes.size()):
		if card_nodes[i].card_data == card:
			card_nodes[i].queue_free()
			card_nodes.remove_at(i)
			break
