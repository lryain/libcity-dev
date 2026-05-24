class_name PlayerInfo


var name: String
var team: int
var color: Color
var focus: Globals.Focus
var health: int
var score: int
var ping: int
var packet_loss: int

func _init() -> void:
	self.name = "" #player_name
	self.color = Color.WHITE # TODO: Assign random color: Color(randf(),randf(),randf())
	self.team = 0
	self.focus = 999
	self.health = 100
	self.score = 0
	self.ping = -1
	self.packet_loss = -1

func serialize():
	return {
		'name': self.name,
		'team': str(self.team),
		'color': self.color.to_html(),
		'focus': self.focus,
		'health': self.health,
		'score': self.score,
		'ping': self.ping,
		'loss': self.packet_loss,
	}
func set_info(name: String, team: int, color: Color, focus: int, health: int, score: int, ping: int, packet_loss: int) -> void:
	self.name = name
	self.team = team
	self.color = color
	self.focus = focus
	self.health = health
	self.score = score
	self.ping = ping
	self.packet_loss = packet_loss

func deserialize(info) -> void:
	self.name = info['name']
	self.team = info['team'].to_int()
	self.color = Color.html(info['color'])
	self.focus = info['focus']
	self.health = info['health']
	self.score = info['score']
	self.ping = info['ping']
	self.packet_loss = info['loss']
