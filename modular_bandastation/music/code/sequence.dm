#define MUSIC_SEQUENCE_MAX_NOTES 4096
#define MUSIC_SEQUENCE_MAX_SECONDS 1800

/datum/song
	var/list/midi_notes = list()
	var/list/midi_tempos = list(list("time" = 0, "bpm" = 120))
	var/list/midi_tracks = list(list("id" = 0, "name" = "Track 1"))
	var/list/midi_track_settings = list()
	var/list/midi_channels = list(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15)
	var/midi_title = "Untitled"
	var/sequence_length = 0
	var/sequence_cursor = 1
	var/sequence_offset = 0
	/// Engine origin: world.time for MIDI sequences, REALTIMEOFDAY for OGG.
	var/playback_started_at = 0
	var/list/voice_ends = list()
	var/list/voice_levels = list()
	var/list/listener_spatial = list()
	/// Last dispatched base gain per channel; cleared when a channel is reused.
	var/list/music_voice_levels_sent = list()
	var/datum/song/sequence_master
	var/list/sequence_followers = list()
	var/channel_starvation = 0

/// Canonical note times are seconds; the tempo map is preserved for MIDI export.
/datum/song/proc/load_sequence(list/document)
	if(playing || !islist(document) || document["version"] != 1)
		return FALSE
	var/list/notes = document["notes"]
	var/compact_notes = document["note_format"] == "tuple-v1"
	if(!isnull(document["note_format"]) && !compact_notes)
		return FALSE
	var/list/tempos = document["tempos"]
	var/list/tracks = document["tracks"]
	if(!islist(notes) || length(notes) > MUSIC_SEQUENCE_MAX_NOTES || !islist(tempos) || length(tempos) > 1024 || !islist(tracks) || length(tracks) > 128)
		return FALSE
	var/list/validated_tracks = list()
	var/list/track_settings = list()
	for(var/list/entry as anything in tracks)
		if(!islist(entry))
			return FALSE
		var/id = entry["id"]
		var/instrument_id = entry["instrument"]
		var/muted = entry["muted"]
		if(!isnum(id) || id != round(id) || id < 0 || id > 127 || !istext(entry["name"]) || track_settings[num2text(id)])
			return FALSE
		if(!isnull(instrument_id) && (!istext(instrument_id) || !(instrument_id in allowed_instrument_ids) || !SSinstruments.instrument_data[instrument_id]))
			return FALSE
		if(!isnull(muted) && (!isnum(muted) || !(muted in list(TRUE, FALSE))))
			return FALSE
		var/list/track = list("id" = id, "name" = copytext(sanitize(entry["name"]), 1, 65), "muted" = !!muted)
		if(instrument_id)
			track["instrument"] = instrument_id
		validated_tracks += list(track)
		track_settings[num2text(id)] = track
	var/list/validated = list()
	var/end = 0
	var/previous_time = -1
	for(var/list/note as anything in notes)
		if(!islist(note))
			return FALSE
		if(compact_notes && length(note) != 6)
			return FALSE
		var/start = compact_notes ? note[1] : note["time"]
		var/duration = compact_notes ? note[2] : note["duration"]
		var/key = compact_notes ? note[3] : note["key"]
		var/velocity = compact_notes ? note[4] : note["velocity"]
		var/channel = compact_notes ? note[5] : note["channel"]
		var/track = compact_notes ? note[6] : note["track"]
		if(!isnum(start) || !isnum(duration) || !isnum(key) || !isnum(velocity) || !isnum(channel) || !isnum(track))
			return FALSE
		if(start < previous_time || start < 0 || duration <= 0 || start + duration > MUSIC_SEQUENCE_MAX_SECONDS || key < 0 || key > 127 || velocity < 1 || velocity > 127 || channel < 0 || channel > 15 || track < 0 || track > 127)
			return FALSE
		if(track != round(track) || !track_settings[num2text(track)])
			return FALSE
		previous_time = start
		end = max(end, start + duration)
		validated += list(list("time" = start, "duration" = duration, "key" = round(key), "velocity" = round(velocity), "channel" = round(channel), "track" = round(track)))
	var/list/validated_tempos = list()
	previous_time = -1
	for(var/list/entry as anything in tempos)
		if(!islist(entry) || !isnum(entry["time"]) || !isnum(entry["bpm"]))
			return FALSE
		if(entry["time"] < 0 || entry["time"] < previous_time || entry["time"] > MUSIC_SEQUENCE_MAX_SECONDS || entry["bpm"] < 1 || entry["bpm"] > 1000)
			return FALSE
		previous_time = entry["time"]
		validated_tempos += list(list("time" = entry["time"], "bpm" = entry["bpm"]))
	midi_notes = validated
	midi_tempos = length(validated_tempos) ? validated_tempos : list(list("time" = 0, "bpm" = 120))
	midi_tracks = validated_tracks
	midi_track_settings = track_settings
	midi_title = copytext(sanitize("[document["title"]]"), 1, 81)
	sequence_length = end
	sequence_offset = 0
	return TRUE

