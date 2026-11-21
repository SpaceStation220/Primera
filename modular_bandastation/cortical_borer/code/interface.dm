/mob/living/basic/cortical_borer
	/// Fixed choices shared by UI data and server effects. Clients cannot select arbitrary reagent paths.
	var/static/list/secretion_options = list(
		"mannitol" = list("name" = "Маннитол", "cost" = 30, "reagent" = /datum/reagent/medicine/mannitol, "desc" = "5 ед.; восстановление мозга. Передозировка от 15 ед."),
		"epinephrine" = list("name" = "Эпинефрин", "cost" = 30, "reagent" = /datum/reagent/medicine/epinephrine, "desc" = "5 ед.; стабилизация критического состояния."),
		"salbutamol" = list("name" = "Сальбутамол", "cost" = 30, "reagent" = /datum/reagent/medicine/salbutamol, "desc" = "5 ед.; лечение кислородного голодания."),
		"spaceacillin" = list("name" = "Спейсациллин", "cost" = 30, "reagent" = /datum/reagent/medicine/spaceacillin, "desc" = "5 ед.; местное противовирусное средство."),
		"salglu" = list("name" = "Физраствор глюкозы", "cost" = 30, "reagent" = /datum/reagent/medicine/salglu_solution, "desc" = "5 ед.; лечение травм, ожогов и восстановление крови."),
		"methamphetamine" = list("name" = "Метамфетамин", "cost" = 50, "reagent" = /datum/reagent/drug/methamphetamine, "desc" = "5 ед.; стимулятор с риском зависимости и передозировки."),
		"insulin" = list("name" = "Инсулин", "cost" = 50, "reagent" = /datum/reagent/medicine/insulin, "desc" = "5 ед.; ускоряет выведение сахара. Нельзя применить, пока сахар уже подавляет борера."),
		"detox" = list("name" = "Очищение: Multiver", "cost" = 30, "reagent" = /datum/reagent/medicine/c2/multiver, "desc" = "5 ед.; местная замена угля. Выводит вещества, но может повреждать лёгкие."),
		"analgesia" = list("name" = "Обезболивание: шахтёрская мазь", "cost" = 30, "reagent" = /datum/reagent/medicine/mine_salve, "desc" = "5 ед.; местная замена гидрокодона. Обезболивает и маскирует повреждения на личном HUD."),
		"organs" = list("name" = "Восстановить органы", "cost" = 30, "desc" = "Местная замена митоколида: восстанавливает 5 урона каждого органического внутреннего органа, кроме мозга."),
		"spin" = list("name" = "Вращение", "cost" = 50, "desc" = "Местная замена крутения: носитель вращается 5 секунд; не оглушает."),
		"feign" = list("name" = "Ложная смерть", "cost" = 30, "desc" = "Местная замена капулеттия: ложная смерть и немота на 20 секунд."),
	)

/mob/living/basic/cortical_borer/ui_state(mob/user)
	return GLOB.always_state

/mob/living/basic/cortical_borer/ui_status(mob/user, datum/ui_state/state)
	if(user != controller() || !borer_mind?.has_antag_datum(/datum/antagonist/cortical_borer))
		return UI_CLOSE
	return user.stat == STABLE && !IS_UNCONSCIOUS(user) && stat != DEAD ? UI_INTERACTIVE : UI_UPDATE

/mob/living/basic/cortical_borer/ui_interact(mob/user, datum/tgui/ui)
	if(ui_status(user) != UI_INTERACTIVE)
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "CorticalBorer", "Мозговой червь")
		ui.open()

