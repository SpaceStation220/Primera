/datum/song
	/// Uploaded sound resource selected for OGG playback.
	var/file_track
	/// Selected resource's display name.
	var/file_track_name
	/// Selected resource duration in deciseconds.
	var/file_track_length = 0
	/// Absolute end time of the current OGG cycle.
	var/file_track_finish_time = 0
	/// Initial human-triggered playback stays at zero until this listener can play it.
	var/datum/weakref/file_start_listener
	/// Receives playback errors for this performance, including after the preparation barrier.
	var/datum/weakref/file_initiator
	var/file_start_deadline = 0
	/// A selected file can be transferred and decoded without starting its timeline.
	var/file_preparing = FALSE
	var/list/file_ready_listeners = list()
	var/list/file_failed_listeners = list()
	/// Snapshot of the initial audience; late arrivals do not hold an existing start.
	var/list/file_start_audience = list()
	var/file_audience_deadline = 0
	/// Startup failures are reported only around an explicit launch, never for later listeners.
	var/file_start_error_until = 0
	/// One-shot common start supplied by OGG unison.
	var/file_sync_start_at
	/// OGG resources retained by this instrument.
	var/list/loaded_file_tracks = list()
	/// Listener -> current mute status of its persistent non-positional file channel.
	var/list/file_listeners = list()
	var/list/music_uploads = list()
	var/file_track_hash
	var/list/song_cues = list()
	var/auto_sing = FALSE
	var/singing_tts = FALSE
	var/next_cue = 1
	var/next_music_upload = 0
	/// Prevent overlapping native file dialogs from racing the selected recording.
	var/file_upload_pending = FALSE
	/// New copies are staged separately so a rejected replacement cannot damage a loaded file.
	var/file_upload_serial = 0
	var/cue_spacing = 5

/// Snapshot of sound origin turfs and their gains for this update.
/datum/song/proc/get_instrument_sources()
	var/list/sources = list()
	var/turf/origin = get_turf(parent)
	if(origin)
		sources[origin] = 1
	return sources

/datum/song/proc/cleanup_music_uploads()
	for(var/path in music_uploads)
		fdel(path)
	music_uploads.Cut()

/** Own the native picker independently of its transient TGUI window, then revalidate live access. */
/datum/song/proc/import_file_song(mob/user, datum/ui_state/upload_state)
	if(QDELETED(parent) || QDELETED(user) || !user.client || !can_use_advanced_music(user) || !in_range(parent, user) || ui_status(user, upload_state) != UI_INTERACTIVE)
		file_upload_pending = FALSE
		to_chat(user, span_warning("OGG upload rejected: you cannot interact with this instrument."))
		update_data_for_all_viewers()
		return
	var/datum/weakref/uploader = WEAKREF(user.client)
	var/new_file = input(user, "Select an OGG file to play through this instrument.", name) as sound|null
	if(QDELETED(src))
		return
	file_upload_pending = FALSE
	if(!new_file)
		to_chat(user, span_notice("No OGG file was received: the file dialog was cancelled or the upload did not complete."))
		update_data_for_all_viewers()
		return
	// A slow native upload may outlive or refresh its original TGUI window.
	if(QDELETED(parent) || QDELETED(user) || !IS_WEAKREF_OF(user.client, uploader) || !can_use_advanced_music(user) || !in_range(parent, user) || ui_status(user, upload_state) != UI_INTERACTIVE)
		to_chat(user, span_warning("OGG upload rejected: you can no longer interact with this instrument."))
		update_data_for_all_viewers()
		return
	if(set_file_track(new_file, user))
		to_chat(user, span_notice("OGG received and added to the instrument's track library."))
	update_static_data_for_all_viewers()