/datum/song/proc/start_sequence(atom/player)
	if(!can_use_advanced_music(player))
		return FALSE
	if(!length(midi_notes) && !length(sequence_master?.midi_notes))
		to_chat(player, span_warning("No MIDI notes loaded."))
		return FALSE
	var/datum/song/source = sequence_master || src
	for(var/list/track as anything in source.midi_tracks)
		var/datum/instrument/instrument = get_sequence_instrument(track["id"])
		if(instrument && !instrument.ready())
			to_chat(player, span_warning("The instrument for MIDI track [track["name"]] is not ready."))
			return FALSE
	playing = TRUE
	music_player = player
	if(sequence_master)
		playback_started_at = sequence_master.playback_started_at
		do_hearcheck()
	else
		seek_sequence(sequence_offset)
	SEND_SIGNAL(parent, COMSIG_INSTRUMENT_START, src, player)
	SEND_SIGNAL(player, COMSIG_ATOM_STARTING_INSTRUMENT, src)
	START_PROCESSING(SSinstruments, src)
	if((id || multi_sync_enabled) && !sync_starting && !sequence_master)
		sync_play()
	return TRUE

/datum/song/proc/seek_sequence(seconds)
	if(sequence_master)
		return FALSE
	sequence_offset = clamp(seconds, 0, max(0, sequence_length - 0.01))
	if(!playing || playback_mode != "sequence")
		return TRUE
	playback_started_at = world.time - sequence_offset SECONDS
	var/list/participants = list(src) + sequence_followers
	for(var/datum/song/member as anything in participants)
		if(QDELETED(member))
			continue
		member.terminate_all_sounds()
		member.playback_started_at = playback_started_at
		member.do_hearcheck()
	sequence_cursor = 1
	while(sequence_cursor <= length(midi_notes))
		var/list/note = midi_notes[sequence_cursor]
		if(note["time"] >= sequence_offset)
			break
		if(note["time"] + note["duration"] > sequence_offset)
			for(var/datum/song/member as anything in participants)
				if(!QDELETED(member))
					member.play_sequence_note(note, note["time"] + note["duration"] - sequence_offset)
		sequence_cursor++
	return TRUE

