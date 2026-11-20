/// One owned side of a sheet. Legacy paper lists are aliases of the active page.
/datum/paper_page
	var/list/datum/paper_input/text_inputs = list()
	var/list/datum/paper_stamp/stamps = list()
	var/list/stamp_cache = list()
	var/list/stamp_overlays = list()
	/// Server-generated PNG, never a player-provided URL or HTML fragment.
	var/photo

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
	return copied

/datum/paper_page/proc/has_content()
	return length(text_inputs) || length(stamps) || photo

/datum/paper_page/proc/get_html()
	var/list/parts = list()
	for(var/datum/paper_input/input as anything in text_inputs)
		parts += input.to_raw_html()
	return parts.Join("\n\n")
