#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/datum/unit_test/proc/lazarus_test_power(action_type, mob/living/treacherous_flesh/parasite)
	var/datum/action/treacherous_flesh/power = locate(action_type) in parasite.actions
	if(!power)
		power = allocate(action_type, parasite)
		power.Grant(parasite)
	return power

/datum/unit_test/proc/lazarus_test_wait(datum/action/treacherous_flesh/power, mob/living/carbon/human/host, list/result)
	result["success"] = power.wait_for_host(2, host)
	result["done"] = TRUE

/// A healthy host has a null diseases list; neither use may leave the button busy.
/datum/unit_test/lazarus_flesh_panacea/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/treacherous_flesh/parasite = allocate(/mob/living/treacherous_flesh)
	TEST_ASSERT(parasite.infest(host), "Panacea fixture could not infest its host.")
	var/datum/action/treacherous_flesh/panacea/power = lazarus_test_power(/datum/action/treacherous_flesh/panacea, parasite)
	TEST_ASSERT_NULL(host.diseases, "The healthy-host regression must begin with a null diseases list.")
	parasite.chemicals = 100
	TEST_ASSERT(power.Trigger(parasite), "Panacea failed on a healthy host.")
	TEST_ASSERT(!power.busy, "Panacea left its button busy after healing a healthy host.")
	TEST_ASSERT_EQUAL(parasite.chemicals, 50, "Panacea did not charge exactly 50 chemicals.")
	TEST_ASSERT(power.Trigger(parasite), "Panacea remained unusable after its first activation.")
	TEST_ASSERT_EQUAL(parasite.chemicals, 0, "The second successful panacea had the wrong cost.")
	TEST_ASSERT(!power.busy, "Repeated panacea left its button busy.")
	host.reagents.clear_reagents()
	parasite.chemicals = 49
	TEST_ASSERT(!power.Trigger(parasite), "Panacea accepted insufficient chemicals.")
	TEST_ASSERT_EQUAL(parasite.chemicals, 49, "Rejected panacea consumed chemicals.")
	TEST_ASSERT_EQUAL(host.reagents.total_volume, 0, "Rejected panacea injected medicine.")
	var/datum/disease/cold/beneficial = allocate(/datum/disease/cold)
	beneficial.severity = DISEASE_SEVERITY_POSITIVE
	var/datum/disease/flu/harmful = allocate(/datum/disease/flu)
	TEST_ASSERT(host.ForceContractDisease(beneficial, make_copy = FALSE), "Could not install the beneficial disease fixture.")
	TEST_ASSERT(host.ForceContractDisease(harmful, make_copy = FALSE), "Could not infect the panacea host.")
	var/obj/item/organ/body_egg/egg = allocate(/obj/item/organ/body_egg, host)
	parasite.chemicals = 50
	TEST_ASSERT(power.Trigger(parasite), "Panacea failed on a diseased host.")
	TEST_ASSERT(QDELETED(harmful), "Panacea did not cure the harmful infection.")
	TEST_ASSERT(beneficial in host.diseases, "Panacea removed a positive disease.")
	TEST_ASSERT_NULL(host.get_organ_by_type(/obj/item/organ/body_egg), "Panacea retained a parasitic organ.")
	TEST_ASSERT_EQUAL(egg.loc, get_turf(host), "Panacea did not expel the removed egg.")
	TEST_ASSERT(host.reagents.has_reagent(/datum/reagent/medicine/mutadone, 1), "Panacea omitted its mutation treatment.")
	TEST_ASSERT(host.reagents.has_reagent(/datum/reagent/medicine/pen_acid, 20), "Panacea omitted its toxin treatment.")
	TEST_ASSERT(host.reagents.has_reagent(/datum/reagent/medicine/mannitol, 25), "Panacea omitted its brain treatment.")
	TEST_ASSERT(!power.busy, "Disease treatment left panacea busy.")

