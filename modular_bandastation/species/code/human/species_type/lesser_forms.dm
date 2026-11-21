/// A primitive tongue that uses the adult form's configured emote sounds.
/obj/item/organ/tongue/monkey/lesser_form
	emote_sounds = list(/datum/emote/living/scream::key = "")
	/// Adult tongue that supplies the sound overrides without changing speech or taste.
	var/obj/item/organ/tongue/adult_tongue_type

/obj/item/organ/tongue/monkey/lesser_form/Initialize(mapload)
	if(!adult_tongue_type)
		return ..()
	// DM initializes these lists on the organ, so read each adult tongue once.
	var/static/list/sound_overrides_by_tongue = list()
	var/list/adult_sounds = sound_overrides_by_tongue[adult_tongue_type]
	if(isnull(adult_sounds))
		var/obj/item/organ/tongue/adult_tongue = new adult_tongue_type(null)
		var/list/configured_sounds = adult_tongue.emote_sounds
		adult_sounds = configured_sounds?.Copy() || list()
		sound_overrides_by_tongue[adult_tongue_type] = adult_sounds
		qdel(adult_tongue)
	var/list/primitive_sounds = emote_sounds
	primitive_sounds = primitive_sounds.Copy()
	for(var/key in adult_sounds)
		primitive_sounds[key] = adult_sounds[key]
	emote_sounds = primitive_sounds
	return ..()

/obj/item/organ/tongue/monkey/lesser_form/stok
	adult_tongue_type = /obj/item/organ/tongue/lizard

/obj/item/organ/tongue/monkey/lesser_form/neara
	adult_tongue_type = /obj/item/organ/tongue/skrell

/obj/item/organ/tongue/monkey/lesser_form/worme
	adult_tongue_type = /obj/item/organ/tongue/moth

/obj/item/organ/tongue/monkey/lesser_form/farwa
	adult_tongue_type = /obj/item/organ/tongue/tajaran

/obj/item/organ/tongue/monkey/lesser_form/sparra
	adult_tongue_type = /obj/item/organ/tongue/vox

/// A chest drawn at the final small size already, without the default monkey displacement.
/obj/item/bodypart/chest/monkey/native_height
	/// Lift human-proportioned clothing from the filtered monkey chest to this sprite's shoulders.
	var/list/native_clothing_offset_y = list("south" = 4)

/obj/item/bodypart/chest/monkey/native_height/Initialize(mapload)
	worn_uniform_offset = new /datum/worn_feature_offset/native_monkey_clothing(src, OFFSET_UNIFORM, offset_y = native_clothing_offset_y)
	worn_suit_offset = new /datum/worn_feature_offset/native_monkey_clothing(src, OFFSET_SUIT, offset_y = native_clothing_offset_y)
	return ..()

/obj/item/bodypart/chest/monkey/native_height/update_mob_heights(mob/living/carbon/holder)
	. = ..()
	if(. == MONKEY_HEIGHT_MEDIUM)
		return NATIVE_MONKEY_HEIGHT_MEDIUM

/// Match the clothing position to native-size sprites. Height traits filter the body as well as the clothing.
/datum/worn_feature_offset/native_monkey_clothing/apply_offset(image/overlay)
	var/mob/living/carbon/human/wearer = attached_part.owner
	if(wearer?.mob_height == NATIVE_MONKEY_HEIGHT_MEDIUM)
		return ..()

/// A head with independent anchors for the crown and face of the native-size sprite.
/obj/item/bodypart/head/monkey/native_height
	/// Horizontal helmet placement by facing, defaulting to the center.
	var/list/native_helmet_x
	/// Vertical helmet placement by facing.
	var/list/native_helmet_y = list("south" = -3)
	/// Horizontal mask and eyewear placement at the face.
	var/list/native_face_x = list("south" = 0, "east" = -1, "west" = 1)
	/// Vertical eyewear placement at eye level.
	var/list/native_eyes_y = list("south" = -2)

/obj/item/bodypart/head/monkey/native_height/Initialize(mapload)
	worn_head_offset = new(src, OFFSET_HEAD, offset_x = native_helmet_x, offset_y = native_helmet_y)
	worn_mask_offset = new(src, OFFSET_FACEMASK, offset_x = native_face_x, offset_y = native_eyes_y)
	worn_glasses_offset = new(src, OFFSET_GLASSES, offset_x = native_face_x, offset_y = native_eyes_y)
	return ..()

