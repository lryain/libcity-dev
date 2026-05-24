extends AudioStreamPlayer

@onready var go = load("res://Assets/Announcer/Go.wav")
@onready var defeat = load("res://Assets/Announcer/Defeat.wav")
@onready var shame = load("res://Assets/Announcer/Shame.wav")
@onready var victory = load("res://Assets/Announcer/Victory.wav")
@onready var getready = load("res://Assets/Announcer/GetReady.wav")
@onready var victory2 = load("res://Assets/Announcer/MercilessVictory.wav")
@onready var defeat2 = load("res://Assets/Announcer/EmbarrassingDefeat.wav")
@onready var firstblood = load("res://Assets/Announcer/FirstBlood.wav")
@onready var yousuck = load("res://Assets/Announcer/YouSuck.wav")
@onready var payback = load("res://Assets/Announcer/Payback.wav")
@onready var welcome = load("res://Assets/Announcer/Welcome.wav")

func speak(sound) -> void:
	stream = sound
	play()
