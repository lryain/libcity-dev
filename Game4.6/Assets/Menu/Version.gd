extends RichTextLabel

var y := -1

var in_bbcode := false

var text_no_bbcode : String = ""


func _ready():

	text = Globals.get_version_string()

	in_bbcode = false
	for i in range(text.length()):
		if text.substr(i, 1) == "[":
			in_bbcode = true
		elif text.substr(i -1 , 1) == "]":
			in_bbcode = false

		if not in_bbcode:
			text_no_bbcode += text.substr(i, 1)


	# text animation
	var tween = create_tween()
#	tween.custom_step(1.0 / text.length())
	#tween.step_finished.connect(func(): print("step"); $AudioStreamPlayer.play())

	visible_ratio = 0.0
	tween.tween_interval(1)
	tween.tween_property(self, "visible_ratio", 1.0, 1)
	tween.parallel()
	tween.tween_method(play_text_sfx, -1, text_no_bbcode.length() -1, 1)
	y = -1
	tween.play()


func play_text_sfx(x: int) -> void:
	if x != y and text_no_bbcode.substr(x, 1) != " ":
		y = x
#		print(x, " ", text_no_bbcode.substr(x, 1))
		self.get_node("AudioStreamPlayer").play()
