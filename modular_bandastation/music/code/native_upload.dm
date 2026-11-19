/client
	/// One active native music bank per client, regardless of open instrument windows.
	var/datum/weakref/native_music_source
	var/native_music_id

/// Reuse a bounded native bank so Notes and MIDI avoid Topic's small payload chunks.
/datum/song/proc/begin_native_music_upload(list/params, mob/user, datum/tgui/ui)
	var/id = params["id"]
	var/count = params["count"]
	var/size = params["size"]
	var/kind = params["kind"]
	var/play_action = params["play_action"]
	if(!istext(id) || !length(id) || length(id) > 80 || !(kind in list("sequence", "notes")) || !isnum(size) || size != round(size) || size < 4 || size > MUSIC_NATIVE_MAX_CHARS || size % 4 || !isnum(count) || count != CEILING(size / MUSIC_NATIVE_PAGE_CHARS, 1) || (!isnull(play_action) && (play_action != "play_music" || kind == "notes")))
		return TRUE
	if((kind != "notes" && !can_use_advanced_music(user)) || !can_use_music_ui(ui, user) || !in_range(parent, user) || playing || midi_start_timer || sequence_master)
		return TRUE
	if(music_document_upload?["state"] in list("preparing", "receiving"))
		return TRUE
	cancel_music_document_upload()
	var/client/owner = user.client
	if(!owner || owner.native_music_source?.resolve())
		music_document_upload = list("id" = id, "state" = "error", "error" = "Another instrument is uploading music. Finish or cancel it first.")
		return TRUE
	var/list/upload = list("id" = id, "kind" = kind, "user" = WEAKREF(user), "count" = count, "next" = 0, "size" = size, "parts" = list(), "state" = "preparing", "play_action" = play_action, "native_client" = WEAKREF(owner), "native_ui" = WEAKREF(ui), "native_controls" = list(), "expires" = world.time + max(20 SECONDS, get_music_upload_delay() * 3))
	music_document_upload = upload
	owner.native_music_source = WEAKREF(src)
	owner.native_music_id = id
	RegisterSignal(ui, COMSIG_QDELETING, PROC_REF(on_native_music_ui_deleted))
	addtimer(CALLBACK(src, PROC_REF(expire_music_upload), id), upload["expires"] - world.time)
	var/prefix = "mainwindow.music_upload_[copytext(md5("[REF(src)]:[id]"), 1, 17)]"
	var/list/controls = upload["native_controls"]
	var/bank_fields = kind == "notes" ? min(MUSIC_NATIVE_FIELDS, CEILING(size / MUSIC_NATIVE_FIELD_CHARS, 1)) : MUSIC_NATIVE_FIELDS
	for(var/index in 0 to bank_fields - 1)
		var/control = "[prefix]_[index]"
		controls += control
		winset(owner, control, list("parent" = "mainwindow", "type" = "input", "no-command" = TRUE, "is-visible" = FALSE))
	var/created = winexists(owner, controls[bank_fields])
	if(!native_music_upload_valid(upload, user, ui) || created != "INPUT")
		fail_native_music_upload(upload, "The music transfer window is no longer available.")
		return TRUE
	upload["state"] = "receiving"
	return TRUE

/// This predicate is repeated after each native call, which can yield to other actions.
/datum/song/proc/native_music_upload_valid(list/upload, mob/user, datum/tgui/ui)
	var/datum/weakref/client_ref = upload?["native_client"]
	var/datum/weakref/ui_ref = upload?["native_ui"]
	var/client/owner = client_ref?.resolve()
	if(QDELETED(src) || music_document_upload != upload || QDELETED(user) || !owner || user.client != owner)
		return FALSE
	if(!IS_WEAKREF_OF(src, owner.native_music_source) || owner.native_music_id != upload["id"] || upload["user"] != WEAKREF(user) || ui_ref?.resolve() != ui)
		return FALSE
	return (upload["kind"] == "notes" || can_use_advanced_music(user)) && can_use_music_ui(ui, user) && in_range(parent, user) && !playing && !midi_start_timer && !sequence_master && (upload["state"] in list("preparing", "receiving")) && world.time <= upload["expires"]

