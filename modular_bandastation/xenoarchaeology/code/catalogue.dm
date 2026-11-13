GLOBAL_LIST_EMPTY(xenoarch_catalogue)
GLOBAL_VAR_INIT(xenoarch_catalogue_next_id, 0)

/** Метка не зависит от typepath: изготовленный идол и выкопанный идол должны различаться. */
/datum/component/xenoarch_catalogue_identity
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Уникальный в раунде номер, не основанный на переиспользуемом REF.
	var/catalogue_id
	/// Только выдача из валуна задаёт геологическое происхождение для награды.
	var/excavation_id
	/// Возраст из исходного керна, не ссылка на валун.
	var/artifact_age

/datum/component/xenoarch_catalogue_identity/Initialize(excavation_id, artifact_age)
	if(!isobj(parent))
		return COMPONENT_INCOMPATIBLE
	catalogue_id = "КСА-[++GLOB.xenoarch_catalogue_next_id]"
	src.excavation_id = excavation_id
	src.artifact_age = artifact_age

/datum/component/xenoarch_catalogue_identity/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_EXAMINE, PROC_REF(on_examine))

/datum/component/xenoarch_catalogue_identity/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_ATOM_EXAMINE)

/datum/component/xenoarch_catalogue_identity/proc/on_examine(atom/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	examine_list += span_notice("Каталожная метка: [catalogue_id].")

/** Журнал владеет снимком, а не артефактом, эффектом или игроком; запись переживает их удаление. */
/datum/xenoarch_catalogue_entry
	/// Совпадает с меткой объекта и остаётся в журнале после удаления компонента.
	var/id
	/// Имя объекта при первом успешном анализе.
	var/artifact_name
	/// Редактируемое название, не меняющее идентичность находки.
	var/title
	/// Неизменяемый результат первого успешного анализа.
	var/report
	/// Время первого успешного анализа внутри раунда.
	var/analyzed_at
	/// Геологическое происхождение из серверной метки, отсутствует у изготовленных объектов.
	var/excavation_id
	/// Возраст из исходного валуна; у изготовленных объектов отсутствует.
	var/artifact_age
	/// Ручной текст не интерпретируется как HTML.
	var/notes = ""
	/// Версия редактируемых полей защищает от тихой перезаписи другим исследователем.
	var/revision = 0
	/// Последний автор наблюдений, строка без ссылки на mob или mind.
	var/edited_by
	/// Первая подпись регистрации, строка без ссылки на mob или mind.
	var/registered_by
	/// Время первой регистрации внутри раунда.
	var/registered_at
	/// Списание права на награду общее для всех станков и не зависит от экземпляров бумаги.
	var/reward_claimed = FALSE

/datum/xenoarch_catalogue_entry/New(obj/target, datum/component/xenoarch_catalogue_identity/identity, analysis_report)
	. = ..()
	id = identity.catalogue_id
	artifact_name = target.declent_ru(NOMINATIVE)
	title = artifact_name
	report = analysis_report
	analyzed_at = round_timestamp()
	excavation_id = identity.excavation_id
	artifact_age = identity.artifact_age

/** Передаёт UI снимок без ссылок на исходную находку и её эффекты. */
/datum/xenoarch_catalogue_entry/proc/get_data()
	return list(
		"id" = id,
		"artifactName" = artifact_name,
		"title" = title,
		"report" = report,
		"analyzedAt" = analyzed_at,
		"excavationId" = excavation_id,
		"age" = artifact_age,
		"notes" = notes,
		"revision" = revision,
		"editedBy" = edited_by,
		"registeredBy" = registered_by,
		"registeredAt" = registered_at,
		"rewardClaimed" = reward_claimed,
	)

/obj/machinery/xenoarch_lab
	/// Номер последнего завершённого паспорта для ссылки в бумажном отчёте.
	var/catalogue_id

/** Вызывается только после завершения штатного анализа; повторное измерение не создаёт новую запись. */
/obj/machinery/xenoarch_lab/proc/catalogue_analysis(obj/target)
	var/datum/component/xenoarch_catalogue_identity/identity = target.LoadComponent(/datum/component/xenoarch_catalogue_identity)
	catalogue_id = identity.catalogue_id
	if(!GLOB.xenoarch_catalogue[catalogue_id])
		GLOB.xenoarch_catalogue[catalogue_id] = new /datum/xenoarch_catalogue_entry(target, identity, report)

/obj/machinery/xenoarch/researcher
	COOLDOWN_DECLARE(catalogue_print_cooldown)

/** Регистрация не пропадает из-за полной ёмкости: очки можно получить позднее на другом станке. */
/obj/machinery/xenoarch/researcher/proc/claim_catalogue_reward(datum/xenoarch_catalogue_entry/entry)
	if(!is_operational || !anchored || panel_open || QDELETED(entry) || GLOB.xenoarch_catalogue[entry.id] != entry)
		return FALSE
	if(!entry.registered_by || !entry.excavation_id || entry.reward_claimed || research + XENOARCH_CATALOGUE_REWARD > max_research)
		return FALSE
	entry.reward_claimed = TRUE
	research += XENOARCH_CATALOGUE_REWARD
	return TRUE

/** Все изменения журнала проходят одну серверную границу; паспорт и происхождение не берутся из UI. */
/obj/machinery/xenoarch/researcher/proc/handle_catalogue_action(action, list/params, mob/user)
	if(!is_operational || !anchored || panel_open || !user.can_perform_action(src, NEED_DEXTERITY|NEED_HANDS|ALLOW_SILICON_REACH))
		return FALSE
	if(!istext(params["id"]))
		return FALSE
	var/datum/xenoarch_catalogue_entry/entry = GLOB.xenoarch_catalogue[params["id"]]
	if(QDELETED(entry))
		return FALSE
	switch(action)
		if("catalogue_save")
			var/new_title = params["title"]
			var/new_notes = params["notes"]
			if(!isnum(params["revision"]) || params["revision"] != entry.revision)
				balloon_alert(user, "запись изменена другим автором!")
				return FALSE
			if(!istext(new_title) || !istext(new_notes) || length_char(new_title) > XENOARCH_CATALOGUE_TITLE_LIMIT || length_char(new_notes) > XENOARCH_CATALOGUE_NOTES_LIMIT)
				return FALSE
			new_title = trim(replacetext(replacetext(new_title, "\n", " "), ascii2text(13), " "))
			if(!length(new_title))
				return FALSE
			entry.title = new_title
			entry.notes = new_notes
			entry.edited_by = user.real_name
			entry.revision++
			return TRUE
		if("catalogue_register")
			if(entry.registered_by)
				return FALSE
			entry.registered_by = user.real_name
			entry.registered_at = round_timestamp()
			claim_catalogue_reward(entry)
			return TRUE
		if("catalogue_claim")
			return claim_catalogue_reward(entry)
		if("catalogue_print")
			if(!COOLDOWN_FINISHED(src, catalogue_print_cooldown))
				return FALSE
			COOLDOWN_START(src, catalogue_print_cooldown, 3 SECONDS)
			var/obj/item/paper/xenoarch_report/paper = new(drop_location())
			paper.add_raw_text(html_encode("Паспорт [entry.id]\nНазвание: [entry.title]\nАнализ: [entry.analyzed_at]\n\n[entry.report]\n\nНаблюдения:\n[entry.notes]\nАвтор наблюдений: [entry.edited_by || "не указан"]\nРегистрация: [entry.registered_by || "не зарегистрирован"] [entry.registered_at]\n"))
			playsound(src, 'sound/machines/printer.ogg', 25, FALSE)
			return TRUE
	return FALSE