/datum/song/proc/set_file_track(new_file, mob/user)
	if(!can_use_advanced_music(user))
		to_chat(user, span_warning("OGG upload rejected: the Musician profession is required."))
		return FALSE
	if(!is_valid_music_upload(new_file) || length(loaded_file_tracks) >= 12)
		to_chat(user, span_warning("Load an OGG up to 3 MiB (maximum 12 tracks per instrument)."))
		return FALSE
	if(world.time < next_music_upload)
		to_chat(user, span_warning("OGG upload rejected: wait [DisplayTimeText(next_music_upload - world.time)] before trying again."))
		return FALSE
	next_music_upload = world.time + 10 SECONDS
	var/hash = md5(new_file)
	var/path = "data/music_[REF(src)]_[hash]_[++file_upload_serial].ogg"
	if(!fcopy(new_file, path))
		fdel(path)
		to_chat(user, span_warning("OGG upload failed: the server could not copy the received file. The existing tracks were not changed."))
		return FALSE
	var/duration = get_music_upload_duration(path)
	if(QDELETED(user) || !can_use_advanced_music(user) || !in_range(parent, user))
		fdel(path)
		to_chat(user, span_warning("OGG upload rejected: access to the instrument changed while reading the file."))
		return FALSE
	if(!is_valid_music_duration(duration))
		fdel(path)
		to_chat(user, span_warning("The OGG duration could not be read, or exceeds 30 minutes."))
		return FALSE
	if(playing || file_preparing)
		stop_playing()
	music_uploads |= path
	file_track = file(path)
	file_track_name = SANITIZE_FILENAME("[new_file]")
	file_track_hash = hash
	file_track_length = duration
	song_cues = list()
	cue_spacing = 5
	store_loaded_file_track(file_track_name, file_track, duration)
	for(var/list/track as anything in loaded_file_tracks)
		if(track["name"] == file_track_name)
			track["hash"] = hash
			track["cues"] = song_cues
			track["spacing"] = cue_spacing
			track["path"] = path
	prune_music_uploads()
	playback_mode = "file"
	prepare_file_playback(user)
	return TRUE

/datum/song/proc/select_loaded_file_track(track_name)
	for(var/list/track as anything in loaded_file_tracks)
		if(track["name"] != track_name)
			continue
		if(playing || file_preparing)
			stop_playing()
		file_track = track["file"]
		file_track_name = track["name"]
		file_track_length = track["length"]
		file_track_hash = track["hash"]
		song_cues = track["cues"] || list()
		cue_spacing = track["spacing"] || 5
		playback_mode = "file"
		return TRUE
	return FALSE

/** Warm the selected OGG in nearby browsers, without signals, lyrics or a running timeline. */
/datum/song/proc/prepare_file_playback(mob/user)
	if(playing || file_preparing || !user?.client || !can_use_advanced_music(user) || !in_range(parent, user) || !file_track || !prepare_file_transfer())
		return FALSE
	music_player = user
	file_initiator = WEAKREF(user)
	file_start_listener = WEAKREF(user)
	file_start_deadline = world.time + 3 MINUTES
	file_preparing = TRUE
	if(!play_file_to_current_listeners(user))
		stop_playing()
		return FALSE
	START_PROCESSING(SSinstruments, src)
	return TRUE

/** Release a silent preparation using the same channel and listener cleanup as playback. */
/datum/song/proc/cancel_file_preparation()
	if(file_preparing)
		file_preparing = FALSE
		terminate_all_sounds()
	file_ready_listeners.Cut()
	file_failed_listeners.Cut()
	file_start_audience.Cut()
	file_audience_deadline = 0
	file_start_error_until = 0

/** Changing a timbre releases channels; it must not leave a preparation using a recycled channel. */
/datum/song/set_instrument(datum/instrument/instrument)
	if(file_preparing)
		stop_playing()
	return ..()

/** Preparation maintenance is local and runs no more than once per spatial interval. */
/datum/song/proc/process_file_preparation()
	if(world.time < last_hearcheck + MUSIC_SPATIAL_UPDATE_INTERVAL)
		return
	var/mob/user = file_initiator?.resolve()
	if(!user?.client || !can_use_advanced_music(user) || !in_range(parent, user) || world.time >= file_start_deadline)
		stop_playing()
		return
	do_hearcheck()

/datum/song/proc/prune_music_uploads()
	var/list/used = list()
	for(var/list/track as anything in loaded_file_tracks)
		if(track["path"])
			used |= track["path"]
	for(var/path in music_uploads.Copy())
		if(!(path in used))
			fdel(path)
			music_uploads -= path

