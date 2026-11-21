/// Book pages and archive serialization live here; the upstream text API stays intact.
/datum/book_info
	/// Owned content datums; legacy content is their encoded compatibility representation.
	var/list/datum/paper_page/pages = list()
	/// Reader-local spread position; never persisted with the document.
	var/current_page_index = 1

/datum/book_info/New(_title, _author, _content)
	..()
	set_content(content, trusted = TRUE)

/datum/book_info/Destroy()
	QDEL_LIST(pages)
	return ..()

/datum/book_info/set_content(_content, trusted = FALSE)
	..()
	QDEL_LIST(pages)
	pages = list(new /datum/paper_page(content || ""))
	current_page_index = 1
	rebuild_content()

/datum/book_info/set_content_using_paper(obj/item/paper/paper)
	return set_content_from_sheets(list(paper))

/datum/book_info/return_copy()
	var/datum/book_info/copied = new
	copy_into(copied)
	return copied

/datum/book_info/copy_into(datum/book_info/copycat)
	if(copycat == src)
		return copycat
	..()
	QDEL_LIST(copycat.pages)
	copycat.pages = list()
	for(var/datum/paper_page/page as anything in pages)
		copycat.pages += page.copy_page()
	copycat.current_page_index = 1
	copycat.rebuild_content()
	return copycat

/datum/book_info/compare(datum/book_info/cmp_with)
	return ..() && to_archive() == cmp_with.to_archive()

/// Append populated page datums in sheet/side order, skipping empty sides.
/datum/book_info/proc/set_content_from_sheets(list/sheets)
	if(!length(sheets) || length(sheets) * 2 > MAX_BOOK_PAGES)
		return FALSE
	var/datum/book_info/candidate = new
	candidate.title = title
	candidate.author = author
	QDEL_LIST(candidate.pages)
	candidate.pages = list()
	for(var/obj/item/paper/sheet as anything in sheets)
		if(QDELETED(sheet))
			qdel(candidate)
			return FALSE
		for(var/side in 1 to 2)
			var/datum/paper_page/source = sheet.get_page(side)
			if(!source.has_content())
				continue
			candidate.pages += source.copy_page()
	if(!candidate.has_content() || candidate.photo_count() > MAX_BOOK_PHOTOS || length(candidate.to_archive()) > MAX_BOOK_ARCHIVE_LENGTH)
		qdel(candidate)
		return FALSE
	candidate.copy_into(src)
	qdel(candidate)
	return TRUE

/datum/book_info/proc/rebuild_content()
	var/list/parts = list()
	for(var/datum/paper_page/page as anything in pages)
		parts += html_encode(page.get_html())
	content = parts.Join("\n\n")

/datum/book_info/proc/has_content()
	for(var/datum/paper_page/page as anything in pages)
		if(page.has_content() || page.torn)
			return TRUE
	return FALSE

/// Count illustrated sides, including repeated pictures on different pages.
/datum/book_info/proc/photo_count()
	var/count = 0
	for(var/datum/paper_page/page as anything in pages)
		if(page.photo)
			count++
	return count

/// Replace one page image atomically, retaining the previous image on any limit failure.
/datum/book_info/proc/set_page_photo(datum/paper_page/page, photo)
	if(!(page in pages) || page.torn)
		return "This page is no longer in the book."
	if(!isnull(photo) && !valid_paper_photo(photo))
		return "Invalid PNG or image exceeds 128 KiB."
	if(photo && !page.photo && photo_count() >= MAX_BOOK_PHOTOS)
		return "A book may contain at most 10 pictures."
	var/previous = page.photo
	page.photo = photo
	if(length(to_archive()) > MAX_BOOK_ARCHIVE_LENGTH)
		page.photo = previous
		return "The complete book exceeds 2 MiB."
	return null

/datum/book_info/proc/get_pages_ui()
	var/list/result = list()
	for(var/datum/paper_page/page as anything in pages)
		result += list(page.to_ui_data())
	return result

/datum/book_info/proc/set_page_content(index, text)
	if(!isnum(index) || index != round(index) || index < 1 || index > length(pages))
		return FALSE
	var/datum/paper_page/page = pages[index]
	if(page.torn)
		return FALSE
	page.text_inputs = list(new /datum/paper_input(trim(text, MAX_PAPER_LENGTH)))
	rebuild_content()
	return TRUE
/// Versioned JSON in library.content. Never serialize the reader's current cursor.
/datum/book_info/proc/to_archive()
	var/list/serialized = list()
	for(var/datum/paper_page/page as anything in pages)
		serialized += list(page.serialize())
	return json_encode(list("format" = "ss220-book", "version" = 2, "pages" = serialized))

/// Old encoded HTML becomes one page; recognized corrupt/newer documents are not overwritten.
/datum/book_info/proc/load_archive(text)
	if(!istext(text) || length(text) > MAX_BOOK_ARCHIVE_LENGTH)
		return FALSE
	var/list/document
	if(copytext(text, 1, 2) == "{")
		try
			document = json_decode(text)
		catch
			document = null
	if(!islist(document) || document["format"] != "ss220-book")
		set_content(text, trusted = TRUE)
		return TRUE
	var/list/serialized = document["pages"]
	if(!(document["version"] in list(1, 2)) || !islist(serialized) || !length(serialized) || length(serialized) > MAX_BOOK_PAGES)
		return FALSE
	var/list/datum/paper_page/loaded = list()
	var/photos = 0
	for(var/list/data as anything in serialized)
		if(!islist(data) || !istext(data["text"]) || (!isnull(data["photo"]) && !valid_paper_photo(data["photo"])))
			QDEL_LIST(loaded)
			return FALSE
		var/torn = document["version"] == 2 ? data["torn"] : FALSE
		if(!(torn in list(FALSE, TRUE)) || (torn && (length(data["text"]) || data["photo"] || length(data["stamps"]) || length(data["inputs"]))))
			QDEL_LIST(loaded)
			return FALSE
		var/datum/paper_page/page = new(data["text"])
		page.torn = torn
		if(document["version"] == 2)
			var/list/inputs = data["inputs"]
			if(!islist(inputs))
				qdel(page)
				QDEL_LIST(loaded)
				return FALSE
			page.text_inputs = list()
			var/list/budget = list(MAX_PAPER_LENGTH)
			for(var/list/input_data as anything in inputs)
				var/datum/paper_input/input = read_book_paper_input(input_data, budget)
				if(!input)
					qdel(page)
					QDEL_LIST(loaded)
					return FALSE
				page.text_inputs += input
		page.photo = data["photo"]
		if(page.photo && ++photos > MAX_BOOK_PHOTOS)
			qdel(page)
			QDEL_LIST(loaded)
			return FALSE
		var/list/stamps = data["stamps"]
		if(!islist(stamps) || length(stamps) > MAX_PAPER_STAMPS)
			qdel(page)
			QDEL_LIST(loaded)
			return FALSE
		for(var/list/stamp as anything in stamps)
			if(!islist(stamp) || !istext(stamp["class"]) || !isnum(stamp["x"]) || !isnum(stamp["y"]) || !isnum(stamp["rotation"]))
				qdel(page)
				QDEL_LIST(loaded)
				return FALSE
			page.stamps += new /datum/paper_stamp(stamp["class"], stamp["x"], stamp["y"], stamp["rotation"])
		loaded += page
	QDEL_LIST(pages)
	pages = loaded
	current_page_index = 1
	rebuild_content()
	return TRUE
