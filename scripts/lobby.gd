extends Control

# Lobby - Pre-game lobby where players get ready before starting

@onready var player_list = $VBoxContainer/PlayersPanel/PlayerList
@onready var ready_button = $VBoxContainer/ButtonsContainer/ReadyButton
@onready var start_game_button = $VBoxContainer/ButtonsContainer/StartGameButton
@onready var back_button = $VBoxContainer/ButtonsContainer/BackButton
@onready var status_label = $VBoxContainer/StatusLabel
@onready var chat_log = $VBoxContainer/ChatPanel/ChatLog
@onready var chat_input = $VBoxContainer/ChatPanel/HBoxContainer/ChatInput
@onready var send_button = $VBoxContainer/ChatPanel/HBoxContainer/SendButton

var is_ready: bool = false

signal start_game()
signal return_to_menu()

func _ready():
	# Connect button signals
	ready_button.pressed.connect(_on_ready_button_pressed)
	start_game_button.pressed.connect(_on_start_game_pressed)
	back_button.pressed.connect(_on_back_pressed)
	send_button.pressed.connect(_on_send_chat_pressed)
	chat_input.text_submitted.connect(_on_chat_submitted)
	
	# Connect to NetworkManager signals
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	
	# Setup initial UI state
	if NetworkManager.is_server():
		start_game_button.visible = true
		start_game_button.disabled = true  # Enable when all ready
		status_label.text = "You are the host. Waiting for players..."
	else:
		start_game_button.visible = false
		status_label.text = "Connected to host. Click Ready to begin."
	
	# Update player list
	update_player_list()

func update_player_list():
	"""Update the list of connected players"""
	player_list.clear()
	
	var players = NetworkManager.connected_peers
	for peer_id in players:
		var player_info = players[peer_id]
		var player_name = player_info.get("name", "Unknown")
		var ready_status = player_info.get("ready", false)
		
		var status_icon = "✓" if ready_status else "○"
		var is_local = peer_id == NetworkManager.get_local_peer_id()
		var local_text = " (You)" if is_local else ""
		var host_text = " [Host]" if peer_id == 1 else ""
		
		var display_text = "%s %s%s%s" % [status_icon, player_name, local_text, host_text]
		player_list.add_item(display_text)
	
	# Update start button if host
	if NetworkManager.is_server():
		var all_ready = NetworkManager.all_players_ready()
		var enough_players = NetworkManager.get_connected_player_count() == NetworkManager.MAX_PLAYERS
		start_game_button.disabled = not (all_ready and enough_players)
		
		if enough_players and all_ready:
			status_label.text = "All players ready! You can start the game."
		elif enough_players:
			status_label.text = "Waiting for all players to be ready..."
		else:
			status_label.text = "Waiting for more players to join..."

func add_chat_message(message: String):
	"""Add a message to the chat log"""
	chat_log.text += message + "\n"
	# Auto-scroll to bottom
	await get_tree().process_frame
	if chat_log.get_v_scroll_bar():
		chat_log.get_v_scroll_bar().value = chat_log.get_v_scroll_bar().max_value

# === BUTTON HANDLERS ===

func _on_ready_button_pressed():
	is_ready = not is_ready
	
	if is_ready:
		ready_button.text = "Not Ready"
		ready_button.add_theme_color_override("font_color", Color.ORANGE)
	else:
		ready_button.text = "Ready"
		ready_button.add_theme_color_override("font_color", Color.GREEN)
	
	# Update local player's ready status
	NetworkManager.set_player_ready(NetworkManager.get_local_peer_id(), is_ready)
	
	# Notify server
	NetworkManager.rpc_set_ready.rpc(is_ready)
	
	update_player_list()

func _on_start_game_pressed():
	if not NetworkManager.is_server():
		return
	
	if not NetworkManager.all_players_ready():
		status_label.text = "Not all players are ready!"
		return
	
	if NetworkManager.get_connected_player_count() < NetworkManager.MAX_PLAYERS:
		status_label.text = "Waiting for more players!"
		return
	
	status_label.text = "Starting game..."
	
	# Notify all clients to start the game
	rpc_start_game.rpc()

func _on_back_pressed():
	# Disconnect and return to menu
	NetworkManager.disconnect_from_server()
	SceneManager.goto_multiplayer_menu()

func _on_send_chat_pressed():
	_send_chat_message()

func _on_chat_submitted(_text: String):
	_send_chat_message()

func _send_chat_message():
	var message = chat_input.text.strip_edges()
	if message.is_empty():
		return
	
	var player_name = NetworkManager.local_player_name
	var formatted_message = "[%s]: %s" % [player_name, message]
	
	# Send to all players
	rpc_receive_chat_message.rpc(formatted_message)
	
	chat_input.text = ""

# === NETWORK SIGNAL HANDLERS ===

func _on_player_connected(peer_id: int, player_info: Dictionary):
	var player_name = player_info.get("name", "Unknown")
	add_chat_message("* %s joined the lobby" % player_name)
	update_player_list()

func _on_player_disconnected(peer_id: int):
	var player_name = NetworkManager.get_player_name(peer_id)
	add_chat_message("* %s left the lobby" % player_name)
	update_player_list()

func _on_server_disconnected():
	status_label.text = "Host disconnected!"
	status_label.add_theme_color_override("font_color", Color.RED)
	
	# Disable all buttons except back
	ready_button.disabled = true
	if start_game_button.visible:
		start_game_button.disabled = true

# === RPC FUNCTIONS ===

@rpc("authority", "call_local", "reliable")
func rpc_start_game():
	"""Host tells all clients to start the game"""
	print("Starting multiplayer game...")
	SceneManager.goto_game()

@rpc("any_peer", "call_local", "reliable")
func rpc_receive_chat_message(message: String):
	"""Receive a chat message from another player"""
	add_chat_message(message)
