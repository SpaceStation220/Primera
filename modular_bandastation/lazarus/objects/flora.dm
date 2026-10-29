// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/** One-use wild crops; harvesting cannot duplicate their finite yield. */
/obj/structure/flora/lazarus
	icon = 'modular_bandastation/lazarus/icons/plants.dmi'
	anchored = TRUE
	max_integrity = 15
	harvest_with_hands = TRUE
	harvest_time = 8 SECONDS
	harvest_amount_low = 3
	harvest_amount_high = 3
	regrowth_time_high = 0
	delete_on_harvest = TRUE
	can_uproot = FALSE
	/// Produce created by the eight-second harvesting action.
	var/harvest_type

/obj/structure/flora/lazarus/get_potential_products()
	if(harvest_type)
		. = list()
		.[harvest_type] = 1

/obj/structure/flora/lazarus/harvest(mob/living/user, product_amount_multiplier = 1)
	if(user && (QDELETED(user) || !isliving(user) || user.incapacitated || !user.Adjacent(src)))
		return FALSE
	. = ..()
	if(. && !delete_on_harvest)
		icon_state = "berry_bush_empty"

/obj/structure/flora/lazarus/berry
	name = "ягодный куст"
	desc = "Куст с разнообразными ягодами. Неясно, как он выжил в столь суровых условиях, но плоды выглядят свежими."
	icon_state = "berry_bush_full"
	harvest_type = /obj/item/food/grown/berries
	harvest_amount_low = 4
	harvest_amount_high = 4
	delete_on_harvest = FALSE

/obj/structure/flora/lazarus/comfrey
	name = "дикий окопник"
	desc = "Растение с целебными свойствами, которое может помочь при травмах."
	icon_state = "comfrey"
	harvest_type = /obj/item/food/grown/comfrey

/obj/structure/flora/lazarus/aloe
	name = "дикое алоэ"
	desc = "Растение с целебными свойствами, которое может помочь при ожогах."
	icon_state = "aloe"
	harvest_type = /obj/item/food/grown/aloe/lazarus
// AI EDIT END
