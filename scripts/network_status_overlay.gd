extends Control

# NetworkStatusOverlay - Shows network status and feedback

@onready var status_panel = $StatusPanel
@onready var status_label = $StatusPanel/VBoxContainer/StatusLabel
@onready var detail_label = $StatusPanel/VBoxContainer/DetailLabel
@onready var connection_indicator = $ConnectionIndicator
@onready var connection_label = $ConnectionIndicator/Label

var fade_timer: Timer = null

func _ready():
	# Hide by default
	status_panel.visible = false
	connection_indicator.visible = false
	
	# Setup fade timer
	fade_timer = Timer.new()
	fade_timer.one_shot = true
	fade_timer.timeout.connect(_on_fade_timeout)
	add_child(fade_timer)
	
	# Setup connection indicator if multiplayer
	if NetworkManager.is_multiplayer_active():
		connection_indicator.visible = true
		update_connection_status()
		
		# Update periodically
		var update_timer = Timer.new()
		update_timer.wait_time = 1.0
		update_timer.timeout.connect(update_connection_status)
		add_child(update_timer)
		update_timer.start()

func show_status(message: String, detail: String = "", duration: float = 2.0):
	"""Show a status message with optional detail"""
	status_label.text = message
	detail_label.text = detail
	detail_label.visible = not detail.is_empty()
	
	status_panel.visible = true
	status_panel.modulate = Color(1, 1, 1, 1)
	
	# Auto-hide after duration
	if duration > 0:
		fade_timer.wait_time = duration
		fade_timer.start()

func show_move_validating():
	"""Show that move is being validated"""
	show_status("Validating move...", "", 0)  # No auto-hide

func show_move_accepted():
	"""Show that move was accepted"""
	status_panel.modulate = Color(0.5, 1.0, 0.5, 1)  # Green tint
	show_status("Move accepted!", "", 1.5)

func show_move_rejected(reason: String):
	"""Show that move was rejected"""
	status_panel.modulate = Color(1.0, 0.5, 0.5, 1)  # Red tint
	show_status("Move Rejected!", reason, 3.0)

func show_waiting_for_opponent():
	"""Show waiting for opponent"""
	show_status("Waiting for opponent...", "", 0)  # No auto-hide

func hide_status():
	"""Hide the status panel"""
	status_panel.visible = false
	if fade_timer.time_left > 0:
		fade_timer.stop()

func update_connection_status():
	"""Update the connection quality indicator"""
	if not NetworkManager.is_multiplayer_active():
		connection_indicator.visible = false
		return
	
	# Get peer count
	var peer_count = NetworkManager.get_connected_player_count()
	
	if peer_count < 2:
		connection_label.text = "⚠ Waiting for players..."
		connection_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		var role = "Host" if NetworkManager.is_server() else "Client"
		connection_label.text = "● %s - Connected" % role
		connection_label.add_theme_color_override("font_color", Color.GREEN)

func _on_fade_timeout():
	"""Fade out the status panel"""
	var tween = create_tween()
	tween.tween_property(status_panel, "modulate:a", 0.0, 0.5)
	await tween.finished
	status_panel.visible = false
