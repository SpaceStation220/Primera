/// Controlled external persistence. Native SQL is covered by the disposable DB smoke test.
/datum/antag_coin_store/coin_test
	var/remaining = 0
	var/pending = FALSE
	var/request_id
	var/charges = 0
	var/refunds = 0
	var/datum/callback/on_claim

/datum/antag_coin_store/coin_test/recover()
	return TRUE

/datum/antag_coin_store/coin_test/read_account(player_ckey)
	return list("remaining" = remaining, "pending" = pending, "request_id" = request_id)

/datum/antag_coin_store/coin_test/claim(datum/antag_coin_request/request)
	if(remaining > 0 || pending)
		return FALSE
	charges++
	remaining = ANTAG_COIN_COOLDOWN_SECONDS
	pending = TRUE
	request_id = request.id
	on_claim?.Invoke()
	return TRUE

/datum/antag_coin_store/coin_test/resolve_request(datum/antag_coin_request/request, refund)
	if(request.id == request_id && pending)
		pending = FALSE
		if(refund)
			remaining = 0
			refunds++
	return TRUE

/// Only transport and connected-admin discovery are replaced; eligibility stays native.
/datum/antag_coin_manager/coin_test
	var/admin_present = TRUE
	var/in_lobby = TRUE
	var/subscription_check = TRUE
	var/refreshed_tier
	var/refresh_calls = 0
	var/list/players = list()
	var/list/messages = list()

/datum/antag_coin_manager/coin_test/has_admin()
	return admin_present

/datum/antag_coin_manager/coin_test/is_present_admin(client/admin)
	return admin && admin_present

/datum/antag_coin_manager/coin_test/lobby_open()
	return in_lobby

/datum/antag_coin_manager/coin_test/refresh_subscription(client/player)
	refresh_calls++
	if(!isnull(refreshed_tier))
		player.donator_level = refreshed_tier
	return subscription_check && has_subscription(player)

/datum/antag_coin_manager/coin_test/ready_players()
	return players.Copy()

/datum/antag_coin_manager/coin_test/notify_player(client/player, message)
	messages += message

/datum/antag_coin_manager/coin_test/proc/close_lobby_during_claim()
	in_lobby = FALSE

/datum/antag_coin_manager/coin_test/proc/throw_during_claim()
	throw EXCEPTION("Synthetic error after the persistence write")

/// Reuses the real preferences, ban cache, account-age mock, and history setup.
/datum/unit_test/antag_coin
	parent_type = /datum/unit_test/traitor_subscription_selection
	abstract_type = /datum/unit_test/antag_coin
	var/datum/antag_coin_manager/coin_test/manager
	var/datum/antag_coin_store/coin_test/coin_store

/datum/unit_test/antag_coin/New()
	. = ..()
	manager = allocate(/datum/antag_coin_manager/coin_test)
	qdel(manager.store)
	coin_store = allocate(/datum/antag_coin_store/coin_test)
	manager.store = coin_store

/datum/unit_test/antag_coin/proc/lobby_candidate(tier = DONATOR_TIER_5, role = ROLE_TRAITOR)
	var/mob/dead/new_player/player = create_candidate(tier, role_flag = role)
	player.ready = PLAYER_READY_TO_PLAY
	player.mind.current = player
	player.mind.set_assigned_role(SSjob.get_job_type(/datum/job/cargo_technician))
	manager.players += player
	return player

/datum/unit_test/antag_coin_allowlist
	parent_type = /datum/unit_test/antag_coin

/datum/unit_test/antag_coin_allowlist/Run()
	TEST_ASSERT_EQUAL(length(manager.choices()), 12, "The approved list must contain exactly twelve scenarios.")
	for(var/choice in manager.choices())
		var/ruleset_type = manager.choices()[choice]
		TEST_ASSERT(ispath(ruleset_type, /datum/dynamic_ruleset/roundstart), "A non-roundstart role entered the coin menu.")
		TEST_ASSERT(ruleset_type != /datum/dynamic_ruleset/roundstart/spies, "Spies must remain excluded.")
	var/mob/dead/new_player/player = lobby_candidate(DONATOR_TIER_4)
	TEST_ASSERT(manager.player_error(player.mock_client), "Tier four must not activate a coin.")
	player.mock_client.donator_level = DONATOR_TIER_5
	TEST_ASSERT_NULL(manager.player_error(player.mock_client), "Antag coin regression")
	TEST_ASSERT_EQUAL(manager.remaining_text(1), "0 ч. 1 мин.", "Antag coin regression")
	TEST_ASSERT_EQUAL(manager.remaining_text(ANTAG_COIN_COOLDOWN_SECONDS), "168 ч. 0 мин.", "Antag coin regression")

