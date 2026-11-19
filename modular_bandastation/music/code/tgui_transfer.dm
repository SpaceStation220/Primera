/// Pace encoded audio independently of the instrument hearcheck; at most eight chunks are unacknowledged.
#define MUSIC_TRANSFER_CHARS 16384
#define MUSIC_TRANSFER_WINDOW 8
#define MUSIC_TRANSFER_INTERVAL (0.1 SECONDS)
#define MUSIC_TRANSFER_TIMEOUT (20 SECONDS)
/// A sparse clock correction keeps cached playback aligned without resending unchanged gain.
#define MUSIC_PLAYBACK_SYNC_INTERVAL (5 SECONDS)

/datum/song
	/// Only the selected recording is encoded, shared by every listener of this song.
	var/file_transfer_data
	var/file_transfer_hash
	var/file_transfer_bytes = 0
	/// Distinguishes restarts and reused sound channels from stale browser messages.
	var/file_transfer_token

/** Encode the validated backing file once, without submitting it to the native resource transport. */
/datum/song/proc/prepare_file_transfer()
	var/hash = md5(file_track)
	if(!hash)
		return FALSE
	if(hash == file_transfer_hash && file_transfer_data)
		return TRUE
	file_transfer_data = null
	file_transfer_hash = null
	file_transfer_bytes = length(file_track)
	if(file_transfer_bytes <= 0 || file_transfer_bytes > MUSIC_UPLOAD_MAX_BYTES)
		return FALSE
	var/encoded = rustg_hash_file(RUSTG_HASH_BASE64, "[file_track]")
	if(!istext(encoded) || length(encoded) != 4 * CEILING(file_transfer_bytes / 3, 1))
		return FALSE
	file_transfer_data = encoded
	file_transfer_hash = hash
	return TRUE

/** Register an audible source before the browser can request its bytes. */
/datum/song/proc/send_browser_file_listener(mob/listener, output_volume)
	var/datum/tgui_panel/panel = listener.client?.tgui_panel
	if(!panel?.is_ready())
		return
	panel.instrument_songs[last_channel_played] = WEAKREF(src)
	file_listeners[listener] = NONE
	var/output_gain = clamp(output_volume / 100, 0, 1)
	var/waiting = !!file_start_deadline
	var/prepare = file_start_deadline && IS_WEAKREF_OF(listener, file_start_listener)
	var/list/previous = panel.instrument_audio_states[last_channel_played]
	if(previous && previous["token"] == file_transfer_token && previous["hash"] == file_transfer_hash && previous["volume"] == output_gain && previous["waiting"] == waiting && previous["prepare"] == prepare && world.time < previous["sent_at"] + MUSIC_PLAYBACK_SYNC_INTERVAL)
		return
	panel.window.send_message("audio/instrumentPlay", list(
		"id" = last_channel_played,
		"token" = file_transfer_token,
		"hash" = file_transfer_hash,
		"volume" = output_gain,
		"position" = file_start_deadline ? 0 : max(0, (world.time - playback_started_at) / (1 SECONDS)),
		"waiting" = waiting,
		"prepare" = prepare,
	))
	panel.instrument_audio_states[last_channel_played] = list("token" = file_transfer_token, "hash" = file_transfer_hash, "volume" = output_gain, "waiting" = waiting, "prepare" = prepare, "sent_at" = world.time)

/datum/song/terminate_sound_mob(mob/listener)
	listener_spatial -= listener
	if(!listener?.client)
		return
	if(playback_mode == "file" && last_channel_played)
		var/datum/tgui_panel/panel = listener?.client?.tgui_panel
		panel?.instrument_songs.Remove(last_channel_played)
		panel?.instrument_audio_states.Remove(last_channel_played)
		panel?.window.send_message("audio/instrumentStop", list("id" = last_channel_played, "token" = file_transfer_token))
	return ..()

/datum/tgui_panel
	/// Allocated channel -> weak song reference; never accept client-supplied file paths.
	var/list/instrument_songs = list()
	/// Last browser playback state per channel, discarded on panel reload or stop.
	var/list/instrument_audio_states = list()
	/// One transfer per client. The browser queues other audible recordings.
	var/list/instrument_transfer
	var/instrument_transfer_timer
	var/instrument_transfer_serial = 0
	var/next_instrument_audio_warning = 0

/** Resolve only a currently audible source registered by the server. */
/datum/tgui_panel/proc/get_instrument_song(id, token, hash)
	if(!istext(id))
		return
	var/datum/weakref/source_ref = instrument_songs[id]
	var/datum/song/song = source_ref?.resolve()
	if(!song || !song.playing || song.playback_mode != "file" || song.last_channel_played != id || song.file_transfer_token != token || song.file_transfer_hash != hash || !(client?.mob in song.file_listeners))
		return
	return song

/** Stop the owned timer and notify the browser so a cancelled queue cannot remain stuck. */
/datum/tgui_panel/proc/cancel_instrument_transfer(notify = TRUE)
	if(instrument_transfer_timer)
		deltimer(instrument_transfer_timer)
		instrument_transfer_timer = null
	if(instrument_transfer && notify)
		window?.send_message("audio/instrumentAbort", list("transfer" = instrument_transfer["transfer"], "hash" = instrument_transfer["hash"]))
	instrument_transfer = null

