class_name OriginEnding
extends RefCounted
## The story ending (Dialogue Manager: game/data/dialogue/origin.dialogue).
## Plays once, on the debrief of a won run, after all Intel files
## (Story.FILES) have been recovered. The choice is saved in the profile and
## pays a one-off Intel bonus.

const RESOURCE: String = "res://game/data/dialogue/origin.dialogue"
const BONUS_INTEL: int = 300
const ENDINGS: Dictionary = {
	"loyal": "The Corner Office",
	"leak": "Open Channel",
}

var profile: Profile


func _init(p: Profile) -> void:
	profile = p


## Should the ending play after this run?
static func due(p: Profile, ctx: RunContext) -> bool:
	return ctx.won and p.ending == "" and p.lore_pages >= Story.FILES.size()


## Called by the dialogue (`do origin.choose("loyal")`).
func choose(id: String) -> void:
	if not ENDINGS.has(id) or profile.ending != "":
		return
	profile.ending = id
	profile.intel += BONUS_INTEL  # the debrief saves the profile
