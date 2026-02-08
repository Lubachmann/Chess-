extends Node

# NetworkManager - Singleton for managing multiplayer connections
# Handles peer creation, connection, disconnection, and network events

# Configuration
const DEFAULT_PORT = 7777
const MAX_PLAYERS = 2

# Network state
var peer: ENetMultiplayerPeer = null
var is_host: bool = false
var connected_peers: Dictionary = {}  # peer_id -> player_info

# Player info
var local_player_name: String = "Player"
var local_peer_id: int = 0

# Signals for network events
signal connection_successful()
signal connection_failed()
signal server_created()
signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal server_disconnected()

func _ready():
	# Connect to multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# === HOST FUNCTIONS ===

func create_server(port: int = DEFAULT_PORT) -> bool:
	"""Create a server/host"""
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_PLAYERS)
	
	if error != OK:
		push_error("Failed to create server: %s" % error)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_host = true
	local_peer_id = multiplayer.get_unique_id()
	
	# Add self to connected peers
	var player_info = {
		"name": local_player_name,
		"peer_id": local_peer_id,
		"ready": false
	}
	connected_peers[local_peer_id] = player_info
	
	print("Server created on port %d with peer ID: %d" % [port, local_peer_id])
	server_created.emit()
	return true

# === CLIENT FUNCTIONS ===

func join_server(ip: String, port: int = DEFAULT_PORT) -> bool:
	"""Join a server as client"""
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)
	
	if error != OK:
		push_error("Failed to connect to server: %s" % error)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_host = false
	
	print("Attempting to connect to %s:%d" % [ip, port])
	return true

# === DISCONNECT FUNCTIONS ===

func disconnect_from_server():
	"""Disconnect from current network session"""
	if peer:
		peer.close()
		peer = null
	
	multiplayer.multiplayer_peer = null
	is_host = false
	connected_peers.clear()
	local_peer_id = 0
	
	print("Disconnected from network session")

# === PLAYER INFO FUNCTIONS ===

func set_player_name(player_name: String):
	"""Set the local player's name"""
	local_player_name = player_name

func get_player_name(peer_id: int) -> String:
	"""Get a player's name by peer ID"""
	if peer_id in connected_peers:
		return connected_peers[peer_id].get("name", "Unknown")
	return "Unknown"

func set_player_ready(peer_id: int, ready: bool):
	"""Set a player's ready status"""
	if peer_id in connected_peers:
		connected_peers[peer_id]["ready"] = ready

func is_player_ready(peer_id: int) -> bool:
	"""Check if a player is ready"""
	if peer_id in connected_peers:
		return connected_peers[peer_id].get("ready", false)
	return false

func all_players_ready() -> bool:
	"""Check if all players are ready"""
	if connected_peers.size() < MAX_PLAYERS:
		return false
	
	for peer_id in connected_peers:
		if not connected_peers[peer_id].get("ready", false):
			return false
	return true

func get_connected_player_count() -> int:
	"""Get the number of connected players"""
	return connected_peers.size()

# === RPC FUNCTIONS ===

@rpc("any_peer", "reliable")
func register_player(player_info: Dictionary):
	"""Client registers their info with the host"""
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Only host processes this
	if not is_host:
		return
	
	player_info["peer_id"] = sender_id
	player_info["ready"] = false
	connected_peers[sender_id] = player_info
	
	print("Player registered: %s (ID: %d)" % [player_info["name"], sender_id])
	
	# Broadcast to all clients about the new player
	rpc_update_player_list.rpc(connected_peers)
	player_connected.emit(sender_id, player_info)

@rpc("authority", "reliable")
func rpc_update_player_list(players: Dictionary):
	"""Host sends updated player list to all clients"""
	connected_peers = players
	
	# Emit signals for each player
	for peer_id in players:
		if peer_id != local_peer_id:
			player_connected.emit(peer_id, players[peer_id])

@rpc("any_peer", "reliable")
func rpc_set_ready(ready: bool):
	"""Player sets their ready status"""
	var sender_id = multiplayer.get_remote_sender_id()
	
	if is_host:
		# Host updates the ready status
		set_player_ready(sender_id, ready)
		# Broadcast updated list
		rpc_update_player_list.rpc(connected_peers)
	else:
		# Client sets their own ready status
		set_player_ready(local_peer_id, ready)

# === SIGNAL HANDLERS ===

func _on_peer_connected(id: int):
	"""Called when a peer connects to the server"""
	print("Peer connected: %d" % id)
	
	if not is_host:
		# We're a client, the peer is the host or another client
		# Send our info to the host
		var player_info = {
			"name": local_player_name
		}
		register_player.rpc_id(1, player_info)

func _on_peer_disconnected(id: int):
	"""Called when a peer disconnects"""
	print("Peer disconnected: %d" % id)
	
	if id in connected_peers:
		connected_peers.erase(id)
	
	player_disconnected.emit(id)
	
	if is_host:
		# Broadcast updated player list
		rpc_update_player_list.rpc(connected_peers)

func _on_connected_to_server():
	"""Called on client when successfully connected to server"""
	print("Successfully connected to server")
	local_peer_id = multiplayer.get_unique_id()
	
	# Add self to connected peers
	var player_info = {
		"name": local_player_name,
		"peer_id": local_peer_id,
		"ready": false
	}
	connected_peers[local_peer_id] = player_info
	
	connection_successful.emit()

func _on_connection_failed():
	"""Called on client when connection fails"""
	print("Connection to server failed")
	peer = null
	connection_failed.emit()

func _on_server_disconnected():
	"""Called on client when server disconnects"""
	print("Server disconnected")
	disconnect_from_server()
	server_disconnected.emit()

# === UTILITY FUNCTIONS ===

func get_local_peer_id() -> int:
	"""Get the local peer's ID"""
	return local_peer_id

func is_server() -> bool:
	"""Check if this peer is the server/host"""
	return is_host

func is_multiplayer_active() -> bool:
	"""Check if multiplayer is active"""
	return peer != null and multiplayer.multiplayer_peer != null
