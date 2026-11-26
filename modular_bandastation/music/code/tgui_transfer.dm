/// Pace encoded audio independently of the instrument hearcheck; at most eight chunks are unacknowledged.
#define MUSIC_TRANSFER_CHARS 16384
#define MUSIC_TRANSFER_WINDOW 8
#define MUSIC_TRANSFER_INTERVAL (0.1 SECONDS)
#define MUSIC_TRANSFER_TIMEOUT (20 SECONDS)
/// Share outbound capacity fairly instead of multiplying the full rate by audience size.
#define MUSIC_TRANSFER_GLOBAL_PACKETS 8
/// Half of each shared budget may bypass the audience queue for waiting initiators.
#define MUSIC_TRANSFER_PRIORITY_PACKETS 4
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
	// rust-g cannot read a resource packed into the DMB/RSC as a filesystem path.
	var/path = "data/concert_transfer_[REF(src)].ogg"
	if(!fcopy(file_track, path))
		fdel(path)
		return FALSE
	var/encoded
	try
		encoded = rustg_hash_file(RUSTG_HASH_BASE64, path)
	catch
		encoded = null
	fdel(path)
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
	var/prepare = !(listener in file_failed_listeners)
	var/list/previous = panel.instrument_audio_states[last_channel_played]
	if(previous && previous["token"] == file_transfer_token && previous["hash"] == file_transfer_hash && previous["volume"] == output_gain && previous["waiting"] == waiting && previous["prepare"] == prepare && world.time < previous["sent_at"] + MUSIC_PLAYBACK_SYNC_INTERVAL)
		return
	panel.window.send_message("audio/instrumentPlay", list(
		"id" = last_channel_played,
		"token" = file_transfer_token,
		"hash" = file_transfer_hash,
		"volume" = output_gain,
		"position" = file_start_deadline ? 0 : (REALTIMEOFDAY - playback_started_at) / (1 SECONDS),
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
	/// Reject late requests even after their completed transfer has been released.
	var/instrument_transfer_request = 0
	var/next_instrument_audio_warning = 0
	/// Pending panels rotate after each packet and are removed on every cancellation path.
	var/static/list/instrument_transfer_queue = list()
	/// Subset of the pending queue, avoiding an audience scan on every packet timer.
	var/static/list/instrument_priority_queue = list()
	var/static/instrument_transfer_budget = MUSIC_TRANSFER_GLOBAL_PACKETS
	var/static/instrument_transfer_priority_budget = MUSIC_TRANSFER_PRIORITY_PACKETS
	var/static/instrument_transfer_budget_at = 0

/** Resolve only a currently audible source registered by the server. */
/datum/tgui_panel/proc/get_instrument_song(id, token, hash)
	if(!istext(id))
		return
	var/datum/weakref/source_ref = instrument_songs[id]
	var/datum/song/song = source_ref?.resolve()
	if(!song || (!song.playing && !song.file_preparing) || song.playback_mode != "file" || song.last_channel_played != id || song.file_transfer_token != token || song.file_transfer_hash != hash || !(client?.mob in song.file_listeners))
		return
	return song

/** Stop the owned timer and notify the browser so a cancelled queue cannot remain stuck. */
/datum/tgui_panel/proc/cancel_instrument_transfer(notify = TRUE, reason = "cancelled")
	instrument_transfer_queue -= src
	instrument_priority_queue -= src
	if(instrument_transfer_timer)
		deltimer(instrument_transfer_timer)
		instrument_transfer_timer = null
	if(instrument_transfer && notify)
		window?.send_message("audio/instrumentAbort", list("transfer" = instrument_transfer["transfer"], "request" = instrument_transfer["request"], "hash" = instrument_transfer["hash"], "reason" = reason))
	instrument_transfer = null

/** An accepted request and its duplicate receive the same explicit transfer header. */
/datum/tgui_panel/proc/send_instrument_transfer_begin()
	window.send_message("audio/instrumentBegin", list(
		"transfer" = instrument_transfer["transfer"],
		"request" = instrument_transfer["request"],
		"hash" = instrument_transfer["hash"],
		"size" = instrument_transfer["size"],
		"bytes" = instrument_transfer["bytes"],
		"offset" = instrument_transfer["start"],
		"chunkSize" = MUSIC_TRANSFER_CHARS,
		"window" = MUSIC_TRANSFER_WINDOW,
	))

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
			if(IS_WEAKREF_OF(client?.mob, candidate.file_start_listener))
				break
	if(!is_ready() || !source || world.time >= transfer["deadline"])
		var/reason = !is_ready() ? "panel_not_ready" : (!source ? "source_unavailable" : "ack_timeout")
		log_admin("OGG transfer aborted: listener=[key_name(client)], reason=[reason], sent=[transfer["sent"]]/[transfer["size"]], acknowledged=[transfer["acked"]], recording_hash=[transfer["hash"]].")
		cancel_instrument_transfer(reason = reason)
		return
	var/sent = transfer["sent"]
	var/priority = source.file_start_deadline && IS_WEAKREF_OF(client?.mob, source.file_start_listener) && !(client.mob in source.file_ready_listeners)
	if(sent < length(source.file_transfer_data) && sent - transfer["acked"] < MUSIC_TRANSFER_CHARS * MUSIC_TRANSFER_WINDOW)
		instrument_transfer_queue |= src
		if(priority)
			instrument_priority_queue |= src
		else
			instrument_priority_queue -= src
		if(world.time >= instrument_transfer_budget_at + MUSIC_TRANSFER_INTERVAL)
			instrument_transfer_budget_at = world.time
			instrument_transfer_budget = MUSIC_TRANSFER_GLOBAL_PACKETS
			instrument_transfer_priority_budget = MUSIC_TRANSFER_PRIORITY_PACKETS
		var/datum/tgui_panel/next_panel = instrument_transfer_queue[1]
		if(instrument_transfer_priority_budget > 0 && length(instrument_priority_queue))
			next_panel = instrument_priority_queue[1]
		if(instrument_transfer_budget > 0 && next_panel == src)
			instrument_transfer_queue -= src
			instrument_priority_queue -= src
			instrument_transfer_budget--
			if(priority)
				instrument_transfer_priority_budget = max(0, instrument_transfer_priority_budget - 1)
			var/chunk = copytext(source.file_transfer_data, sent + 1, sent + MUSIC_TRANSFER_CHARS + 1)
			transfer["sent"] += length(chunk)
			window.send_message("audio/instrumentChunk", list("transfer" = transfer["transfer"], "offset" = sent, "data" = chunk))
			// A large audience may outlive the startup deadline while still making progress.
			if(source.file_start_deadline && IS_WEAKREF_OF(client?.mob, source.file_start_listener))
				source.file_start_deadline = max(source.file_start_deadline, REALTIMEOFDAY + 45 SECONDS)
	else
		instrument_transfer_queue -= src
		instrument_priority_queue -= src
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
		instrument_transfer_request = 0
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
			if(!islist(payload))
				return TRUE
			var/request_id = payload["request"]
			if(!isnum(request_id) || request_id < 1 || request_id > 1e9 || request_id != round(request_id))
				return TRUE
			var/datum/song/song = get_instrument_song(payload["id"], payload["token"], payload["hash"])
			if(!song?.file_transfer_data || !is_ready())
				window.send_message("audio/instrumentAbort", list("request" = request_id, "reason" = "source_unavailable"))
				return TRUE
			var/offset = isnull(payload["offset"]) ? 0 : payload["offset"]
			if(!isnum(offset) || offset < 0 || offset >= length(song.file_transfer_data) || offset != round(offset) || offset % MUSIC_TRANSFER_CHARS)
				window.send_message("audio/instrumentAbort", list("request" = request_id, "reason" = "invalid_offset"))
				return TRUE
			if(request_id <= instrument_transfer_request)
				if(instrument_transfer && instrument_transfer["request"] == request_id && instrument_transfer["hash"] == song.file_transfer_hash && instrument_transfer["start"] == offset)
					send_instrument_transfer_begin()
					return TRUE
				window.send_message("audio/instrumentAbort", list("request" = request_id, "reason" = "stale_request"))
				return TRUE
			instrument_transfer_request = request_id
			cancel_instrument_transfer(FALSE)
			instrument_transfer = list(
				"transfer" = "[++instrument_transfer_serial]",
				"request" = request_id,
				"hash" = song.file_transfer_hash,
				"start" = offset,
				"sent" = offset,
				"acked" = offset,
				"size" = length(song.file_transfer_data),
				"bytes" = song.file_transfer_bytes,
				"deadline" = world.time + MUSIC_TRANSFER_TIMEOUT,
			)
			send_instrument_transfer_begin()
			instrument_transfer_timer = addtimer(CALLBACK(src, PROC_REF(pump_instrument_transfer)), MUSIC_TRANSFER_INTERVAL, TIMER_STOPPABLE)
			return TRUE
		if("audio/instrumentAck")
			if(!islist(payload) || !instrument_transfer || payload["transfer"] != instrument_transfer["transfer"])
				return TRUE
			var/received = payload["received"]
			if(!isnum(received) || received != round(received) || received <= instrument_transfer["acked"] || received > instrument_transfer["sent"] || (received != instrument_transfer["size"] && received % MUSIC_TRANSFER_CHARS))
				return TRUE
			instrument_transfer["acked"] = received
			instrument_transfer["deadline"] = world.time + MUSIC_TRANSFER_TIMEOUT
			if(received == instrument_transfer["size"])
				cancel_instrument_transfer(FALSE)
			return TRUE
		if("audio/instrumentCancel")
			if(islist(payload) && instrument_transfer && payload["request"] == instrument_transfer["request"])
				cancel_instrument_transfer(FALSE)
			return TRUE
		if("audio/instrumentError")
			if(!islist(payload))
				return TRUE
			var/datum/song/song = get_instrument_song(payload["id"], payload["token"], payload["hash"])
			if(!song)
				return TRUE
			var/mob/initiator = song.file_initiator?.resolve()
			var/datum/tgui_panel/initiator_panel = initiator?.client?.tgui_panel
			var/reason = payload["reason"]
			if(!(reason in list("transfer", "decode", "blocked", "playback")))
				return TRUE
			var/detail = payload["detail"]
			if(!(detail in list("timeout", "invalid_header", "invalid_chunk", "invalid_ogg", "incomplete", "server_abort", "ack_timeout", "panel_not_ready", "source_unavailable", "invalid_offset", "stale_request", "cancelled")))
				detail = "unspecified"
			if(client.mob in song.file_failed_listeners)
				return TRUE
			log_admin("OGG browser failure: listener=[key_name(client)], initiator=[key_name(initiator)], source=[song.parent] ([AREACOORD(song.parent)]), channel=[song.last_channel_played], reason=[reason], detail=[detail], preparing=[song.file_preparing], playing=[song.playing].")
			// A browser gesture can recover autoplay; keep its silent preparation enabled.
			if(reason != "blocked")
				song.file_failed_listeners |= client.mob
			song.file_ready_listeners -= client.mob
			SStgui.update_uis(song)
			if((!song.playing && !song.file_preparing) || (!song.file_start_deadline && REALTIMEOFDAY > song.file_start_error_until))
				return TRUE
			if(reason != "blocked" && IS_WEAKREF_OF(client?.mob, song.file_start_listener))
				song.stop_playing()
			if(client.mob == initiator && initiator_panel && world.time >= initiator_panel.next_instrument_audio_warning)
				initiator_panel.next_instrument_audio_warning = world.time + 10 SECONDS
				var/message = "Instrument music could not be played. Stop and restart it to retry."
				switch(reason)
					if("blocked")
						message = "Your browser blocked automatic music playback. Click the chat window to enable it."
					if("transfer")
						message = "The recording could not be transferred to your browser. Stop and restart it to retry."
					if("decode")
						message = "Your browser could not decode the OGG recording. Check its codec and try another recording."
				to_chat(initiator, span_warning(message))
			return TRUE

#undef MUSIC_TRANSFER_CHARS
#undef MUSIC_TRANSFER_WINDOW
#undef MUSIC_TRANSFER_INTERVAL
#undef MUSIC_TRANSFER_TIMEOUT
#undef MUSIC_TRANSFER_GLOBAL_PACKETS
#undef MUSIC_TRANSFER_PRIORITY_PACKETS
#undef MUSIC_PLAYBACK_SYNC_INTERVAL
