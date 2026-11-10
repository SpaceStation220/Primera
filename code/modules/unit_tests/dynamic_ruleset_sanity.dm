/// Verifies that dynamic rulesets are setup properly without external configuration.
/datum/unit_test/dynamic_ruleset_sanity

/datum/unit_test/dynamic_ruleset_sanity/Run()
	for (var/datum/dynamic_ruleset/midround/ruleset as anything in subtypesof(/datum/dynamic_ruleset/midround))
		if(!initial(ruleset.config_tag))
			continue
		var/midround_ruleset_style = initial(ruleset.midround_type)
		if (midround_ruleset_style != HEAVY_MIDROUND && midround_ruleset_style != LIGHT_MIDROUND)
			TEST_FAIL("[ruleset] has an invalid midround_ruleset_style, it should be HEAVY_MIDROUND or LIGHT_MIDROUND")

/// Verifies that dynamic rulesets have unique antag_flag.
/datum/unit_test/dynamic_unique_antag_flags

/datum/unit_test/dynamic_unique_antag_flags/Run()
	var/list/known_antag_flags = list()

	for (var/datum/dynamic_ruleset/ruleset as anything in subtypesof(/datum/dynamic_ruleset))
		if(!initial(ruleset.config_tag))
			continue

		var/antag_flag = initial(ruleset.pref_flag)

		// null antag flag is valid for rulesets with no associated preferecne
		if (isnull(antag_flag))
			// however if you set preview_antag_datum, it is assumed you do have a preference, and thus should have a flag
			if (initial(ruleset.preview_antag_datum))
				TEST_FAIL("[ruleset] sets preview_antag_datum, but has no pref_flag! \
					If you want to use a preview antag datum, you must set a pref_flag.")
			continue

		if (antag_flag in known_antag_flags)
			if(!(initial(ruleset.ruleset_flags) & RULESET_VARIATION))
				TEST_FAIL("[ruleset] has a non-unique antag_flag [antag_flag] (used by [known_antag_flags[antag_flag]])!")
			continue

		known_antag_flags[antag_flag] = ruleset

/// Supplies the account-age method missing from the native client mock.
/datum/client_interface/traitor_subscription_candidate

/datum/client_interface/traitor_subscription_candidate/proc/get_remaining_days(days_needed)
	return 0

/datum/client_interface/traitor_subscription_candidate/Destroy()
	if(mob)
		mob.mock_client = null
		mob.key = null
	mob = null
	prefs = null
	return ..()

/// Shared native candidate setup and state restoration for subscription selection tests.
/datum/unit_test/traitor_subscription_selection
	abstract_type = /datum/unit_test/traitor_subscription_selection
	/// Config and shared state restored even when an assertion returns early.
	var/original_weighted_selection
	/// History-weight settings restored after zero-weight regression scenarios.
	var/original_base_weight
	/// Original penalty applied to each recent antagonist episode.
	var/original_weight_penalty
	/// Original lower bound for history weights.
	var/original_min_weight
	/// History window restored after fixing it for the isolated cache fixture.
	var/original_history_window
	var/list/original_prevented_occupations
	var/alist/original_antag_history
	/// Isolated history entries, avoiding a database dependency in weighted selection.
	var/alist/history_by_ckey

/datum/unit_test/traitor_subscription_selection/New()
	. = ..()
	original_weighted_selection = CONFIG_GET(flag/antag_weighted_selection)
	original_base_weight = CONFIG_GET(number/antag_base_weight)
	original_weight_penalty = CONFIG_GET(number/antag_weight_penalty)
	original_min_weight = CONFIG_GET(number/antag_min_weight)
	original_history_window = CONFIG_GET(number/antag_history_window_days)
	CONFIG_SET(number/antag_history_window_days, 14)
	original_prevented_occupations = SSjob.prevented_occupations
	SSjob.prevented_occupations = list()
	original_antag_history = GLOB.player_antag_episodes_cache
	GLOB.player_antag_episodes_cache = alist()
	var/days_back = CONFIG_GET(number/antag_history_window_days)
	history_by_ckey = alist()
	var/list/history_groups = list(
		CONFIG_GET(str_list/tracked_antagonists_roundstart),
		CONFIG_GET(str_list/tracked_antagonists_midround),
	)
	for(var/list/tracked_antagonists as anything in history_groups)
		var/cache_key = jointext(sort_list(tracked_antagonists), ",")
		GLOB.player_antag_episodes_cache[cache_key] = alist()
		GLOB.player_antag_episodes_cache[cache_key][days_back] = history_by_ckey