/datum/song/proc/start_file_playing(atom/player, mob/initiator)
	if(!can_use_advanced_music(player))
		return
	if(!file_track)
		return FALSE
	if(file_preparing && (length(file_failed_listeners) || !IS_WEAKREF_OF(player, file_initiator)))
		stop_playing()
	if(!prepare_file_transfer())
		to_chat(player, span_warning("The recording could not be prepared for playback."))
		return FALSE
	var/prepared = file_preparing
	file_preparing = FALSE
	playing = TRUE
	music_player = player
	if(!initiator && ismob(player))
		initiator = player
	file_initiator = initiator ? WEAKREF(initiator) : null
	file_start_listener = null
	file_start_deadline = 0
	if(initiator?.client && !sync_starting)
		file_start_listener = WEAKREF(initiator)
		file_start_deadline = world.time + 3 MINUTES
	playback_started_at = isnull(file_sync_start_at) ? world.time : file_sync_start_at
	file_sync_start_at = null
	file_start_error_until = playback_started_at + MUSIC_START_AUDIENCE_WAIT
	file_track_finish_time = playback_started_at + file_track_length
	next_cue = 1
	if(!prepared && !play_file_to_current_listeners(player))
		stop_playing()
		return FALSE
	if(prepared)
		last_hearcheck = world.time - MUSIC_SPATIAL_UPDATE_INTERVAL
		do_hearcheck()
	file_start_audience = file_listeners.Copy()
	SEND_SIGNAL(parent, COMSIG_INSTRUMENT_START, src, player)
	SEND_SIGNAL(player, COMSIG_ATOM_STARTING_INSTRUMENT, src)
	START_PROCESSING(SSinstruments, src)
	if(file_start_deadline && (initiator in file_ready_listeners))
		begin_file_timeline(initiator)
		return TRUE
	if(!file_start_deadline && auto_unison_enabled && !sync_starting)
		sync_play()
	return TRUE

/** Record a browser's warm-up and commit a shared future start for the initial audience. */
/datum/song/proc/begin_file_timeline(mob/listener)
	if((!playing && !file_preparing) || !file_start_deadline || !(listener in file_listeners) || !listener?.client)
		return FALSE
	var/new_ready = !(listener in file_ready_listeners)
	file_ready_listeners |= listener
	file_failed_listeners -= listener
	if(new_ready)
		SStgui.update_uis(src)
	if(file_preparing)
		return TRUE
	var/mob/initiator = file_start_listener?.resolve()
	if(world.time >= file_start_deadline || !initiator?.client || should_stop_playing(music_player) == STOP_PLAYING || !can_use_advanced_music(music_player))
		stop_playing()
		return FALSE
	if(!(initiator in file_ready_listeners))
		return TRUE
	if(!file_audience_deadline)
		file_audience_deadline = world.time + MUSIC_START_AUDIENCE_WAIT
	for(var/mob/member as anything in file_start_audience)
		if(member.client && (member in file_listeners) && file_listeners[member] != SOUND_MUTE && !(member in file_ready_listeners) && !(member in file_failed_listeners) && world.time < file_audience_deadline)
			return TRUE
	file_start_listener = null
	file_start_deadline = 0
	file_start_audience.Cut()
	file_audience_deadline = 0
	playback_started_at = world.time + MUSIC_START_LEAD
	file_start_error_until = playback_started_at + MUSIC_START_AUDIENCE_WAIT
	file_track_finish_time = playback_started_at + file_track_length
	next_cue = 1
	last_hearcheck = world.time - MUSIC_SPATIAL_UPDATE_INTERVAL
	do_hearcheck()
	if(auto_unison_enabled && !sync_starting)
		sync_play()
	return TRUE

/datum/song/proc/play_file_to_current_listeners(atom/player)
	var/static/playback_serial = 0
	file_transfer_token = "[REF(src)]-[++playback_serial]"
	var/channel = pop_channel()
	if(isnull(channel))
		channel_starvation++
		to_chat(player, span_warning("No music channel is currently available."))
		return FALSE
	var/channel_text = num2text(channel)
	channels_playing[channel_text] = 100
	last_channel_played = channel_text
	file_listeners.Cut()
	last_hearcheck = world.time - MUSIC_SPATIAL_UPDATE_INTERVAL
	do_hearcheck()
	return TRUE