/datum/unit_test/lazarus_flesh_recovery/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/treacherous_flesh/parasite = allocate(/mob/living/treacherous_flesh)
	TEST_ASSERT(parasite.infest(host), "Recovery fixture could not infest its host.")
	var/datum/action/treacherous_flesh/fleshmend/heal = lazarus_test_power(/datum/action/treacherous_flesh/fleshmend, parasite)
	host.adjust_brute_loss(30)
	parasite.chemicals = 29
	TEST_ASSERT(!heal.Trigger(parasite), "Fleshmend accepted insufficient chemicals.")
	TEST_ASSERT_NULL(host.has_status_effect(/datum/status_effect/fleshmend), "Rejected fleshmend created a healing effect.")
	parasite.chemicals = 100
	TEST_ASSERT(heal.Trigger(parasite), "Fleshmend failed to activate.")
	var/datum/status_effect/fleshmend/healing = host.has_status_effect(/datum/status_effect/fleshmend)
	TEST_ASSERT_NOTNULL(healing, "Fleshmend did not install its native healing effect.")
	healing.tick(1)
	TEST_ASSERT(host.get_brute_loss() < 30, "A real fleshmend tick did not heal damage.")
	var/healed_damage = host.get_brute_loss()
	host.on_fire = TRUE
	healing.tick(1)
	TEST_ASSERT_EQUAL(host.get_brute_loss(), healed_damage, "Fleshmend healed while its host was on fire.")
	host.on_fire = FALSE
	TEST_ASSERT(!heal.Trigger(parasite), "Fleshmend accepted an ineffective recast of its unique native effect.")
	TEST_ASSERT_EQUAL(parasite.chemicals, 70, "Rejected fleshmend recast consumed another 30 chemicals.")
	TEST_ASSERT(!heal.busy, "Rejected fleshmend recast left the button busy.")
	var/datum/action/treacherous_flesh/adrenaline/stimulant = lazarus_test_power(/datum/action/treacherous_flesh/adrenaline, parasite)
	host.SetSleeping(10 SECONDS)
	host.Stun(10 SECONDS)
	host.set_stamina_loss(50)
	parasite.chemicals = 50
	TEST_ASSERT(stimulant.Trigger(parasite), "Adrenaline failed on a sleeping, stunned host.")
	TEST_ASSERT(!host.IsSleeping() && !host.IsStun(), "Adrenaline did not clear sleep and stun.")
	TEST_ASSERT_EQUAL(host.get_stamina_loss(), 0, "Adrenaline did not restore stamina.")
	TEST_ASSERT(host.reagents.has_reagent(/datum/reagent/medicine/synaptizine, 15), "Adrenaline omitted synaptizine.")
	TEST_ASSERT(host.reagents.has_reagent(/datum/reagent/medicine/changelingadrenaline, 1), "Adrenaline omitted its native stimulant.")
	TEST_ASSERT_EQUAL(parasite.chemicals, 0, "Adrenaline had the wrong cost.")
	TEST_ASSERT(!stimulant.Trigger(parasite), "Adrenaline activated without chemicals.")

/datum/unit_test/lazarus_flesh_regrowth_heat/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/treacherous_flesh/parasite = allocate(/mob/living/treacherous_flesh)
	TEST_ASSERT(parasite.infest(host), "Regrowth fixture could not infest its host.")
	var/datum/action/treacherous_flesh/regrow_organs/regrowth = lazarus_test_power(/datum/action/treacherous_flesh/regrow_organs, parasite)
	var/obj/item/bodypart/arm = host.get_bodypart(BODY_ZONE_R_ARM)
	arm.drop_limb(special = TRUE)
	allocated += arm
	var/obj/item/organ/appendix = host.get_organ_slot(ORGAN_SLOT_APPENDIX)
	appendix.Remove(host)
	allocated += appendix
	var/obj/item/organ/liver = host.get_organ_slot(ORGAN_SLOT_LIVER)
	liver.set_organ_damage(20)
	parasite.chemicals = 99
	TEST_ASSERT(!regrowth.Trigger(parasite), "Regrowth accepted insufficient chemicals.")
	TEST_ASSERT_NULL(host.get_bodypart(BODY_ZONE_R_ARM), "Rejected regrowth restored the lost arm.")
	parasite.chemicals = 100
	TEST_ASSERT(regrowth.Trigger(parasite), "Regrowth failed with sufficient chemicals.")
	TEST_ASSERT_NOTNULL(host.get_bodypart(BODY_ZONE_R_ARM), "Regrowth did not recreate the arm.")
	TEST_ASSERT_NOTNULL(host.get_organ_slot(ORGAN_SLOT_APPENDIX), "Regrowth did not replace the missing organ.")
	TEST_ASSERT_EQUAL(liver.damage, 0, "Regrowth did not repair an existing damaged organ.")
	TEST_ASSERT_EQUAL(parasite.chemicals, 0, "Regrowth did not charge 100 chemicals.")
	var/datum/action/treacherous_flesh/heat_up/heater = lazarus_test_power(/datum/action/treacherous_flesh/heat_up, parasite)
	host.frostbite = 0
	parasite.chemicals = 19
	TEST_ASSERT(!heater.Trigger(parasite), "Heating accepted insufficient chemicals.")
	TEST_ASSERT_EQUAL(host.frostbite, 0, "Rejected heating changed the host's heat reserve.")
	parasite.chemicals = 40
	TEST_ASSERT(heater.Trigger(parasite), "Heating failed to activate.")
	TEST_ASSERT_EQUAL(host.frostbite, 1500, "Heating added the wrong amount of warmth.")
	host.frostbite = FROSTBITE_WARM - 100
	TEST_ASSERT(heater.Trigger(parasite), "Repeated heating failed.")
	TEST_ASSERT_EQUAL(host.frostbite, FROSTBITE_WARM, "Heating exceeded the maximum heat reserve.")
	TEST_ASSERT_EQUAL(parasite.chemicals, 0, "Two heating activations had the wrong cost.")