/datum/species/monkey/stok
	name = "Сток"
	mutanttongue = /obj/item/organ/tongue/monkey/lesser_form/stok
	gib_anim = null
	changesource_flags = MIRROR_BADMIN
	plural_form = "Стоки"
	id = "stok"
	adult_form = /datum/species/lizard
	recycled_cube_type = /obj/item/food/monkeycube/stok
	mutant_organs = list(/obj/item/organ/tail/monkey/stok = "Сток")
	bodypart_overrides = list(
		BODY_ZONE_HEAD = /obj/item/bodypart/head/monkey/stok,
		BODY_ZONE_CHEST = /obj/item/bodypart/chest/monkey/native_height/stok,
		BODY_ZONE_L_ARM = /obj/item/bodypart/arm/left/monkey/stok,
		BODY_ZONE_R_ARM = /obj/item/bodypart/arm/right/monkey/stok,
		BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left/monkey/stok,
		BODY_ZONE_R_LEG = /obj/item/bodypart/leg/right/monkey/stok,
	)

/mob/living/carbon/human/species/monkey/stok
	race = /datum/species/monkey/stok
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "stok_chest"

/obj/item/food/monkeycube/stok
	name = "кубик стока"
	desc = "Этот обезвоженный экземпляр оживёт, если добавить воды."
	spawned_mob = /mob/living/carbon/human/species/monkey/stok

/obj/item/storage/box/monkeycubes/stok
	name = "коробка кубиков стоков"
	desc = "Пять обезвоженных экземпляров. Просто добавьте воды!"
	icon = 'icons/bandastation/mob/species/lesser_forms/boxes.dmi'
	icon_state = "stok_box"
	cube_type = /obj/item/food/monkeycube/stok

/obj/item/organ/tail/monkey/stok
	name = "хвост стока"
	icon = 'icons/bandastation/mob/species/lesser_forms/tails.dmi'
	icon_state = "m_tail_monkey_stok_BEHIND"
	dir = EAST
	restyle_flags = NONE
	sprite_accessory_override = /datum/sprite_accessory/tails/monkey/stok

/datum/sprite_accessory/tails/monkey/stok
	name = "Сток"
	icon = 'icons/bandastation/mob/species/lesser_forms/tails.dmi'
	icon_state = "stok"
	color_src = FALSE
	natural_spawn = FALSE

/obj/item/bodypart/head/monkey/stok
	parent_type = /obj/item/bodypart/head/monkey/native_height
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "stok_head"
	limb_id = "stok"

/obj/item/bodypart/chest/monkey/native_height/stok
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "stok_chest"
	limb_id = "stok"

/obj/item/bodypart/arm/left/monkey/stok
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "stok_l_arm"
	limb_id = "stok"

/obj/item/bodypart/arm/right/monkey/stok
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "stok_r_arm"
	limb_id = "stok"

/obj/item/bodypart/leg/left/monkey/stok
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "stok_l_leg"
	limb_id = "stok"

/obj/item/bodypart/leg/right/monkey/stok
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "stok_r_leg"
	limb_id = "stok"

/datum/species/monkey/neara
	name = "Неара"
	mutanttongue = /obj/item/organ/tongue/monkey/lesser_form/neara
	gib_anim = null
	changesource_flags = MIRROR_BADMIN
	plural_form = "Неары"
	id = "neara"
	adult_form = /datum/species/skrell
	recycled_cube_type = /obj/item/food/monkeycube/neara
	mutant_organs = null
	bodypart_overrides = list(
		BODY_ZONE_HEAD = /obj/item/bodypart/head/monkey/neara,
		BODY_ZONE_CHEST = /obj/item/bodypart/chest/monkey/native_height/neara,
		BODY_ZONE_L_ARM = /obj/item/bodypart/arm/left/monkey/neara,
		BODY_ZONE_R_ARM = /obj/item/bodypart/arm/right/monkey/neara,
		BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left/monkey/neara,
		BODY_ZONE_R_LEG = /obj/item/bodypart/leg/right/monkey/neara,
	)

