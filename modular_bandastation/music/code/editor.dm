/datum/song
	var/list/music_document_upload
	/// Separate TGUI source so the piano roll does not replace the track manager.
	var/datum/music_piano_roll/piano_roll

/datum/song/proc/music_ui_data(list/data, mob/user)
	data["midi_start_delay_ticks"] = midi_start_delay_ticks
	data["midi_start_pending"] = !!midi_start_timer
	data["auto_repeat"] = auto_repeat
	data["playback_mode"] = playback_mode
	data["file_track_name"] = file_track_name
	data["file_track_length"] = file_track_length ? DisplayTimeText(file_track_length) : null
	data["file_track_length_seconds"] = max(0, file_track_length / (1 SECONDS))
	data["can_load_file_tracks"] = TRUE
	data["preset_file_tracks"] = list()
	data["loaded_file_tracks"] = list()
	for(var/list/track as anything in loaded_file_tracks)
		data["loaded_file_tracks"] += list(list(
			"name" = track["name"],
			"length" = track["length"] ? DisplayTimeText(track["length"]) : null,
			"length_seconds" = max(1, round((track["length"] || 1 SECONDS) / (1 SECONDS))),
			"selected" = (track["name"] == file_track_name),
		))
	data["advanced_music_access"] = can_use_advanced_music(user)
	data["using_instrument_id"] = using_instrument?.id
	data["music_upload"] = null
	data["music_upload_interval"] = get_music_upload_delay() * 100
	if(music_document_upload)
		data["music_upload"] = list("id" = music_document_upload["id"], "next" = music_document_upload["next"], "state" = music_document_upload["state"], "error" = music_document_upload["error"])
		if(music_document_upload["user"] == WEAKREF(user))
			data["music_upload"]["native_controls"] = music_document_upload["native_controls"]
	data["midi_shared"] = !!sequence_master
	data["auto_sing"] = auto_sing
	data["singing_tts"] = singing_tts
	data["audio_hash"] = file_track_hash
	data["midi_channels"] = midi_channels
	data["sequence_offset"] = sequence_offset
	data["sequence_length"] = sequence_master ? sequence_master.sequence_length : sequence_length
	data["playback_seconds"] = playing ? max(0, (world.time - playback_started_at) / (1 SECONDS)) : (playback_mode == "sequence" ? sequence_offset : 0)
	return data

/datum/song/ui_static_data(mob/user)
	return music_ui_static_data(..())

/datum/song/proc/music_ui_static_data(list/data)
	var/datum/song/sequence_source = src
	if(sequence_master)
		sequence_source = sequence_master
	data["sequence_document"] = list("version" = 1, "title" = sequence_source.midi_title, "notes" = sequence_source.midi_notes, "tempos" = sequence_source.midi_tempos, "tracks" = sequence_source.midi_tracks)
	data["cue_document"] = list("version" = 1, "audio_hash" = file_track_hash, "spacing_seconds" = cue_spacing, "cues" = song_cues)
	return data

/// A queued action or file picker may outlive the window's interactive state.
/datum/song/proc/can_use_music_ui(datum/tgui/ui, mob/user)
	if(QDELETED(ui) || ui.closing || ui.status != UI_INTERACTIVE || QDELETED(user) || ui.user != user)
		return FALSE
	var/datum/window_source = ui.src_object
	return !QDELETED(window_source) && (window_source == src || window_source == piano_roll) && window_source.ui_status(user, ui.state) == UI_INTERACTIVE