/datum/unit_test/lazarus_flesh_equipment/proc/block_helmet(datum/source, obj/item/item, slot)
	SIGNAL_HANDLER
	if(slot == ITEM_SLOT_HEAD)
		return COMPONENT_BLOCK_EQUIP

/datum/unit_test/lazarus_flesh_equipment/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/treacherous_flesh/parasite = allocate(/mob/living/treacherous_flesh)
	TEST_ASSERT(parasite.infest(host), "Equipment fixture could not infest its host.")
	var/datum/action/treacherous_flesh/armblade/weapon = lazarus_test_power(/datum/action/treacherous_flesh/armblade, parasite)
	var/obj/item/analyzer/held = allocate(/obj/item/analyzer)
	TEST_ASSERT(host.put_in_active_hand(held), "Equipment fixture could not hold its ordinary item.")
	parasite.chemicals = 24
	TEST_ASSERT(!weapon.Trigger(parasite), "Armblade accepted insufficient chemicals.")
	TEST_ASSERT(host.is_holding(held), "Rejected armblade dropped the host's item.")
	parasite.chemicals = 25
	ADD_TRAIT(held, TRAIT_NODROP, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!weapon.Trigger(parasite), "Armblade displaced an undroppable held item.")
	TEST_ASSERT_EQUAL(parasite.chemicals, 25, "An obstructed armblade consumed chemicals.")
	REMOVE_TRAIT(held, TRAIT_NODROP, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(weapon.Trigger(parasite), "Armblade failed with a usable hand.")
	TEST_ASSERT(host.is_holding(weapon.blade), "Armblade did not equip its generated weapon.")
	TEST_ASSERT(weapon.Trigger(parasite), "Armblade could not retract without chemicals.")
	TEST_ASSERT_NULL(weapon.blade, "Retracting armblade retained its weapon.")
	TEST_ASSERT(!QDELETED(held), "Retracting armblade deleted an unrelated item.")
	for(var/zone in list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM))
		var/obj/item/bodypart/arm = host.get_bodypart(zone)
		arm.drop_limb(special = TRUE)
		allocated += arm
	parasite.chemicals = 25
	TEST_ASSERT(!weapon.Trigger(parasite), "An armless host reported a successful armblade.")
	TEST_ASSERT_EQUAL(parasite.chemicals, 25, "A failed armblade placement consumed chemicals.")
	TEST_ASSERT_NULL(weapon.blade, "A failed armblade placement retained a generated weapon.")
	host.regenerate_limbs()
	var/datum/action/treacherous_flesh/chitin_armor/shell = lazarus_test_power(/datum/action/treacherous_flesh/chitin_armor, parasite)
	var/obj/item/clothing/suit/armor/ordinary_suit = allocate(/obj/item/clothing/suit/armor/vest)
	var/obj/item/clothing/head/helmet/ordinary_helmet = allocate(/obj/item/clothing/head/helmet)
	TEST_ASSERT(host.equip_to_slot_if_possible(ordinary_suit, ITEM_SLOT_OCLOTHING), "Could not equip the ordinary suit.")
	TEST_ASSERT(host.equip_to_slot_if_possible(ordinary_helmet, ITEM_SLOT_HEAD), "Could not equip the ordinary helmet.")
	parasite.chemicals = 39
	TEST_ASSERT(!shell.Trigger(parasite), "Chitin accepted insufficient chemicals.")
	TEST_ASSERT(host.wear_suit == ordinary_suit && host.head == ordinary_helmet, "Rejected chitin stripped the host's equipment.")
	parasite.chemicals = 40
	ADD_TRAIT(ordinary_helmet, TRAIT_NODROP, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!shell.Trigger(parasite), "Chitin displaced an undroppable helmet.")
	TEST_ASSERT(host.wear_suit == ordinary_suit && host.head == ordinary_helmet, "An obstructed helmet made chitin strip the ordinary suit.")
	REMOVE_TRAIT(ordinary_helmet, TRAIT_NODROP, TRAIT_SOURCE_UNIT_TESTS)
	RegisterSignal(host, COMSIG_HUMAN_EQUIPPING_ITEM, PROC_REF(block_helmet))
	TEST_ASSERT(!shell.Trigger(parasite), "Chitin reported success when helmet equipment was blocked.")
	UnregisterSignal(host, COMSIG_HUMAN_EQUIPPING_ITEM)
	TEST_ASSERT_EQUAL(parasite.chemicals, 40, "Failed chitin equipment consumed chemicals.")
	TEST_ASSERT_NULL(shell.armor, "Failed chitin equipment retained its suit.")
	TEST_ASSERT_NULL(shell.helmet, "Failed chitin equipment retained its helmet.")
	TEST_ASSERT(shell.Trigger(parasite), "Chitin failed after its equipment obstruction was removed.")
	TEST_ASSERT(host.wear_suit == shell.armor && host.head == shell.helmet, "Chitin did not equip both pieces.")
	TEST_ASSERT(shell.Trigger(parasite), "Chitin could not retract without chemicals.")
	TEST_ASSERT(!QDELETED(ordinary_suit) && !QDELETED(ordinary_helmet), "Retracting chitin deleted unrelated clothing.")

