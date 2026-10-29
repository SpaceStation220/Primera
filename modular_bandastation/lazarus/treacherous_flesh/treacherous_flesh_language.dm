// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/** A private language whose radio-like transmission is handled by Lazarus mobs. */
/datum/language/treacherous_flesh
	name = "Разум Улья Биоморфов"
	desc = "Биоморфы общаются на больших расстояниях посредством радиоволн."
	key = "~"
	flags = LANGUAGE_TONGUELESS_SPEECH
	default_priority = 100
	icon_state = "wormspeak"
	syllables = list("а", "шш", "кха", "рр")

/datum/language_holder/treacherous_flesh
	understood_languages = list(/datum/language/treacherous_flesh = list(LANGUAGE_ATOM))
	spoken_languages = list(/datum/language/treacherous_flesh = list(LANGUAGE_ATOM))

/** Broadcasts only to this faction and observers; player text remains escaped. */
/proc/lazarus_hivemind(mob/living/speaker, message)
	message = trim(copytext_char(sanitize(message), 1, MAX_MESSAGE_LEN))
	if(!length(message) || speaker.stat == DEAD || speaker.client?.handle_spam_prevention(message, MUTE_IC))
		return
	var/rendered = span_purple("<b>Разум Улья — [speaker.name]:</b> [message]")
	for(var/mob/listener as anything in (GLOB.lazarus_flesh | GLOB.lazarus_biomorphs | GLOB.dead_mob_list))
		to_chat(listener, rendered)
	speaker.log_talk(message, LOG_SAY, tag = "Lazarus hivemind")
// AI EDIT END
