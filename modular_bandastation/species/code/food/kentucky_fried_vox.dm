/// Rare slab from a Vox, used for the six-serving recipe.
/obj/item/food/meat/slab/human/mutant/vox
	name = "vox meat"
	desc = "A slab of blue meat from a Vox."
	icon = 'icons/bandastation/obj/food/kentucky_fried_vox.dmi'
	icon_state = "vox_meat"
	slab_color = "#5080be"
	venue_value = FOOD_MEAT_MUTANT_RARE

/// Slab from a Sparra, used for the three-serving recipe.
/obj/item/food/meat/slab/monkey/sparra
	name = "sparra meat"
	desc = "A small slab of blue meat from a Sparra."
	icon = 'icons/bandastation/obj/food/kentucky_fried_vox.dmi'
	icon_state = "vox_meat"
	slab_color = "#5080be"

/// Coat the meat before frying it.
/datum/crafting_recipe/food/breaded_vox
	name = "Vox in crispy breading (6 servings)"
	reqs = list(
		/obj/item/food/meat/slab/human/mutant/vox = 1,
		/datum/reagent/consumable/flour = 5,
		/datum/reagent/consumable/corn_starch = 5,
	)
	result = /obj/item/food/breaded_vox
	added_foodtypes = GRAIN
	dish_category = DISH_MEAT

/datum/crafting_recipe/food/breaded_vox/sparra
	name = "Sparra in crispy breading (3 servings)"
	reqs = list(
		/obj/item/food/meat/slab/monkey/sparra = 1,
		/datum/reagent/consumable/flour = 5,
		/datum/reagent/consumable/corn_starch = 5,
	)
	result = /obj/item/food/breaded_vox/sparra

/// A raw batch. The fryer packs the finished portions when the player takes it out.
/obj/item/food/breaded_vox
	name = "breaded vox"
	desc = "Raw Vox coated in flour and starch. Take it out of a deep fryer after it dings."
	icon = 'icons/bandastation/obj/food/kentucky_fried_vox.dmi'
	icon_state = "breaded_batch"
	foodtypes = MEAT | GRAIN | RAW | GORE
	tastes = list("vox meat" = 2, "breading" = 1)
	/// The bucket determines the yield for the meat used.
	var/obj/item/storage/kentucky_fried_vox/bucket_type = /obj/item/storage/kentucky_fried_vox

/obj/item/food/breaded_vox/sparra
	name = "breaded sparra"
	desc = "Raw Sparra coated in flour and starch. Take it out of a deep fryer after it dings."
	foodtypes = MEAT | GRAIN | RAW
	tastes = list("sparra meat" = 2, "breading" = 1)
	bucket_type = /obj/item/storage/kentucky_fried_vox/sparra

/// Replace this batch with one bucket, dividing the retained reagents among its portions.
/obj/item/food/breaded_vox/proc/pack_servings()
	var/obj/item/storage/kentucky_fried_vox/bucket = new bucket_type(drop_location())
	var/reagents_per_serving = reagents.total_volume / bucket.serving_count
	var/list/handmade_sources = GET_TRAIT_SOURCES(src, TRAIT_HANDMADE)
	for(var/obj/item/food/kentucky_fried_vox/serving in bucket)
		reagents.trans_to(serving, reagents_per_serving, no_react = TRUE)
		for(var/handmade_source in handmade_sources)
			ADD_TRAIT(serving, TRAIT_HANDMADE, handmade_source)
	qdel(src)
	return bucket

/// Holds the cooked pieces in the standard storage interface.
/obj/item/storage/kentucky_fried_vox
	name = "Kentucky Fried Vox"
	desc = "A bucket of crispy fried Vox."
	icon = 'icons/bandastation/obj/food/kentucky_fried_vox.dmi'
	icon_state = "bucket"
	resistance_flags = FLAMMABLE
	/// Number of servings packed into a freshly cooked bucket.
	var/serving_count = 6
	/// Item spawned for each serving.
	var/obj/item/food/kentucky_fried_vox/serving_type = /obj/item/food/kentucky_fried_vox

/obj/item/storage/kentucky_fried_vox/sparra
	name = "Kentucky Fried Vox (Sparra)"
	desc = "A bucket of crispy fried Sparra."
	serving_count = 3
	serving_type = /obj/item/food/kentucky_fried_vox/sparra

/obj/item/storage/kentucky_fried_vox/Initialize(mapload)
	. = ..()
	atom_storage.max_slots = serving_count
	atom_storage.set_holdable(list(/obj/item/food/kentucky_fried_vox))

/obj/item/storage/kentucky_fried_vox/PopulateContents()
	for(var/i in 1 to serving_count)
		new serving_type(src)

/obj/item/storage/kentucky_fried_vox/update_icon_state()
	icon_state = length(contents) ? "bucket" : "bucket_empty"
	return ..()

/obj/item/storage/kentucky_fried_vox/examine(mob/user)
	. = ..()
	var/remaining = length(contents)
	. += span_notice("В ведёрке [remaining] [declension_ru(remaining, "порция", "порции", "порций")].")

/// An individual portion that can be served separately.
/obj/item/food/kentucky_fried_vox
	name = "fried vox piece"
	desc = "A piece of Vox meat in a crispy coating."
	icon = 'icons/bandastation/obj/food/kentucky_fried_vox.dmi'
	icon_state = "serving"
	food_reagents = list(/datum/reagent/consumable/nutriment/protein = 2, /datum/reagent/consumable/nutriment/vitamin = 1)
	foodtypes = MEAT | GRAIN | FRIED | GORE
	food_flags = FOOD_FINGER_FOOD
	tastes = list("vox meat" = 2, "crispy breading" = 1)
	w_class = WEIGHT_CLASS_TINY
	crafting_complexity = FOOD_COMPLEXITY_3

/obj/item/food/kentucky_fried_vox/sparra
	name = "fried sparra piece"
	desc = "A piece of Sparra meat in a crispy coating."
	foodtypes = MEAT | GRAIN | FRIED
	tastes = list("sparra meat" = 2, "crispy breading" = 1)
