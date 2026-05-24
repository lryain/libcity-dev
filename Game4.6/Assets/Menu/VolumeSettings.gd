extends VBoxContainer


func _ready() -> void:
	pass


func _master_volume_changed(value: float) -> void:
	Settings.set_var("audio_volume_master", value)


func _music_volume_changed(value: float) -> void:
	Settings.set_var("audio_volume_music", value)


func _sfx_volume_changed(value: float) -> void:
	Settings.set_var("audio_volume_sfx", value)


func _ui_volume_changed(value: float) -> void:
	Settings.set_var("audio_volume_ui", value)


func _on_visibility_changed():
	if visible:
		%MasterSlider.set_value_no_signal(Settings.get_var("audio_volume_master"))
		%MusicSlider.set_value_no_signal(Settings.get_var("audio_volume_music"))
		%SfxSlider.set_value_no_signal(Settings.get_var("audio_volume_sfx"))
		%UiSlider.set_value_no_signal(Settings.get_var("audio_volume_ui"))
