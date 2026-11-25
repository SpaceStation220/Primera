/obj/item/paper
	var/current_side = 1
	var/datum/paper_page/front_page
	var/datum/paper_page/back_page

/obj/item/paper/Initialize(mapload)
	. = ..()
	front_page = new
	back_page = new
	save_active_page()
	bind_active_page()

/obj/item/paper/Destroy()
	. = ..()
	QDEL_NULL(front_page)
	QDEL_NULL(back_page)

/// Capture assignments made by existing paper producers/copiers before changing sides.
/obj/item/paper/proc/save_active_page()
	var/datum/paper_page/page = current_side == 2 ? back_page : front_page
	if(!page)
		return
	page.text_inputs = raw_text_inputs || list()
	page.stamps = raw_stamp_data || list()
	page.stamp_cache = stamp_cache || list()

/obj/item/paper/proc/bind_active_page()
	var/datum/paper_page/page = current_side == 2 ? back_page : front_page
	raw_text_inputs = page.text_inputs
	raw_stamp_data = page.stamps
	stamp_cache = page.stamp_cache

/obj/item/paper/proc/get_page(side)
	save_active_page()
	return side == 2 ? back_page : front_page

/obj/item/paper/proc/set_side(side)
	if(side != 1 && side != 2)
		return FALSE
	save_active_page()
	current_side = side
	bind_active_page()
	cut_overlays()
	var/datum/paper_page/page = get_page(side)
	add_overlay(page.stamp_overlays)
	update_appearance()
	update_static_data_for_all_viewers()
	return TRUE

/obj/item/paper/add_stamp(stamp_class, stamp_x, stamp_y, rotation, stamp_icon_state, stamp_icon = 'icons/obj/service/bureaucracy.dmi')
	var/list/before = overlays.Copy()
	. = ..()
	if(!front_page)
		return
	save_active_page()
	var/datum/paper_page/page = get_page(current_side)
	page.stamp_overlays += overlays - before

/obj/item/paper/clear_paper()
	. = ..()
	if(!front_page)
		return
	save_active_page()
	var/datum/paper_page/page = get_page(current_side)
	page.stamp_overlays.Cut()
	page.photo = null
	bind_active_page()

/obj/item/paper/is_empty()
	if(!front_page)
		return ..()
	save_active_page()
	return !front_page.has_content() && !back_page.has_content()

/obj/item/paper/copy(paper_type = /obj/item/paper, atom/location = loc, colored = TRUE, greyscale_override = null)
	save_active_page()
	var/obj/item/paper/copied = ..()
	QDEL_NULL(copied.front_page)
	QDEL_NULL(copied.back_page)
	copied.front_page = front_page.copy_page()
	copied.back_page = back_page.copy_page()
	if(!colored)
		var/new_color = greyscale_override || COLOR_WEBSAFE_DARK_GRAY
		for(var/datum/paper_page/page as anything in list(copied.front_page, copied.back_page))
			for(var/datum/paper_input/input as anything in page.text_inputs)
				input.apply_colour(new_color)
	copied.current_side = current_side
	copied.bind_active_page()
	copied.set_side(current_side)
	return copied

/obj/item/paper/convert_to_data(include_ref = FALSE)
	. = ..()
	if(!front_page)
		return
	save_active_page()
	.["paper_side"] = current_side
	.["paper_sides"] = list(serialize_page(front_page), serialize_page(back_page))

/obj/item/paper/proc/serialize_page(datum/paper_page/page)
	var/list/data = list("text" = list(), "stamps" = list(), "photo" = page.photo)
	for(var/datum/paper_input/input as anything in page.text_inputs)
		data["text"] += list(input.to_list(FALSE))
	for(var/datum/paper_stamp/stamp as anything in page.stamps)
		data["stamps"] += list(stamp.to_list())
	return data

/obj/item/paper/write_from_data(list/data)
	var/list/sides = data["paper_sides"]
	if(!islist(sides) || length(sides) != 2)
		. = ..()
		save_active_page()
		return
	for(var/side in 1 to 2)
		set_side(side)
		var/list/page = sides[side]
		if(!islist(page))
			continue
		var/list/legacy_data = list(
			LIST_PAPER_RAW_TEXT_INPUT = page["text"],
			LIST_PAPER_RAW_STAMP_INPUT = page["stamps"],
			LIST_PAPER_COLOR = data[LIST_PAPER_COLOR],
			LIST_PAPER_NAME = data[LIST_PAPER_NAME],
		)
		..(legacy_data)
		save_active_page()
		var/datum/paper_page/active = get_page(side)
		active.photo = valid_paper_photo(page["photo"]) ? page["photo"] : null
	set_side(data["paper_side"] == 2 ? 2 : 1)

/obj/item/paper/ui_static_data(mob/user)
	. = ..()
	.["current_side"] = current_side
	.["page_key"] = "[REF(src)]_[current_side]"
	var/datum/paper_page/page = get_page(current_side)
	.["page_photo"] = page.photo
	if(istype(loc, /obj/item/paper_stack))
		var/obj/item/paper_stack/stack = loc
		.["is_stack"] = TRUE
		.["stack_page_index"] = (stack.sheets.Find(src) - 1) * 2 + current_side
		.["stack_page_count"] = length(stack.sheets) * 2

/obj/item/paper/ui_act(action, params, datum/tgui/ui)
	. = ..()
	if(.)
		return
	if(action == "flip_side")
		set_side(current_side == 1 ? 2 : 1)
		return TRUE
	if(istype(loc, /obj/item/paper_stack) && (action in list("stack_next", "stack_prev", "remove_sheet")))
		var/obj/item/paper_stack/stack = loc
		var/mob/user = ui.user
		var/index = (stack.sheets.Find(src) - 1) * 2 + current_side
		ui.close()
		if(action == "remove_sheet")
			stack.eject_sheet(stack.sheets.Find(src), user)
		else
			stack.open_page(user, index + (action == "stack_next" ? 1 : -1))
		return TRUE

/obj/item/paper/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/paper))
		if(tool == src)
			return ITEM_INTERACT_BLOCKING
		var/obj/item/paper_stack/stack = new(drop_location())
		if(!stack.add_sheet(tool, user))
			qdel(stack)
			return ITEM_INTERACT_BLOCKING
		if(!stack.add_sheet(src, user))
			stack.eject_sheet(1, user)
			return ITEM_INTERACT_BLOCKING
		user.put_in_hands(stack)
		return ITEM_INTERACT_SUCCESS
	if(istype(tool, /obj/item/paper_stack))
		var/obj/item/paper_stack/stack = tool
		return stack.add_sheet(src, user) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING
	return ..()

/// Bound inline server-created/normalized PNG data; never accept a remote URL.
/proc/valid_paper_photo(value)
	if(!istext(value) || length(value) % 4 || length(value) > MAX_PAPER_PHOTO_LENGTH || copytext(value, 1, 12) != "iVBORw0KGgo")
		return FALSE
	var/static/regex/base64 = regex(@"^[A-Za-z0-9+/]*={0,2}$")
	if(!base64.Find(value))
		return FALSE
	var/bytes = length(value) / 4 * 3 - (endswith(value, "==") ? 2 : (endswith(value, "=") ? 1 : 0))
	return bytes <= MAX_BOOK_PNG_BYTES
