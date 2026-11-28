/// Administration grants this role explicitly; reproduction offers new independent minds to ghosts.
/datum/antagonist/cortical_borer
	name = "Мозговой червь"
	roundend_category = "Мозговые черви"
	antagpanel_category = "Extra"
	jobban_flag = ROLE_TRAITOR
	show_to_ghosts = FALSE
	ui_name = null
	/// A role can move between bodies without losing its original parasite.
	var/datum/weakref/borer_ref

/datum/antagonist/cortical_borer/can_be_owned(datum/mind/new_owner)
	return ..() && istype(new_owner.current, /mob/living/basic/cortical_borer)

/datum/antagonist/cortical_borer/on_gain()
	var/mob/living/basic/cortical_borer/borer = owner.current
	borer_ref = WEAKREF(borer)
	borer.borer_mind = owner
	ADD_TRAIT(owner, TRAIT_UNCONVERTABLE, REF(src))
	if(borer.menu_action.owner != borer)
		borer.menu_action.Grant(borer)
	if(!borer.host)
		if(borer.infest_action.owner != borer)
			borer.infest_action.Grant(borer)
		if(borer.dominate_action.owner != borer)
			borer.dominate_action.Grant(borer)
		if(borer.hide_action.owner != borer)
			borer.hide_action.Grant(borer)
	borer.update_mob_action_buttons(UPDATE_BUTTON_STATUS)
	return ..()

/datum/antagonist/cortical_borer/greet()
	to_chat(owner.current, span_boldnotice("Вы — мозговой червь! Найдите живого носителя, общайтесь с ним, поддерживайте его жизнь и выращивайте потомство."))
	to_chat(owner.current, span_notice("Откройте панель борера. Сахар подавляет ваши способности. Носитель может сопротивляться контролю, а хирург — извлечь вас. Mindshield не защищает от контроля."))

/datum/antagonist/cortical_borer/on_removal()
	REMOVE_TRAIT(owner, TRAIT_UNCONVERTABLE, REF(src))
	var/mob/living/basic/cortical_borer/borer = borer_ref?.resolve()
	if(borer)
		borer.leave_host()
		borer.menu_action.Remove(borer)
		borer.infest_action.Remove(borer)
		borer.dominate_action.Remove(borer)
		borer.hide_action.Remove(borer)
	return ..()

/datum/antagonist/cortical_borer/Destroy()
	borer_ref = null
	return ..()