/datum/unit_test/traitor_subscription_selection/Destroy()
	CONFIG_SET(flag/antag_weighted_selection, original_weighted_selection)
	CONFIG_SET(number/antag_base_weight, original_base_weight)
	CONFIG_SET(number/antag_weight_penalty, original_weight_penalty)
	CONFIG_SET(number/antag_min_weight, original_min_weight)
	CONFIG_SET(number/antag_history_window_days, original_history_window)
	SSjob.prevented_occupations = original_prevented_occupations
	GLOB.player_antag_episodes_cache = original_antag_history
	original_prevented_occupations = null
	original_antag_history = null
	history_by_ckey = null
	return ..()

/// Creates an opted-in candidate with server-supplied subscription data and native preferences.
/datum/unit_test/traitor_subscription_selection/proc/create_candidate(donation_tier, candidate_type = /mob/dead/new_player, role_flag = ROLE_TRAITOR)
	var/datum/client_interface/traitor_subscription_candidate/mock_client = allocate(/datum/client_interface/traitor_subscription_candidate)
	mock_client.donator_level = donation_tier
	mock_client.ban_cache = list()
	history_by_ckey[mock_client.ckey] = 0
	var/datum/preferences/preferences = allocate(/datum/preferences, mock_client)
	mock_client.prefs = preferences
	preferences.be_special = list(role_flag)
	TEST_ASSERT(preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/antag_roll], TRUE), "Failed to enable antagonist selection for a subscription candidate.")
	var/mob/candidate = allocate(candidate_type)
	candidate.key = mock_client.key
	candidate.mock_client = mock_client
	mock_client.mob = candidate
	candidate.mind = allocate(/datum/mind, mock_client.key)
	if(isliving(candidate))
		candidate.mind.set_assigned_role(SSjob.get_job_type(/datum/job/cargo_technician))
	return candidate

/// Subscription priority must respect the slot cap, fall back to ordinary players, and keep native eligibility checks.
/datum/unit_test/roundstart_traitor_subscription_priority
	parent_type = /datum/unit_test/traitor_subscription_selection

/datum/unit_test/roundstart_traitor_subscription_priority/Run()
	for(var/use_weights in list(FALSE, TRUE))
		CONFIG_SET(flag/antag_weighted_selection, use_weights)
		var/mob/dead/new_player/ordinary = create_candidate(BASIC_DONATOR_LEVEL)
		var/mob/dead/new_player/tier_one = create_candidate(DONATOR_TIER_1)
		var/mob/dead/new_player/tier_two = create_candidate(DONATOR_TIER_2)
		var/mob/dead/new_player/tier_three = create_candidate(DONATOR_TIER_3)
		var/mob/dead/new_player/tier_four = create_candidate(DONATOR_TIER_4)
		var/mob/dead/new_player/tier_five = create_candidate(DONATOR_TIER_5)
		var/mob/dead/new_player/other_tier_five = create_candidate(DONATOR_TIER_5)
		var/mob/dead/new_player/opted_out = create_candidate(DONATOR_TIER_5)
		opted_out.mock_client.prefs.be_special = list()
		var/mob/dead/new_player/banned = create_candidate(DONATOR_TIER_5)
		banned.mock_client.ban_cache = list(ROLE_TRAITOR)
		var/list/mob/candidates = list(ordinary, tier_one, tier_two, tier_three, tier_four, tier_five, other_tier_five, opted_out, banned)
		var/datum/dynamic_ruleset/roundstart/traitor/ruleset = allocate(/datum/dynamic_ruleset/roundstart/traitor)
		// The native population cap provides five slots; only four eligible subscribers have priority.
		TEST_ASSERT(ruleset.prepare_execution(120, candidates), "Traitor selection failed with eligible candidates (weights=[use_weights]).")
		TEST_ASSERT_EQUAL(length(ruleset.selected_minds), 5, "Subscription priority changed the native slot cap.")
		TEST_ASSERT((ruleset.selected_minds[1] in list(tier_five.mind, other_tier_five.mind)) && (ruleset.selected_minds[2] in list(tier_five.mind, other_tier_five.mind)), "Tier 5 did not fill the first slots.")
		TEST_ASSERT_EQUAL(ruleset.selected_minds[3], tier_four.mind, "Tier 4 did not precede tier 3.")
		TEST_ASSERT_EQUAL(ruleset.selected_minds[4], tier_three.mind, "Tier 3 did not precede ordinary candidates.")
		TEST_ASSERT(ruleset.selected_minds[5] in list(ordinary.mind, tier_one.mind, tier_two.mind), "The remaining slot did not fall back to the ordinary pool.")
		TEST_ASSERT_EQUAL(length(candidates), 4, "Selection did not remove exactly the selected candidates.")
		TEST_ASSERT((opted_out in candidates) && (banned in candidates), "Subscription priority bypassed opt-in or role bans.")

		var/datum/dynamic_ruleset/roundstart/traitor/one_slot = allocate(/datum/dynamic_ruleset/roundstart/traitor)
		TEST_ASSERT(one_slot.prepare_execution(24, list(ordinary, tier_three, tier_four, tier_five, other_tier_five)), "A one-slot traitor selection failed.")
		TEST_ASSERT_EQUAL(length(one_slot.selected_minds), 1, "More subscribers than slots exceeded the cap.")
		TEST_ASSERT(one_slot.selected_minds[1] in list(tier_five.mind, other_tier_five.mind), "A lower tier displaced an eligible tier 5 when slots were limited.")

