extends Control

# MultiplayerMenu - Main menu for multiplayer options

@onready var main_panel = $MainPanel
@onready var host_panel = $HostPanel
@onready var join_panel = $JoinPanel

# Main panel buttons
@onready var local_game_button = $MainPanel/VBoxContainer/LocalGameButton
@onready var host_game_button = $MainPanel/VBoxContainer/HostGameButton
@onready var join_game_button = $MainPanel/VBoxContainer/JoinGameButton
@onready var quit_button = $MainPanel/VBoxContainer/QuitButton

# Host panel elements
@onready var host_port_input = $HostPanel/VBoxContainer/PortContainer/PortInput
@onready var host_name_input = $HostPanel/VBoxContainer/NameContainer/NameInput
@onready var start_server_button = $HostPanel/VBoxContainer/StartServerButton
@onready var host_back_button = $HostPanel/VBoxContainer/BackButton
@onready var host_status_label = $HostPanel/VBoxContainer/StatusLabel

# Join panel elements
@onready var join_ip_input = $JoinPanel/VBoxContainer/IPContainer/IPInput
@onready var join_port_input = $JoinPanel/VBoxContainer/PortContainer/PortInput
@onready var join_name_input = $JoinPanel/VBoxContainer/NameContainer/NameInput
@onready var connect_button = $JoinPanel/VBoxContainer/ConnectButton
@onready var join_back_button = $JoinPanel/VBoxContainer/BackButton
@onready var join_status_label = $JoinPanel/VBoxContainer/StatusLabel

signal start_local_game()
signal enter_lobby()

func _ready():
	# Connect button signals
	local_game_button.pressed.connect(_on_local_game_pressed)
	host_game_button.pressed.connect(_on_host_game_pressed)
	join_game_button.pressed.connect(_on_join_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	start_server_button.pressed.connect(_on_start_server_pressed)
	host_back_button.pressed.connect(_on_host_back_pressed)
	
	connect_button.pressed.connect(_on_connect_pressed)
	join_back_button.pressed.connect(_on_join_back_pressed)
	
	# Connect to NetworkManager signals
	NetworkManager.server_created.connect(_on_server_created)
	NetworkManager.connection_successful.connect(_on_connection_successful)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	
	# Set default values
	host_port_input.text = str(NetworkManager.DEFAULT_PORT)
	join_port_input.text = str(NetworkManager.DEFAULT_PORT)
	join_ip_input.text = "127.0.0.1"
	
	# Generate default player name
	var random_num = randi() % 1000
	host_name_input.text = "Player%d" % random_num
	join_name_input.text = "Player%d" % random_num
	
	# Show main panel
	show_main_panel()

func show_main_panel():
	main_panel.visible = true
	host_panel.visible = false
	join_panel.visible = false

func show_host_panel():
	main_panel.visible = false
	host_panel.visible = true
	join_panel.visible = false
	host_status_label.text = ""

func show_join_panel():
	main_panel.visible = false
	host_panel.visible = false
	join_panel.visible = true
	join_status_label.text = ""

# === BUTTON HANDLERS ===

func _on_local_game_pressed():
	print("Starting local game...")
	SceneManager.goto_game()
	# Don't emit start_local_game signal anymore

func _on_host_game_pressed():
	print("Opening host menu...")
	show_host_panel()

func _on_join_game_pressed():
	print("Opening join menu...")
	show_join_panel()

func _on_quit_pressed():
	print("Quitting game...")
	get_tree().quit()

func _on_start_server_pressed():
	var port = int(host_port_input.text)
	var player_name = host_name_input.text.strip_edges()
	
	if player_name.is_empty():
		host_status_label.text = "Please enter a player name!"
		host_status_label.add_theme_color_override("font_color", Color.RED)
		return
	
	if port < 1024 or port > 65535:
		host_status_label.text = "Port must be between 1024 and 65535!"
		host_status_label.add_theme_color_override("font_color", Color.RED)
		return
	
	host_status_label.text = "Creating server..."
	host_status_label.add_theme_color_override("font_color", Color.YELLOW)
	
	NetworkManager.set_player_name(player_name)
	
	if NetworkManager.create_server(port):
		# Success - server_created signal will be emitted
		pass
	else:
		host_status_label.text = "Failed to create server!"
		host_status_label.add_theme_color_override("font_color", Color.RED)

func _on_host_back_pressed():
	show_main_panel()

func _on_connect_pressed():
	var ip = join_ip_input.text.strip_edges()
	var port = int(join_port_input.text)
	var player_name = join_name_input.text.strip_edges()
	
	if player_name.is_empty():
		join_status_label.text = "Please enter a player name!"
		join_status_label.add_theme_color_override("font_color", Color.RED)
		return
	
	if ip.is_empty():
		join_status_label.text = "Please enter an IP address!"
		join_status_label.add_theme_color_override("font_color", Color.RED)
		return
	
	if port < 1024 or port > 65535:
		join_status_label.text = "Port must be between 1024 and 65535!"
		join_status_label.add_theme_color_override("font_color", Color.RED)
		return
	
	join_status_label.text = "Connecting to server..."
	join_status_label.add_theme_color_override("font_color", Color.YELLOW)
	
	NetworkManager.set_player_name(player_name)
	
	if NetworkManager.join_server(ip, port):
		# Connection attempt started - will get callback
		connect_button.disabled = true
	else:
		join_status_label.text = "Failed to connect!"
		join_status_label.add_theme_color_override("font_color", Color.RED)

func _on_join_back_pressed():
	NetworkManager.disconnect_from_server()
	connect_button.disabled = false
	show_main_panel()

# === NETWORK SIGNAL HANDLERS ===

func _on_server_created():
	host_status_label.text = "Server created! Waiting for players..."
	host_status_label.add_theme_color_override("font_color", Color.GREEN)
	
	# Wait a moment then go to lobby
	await get_tree().create_timer(1.0).timeout
	SceneManager.goto_lobby()

func _on_connection_successful():
	join_status_label.text = "Connected successfully!"
	join_status_label.add_theme_color_override("font_color", Color.GREEN)
	
	# Wait a moment then go to lobby
	await get_tree().create_timer(1.0).timeout
	SceneManager.goto_lobby()

func _on_connection_failed():
	join_status_label.text = "Connection failed!"
	join_status_label.add_theme_color_override("font_color", Color.RED)
	connect_button.disabled = false