/// All powers must reject stale hosts and forced reentry before reaching their effects.
/datum/unit_test/lazarus_flesh_action_guards/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/treacherous_flesh/parasite = allocate(/mob/living/treacherous_flesh)
	TEST_ASSERT(parasite.infest(host), "Action-guard fixture could not infest its host.")
	for(var/stage in 0 to LAZARUS_FLESH_FINAL_STAGE)
		parasite.evolution_stage = stage
		parasite.grant_skills()
	parasite.chemicals = 200
	for(var/datum/action/treacherous_flesh/power in parasite.actions)
		power.busy = TRUE
		TEST_ASSERT(!power.Trigger(parasite, TRIGGER_FORCE_AVAILABLE), "[power.type] bypassed its busy guard.")
		power.busy = FALSE
	var/datum/action/treacherous_flesh/passive_infest/infection = lazarus_test_power(/datum/action/treacherous_flesh/passive_infest, parasite)
	parasite.chemicals = 2
	TEST_ASSERT(!infection.Trigger(parasite), "Passive infection enabled without its minimum reserve.")
	parasite.chemicals = 3
	TEST_ASSERT(infection.Trigger(parasite) && parasite.infecting, "Passive infection did not enable.")
	TEST_ASSERT(infection.Trigger(parasite) && !parasite.infecting, "Passive infection did not disable.")
	var/datum/action/treacherous_flesh/emit_pheromones/pheromones = lazarus_test_power(/datum/action/treacherous_flesh/emit_pheromones, parasite)
	host.add_faction("treacherous_flesh")
	TEST_ASSERT(pheromones.Trigger(parasite) && pheromones.Trigger(parasite), "Pheromones could not toggle twice.")
	TEST_ASSERT(host.has_faction("treacherous_flesh"), "Pheromones removed a preexisting faction.")
	parasite.chemicals = 200
	var/list/wait_result = list()
	INVOKE_ASYNC(src, PROC_REF(lazarus_test_wait), infection, host, wait_result)
	TEST_ASSERT(!wait_result["done"], "The delayed-host guard did not yield before interruption.")
	parasite.disinfest(delete = FALSE)
	var/deadline = world.time + 5 SECONDS
	UNTIL(wait_result["done"] || world.time >= deadline)
	TEST_ASSERT(wait_result["done"] && !wait_result["success"], "A real delayed action accepted a host removed during its wait.")
	for(var/datum/action/treacherous_flesh/power in parasite.actions)
		TEST_ASSERT(!power.Trigger(parasite, TRIGGER_FORCE_AVAILABLE), "[power.type] activated after losing its host.")
	TEST_ASSERT_EQUAL(parasite.chemicals, 200, "Rejected actions spent chemicals after losing their host.")