/// Native living crew candidates share the same eligibility and subscription fixtures as lobby players.
/datum/unit_test/midround_traitor_subscription_priority
	parent_type = /datum/unit_test/traitor_subscription_selection
	abstract_type = /datum/unit_test/midround_traitor_subscription_priority

/// Creates a living crew member opted into the sleeper-agent preference, without granting an antagonist role.
/datum/unit_test/midround_traitor_subscription_priority/proc/create_living_candidate(donation_tier)
	return create_candidate(donation_tier, candidate_type = /mob/living/carbon/human/consistent, role_flag = ROLE_SLEEPER_AGENT)

/// Successive single-slot events must exhaust each higher tier before falling back to ordinary players.
/datum/unit_test/midround_traitor_subscription_priority/single/Run()
	for(var/use_weights in list(FALSE, TRUE))
		CONFIG_SET(flag/antag_weighted_selection, use_weights)
		var/list/mob/candidates = list(
			create_living_candidate(BASIC_DONATOR_LEVEL),
			create_living_candidate(DONATOR_TIER_3),
			create_living_candidate(DONATOR_TIER_4),
			create_living_candidate(DONATOR_TIER_5),
			create_living_candidate(DONATOR_TIER_5),
		)
		var/list/tier_by_mind = list()
		for(var/mob/candidate as anything in candidates)
			tier_by_mind[candidate.mind] = candidate.mock_client.donator_level

		for(var/expected_tier in list(DONATOR_TIER_5, DONATOR_TIER_5, DONATOR_TIER_4, DONATOR_TIER_3, BASIC_DONATOR_LEVEL))
			var/datum/dynamic_ruleset/midround/from_living/traitor/ruleset = allocate(/datum/dynamic_ruleset/midround/from_living/traitor)
			TEST_ASSERT(ruleset.prepare_execution(24, candidates), "Midround traitor selection failed (weights=[use_weights]).")
			TEST_ASSERT_EQUAL(length(ruleset.selected_minds), 1, "Midround subscription priority exceeded the native one-slot cap.")
			TEST_ASSERT_EQUAL(tier_by_mind[ruleset.selected_minds[1]], expected_tier, "Midround traitor selection skipped a higher subscription tier.")
		TEST_ASSERT_EQUAL(length(candidates), 0, "Successive midround selections duplicated or lost a candidate.")

/// Mass traitors must inherit priority and fill remaining native slots from ordinary candidates.
/datum/unit_test/midround_traitor_subscription_priority/mass/Run()
	for(var/use_weights in list(FALSE, TRUE))
		CONFIG_SET(flag/antag_weighted_selection, use_weights)
		var/mob/living/carbon/human/ordinary = create_living_candidate(BASIC_DONATOR_LEVEL)
		var/mob/living/carbon/human/tier_two = create_living_candidate(DONATOR_TIER_2)
		var/mob/living/carbon/human/tier_three = create_living_candidate(DONATOR_TIER_3)
		var/mob/living/carbon/human/tier_four = create_living_candidate(DONATOR_TIER_4)
		var/mob/living/carbon/human/tier_five = create_living_candidate(DONATOR_TIER_5)
		var/list/mob/candidates = list(ordinary, tier_two, tier_three, tier_four, tier_five)
		var/datum/dynamic_ruleset/midround/from_living/traitor/mass/ruleset = allocate(/datum/dynamic_ruleset/midround/from_living/traitor/mass)
		TEST_ASSERT(ruleset.prepare_execution(24, candidates), "Mass traitor selection failed (weights=[use_weights]).")
		TEST_ASSERT_EQUAL(length(ruleset.selected_minds), 4, "Mass traitor subscription priority changed the native slot cap.")
		TEST_ASSERT_EQUAL(ruleset.selected_minds[1], tier_five.mind, "Mass traitors did not select tier 5 first.")
		TEST_ASSERT_EQUAL(ruleset.selected_minds[2], tier_four.mind, "Mass traitors did not select tier 4 next.")
		TEST_ASSERT_EQUAL(ruleset.selected_minds[3], tier_three.mind, "Mass traitors did not select tier 3 before the ordinary pool.")
		TEST_ASSERT(ruleset.selected_minds[4] in list(ordinary.mind, tier_two.mind), "Mass traitors did not fill the last slot from the ordinary pool.")
		TEST_ASSERT_EQUAL(length(candidates), 1, "Mass traitor selection did not remove exactly the four selected candidates.")

