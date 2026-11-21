/// One owned side of a sheet. Legacy paper lists are aliases of the active page.
/datum/paper_page
	var/list/datum/paper_input/text_inputs = list()
	var/list/datum/paper_stamp/stamps = list()
	var/list/stamp_cache = list()
	var/list/stamp_overlays = list()
	/// Server-generated PNG, never a player-provided URL or HTML fragment.
	var/photo
	/// A book slot whose content was extracted; this is not a page containing the word "tear".
	var/torn = FALSE

/datum/paper_page/New(encoded_text = "")
	if(length(encoded_text))
		text_inputs += new /datum/paper_input(html_decode(encoded_text))

/datum/paper_page/Destroy()
	text_inputs = null
	stamps = null
	stamp_cache = null
	stamp_overlays = null
	return ..()

/datum/paper_page/proc/copy_page()
	var/datum/paper_page/copied = new
	for(var/datum/paper_input/input as anything in text_inputs)
		copied.text_inputs += input.make_copy()
	for(var/datum/paper_stamp/stamp as anything in stamps)
		copied.stamps += stamp.make_copy()
	copied.stamp_cache = stamp_cache.Copy()
	copied.stamp_overlays = stamp_overlays.Copy()
	copied.photo = photo
	copied.torn = torn
	return copied

/datum/paper_page/proc/has_content()
	return !torn && (length(text_inputs) || length(stamps) || photo)

/datum/paper_page/proc/get_html()
	if(torn)
		return html_decode("&#1056;&#1072;&#1079;&#1088;&#1099;&#1074;")
	var/list/parts = list()
	for(var/datum/paper_input/input as anything in text_inputs)
		parts += input.to_raw_html()
	return parts.Join("\n\n")

/// Versioned book archives retain rendered content, original PNGs, stamps and structural tears.
/datum/paper_page/proc/serialize()
	var/list/saved_stamps = list()
	var/list/inputs = list()
	for(var/datum/paper_input/input as anything in text_inputs)
		inputs += list(input.to_book_data())
	for(var/datum/paper_stamp/stamp as anything in stamps)
		saved_stamps += list(stamp.to_list())
	return list("text" = torn ? "" : html_encode(get_html()), "inputs" = inputs, "photo" = photo, "stamps" = saved_stamps, "torn" = torn)

/// Book viewers share the same page payload as paper, without exposing input datum references.
/datum/paper_page/proc/to_ui_data()
	var/list/saved_stamps = list()
	for(var/datum/paper_stamp/stamp as anything in stamps)
		saved_stamps += list(stamp.to_list())
	return list("content" = get_html(), "photo" = photo, "stamps" = saved_stamps, "torn" = torn)

/// Persist input fields and formatting as data, never live datum references.
/datum/paper_input/proc/to_book_data()
	var/list/saved_children = list()
	for(var/datum/paper_input/child as anything in children)
		saved_children += list(child.to_book_data())
	return list(
		LIST_PAPER_RAW_TEXT = html_encode(raw_text || ""),
		LIST_PAPER_FONT = html_encode(font || ""),
		LIST_PAPER_FIELD_COLOR = html_encode(colour || ""),
		LIST_PAPER_BOLD = !!bold,
		LIST_PAPER_ADVANCED_HTML = !!advanced_html,
		LIST_PAPER_CHILDREN = saved_children,
	)

/// Bound recursive archive data before rebuilding the normal paper-input hierarchy.
/proc/read_book_paper_input(list/data, list/budget, depth = 0)
	if(!islist(data) || depth > 32 || --budget[1] < 0)
		return null
	var/raw = data[LIST_PAPER_RAW_TEXT]
	var/font = data[LIST_PAPER_FONT]
	var/colour = data[LIST_PAPER_FIELD_COLOR]
	var/bold = data[LIST_PAPER_BOLD]
	var/advanced = data[LIST_PAPER_ADVANCED_HTML]
	var/list/child_data = data[LIST_PAPER_CHILDREN]
	if(!istext(raw) || !istext(font) || !istext(colour) || !islist(child_data) || !(bold in list(FALSE, TRUE)) || !(advanced in list(FALSE, TRUE)))
		return null
	var/list/children = list()
	for(var/list/entry as anything in child_data)
		var/datum/paper_input/child = read_book_paper_input(entry, budget, depth + 1)
		if(!child)
			QDEL_LIST(children)
			return null
		children += child
	var/decoded = html_decode(raw)
	var/regex/child_key = new(@"\[child_(\d+)\]", "gm")
	while(child_key.Find(decoded))
		var/index = text2num(child_key.group[1])
		if(index < 1 || index > length(children))
			QDEL_LIST(children)
			return null
	return new /datum/paper_input(decoded, html_decode(font), html_decode(colour), bold, advanced, children)
