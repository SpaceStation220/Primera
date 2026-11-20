/obj/item/book/Destroy()
	QDEL_NULL(book_data)
	return ..()

/obj/item/book/ui_assets(mob/user)
	return list(get_asset_datum(/datum/asset/spritesheet/simple/stamps))

/obj/machinery/computer/libraryconsole/ui_assets(mob/user)
	. = ..()
	LAZYADD(., get_asset_datum(/datum/asset/spritesheet/simple/stamps))

/datum/admin_book_viewer/ui_assets(mob/user)
	return list(get_asset_datum(/datum/asset/spritesheet/simple/stamps))

/obj/item/book/ui_data(mob/user)
	var/list/data = list()
	var/total = length(book_data.pages)
	book_data.current_page_index = clamp(book_data.current_page_index, 1, max(1, total))
	if(!(book_data.current_page_index % 2))
		book_data.current_page_index--
	var/left = book_data.current_page_index
	var/list/spread = list()
	for(var/index in left to min(left + 1, total))
		var/datum/book_page/page = book_data.pages[index]
		spread += list(page.to_ui_data())
	data["spread"] = spread
	data["current_page"] = left
	data["total_pages"] = total
	data["can_tear"] = !unique && !carved && isliving(user) && user.can_perform_action(src)
	return data

/obj/item/book/ui_act(action, params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!can_read_book(ui.user))
		return TRUE
	switch(action)
		if("next_spread")
			if(book_data.current_page_index + 2 <= length(book_data.pages))
				book_data.current_page_index += 2
			return TRUE
		if("prev_spread")
			book_data.current_page_index = max(1, book_data.current_page_index - 2)
			return TRUE
		if("tear_sheet")
			tear_sheet(ui.user)
			return TRUE

/obj/item/book/proc/tear_sheet(mob/living/user)
	if(!isliving(user) || unique || carved || !user.can_perform_action(src) || !can_read_book(user))
		return FALSE
	var/index = book_data.current_page_index
	if(index < 1 || index > length(book_data.pages))
		return FALSE
	var/obj/item/paper/sheet = new(drop_location())
	for(var/side in 1 to min(2, length(book_data.pages) - index + 1))
		var/datum/book_page/page = book_data.pages[index + side - 1]
		var/datum/paper_page/target = side == 1 ? sheet.front_page : sheet.back_page
		if(length(page.text))
			target.text_inputs += new /datum/paper_input(html_decode(page.text))
		target.photo = page.photo
		for(var/list/stamp as anything in page.stamps)
			target.stamps += new /datum/paper_stamp(stamp["class"], stamp["x"], stamp["y"], stamp["rotation"])
	sheet.bind_active_page()
	sheet.update_appearance()
	var/end = min(index + 2, length(book_data.pages) + 1)
	for(var/cursor in index to end - 1)
		qdel(book_data.pages[cursor])
	book_data.pages.Cut(index, end)
	book_data.current_page_index = max(1, min(index, length(book_data.pages)))
	book_data.rebuild_content()
	user.put_in_hands(sheet)
	SStgui.update_uis(src)
	return TRUE
