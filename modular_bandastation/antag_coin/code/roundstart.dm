/// Ordinary preparation errors must not strand a paid request in SETTING_UP.
/datum/antag_coin_manager/proc/prepare_roundstart()
	try
		if(!SSdynamic.select_roundstart_antagonists())
			return FALSE
		CHECK_TICK
		SEND_GLOBAL_SIGNAL(COMSIG_GLOB_PRE_JOBS_ASSIGNED, SSticker)
		if(!SSjob.divide_occupations())
			return FALSE
		CHECK_TICK
		return validate_prepared()
	catch(var/exception/error)
		failure_reason = "Ошибка подготовки выбранного сценария."
		log_game("Antag coin preparation exception: [error.name] at [error.file]:[error.line].")
		return FALSE

/// Capture only the state that this attempt can change, before the dry job run.
/datum/antag_coin_manager/proc/begin_start()
	var/datum/antag_coin_request/request = approved_request
	if(!request)
		return TRUE
	for(var/player_ckey in requests.Copy())
		var/datum/antag_coin_request/pending = requests[player_ckey]
		if(pending != request)
			close_request(pending, "Подготовка раунда началась. Коин не потрачен.")
	failure_reason = player_error(request.get_client(), require_lobby = FALSE, require_subscription = FALSE)
	if(failure_reason)
		return FALSE
	saved_forced_jobs = SSjob.forced_occupations?.Copy()
	saved_prevented_jobs = deep_copy_list_alt(SSjob.prevented_occupations)
	saved_spawn_counts = SSdynamic.rulesets_to_spawn.Copy()
	saved_tier = SSdynamic.current_tier
	saved_timers = list(SSdynamic.light_ruleset_start, SSdynamic.heavy_ruleset_start, SSdynamic.latejoin_ruleset_start)
	displaced_rulesets = list()
	start_prepared = TRUE
	for(var/datum/dynamic_ruleset/roundstart/queued in SSdynamic.queued_rulesets.Copy())
		displaced_rulesets += queued
		SSdynamic.unqueue_ruleset(queued)
	coin_ruleset = new request.ruleset_type(SSdynamic.get_config())
	var/client/player = request.get_client()
	coin_ruleset.coin_reserved_mind = player.mob.mind
	SSdynamic.queued_rulesets += coin_ruleset
	return TRUE

/// Final validation happens after real job assignment and before creating characters.
/datum/antag_coin_manager/proc/validate_prepared()
	if(!approved_request)
		return TRUE
	var/client/player = approved_request.get_client()
	failure_reason = player_error(player, require_lobby = FALSE, require_subscription = FALSE)
	if(failure_reason)
		return FALSE
	if(!coin_ruleset || player.mob.mind != coin_ruleset.coin_reserved_mind || !(player.mob.mind in coin_ruleset.selected_minds))
		failure_reason = "Не удалось закрепить роль за владельцем антаг коина."
		return FALSE
	var/list/candidates = ready_players() - SSjob.unassigned
	failure_reason = scenario_error(coin_ruleset, player.mob, candidates)
	if(failure_reason)
		return FALSE
	for(var/datum/mind/member as anything in coin_ruleset.selected_minds)
		var/mob/dead/new_player/lobby_player = member.current
		if(!istype(lobby_player) || !GET_CLIENT(lobby_player) || !(lobby_player in coin_ruleset.trim_candidates(list(lobby_player))))
			failure_reason = "Состав команды изменился во время подготовки."
			return FALSE
		if(is_unassigned_job(member.assigned_role) || (member.assigned_role.title in coin_ruleset.get_blacklisted_roles()))
			failure_reason = "Не удалось назначить совместимую профессию."
			return FALSE
		var/forced_job = LAZYACCESS(SSjob.forced_occupations, member)
		if(forced_job && !istype(member.assigned_role, forced_job))
			failure_reason = "Не удалось назначить обязательную профессию выбранного сценария."
			return FALSE
	if(istype(coin_ruleset, /datum/dynamic_ruleset/roundstart/revolution))
		var/heads = 0
		for(var/mob/dead/new_player/candidate as anything in candidates)
			if(candidate.mind?.assigned_role?.job_flags & JOB_HEAD_OF_STAFF)
				heads++
		var/datum/dynamic_ruleset/roundstart/revolution/revolution = coin_ruleset
		if(heads < revolution.heads_necessary)
			failure_reason = "Недостаточно глав отделов для Revolution."
			return FALSE
	return TRUE

/// A failed preparation is a new lobby attempt, not a silent fallback event.
/datum/antag_coin_manager/proc/abort_start(reason)
	var/datum/antag_coin_request/request = approved_request
	if(!request)
		return
	if(start_prepared)
		if(coin_ruleset)
			SSdynamic.unqueue_ruleset(coin_ruleset)
			QDEL_NULL(coin_ruleset)
		SSdynamic.queued_rulesets += displaced_rulesets
		SSjob.forced_occupations = saved_forced_jobs
		SSjob.prevented_occupations = saved_prevented_jobs
		SSdynamic.rulesets_to_spawn = saved_spawn_counts
		if(SSdynamic.current_tier != saved_tier)
			QDEL_NULL(SSdynamic.current_tier)
			SSdynamic.current_tier = saved_tier
		SSdynamic.light_ruleset_start = saved_timers[1]
		SSdynamic.heavy_ruleset_start = saved_timers[2]
		SSdynamic.latejoin_ruleset_start = saved_timers[3]
		start_prepared = FALSE
	SSjob.reset_occupations()
	approved_request = null
	restart_requested = TRUE
	close_request(request, "Не удалось запустить выбранный сценарий. Запуск отменён; возврат антаг коина обрабатывается.")
	message_admins("Antag coin [request.id]: start canceled: [html_encode(reason)]. Returning to lobby countdown.")
	log_dynamic("Antag coin [request.id]: start canceled: [reason].")
	resolve_storage(request, TRUE)

/// Clown leaders are siblings of regular clown operatives, rather than their subtype.
/datum/antag_coin_manager/proc/has_assigned_role(datum/dynamic_ruleset/roundstart/ruleset, datum/mind/owner)
	if(!ruleset || !owner)
		return FALSE
	if(istype(ruleset, /datum/dynamic_ruleset/roundstart/revolution))
		return "Dormant Head Revolutionary" in owner.special_roles
	if(istype(ruleset, /datum/dynamic_ruleset/roundstart/nukies/clown))
		return owner.has_antag_datum(/datum/antagonist/nukeop/clownop) || owner.has_antag_datum(/datum/antagonist/nukeop/leader/clownop)
	return !!owner.has_antag_datum(ruleset.preview_antag_datum)

/// Called after native role assignment; the Revolution role is initially dormant.
/datum/antag_coin_manager/proc/round_started()
	set waitfor = FALSE
	if(!approved_request)
		return
	var/datum/antag_coin_request/request = approved_request
	var/datum/mind/owner = coin_ruleset?.coin_reserved_mind
	var/assigned = has_assigned_role(coin_ruleset, owner)
	QDEL_LIST(displaced_rulesets)
	start_prepared = FALSE
	approved_request = null
	coin_ruleset = null
	close_request(request, null)
	if(!assigned)
		message_admins("Antag coin [request.id]: native assignment failed after preparation. Refunding; check runtimes.")
		resolve_storage(request, TRUE)
	else
		resolve_storage(request, FALSE)