/// Even a tier-5 subscription cannot bypass midround opt-in, bans, crew, living-body, and existing-antagonist checks.
/datum/unit_test/midround_traitor_subscription_priority/eligibility/Run()
	for(var/use_weights in list(FALSE, TRUE))
		CONFIG_SET(flag/antag_weighted_selection, use_weights)
		var/mob/living/carbon/human/ordinary = create_living_candidate(BASIC_DONATOR_LEVEL)
		var/mob/living/carbon/human/wrong_preference = create_living_candidate(DONATOR_TIER_5)
		wrong_preference.mock_client.prefs.be_special = list(ROLE_TRAITOR)
		var/mob/living/carbon/human/opted_out = create_living_candidate(DONATOR_TIER_5)
		TEST_ASSERT(opted_out.mock_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/antag_roll], FALSE), "Failed to disable antagonist selection for the opted-out subscriber.")
		TEST_ASSERT(!opted_out.mock_client.prefs.read_preference(/datum/preference/toggle/antag_roll), "The opted-out subscriber still has antagonist selection enabled.")
		var/mob/living/carbon/human/banned = create_living_candidate(DONATOR_TIER_5)
		banned.mock_client.ban_cache = list(ROLE_TRAITOR)
		var/mob/living/carbon/human/dead = create_living_candidate(DONATOR_TIER_5)
		dead.death()
		var/mob/living/carbon/human/already_antag = create_living_candidate(DONATOR_TIER_5)
		already_antag.mind.antag_datums = list(allocate(/datum/antagonist))
		var/mob/living/carbon/human/prohibited_job = create_living_candidate(DONATOR_TIER_5)
		prohibited_job.mind.set_assigned_role(SSjob.get_job_type(/datum/job/head_of_personnel))
		var/mob/living/carbon/human/temporary_body = create_living_candidate(DONATOR_TIER_5)
		ADD_TRAIT(temporary_body, TRAIT_TEMPORARY_BODY, TRAIT_SOURCE_UNIT_TESTS)
		var/mob/living/carbon/human/disconnected = create_living_candidate(DONATOR_TIER_5)
		disconnected.mock_client = null
		var/list/mob/candidates = list(wrong_preference, opted_out, banned, dead, already_antag, prohibited_job, temporary_body, disconnected, ordinary)
		var/datum/dynamic_ruleset/midround/from_living/traitor/ruleset = allocate(/datum/dynamic_ruleset/midround/from_living/traitor)
		TEST_ASSERT(ruleset.prepare_execution(24, candidates), "An eligible ordinary player was excluded with invalid subscribers present.")
		TEST_ASSERT_EQUAL(length(ruleset.selected_minds), 1, "Eligibility filtering changed the native one-slot cap.")
		TEST_ASSERT_EQUAL(ruleset.selected_minds[1], ordinary.mind, "An ineligible tier-5 subscriber bypassed a native midround check.")

/// Native lobby and ghost candidates exercise the Changeling-specific tier threshold.
/datum/unit_test/changeling_subscription_priority
	parent_type = /datum/unit_test/traitor_subscription_selection
	abstract_type = /datum/unit_test/changeling_subscription_priority
	/// Restore the server's ghost-event policy after exercising native ghost rulesets.
	var/original_ghost_role_flags

/datum/unit_test/changeling_subscription_priority/New()
	. = ..()
	original_ghost_role_flags = GLOB.ghost_role_flags
	GLOB.ghost_role_flags |= GHOSTROLE_MIDROUND_EVENT

/datum/unit_test/changeling_subscription_priority/Destroy()
	GLOB.ghost_role_flags = original_ghost_role_flags
	return ..()

/// Runs native preparation and owns any fresh minds created for selected ghosts.
/datum/unit_test/changeling_subscription_priority/proc/prepare_candidates(datum/dynamic_ruleset/ruleset, population, list/mob/candidates)
	var/prepared = ruleset.prepare_execution(population, candidates)
	allocated |= ruleset.selected_minds
	return prepared