/mob/living/carbon/human/species/monkey/neara
	race = /datum/species/monkey/neara
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "neara_chest"

/obj/item/food/monkeycube/neara
	name = "кубик неары"
	desc = "Этот обезвоженный экземпляр оживёт, если добавить воды."
	spawned_mob = /mob/living/carbon/human/species/monkey/neara

/obj/item/storage/box/monkeycubes/neara
	name = "коробка кубиков неар"
	desc = "Пять обезвоженных экземпляров. Просто добавьте воды!"
	icon = 'icons/bandastation/mob/species/lesser_forms/boxes.dmi'
	icon_state = "neaera_box"
	cube_type = /obj/item/food/monkeycube/neara

/obj/item/bodypart/head/monkey/neara
	parent_type = /obj/item/bodypart/head/monkey/native_height
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "neara_head"
	limb_id = "neara"

/obj/item/bodypart/chest/monkey/native_height/neara
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "neara_chest"
	limb_id = "neara"

/obj/item/bodypart/arm/left/monkey/neara
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "neara_l_arm"
	limb_id = "neara"

/obj/item/bodypart/arm/right/monkey/neara
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "neara_r_arm"
	limb_id = "neara"

/obj/item/bodypart/leg/left/monkey/neara
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "neara_l_leg"
	limb_id = "neara"

/obj/item/bodypart/leg/right/monkey/neara
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "neara_r_leg"
	limb_id = "neara"

/datum/species/monkey/worme
	name = "Нианский червь"
	mutanttongue = /obj/item/organ/tongue/monkey/lesser_form/worme
	gib_anim = null
	changesource_flags = MIRROR_BADMIN
	plural_form = "Нианские черви"
	id = SPECIES_WORME
	adult_form = /datum/species/moth
	recycled_cube_type = /obj/item/food/monkeycube/worme
	mutant_organs = null
	bodypart_overrides = list(
		BODY_ZONE_HEAD = /obj/item/bodypart/head/monkey/worme,
		BODY_ZONE_CHEST = /obj/item/bodypart/chest/monkey/native_height/worme,
		BODY_ZONE_L_ARM = /obj/item/bodypart/arm/left/monkey/worme,
		BODY_ZONE_R_ARM = /obj/item/bodypart/arm/right/monkey/worme,
		BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left/monkey/worme,
		BODY_ZONE_R_LEG = /obj/item/bodypart/leg/right/monkey/worme,
	)

/mob/living/carbon/human/species/monkey/worme
	race = /datum/species/monkey/worme
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "worme_chest"

/obj/item/food/monkeycube/worme
	name = "кубик нианского червя"
	desc = "Этот обезвоженный экземпляр оживёт, если добавить воды."
	spawned_mob = /mob/living/carbon/human/species/monkey/worme

/obj/item/storage/box/monkeycubes/worme
	name = "коробка кубиков нианских червей"
	desc = "Пять обезвоженных экземпляров. Просто добавьте воды!"
	icon = 'icons/bandastation/mob/species/lesser_forms/boxes.dmi'
	icon_state = "nian_worme_box"
	cube_type = /obj/item/food/monkeycube/worme

/obj/item/bodypart/head/monkey/worme
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "worme_head"
	limb_id = "worme"

/obj/item/bodypart/head/monkey/worme/Initialize(mapload)
	// The head sits lower in front and back and leans toward the back of the side frame.
	var/static/list/height_offsets = list("south" = -3, "east" = -2, "west" = -2)
	var/static/list/head_offsets = list("south" = 0, "east" = -2, "west" = 2)
	var/static/list/ear_offsets = list("south" = 0, "east" = -1, "west" = 1)
	worn_head_offset = new(src, OFFSET_HEAD, offset_x = head_offsets, offset_y = height_offsets)
	worn_mask_offset = new(src, OFFSET_FACEMASK, offset_x = head_offsets, offset_y = height_offsets)
	worn_glasses_offset = new(src, OFFSET_GLASSES, offset_x = head_offsets, offset_y = height_offsets)
	worn_ears_offset = new(src, OFFSET_EARS, offset_x = ear_offsets, offset_y = height_offsets)
	return ..()