/datum/action/treacherous_flesh/contact_host/lazarus_test
	var/approved = FALSE

/datum/action/treacherous_flesh/contact_host/lazarus_test/confirm_activation(message)
	return approved

/datum/action/treacherous_flesh/enslave_mind/lazarus_test
	var/approved = FALSE

/datum/action/treacherous_flesh/enslave_mind/lazarus_test/confirm_activation(message)
	return approved

/datum/action/treacherous_flesh/enslave_mind/lazarus_test/wait_for_host(duration, mob/living/carbon/human/expected_host)
	return ..(2, expected_host)

/datum/unit_test/lazarus_flesh_contact_enslavement/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/treacherous_flesh/parasite = allocate(/mob/living/treacherous_flesh)
	TEST_ASSERT(parasite.infest(host), "Contact fixture could not infest its host.")
	host.mind_initialize()
	var/datum/action/treacherous_flesh/contact_host/lazarus_test/contact = lazarus_test_power(/datum/action/treacherous_flesh/contact_host/lazarus_test, parasite)
	TEST_ASSERT(!contact.Trigger(parasite) && !parasite.contacted, "Cancelled contact revealed the parasite.")
	contact.approved = TRUE
	TEST_ASSERT(contact.Trigger(parasite), "Confirmed contact failed.")
	TEST_ASSERT(parasite.contacted, "Confirmed contact did not reveal the parasite.")
	TEST_ASSERT_NOTNULL(locate(/datum/action/communicate_parasite) in host.actions, "Contact did not grant the host's reply action.")
	TEST_ASSERT_NULL(locate(/datum/action/treacherous_flesh/message_host) in parasite.actions, "Contact retained the anonymous message action.")
	TEST_ASSERT(!contact.Trigger(parasite), "Repeated contact duplicated the reply actions.")
	var/datum/action/treacherous_flesh/communicate_host/talk = locate() in parasite.actions
	TEST_ASSERT(!talk.Trigger(parasite), "A cancelled empty message reported success.")
	var/datum/action/treacherous_flesh/enslave_mind/lazarus_test/enslave = lazarus_test_power(/datum/action/treacherous_flesh/enslave_mind/lazarus_test, parasite)
	parasite.chemicals = 200
	TEST_ASSERT(!enslave.Trigger(parasite), "Cancelled enslavement reported success.")
	enslave.approved = TRUE
	ADD_TRAIT(host, TRAIT_MINDSHIELD, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!enslave.Trigger(parasite), "Enslavement bypassed a mindshield.")
	REMOVE_TRAIT(host, TRAIT_MINDSHIELD, TRAIT_SOURCE_UNIT_TESTS)
	parasite.chemicals = 149
	TEST_ASSERT(!enslave.Trigger(parasite), "Enslavement accepted insufficient chemicals.")
	parasite.chemicals = 150
	TEST_ASSERT(enslave.Trigger(parasite), "Confirmed, funded enslavement failed.")
	TEST_ASSERT(parasite.host_enslaved && host.mind.has_antag_datum(/datum/antagonist/lazarus_host), "Enslavement did not assign its native antagonist role.")
	TEST_ASSERT(!enslave.Trigger(parasite), "Enslavement could be repeated on the same host.")
	TEST_ASSERT(!enslave.busy, "Enslavement left its button busy.")

/datum/action/treacherous_flesh/take_control/lazarus_test
	var/approved = FALSE

/datum/action/treacherous_flesh/take_control/lazarus_test/confirm_activation(message)
	return approved

/datum/action/treacherous_flesh/take_control/lazarus_test/wait_for_host(duration, mob/living/carbon/human/expected_host)
	return ..(2, expected_host)

/datum/action/treacherous_flesh/leave_the_body/lazarus_test
	var/approved = FALSE

/datum/action/treacherous_flesh/leave_the_body/lazarus_test/confirm_activation(message)
	return approved

/datum/action/treacherous_flesh/leave_the_body/lazarus_test/wait_for_host(duration, mob/living/carbon/human/expected_host)
	return ..(2, expected_host)