/// Buying a new subscription must not require reconnecting to replace the login cache.
/datum/unit_test/antag_coin_live_subscription_refresh
	parent_type = /datum/unit_test/antag_coin

/datum/unit_test/antag_coin_live_subscription_refresh/Run()
	var/mob/dead/new_player/player = lobby_candidate(DONATOR_TIER_4)
	manager.refreshed_tier = DONATOR_TIER_5
	coin_store.remaining = 3600
	manager.open_menu(player.mock_client)
	TEST_ASSERT_EQUAL(player.mock_client.donator_level, DONATOR_TIER_5, "A new tier-five purchase was blocked by the login cache.")
	TEST_ASSERT(findtext(manager.messages[length(manager.messages)], "1 ч. 0 мин."), "A verified tier five did not receive the cooldown message.")
	TEST_ASSERT_EQUAL(coin_store.charges, 0, "Opening the menu spent a coin.")
	manager.refreshed_tier = DONATOR_TIER_4
	manager.open_menu(player.mock_client)
	TEST_ASSERT(findtext(manager.messages[length(manager.messages)], "требуется действующая подписка Tier 5"), "An expired tier-five subscription was not rejected.")
	manager.opening_clients[player.mock_client.ckey] = TRUE
	var/previous_calls = manager.refresh_calls
	manager.open_menu(player.mock_client)
	TEST_ASSERT_EQUAL(manager.refresh_calls, previous_calls, "A reentrant click started another entitlement request.")

/datum/unit_test/antag_coin_personal_reservation
	parent_type = /datum/unit_test/antag_coin

/datum/unit_test/antag_coin_personal_reservation/Run()
	for(var/weighted in list(FALSE, TRUE))
		CONFIG_SET(flag/antag_weighted_selection, weighted)
		var/mob/dead/new_player/owner = lobby_candidate()
		var/mob/dead/new_player/other_five = lobby_candidate()
		var/mob/dead/new_player/four = lobby_candidate(DONATOR_TIER_4)
		var/mob/dead/new_player/ordinary = lobby_candidate(BASIC_DONATOR_LEVEL)
		var/list/candidates = list(ordinary, other_five, four, owner)
		var/datum/dynamic_ruleset/roundstart/traitor/one_slot = allocate(/datum/dynamic_ruleset/roundstart/traitor)
		one_slot.coin_reserved_mind = owner.mind
		TEST_ASSERT(one_slot.prepare_execution(24, candidates), "Native preparation with a personal reservation failed.")
		TEST_ASSERT_EQUAL(length(one_slot.selected_minds), 1, "The reservation increased the native cap.")
		TEST_ASSERT_EQUAL(one_slot.selected_minds[1], owner.mind, "Another tier five displaced the owner.")
		TEST_ASSERT(!(owner in candidates) && (other_five in candidates), "Reservation removed the wrong player.")
		var/datum/dynamic_ruleset/roundstart/traitor/three_slots = allocate(/datum/dynamic_ruleset/roundstart/traitor)
		three_slots.coin_reserved_mind = owner.mind
		TEST_ASSERT(three_slots.prepare_execution(72, list(ordinary, four, other_five, owner)), "Three-slot preparation failed.")
		TEST_ASSERT_EQUAL(length(three_slots.selected_minds), 3, "Antag coin regression")
		TEST_ASSERT_EQUAL(three_slots.selected_minds[1], owner.mind, "Antag coin regression")
		TEST_ASSERT_EQUAL(three_slots.selected_minds[2], other_five.mind, "Antag coin regression")
		TEST_ASSERT_EQUAL(three_slots.selected_minds[3], four.mind, "Ordinary selection of the remaining slots changed.")

/datum/unit_test/antag_coin_reservation_filters
	parent_type = /datum/unit_test/antag_coin

