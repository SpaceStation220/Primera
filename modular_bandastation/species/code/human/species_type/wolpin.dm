/// The primitive canid form of a vulpkanin, using the shared lesser-humanoid mechanics.
/datum/species/monkey/wolpin
	recycled_cube_type = /obj/item/food/monkeycube/wolpin
	gib_anim = null
	name = "Волпин"
	plural_form = "Волпины"
	id = "wolpin"
	adult_form = /datum/species/vulpkanin
	changesource_flags = MIRROR_BADMIN
	mutanttongue = /obj/item/organ/tongue/monkey/wolpin
	species_language_holder = /datum/language_holder/wolpin
	mutant_organs = list(/obj/item/organ/tail/monkey/wolpin = "Wolpin")
	bodypart_overrides = list(
		BODY_ZONE_HEAD = /obj/item/bodypart/head/monkey/wolpin,
		BODY_ZONE_CHEST = /obj/item/bodypart/chest/monkey/wolpin,
		BODY_ZONE_L_ARM = /obj/item/bodypart/arm/left/monkey/wolpin,
		BODY_ZONE_R_ARM = /obj/item/bodypart/arm/right/monkey/wolpin,
		BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left/monkey/wolpin,
		BODY_ZONE_R_LEG = /obj/item/bodypart/leg/right/monkey/wolpin,
	)

/// A natural wolpin, including the normal lesser-form AI and cube population tracking.
/mob/living/carbon/human/species/monkey/wolpin
	race = /datum/species/monkey/wolpin
	icon = 'icons/bandastation/mob/species/wolpin/bodyparts.dmi'
	icon_state = "wolpin_chest"

/// Wolpin tails share the monkey-tail feature catalog, but have their own appearance.
/obj/item/organ/tail/monkey/wolpin
	name = "хвост волпина"
	icon = 'icons/bandastation/mob/species/wolpin/tail.dmi'
	icon_state = "m_tail_monkey_wolpin_BEHIND"
	dir = EAST // The behind layer has a visible side sprite for the dropped organ.
	restyle_flags = NONE
	sprite_accessory_override = /datum/sprite_accessory/tails/monkey/wolpin

/datum/sprite_accessory/tails/monkey/wolpin
	name = "Wolpin"
	icon = 'icons/bandastation/mob/species/wolpin/tail.dmi'
	icon_state = "wolpin"
	color_src = FALSE
	natural_spawn = FALSE

/// A dehydrated wolpin. Expansion and population limits are inherited from monkey cubes.
/obj/item/food/monkeycube/wolpin
	name = "кубик волпина"
	desc = "Обезвоженный волпин. Просто добавьте воды!"
	icon = 'icons/bandastation/mob/species/wolpin/cubes.dmi'
	spawned_mob = /mob/living/carbon/human/species/monkey/wolpin

/obj/item/storage/box/monkeycubes/wolpin
	name = "коробка кубиков волпинов"
	desc = "Пять обезвоженных волпинов. Просто добавьте воды!"
	icon = 'icons/bandastation/mob/species/wolpin/box.dmi'
	icon_state = "wolpin_box"
	illustration = null
	cube_type = /obj/item/food/monkeycube/wolpin

/obj/item/bodypart/arm/right/monkey/wolpin
	icon = 'icons/bandastation/mob/species/wolpin/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/wolpin/bodyparts.dmi'
	icon_state = "wolpin_r_arm"
	limb_id = "wolpin"

/obj/item/bodypart/arm/left/monkey/wolpin
	icon = 'icons/bandastation/mob/species/wolpin/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/wolpin/bodyparts.dmi'
	icon_state = "wolpin_l_arm"
	limb_id = "wolpin"

/obj/item/bodypart/head/monkey/wolpin
	parent_type = /obj/item/bodypart/head/monkey/native_height
	icon = 'icons/bandastation/mob/species/wolpin/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/wolpin/bodyparts.dmi'
	icon_state = "wolpin_head"
	limb_id = "wolpin"
	native_helmet_x = list("south" = 0, "east" = -1, "west" = 1)
	native_helmet_y = list("south" = -1)
	native_eyes_y = list("south" = 0)

/obj/item/bodypart/chest/monkey/wolpin
	parent_type = /obj/item/bodypart/chest/monkey/native_height
	icon = 'icons/bandastation/mob/species/wolpin/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/wolpin/bodyparts.dmi'
	icon_state = "wolpin_chest"
	limb_id = "wolpin"
	native_clothing_offset_y = list("south" = 6, "north" = 7)

/obj/item/bodypart/leg/right/monkey/wolpin
	icon = 'icons/bandastation/mob/species/wolpin/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/wolpin/bodyparts.dmi'
	icon_state = "wolpin_r_leg"
	limb_id = "wolpin"

/obj/item/bodypart/leg/left/monkey/wolpin
	icon = 'icons/bandastation/mob/species/wolpin/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/wolpin/bodyparts.dmi'
	icon_state = "wolpin_l_leg"
	limb_id = "wolpin"


/// A canid primitive tongue keeps the lesser-form speech restrictions without primate sounds.
/obj/item/organ/tongue/monkey/wolpin
	parent_type = /obj/item/organ/tongue/monkey/lesser_form
	adult_tongue_type = /obj/item/organ/tongue/vulpkanin
	name = "язык волпина"
	desc = "Язык небольшого псового существа."
	say_mod = "лает"
	languages_native = list(/datum/language/monkey/wolpin)
	emote_sounds = list(
		/datum/emote/living/scream::key = 'sound/mobs/non-humanoids/wolpin/dog_yelp.ogg',
		/datum/emote/living/carbon/human/vulpkanin/bark::key = list(
			'sound/mobs/non-humanoids/wolpin/dog_bark1.ogg',
			'sound/mobs/non-humanoids/wolpin/dog_bark2.ogg',
		),
	)

/datum/language/monkey/wolpin
	name = "Волпинский"
	desc = "Гортанные звуки, рычание и лай, отдалённо напоминающие канилунц."
	key = "r"
	syllables = list("гав", "вуф", "рр", "ау", "вух")

/datum/language/monkey/wolpin/get_random_name(gender = NEUTER, name_count = 2, syllable_min = 2, syllable_max = 4, force_use_syllables = FALSE)
	return "волпин ([rand(1, 999)])"

/datum/language_holder/wolpin
	understood_languages = list(
		/datum/language/common = list(LANGUAGE_ATOM),
		/datum/language/monkey/wolpin = list(LANGUAGE_ATOM),
	)
	spoken_languages = list(/datum/language/monkey/wolpin = list(LANGUAGE_ATOM))

/// Wolpins can bark without granting the other greater-form emotes.
/datum/emote/living/carbon/human/vulpkanin/bark/wolpin
	species_type_whitelist_typecache = list(/datum/species/monkey/wolpin)
	sound = 'sound/mobs/non-humanoids/wolpin/dog_bark1.ogg'
