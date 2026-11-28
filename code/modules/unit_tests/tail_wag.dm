/// Tests to make sure tail wagging behaves as expected
/datum/unit_test/tail_wag
	// used by the stop_after test
	var/timer_finished = FALSE

/datum/unit_test/tail_wag/Run()
	var/mob/living/carbon/human/dummy = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/tail/cat/dummy_tail = allocate(/obj/item/organ/tail/cat)
	dummy_tail.Insert(dummy, special = TRUE, movement_flags = DELETE_IF_REPLACED)

	// SANITY TEST

	// start wagging
	dummy.wag_tail()
	if(!(dummy_tail.wag_flags & WAG_WAGGING))
		TEST_FAIL("Tail did not start wagging when it should have!")

	// stop wagging
	dummy.unwag_tail()
	if(dummy_tail.wag_flags & WAG_WAGGING)
		TEST_FAIL("Tail did not stop wagging when it should have!")

	// TESTING WAG EMOTE

	// start wagging
	dummy.emote("wag")
	if(!(dummy_tail.wag_flags & WAG_WAGGING))
		TEST_FAIL("Tail did not start wagging after using the *wag emote!")

	// stop wagging
	dummy.emote("wag")
	if(dummy_tail.wag_flags & WAG_WAGGING)
		TEST_FAIL("Tail did not stop wagging after using the *wag emote!")

	// TESTING WAG_ABLE FLAG

	// flip the wag flag to unwaggable
	dummy_tail.wag_flags &= ~WAG_ABLE

	// try to wag it again
	dummy.wag_tail()
	if(dummy_tail.wag_flags & WAG_WAGGING)
		TEST_FAIL("Tail should not have the ability to wag, yet it did!")

	// flip the wag flag to waggable again
	dummy_tail.wag_flags |= WAG_ABLE

	// start wagging again
	dummy.wag_tail()
	if(!(dummy_tail.wag_flags & WAG_WAGGING))
		TEST_FAIL("Tail did not start wagging when it should have!")

	// TESTING STOP_AFTER

	// stop wagging
	dummy.unwag_tail()
	if(dummy_tail.wag_flags & WAG_WAGGING)
		TEST_FAIL("Tail did not stop wagging when it should have!")

	// start wagging, stop after 0.1 seconds
	dummy.wag_tail(0.1 SECONDS)
	// because timers are a pain
	addtimer(VARSET_CALLBACK(src, timer_finished, TRUE), 0.2 SECONDS)
	if(!(dummy_tail.wag_flags & WAG_WAGGING))
		TEST_FAIL("Tail did not start wagging when it should have!")

	UNTIL(timer_finished) // wait a little bit

	if(dummy_tail.wag_flags & WAG_WAGGING)
		TEST_FAIL("Tail was supposed to stop wagging on its own after 0.1 seconds but it did not!")

	// TESTING TAIL REMOVAL

	// remove the tail
	dummy_tail.Remove(dummy, special = TRUE)

	// check if tail is still wagging after being removed
	if(dummy_tail.wag_flags & WAG_WAGGING)
		TEST_FAIL("Tail was still wagging after being removed!")

	// try to wag the removed tail
	dummy.wag_tail()
	if(dummy_tail.wag_flags & WAG_WAGGING)
		TEST_FAIL("A disembodied tail was able to start wagging!")

	// TESTING MOB DEATH

	// put it back and start wagging again
	dummy_tail.Insert(dummy, special = TRUE, movement_flags = DELETE_IF_REPLACED)
	dummy.wag_tail()
	if(!(dummy_tail.wag_flags & WAG_WAGGING))
		TEST_FAIL("Tail did not start wagging when it should have!")

	// kill the mob, see if it stops wagging
	dummy.adjust_brute_loss(9001)
	if(dummy_tail.wag_flags & WAG_WAGGING)
		TEST_FAIL("A mob's tail was still wagging after being killed!")

	// check if we are still able to wag the tail after death
	dummy.wag_tail()
	if(dummy_tail.wag_flags & WAG_WAGGING)
		TEST_FAIL("A dead mob was able to wag their tail!")

/// A tail can be restyled while its owner's back spines and wag animation stay active.
/datum/unit_test/tail_restyle_spines/Run()
	var/mob/living/carbon/human/lizard = allocate(/mob/living/carbon/human/consistent)
	lizard.dna.features[FEATURE_SPINES] = /datum/sprite_accessory/spines/short::name
	lizard.dna.features[FEATURE_TAIL_LIZARD] = /datum/sprite_accessory/tails/lizard/mechanical::name
	lizard.set_species(/datum/species/lizard)
	var/obj/item/organ/tail/tail = lizard.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL)
	TEST_ASSERT_NOTNULL(tail, "Lizard did not receive a tail.")
	lizard.wag_tail()

	tail.simple_change_sprite(/datum/sprite_accessory/tails/lizard/smooth)
	var/list/organic_states = get_limb_states(tail.bodypart_owner)
	TEST_ASSERT("m_tailspines_lizard_wagging_short_ADJ" in organic_states, "Restoring an organic tail while wagging should restore its moving spines.")

	tail.simple_change_sprite(/datum/sprite_accessory/tails/lizard/mechanical)
	var/list/mechanical_states = get_limb_states(tail.bodypart_owner)
	TEST_ASSERT("m_spines_short_ADJ" in mechanical_states, "The back spines should stay visible.")
	TEST_ASSERT("m_tail_lizard_wagging_mechanical_BEHIND" in mechanical_states, "The mechanical tail should keep wagging.")
	TEST_ASSERT(!("m_tailspines_lizard_wagging_short_ADJ" in mechanical_states), "The previous tail's spines should disappear.")

/datum/unit_test/tail_restyle_spines/proc/get_limb_states(obj/item/bodypart/limb)
	var/list/states = list()
	for(var/image/layer as anything in limb.get_limb_icon())
		states |= layer.icon_state
	return states
