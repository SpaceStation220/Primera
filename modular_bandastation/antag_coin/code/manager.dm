/// One immutable choice, bound to an account and to the connected lobby client.
/datum/antag_coin_request
	var/id
	var/player_ckey
	var/datum/weakref/client_ref
	var/ruleset_type
	var/expires_at
	var/state = ANTAG_COIN_PENDING
	var/admin_ckey
	var/charge_attempted = FALSE

/datum/antag_coin_request/New(client/player, ruleset_type)
	id = rustg_generate_uuid_v4()
	player_ckey = player.ckey
	client_ref = WEAKREF(player)
	src.ruleset_type = ruleset_type
	expires_at = world.time + ANTAG_COIN_REQUEST_TIMEOUT

/datum/antag_coin_request/proc/get_client()
	return client_ref?.resolve()

/// Owns approval, its start reservation, and retries of durable resolution.
/datum/antag_coin_manager
	var/datum/antag_coin_store/store
	var/list/requests = list()
	var/datum/antag_coin_request/approved_request
	var/datum/antag_coin_request/approving_request
	var/list/account_cache = list()
	var/list/loading_accounts = list()
	var/list/opening_clients = list()
	var/storage_recovered = FALSE
	var/storage_recovering = FALSE
	var/restart_requested = FALSE
	var/failure_reason
	var/datum/dynamic_ruleset/roundstart/coin_ruleset
	var/list/saved_forced_jobs
	var/list/saved_prevented_jobs
	var/list/saved_spawn_counts
	var/list/displaced_rulesets
	var/datum/dynamic_tier/saved_tier
	var/list/saved_timers
	var/start_prepared = FALSE

/datum/antag_coin_manager/New()
	store = new

/datum/antag_coin_manager/proc/notify_player(client/player, message)
	if(player)
		to_chat(player, message)

/datum/antag_coin_manager/Destroy()
	QDEL_LIST_ASSOC_VAL(requests)
	QDEL_NULL(store)
	return ..()

/// An explicit allowlist: no client-supplied typepaths, Spies, or non-role modes.
/datum/antag_coin_manager/proc/choices()
	var/static/list/allowed = list(
		"traitor" = /datum/dynamic_ruleset/roundstart/traitor,
		"malf_ai" = /datum/dynamic_ruleset/roundstart/malf_ai,
		"blood_brother" = /datum/dynamic_ruleset/roundstart/blood_brother,
		"changeling" = /datum/dynamic_ruleset/roundstart/changeling,
		"blood_worm" = /datum/dynamic_ruleset/roundstart/blood_worm,
		"heretic" = /datum/dynamic_ruleset/roundstart/heretic,
		"wizard" = /datum/dynamic_ruleset/roundstart/wizard,
		"blood_cult" = /datum/dynamic_ruleset/roundstart/blood_cult,
		"nukies" = /datum/dynamic_ruleset/roundstart/nukies,
		"clownops" = /datum/dynamic_ruleset/roundstart/nukies/clown,
		"revolution" = /datum/dynamic_ruleset/roundstart/revolution,
		"vampire" = /datum/dynamic_ruleset/roundstart/vampire,
	)
	return allowed

/datum/antag_coin_manager/proc/has_subscription(client/player)
	return player && player.donator_level >= DONATOR_TIER_5

/datum/antag_coin_manager/proc/refresh_subscription(client/player)
	return SScentral.update_player_donate_tier_blocking(player) && has_subscription(player)

/datum/antag_coin_manager/proc/lobby_open()
	return SSticker.current_state == GAME_STATE_PREGAME

/datum/antag_coin_manager/proc/has_admin()
	return length(get_holders_with_rights(R_ADMIN)) > 0

/datum/antag_coin_manager/proc/is_present_admin(client/admin)
	return admin && (admin in GLOB.admins) && check_rights_for(admin, R_ADMIN)

/datum/antag_coin_manager/proc/ensure_storage()
	if(storage_recovered)
		return TRUE
	if(storage_recovering)
		return FALSE
	storage_recovering = TRUE
	storage_recovered = store.recover()
	storage_recovering = FALSE
	return storage_recovered

/// Only lightweight cached data is read during preference polling.
/datum/antag_coin_manager/proc/card_data(client/player)
	var/list/account = account_cache[player.ckey]
	var/remaining = account ? max(0, ceil((account["ready_at"] - world.time) / (1 SECONDS))) : 0
	return list(
		"tier_five" = has_subscription(player),
		"remaining" = remaining,
		"pending" = !isnull(requests[player.ckey]) || account?["pending"],
		"approved" = !isnull(approved_request),
		"lobby" = lobby_open(),
	)

/datum/antag_coin_manager/proc/load_account(client/player)
	var/player_ckey = player?.ckey
	if(!player_ckey)
		return null
	while(loading_accounts[player_ckey])
		stoplag(1)
	loading_accounts[player_ckey] = TRUE
	var/list/account
	if(ensure_storage())
		account = store.read_account(player_ckey)
	if(account)
		account_cache[player_ckey] = list("ready_at" = world.time + account["remaining"] * (1 SECONDS), "pending" = account["pending"])
	loading_accounts -= player_ckey
	return account

