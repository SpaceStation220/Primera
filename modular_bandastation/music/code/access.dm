/// Check the active profession rather than an item, displayed title, or ID card.
/proc/is_music_artist(atom/user)
	var/mob/living/player = user
	return istype(player) && istype(player.mind?.assigned_role, /datum/job/donor/musician)

/// Instrument extensions and disk recording use the same profession boundary.
/datum/song/proc/can_use_advanced_music(atom/user)
	return is_music_artist(user)

/// Shared file bounds for instruments and writable concert media.
/proc/is_valid_music_upload(upload)
	return upload && IS_OGG_FILE(upload) && length(upload) > 0 && length(upload) <= MUSIC_UPLOAD_MAX_BYTES

/// Reject invalid or excessively long decoded audio on either upload path.
/proc/is_valid_music_duration(duration)
	return isnum(duration) && duration > 0 && duration <= MUSIC_UPLOAD_MAX_DURATION

/// Malformed user-supplied audio must not abort its owner's upload cleanup.
/proc/get_music_upload_duration(path)
	try
		return SSsounds.get_sound_length(path)
	catch
		return 0

/// UI actions remain guarded even if a client forges a disabled tab or upload.
/datum/song/proc/authorize_music_action(action, list/params, mob/user)
	if(action == "begin_native_music_upload")
		return params["kind"] == "notes" || can_use_advanced_music(user)
	if(action == "read_native_music_upload")
		return music_document_upload?["kind"] == "notes" || can_use_advanced_music(user)
	var/advanced = (action in list("play_music", "play", "open_piano_roll", "upload_music_document", "set_sequence_document", "set_song_cues", "sequence_channel", "sequence_seek", "auto_sing", "singing_tts", "import_file_song", "clear_file_song", "select_loaded_file_track", "set_file_track_length", "remove_file_track"))
	if(action == "play_music")
		advanced = params["mode"] != "midi"
	if(action == "play")
		advanced = playback_mode != "midi"
	if(action == "upload_music_document" && params["kind"] == "notes")
		advanced = FALSE
	if(action in list("select_music_mode", "set_playback_mode"))
		advanced = (params["mode"] in list("sequence", "file"))
	if(!advanced || can_use_advanced_music(user))
		return TRUE
	to_chat(user, span_warning("MIDI, OGG and extended music controls require the Musician profession."))
	return FALSE