/obj/item/bodypart/chest/monkey/native_height/worme
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "worme_chest"
	limb_id = SPECIES_WORME
	native_clothing_offset_y = list("south" = 4, "east" = 3, "west" = 3)

/obj/item/bodypart/arm/left/monkey/worme
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "worme_l_arm"
	limb_id = "worme"

/obj/item/bodypart/arm/right/monkey/worme
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "worme_r_arm"
	limb_id = "worme"

/obj/item/bodypart/leg/left/monkey/worme
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "worme_l_leg"
	limb_id = "worme"

/obj/item/bodypart/leg/right/monkey/worme
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "worme_r_leg"
	limb_id = "worme"

/datum/species/monkey/farwa
	name = "Фарва"
	mutanttongue = /obj/item/organ/tongue/monkey/lesser_form/farwa
	gib_anim = null
	changesource_flags = MIRROR_BADMIN
	plural_form = "Фарвы"
	id = "farwa"
	adult_form = /datum/species/tajaran
	recycled_cube_type = /obj/item/food/monkeycube/farwa
	mutant_organs = list(/obj/item/organ/tail/monkey/farwa = "Фарва")
	bodypart_overrides = list(
		BODY_ZONE_HEAD = /obj/item/bodypart/head/monkey/farwa,
		BODY_ZONE_CHEST = /obj/item/bodypart/chest/monkey/native_height/farwa,
		BODY_ZONE_L_ARM = /obj/item/bodypart/arm/left/monkey/farwa,
		BODY_ZONE_R_ARM = /obj/item/bodypart/arm/right/monkey/farwa,
		BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left/monkey/farwa,
		BODY_ZONE_R_LEG = /obj/item/bodypart/leg/right/monkey/farwa,
	)

/mob/living/carbon/human/species/monkey/farwa
	race = /datum/species/monkey/farwa
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "farwa_chest"

/obj/item/food/monkeycube/farwa
	name = "кубик фарвы"
	desc = "Этот обезвоженный экземпляр оживёт, если добавить воды."
	spawned_mob = /mob/living/carbon/human/species/monkey/farwa

/obj/item/storage/box/monkeycubes/farwa
	name = "коробка кубиков фарв"
	desc = "Пять обезвоженных экземпляров. Просто добавьте воды!"
	icon = 'icons/bandastation/mob/species/lesser_forms/boxes.dmi'
	icon_state = "farwa_box"
	cube_type = /obj/item/food/monkeycube/farwa

/obj/item/organ/tail/monkey/farwa
	name = "хвост фарвы"
	icon = 'icons/bandastation/mob/species/lesser_forms/tails.dmi'
	icon_state = "m_tail_monkey_farwa_BEHIND"
	dir = EAST
	restyle_flags = NONE
	sprite_accessory_override = /datum/sprite_accessory/tails/monkey/farwa

/datum/sprite_accessory/tails/monkey/farwa
	name = "Фарва"
	icon = 'icons/bandastation/mob/species/lesser_forms/tails.dmi'
	icon_state = "farwa"
	color_src = FALSE
	natural_spawn = FALSE

/obj/item/bodypart/head/monkey/farwa
	parent_type = /obj/item/bodypart/head/monkey/native_height
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "farwa_head"
	limb_id = "farwa"
	native_helmet_x = list("south" = 0, "east" = -1, "west" = 1)
	native_helmet_y = list("south" = -2)
	native_eyes_y = list("south" = -3)

/obj/item/bodypart/chest/monkey/native_height/farwa
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "farwa_chest"
	limb_id = "farwa"

/obj/item/bodypart/arm/left/monkey/farwa
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "farwa_l_arm"
	limb_id = "farwa"

/obj/item/bodypart/arm/right/monkey/farwa
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "farwa_r_arm"
	limb_id = "farwa"

/obj/item/bodypart/leg/left/monkey/farwa
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "farwa_l_leg"
	limb_id = "farwa"

/obj/item/bodypart/leg/right/monkey/farwa
	icon = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/bodyparts.dmi'
	icon_state = "farwa_r_leg"
	limb_id = "farwa"