/datum/unit_test/antag_coin_reservation_filters/Run()
	var/mob/dead/new_player/owner = lobby_candidate()
	var/mob/dead/new_player/other = lobby_candidate()
	for(var/mode in list("optout", "global_optout", "ban"))
		owner.mock_client.prefs.be_special = list(ROLE_TRAITOR)
		owner.mock_client.ban_cache = list()
		TEST_ASSERT(owner.mock_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/antag_roll], mode != "global_optout"), "Antag coin regression")
		if(mode == "optout")
			owner.mock_client.prefs.be_special = list()
		if(mode == "ban")
			owner.mock_client.ban_cache = list(ROLE_SYNDICATE)
		var/datum/dynamic_ruleset/roundstart/traitor/ruleset = allocate(/datum/dynamic_ruleset/roundstart/traitor)
		ruleset.coin_reserved_mind = owner.mind
		var/list/candidates = list(other, owner)
		TEST_ASSERT(!ruleset.prepare_execution(24, candidates), "Reservation bypassed [mode].")
		TEST_ASSERT_EQUAL(length(ruleset.selected_minds), 0, "Antag coin regression")
		TEST_ASSERT_EQUAL(length(candidates), 2, "A failed reservation consumed other candidates.")

/datum/unit_test/antag_coin_approval_and_competition
	parent_type = /datum/unit_test/antag_coin

/datum/unit_test/antag_coin_approval_and_competition/Run()
	var/mob/dead/new_player/owner = lobby_candidate()
	var/mob/dead/new_player/other = lobby_candidate()
	lobby_candidate()
	TEST_ASSERT(!manager.request_role(owner.mock_client, "/datum/dynamic_ruleset/roundstart/spies"), "Client-supplied paths must not be accepted.")
	TEST_ASSERT(manager.request_role(owner.mock_client, "traitor"), "Antag coin regression")
	var/datum/antag_coin_request/first = manager.requests[owner.mock_client.ckey]
	TEST_ASSERT(!manager.request_role(owner.mock_client, "traitor"), "Duplicate requests were accepted.")
	TEST_ASSERT(manager.request_role(other.mock_client, "traitor"), "Antag coin regression")
	var/datum/antag_coin_request/second = manager.requests[other.mock_client.ckey]
	TEST_ASSERT(manager.approve(first, other.mock_client), "Valid approval failed.")
	TEST_ASSERT_EQUAL(manager.approved_request, first, "Antag coin regression")
	TEST_ASSERT_EQUAL(second.state, ANTAG_COIN_CLOSED, "Competing requests must close without spending.")
	TEST_ASSERT(!manager.approve(first, other.mock_client), "A duplicate approval was accepted.")
	TEST_ASSERT(!manager.approve(second, other.mock_client), "A second coin was approved for the same attempt.")
	TEST_ASSERT_EQUAL(coin_store.charges, 1, "Antag coin regression")
	TEST_ASSERT_EQUAL(coin_store.remaining, ANTAG_COIN_COOLDOWN_SECONDS, "Antag coin regression")

/datum/unit_test/antag_coin_approval_expiry
	parent_type = /datum/unit_test/antag_coin

/datum/unit_test/antag_coin_approval_expiry/Run()
	var/mob/dead/new_player/owner = lobby_candidate()
	var/mob/dead/new_player/admin = lobby_candidate()
	lobby_candidate()
	manager.admin_present = FALSE
	TEST_ASSERT(!manager.request_role(owner.mock_client, "traitor"), "A request without an administrator was accepted.")
	manager.admin_present = TRUE
	TEST_ASSERT(manager.request_role(owner.mock_client, "traitor"), "Antag coin regression")
	var/datum/antag_coin_request/request = manager.requests[owner.mock_client.ckey]
	request.expires_at = world.time
	TEST_ASSERT(!manager.approve(request, admin.mock_client), "Approval at the expiry boundary was accepted.")
	manager.expire_request(request)
	TEST_ASSERT_EQUAL(coin_store.charges, 0, "Antag coin regression")
	TEST_ASSERT_EQUAL(length(manager.requests), 0, "Antag coin regression")
	TEST_ASSERT(manager.request_role(owner.mock_client, "traitor"), "Antag coin regression")
	request = manager.requests[owner.mock_client.ckey]
	manager.subscription_check = FALSE
	TEST_ASSERT(!manager.approve(request, admin.mock_client), "An unverified/stale tier five was accepted.")
	TEST_ASSERT_EQUAL(coin_store.charges, 0, "Antag coin regression")

