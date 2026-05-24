extends Node
# All possible badges in the game

# APPEND ONLY! modifying this enum's order will result in corrupted user data!
enum Badge {
	ERROR,
	BOT,
	DEV,
	CON,
	SUP,
	ADM,
	MOD,
	PRE_ALPHA,
	ALPHA,
	BETA,
	DAY1,
	AUTH,
	NO_AUTH,
}

# mapping enum values to resources

@onready var resources = {
	Badge.ERROR : load("res://Assets/Badges/Resources/Error.tres"),
	Badge.BOT : load("res://Assets/Badges/Resources/Bot.tres"),
	Badge.DEV : load("res://Assets/Badges/Resources/Developer.tres"),
	Badge.CON : load("res://Assets/Badges/Resources/Contributor.tres"),
	Badge.SUP : load("res://Assets/Badges/Resources/Supporter.tres"),
	Badge.ADM : load("res://Assets/Badges/Resources/Admin.tres"),
	Badge.MOD : load("res://Assets/Badges/Resources/Moderator.tres"),
	Badge.PRE_ALPHA : load("res://Assets/Badges/Resources/PreAlphaTester.tres"),
	Badge.ALPHA : load("res://Assets/Badges/Resources/AlphaTester.tres"),
	Badge.BETA : load("res://Assets/Badges/Resources/BetaTester.tres"),
	Badge.DAY1 : load("res://Assets/Badges/Resources/DayOne.tres"),
	Badge.AUTH : load("res://Assets/Badges/Resources/Auth.tres"),
	Badge.NO_AUTH : load("res://Assets/Badges/Resources/NoAuth.tres"),
}

# returns a badge of highest priority from an array of badges
func get_top_priority_badge(badges: Array):#-> Badge:
	if badges.size() > 0:
#		print("Applying badges: ", profile.badges)
		var priorities = {}
		var min_priority = 1 << 32 # use a really high number to make sure anything will be lower than it
#		print ("Min priority: ", min_priority)
		for i in badges:
#			print(Badges.resources)
			priorities[Badges.resources[i].priority] = i
			min_priority = min(min_priority, Badges.resources[i].priority)

#		print ("Badges by priority: ", priorities)

		return priorities[min_priority]
	else:
		return Badge.ERROR


# same as above, only also looks up the texture resource for the badge
func get_top_priority_badge_texture(badges: Array) -> Texture2D:
	var badge = get_top_priority_badge(badges)
	return get_badge_texture(badge)


# fetch texture resource for a given badge
func get_badge_texture(badge: Badge) -> Texture2D:
	return Badges.resources[badge].texture