/datum/species/monkey/sparra
	name = "Спарра"
	plural_form = "Спарры"
	id = "sparra"
	changesource_flags = MIRROR_BADMIN
	adult_form = /datum/species/vox
	recycled_cube_type = /obj/item/food/monkeycube/sparra
	mutantlungs = /obj/item/organ/lungs/vox
	mutanttongue = /obj/item/organ/tongue/monkey/lesser_form/sparra
	mutant_organs = null
	gib_anim = null
	no_equip_flags = ITEM_SLOT_OCLOTHING | ITEM_SLOT_GLOVES | ITEM_SLOT_FEET | ITEM_SLOT_SUITSTORE | ITEM_SLOT_ICLOTHING | ITEM_SLOT_HEAD | ITEM_SLOT_EYES
	uniformless_id_type = /obj/item
	uniformless_belt_type = /obj/item/tank/internals/nitrogen/belt
	bodypart_overrides = list(
		BODY_ZONE_HEAD = /obj/item/bodypart/head/monkey/sparra,
		BODY_ZONE_CHEST = /obj/item/bodypart/chest/monkey/native_height/sparra,
		BODY_ZONE_L_ARM = /obj/item/bodypart/arm/left/monkey/sparra,
		BODY_ZONE_R_ARM = /obj/item/bodypart/arm/right/monkey/sparra,
		BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left/monkey/sparra,
		BODY_ZONE_R_LEG = /obj/item/bodypart/leg/right/monkey/sparra,
	)

/mob/living/carbon/human/species/monkey/sparra
	race = /datum/species/monkey/sparra
	icon = 'icons/bandastation/mob/species/lesser_forms/vox_sparra.dmi'
	icon_state = "sparra_chest"

/obj/item/food/monkeycube/sparra
	name = "кубик спарры"
	desc = "Этот обезвоженный экземпляр оживёт, если добавить воды."
	spawned_mob = /mob/living/carbon/human/species/monkey/sparra

/obj/item/storage/box/monkeycubes/sparra
	name = "коробка кубиков спарр"
	desc = "Пять обезвоженных экземпляров. Просто добавьте воды!"
	icon = 'icons/bandastation/mob/species/lesser_forms/boxes.dmi'
	icon_state = "sparra_box"
	cube_type = /obj/item/food/monkeycube/sparra

/obj/item/bodypart/head/monkey/sparra
	icon = 'icons/bandastation/mob/species/lesser_forms/vox_sparra.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/vox_sparra.dmi'
	icon_state = "sparra_head"
	limb_id = "sparra"

/obj/item/bodypart/head/monkey/sparra/Initialize(mapload)
	var/static/list/mask_x = list("south" = 0, "east" = -3, "west" = 3)
	var/static/list/mask_y = list("south" = -2)
	worn_mask_offset = new(src, OFFSET_FACEMASK, offset_x = mask_x, offset_y = mask_y)
	return ..()

/obj/item/bodypart/chest/monkey/native_height/sparra
	icon = 'icons/bandastation/mob/species/lesser_forms/vox_sparra.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/vox_sparra.dmi'
	icon_state = "sparra_chest"
	limb_id = "sparra"

/obj/item/bodypart/arm/left/monkey/sparra
	icon = 'icons/bandastation/mob/species/lesser_forms/vox_sparra.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/vox_sparra.dmi'
	icon_state = "sparra_l_arm"
	limb_id = "sparra"

/obj/item/bodypart/arm/right/monkey/sparra
	icon = 'icons/bandastation/mob/species/lesser_forms/vox_sparra.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/vox_sparra.dmi'
	icon_state = "sparra_r_arm"
	limb_id = "sparra"

/obj/item/bodypart/leg/left/monkey/sparra
	icon = 'icons/bandastation/mob/species/lesser_forms/vox_sparra.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/vox_sparra.dmi'
	icon_state = "sparra_l_leg"
	limb_id = "sparra"

/obj/item/bodypart/leg/right/monkey/sparra
	icon = 'icons/bandastation/mob/species/lesser_forms/vox_sparra.dmi'
	icon_static = 'icons/bandastation/mob/species/lesser_forms/vox_sparra.dmi'
	icon_state = "sparra_r_leg"
	limb_id = "sparra"
