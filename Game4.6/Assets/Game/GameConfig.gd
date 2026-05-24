class_name GameConfig extends Resource

# this resource determines how GameState behavies, influencing various settings of a game host

@export_range(0, 1) var friendy_fire_amount : float = 0
@export_range(0, 15) var respawn_wait_time : float = 5.0 # seconds
@export_range(0, 1000) var match_score_limit : int = 250 # points
@export_range(0, 60) var match_time_limit_minutes : int = 10 # minutes

@export_range(0,32) var bot_amount : int = 5 # maximum amount of bots
@export var bots_fill_vacant : bool = true # bots will only take plaes of human players or they will stay there at all times
@export var bots_vs_humans : bool = false # bots and humans will always be on opposing teams

@export var game_mode : Globals.GameMode = Globals.GameMode.CONTROL_POINTS
@export var map : String = "CP1"