/datum/unit_test/antag_coin_approval_race_refund
	parent_type = /datum/unit_test/antag_coin

/datum/unit_test/antag_coin_approval_race_refund/Run()
	var/mob/dead/new_player/owner = lobby_candidate()
	var/mob/dead/new_player/admin = lobby_candidate()
	lobby_candidate()
	TEST_ASSERT(manager.request_role(owner.mock_client, "traitor"), "Antag coin regression")
	var/datum/antag_coin_request/request = manager.requests[owner.mock_client.ckey]
	coin_store.on_claim = CALLBACK(manager, TYPE_PROC_REF(/datum/antag_coin_manager/coin_test, close_lobby_during_claim))
	TEST_ASSERT(!manager.approve(request, admin.mock_client), "Lobby closed during SQL but approval still succeeded.")
	TEST_ASSERT_NULL(manager.approved_request, "Antag coin regression")
	TEST_ASSERT_NULL(manager.approving_request, "Antag coin regression")
	TEST_ASSERT_EQUAL(coin_store.charges, 1, "Antag coin regression")
	TEST_ASSERT_EQUAL(coin_store.refunds, 1, "A write racing round setup must be refunded.")
	TEST_ASSERT_EQUAL(coin_store.remaining, 0, "Antag coin regression")
	manager.resolve_storage(request, TRUE)
	TEST_ASSERT_EQUAL(coin_store.refunds, 1, "Retrying refund credited the coin twice.")

/datum/unit_test/antag_coin_team_minimum
	parent_type = /datum/unit_test/antag_coin

/datum/unit_test/antag_coin_team_minimum/Run()
	var/mob/dead/new_player/owner = lobby_candidate(role = ROLE_CULTIST)
	var/mob/dead/new_player/other = lobby_candidate(role = ROLE_CULTIST)
	var/datum/dynamic_ruleset/roundstart/blood_cult/cult = allocate(/datum/dynamic_ruleset/roundstart/blood_cult)
	cult.coin_reserved_mind = owner.mind
	var/list/candidates = list(owner, other)
	TEST_ASSERT(!cult.prepare_execution(40, candidates), "A personal slot bypassed the cult's three-player minimum.")
	TEST_ASSERT_EQUAL(length(cult.selected_minds), 0, "Antag coin regression")
	TEST_ASSERT_EQUAL(length(candidates), 2, "Antag coin regression")
	var/mob/dead/new_player/third = lobby_candidate(role = ROLE_CULTIST)
	TEST_ASSERT(cult.prepare_execution(40, list(other, third, owner)), "A complete native team could not prepare.")
	TEST_ASSERT_EQUAL(length(cult.selected_minds), 3, "Antag coin regression")
	TEST_ASSERT_EQUAL(cult.selected_minds[1], owner.mind, "Antag coin regression")

/datum/unit_test/antag_coin_approval_exception_refund
	parent_type = /datum/unit_test/antag_coin

/datum/unit_test/antag_coin_approval_exception_refund/Run()
	var/mob/dead/new_player/owner = lobby_candidate()
	var/mob/dead/new_player/admin = lobby_candidate()
	lobby_candidate()
	TEST_ASSERT(manager.request_role(owner.mock_client, "traitor"), "Request setup failed.")
	var/datum/antag_coin_request/request = manager.requests[owner.mock_client.ckey]
	coin_store.on_claim = CALLBACK(manager, TYPE_PROC_REF(/datum/antag_coin_manager/coin_test, throw_during_claim))
	TEST_ASSERT(!manager.approve(request, admin.mock_client), "An exception incorrectly approved the request.")
	TEST_ASSERT_NULL(manager.approved_request, "The failed approval kept its role reservation.")
	TEST_ASSERT_NULL(manager.approving_request, "The exception left the global approval lock held.")
	TEST_ASSERT_EQUAL(coin_store.charges, 1, "Fixture did not reach the persistence write.")
	TEST_ASSERT_EQUAL(coin_store.refunds, 1, "A post-write exception lost the coin.")