/datum/antag_coin_manager/proc/remaining_text(seconds)
	var/minutes = ceil(seconds / 60)
	return "[FLOOR(minutes / 60, 1)] ч. [minutes % 60] мин."

/// Returns the reason rather than silently changing player preferences.
/datum/antag_coin_manager/proc/player_error(client/player, require_lobby = TRUE, require_subscription = TRUE)
	if(!player || (require_subscription && !has_subscription(player)))
		return "Для использования «Антаг коина» требуется действующая подписка Tier 5."
	if(require_lobby && !lobby_open())
		return "Антаг коин можно использовать только в лобби до начала подготовки раунда."
	var/mob/dead/new_player/lobby_player = player.mob
	if(!istype(lobby_player) || lobby_player.ready != PLAYER_READY_TO_PLAY || !lobby_player.mind)
		return "Для использования антаг коина нужно быть готовым к старту раунда."
	if(!player.prefs.read_preference(/datum/preference/toggle/antag_roll))
		return "Включите общий подбор антагонистов перед использованием антаг коина."
	return null

/datum/antag_coin_manager/proc/ready_players()
	var/list/players = list()
	for(var/mob/dead/new_player/player as anything in GLOB.new_player_list)
		if(GET_CLIENT(player) && player.mind && player.ready == PLAYER_READY_TO_PLAY)
			players += player
	return players

/// Native hard requirements are separate from the random event's weight.
/datum/antag_coin_manager/proc/scenario_error(datum/dynamic_ruleset/roundstart/ruleset, mob/dead/new_player/player, list/candidates)
	if(ruleset.type in SSdynamic.admin_disabled_rulesets)
		return "Сценарий отключён администрацией."
	if(!ruleset.can_be_selected())
		return "Сценарий сейчас недоступен."
	var/tier = isnull(SSdynamic.current_tier) ? DYNAMIC_TIER_LOW : SSdynamic.current_tier.tier
	if(length(candidates) < ruleset.get_minimum_population(tier))
		return "Недостаточно готовых игроков для этого сценария."
	var/list/eligible = ruleset.trim_candidates(candidates)
	if(!(player in eligible))
		return "Нет допуска к роли: проверьте предпочтения, баны, возраст аккаунта, вид и профессию."
	if(ruleset.get_antag_cap(length(candidates), ruleset.max_antag_cap || ruleset.min_antag_cap) < 1)
		return "В этом сценарии нет доступного места."
	if(length(eligible) < ruleset.get_antag_cap(length(candidates), ruleset.min_antag_cap))
		return "Недостаточно подходящих кандидатов для команды."
	return null

/datum/antag_coin_manager/proc/request_role(client/player, choice)
	var/error = player_error(player)
	if(error)
		notify_player(player, span_danger(error))
		return FALSE
	var/datum/dynamic_ruleset/roundstart/ruleset_type = choices()[choice]
	if(!ruleset_type || approved_request || approving_request || requests[player.ckey])
		notify_player(player, span_warning("На этот старт уже есть одобренная заявка или ваша заявка ещё рассматривается."))
		return FALSE
	if(!has_admin())
		notify_player(player, span_danger("На сервере нет администратора, который может одобрить антаг коин."))
		return FALSE
	if(!refresh_subscription(player))
		notify_player(player, span_danger("Не удалось подтвердить действующую подписку Tier 5. Коин не потрачен."))
		return FALSE
	var/list/account = load_account(player)
	if(!account)
		notify_player(player, span_danger("Хранилище антаг коина недоступно. Повторите позже."))
		return FALSE
	if(account["pending"] || account["remaining"] > 0)
		notify_player(player, span_warning("Антаг коин недоступен. До следующего использования осталось: [remaining_text(account["remaining"])]."))
		return FALSE
	// HTTP and SQL may both yield. Recheck before publishing a request.
	if(player_error(player) || approved_request || approving_request || requests[player.ckey] || !has_admin())
		return FALSE
	var/datum/dynamic_ruleset/roundstart/ruleset = new ruleset_type(SSdynamic.get_config())
	error = scenario_error(ruleset, player.mob, ready_players())
	qdel(ruleset)
	if(error)
		notify_player(player, span_danger(error))
		return FALSE
	var/datum/antag_coin_request/request = new(player, ruleset_type)
	requests[player.ckey] = request
	addtimer(CALLBACK(src, PROC_REF(expire_request), request), ANTAG_COIN_REQUEST_TIMEOUT)
	var/role_name = initial(ruleset_type.name)
	notify_player(player, span_notice("Заявка на [role_name] отправлена. Ожидание решения администратора: 30 секунд."))
	to_chat(get_holders_with_rights(R_ADMIN), span_adminnotice("[key_name(player)] просит антаг коин: [role_name]. Только этот стартовый сценарий; 30 секунд. \
		<a href='byond://?src=[REF(src)];[HrefToken(forceGlobal = TRUE)];approve=[request.id]'>Одобрить</a> / \
		<a href='byond://?src=[REF(src)];[HrefToken(forceGlobal = TRUE)];deny=[request.id]'>Отклонить</a>"), confidential = TRUE)
	return TRUE