/// Tier 3 must stay in the same draw pool as tiers 0-2, without a flaky probability assertion.
/datum/unit_test/changeling_subscription_priority/ordinary_pool/Run()
	for(var/ruleset_type in list(/datum/dynamic_ruleset/roundstart/changeling, /datum/dynamic_ruleset/midround/from_ghosts/space_changeling))
		var/datum/dynamic_ruleset/ruleset = allocate(ruleset_type)
		var/list/mob/weighted_candidates = list()
		for(var/tier in list(BASIC_DONATOR_LEVEL, DONATOR_TIER_1, DONATOR_TIER_2, DONATOR_TIER_3))
			var/mob/candidate = create_candidate(tier, role_flag = ruleset.pref_flag)
			weighted_candidates[candidate] = 10 + tier
		// Inspect the protected draw boundary to prove neutrality without depending on which RNG result wins.
		var/list/mob/ordinary_pool = UNLINT(ruleset.get_priority_candidates(weighted_candidates))
		TEST_ASSERT_EQUAL(length(ordinary_pool), 4, "Changeling subscription priority excluded a tier-0-through-3 candidate from the common pool.")
		for(var/mob/candidate as anything in weighted_candidates)
			TEST_ASSERT_EQUAL(ordinary_pool[candidate], weighted_candidates[candidate], "Changeling subscription priority changed a lower tier's lottery weight.")

/// Roundstart Changelings must select tiers 5 and 4 before the ordinary pool and preserve native eligibility.
/datum/unit_test/changeling_subscription_priority/roundstart/Run()
	for(var/use_weights in list(FALSE, TRUE))
		CONFIG_SET(flag/antag_weighted_selection, use_weights)
		var/mob/ordinary = create_candidate(BASIC_DONATOR_LEVEL, role_flag = ROLE_CHANGELING)
		var/mob/tier_three = create_candidate(DONATOR_TIER_3, role_flag = ROLE_CHANGELING)
		var/mob/tier_four = create_candidate(DONATOR_TIER_4, role_flag = ROLE_CHANGELING)
		var/mob/tier_five = create_candidate(DONATOR_TIER_5, role_flag = ROLE_CHANGELING)
		var/mob/wrong_preference = create_candidate(DONATOR_TIER_5, role_flag = ROLE_TRAITOR)
		var/mob/banned = create_candidate(DONATOR_TIER_5, role_flag = ROLE_CHANGELING)
		banned.mock_client.ban_cache = list(ROLE_CHANGELING)
		var/list/mob/candidates = list(ordinary, tier_three, tier_four, tier_five, wrong_preference, banned)
		var/datum/dynamic_ruleset/roundstart/changeling/ruleset = allocate(/datum/dynamic_ruleset/roundstart/changeling)
		TEST_ASSERT(prepare_candidates(ruleset, 87, candidates), "Roundstart Changeling preparation failed (weights=[use_weights]).")
		TEST_ASSERT_EQUAL(length(ruleset.selected_minds), 3, "Changeling subscription priority changed the native population cap.")
		TEST_ASSERT_EQUAL(ruleset.selected_minds[1], tier_five.mind, "Roundstart Changelings did not select tier 5 first.")
		TEST_ASSERT_EQUAL(ruleset.selected_minds[2], tier_four.mind, "Roundstart Changelings did not select tier 4 next.")
		TEST_ASSERT(ruleset.selected_minds[3] in list(ordinary.mind, tier_three.mind), "Roundstart Changelings did not use the common pool for the remaining slot.")
		TEST_ASSERT((wrong_preference in candidates) && (banned in candidates), "A subscribed Changeling candidate bypassed opt-in or role bans.")

