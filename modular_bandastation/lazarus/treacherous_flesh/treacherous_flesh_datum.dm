// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/datum/job/treacherous_flesh
	title = "Treacherous Flesh"
	tgui_icon = FA_ICON_BUG

/** The parasite's identity follows its mind through control, escape and ascension. */
/datum/antagonist/treacherous_flesh
	name = "Коварная плоть"
	roundend_category = "Биоморфы Лазаря"
	antagpanel_category = ANTAG_GROUP_ABOMINATIONS
	pref_flag = ROLE_SENTIENCE
	ui_name = "AntagInfoGeneric"
	show_name_in_check_antagonists = TRUE
	show_to_ghosts = TRUE

/datum/antagonist/treacherous_flesh/on_gain()
	if(!length(objectives))
		var/datum/objective/treacherous_flesh/objective = new()
		objective.owner = owner
		objectives += objective
	return ..()

/datum/antagonist/treacherous_flesh/greet()
	. = ..()
	to_chat(owner.current, span_boldnotice("Вы — коварная плоть. Развивайтесь внутри носителя, распространяйте заражённые ткани и ассимилируйте колонию."))
	to_chat(owner.current, span_notice("В начале носитель не знает о вас. Контакт открывает телепатию. Поздние стадии позволяют захватить тело, поработить разум и вознестись в высшего биоморфа. Врачи могут обнаружить и извлечь вас."))
	owner.announce_objectives()

/datum/antagonist/treacherous_flesh/admin_add(datum/mind/new_owner, mob/admin)
	if(!admin?.client || !check_rights_for(admin.client, R_ADMIN))
		return
	if(ishuman(new_owner.current))
		var/mob/living/carbon/human/host = new_owner.current
		if(host.stat == DEAD || !(host.mob_biotypes & MOB_ORGANIC) || lazarus_host_infested(host))
			to_chat(admin, span_warning("Этот носитель не подходит или уже заражён."))
			return
		var/obj/effect/mob_spawn/ghost_role/treacherous_flesh/egg = new(host, host)
		notify_ghosts("Зародыш коварной плоти появился внутри организма [host].", source = egg, click_interact = TRUE)
		message_admins("[key_name_admin(admin)] заразил [ADMIN_LOOKUPFLW(host)] зародышем коварной плоти.")
		return
	if(!istype(new_owner.current, /mob/living/treacherous_flesh) && !istype(new_owner.current, /mob/living/basic/flesh_biomorph))
		to_chat(admin, span_warning("Заразите носителя клетками коварной плоти или создайте внутри него зародыш для роли призрака."))
		return
	return ..()

/datum/objective/treacherous_flesh
	name = "Ассимиляция"
	explanation_text = "Размножайтесь, ассимилируйте колонию и помогите молодым биоморфам развиться."
	no_failure = TRUE

/** A separate datum lets removal release only this parasite's enthrallment. */
/datum/antagonist/lazarus_host
	name = "Порабощённый носитель"
	roundend_category = "Носители Лазаря"
	antagpanel_category = ANTAG_GROUP_ABOMINATIONS
	ui_name = "AntagInfoGeneric"
	show_name_in_check_antagonists = TRUE

/datum/antagonist/lazarus_host/on_gain()
	var/datum/objective/objective = new()
	objective.owner = owner
	objective.explanation_text = "Подчиняйтесь голосу паразита и помогайте биоморфам распространять плоть."
	objective.completed = TRUE
	objectives += objective
	return ..()

/datum/antagonist/lazarus_host/greet()
	. = ..()
	to_chat(owner.current, span_userdanger("Голос внутри вас — ваш господин. Вы должны исполнять его приказы и помогать Великой Матери."))
	owner.announce_objectives()
// AI EDIT END