/datum/antag_coin_manager/proc/expire_request(datum/antag_coin_request/request)
	if(request.state != ANTAG_COIN_PENDING && request.state != ANTAG_COIN_APPROVING)
		return
	close_request(request, "Время ожидания антаг коина истекло. Коин не потрачен.")

/datum/antag_coin_manager/proc/close_request(datum/antag_coin_request/request, message)
	request.state = ANTAG_COIN_CLOSED
	if(requests[request.player_ckey] == request)
		requests -= request.player_ckey
	if(message)
		notify_player(request.get_client(), span_notice(message))

/datum/antag_coin_manager/Topic(href, list/href_list)
	var/client/admin = usr?.client
	if(!is_present_admin(admin) || !admin.holder.CheckAdminHref(href, href_list))
		return
	var/request_id = href_list["approve"] || href_list["deny"]
	for(var/player_ckey in requests)
		var/datum/antag_coin_request/request = requests[player_ckey]
		if(request.id != request_id)
			continue
		if(href_list["deny"])
			if(request.state == ANTAG_COIN_PENDING)
				close_request(request, "Администратор отклонил антаг коин. Коин не потрачен.")
		else
			approve(request, admin)
		return

/// The global in-flight lock is taken before any HTTP or SQL yield.
/datum/antag_coin_manager/proc/approve(datum/antag_coin_request/request, client/admin)
	if(!is_present_admin(admin) || !lobby_open() || approved_request || approving_request)
		return FALSE
	if(request.state != ANTAG_COIN_PENDING || requests[request.player_ckey] != request || world.time >= request.expires_at)
		return FALSE
	approving_request = request
	request.state = ANTAG_COIN_APPROVING
	var/success = FALSE
	try
		success = validate_and_charge(request, admin)
	catch(var/exception/error)
		log_game("Antag coin approval exception: [error.name].")
	if(!success)
		approving_request = null
		close_request(request, "Антаг коин не одобрен: условия изменились или проверка не завершилась вовремя.")
		// Also resolves a SQL timeout whose write may actually have committed.
		if(request.charge_attempted)
			resolve_storage(request, TRUE, notify_result = FALSE)
		return FALSE
	var/client/player = request.get_client()
	approved_request = request
	request.state = ANTAG_COIN_APPROVED
	approving_request = null
	account_cache[player.ckey] = list("ready_at" = world.time + ANTAG_COIN_COOLDOWN_SECONDS * (1 SECONDS), "pending" = TRUE)
	for(var/player_ckey in requests.Copy())
		var/datum/antag_coin_request/other = requests[player_ckey]
		if(other != request)
			close_request(other, "На ближайший старт одобрен другой антаг коин. Ваш коин не потрачен.")
	var/datum/dynamic_ruleset/roundstart/ruleset_type = request.ruleset_type
	notify_player(player, span_notice("Антаг коин активирован: [initial(ruleset_type.name)]. Следующее использование будет доступно через 168 ч."))
	log_admin("[admin.ckey] approved antag coin [request.id] for [request.player_ckey]: [ruleset_type].")
	return TRUE

/datum/antag_coin_manager/proc/validate_and_charge(datum/antag_coin_request/request, client/admin)
	if(approving_request != request || !approval_valid(request, admin))
		return FALSE
	var/client/player = request.get_client()
	if(!refresh_subscription(player))
		return FALSE
	var/datum/dynamic_ruleset/roundstart/ruleset = new request.ruleset_type(SSdynamic.get_config())
	var/error = scenario_error(ruleset, player?.mob, ready_players())
	qdel(ruleset)
	if(error || !approval_valid(request, admin))
		return FALSE
	request.admin_ckey = admin.ckey
	request.charge_attempted = TRUE
	return store.claim(request) && approval_valid(request, admin)

/datum/antag_coin_manager/proc/approval_valid(datum/antag_coin_request/request, client/admin)
	return request.state == ANTAG_COIN_APPROVING && world.time < request.expires_at && lobby_open() \
		&& is_present_admin(admin) && !player_error(request.get_client()) && !approved_request

/// Failed resolutions are retained in SQL and retried without granting another use.
/datum/antag_coin_manager/proc/resolve_storage(datum/antag_coin_request/request, refund, notify_result = TRUE)
	var/success = FALSE
	try
		success = refund ? store.refund(request) : store.commit(request)
	catch(var/exception/error)
		log_game("Antag coin storage exception: [error.name].")
	if(!success)
		addtimer(CALLBACK(src, PROC_REF(resolve_storage), request, refund, notify_result), 10 SECONDS)
		message_admins("Antag coin [request.id]: storage resolution pending ([refund ? "refund" : "commit"]).")
		return FALSE
	account_cache -= request.player_ckey
	if(refund && notify_result)
		notify_player(request.get_client(), span_notice("Антаг коин возвращён, перезарядка этой активации отменена."))
	log_admin("Antag coin [request.id] for [request.player_ckey]: [refund ? "refunded" : "used"].")
	return TRUE