/datum/song/proc/process_sequence()
	var/turf/here = get_turf(parent)
	var/turf/master_turf = get_turf(sequence_master?.parent)
	if(should_stop_playing(music_player) == STOP_PLAYING || (sequence_master && (!sequence_master.playing || !here || !master_turf || get_dist(parent, sequence_master.parent) > 5 || here.z != master_turf.z)))
		stop_playing()
		return
	process_sequence_voices()
	if(world.time >= last_hearcheck + MUSIC_SPATIAL_UPDATE_INTERVAL)
		do_hearcheck()
	if(!can_use_advanced_music(music_player))
		stop_playing()
		return
	if(sequence_master)
		return
	var/elapsed = (world.time - playback_started_at) / (1 SECONDS)
	// Score timestamps can fall between server ticks; do not subtract that quantization from the attack.
	var/tick_window = max(world.tick_lag, SSinstruments.wait) / (1 SECONDS)
	var/budget = 64
	while(sequence_cursor <= length(midi_notes) && budget-- > 0)
		var/list/note = midi_notes[sequence_cursor]
		if(note["time"] > elapsed)
			break
		sequence_cursor++
		var/duration = note["duration"] - max(0, elapsed - note["time"] - tick_window)
		if(duration <= 0)
			continue
		play_sequence_note(note, duration)
		for(var/datum/song/follower as anything in sequence_followers.Copy())
			if(QDELETED(follower) || !follower.playing || follower.sequence_master != src)
				sequence_followers -= follower
				continue
			follower.play_sequence_note(note, duration)
	if(sequence_cursor <= length(midi_notes) || elapsed < sequence_length)
		return
	if(repeat > 0 || auto_repeat)
		if(!auto_repeat)
			repeat--
		// Let the previous cycle's releases finish while the next attacks begin.
		sequence_cursor = 1
		playback_started_at += sequence_length SECONDS
		return
	if(elapsed < sequence_length + tick_window + MUSIC_MIDI_RELEASE / (1 SECONDS))
		return
	stop_playing(TRUE)

/datum/song/proc/play_sequence_note(list/note, duration)
	if(!length(hearing_mobs))
		return
	if(playback_mode == "sequence" && !(note["channel"] in midi_channels))
		return
	var/datum/instrument/instrument = using_instrument
	if(playback_mode == "sequence")
		instrument = get_sequence_instrument(note["track"])
	if(QDELETED(instrument))
		return
	var/key = clamp(note["key"] + note_shift, key_min, key_max)
	var/datum/instrument_key/sample_key = get_music_sample(key, instrument)
	if(!sample_key)
		return
	var/sample = sample_key.sample
	var/frequency = sample_key.frequency
	var/channel = pop_channel()
	if(isnull(channel))
		channel_starvation++
		return
	var/text_channel = num2text(channel)
	channels_playing[text_channel] = 100
	voice_ends[text_channel] = world.time + duration SECONDS
	voice_levels[text_channel] = instrument.volume_multiplier * note["velocity"] / 127
	var/sound/voice = sound(sample)
	voice.frequency = frequency
	var/output_volume = get_output_volume(volume * voice_levels[text_channel])
	for(var/mob/listener as anything in hearing_mobs)
		if(!listener.client)
			continue
		var/list/spatial = listener_spatial[listener]
		var/turf/origin = spatial?["stereo"] ? get_turf(listener) : (spatial?["origin"] || get_turf(parent))
		listener.playsound_local(origin, null, output_volume * get_listener_volume_multiplier(listener) * (spatial?["source_gain"] || 1), frequency = frequency, sound_to_use = voice, channel = channel, pressure_affected = FALSE, max_distance = instrument_range, falloff_distance = get_source_falloff_distance(origin), falloff_exponent = INSTRUMENT_FALLOFF_EXPONENT)

/// Unison follows the leader's notes but keeps the follower's own timbre.
/datum/song/proc/get_sequence_instrument(track)
	var/datum/song/source = sequence_master || src
	var/list/settings = source.midi_track_settings[num2text(track)]
	if(settings?["muted"])
		return null
	if(sequence_master)
		return using_instrument
	var/instrument_id = settings?["instrument"]
	if(instrument_id && (instrument_id in allowed_instrument_ids))
		var/datum/instrument/instrument = SSinstruments.instrument_data[instrument_id]
		if(!QDELETED(instrument))
			return instrument
	return using_instrument

