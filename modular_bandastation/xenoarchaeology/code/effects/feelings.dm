#define ARTIFACT_BAD_MESSAGES_MINOR list("Вам тревожно.", "Что-то здесь не так.", "Вас охватывает дурное предчувствие.")

#define ARTIFACT_BAD_MESSAGES_MAJOR list("Нужно бежать отсюда!", "Кто-то пытается вас убить!", "Помогите!")

#define ARTIFACT_GOOD_MESSAGES_MINOR list("Вам хорошо.", "Всё идёт как надо.", "Все цвета стали ярче.")

#define ARTIFACT_GOOD_MESSAGES_MAJOR list("Хочется обнять каждого встречного!", "Вы чувствуете эйфорию.", "Мир словно помогает вам.")

/datum/xenoartifact_effect/feelings
	type_name = XENO_EFFECT_PSIONIC
	/// List of major messages for mood events
	var/list/drastic_message_list
	/// List of minor messages for mood events
	var/list/normal_message_list

/datum/xenoartifact_effect/feelings/do_effect_touch(mob/user)
	. = ..()
	if(!.)
		return
	if(!ishuman(user))
		return
	var/mob/living/carbon/human/human_mob = user
	run_send_messages(human_mob, 50, 80)
	human_mob.adjust_dizzy_up_to(3 SECONDS, 15 SECONDS)

/datum/xenoartifact_effect/feelings/do_effect_aura(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/carbon/human/human_mob in range(range, curr_turf))
		run_send_messages(human_mob, 2.5, 5, seconds_per_tick)
		human_mob.adjust_dizzy_up_to(1.5 SECONDS * seconds_per_tick, 15 SECONDS)

/datum/xenoartifact_effect/feelings/do_effect_pulse(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/carbon/human/human_mob in range(range, curr_turf))
		run_send_messages(human_mob, 80, 100)
		human_mob.adjust_dizzy_up_to(3 SECONDS, 10 SECONDS)
		if(prob(25))
			human_mob.adjust_dizzy_up_to(5 SECONDS, 30 SECONDS)

/datum/xenoartifact_effect/feelings/do_effect_destroy()
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/carbon/human/human_mob in range(7, curr_turf))
		run_send_messages(human_mob, 100, 0)
		human_mob.adjust_dizzy(30 SECONDS)

/**
 * Randomly selects between major and minor mood and applies it to the mob
 *
 * Arguments:
 * * receiver - who will receive mood event
 * * drastic_message_chance - chance to receive major mood event
 * * normal_message_chance - chance to receive minor mood event
 */
/datum/xenoartifact_effect/feelings/proc/run_send_messages(mob/receiver, drastic_message_chance = 0, normal_message_chance = 0, seconds_per_tick = 1)
	if(SPT_PROB(drastic_message_chance, seconds_per_tick))
		send_drastic_message(receiver)
		return
	if(SPT_PROB(normal_message_chance, seconds_per_tick))
		send_minor_message(receiver)

/// Send major mood event
/datum/xenoartifact_effect/feelings/proc/send_drastic_message(mob/receiver)

/// Send minor mood event
/datum/xenoartifact_effect/feelings/proc/send_minor_message(mob/receiver)

/datum/xenoartifact_effect/feelings/bad
	log_name = "Тревога"
	drastic_message_list = ARTIFACT_BAD_MESSAGES_MAJOR
	normal_message_list = ARTIFACT_BAD_MESSAGES_MINOR

/datum/xenoartifact_effect/feelings/bad/send_drastic_message(mob/receiver)
	to_chat(receiver, "<font color='red' size='[num2text(rand(3, 5))]'><b>[pick(drastic_message_list)]</b></font>")
	var/mob/living/living_target = receiver
	living_target.add_mood_event("drastic_effect_bad", /datum/mood_event/artifact_effect_bad_major)

/datum/xenoartifact_effect/feelings/bad/send_minor_message(mob/receiver)
	to_chat(receiver, "<font color='red'>[pick(normal_message_list)]</font>")
	var/mob/living/living_target = receiver
	living_target.add_mood_event("minor_effect_bad", /datum/mood_event/artifact_effect_bad_minor)

/datum/xenoartifact_effect/feelings/good
	log_name = "Эйфория"
	drastic_message_list = ARTIFACT_GOOD_MESSAGES_MAJOR
	normal_message_list = ARTIFACT_GOOD_MESSAGES_MINOR

/datum/xenoartifact_effect/feelings/good/send_drastic_message(mob/receiver)
	to_chat(receiver, "<font color='blue' size='[num2text(rand(1,5))]'><b>[pick(drastic_message_list)]</b></font>")
	var/mob/living/living_target = receiver
	living_target.add_mood_event("drastic_effect_good",/datum/mood_event/artifact_effect_good_major)

/datum/xenoartifact_effect/feelings/good/send_minor_message(mob/receiver)
	to_chat(receiver, "<font color='blue'>[pick(normal_message_list)]</font>")
	var/mob/living/living_target = receiver
	living_target.add_mood_event("minor_effect_good", /datum/mood_event/artifact_effect_good_minor)

/datum/mood_event/artifact_effect_good_major
	description = span_nicegreen("Ух! Что происходит?")
	mood_change = 10
	timeout = 10 MINUTES

/datum/mood_event/artifact_effect_good_minor
	description = span_nicegreen("Мне странно, но очень спокойно...")
	mood_change = 5
	timeout = 5 MINUTES

/datum/mood_event/artifact_effect_bad_major
	description = span_warning("Словно стая гусей клюёт мой череп...")
	mood_change = -10
	timeout = 10 MINUTES

/datum/mood_event/artifact_effect_bad_minor
	description = span_warning("Мне странно и тревожно...")
	mood_change = -5
	timeout = 5 MINUTES

#undef ARTIFACT_BAD_MESSAGES_MINOR
#undef ARTIFACT_BAD_MESSAGES_MAJOR
#undef ARTIFACT_GOOD_MESSAGES_MINOR
#undef ARTIFACT_GOOD_MESSAGES_MAJOR
