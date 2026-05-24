class_name CharacterState

var health : int
var alive : bool = true
var team := Globals.Teams.NONE
var kills : int = 0
var deaths : int = 0

#var zoomed_in := false

#var user_id =

# spawning
var spawn_time : float = 0 # scheduled (re)spawn time
#var spawn_transform : Transform3D # scheduled (re)spawn location

# connection stats
var ping : float
var packet_loss : float
