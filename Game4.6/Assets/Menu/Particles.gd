extends VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%ParticleDensitySlider.value = Settings.get_var("render_particles_amount")
	%ParticleDensityValueLabel.text = str(%ParticleDensitySlider.value)


func _on_particle_density_slider_value_changed(value: float) -> void:
	Settings.set_var("render_particles_amount", value)
	%ParticleDensityValueLabel.text = str(value)
