extends Node

# SceneManager - Handles transitions between scenes

var current_scene: Node = null

# Scene paths
const MULTIPLAYER_MENU_SCENE = "res://scenes/multiplayer_menu.tscn"
const LOBBY_SCENE = "res://scenes/lobby.tscn"
const GAME_SCENE = "res://scenes/main.tscn"

func _ready():
	# Get the current scene
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)

func goto_scene(path: String):
	"""Change to a new scene"""
	# This function will usually be called from a signal callback,
	# or some other function in the current scene.
	# Deleting the current scene at this point is
	# a bad idea, because it may still be executing code.
	# This will result in a crash or unexpected behavior.
	
	# The solution is to defer the load to a later time, when
	# we can be sure that no code from the current scene is running:
	call_deferred("_deferred_goto_scene", path)

func _deferred_goto_scene(path: String):
	"""Actually change the scene (deferred)"""
	# It is now safe to remove the current scene
	if current_scene:
		current_scene.free()
	
	# Load the new scene
	var s = ResourceLoader.load(path)
	
	# Instance the new scene
	current_scene = s.instantiate()
	
	# Add it to the active scene, as child of root
	get_tree().root.add_child(current_scene)
	
	# Make it the current scene, for SceneTree.change_scene_to_file() to work
	get_tree().current_scene = current_scene
	
	print("Scene changed to: %s" % path)

func goto_multiplayer_menu():
	"""Go to the multiplayer menu"""
	goto_scene(MULTIPLAYER_MENU_SCENE)

func goto_lobby():
	"""Go to the lobby"""
	goto_scene(LOBBY_SCENE)

func goto_game():
	"""Go to the game"""
	goto_scene(GAME_SCENE)
