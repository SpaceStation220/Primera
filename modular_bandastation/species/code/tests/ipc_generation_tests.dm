/// Preferences configure a new core; transplantation and ID/job changes cannot rewrite it.
/datum/unit_test/ipc_generation_identity/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	var/datum/preference/choiced/ipc/generation/preference = GLOB.preference_entries[/datum/preference/choiced/ipc/generation]
	preference.apply_to_human(ipc, "I", null)
	var/obj/item/organ/brain/ipc/core = ipc.get_organ_slot(ORGAN_SLOT_BRAIN)
	var/datum/ipc_os/os = core.operating_system
	TEST_ASSERT_EQUAL(os.generation(), "I", "Character generation preference did not configure the personality core.")
	var/datum/job/doctor/job = SSjob.get_job_type(/datum/job/doctor)
	os.on_job_spawn(SSdcs, job, ipc)
	TEST_ASSERT_EQUAL(core.ipc_department, "medical", "Real medical roundstart job did not assign its department.")
	os.on_job_spawn(SSdcs, SSjob.get_job_type(/datum/job/station_engineer), ipc)
	TEST_ASSERT_EQUAL(core.ipc_department, "medical", "A second job signal rewrote the original specialization.")
	preference.apply_to_human(ipc, "II", null)
	TEST_ASSERT_EQUAL(os.generation(), "I", "Reapplying cosmetic preferences rewrote a round participant's generation.")
	core.Remove(ipc, special = TRUE)
	TEST_ASSERT_NULL(os.host, "Extracted generation core retained its old host.")
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
	recipient.set_species(/datum/species/ipc)
	TEST_ASSERT(core.Insert(recipient, movement_flags = DELETE_IF_REPLACED), "Core transplantation failed.")
	TEST_ASSERT_EQUAL(recipient.get_ipc_os().generation(), "I", "Transplant changed generation.")
	TEST_ASSERT_EQUAL(core.ipc_department, "medical", "Transplant changed saved specialization.")
	var/obj/item/organ/brain/organic = allocate(/obj/item/organ/brain)
	TEST_ASSERT(organic.Insert(recipient, movement_flags = DELETE_IF_REPLACED), "Organic control transplant failed.")
	TEST_ASSERT_EQUAL(recipient.get_ipc_os().generation(), "II", "An ordinary brain inherited generation I from the chassis.")

/// Stale character saves and forged choices cannot cross manufacturer boundaries.
/datum/unit_test/ipc_manufacturer_preferences/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences, mock_client)
	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/ipc
	preferences.value_cache[/datum/preference/choiced/ipc/manufacturer] = /datum/ipc_manufacturer/bishop::name
	var/datum/preference/choiced/ipc/head/head = GLOB.preference_entries[/datum/preference/choiced/ipc/head]
	TEST_ASSERT(!head.is_valid(/datum/ipc_chassis/xion::name, preferences), "Bishop accepted a forged Xion head.")
	TEST_ASSERT_EQUAL(head.deserialize(/datum/ipc_chassis/xion::name, preferences), /datum/ipc_chassis/bishop::name, "An incompatible saved head was not migrated to the selected brand.")
	preferences.value_cache[/datum/preference/choiced/ipc/manufacturer] = /datum/ipc_manufacturer/con::name
	TEST_ASSERT(head.is_valid(/datum/ipc_chassis/xion::name, preferences), "CON could not combine manufacturers.")
	var/datum/preference/choiced/ipc/manufacturer/manufacturer = GLOB.preference_entries[/datum/preference/choiced/ipc/manufacturer]
	TEST_ASSERT_EQUAL(manufacturer.deserialize("HEF", preferences), "CON", "Legacy HEF did not migrate to CON.")
	var/datum/preference/choiced/ipc/generation/generation = GLOB.preference_entries[/datum/preference/choiced/ipc/generation]
	TEST_ASSERT(generation.is_valid("III", preferences), "Humanity was missing from character creation.")

/// Mechanical identity comes from the torso, never the selected cosmetic sprite or brain.
/datum/unit_test/ipc_manufacturer_torso/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	var/datum/ipc_os/os = ipc.get_ipc_os()
	var/datum/preference/choiced/ipc/manufacturer/preference = GLOB.preference_entries[/datum/preference/choiced/ipc/manufacturer]
	preference.apply_to_human(ipc, /datum/ipc_manufacturer/bishop::name, null)
	TEST_ASSERT_EQUAL(os.capacity(), 27, "Bishop torso did not add three GB.")
	os.unlock(TRUE)
	TEST_ASSERT_EQUAL(os.capacity(), 35, "Bishop and EMAG did not combine.")
	var/obj/item/bodypart/chest/robot/ipc/neutral = allocate(/obj/item/bodypart/chest/robot/ipc)
	TEST_ASSERT(neutral.replace_limb(ipc), "Replacing the branded torso failed.")
	TEST_ASSERT_EQUAL(os.capacity(), 32, "A neutral replacement retained the old torso memory bonus.")
	ipc.dna.features[FEATURE_IPC_CHASSIS] = /datum/ipc_chassis/bishop::name
	ipc.update_body(is_creating = TRUE)
	TEST_ASSERT_EQUAL(os.capacity(), 32, "Cosmetic Bishop appearance granted a neutral torso branded memory.")
	preference.apply_to_human(ipc, /datum/ipc_manufacturer/yang::name, null)
	TEST_ASSERT_EQUAL(os.capacity(), 29, "Yang did not receive the Unbranded memory penalty.")
	preference.apply_to_human(ipc, /datum/ipc_manufacturer/ward::name, null)
	var/obj/item/organ/heart/ipc/battery = ipc.get_organ_slot(ORGAN_SLOT_HEART)
	battery.adjust_charge(10000)
	TEST_ASSERT_EQUAL(ipc.nutrition, 660, "Ward did not increase absolute battery capacity to 120 base units.")
	TEST_ASSERT_EQUAL(ipc.ipc_apc_charge_limit(), 540, "Ward changed the relative APC ceiling.")
	preference.apply_to_human(ipc, /datum/ipc_manufacturer/con::name, null)
	TEST_ASSERT_EQUAL(ipc.nutrition, 550, "Losing Ward failed to clamp stored energy.")
	TEST_ASSERT_EQUAL(os.capacity(), 32, "CON granted a branded memory effect.")
