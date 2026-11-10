/datum/asset/simple/antag_coin
	assets = list("antag_coin.png" = 'modular_bandastation/antag_coin/icons/antag_coin.png')

/// Separate action: bulk antagonist preference toggles cannot activate a coin.
/datum/preference_middleware/antag_coin
	action_delegations = list("antag_coin_open" = PROC_REF(open_coin))
	var/next_card_refresh = 0

/datum/preference_middleware/antag_coin/get_ui_data(mob/user)
	var/client/player = preferences.parent
	if(GLOB.antag_coins.has_subscription(player) && world.time >= next_card_refresh)
		next_card_refresh = world.time + 30 SECONDS
		INVOKE_ASYNC(GLOB.antag_coins, TYPE_PROC_REF(/datum/antag_coin_manager, load_account), player)
	return list("antag_coin" = GLOB.antag_coins.card_data(player))

/datum/preference_middleware/antag_coin/get_ui_assets()
	return list(get_asset_datum(/datum/asset/simple/antag_coin))

/datum/preference_middleware/antag_coin/proc/open_coin(list/params, mob/user)
	if(user.client != preferences.parent)
		return FALSE
	INVOKE_ASYNC(GLOB.antag_coins, TYPE_PROC_REF(/datum/antag_coin_manager, open_menu), user.client)
	return TRUE

/datum/antag_coin_manager/proc/open_menu(client/player)
	var/player_ckey = player?.ckey
	if(!player_ckey || opening_clients[player_ckey])
		return
	opening_clients[player_ckey] = TRUE
	try
		process_open_menu(player)
	catch(var/exception/error)
		notify_player(player, span_danger("Проверка антаг коина временно недоступна. Коин не потрачен."))
		log_game("Antag coin menu exception: [error.name].")
	opening_clients -= player_ckey

/// Refresh before inspecting cached tier so an in-session purchase works immediately.
/datum/antag_coin_manager/proc/process_open_menu(client/player)
	if(!refresh_subscription(player))
		var/message = has_subscription(player) \
			? "Не удалось подтвердить действующую подписку Tier 5. Коин не потрачен." \
			: "Для использования «Антаг коина» требуется действующая подписка Tier 5."
		notify_player(player, span_danger(message))
		return
	var/list/account = load_account(player)
	if(!player)
		return
	if(!account)
		notify_player(player, span_danger("Хранилище антаг коина недоступно. Повторите позже."))
		return
	if(account["remaining"] > 0)
		notify_player(player, span_notice("Антаг коин перезаряжается. До следующего использования осталось: [remaining_text(account["remaining"])]."))
		return
	var/error = player_error(player)
	if(error)
		notify_player(player, span_danger(error))
		return
	if(account["pending"] || requests[player.ckey] || approved_request || approving_request)
		notify_player(player, span_warning("На ближайший старт уже есть заявка или операция с вашим коином ещё обрабатывается."))
		return
	if(!has_admin())
		notify_player(player, span_danger("На сервере нет администратора, который может одобрить антаг коин."))
		return
	var/datum/antag_coin_menu/menu = new(player, src)
	menu.ui_interact(player.mob)

/datum/antag_coin_menu
	var/datum/weakref/client_ref
	var/datum/antag_coin_manager/manager

/datum/antag_coin_menu/New(client/player, datum/antag_coin_manager/manager)
	client_ref = WEAKREF(player)
	src.manager = manager

/datum/antag_coin_menu/ui_state(mob/user)
	return GLOB.always_state

/datum/antag_coin_menu/ui_status(mob/user, datum/ui_state/state)
	return user.client == client_ref.resolve() ? UI_INTERACTIVE : UI_CLOSE

/datum/antag_coin_menu/ui_assets(mob/user)
	return list(get_asset_datum(/datum/asset/simple/antag_coin))

/datum/antag_coin_menu/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AntagCoin", "Антаг коин")
		ui.open()

/datum/antag_coin_menu/ui_close(mob/user)
	qdel(src)

/datum/antag_coin_menu/ui_data(mob/user)
	var/list/options = list()
	var/list/candidates = manager.ready_players()
	for(var/choice in manager.choices())
		var/ruleset_type = manager.choices()[choice]
		var/datum/dynamic_ruleset/roundstart/ruleset = new ruleset_type(SSdynamic.get_config())
		options += list(list(
			"id" = choice,
			"name" = initial(ruleset.name),
			"reason" = manager.scenario_error(ruleset, user, candidates),
		))
		qdel(ruleset)
	return list("options" = options, "blocked" = manager.player_error(user.client) || !manager.has_admin() || !isnull(manager.approved_request))

/datum/antag_coin_menu/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || usr.client != client_ref.resolve())
		return
	if(action == "request")
		INVOKE_ASYNC(manager, TYPE_PROC_REF(/datum/antag_coin_manager, request_role), usr.client, params["choice"])
		SStgui.close_uis(src)
		return TRUE
