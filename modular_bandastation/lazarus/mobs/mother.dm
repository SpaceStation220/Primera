// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/** Defenseless source of the colony's sacred meat. */
/mob/living/basic/great_mother
	name = "великая мать"
	desc = "Огромный беззащитный глазной отросток, управляющий биомассой."
	health = 800
	maxHealth = 800
	icon = 'modular_bandastation/lazarus/icons/great_mother.dmi'
	icon_state = "mother"
	icon_living = "mother"
	move_resist = MOVE_FORCE_STRONG
	faction = list("treacherous_flesh")
	status_flags = CANPUSH
	physiology = list(STAMINA = 0)
	death_sound = 'modular_bandastation/lazarus/sound/shadowdeath.ogg'

/mob/living/basic/great_mother/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_NOFIRE, INNATE_TRAIT)
	AddElement(/datum/element/death_drops, string_list(list(/obj/item/food/meat/slab/mother = 15)))

/mob/living/basic/great_mother/death(gibbed)
	. = ..()
	if(. && !gibbed)
		gib()

/obj/item/food/meat/slab/mother
	name = "плоть великой матери"
	desc = "Священная плоть."
// AI EDIT END
