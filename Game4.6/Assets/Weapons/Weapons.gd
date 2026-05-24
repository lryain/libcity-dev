class_name Weapons

#enum WeaponSlot {
#	PRIMARY,
#	SECONDARY,
#	TERTIARY,
#}

enum Weapon {
	NONE = -1, # otherwise null will give the same value as
	GENERIC = 1,
	HITSCAN = 2,
	AUTOMATIC = 3,
	PLASMA = 4,
}

const WeaponScenePaths = {
	Weapon.NONE : null,
	Weapon.GENERIC : "res://Assets/Weapons/WeaponTypes/Generic/Weapon.tscn",
	Weapon.HITSCAN : "res://Assets/Weapons/WeaponTypes/HitscanShootingWeapon/HitscanShootingWeapon.tscn",
	Weapon.AUTOMATIC : "res://Assets/Weapons/WeaponTypes/HitscanShootingWeapon/AutomaticHitscanShootingWeapon.tscn",
	Weapon.PLASMA : "res://Assets/Weapons/WeaponTypes/ProjectileShootingWeapon/ProjectileShootingWeapon.tscn",
}