/mob/living/basic/cortical_borer/ui_data(mob/user)
	var/list/chemical_data = list()
	for(var/id in secretion_options)
		var/list/option = secretion_options[id]
		chemical_data += list(list("id" = id, "name" = option["name"], "desc" = option["desc"], "cost" = option["cost"]))
	var/list/focus_data = list()
	for(var/datum/cortical_borer_focus/focus_type as anything in subtypesof(/datum/cortical_borer_focus))
		focus_data += list(list("id" = initial(focus_type.id), "name" = initial(focus_type.name), "desc" = initial(focus_type.desc), "cost" = initial(focus_type.cost), "learned" = !!(locate(focus_type) in focuses)))
	return list(
		"chemicals" = round(chemicals, 0.1),
		"capacity" = max_chemicals,
		"host" = host?.real_name,
		"generation" = generation,
		"rank" = list("Молодой", "Зрелый", "Взрослый", "Старейшина")[rank],
		"points" = evolution_points,
		"reproductions" = reproductions,
		"reproduction_cost" = reproduction_cost(),
		"torment_cost" = torment_cost(),
		"torment_ready" = COOLDOWN_FINISHED(src, torment_cooldown),
		"controlling" = controlling,
		"docile" = !!is_docile(),
		"busy" = busy,
		"sneaking" = sneaking,
		"can_act" = can_act(user),
		"can_control" = can_control(),
		"cult_host" = !!host?.mind?.has_antag_datum(/datum/antagonist/cult),
		"chemistry_ready" = COOLDOWN_FINISHED(src, secretion_cooldown),
		"chemistry" = chemical_data,
		"focuses" = focus_data,
	)

/mob/living/basic/cortical_borer/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || ui.user != controller() || !can_act(ui.user))
		return TRUE
	switch(action)
		if("talk", "hive")
			INVOKE_ASYNC(src, PROC_REF(communicate), ui.user, null, action == "hive")
		if("control")
			INVOKE_ASYNC(src, PROC_REF(begin_control), ui.user)
		if("release")
			release_control()
		if("leave")
			INVOKE_ASYNC(src, PROC_REF(begin_leave), ui.user)
		if("reproduce")
			reproduce(ui.user)
		if("torment")
			torment(ui.user)
		if("speech")
			INVOKE_ASYNC(src, PROC_REF(force_host_speech), ui.user)
		if("scan")
			if(host && can_act(ui.user))
				healthscan(ui.user, host, scanpower = SCANPOWER_ADVANCED)
		if("sneak")
			if(controlling && can_act(ui.user, require_host = TRUE) && (!host_mind?.active || sneaking))
				if(sneaking)
					sneaking = FALSE
				else if(chemicals >= 50)
					chemicals -= 50
					sneaking = TRUE
				host.med_hud_set_status()
		if("secrete")
			secrete(ui.user, params["id"])
		if("learn")
			learn_focus(ui.user, params["id"])
		else
			return FALSE
	return TRUE

/// Whitelisted, atomic resource spending. The UI never controls a typepath, dose or price.
/mob/living/basic/cortical_borer/proc/secrete(mob/user, option_id)
	if(!can_act(user, require_host = TRUE, allow_control = FALSE) || !istext(option_id) || !COOLDOWN_FINISHED(src, secretion_cooldown))
		return FALSE
	var/list/option = secretion_options[option_id]
	if(!option || chemicals < option["cost"] || !host.reagents)
		return FALSE
	if(option["reagent"] && host.reagents.total_volume + 5 > host.reagents.maximum_volume)
		return FALSE
	chemicals -= option["cost"]
	COOLDOWN_START(src, secretion_cooldown, 1 SECONDS)
	if(option["reagent"])
		host.reagents.add_reagent(option["reagent"], 5)
	else
		switch(option_id)
			if("organs")
				for(var/obj/item/organ/organ as anything in host.organs)
					if((organ.organ_flags & ORGAN_ORGANIC) && !(organ.organ_flags & ORGAN_EXTERNAL) && organ.slot != ORGAN_SLOT_BRAIN)
						organ.apply_organ_damage(-5)
			if("spin")
				host.SpinAnimation(speed = 10, loops = 5)
			if("feign")
				host.apply_status_effect(/datum/status_effect/cortical_borer_feign)
	to_chat(user, span_notice("Применено: [option["name"]]."))
	log_combat(src, host, "secreted [option["name"]] as a cortical borer")
	return TRUE

/// Timed local equivalent of the source's false death; no parasite reference survives on the host.
/datum/status_effect/cortical_borer_feign
	id = "cortical_borer_feign"
	duration = 20 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null

/datum/status_effect/cortical_borer_feign/on_apply()
	owner.fakedeath(type)
	ADD_TRAIT(owner, TRAIT_MUTE, type)
	return TRUE

/datum/status_effect/cortical_borer_feign/on_remove()
	owner.cure_fakedeath(type)
	REMOVE_TRAIT(owner, TRAIT_MUTE, type)
