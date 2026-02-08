class_name Card
extends Resource

enum CardType {
	INSTANT,           # Plays immediately
	PIECE_MODIFIER,    # Modifies a piece temporarily
	BOARD_EFFECT       # Affects the board/game state
}

enum TargetType {
	NO_TARGET,         # No targeting needed
	OWN_PIECE,         # Target your own piece
	ENEMY_PIECE,       # Target opponent's piece
	ANY_PIECE,         # Target any piece
	EMPTY_SQUARE       # Target an empty square
}

@export var card_name: String
@export var description: String
@export var card_type: CardType
@export var target_type: TargetType
@export var effect_id: String  # Unique identifier for the effect
@export var duration: int = 0  # 0 = instant, >0 = turns remaining
@export var icon_texture: Texture2D  # For future artwork

# Effect data - stored as dictionary for flexibility
var effect_data: Dictionary = {}

func _init(p_name: String = "", p_description: String = "", p_type: CardType = CardType.INSTANT, 
           p_target: TargetType = TargetType.NO_TARGET, p_effect_id: String = "", p_duration: int = 0):
	card_name = p_name
	description = p_description
	card_type = p_type
	target_type = p_target
	effect_id = p_effect_id
	duration = p_duration

func requires_target() -> bool:
	return target_type != TargetType.NO_TARGET

func get_display_text() -> String:
	return "%s\n%s" % [card_name, description]