/// Single-slot ghost Changeling selections must exhaust tier 5, then tier 4, then use the common pool.
/datum/unit_test/changeling_subscription_priority/midround/Run()
	for(var/use_weights in list(FALSE, TRUE))
		CONFIG_SET(flag/antag_weighted_selection, use_weights)
		var/list/mob/candidates = list()
		var/list/tier_by_key = list()
		var/list/ordinary_keys = list()
		for(var/tier in list(BASIC_DONATOR_LEVEL, DONATOR_TIER_3, DONATOR_TIER_4, DONATOR_TIER_5, DONATOR_TIER_5))
			var/mob/candidate = create_candidate(tier, candidate_type = /mob/dead/observer, role_flag = ROLE_CHANGELING_MIDROUND)
			candidates += candidate
			tier_by_key[candidate.key] = tier
			if(tier < DONATOR_TIER_4)
				ordinary_keys += candidate.key
		var/mob/wrong_preference = create_candidate(DONATOR_TIER_5, candidate_type = /mob/dead/observer, role_flag = ROLE_CHANGELING)
		var/mob/banned = create_candidate(DONATOR_TIER_5, candidate_type = /mob/dead/observer, role_flag = ROLE_CHANGELING_MIDROUND)
		banned.mock_client.ban_cache = list(ROLE_CHANGELING)
		candidates += list(wrong_preference, banned)
		for(var/expected_tier in list(DONATOR_TIER_5, DONATOR_TIER_5, DONATOR_TIER_4))
			var/datum/dynamic_ruleset/midround/from_ghosts/space_changeling/ruleset = allocate(/datum/dynamic_ruleset/midround/from_ghosts/space_changeling)
			TEST_ASSERT(prepare_candidates(ruleset, 30, candidates), "Midround Changeling preparation failed (weights=[use_weights]).")
			TEST_ASSERT_EQUAL(length(ruleset.selected_minds), 1, "Midround Changeling subscription priority exceeded the native one-slot cap.")
			var/datum/mind/selected = ruleset.selected_minds[1]
			TEST_ASSERT_EQUAL(tier_by_key[selected.key], expected_tier, "Midround Changelings skipped a higher eligible subscription tier.")
		var/datum/dynamic_ruleset/midround/from_ghosts/space_changeling/fallback = allocate(/datum/dynamic_ruleset/midround/from_ghosts/space_changeling)
		TEST_ASSERT(prepare_candidates(fallback, 30, candidates), "Midround Changelings did not fall back to the ordinary pool.")
		var/datum/mind/ordinary_selection = fallback.selected_minds[1]
		TEST_ASSERT(ordinary_selection.key in ordinary_keys, "Midround Changelings selected an ineligible subscriber instead of an ordinary volunteer.")
		TEST_ASSERT((wrong_preference in candidates) && (banned in candidates), "A ghost subscriber bypassed the midround preference or Changeling ban.")

/// The mass ghost event must inherit the tier-4 threshold without changing its three-slot cap.
/datum/unit_test/changeling_subscription_priority/mass/Run()
	for(var/use_weights in list(FALSE, TRUE))
		CONFIG_SET(flag/antag_weighted_selection, use_weights)
		var/mob/tier_five = create_candidate(DONATOR_TIER_5, candidate_type = /mob/dead/observer, role_flag = ROLE_CHANGELING_MIDROUND)
		var/mob/tier_four = create_candidate(DONATOR_TIER_4, candidate_type = /mob/dead/observer, role_flag = ROLE_CHANGELING_MIDROUND)
		var/mob/tier_three = create_candidate(DONATOR_TIER_3, candidate_type = /mob/dead/observer, role_flag = ROLE_CHANGELING_MIDROUND)
		var/mob/ordinary = create_candidate(BASIC_DONATOR_LEVEL, candidate_type = /mob/dead/observer, role_flag = ROLE_CHANGELING_MIDROUND)
		var/list/mob/candidates = list(ordinary, tier_three, tier_four, tier_five)
		var/datum/dynamic_ruleset/midround/from_ghosts/space_changeling/mass/ruleset = allocate(/datum/dynamic_ruleset/midround/from_ghosts/space_changeling/mass)
		TEST_ASSERT(prepare_candidates(ruleset, 30, candidates), "Mass Changeling preparation failed (weights=[use_weights]).")
		TEST_ASSERT_EQUAL(length(ruleset.selected_minds), 3, "Mass Changelings changed their native slot cap.")
		var/list/selected_keys = list()
		for(var/datum/mind/selected as anything in ruleset.selected_minds)
			selected_keys += selected.key
		TEST_ASSERT_EQUAL(selected_keys[1], tier_five.key, "Mass Changelings did not select tier 5 first.")
		TEST_ASSERT_EQUAL(selected_keys[2], tier_four.key, "Mass Changelings did not select tier 4 next.")
		TEST_ASSERT(selected_keys[3] in list(ordinary.key, tier_three.key), "Mass Changelings did not fill the remaining slot from the common pool.")
		TEST_ASSERT_EQUAL(length(candidates), 1, "Mass Changeling preparation did not remove exactly the selected volunteers.")

/// Native Vampire candidates reuse the subscription fixture without weakening species compatibility.
/datum/unit_test/vampire_subscription_priority
	parent_type = /datum/unit_test/traitor_subscription_selection
	abstract_type = /datum/unit_test/vampire_subscription_priority

/// Fixes the fixture species to human so server race settings cannot affect the priority assertions.
/datum/unit_test/vampire_subscription_priority/proc/create_vampire_candidate(donation_tier)
	var/mob/candidate = create_candidate(donation_tier, role_flag = /datum/dynamic_ruleset/roundstart/vampire::pref_flag)
	candidate.mock_client.prefs.value_cache[/datum/preference/choiced/species] = /datum/species/human
	return candidate

