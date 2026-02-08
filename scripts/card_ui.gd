extends Control

@export var card_data: Card

@onready var card_name_label: Label = $Panel/VBoxContainer/CardName
@onready var description_label: Label = $Panel/VBoxContainer/Description
@onready var panel: Panel = $Panel

var is_hovered: bool = false
var is_selected: bool = false
var original_modulate: Color

signal card_clicked(card: Card)
signal card_hovered(card: Card)

func _ready():
	# Set up mouse interaction
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	if card_data:
		update_display()

func set_card(card: Card):
	card_data = card
	if is_node_ready():
		update_display()

func update_display():
	if not card_data:
		return
	
	card_name_label.text = card_data.card_name
	description_label.text = card_data.description
	
	# Color code by card type with modulate on the panel
	match card_data.card_type:
		Card.CardType.INSTANT:
			panel.modulate = Color(1.0, 0.95, 0.7)  # Yellow tint
		Card.CardType.PIECE_MODIFIER:
			panel.modulate = Color(0.7, 0.85, 1.0)  # Blue tint
		Card.CardType.BOARD_EFFECT:
			panel.modulate = Color(0.9, 0.7, 1.0)  # Purple tint
	
	original_modulate = panel.modulate

func _on_mouse_entered():
	is_hovered = true
	scale = Vector2(1.15, 1.15)
	z_index = 10
	# Brighten on hover
	panel.modulate = original_modulate * 1.2
	card_hovered.emit(card_data)

func _on_mouse_exited():
	is_hovered = false
	if not is_selected:
		scale = Vector2(1.0, 1.0)
		z_index = 0
		panel.modulate = original_modulate

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Card clicked: ", card_data.card_name if card_data else "no card")
		card_clicked.emit(card_data)

func set_selected(selected: bool):
	is_selected = selected
	if selected:
		panel.modulate = Color(1.2, 1.2, 0.8)  # Bright highlight
		scale = Vector2(1.15, 1.15)
		z_index = 10
	else:
		scale = Vector2(1.0, 1.0)
		z_index = 0
		panel.modulate = original_modulate