/// Read at most one 32-field page; normal Topic limits still govern this request.
/datum/song/proc/read_native_music_upload(list/params, mob/user, datum/tgui/ui)
	var/list/upload = music_document_upload
	if(!upload || !upload["native_controls"] || upload["state"] != "receiving" || upload["id"] != params["id"] || upload["user"] != WEAKREF(user) || upload["reading"])
		return TRUE
	if(!native_music_upload_valid(upload, user, ui))
		fail_native_music_upload(upload, "Music upload lost access to the instrument.")
		return TRUE
	var/index = params["index"]
	if(!isnum(index) || index != upload["next"])
		return TRUE
	upload["reading"] = TRUE
	var/list/controls = upload["native_controls"]
	var/client/owner = user.client
	var/page_size = min(MUSIC_NATIVE_PAGE_CHARS, upload["size"] - index * MUSIC_NATIVE_PAGE_CHARS)
	var/field_count = CEILING(page_size / MUSIC_NATIVE_FIELD_CHARS, 1)
	var/list/parts = list()
	for(var/start = 1; start <= field_count; start += 16)
		var/list/ids = controls.Copy(start, min(start + 16, field_count + 1))
		var/response = winget(owner, ids.Join(";"), "text")
		if(!native_music_upload_valid(upload, user, ui))
			fail_native_music_upload(upload, "Music upload was interrupted; the previous composition is unchanged.")
			return TRUE
		if(!istext(response) || length(response) > 16 * MUSIC_NATIVE_FIELD_CHARS * 4)
			fail_native_music_upload(upload, "The music transfer response exceeded its page limit.")
			return TRUE
		var/list/values = length(ids) > 1 ? params2list(response) : list("[ids[1]].text" = response)
		for(var/field in start to min(start + 15, field_count))
			var/value = values["[controls[field]].text"] || values["[copytext(controls[field], length("mainwindow.") + 1)].text"]
			var/expected_size = min(MUSIC_NATIVE_FIELD_CHARS, page_size - (field - 1) * MUSIC_NATIVE_FIELD_CHARS)
			var/prefix = "[index]:"
			if(!istext(value) || length(value) != length(prefix) + expected_size || copytext(value, 1, length(prefix) + 1) != prefix)
				fail_native_music_upload(upload, "Music transfer was incomplete. Please retry.")
				return TRUE
			parts += copytext(value, length(prefix) + 1)
	var/list/pages = upload["parts"]
	pages += parts.Join()
	upload["reading"] = FALSE
	upload["next"]++
	upload["expires"] = world.time + max(20 SECONDS, get_music_upload_delay() * 3)
	if(upload["next"] < upload["count"])
		return TRUE
	var/encoded = replacetext(replacetext(pages.Join(), "-", "+"), "_", "/")
	var/raw = rustg_decode_base64(encoded)
	if(length(encoded) != upload["size"] || !length(raw) || length(raw) > MUSIC_DOCUMENT_MAX_BYTES || rustg_encode_base64(raw) != encoded)
		fail_native_music_upload(upload, "Invalid music transport data; the previous composition is unchanged.")
		return TRUE
	return complete_music_document_upload(upload, raw, user)

/// Release controls, signals and the client-wide reservation on every terminal path.
/datum/song/proc/clear_native_music_fields(list/upload)
	if(!upload?["native_controls"])
		return
	var/datum/weakref/ui_ref = upload["native_ui"]
	var/datum/tgui/ui = ui_ref?.resolve()
	if(ui)
		UnregisterSignal(ui, COMSIG_QDELETING)
	var/datum/weakref/client_ref = upload["native_client"]
	var/client/owner = client_ref?.resolve()
	if(owner)
		for(var/control in upload["native_controls"])
			winset(owner, control, "parent=none")
		if(IS_WEAKREF_OF(src, owner.native_music_source) && owner.native_music_id == upload["id"])
			owner.native_music_source = null
			owner.native_music_id = null
	upload["native_controls"] = null
	upload["native_client"] = null
	upload["native_ui"] = null

/// Retain a visible error, but never retain a native bank after failure.
/datum/song/proc/fail_native_music_upload(list/upload, message)
	if(!upload)
		return
	upload["state"] = "error"
	upload["error"] = message
	upload["parts"] = null
	clear_native_music_fields(upload)

/// Cancel the current transfer before its source or interactive window is deleted.
/datum/song/proc/cancel_music_document_upload()
	clear_native_music_fields(music_document_upload)
	music_document_upload = null

/datum/song/proc/on_native_music_ui_deleted()
	SIGNAL_HANDLER
	cancel_music_document_upload()
