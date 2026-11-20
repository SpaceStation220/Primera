/// A physical bundle; the contained sheet remains the UI host and owns writer signals.
/obj/item/paper_stack
	name = "paper stack"
	desc = "A bundle of two-sided sheets."
	icon = 'icons/obj/service/bureaucracy.dmi'
	icon_state = "paper_stack"
	inhand_icon_state = "paper"
	w_class = WEIGHT_CLASS_SMALL
	resistance_flags = FLAMMABLE
	var/list/obj/item/paper/sheets = list()
	var/current_page_index = 1

/obj/item/paper_stack/Destroy()
	var/list/owned_sheets = sheets
	sheets = null
	QDEL_LIST(owned_sheets)
	return ..()

/obj/item/paper_stack/examine(mob/user)
	. = ..()
	. += span_notice("Contains [length(sheets)] sheets ([length(sheets) * 2] pages). Alt-click to remove a sheet.")

/obj/item/paper_stack/IsContainedAtomAccessible(atom/contained, atom/movable/user)
	return (contained in sheets) && user.Adjacent(src)

/obj/item/paper_stack/proc/add_sheet(obj/item/paper/sheet, mob/living/user)
	if(!istype(sheet) || (sheet in sheets) || length(sheets) >= MAX_PAPER_STACK_SHEETS)
		return FALSE
	if(user)
		if(!user.can_perform_action(src) || !user.Adjacent(sheet))
			return FALSE
		if(sheet.loc == user)
			if(!user.transferItemToLoc(sheet, src))
				return FALSE
		else
			if(sheet.loc != drop_location())
				return FALSE
			sheet.forceMove(src)
	else
		sheet.forceMove(src)
	SStgui.close_uis(sheet)
	sheet.save_active_page()
	sheets += sheet
	return TRUE

/obj/item/paper_stack/proc/merge_stack(obj/item/paper_stack/other, mob/living/user)
	if(!other || other == src || length(sheets) + length(other.sheets) > MAX_PAPER_STACK_SHEETS)
		return FALSE
	if(!user.can_perform_action(src) || !user.Adjacent(other) || !user.is_holding(other))
		return FALSE
	if(!user.temporarilyRemoveItemFromInventory(other))
		return FALSE
	for(var/obj/item/paper/sheet as anything in other.sheets.Copy())
		other.sheets -= sheet
		SStgui.close_uis(sheet)
		sheet.forceMove(src)
		sheets += sheet
	qdel(other)
	return TRUE

/obj/item/paper_stack/proc/add_photo(obj/item/photo/photo, mob/living/user)
	if(length(sheets) >= MAX_PAPER_STACK_SHEETS || !photo?.picture?.picture_image)
		return FALSE
	var/encoded = icon2base64(photo.picture.picture_image)
	if(!valid_paper_photo(encoded))
		to_chat(user, span_warning("This photograph is too large for a paper page."))
		return FALSE
	if(!user.can_perform_action(src) || !user.is_holding(photo))
		return FALSE
	if(!user.temporarilyRemoveItemFromInventory(photo))
		return FALSE
	var/obj/item/paper/sheet = new(drop_location())
	sheet.front_page.photo = encoded
	if(length(photo.scribble))
		sheet.set_side(2)
		sheet.add_raw_text(photo.scribble)
		sheet.set_side(1)
	add_sheet(sheet)
	qdel(photo)
	return TRUE

/obj/item/paper_stack/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/paper))
		return add_sheet(tool, user) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING
	if(istype(tool, /obj/item/paper_stack))
		return merge_stack(tool, user) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING
	if(istype(tool, /obj/item/photo))
		return add_photo(tool, user) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING
	ui_interact(user)
	return ITEM_INTERACT_SUCCESS

/obj/item/paper_stack/attack_self(mob/user)
	ui_interact(user)

/obj/item/paper_stack/ui_interact(mob/user, datum/tgui/ui)
	open_page(user, current_page_index)

/obj/item/paper_stack/proc/open_page(mob/user, index)
	if(!length(sheets) || !isnum(index) || index != round(index) || index < 1 || index > length(sheets) * 2)
		return FALSE
	if(!user.can_perform_action(src) || (resistance_flags & ON_FIRE))
		return FALSE
	current_page_index = index
	var/obj/item/paper/sheet = sheets[CEILING(index / 2, 1)]
	sheet.set_side(index % 2 ? 1 : 2)
	sheet.ui_interact(user)
	return TRUE

/obj/item/paper_stack/proc/eject_sheet(index, mob/living/user)
	if(!isnum(index) || index != round(index) || index < 1 || index > length(sheets))
		return
	if(user && !user.can_perform_action(src))
		return
	var/obj/item/paper/sheet = sheets[index]
	sheets.Cut(index, index + 1)
	SStgui.close_uis(sheet)
	sheet.forceMove(drop_location())
	if(user)
		user.put_in_hands(sheet)
	collapse_stack()
	return sheet

/obj/item/paper_stack/proc/collapse_stack()
	current_page_index = clamp(current_page_index, 1, max(1, length(sheets) * 2))
	if(length(sheets) > 1)
		return
	if(length(sheets))
		var/obj/item/paper/remaining = sheets[1]
		sheets.Cut()
		SStgui.close_uis(remaining)
		remaining.forceMove(drop_location())
	qdel(src)

/obj/item/paper_stack/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone in sheets)
		sheets -= gone
		collapse_stack()

/obj/item/paper_stack/click_alt(mob/living/user)
	eject_sheet(CEILING(current_page_index / 2, 1), user)
	return CLICK_ACTION_SUCCESS
