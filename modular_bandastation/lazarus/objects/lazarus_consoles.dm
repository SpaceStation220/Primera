// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/// Event-only state shared by the quarantine and distress consoles.
GLOBAL_VAR_INIT(lazarus_quarantine, TRUE)
GLOBAL_VAR_INIT(lazarus_distress_sent, FALSE)

/** Indestructible colony consoles; actions are revalidated after confirmation. */
/obj/structure/event_console
	name = "консоль колонии"
	density = TRUE
	anchored = TRUE
	icon = 'icons/obj/machines/computer.dmi'
	icon_state = "computer"
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// Screen and keyboard appearances retained by the converted map.
	var/icon_keyboard = "tech_key"
	var/icon_screen = "comm"

/obj/structure/event_console/Initialize(mapload)
	. = ..()
	set_light(2, 0.9, LIGHT_COLOR_BLUE)
	update_appearance()

/obj/structure/event_console/update_overlays()
	. = ..()
	. += icon_keyboard
	. += icon_screen

/obj/structure/event_console/shuttle_console
	name = "консоль коммуникации"
	desc = "Отправляет администрации сигнал бедствия после снятия карантина."

/obj/structure/event_console/shuttle_console/attack_hand(mob/living/user, list/modifiers)
	if(!ishuman(user) || user.incapacitated || !user.can_interact_with(src))
		return
	if(GLOB.lazarus_quarantine)
		to_chat(user, span_warning("Объект находится на карантине. Вызов помощи невозможен."))
		return
	if(GLOB.lazarus_distress_sent)
		to_chat(user, span_notice("Сигнал бедствия уже отправлен."))
		return
	if(tgui_alert(user, "Отправить необратимый сигнал бедствия?", name, list("Да", "Нет")) != "Да")
		return
	if(QDELETED(src) || QDELETED(user) || user.incapacitated || !user.can_interact_with(src) || GLOB.lazarus_quarantine || GLOB.lazarus_distress_sent)
		return
	GLOB.lazarus_distress_sent = TRUE
	to_chat(user, span_notice("Сигнал бедствия отправлен. Ожидайте ответа спасателей."))
	message_admins("ЛАЗАРЬ: [ADMIN_LOOKUPFLW(user)] отправляет сигнал бедствия из [ADMIN_VERBOSEJMP(src)].")
	log_game("Lazarus distress signal sent by [key_name(user)].")

/obj/structure/event_console/quarantine
	name = "консоль управления карантином"
	desc = "Отключает карантин и разблокирует отправку сигнала бедствия."

/obj/structure/event_console/quarantine/attack_hand(mob/living/user, list/modifiers)
	if(!ishuman(user) || user.incapacitated || !user.can_interact_with(src))
		return
	if(!GLOB.lazarus_quarantine)
		to_chat(user, span_notice("Карантин уже снят."))
		return
	if(tgui_alert(user, "Снять карантин? Это действие нельзя отменить.", name, list("Да", "Нет")) != "Да")
		return
	if(QDELETED(src) || QDELETED(user) || user.incapacitated || !user.can_interact_with(src) || !GLOB.lazarus_quarantine)
		return
	GLOB.lazarus_quarantine = FALSE
	to_chat(user, span_notice("Карантин снят."))
	message_admins("ЛАЗАРЬ: [ADMIN_LOOKUPFLW(user)] снимает карантин в [ADMIN_VERBOSEJMP(src)].")
	log_game("Lazarus quarantine lifted by [key_name(user)].")

/** The original TSF evacuation is dispatched by event administrators. */
/datum/map_template/shuttle/emergency/lazarus
	prefix = "modular_bandastation/lazarus/maps/"
	suffix = "lazarus"
	name = "TSF Escape Shuttle"
	occupancy_limit = 25
	description = "Спасательный шаттл проекта «Лазарь»."
// AI EDIT END