/// Recompute audibility and location, without restarting existing listeners.
/datum/song/proc/update_file_listeners(list/sources)
	if((!playing && !file_preparing) || playback_mode != "file" || !last_channel_played)
		return
	var/list/listeners = file_listeners | hearing_mobs
	for(var/mob/listener as anything in listeners)
		if(QDELETED(listener) || !listener.client)
			file_listeners -= listener
			file_ready_listeners -= listener
			file_failed_listeners -= listener
			continue
		var/turf/destination = get_turf(listener)
		var/turf/loudest
		var/nearest_distance = INFINITY
		var/strongest_gain = 0
		for(var/turf/origin as anything in sources)
			if(!destination || origin.z != destination.z)
				continue
			var/distance = get_dist_euclidean(destination, origin)
			nearest_distance = min(nearest_distance, distance)
			var/source_gain = get_file_source_gain(distance, sources[origin])
			if(source_gain > strongest_gain)
				strongest_gain = source_gain
				loudest = origin
		var/multiplier = get_listener_volume_multiplier(listener)
		if(nearest_distance > instrument_range + INSTRUMENT_FILE_RETENTION_MARGIN)
			if(listener in file_listeners)
				terminate_sound_mob(listener)
				file_listeners -= listener
				file_ready_listeners -= listener
				file_failed_listeners -= listener
			continue
		if(!(listener in hearing_mobs) || !loudest || !multiplier || HAS_TRAIT(listener, TRAIT_DEAF))
			mute_file_listener(listener)
			continue
		send_browser_file_listener(listener, get_file_output_volume() * multiplier * strongest_gain)
	// Muted/deaf initiators still need the preparation packet to release the shared start.
	var/mob/initiator = file_start_listener?.resolve()
	if(file_start_deadline && initiator?.client && !(initiator in file_listeners))
		send_browser_file_listener(initiator, 0)

/// Keep a nearby stream alive silently so crossing a range edge does not seek again.
/datum/song/proc/mute_file_listener(mob/listener)
	if(!(listener in file_listeners) || file_listeners[listener] == SOUND_MUTE)
		return
	send_browser_file_listener(listener, 0)
	file_listeners[listener] = SOUND_MUTE

/// Stop retained muted listeners too, before the shared channel is released or reused.
/datum/song/terminate_all_sounds(clear_channels = TRUE)
	for(var/mob/listener as anything in file_listeners)
		if(!QDELETED(listener) && !(listener in hearing_mobs))
			terminate_sound_mob(listener)
	file_listeners.Cut()
	return ..()

/** One channel stays non-positional for its entire lifetime; updates also unmute it. */
/datum/song/proc/make_file_sound(mob/listener, turf/origin, distance, multiplier, gain = 1)
	var/sound/track = sound(file_track)
	track.channel = text2num(last_channel_played)
	configure_file_sound(track, origin, get_turf(listener), distance, multiplier, gain)
	if(listener in file_listeners)
		track.status = SOUND_UPDATE
	else
		track.offset = max(0, (world.time - playback_started_at) / (1 SECONDS))
	file_listeners[listener] = NONE
	return track

/// Compare source gains after distance falloff, not merely their proximity.
/datum/song/proc/get_file_source_gain(distance, gain = 1)
	if(distance > instrument_range)
		return 0
	if(distance <= get_sound_falloff_distance())
		return max(0, gain)
	return max(0, gain * (1 - CALCULATE_SOUND_VOLUME_RATIO(100, distance, instrument_range, get_sound_falloff_distance(), INSTRUMENT_FALLOFF_EXPONENT)))

/** OGG distance affects volume only; native channel mode never changes while walking. */
/datum/song/proc/configure_file_sound(sound/track, turf/origin, turf/destination, distance, multiplier, gain = 1)
	track.volume = max(0, get_file_output_volume() * multiplier * get_file_source_gain(distance, gain))
	track.x = 0
	track.z = 0
	track.y = 0
	track.pan = 0
	track.environment = SOUND_ENVIRONMENT_NONE
	return TRUE

/datum/song/proc/process_file_playing()
	if(should_stop_playing(music_player) == STOP_PLAYING)
		stop_playing()
		return
	var/refreshed = world.time >= last_hearcheck + MUSIC_SPATIAL_UPDATE_INTERVAL
	if(refreshed)
		do_hearcheck()
	if(!can_use_advanced_music(music_player))
		stop_playing()
		return
	if(file_start_deadline)
		var/mob/initiator = file_start_listener?.resolve()
		if(!initiator?.client || world.time >= file_start_deadline)
			to_chat(initiator, span_warning("Music preparation was interrupted. Start it again to retry."))
			stop_playing()
		else if((initiator in file_ready_listeners) && (refreshed || (file_audience_deadline && world.time >= file_audience_deadline)))
			begin_file_timeline(initiator)
		return
	process_song_cues()
	if(world.time < file_track_finish_time)
		return
	if(repeat > 0 || auto_repeat)
		if(!auto_repeat)
			repeat--
		terminate_all_sounds()
		playback_started_at = file_track_finish_time
		file_track_finish_time += file_track_length
		next_cue = 1
		play_file_to_current_listeners(music_player)
		SEND_SIGNAL(parent, COMSIG_INSTRUMENT_REPEAT, TRUE)
		return
	stop_playing(TRUE)