/datum/song/proc/handle_music_action(action, list/params, mob/user, datum/tgui/ui)
	if(!authorize_music_action(action, params, user))
		return TRUE
	if(!user || !user.client || !in_range(parent, user))
		return FALSE
	switch(action)
		if("import_file_song")
			var/new_file = input(user, "Select an OGG file to play through this instrument.", name) as sound|null
			if(!new_file || QDELETED(src) || QDELETED(parent) || !can_use_music_ui(ui, user) || !in_range(parent, user))
				return TRUE
			set_file_track(new_file, user)
			update_static_data_for_all_viewers()
			return TRUE
		if("clear_file_song")
			clear_file_track()
			return TRUE
		if("set_playback_mode")
			set_playback_mode(params["mode"])
			return TRUE
		if("select_loaded_file_track")
			if(select_loaded_file_track(params["track"]) && params["play"])
				INVOKE_ASYNC(src, PROC_REF(start_playing), user)
			update_static_data_for_all_viewers()
			return TRUE
		if("set_file_track_length")
			var/length_seconds = text2num(params["seconds"])
			set_file_track_length(length_seconds SECONDS)
			return TRUE
		if("set_auto_repeat")
			set_auto_repeat(params["enabled"])
			return TRUE
		if("set_repeat_amount")
			var/repeat_amount = params["amount"]
			if(!isnum(repeat_amount))
				return FALSE
			set_repeats(repeat_amount)
			return TRUE
		if("set_midi_start_delay")
			var/new_delay = params["amount"]
			if(!isnum(new_delay))
				return FALSE
			midi_start_delay_ticks = clamp(round(new_delay), 0, 6000)
			return TRUE
		if("open_piano_roll")
			if(!can_use_advanced_music(user))
				return TRUE
			if(!piano_roll)
				piano_roll = new(src)
			piano_roll.ui_interact(user)
			return TRUE
		if("upload_music_document")
			return receive_music_document(params, user)
		if("begin_native_music_upload")
			return begin_native_music_upload(params, user, ui)
		if("read_native_music_upload")
			return read_native_music_upload(params, user, ui)
		if("cancel_music_upload")
			if(music_document_upload && music_document_upload["id"] == params["id"] && music_document_upload["user"] == WEAKREF(user))
				cancel_music_document_upload()
			return TRUE
		if("select_music_mode")
			select_performance_mode(params["mode"])
			return TRUE
		if("play_music")
			var/requested_mode = params["mode"]
			if(!(requested_mode in list("midi", "sequence", "file")))
				return TRUE
			if(playing)
				var/same_mode = playback_mode == requested_mode
				stop_playing()
				if(same_mode)
					return TRUE
			if(cancel_delayed_midi_start())
				return TRUE
			select_performance_mode(requested_mode)
			start_playing(user)
			return TRUE
		if("set_sequence_document", "set_song_cues")
			apply_music_document(action, params["document"], user)
			return TRUE
		if("sequence_channel")
			var/channel = text2num("[params["channel"]]")
			if(!isnum(channel) || channel < 0 || channel > 15)
				return TRUE
			channel = round(channel)
			if(channel in midi_channels)
				midi_channels -= channel
			else
				midi_channels |= channel
			return TRUE
		if("sequence_seek")
			var/seconds = text2num("[params["seconds"]]")
			if(!isnum(seconds))
				return TRUE
			seek_sequence(seconds)
			return TRUE
		if("auto_sing")
			auto_sing = !!params["enabled"]
			return TRUE
		if("singing_tts")
			singing_tts = !!params["enabled"]
			return TRUE
		if("remove_file_track")
			if(playing)
				return TRUE
			for(var/list/track as anything in loaded_file_tracks)
				if(track["name"] == params["track"])
					loaded_file_tracks -= list(track)
					if(file_track_name == track["name"])
						clear_file_track()
						file_track_hash = null
						song_cues = list()
					break
			prune_music_uploads()
			update_static_data_for_all_viewers()
			return TRUE
	return FALSE

/// Reserve three quarters of the configured Topic budget for normal interaction.
/datum/song/proc/get_music_upload_delay()
	. = 1 SECONDS
	var/second_limit = CONFIG_GET(number/second_topic_limit)
	var/minute_limit = CONFIG_GET(number/minute_topic_limit)
	if(second_limit > 0)
		. = max(., (4 SECONDS) / second_limit)
	if(minute_limit > 0)
		. = max(., (4 MINUTES) / minute_limit)

/// All chunks still pass the normal Topic limiter and instrument UI validation.
/datum/song/proc/receive_music_document(list/params, mob/user)
	var/id = params["id"]
	var/index = params["index"]
	var/count = params["count"]
	var/part = params["part"]
	var/kind = params["kind"]
	var/play_action = params["play_action"]
	if(!istext(id) || length(id) > 80 || !isnum(index) || !isnum(count) || index != round(index) || count != round(count) || count < 1 || count > 4096 || index < 0 || index >= count || !istext(part) || length(part) > 8192 || !(kind in list("sequence", "cues", "notes")))
		return TRUE
	if((!isnull(play_action) && play_action != "play_music") || (kind == "notes" && !isnull(play_action)))
		return TRUE
	var/idle_timeout = max(20 SECONDS, get_music_upload_delay() * 3)
	if(index == 0 && music_document_upload?["id"] != id)
		if(music_document_upload?["state"] in list("preparing", "receiving"))
			to_chat(user, span_warning("Another music upload is still in progress."))
			return TRUE
		cancel_music_document_upload()
		music_document_upload = list("id" = id, "user" = WEAKREF(user), "kind" = kind, "count" = count, "next" = 0, "parts" = list(), "size" = 0, "state" = "receiving", "expires" = world.time + idle_timeout, "play_action" = play_action)
		addtimer(CALLBACK(src, PROC_REF(expire_music_upload), id), idle_timeout)
	var/list/upload = music_document_upload
	if(!upload || upload["native_controls"] || upload["id"] != id || upload["user"] != WEAKREF(user) || upload["state"] != "receiving")
		return TRUE
	if(index != upload["next"] || count != upload["count"] || kind != upload["kind"] || play_action != upload["play_action"] || world.time > upload["expires"] || upload["size"] + length(part) > 600000)
		upload["state"] = "error"
		upload["error"] = "Music upload is invalid or expired. Please retry."
		upload["parts"] = null
		return TRUE
	var/list/parts = upload["parts"]
	parts += part
	upload["size"] += length(part)
	upload["next"]++
	upload["expires"] = world.time + idle_timeout
	if(upload["next"] < count)
		return TRUE
	var/raw = parts.Join()
	return complete_music_document_upload(upload, raw, user)