/datum/song/proc/process_sequence_voices()
	for(var/channel in voice_ends.Copy())
		if(world.time < voice_ends[channel])
			continue
		if(playback_mode == "sequence" && world.time < voice_ends[channel] + MUSIC_MIDI_RELEASE)
			var/remaining = (voice_ends[channel] + MUSIC_MIDI_RELEASE - world.time) / MUSIC_MIDI_RELEASE
			channels_playing[channel] = 100 * remaining
			var/level = get_output_volume(volume * voice_levels[channel]) * remaining
			if(!(channel in music_voice_levels_sent) || music_voice_levels_sent[channel] != level)
				for(var/mob/listener as anything in hearing_mobs)
					update_music_voice_listener(listener, text2num(channel), level)
				music_voice_levels_sent[channel] = level
			continue
		for(var/mob/listener as anything in hearing_mobs)
			if(listener.client)
				listener.stop_sound_channel(text2num(channel))
		channels_playing -= channel
		channels_idle += channel
		voice_ends -= channel
		voice_levels -= channel
		music_voice_levels_sent -= channel
	trim_idle_channels()

/datum/song/proc/refresh_music_spatial()
	var/list/previous_spatial = listener_spatial
	listener_spatial = list()
	var/turf/parent_source = get_turf(parent)
	if(!parent_source)
		return
	var/list/sources = get_instrument_sources()
	var/list/changed_listeners = list()
	for(var/mob/listener as anything in hearing_mobs)
		if(!listener.client)
			continue
		var/turf/destination = get_turf(listener)
		if(!destination)
			continue
		var/turf/source = music_listener_sources[listener] || parent_source
		if(!(source in sources))
			continue
		var/distance = get_dist_euclidean(source, destination)
		var/stereo = source != parent_source && distance <= CONCERT_STEREO_RADIUS
		var/x = stereo ? 0 : source.x - destination.x
		var/z = stereo ? 0 : source.y - destination.y
		var/preference = (listener.client.prefs.read_preference(/datum/preference/numeric/volume/sound_instruments) || 0) / 100
		var/gain = get_file_source_gain(distance, sources[source], source) * preference
		var/list/spatial = previous_spatial[listener]
		if(!spatial || spatial["client"] != listener.client || spatial["x"] != x || spatial["z"] != z || spatial["gain"] != gain || spatial["range"] != instrument_range)
			spatial = list("client" = listener.client, "x" = x, "z" = z, "gain" = gain, "range" = instrument_range, "preference" = preference)
			changed_listeners += listener
		spatial["origin"] = source
		spatial["source_gain"] = sources[source]
		spatial["stereo"] = stereo
		listener_spatial[listener] = spatial
	for(var/channel in channels_playing)
		var/level = voice_levels[channel] ? get_output_volume(volume * voice_levels[channel]) : (channels_playing[channel] * 0.01 * get_output_volume(volume * using_instrument.volume_multiplier))
		if(playback_mode == "sequence" && voice_levels[channel])
			level *= channels_playing[channel] * 0.01
		var/list/listeners = ((channel in music_voice_levels_sent) && music_voice_levels_sent[channel] == level) ? changed_listeners : listener_spatial
		for(var/mob/listener as anything in listeners)
			update_music_voice_listener(listener, text2num(channel), level)
		music_voice_levels_sent[channel] = level

/datum/song/proc/update_music_voice_listener(mob/listener, channel, level)
	var/list/spatial = listener_spatial[listener]
	if(!spatial || !listener.client || spatial["client"] != listener.client)
		return
	var/sound/update = sound(null, channel = channel)
	update.status = SOUND_UPDATE
	update.volume = level * spatial["gain"]
	update.x = spatial["x"]
	update.z = spatial["z"]
	update.y = 0
	update.falloff = instrument_range
	SEND_SOUND(listener, update)

#undef MUSIC_SEQUENCE_MAX_NOTES
#undef MUSIC_SEQUENCE_MAX_SECONDS