/datum/unit_test/antag_coin_lobby_countdown
	var/original_state
	var/original_time
	var/original_immediate
	var/original_countdown

/datum/unit_test/antag_coin_lobby_countdown/New()
	. = ..()
	original_state = SSticker.current_state
	original_time = SSticker.timeLeft
	original_immediate = SSticker.start_immediately
	original_countdown = CONFIG_GET(number/lobby_countdown)

/datum/unit_test/antag_coin_lobby_countdown/Destroy()
	SSticker.current_state = original_state
	SSticker.timeLeft = original_time
	SSticker.start_immediately = original_immediate
	CONFIG_SET(number/lobby_countdown, original_countdown)
	return ..()

/datum/unit_test/antag_coin_lobby_countdown/Run()
	CONFIG_SET(number/lobby_countdown, 120)
	SSticker.start_immediately = TRUE
	SSticker.timeLeft = 0
	SSticker.restart_coin_countdown()
	TEST_ASSERT_EQUAL(SSticker.current_state, GAME_STATE_PREGAME, "Antag coin regression")
	TEST_ASSERT(!SSticker.start_immediately, "Force-start bypassed the restarted countdown.")
	TEST_ASSERT_EQUAL(SSticker.timeLeft, 120 SECONDS, "The new lobby countdown was not reset in full.")

/// Dynamic's green tier is numeric zero, which must not fall back to the low tier.
/datum/unit_test/antag_coin_green_population
	parent_type = /datum/unit_test/antag_coin
	var/datum/dynamic_tier/original_tier

/datum/unit_test/antag_coin_green_population/New()
	. = ..()
	original_tier = SSdynamic.current_tier
	SSdynamic.current_tier = allocate(/datum/dynamic_tier/greenshift)

/datum/unit_test/antag_coin_green_population/Destroy()
	SSdynamic.current_tier = original_tier
	return ..()

/datum/unit_test/antag_coin_green_population/Run()
	var/mob/dead/new_player/owner = lobby_candidate()
	lobby_candidate()
	lobby_candidate()
	var/datum/dynamic_ruleset/roundstart/traitor/ruleset = allocate(/datum/dynamic_ruleset/roundstart/traitor)
	ruleset.min_pop = alist()
	ruleset.min_pop[DYNAMIC_TIER_GREEN] = 3
	ruleset.min_pop[DYNAMIC_TIER_LOW] = 100
	TEST_ASSERT_NULL(manager.scenario_error(ruleset, owner, manager.players), "The green-tier population rule was replaced by low-tier limits.")

/// Successfully granting the commander must not accidentally refund a clown-op coin.
/datum/unit_test/antag_coin_clown_leader_confirmation
	parent_type = /datum/unit_test/antag_coin

/datum/unit_test/antag_coin_clown_leader_confirmation/Run()
	var/datum/mind/owner = allocate(/datum/mind)
	var/datum/dynamic_ruleset/roundstart/nukies/clown/ruleset = allocate(/datum/dynamic_ruleset/roundstart/nukies/clown)
	var/datum/antagonist/nukeop/leader/clownop/leader = allocate(/datum/antagonist/nukeop/leader/clownop)
	owner.antag_datums = list(leader)
	TEST_ASSERT(manager.has_assigned_role(ruleset, owner), "The clown commander was not recognized as a successful assignment.")
	var/datum/antagonist/nukeop/clownop/operative = allocate(/datum/antagonist/nukeop/clownop)
	owner.antag_datums = list(operative)
	TEST_ASSERT(manager.has_assigned_role(ruleset, owner), "The regular clown operative was not recognized.")
	var/datum/antagonist/nukeop/ordinary = allocate(/datum/antagonist/nukeop)
	owner.antag_datums = list(ordinary)
	TEST_ASSERT(!manager.has_assigned_role(ruleset, owner), "A different operative role incorrectly completed the clown-op coin.")
	owner.antag_datums = null

/// Exercise the actual reservation/occupation snapshot and rollback path together.
/datum/unit_test/antag_coin_start_rollback
	parent_type = /datum/unit_test/antag_coin
	var/list/original_queue
	var/list/original_forced
	var/list/original_counts
	var/list/original_timers
	var/datum/dynamic_tier/original_tier

