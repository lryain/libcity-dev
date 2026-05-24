class_name CharMovement extends Node

enum SpecialType {NONE, JETPACK}

## Character movement may need to pass something up to HUD
signal character_hud_update(update: CharHudUpdate)


## reference to character using this movement component - passed from above
var character: CharacterBody3D:
	set(value):
		character = value
		on_character_changed()


## A hook to add logic when we recieve the character reference
func on_character_changed() -> void:
	pass


## Called once for every aim event (might be multiple times per physics frame)
func aim(aim: Vector2) -> void:
	pass


## Called on respawn
func reset() -> void:
	pass


## Called every physics frame by character
func process(delta:float) -> void:
	pass


## these must be exposed for HUD to be able to update properly
var special_type : SpecialType = SpecialType.NONE # type of special movement ability
var special_active : bool = false # is the special currently used?
var special_amount : float = 1 # fraction shown on the special bar in HUD (fuel, cooldown etc.)
