//Some information about how html sanitization is handled
//All book info datums should store sanitized data. This cannot be worked around
//All inputs and outputs from the round (DB calls) need to use sanitized data
//All tgui menus should get unsanitized data, since jsx handles that on its own
//Everything else should use sanitized data. Yes including names, it's an xss vuln because of how chat works
///A datum which contains all the metadata of a book
/datum/book_info
	///The title of the book
	var/title
	///The "author" of the book
	var/author
	///The info inside the book
	var/content
	/// Owned pages; content remains an encoded, full-book compatibility view.
	var/list/datum/book_page/pages = list()
	var/current_page_index = 1

/datum/book_info/New(_title, _author, _content)
	title = _title
	author = _author
	set_content(_content, trusted = TRUE)

/datum/book_info/Destroy()
	QDEL_LIST(pages)
	return ..()

/datum/book_info/proc/set_title(_title, trusted = FALSE)  //Trusted should only be used for books read from the db, or in cases that we can be sure the info has already been sanitized
	if(trusted)
		title = _title
		return
	title = reject_bad_text(trim(html_encode(_title), 30))

/datum/book_info/proc/get_title(default="N/A") //Loads in an html decoded version of the title. Only use this for tgui menus, absolutely nothing else.
	return html_decode(title) || "N/A"

/datum/book_info/proc/set_author(_author, trusted = FALSE)
	if(trusted)
		author = _author
		return
	author = trim(html_encode(_author), MAX_NAME_LEN)

/datum/book_info/proc/get_author(default="N/A")
	return html_decode(author) || "N/A"

/datum/book_info/proc/set_content(_content, trusted = FALSE)
	QDEL_LIST(pages)
	pages = list(new /datum/book_page(trusted ? (_content || "") : trim(html_encode(trim(_content, MAX_PAPER_LENGTH)), MAX_BOOK_LENGTH)))
	current_page_index = 1
	rebuild_content()

/datum/book_info/proc/set_content_using_paper(obj/item/paper/paper)
	return set_content_from_sheets(list(paper))

/datum/book_info/proc/get_content(default="N/A")
	return html_decode(content) || "N/A"

///Returns a copy of the book_info datum
/datum/book_info/proc/return_copy()
	var/datum/book_info/copycat = new
	copy_into(copycat)
	return copycat

///Modify an existing book_info datum to match your data
/datum/book_info/proc/copy_into(datum/book_info/copycat)
	if(copycat == src)
		return copycat
	copycat.set_title(title, trusted = TRUE)
	copycat.set_author(author, trusted = TRUE)
	QDEL_LIST(copycat.pages)
	copycat.pages = list()
	for(var/datum/book_page/page as anything in pages)
		copycat.pages += page.copy_page()
	copycat.current_page_index = 1
	copycat.rebuild_content()
	return copycat

/datum/book_info/proc/compare(datum/book_info/cmp_with)
	if(author != cmp_with.author)
		return FALSE
	if(title != cmp_with.title)
		return FALSE
	if(to_archive() != cmp_with.to_archive())
		return FALSE
	return TRUE

/// Adopt both sides in order, including blank sides between written pages.
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
			var/datum/book_page/page = new(html_encode(source.get_html()))
			page.photo = source.photo
			for(var/datum/paper_stamp/stamp as anything in source.stamps)
				page.stamps += list(stamp.to_list())
			candidate.pages += page
	if(!candidate.has_content() || length(candidate.to_archive()) > MAX_BOOK_ARCHIVE_LENGTH)
		qdel(candidate)
		return FALSE
	candidate.copy_into(src)
	qdel(candidate)
	return TRUE

/datum/book_info/proc/rebuild_content()
	var/list/parts = list()
	for(var/datum/book_page/page as anything in pages)
		parts += page.text
	content = parts.Join("\n\n")

/datum/book_info/proc/has_content()
	for(var/datum/book_page/page as anything in pages)
		if(length(page.text) || page.photo || length(page.stamps))
			return TRUE
	return FALSE

/datum/book_info/proc/get_pages_ui()
	var/list/result = list()
	for(var/datum/book_page/page as anything in pages)
		result += list(page.to_ui_data())
	return result

/datum/book_info/proc/set_page_content(index, text)
	if(!isnum(index) || index != round(index) || index < 1 || index > length(pages))
		return FALSE
	var/datum/book_page/page = pages[index]
	page.text = trim(html_encode(trim(text, MAX_PAPER_LENGTH)), MAX_BOOK_LENGTH)
	rebuild_content()
	return TRUE

/// Versioned JSON in library.content. Never serialize the reader's current cursor.
/datum/book_info/proc/to_archive()
	var/list/serialized = list()
	for(var/datum/book_page/page as anything in pages)
		serialized += list(page.serialize())
	return json_encode(list("format" = "ss220-book", "version" = 1, "pages" = serialized))

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
	if(document["version"] != 1 || !islist(serialized) || !length(serialized) || length(serialized) > MAX_BOOK_PAGES)
		return FALSE
	var/list/datum/book_page/loaded = list()
	for(var/list/data as anything in serialized)
		if(!islist(data) || !istext(data["text"]) || (!isnull(data["photo"]) && !valid_paper_photo(data["photo"])))
			QDEL_LIST(loaded)
			return FALSE
		var/datum/book_page/page = new(data["text"])
		page.photo = data["photo"]
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
			page.stamps += list(stamp.Copy())
		loaded += page
	QDEL_LIST(pages)
	pages = loaded
	current_page_index = 1
	rebuild_content()
	return TRUE

/// Library pages store encoded text separately from safe, inline PNG photos and stamp data.
/datum/book_page
	var/text = ""
	var/photo
	var/list/stamps = list()

/datum/book_page/New(content = "")
	text = content

/datum/book_page/Destroy()
	stamps = null
	return ..()

/datum/book_page/proc/serialize()
	return list("text" = text, "photo" = photo, "stamps" = stamps)

/datum/book_page/proc/copy_page()
	var/datum/book_page/copied = new(text)
	copied.photo = photo
	for(var/list/stamp as anything in stamps)
		copied.stamps += list(stamp.Copy())
	return copied

/datum/book_page/proc/to_ui_data()
	return list("content" = html_decode(text), "photo" = photo, "stamps" = stamps)