/// Tiers 0-4 must share one unchanged lottery pool; only tier 5 may take priority.
/datum/unit_test/vampire_subscription_priority/ordinary_pool/Run()
	var/datum/dynamic_ruleset/roundstart/vampire/ruleset = allocate(/datum/dynamic_ruleset/roundstart/vampire)
	var/list/mob/weighted_candidates = list()
	for(var/tier in list(BASIC_DONATOR_LEVEL, DONATOR_TIER_1, DONATOR_TIER_2, DONATOR_TIER_3, DONATOR_TIER_4))
		var/mob/candidate = create_vampire_candidate(tier)
		weighted_candidates[candidate] = 10 + tier
	// Inspect the protected draw boundary so the equality of lower-tier access does not depend on RNG.
	var/list/mob/ordinary_pool = UNLINT(ruleset.get_priority_candidates(weighted_candidates))
	TEST_ASSERT_EQUAL(length(ordinary_pool), 5, "Vampire priority excluded a tier-0-through-4 candidate from the ordinary pool.")
	for(var/mob/candidate as anything in weighted_candidates)
		TEST_ASSERT_EQUAL(ordinary_pool[candidate], weighted_candidates[candidate], "Vampire priority changed a lower tier's lottery weight.")

/// Eligible tier 5 candidates fill existing slots first; banned, opted-out, or incompatible subscribers cannot bypass filters.
/datum/unit_test/vampire_subscription_priority/roundstart/Run()
	for(var/use_weights in list(FALSE, TRUE))
		CONFIG_SET(flag/antag_weighted_selection, use_weights)
		var/mob/ordinary = create_vampire_candidate(BASIC_DONATOR_LEVEL)
		var/mob/tier_four = create_vampire_candidate(DONATOR_TIER_4)
		var/mob/tier_five = create_vampire_candidate(DONATOR_TIER_5)
		var/mob/other_tier_five = create_vampire_candidate(DONATOR_TIER_5)
		var/mob/wrong_preference = create_vampire_candidate(DONATOR_TIER_5)
		wrong_preference.mock_client.prefs.be_special = list(ROLE_TRAITOR)
		var/mob/banned = create_vampire_candidate(DONATOR_TIER_5)
		banned.mock_client.ban_cache = list(/datum/dynamic_ruleset/roundstart/vampire::pref_flag)
		var/mob/incompatible_species = create_vampire_candidate(DONATOR_TIER_5)
		incompatible_species.mock_client.prefs.value_cache[/datum/preference/choiced/species] = /datum/species/plasmaman
		var/list/mob/candidates = list(ordinary, tier_four, tier_five, other_tier_five, wrong_preference, banned, incompatible_species)
		var/datum/dynamic_ruleset/roundstart/vampire/ruleset = allocate(/datum/dynamic_ruleset/roundstart/vampire)
		TEST_ASSERT(ruleset.prepare_execution(72, candidates), "Vampire preparation failed with eligible candidates (weights=[use_weights]).")
		TEST_ASSERT_EQUAL(length(ruleset.selected_minds), 3, "Vampire priority changed the native population cap.")
		TEST_ASSERT((ruleset.selected_minds[1] in list(tier_five.mind, other_tier_five.mind)) && (ruleset.selected_minds[2] in list(tier_five.mind, other_tier_five.mind)), "Vampires did not fill the first slots from eligible tier 5 candidates.")
		TEST_ASSERT(ruleset.selected_minds[3] in list(ordinary.mind, tier_four.mind), "Vampires did not fill the remaining slot from the ordinary pool.")
		TEST_ASSERT_EQUAL(length(candidates), 4, "Vampire selection did not remove exactly the three selected candidates.")
		TEST_ASSERT((wrong_preference in candidates) && (banned in candidates) && (incompatible_species in candidates), "A tier-5 subscription bypassed Vampire opt-in, bans, or the native species check.")

/// Cult keeps native history weights and never opts into subscription priority.
/datum/unit_test/traitor_subscription_selection/unaffected_cult/Run()
	CONFIG_SET(flag/antag_weighted_selection, TRUE)
	CONFIG_SET(number/antag_base_weight, 100)
	CONFIG_SET(number/antag_weight_penalty, 100)
	CONFIG_SET(number/antag_min_weight, 0)
	var/list/mob/candidates = list()
	var/list/datum/mind/ordinary_minds = list()
	for(var/i in 1 to 3)
		var/mob/ordinary = create_candidate(BASIC_DONATOR_LEVEL, role_flag = ROLE_CULTIST)
		var/mob/subscriber = create_candidate(DONATOR_TIER_5, role_flag = ROLE_CULTIST)
		history_by_ckey[subscriber.mock_client.ckey] = 1
		candidates += list(ordinary, subscriber)
		ordinary_minds += ordinary.mind
	var/datum/dynamic_ruleset/roundstart/blood_cult/ruleset = allocate(/datum/dynamic_ruleset/roundstart/blood_cult)
	TEST_ASSERT_NULL(UNLINT(ruleset.get_priority_candidates(candidates)), "Cult opted into subscription selection.")
	TEST_ASSERT(ruleset.prepare_execution(40, candidates), "Cult preparation failed with three eligible positive-weight candidates.")
	TEST_ASSERT_EQUAL(length(ruleset.selected_minds), 3, "Cult subscription neutrality changed the native slot count.")
	for(var/datum/mind/selected as anything in ruleset.selected_minds)
		TEST_ASSERT(selected in ordinary_minds, "A subscription overrode Cult's native history weights.")

