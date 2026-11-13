/// Non-targeted actions share the parasite as their target, so framework teardown clears them.
/datum/action/innate/cortical_borer
	button_icon = 'modular_bandastation/cortical_borer/icons/actions.dmi'
	button_icon_state = "borer_brain"
	background_icon_state = "bg_alien"
	show_to_observers = FALSE

/// Open the chemical, development and host-control panel.
/datum/action/innate/cortical_borer/menu
	name = "Панель мозгового червя"
	desc = "Связь, химикаты, развитие и управление носителем."

/datum/action/innate/cortical_borer/menu/Activate()
	var/mob/living/basic/cortical_borer/borer = target
	if(owner == borer.controller())
		borer.ui_interact(owner)

/// The original host can communicate without being able to inspect the parasite's UI.
/datum/action/innate/cortical_borer/communicate
	name = "Связаться с паразитом"
	desc = "Послать мысленное сообщение мозговому червю."
	button_icon_state = "alien_whisper"

/datum/action/innate/cortical_borer/communicate/Activate()
	var/mob/living/basic/cortical_borer/borer = target
	borer.communicate(owner)

/// A visible alternative to the Resist verb, available only to the original mind.
/datum/action/innate/cortical_borer/resist
	name = "Сопротивляться паразиту"
	desc = "Вернуть контроль над своим телом."
	button_icon_state = "borer_leave"

/datum/action/innate/cortical_borer/resist/Activate()
	var/mob/living/basic/cortical_borer/borer = target
	if(owner == borer.captive)
		borer.captive.resist()

/// Like alien larvae, stay below furniture; ignore elevation so tables do not lift us onto their tops.
/datum/action/innate/cortical_borer/hide
	name = "Прятаться под мебелью"
	desc = "Прижаться к полу, чтобы ползать под столами и другими предметами. Нажмите снова, чтобы подняться."
	button_icon_state = "borer_hiding_false"
	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED

/datum/action/innate/cortical_borer/hide/IsAvailable(feedback = FALSE)
	var/mob/living/basic/cortical_borer/borer = target
	return ..() && !borer.host && !borer.busy && !HAS_TRAIT(borer, TRAIT_MOVE_VENTCRAWLING) && borer.can_act(owner)

/datum/action/innate/cortical_borer/hide/Activate()
	if(!IsAvailable())
		return
	var/mob/living/basic/cortical_borer/borer = target
	active = TRUE
	borer.layer = ABOVE_NORMAL_TURF_LAYER
	ADD_TRAIT(borer, TRAIT_IGNORE_ELEVATION, REF(src))
	button_icon_state = "borer_hiding_true"
	build_all_button_icons()

/datum/action/innate/cortical_borer/hide/Deactivate()
	var/mob/living/basic/cortical_borer/borer = target
	active = FALSE
	if(borer)
		borer.layer = initial(borer.layer)
		REMOVE_TRAIT(borer, TRAIT_IGNORE_ELEVATION, REF(src))
	button_icon_state = "borer_hiding_false"
	build_all_button_icons()

/datum/action/innate/cortical_borer/hide/Remove(mob/remove_from)
	Deactivate()
	return ..()

/// Targeted abilities outside a host. All effects are revalidated in Activate.
/datum/action/cooldown/mob_cooldown/cortical_borer
	button_icon = 'modular_bandastation/cortical_borer/icons/actions.dmi'
	button_icon_state = "infest"
	background_icon_state = "bg_alien"
	shared_cooldown = NONE

/datum/action/cooldown/mob_cooldown/cortical_borer/IsAvailable(feedback)
	var/mob/living/basic/cortical_borer/borer = target
	return ..() && !borer.host && !borer.busy && !HAS_TRAIT(borer, TRAIT_MOVE_VENTCRAWLING) && borer.can_act(owner)

/// Infect a reachable humanoid after a continuous channel.
/datum/action/cooldown/mob_cooldown/cortical_borer/infest
	name = "Заразить носителя"
	desc = "Проникнуть в голову соседнего живого органического гуманоида."
	cooldown_time = 0

/datum/action/cooldown/mob_cooldown/cortical_borer/infest/Activate(atom/target_atom)
	var/mob/living/basic/cortical_borer/borer = target
	if(!IsAvailable() || !ishuman(target_atom))
		return FALSE
	var/mob/living/carbon/human/victim = target_atom
	if(!borer.can_infest(victim) || !borer.Adjacent(victim) || !victim.IsReachableBy(borer))
		to_chat(owner, span_warning("Этот носитель недоступен или несовместим."))
		return FALSE
	borer.busy = TRUE
	to_chat(owner, span_notice("Вы ищете путь в слуховой проход [victim]..."))
	var/delay = (locate(/datum/cortical_borer_focus/secretion) in borer.focuses) ? 2.5 SECONDS : 5 SECONDS
	var/succeeded = do_after(borer, delay, victim)
	if(QDELETED(src) || QDELETED(borer))
		return FALSE
	borer.busy = FALSE
	if(!succeeded || !IsAvailable() || !borer.Adjacent(victim) || !victim.IsReachableBy(borer) || !borer.can_infest(victim))
		return FALSE
	return borer.enter_host(victim)

/// The source's Weaken corresponds to a knockdown, not a total unconsciousness effect.
/datum/action/cooldown/mob_cooldown/cortical_borer/dominate
	name = "Подавить жертву"
	desc = "Сбить с ног живого гуманоида в трёх клетках. Перезарядка 30 секунд."
	button_icon_state = "genetic_cryo"
	cooldown_time = 30 SECONDS

/datum/action/cooldown/mob_cooldown/cortical_borer/dominate/Activate(atom/target_atom)
	if(!IsAvailable() || !ishuman(target_atom))
		return FALSE
	var/mob/living/basic/cortical_borer/borer = target
	var/mob/living/carbon/human/victim = target_atom
	if(victim.stat == DEAD || victim.get_cortical_borer() || !(victim in view(3, borer)))
		return FALSE
	var/duration = 6 SECONDS
	if(locate(/datum/cortical_borer_focus/sting) in borer.focuses)
		duration += 5 SECONDS
	victim.Knockdown(duration)
	to_chat(victim, span_userdanger("Волна чужого ужаса подкашивает ваши ноги!"))
	log_combat(borer, victim, "dominated as a cortical borer")
	StartCooldown()
	return TRUE