/datum/unit_test/lazarus_flesh_control_escape/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/treacherous_flesh/parasite = allocate(/mob/living/treacherous_flesh)
	TEST_ASSERT(parasite.infest(host), "Control fixture could not infest its host.")
	host.mind_initialize()
	parasite.mind_initialize()
	var/datum/mind/host_mind = host.mind
	var/datum/mind/parasite_mind = parasite.mind
	var/datum/action/treacherous_flesh/take_control/lazarus_test/control = lazarus_test_power(/datum/action/treacherous_flesh/take_control/lazarus_test, parasite)
	TEST_ASSERT(!control.Trigger(parasite), "Cancelled control reported success.")
	var/list/wait_result = list()
	INVOKE_ASYNC(src, PROC_REF(lazarus_test_wait), control, host, wait_result)
	TEST_ASSERT(!wait_result["done"], "The control guard did not yield before interruption.")
	TEST_ASSERT(parasite.take_control(), "The interruption fixture could not take control.")
	var/deadline = world.time + 5 SECONDS
	UNTIL(wait_result["done"] || world.time >= deadline)
	TEST_ASSERT(wait_result["done"] && !wait_result["success"], "A pending ability remained authorized after another action took control.")
	var/datum/action/treacherous_flesh/panacea/panacea = lazarus_test_power(/datum/action/treacherous_flesh/panacea, parasite)
	parasite.chemicals = 100
	TEST_ASSERT(!panacea.Trigger(parasite, TRIGGER_FORCE_AVAILABLE), "A forced ability bypassed the control restriction.")
	TEST_ASSERT_EQUAL(parasite.chemicals, 100, "A blocked ability spent chemicals during mind control.")
	parasite.restore_control()
	TEST_ASSERT(panacea.Trigger(parasite), "Restoring control did not reenable the parasite's abilities.")
	control.approved = TRUE
	TEST_ASSERT(control.Trigger(parasite), "Confirmed control failed.")
	TEST_ASSERT(host.mind == parasite_mind && parasite.trapped_mind.mind == host_mind, "Control activation did not preserve both minds.")
	TEST_ASSERT(!control.Trigger(parasite), "Repeated control displaced an already trapped mind.")
	var/datum/action/return_control/return_action = locate() in host.actions
	TEST_ASSERT(return_action.Trigger(host), "The real return-control action failed.")
	TEST_ASSERT(host.mind == host_mind && parasite.mind == parasite_mind, "Return-control did not restore both players.")
	var/datum/action/treacherous_flesh/leave_the_body/lazarus_test/escape = lazarus_test_power(/datum/action/treacherous_flesh/leave_the_body/lazarus_test, parasite)
	TEST_ASSERT(!escape.Trigger(parasite), "Cancelled escape reported success.")
	escape.approved = TRUE
	TEST_ASSERT(escape.Trigger(parasite), "Confirmed escape failed.")
	TEST_ASSERT(QDELETED(parasite), "Successful escape retained its parasite body.")
	TEST_ASSERT(istype(parasite_mind.current, /mob/living/basic/flesh_biomorph/lesser/small), "Escape did not move its player into the expected biomorph.")
	TEST_ASSERT_NULL(host.treacherous_flesh, "Escape retained the host's parasite reference.")

/datum/unit_test/lazarus_flesh_accelerated_evolution/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/treacherous_flesh/parasite = allocate(/mob/living/treacherous_flesh)
	TEST_ASSERT(parasite.infest(host), "Evolution fixture could not infest its host.")
	var/datum/action/treacherous_flesh/speed_up_evolution/evolution = lazarus_test_power(/datum/action/treacherous_flesh/speed_up_evolution, parasite)
	parasite.chemicals = 99
	TEST_ASSERT(!evolution.Trigger(parasite), "Accelerated evolution accepted insufficient chemicals.")
	TEST_ASSERT_EQUAL(parasite.evolution_points, 0, "Rejected evolution granted progress.")
	parasite.chemicals = 100
	var/started = world.time
	TEST_ASSERT(evolution.Trigger(parasite), "Funded accelerated evolution failed.")
	var/elapsed_seconds = (world.time - started) / 10
	TEST_ASSERT(parasite.evolution_points >= 60 && parasite.evolution_points <= 60 + elapsed_seconds / 2 + 2, "Accelerated evolution did not grant its 60-point bonus.")
	TEST_ASSERT(parasite.chemicals <= elapsed_seconds + 2, "Accelerated evolution did not pay 100 chemicals before natural regeneration.")
	TEST_ASSERT(!evolution.busy, "Accelerated evolution left its button busy.")

#endif