/datum/unit_test/antag_coin_start_rollback/New()
	. = ..()
	original_queue = SSdynamic.queued_rulesets
	original_forced = SSjob.forced_occupations
	original_counts = SSdynamic.rulesets_to_spawn
	original_tier = SSdynamic.current_tier
	original_timers = list(SSdynamic.light_ruleset_start, SSdynamic.heavy_ruleset_start, SSdynamic.latejoin_ruleset_start)
	SSdynamic.queued_rulesets = list()
	SSjob.forced_occupations = list()
	SSdynamic.rulesets_to_spawn = original_counts.Copy()

/datum/unit_test/antag_coin_start_rollback/Destroy()
	if(manager.coin_ruleset)
		qdel(manager.coin_ruleset)
	SSdynamic.queued_rulesets = original_queue
	SSjob.forced_occupations = original_forced
	SSdynamic.rulesets_to_spawn = original_counts
	if(SSdynamic.current_tier != original_tier)
		qdel(SSdynamic.current_tier)
		SSdynamic.current_tier = original_tier
	SSdynamic.light_ruleset_start = original_timers[1]
	SSdynamic.heavy_ruleset_start = original_timers[2]
	SSdynamic.latejoin_ruleset_start = original_timers[3]
	return ..()

/datum/unit_test/antag_coin_start_rollback/Run()
	var/mob/dead/new_player/owner = lobby_candidate()
	var/mob/dead/new_player/admin = lobby_candidate()
	lobby_candidate()
	SSjob.prevented_occupations[admin.mind] = list("fixture_marker")
	var/starting_count = SSdynamic.rulesets_to_spawn[ROUNDSTART]
	TEST_ASSERT(manager.request_role(owner.mock_client, "traitor"), "Antag coin regression")
	var/datum/antag_coin_request/request = manager.requests[owner.mock_client.ckey]
	TEST_ASSERT(manager.approve(request, admin.mock_client), "Antag coin regression")
	TEST_ASSERT(manager.begin_start(), "Antag coin regression")
	TEST_ASSERT_EQUAL(length(SSdynamic.queued_rulesets), 1, "Coin did not isolate its selected start event.")
	TEST_ASSERT(manager.coin_ruleset.prepare_execution(3, manager.players.Copy()), "Antag coin regression")
	TEST_ASSERT(manager.validate_prepared(), "A valid reserved owner did not pass post-job validation.")
	owner.mock_client.donator_level = DONATOR_TIER_4
	TEST_ASSERT(manager.validate_prepared(), "Subscription expiry after paid approval must not revoke the booked role.")
	SSjob.forced_occupations[owner.mind] = /datum/job/ai
	TEST_ASSERT(!manager.validate_prepared(), "An incompatible forced job was not detected before spawning characters.")
	SSjob.forced_occupations -= owner.mind
	SSdynamic.rulesets_to_spawn[ROUNDSTART] -= 1
	SSdynamic.light_ruleset_start = world.time + 100 SECONDS
	owner.mock_client.prefs.be_special = list()
	TEST_ASSERT(!manager.validate_prepared(), "An opt-out after preparation was ignored.")
	manager.abort_start(manager.failure_reason)
	TEST_ASSERT_NULL(manager.approved_request, "Antag coin regression")
	TEST_ASSERT_NULL(manager.coin_ruleset, "Antag coin regression")
	TEST_ASSERT_EQUAL(length(SSdynamic.queued_rulesets), 0, "Antag coin regression")
	TEST_ASSERT_EQUAL(SSdynamic.rulesets_to_spawn[ROUNDSTART], starting_count, "Antag coin regression")
	TEST_ASSERT(!(owner.mind in SSjob.prevented_occupations), "Reservation left a stale occupation restriction.")
	TEST_ASSERT_EQUAL(SSjob.prevented_occupations[admin.mind][1], "fixture_marker", "Rollback lost a preexisting occupation restriction.")
	TEST_ASSERT_EQUAL(coin_store.remaining, 0, "Antag coin regression")
	TEST_ASSERT_EQUAL(coin_store.refunds, 1, "Antag coin regression")
	TEST_ASSERT(manager.restart_requested, "Antag coin regression")
	manager.abort_start("repeated callback")
	TEST_ASSERT_EQUAL(coin_store.refunds, 1, "Aborting twice refunded twice.")
