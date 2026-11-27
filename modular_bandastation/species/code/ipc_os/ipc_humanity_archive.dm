/datum/ipc_os_program/humanity/ui_host(mob/user)
	return body

/datum/ipc_os_program/humanity/ui_state(mob/user)
	return GLOB.conscious_state

/datum/ipc_os_program/humanity/ui_status(mob/user, datum/ui_state/state)
	return available() && user == body && os.can_view(user) ? UI_INTERACTIVE : UI_CLOSE

/datum/ipc_os_program/humanity/ui_interact(mob/user, datum/tgui/ui)
	if(ui_status(user) != UI_INTERACTIVE)
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "HumanityArchive", name)
		if(ui.open())
			play_archive_sound()

/// Never send the concealed text to the rendering client. Whole words preserve Unicode clusters.
/datum/ipc_os_program/humanity/proc/read_record(label)
	var/original = records[label]
	if(!original || stage < 3)
		return original
	var/list/words = splittext(original, " ")
	var/offset = hex2num(copytext(md5(label), 1, 3)) % 5
	var/list/fragments = list()
	var/hidden = FALSE
	for(var/index in 1 to length(words))
		var/conceal = ((index + offset) % 5) < (stage == 3 ? 2 : 4)
		if(length(words) > 1 && index == 1)
			conceal = FALSE
		if(length(words) > 1 && index == length(words))
			conceal = TRUE
		if(conceal)
			if(!hidden)
				fragments += (stage == 3 ? "〔утрачена ассоциация〕" : "〔фрагмент недоступен〕")
		else
			fragments += words[index]
		hidden = conceal
	return jointext(fragments, " ")

/datum/ipc_os_program/humanity/ui_data(mob/user)
	if(ui_status(user) != UI_INTERACTIVE)
		return list()
	var/static/list/portraits = list()
	var/portrait_key = "[stage]"
	if(!portraits[portrait_key])
		portraits[portrait_key] = icon2base64(icon('modular_bandastation/species/icons/hud/humanity.dmi', "stage[stage]-rest"))
	var/list/visible_records = list()
	for(var/label in records)
		visible_records += list(list("label" = label, "text" = read_record(label)))
	var/obj/item/photo/token = keepsake?.resolve()
	var/obj/item/held_item = body.get_active_held_item()
	return list(
		"stage" = stage,
		"portrait" = portraits[portrait_key],
		"records" = visible_records,
		"anchor" = anchor,
		"keepsake" = token?.name,
		"held" = token && body.contains(token),
		"can_bind" = os.can_use(user) && anchor == "keepsake" && !anchoring && held_item != token && suitable_keepsake(held_item),
		"ready" = os.can_use(user) && !anchoring && world.time >= next_anchor,
	)

/datum/ipc_os_program/humanity/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || ui_status(ui.user) != UI_INTERACTIVE)
		return
	switch(action)
		if("bind")
			if(!os.can_use(ui.user) || anchor != "keepsake" || anchoring)
				return FALSE
			var/obj/item/item = body.get_active_held_item()
			if(item == keepsake?.resolve() || !suitable_keepsake(item))
				return FALSE
			keepsake = WEAKREF(item)
			return TRUE
		if("anchor")
			INVOKE_ASYNC(src, PROC_REF(use_anchor), ui.user, params["kind"])
			return TRUE
	return FALSE

/datum/ipc_os_program/humanity/proc/give_starting_photo(mob/living/carbon/human/spawned)
	if(starting_photo_given || anchor != "keepsake" || body != spawned || !available() || QDELETED(spawned))
		return
	var/turf/drop_at = get_turf(spawned)
	if(!drop_at)
		return
	starting_photo_given = TRUE
	var/icon/portrait = getFlatIcon(spawned.appearance, defdir = SOUTH, no_anim = TRUE)
	var/icon/print = icon(portrait)
	print.DrawBox("#43565f", 1, 1, print.Width(), print.Height())
	print.Blend(portrait, ICON_OVERLAY)
	var/datum/picture/picture = new(
		name = "памятная фотография",
		desc = html_encode(keepsake_description || "Портрет, который помогает владельцу собраться с мыслями."),
		image = print,
		size_x = print.Width(),
		size_y = print.Height(),
	)
	var/obj/item/photo/humanity_keepsake/photo = new(drop_at, picture)
	keepsake = WEAKREF(photo)
	var/static/list/photo_slots = list(LOCATION_BACKPACK, LOCATION_LPOCKET, LOCATION_RPOCKET, LOCATION_HANDS)
	spawned.equip_in_one_of_slots(photo, photo_slots, qdel_on_fail = FALSE, indirect_action = TRUE)

/obj/item/photo/humanity_keepsake
	show_picture = FALSE

/datum/ipc_os_program/humanity/proc/suitable_keepsake(obj/item/photo/item)
	return istype(item) && !QDELETED(item) && !!item.picture?.picture_image

/datum/ipc_os_program/humanity/proc/anchor_valid(mob/living/carbon/human/user, kind, token)
	return action_token == token && user == body && available() && os.can_use(user) && (kind != "keepsake" || body.contains(keepsake?.resolve()))

/datum/ipc_os_program/humanity/proc/use_anchor(mob/living/carbon/human/user, kind)
	if(anchoring || world.time < next_anchor || !(kind in list("reflection", "habit", "keepsake")) || (kind != "reflection" && kind != anchor))
		return
	var/token = ++action_token
	if(!anchor_valid(user, kind, token))
		return
	anchoring = TRUE
	SStgui.update_uis(src)
	var/duration = kind == "habit" ? 6 SECONDS : (kind == "keepsake" ? 5 SECONDS : 10 SECONDS)
	var/completed = do_after(user, duration, target = user, extra_checks = CALLBACK(src, PROC_REF(anchor_valid), user, kind, token))
	if(token != action_token)
		return
	anchoring = FALSE
	if(completed && anchor_valid(user, kind, token))
		next_anchor = world.time + 4 MINUTES
		user.add_mood_event("humanity_anchor", kind == anchor ? /datum/mood_event/humanity_anchor : /datum/mood_event/humanity_anchor/reflection)
		to_chat(user, span_notice("На мгновение всё снова кажется знакомым."))
		if(kind == "habit" && length(habit_emote))
			var/message = sanitize(habit_emote, apply_ic_filter = TRUE)
			if(length(trim(message)))
				user.emote("me", message = message, intentional = TRUE)
	SStgui.update_uis(src)
