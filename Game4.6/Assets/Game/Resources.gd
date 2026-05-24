extends Node
# This script is there to keep references to resources that need to stay in memory at all times during a game to avoid lag spikes

var resources = []

var paths = [
	"res://Assets/Characters/Character.tscn",
	"res://Assets/Characters/CharacterControllerBot.tscn",
	"res://Assets/Characters/CharacterControllerPlayer.tscn",
	"res://Assets/Weapons/WeaponTypes/Generic/Weapon.tscn",
	"res://Assets/Weapons/WeaponTypes/ShootingWeapon/ShootingWeapon.tscn",
	"res://Assets/Weapons/WeaponTypes/ProjectileShootingWeapon/ProjectileShootingWeapon.tscn",
	"res://Assets/Weapons/WeaponTypes/HitscanShootingWeapon/HitscanShootingWeapon.tscn",
	"res://Assets/Weapons/WeaponTypes/HitscanShootingWeapon/AutomaticHitscanShootingWeapon.tscn",
	"res://Assets/Weapons/WeaponTypes/ProjectileShootingWeapon/Projectiles/Projectile.tscn",
	"res://Assets/Weapons/WeaponTypes/ProjectileShootingWeapon/Projectiles/Projectile2.tscn",
	"res://Assets/Weapons/Damage/Explosion.tscn",
	"res://Assets/Effects/ImpactExplosion.tscn",
	"res://Assets/Effects/ImpactPlasma.tscn",
	"res://Assets/Effects/ImpactPlasmaExplosion.tscn",
	"res://Assets/Effects/PlasmaComboExplosion.tscn",
]


func load_resources():
	for i in paths:
		resources.append(load(i))


func unload_resources():
	resources.clear()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_resources()


func _exit_tree() -> void:
	unload_resources()