/** One small output per timer invocation; acknowledgments bound the native connection backlog. */
/datum/tgui_panel/proc/pump_instrument_transfer()
	instrument_transfer_timer = null
	var/list/transfer = instrument_transfer
	if(!transfer)
		return
	var/datum/song/source
	for(var/id in instrument_songs)
		var/datum/weakref/source_ref = instrument_songs[id]
		var/datum/song/candidate = source_ref?.resolve()
		if(candidate && get_instrument_song(id, candidate.file_transfer_token, transfer["hash"]))
			source = candidate
			break
	if(!is_ready() || !source || world.time >= transfer["deadline"])
		cancel_instrument_transfer()
		return
	var/sent = transfer["sent"]
	if(sent < length(source.file_transfer_data) && sent - transfer["acked"] < MUSIC_TRANSFER_CHARS * MUSIC_TRANSFER_WINDOW)
		var/chunk = copytext(source.file_transfer_data, sent + 1, sent + MUSIC_TRANSFER_CHARS + 1)
		transfer["sent"] += length(chunk)
		window.send_message("audio/instrumentChunk", list("transfer" = transfer["transfer"], "offset" = sent, "data" = chunk))
	instrument_transfer_timer = addtimer(CALLBACK(src, PROC_REF(pump_instrument_transfer)), MUSIC_TRANSFER_INTERVAL, TIMER_STOPPABLE)

/** Clear old-body voices and pending downloads without affecting admin music. */
/datum/tgui_panel/proc/stop_instrument_music(suppress = TRUE)
	cancel_pending_instrument_starts()
	instrument_songs.Cut()
	instrument_audio_states.Cut()
	cancel_instrument_transfer(FALSE)
	window?.send_message("audio/instrumentStop", list("reset" = !suppress))

/** A personal stop or disconnect must not leave the initiator's whole performance waiting. */
/datum/tgui_panel/proc/cancel_pending_instrument_starts()
	for(var/id in instrument_songs.Copy())
		var/datum/weakref/source_ref = instrument_songs[id]
		var/datum/song/song = source_ref?.resolve()
		if(song?.file_start_deadline && IS_WEAKREF_OF(client?.mob, song.file_start_listener))
			song.stop_playing()

/mob/Login()
	. = ..()
	client?.tgui_panel?.stop_instrument_music(FALSE)

/datum/tgui_panel/Del()
	cancel_pending_instrument_starts()
	cancel_instrument_transfer(FALSE)
	instrument_songs.Cut()
	instrument_audio_states.Cut()
	return ..()

/datum/tgui_panel/on_message(type, payload)
	. = ..()
	if(type == "ready")
		cancel_instrument_transfer(FALSE)
		instrument_audio_states.Cut()
		return TRUE
	if(.)
		return
	switch(type)
		if("audio/instrumentReady")
			if(islist(payload))
				var/datum/song/song = get_instrument_song(payload["id"], payload["token"], payload["hash"])
				song?.begin_file_timeline(client.mob)
			return TRUE
		if("audio/instrumentRequest")
			if(!islist(payload) || instrument_transfer || !is_ready())
				return TRUE
			var/datum/song/song = get_instrument_song(payload["id"], payload["token"], payload["hash"])
			var/request_id = payload["request"]
			if(!song?.file_transfer_data || !isnum(request_id) || request_id < 1 || request_id != round(request_id))
				return TRUE
			instrument_transfer = list(
				"transfer" = "[++instrument_transfer_serial]",
				"request" = request_id,
				"hash" = song.file_transfer_hash,
				"sent" = 0,
				"acked" = 0,
				"size" = length(song.file_transfer_data),
				"bytes" = song.file_transfer_bytes,
				"deadline" = world.time + MUSIC_TRANSFER_TIMEOUT,
			)
			window.send_message("audio/instrumentBegin", list(
				"transfer" = instrument_transfer["transfer"],
				"request" = request_id,
				"hash" = song.file_transfer_hash,
				"size" = length(song.file_transfer_data),
				"bytes" = song.file_transfer_bytes,
				"chunkSize" = MUSIC_TRANSFER_CHARS,
				"window" = MUSIC_TRANSFER_WINDOW,
			))
			instrument_transfer_timer = addtimer(CALLBACK(src, PROC_REF(pump_instrument_transfer)), MUSIC_TRANSFER_INTERVAL, TIMER_STOPPABLE)
			return TRUE
		if("audio/instrumentAck")
			if(!islist(payload) || !instrument_transfer || payload["transfer"] != instrument_transfer["transfer"])
				return TRUE
			var/received = payload["received"]
			if(!isnum(received) || received != round(received) || received <= instrument_transfer["acked"] || received > instrument_transfer["sent"])
				return TRUE
			instrument_transfer["acked"] = received
			instrument_transfer["deadline"] = world.time + MUSIC_TRANSFER_TIMEOUT
			if(received == instrument_transfer["size"])
				if(payload["bytes"] == instrument_transfer["bytes"])
					to_chat(client, span_notice("Music loaded: [round(payload["bytes"] / 1024)] KiB."))
				cancel_instrument_transfer(FALSE)
			return TRUE
		if("audio/instrumentCancel")
			if(islist(payload) && instrument_transfer && payload["request"] == instrument_transfer["request"])
				cancel_instrument_transfer(FALSE)
			return TRUE
		if("audio/instrumentError")
			if(islist(payload))
				var/datum/song/song = get_instrument_song(payload["id"], payload["token"], payload["hash"])
				if(song?.file_start_deadline && IS_WEAKREF_OF(client?.mob, song.file_start_listener))
					song.stop_playing()
			if(world.time >= next_instrument_audio_warning)
				next_instrument_audio_warning = world.time + 10 SECONDS
				to_chat(client, span_warning("Instrument music could not be loaded or played. Stop and restart it to retry."))
			return TRUE

#undef MUSIC_TRANSFER_CHARS
#undef MUSIC_TRANSFER_WINDOW
#undef MUSIC_TRANSFER_INTERVAL
#undef MUSIC_TRANSFER_TIMEOUT
#undef MUSIC_PLAYBACK_SYNC_INTERVAL