/// Import timed lyrics for the selected OGG, ignoring bracketed performance annotations.
/datum/song/proc/load_song_cues(list/document)
	if(!file_track || !islist(document) || document["version"] != 1)
		return FALSE
	var/list/cues = document["cues"]
	var/spacing = document["spacing_seconds"]
	if(isnull(spacing))
		spacing = 5
	if(!isnum(spacing) || spacing < 0.1 || spacing > 120)
		return FALSE
	if(!islist(cues) || length(cues) > 200)
		return FALSE
	var/list/validated = list()
	var/previous_time = -1
	var/static/regex/cue_tags = regex("\\\[\[^\\\]\\r\\n]*\\\]", "g")
	for(var/list/cue as anything in cues)
		if(!islist(cue) || !isnum(cue["time"]) || !istext(cue["text"]))
			return FALSE
		if(cue["time"] < previous_time || cue["time"] < 0 || cue["time"] > file_track_length / (1 SECONDS) || length_char(cue["text"]) > 300)
			return FALSE
		previous_time = cue["time"]
		var/text = trim(cue_tags.Replace(cue["text"], ""))
		if(length(text))
			validated += list(list("time" = cue["time"], "text" = text))
	song_cues = validated
	cue_spacing = spacing
	for(var/list/track as anything in loaded_file_tracks)
		if(track["hash"] == file_track_hash)
			track["cues"] = song_cues
			track["spacing"] = cue_spacing
	next_cue = 1
	return TRUE

/datum/song/proc/process_song_cues()
	if(!isliving(music_player))
		return
	var/mob/living/singer = music_player
	var/elapsed = (world.time - playback_started_at) / (1 SECONDS)
	var/emitted = 0
	while(next_cue <= length(song_cues))
		var/list/cue = song_cues[next_cue]
		if(cue["time"] > elapsed)
			break
		next_cue++
		if(!auto_sing || emitted >= 2 || elapsed - cue["time"] > 2 || !singer.is_holding(parent) || singer.incapacitated)
			continue
		emitted++
		INVOKE_ASYNC(src, PROC_REF(emit_song_cue), singer, cue["text"], singing_tts)

/datum/song/proc/emit_song_cue(mob/living/singer, text, use_tts)
	if(!QDELETED(singer) && can_use_advanced_music(singer) && playing && singer.is_holding(parent) && !singer.incapacitated)
		singer.say(text, forced = "instrument auto song", message_mods = list("music_no_tts" = !use_tts))

/// Retain an uploaded track in the instrument's library.
/datum/song/proc/store_loaded_file_track(track_name, track_file, track_length)
	for(var/list/track as anything in loaded_file_tracks)
		if(track["name"] == track_name)
			track["file"] = track_file
			track["length"] = track_length
			return
	loaded_file_tracks += list(list(
		"name" = track_name,
		"file" = track_file,
		"length" = track_length,
	))


/// Update the selected OGG duration within the existing bounds.
/datum/song/proc/set_file_track_length(new_length)
	new_length = round(text2num("[new_length]"))
	if(!isnum(new_length))
		return FALSE
	file_track_length = clamp(new_length, 1 SECONDS, 30 MINUTES)
	for(var/list/track as anything in loaded_file_tracks)
		if(track["name"] == file_track_name)
			track["length"] = file_track_length
			break
	if(playing && playback_mode == "file")
		file_track_finish_time = playback_started_at + file_track_length
	return TRUE


/// Set the shared loop flag.
/datum/song/proc/set_auto_repeat(new_auto_repeat)
	auto_repeat = !!new_auto_repeat


/// Stop and clear the selected OGG and its cue sheet.
/datum/song/proc/clear_file_track()
	if((playing || file_preparing) && playback_mode == "file")
		stop_playing()
	file_track = null
	file_track_name = null
	file_track_length = 0
	file_track_hash = null
	file_transfer_data = null
	file_transfer_hash = null
	file_transfer_token = null
	cue_spacing = 5
	song_cues = list()
	next_cue = 1
	if(playback_mode == "file")
		playback_mode = "midi"
