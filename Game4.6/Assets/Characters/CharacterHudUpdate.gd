class_name CharHudUpdate

### This class holds everything that a character can communicate up to HUD for visual and auditory feedback to the player
### HUD will show overlays, animate the croshair etc aas needed

var character : Character
var state : CharacterState

# for the overlays (bleeding eyes etc.)
var got_damage: Damage # what damage did the character recieve?
var got_healing: int # how much healing did the character recieve?
var got_ammo: int # how much ammo did the character pick up?

# for crosshair animation
var did_damage: int # how much damage did the character deal to others?
var did_kill: Character # did the character just kill someone?
var did_healing: int # how much healing did the character deal to others?

# for changing HUD mode
var got_killed: bool # did the character just die?
var got_spawned: bool # did the character just (re)spawn?

# for weapon and ammo displays
var current_weapon: Weapons.Weapon
var current_weapon_clip: int # how many shots before reloading?
var current_weapon_stock: int # how many shots in stock (not counting clip)?


var special_type: CharMovement.SpecialType # what's the special move/action used for HUD but not only
var special_active: bool
var special_amount: float # range: depleted = 0.0 - full = 1.0; This can be jetpack fuel, special move or grappling hook recharge etc.

# for crosshair grey-out and vignette
var zoom: bool
var zoom_amount: float # how much zoomed in the character is