/// Both transports commit through the same bounded document validation.
/datum/song/proc/complete_music_document_upload(list/upload, raw, mob/user)
	upload["parts"] = null
	clear_native_music_fields(upload)
	var/kind = upload["kind"]
	var/success = apply_music_document(kind == "notes" ? "import_notes_document" : (kind == "sequence" ? "set_sequence_document" : "set_song_cues"), raw, user, upload["play_action"])
	upload["state"] = success ? "complete" : "error"
	if(!success)
		upload["error"] = "Music document rejected; playback was not started. Check the project and retry."
	return TRUE

/datum/song/proc/expire_music_upload(id)
	var/list/upload = music_document_upload
	if(!upload || upload["id"] != id || !(upload["state"] in list("preparing", "receiving")))
		return
	if(upload["expires"] > world.time)
		addtimer(CALLBACK(src, PROC_REF(expire_music_upload), id), upload["expires"] - world.time)
		return
	upload["state"] = "error"
	upload["error"] = "Music upload expired. Please retry."
	upload["parts"] = null
	clear_native_music_fields(upload)

/datum/song/proc/apply_music_document(action, raw, mob/user, play_action)
	if(action != "import_notes_document" && !can_use_advanced_music(user))
		return FALSE
	if(playing || midi_start_timer)
		return FALSE
	if(action == "set_sequence_document" && sequence_master)
		return FALSE
	if(!istext(raw) || length(raw) > MUSIC_DOCUMENT_MAX_BYTES)
		return FALSE
	var/list/document
	try
		document = json_decode(raw)
	catch
		to_chat(user, span_warning("Invalid music document."))
		return FALSE
	if(action == "import_notes_document")
		if(!islist(document) || document["version"] != 1 || !istext(document["text"]) || length_char(document["text"]) > MUSIC_NOTES_MAX_CHARS || !isnull(play_action))
			return FALSE
		var/text = html_encode(replacetext(document["text"], ascii2text(13), ""))
		var/list/import_lines = splittext(text, "\n")
		if(length(import_lines) > SSinstruments.musician_maxlines)
			return FALSE
		for(var/line in import_lines)
			if(length_char(line) > SSinstruments.musician_maxlinechars)
				return FALSE
		ParseSong(user, text)
		set_playback_mode("midi")
		update_static_data_for_all_viewers()
		return TRUE
	var/success = action == "set_sequence_document" ? load_sequence(document) : load_song_cues(document)
	if(!success)
		to_chat(user, span_warning("Music document rejected. Check its limits, timing and audio fingerprint."))
		return FALSE
	update_static_data_for_all_viewers()
	piano_roll?.update_static_data_for_all_viewers()
	if(play_action == "play_music")
		handle_music_action(play_action, list("mode" = action == "set_sequence_document" ? "sequence" : "file"), user)
	return TRUE

/// A tab selects an engine explicitly; no playback command inherits an old mode.
/datum/song/proc/select_performance_mode(new_mode)
	if(!(new_mode in list("midi", "sequence", "file")))
		return FALSE
	if(new_mode == playback_mode)
		return TRUE
	cancel_delayed_midi_start()
	set_playback_mode(new_mode)
	return TRUE

/// Independent window; the song remains the sole owner of the composition and uploads.
/datum/music_piano_roll
	/// Owning song, cleared when this window source is destroyed.
	var/datum/song/song

/datum/music_piano_roll/New(datum/song/owner)
	song = owner
	return ..()

/datum/music_piano_roll/Destroy()
	song = null
	return ..()

/datum/music_piano_roll/ui_host(mob/user)
	return song?.parent

/datum/music_piano_roll/ui_state(mob/user)
	return song?.ui_state(user)

/datum/music_piano_roll/ui_status(mob/user, datum/ui_state/state)
	if(QDELETED(song) || !song.can_use_advanced_music(user))
		return UI_CLOSE
	return ..()

/datum/music_piano_roll/ui_interact(mob/user, datum/tgui/ui)
	if(QDELETED(song) || !song.can_use_advanced_music(user))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "InstrumentPianoRoll220", "[song.parent.name] - Piano roll")
		ui.open()

/datum/music_piano_roll/ui_data(mob/user)
	return song.ui_data(user)

/datum/music_piano_roll/ui_static_data(mob/user)
	return song.ui_static_data(user)

/datum/music_piano_roll/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return TRUE
	var/mob/user = ui.user
	if(QDELETED(song) || !song.can_use_music_ui(ui, user))
		return FALSE
	return song.handle_music_action(action, params, user, ui)
