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

/datum/admin_book_viewer/ui_data(mob/user)
	. = ..()
	if(!view_raw)
		var/datum/book_info/book = new
		if(book.load_archive(content))
			.["pages"] = book.get_pages_ui()
		qdel(book)

/obj/item/book/ui_data(mob/user)
	var/list/data = list()
	var/total = length(book_data.pages)
	book_data.current_page_index = clamp(book_data.current_page_index, 1, max(1, total))
	if(!(book_data.current_page_index % 2))
		book_data.current_page_index--
	var/left = book_data.current_page_index
	var/list/spread = list()
	for(var/index in left to min(left + 1, total))
		var/datum/paper_page/page = book_data.pages[index]
		spread += list(page.to_ui_data())
	data["spread"] = spread
	data["current_page"] = left
	data["total_pages"] = total
	data["can_tear"] = !unique && !carved && isliving(user) && user.can_perform_action(src)
	data["can_edit_images"] = can_edit_images(user)
	data["image_count"] = book_data.photo_count()
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
		if("tear_sheet", "upload_image", "remove_image")
			var/index = params["page"]
			if(!isnum(index) || index != round(index) || index < 1 || index > length(book_data.pages))
				return TRUE
			if(index < book_data.current_page_index || index > book_data.current_page_index + 1)
				return TRUE
			var/datum/paper_page/page = book_data.pages[index]
			if(action == "tear_sheet")
				tear_sheet(ui.user, index)
			else if(action == "upload_image")
				upload_page_image(ui.user, page)
			else
				apply_page_image(ui.user, page, null)
			return TRUE

/// Image editing requires physical possession, not merely an open reader window.
/obj/item/book/proc/can_edit_images(mob/living/user)
	return isliving(user) && !QDELETED(user) && !QDELETED(src) && !unique && !carved && user.is_holding(src) && user.can_perform_action(src)

/// Final mutation boundary, also rechecked after the native file dialog yields.
/obj/item/book/proc/apply_page_image(mob/living/user, datum/paper_page/page, photo)
	if(!can_edit_images(user) || !can_read_book(user) || QDELETED(page))
		return FALSE
	var/error = book_data.set_page_photo(page, photo)
	if(error)
		to_chat(user, span_warning(error))
		return FALSE
	SStgui.update_uis(src)
	return TRUE

/// Import a PNG onto the exact page selected before the file dialog opened.
/obj/item/book/proc/upload_page_image(mob/living/user, datum/paper_page/page)
	if(!can_edit_images(user) || !(page in book_data.pages) || page.torn)
		return
	if(!page.photo && book_data.photo_count() >= MAX_BOOK_PHOTOS)
		to_chat(user, span_warning("A book may contain at most 10 pictures."))
		return
	var/datum/book_info/original_book = book_data
	var/previous_photo = page.photo
	var/upload = input(user, "Select a static PNG: at most 300x300 pixels and 128 KiB.", "Book illustration") as null|file
	if(QDELETED(src))
		return
	if(!upload || !can_edit_images(user) || book_data != original_book || QDELETED(page) || !(page in book_data.pages) || page.photo != previous_photo)
		return
	var/list/result = read_book_png(upload, "data/book_image_[REF(src)].png")
	if(result["error"])
		to_chat(user, span_warning(result["error"]))
		return
	apply_page_image(user, page, result["photo"])

/// Move page 1 or the even/next-odd pair to paper, retaining torn slots and numbering.
/obj/item/book/proc/tear_sheet(mob/living/user, index = book_data.current_page_index)
	if(!isliving(user) || unique || carved || !user.can_perform_action(src) || !can_read_book(user))
		return FALSE
	if(!isnum(index) || index != round(index) || index < 1 || index > length(book_data.pages))
		return FALSE
	var/datum/paper_page/selected = book_data.pages[index]
	if(selected.torn)
		return FALSE
	var/first = index == 1 ? 1 : (index % 2 ? index - 1 : index)
	var/last = index == 1 ? 1 : min(first + 1, length(book_data.pages))
	var/obj/item/paper/sheet = new(drop_location())
	for(var/page_index in first to last)
		var/datum/paper_page/page = book_data.pages[page_index]
		if(page.torn)
			continue
		var/datum/paper_page/gap = new
		gap.torn = TRUE
		book_data.pages[page_index] = gap
		if(page_index == first)
			QDEL_NULL(sheet.front_page)
			sheet.front_page = page
		else
			QDEL_NULL(sheet.back_page)
			sheet.back_page = page
	sheet.bind_active_page()
	sheet.set_side(1)
	book_data.rebuild_content()
	user.put_in_hands(sheet)
	SStgui.update_uis(src)
	return TRUE
