extends Resource
class_name CharacterProfile

# This class contains information about character appearance customization
# and other personalized stuff that will be visible to other players in-game

# character display name (scoreboard, chat etc.)
@export var display_name : String = "Default"
# character color (chat, scoreboard name color, character model accents etc.)
@export var display_color : Color = Color.DARK_GRAY
# character custom face texture
#@export var face : Texture2D = load("res://Assets/Characters/Faces/FacePlaceholder.png")

@export var avatar_hash := PackedByteArray()

# 1st person vertical FOV
@export var fov : int = 90

@export var badges : Array[Badges.Badge] = [Badges.Badge.ERROR]

@export var voice : String = "res://Assets/Characters/CharacterVoices/Default.tres"
@export var voice_pitch : float = 1
