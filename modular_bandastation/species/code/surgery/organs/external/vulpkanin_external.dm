/// VULPKANIN TAIL

/obj/item/organ/tail/vulpkanin
	name = "vulpkanin tail"

	bodypart_overlay = /datum/bodypart_overlay/mutant/tail/vulpkanin

	wag_flags = WAG_ABLE
	dna_block = /datum/dna_block/feature/accessory/vulpkanin_tail
	var/datum/bodypart_overlay/mutant/vulpkanin_tail_markings/tail_markings_overlay

/obj/item/organ/tail/vulpkanin/on_mob_insert(mob/living/carbon/owner)
	. = ..()
	add_verb(owner, /mob/living/carbon/human/proc/emote_wag)

/obj/item/organ/tail/vulpkanin/on_mob_remove(mob/living/carbon/owner)
	. = ..()
	remove_verb(owner, /mob/living/carbon/human/proc/emote_wag)

/datum/bodypart_overlay/mutant/tail/vulpkanin
	feature_key = FEATURE_VULPKANIN_TAIL

/datum/bodypart_overlay/mutant/tail/vulpkanin/get_global_feature_list()
	return SSaccessories.feature_list[FEATURE_VULPKANIN_TAIL]

/obj/item/organ/tail/vulpkanin/on_bodypart_insert(obj/item/bodypart/bodypart)
	var/data = ..()
	insert_tail_markings(bodypart)
	return data

/obj/item/organ/tail/vulpkanin/on_bodypart_remove(obj/item/bodypart/bodypart)
	remove_tail_markings(bodypart)
	return ..()

/obj/item/organ/tail/vulpkanin/proc/insert_tail_markings(obj/item/bodypart/bodypart)
	if(tail_markings_overlay)
		return

	var/mob/living/carbon/human/human = bodypart.owner
	if(!istype(human))
		return
	var/feature_name = human.dna.features[FEATURE_VULPKANIN_TAIL_MARKINGS]
	if(!feature_name || feature_name == SPRITE_ACCESSORY_NONE)
		return
	var/datum/sprite_accessory/marking = SSaccessories.feature_list[FEATURE_VULPKANIN_TAIL_MARKINGS][feature_name]
	if(!marking)
		return

	tail_markings_overlay = new
	tail_markings_overlay.source_tail = bodypart_overlay
	tail_markings_overlay.sprite_datum = marking
	tail_markings_overlay.tail_markings_color = human.dna.features[FEATURE_VULPKANIN_TAIL_MARKINGS_COLOR]
	bodypart.add_bodypart_overlay(tail_markings_overlay)

/obj/item/organ/tail/vulpkanin/proc/remove_tail_markings(obj/item/bodypart/bodypart)
	if(!tail_markings_overlay)
		return
	bodypart.remove_bodypart_overlay(tail_markings_overlay)
	QDEL_NULL(tail_markings_overlay)

/// MARK: bodypart overlay

/datum/bodypart_overlay/mutant/vulpkanin_tail_markings
	parent_type = /datum/bodypart_overlay/mutant/tail_detail
	feature_key = FEATURE_VULPKANIN_TAIL_MARKINGS
	color_source = ORGAN_COLOR_OVERRIDE
	var/tail_markings_color = "#FFFFFF"

/datum/bodypart_overlay/mutant/vulpkanin_tail_markings/get_global_feature_list()
	return SSaccessories.feature_list[FEATURE_VULPKANIN_TAIL_MARKINGS]

/datum/bodypart_overlay/mutant/vulpkanin_tail_markings/override_color(rgb_value)
	return tail_markings_color
