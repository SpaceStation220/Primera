/proc/is_humanity_quirk(quirk_type)
	var/static/list/allowed_quirks = list(
		/datum/quirk/unstable = TRUE,
		/datum/quirk/clumsy = TRUE,
		/datum/quirk/cursed = TRUE,
		/datum/quirk/illiterate = TRUE,
		/datum/quirk/nonviolent = TRUE,
		/datum/quirk/pushover = TRUE,
		/datum/quirk/claustrophobia = TRUE,
		/datum/quirk/prosopagnosia = TRUE,
		/datum/quirk/poor_aim = TRUE,
		/datum/quirk/depression = TRUE,
		/datum/quirk/erratic = TRUE,
		/datum/quirk/monophobia = TRUE,
		/datum/quirk/nyctophobia = TRUE,
		/datum/quirk/pyrophobia = TRUE,
		/datum/quirk/social_anxiety = TRUE,
		/datum/quirk/csl = TRUE,
		/datum/quirk/item_quirk/family_heirloom = TRUE,
		/datum/quirk/hypersensitive = TRUE,
		/datum/quirk/indebted = TRUE,
		/datum/quirk/softspoken = TRUE,
		/datum/quirk/foreigner = TRUE,
		/datum/quirk/evil = TRUE,
		/datum/quirk/gamer = TRUE,
		/datum/quirk/heterochromatic = TRUE,
		/datum/quirk/phobia = TRUE,
		/datum/quirk/item_quirk/photographer = TRUE,
		/datum/quirk/shifty_eyes = TRUE,
		/datum/quirk/death_dnr_poll = TRUE,
		/datum/quirk/friendly = TRUE,
		/datum/quirk/item_quirk/mime_fan = TRUE,
		/datum/quirk/item_quirk/musician = TRUE,
		/datum/quirk/bilingual = TRUE,
		/datum/quirk/jolly = TRUE,
		/datum/quirk/item_quirk/poster_boy = TRUE,
		/datum/quirk/item_quirk/signer = TRUE,
		/datum/quirk/item_quirk/tagger = TRUE,
		/datum/quirk/throwingarm = TRUE,
		/datum/quirk/pyromania = TRUE,
		/datum/quirk/empath = TRUE,
		/datum/quirk/freerunning = TRUE,
		/datum/quirk/selfaware = TRUE,
		/datum/quirk/skittish = TRUE,
		/datum/quirk/death_mimicry = TRUE,
	)
	return !!allowed_quirks[quirk_type]

/datum/preferences/proc/can_select_generation_quirk(datum/quirk/quirk, species_path, generation_override)
	if(!quirk)
		return FALSE
	if(species_path == /datum/species/ipc)
		return is_humanity_quirk(quirk.type) && (generation_override || read_preference(/datum/preference/choiced/ipc/generation)) == "III"
	return quirk.is_species_appropriate(species_path)

/datum/preference/text/humanity
	abstract_type = /datum/preference/text/humanity
	savefile_identifier = PREFERENCE_CHARACTER
	category = "humanity"
	can_randomize = FALSE
	should_update_preview = FALSE
	maximum_value_length = 400
	var/record_label

/datum/preference/text/humanity/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	// Only the generation preference may initialize an engram.

/datum/preference/text/humanity/deserialize(input, datum/preferences/preferences)
	return istext(input) ? copytext_char(input, 1, maximum_value_length + 1) : ""

/datum/preference/text/humanity/is_valid(value, datum/preferences/preferences)
	return istext(value) && length_char(value) <= maximum_value_length

/datum/preference/text/humanity/identity
	savefile_key = "humanity_identity"
	record_label = "Кем вы были до оцифровки?"

/datum/preference/text/humanity/memory
	savefile_key = "humanity_memory"
	record_label = "Воспоминание, которое вы боитесь потерять"

/datum/preference/text/humanity/fear
	savefile_key = "humanity_fear"
	record_label = "Что пугает вас в новом существовании?"

/datum/preference/text/humanity/habit
	savefile_key = "humanity_habit"
	record_label = "Привычка"
	maximum_value_length = 180

/datum/preference/text/humanity/keepsake
	savefile_key = "humanity_keepsake"
	record_label = "Значение фотографии"
	maximum_value_length = 180

/datum/preference/choiced/humanity_anchor
	savefile_key = "humanity_anchor"
	savefile_identifier = PREFERENCE_CHARACTER
	category = "humanity"
	can_randomize = FALSE
	should_update_preview = FALSE

/datum/preference/choiced/humanity_anchor/init_possible_values()
	return list("reflection", "social", "habit", "keepsake")

/datum/preference/choiced/humanity_anchor/create_default_value()
	return "reflection"

/datum/preference/choiced/humanity_anchor/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return

/datum/preferences/proc/humanity_profile()
	var/anchor = read_preference(/datum/preference/choiced/humanity_anchor)
	var/list/fields = list()
	for(var/path in subtypesof(/datum/preference/text/humanity))
		var/datum/preference/text/humanity/field = GLOB.preference_entries[path]
		if((path == /datum/preference/text/humanity/habit && anchor != "habit") || (path == /datum/preference/text/humanity/keepsake && anchor != "keepsake"))
			continue
		fields += list(list("key" = field.savefile_key, "label" = field.record_label, "value" = read_preference(path), "limit" = field.maximum_value_length))
	return list("anchor" = anchor, "fields" = fields)

/datum/preference_middleware/humanity/get_ui_data(mob/user)
	if(preferences.current_window == PREFERENCE_TAB_CHARACTER_PREFERENCES && preferences.read_preference(/datum/preference/choiced/species) == /datum/species/ipc && preferences.read_preference(/datum/preference/choiced/ipc/generation) == "III")
		return list("humanity_profile" = preferences.humanity_profile())
	return list()

/datum/ipc_os_program/humanity/proc/configure(datum/preferences/preferences)
	if(!preferences)
		return
	var/list/profile = preferences.humanity_profile()
	anchor = profile["anchor"]
	habit_emote = trim(preferences.read_preference(/datum/preference/text/humanity/habit))
	keepsake_description = trim(preferences.read_preference(/datum/preference/text/humanity/keepsake))
	records.Cut()
	for(var/list/field as anything in profile["fields"])
		if(length(trim(field["value"])))
			records[field["label"]] = field["value"]