/// Priority remains local to each selected event while both events share the native candidate list.
/datum/unit_test/traitor_subscription_selection/mixed_roundstart/Run()
	for(var/use_weights in list(FALSE, TRUE))
		CONFIG_SET(flag/antag_weighted_selection, use_weights)
		var/list/mob/candidates = list()
		var/list/tier_by_mind = list()
		for(var/tier in list(DONATOR_TIER_5, DONATOR_TIER_5, DONATOR_TIER_4, DONATOR_TIER_4, DONATOR_TIER_3, BASIC_DONATOR_LEVEL))
			var/mob/candidate = create_candidate(tier)
			candidate.mock_client.prefs.be_special = list(ROLE_TRAITOR, ROLE_CHANGELING)
			candidates += candidate
			tier_by_mind[candidate.mind] = tier
		var/datum/dynamic_ruleset/roundstart/traitor/traitors = allocate(/datum/dynamic_ruleset/roundstart/traitor)
		var/datum/dynamic_ruleset/roundstart/changeling/changelings = allocate(/datum/dynamic_ruleset/roundstart/changeling)
		TEST_ASSERT(traitors.prepare_execution(48, candidates), "The traitor portion of a mixed round failed.")
		TEST_ASSERT(changelings.prepare_execution(48, candidates), "The Changeling portion of a mixed round failed.")
		TEST_ASSERT_EQUAL(length(traitors.selected_minds), 2, "Mixed-round traitors changed the native cap.")
		TEST_ASSERT_EQUAL(length(changelings.selected_minds), 2, "Mixed-round Changelings changed the native cap.")
		for(var/datum/mind/selected as anything in traitors.selected_minds)
			TEST_ASSERT_EQUAL(tier_by_mind[selected], DONATOR_TIER_5, "Mixed-round traitors skipped tier 5.")
		for(var/datum/mind/selected as anything in changelings.selected_minds)
			TEST_ASSERT_EQUAL(tier_by_mind[selected], DONATOR_TIER_4, "Mixed-round Changelings skipped the remaining tier 4 candidates.")
		TEST_ASSERT_EQUAL(length(candidates), 2, "Mixed events duplicated or lost a selected candidate.")

/// An all-zero highest-tier group must fill its slots before positive-weight lower tiers.
/datum/unit_test/roundstart_traitor_subscription_priority/zero_weights/Run()
	CONFIG_SET(flag/antag_weighted_selection, TRUE)
	CONFIG_SET(number/antag_base_weight, 100)
	CONFIG_SET(number/antag_weight_penalty, 100)
	CONFIG_SET(number/antag_min_weight, 0)
	var/mob/ordinary = create_candidate(BASIC_DONATOR_LEVEL)
	var/list/mob/candidates = list(ordinary)
	var/list/tier_by_mind = list()
	tier_by_mind[ordinary.mind] = BASIC_DONATOR_LEVEL
	for(var/tier in list(DONATOR_TIER_3, DONATOR_TIER_4, DONATOR_TIER_5, DONATOR_TIER_5))
		var/mob/candidate = create_candidate(tier)
		history_by_ckey[candidate.mock_client.ckey] = 1
		candidates += candidate
		tier_by_mind[candidate.mind] = tier
	var/datum/dynamic_ruleset/roundstart/traitor/ruleset = allocate(/datum/dynamic_ruleset/roundstart/traitor)
	TEST_ASSERT(ruleset.prepare_execution(120, candidates), "Zero-weight subscribers prevented traitor preparation.")
	TEST_ASSERT_EQUAL(length(ruleset.selected_minds), 5, "An all-zero priority pool lost or duplicated a traitor slot.")
	var/list/expected_tiers = list(DONATOR_TIER_5, DONATOR_TIER_5, DONATOR_TIER_4, DONATOR_TIER_3, BASIC_DONATOR_LEVEL)
	for(var/i in 1 to length(expected_tiers))
		TEST_ASSERT_EQUAL(tier_by_mind[ruleset.selected_minds[i]], expected_tiers[i], "Zero historical weights displaced subscription priority.")
	TEST_ASSERT_EQUAL(length(candidates), 0, "Zero-weight selection left eligible candidates unselected.")
