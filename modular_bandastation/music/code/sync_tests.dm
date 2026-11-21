/// OGG sync requires bilateral consent and never replaces the follower's track or cues.
/datum/unit_test/music_ogg_unison
	parent_type = /datum/unit_test/music_with_test_minds

/datum/unit_test/music_ogg_unison/Run()
	var/datum/job/musician = allocate(/datum/job/donor/musician)
	var/list/players = list()
	var/list/songs = list()
	for(var/index in 1 to 2)
		var/mob/living/carbon/human/consistent/player = allocate_player()
		player.mind.assigned_role = musician
		var/obj/item/instrument/guitar/instrument = allocate(/obj/item/instrument/guitar, run_loc_floor_bottom_left)
		if(!player.put_in_active_hand(instrument))
			Fail("The OGG fixture could not hold its instrument.", __FILE__, __LINE__)
			return
		players += player
		songs += instrument.song
	var/datum/song/leader = songs[1]
	var/datum/song/follower = songs[2]
	leader.playback_mode = "file"
	leader.file_track = 'sound/items/bikehorn.ogg'
	leader.file_track_length = 60 SECONDS
	follower.playback_mode = "file"
	follower.file_track = 'sound/items/barcodebeep.ogg'
	follower.file_track_length = 30 SECONDS
	follower.file_track_hash = "own-track"
	var/list/own_cues = list(list("time" = 1, "text" = "Own lyrics"))
	follower.song_cues = own_cues
	for(var/list/consent as anything in list(list(FALSE, TRUE), list(TRUE, FALSE), list(TRUE, TRUE)))
		leader.auto_unison_enabled = consent[1]
		follower.auto_unison_enabled = consent[2]
		leader.start_playing(players[1])
		if(!leader.playing)
			Fail("The OGG leader did not start through start_playing.", __FILE__, __LINE__)
			return
		if(follower.playing != (consent[1] && consent[2]))
			Fail("OGG unison ignored bilateral consent ([consent[1]]/[consent[2]]).", __FILE__, __LINE__)
		if(follower.playing && (follower.file_track != 'sound/items/barcodebeep.ogg' || follower.song_cues != own_cues || follower.file_track_hash != "own-track" || follower.file_track_finish_time != follower.playback_started_at + 30 SECONDS))
			Fail("OGG unison replaced the follower's own track, lyrics or duration.", __FILE__, __LINE__)
		leader.stop_playing()
		follower.stop_playing()
	if(leader.using_sound_channels || follower.using_sound_channels)
		Fail("Stopping OGG unison did not release its allocated channels.", __FILE__, __LINE__)
	var/obj/item/instrument/follower_instrument = follower.parent
	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack, run_loc_floor_bottom_left)
	follower_instrument.forceMove(bag)
	leader.start_playing(players[1])
	if(follower.playing)
		Fail("OGG unison started an instrument inside a bag.", __FILE__, __LINE__)
	leader.stop_playing()

/// MIDI attacks between two server ticks must not lose their entire note duration.
/datum/unit_test/music_midi_tick_window
	parent_type = /datum/unit_test/music_with_test_minds

/datum/unit_test/music_midi_tick_window/Run()
	var/mob/living/carbon/human/consistent/player = allocate_player()
	player.mind.assigned_role = allocate(/datum/job/donor/musician)
	var/obj/item/instrument/soundhand_metal_guitar/instrument = allocate(/obj/item/instrument/soundhand_metal_guitar, run_loc_floor_bottom_left)
	if(!player.put_in_active_hand(instrument))
		return Fail("The MIDI fixture could not hold its instrument.", __FILE__, __LINE__)
	var/datum/song/song = instrument.song
	var/frame = max(world.tick_lag, SSinstruments.wait) / (1 SECONDS)
	var/duration = frame / 4
	var/list/document = list("version" = 1, "title" = "Short attack", "notes" = list(list("time" = frame / 2, "duration" = duration, "key" = 60, "velocity" = 100, "channel" = 0, "track" = 0)), "tempos" = list(list("time" = 0, "bpm" = 120)), "tracks" = list(list("id" = 0, "name" = "Guitar")))
	if(!song.load_sequence(document))
		return Fail("The short MIDI document was rejected.", __FILE__, __LINE__)
	song.playback_mode = "sequence"
	song.start_playing(player)
	if(!song.playing)
		return Fail("The short MIDI did not start.", __FILE__, __LINE__)
	// No client is needed to check the real scheduler and voice allocation; packet delivery is separate.
	song.hearing_mobs[player] = 0
	song.last_hearcheck = world.time
	song.playback_started_at = world.time - frame SECONDS
	song.process(SSinstruments.wait)
	if(!song.playing || length(song.voice_ends) != 1)
		return Fail("A short MIDI attack between ticks was dropped or stopped at the nominal score end.", __FILE__, __LINE__)
	var/channel = song.voice_ends[1]
	if(abs(song.voice_ends[channel] - world.time - duration SECONDS) > 0.001)
		return Fail("Ordinary tick quantization shortened a MIDI attack.", __FILE__, __LINE__)
	song.stop_playing()
	// A long stall must not replay the entire expired backlog at once.
	song.start_playing(player)
	song.hearing_mobs[player] = 0
	song.last_hearcheck = world.time
	song.playback_started_at = world.time - 10 SECONDS
	song.process(SSinstruments.wait)
	if(song.playing || length(song.voice_ends))
		Fail("A long-expired MIDI attack was replayed after a server stall.", __FILE__, __LINE__)

/// Capture the envelope output boundary without requiring a connected audio client.
/datum/song/handheld/music_envelope_test
	var/list/dispatched_levels = list()

/datum/song/handheld/music_envelope_test/update_music_voice_listener(mob/listener, channel, level)
	dispatched_levels += level
	return ..()

/// A short bass note must receive intermediate decay updates between slow spatial passes.
/datum/unit_test/music_notes_envelope
	parent_type = /datum/unit_test/music_with_test_minds

/datum/unit_test/music_notes_envelope/Run()
	var/mob/living/carbon/human/consistent/player = allocate_player()
	player.mind.assigned_role = allocate(/datum/job/donor/musician)
	var/obj/item/instrument/soundhand_bass_guitar/instrument = allocate(/obj/item/instrument/soundhand_bass_guitar, run_loc_floor_bottom_left)
	if(!player.put_in_active_hand(instrument))
		return Fail("The bass fixture could not hold its instrument.", __FILE__, __LINE__)
	var/datum/song/handheld/music_envelope_test/song = allocate(/datum/song/handheld/music_envelope_test, instrument, list("cshbassgt"))
	song.lines = list("C4-D4,E4")
	song.full_sustain_held_note = FALSE
	song.start_playing(player)
	song.hearing_mobs[player] = 0
	song.last_hearcheck = world.time
	song.process_song(0)
	if(length(song.channels_playing) != 2)
		return Fail("The bass chord did not allocate two independent voices.", __FILE__, __LINE__)
	song.process_decay(1)
	if(length(song.dispatched_levels) != 2)
		return Fail("Notes did not emit intermediate decay before the next spatial refresh.", __FILE__, __LINE__)
	for(var/channel in song.channels_playing)
		if(abs(song.channels_playing[channel] - 80) > 0.001)
			Fail("The original half-second bass envelope changed.", __FILE__, __LINE__)
	song.stop_playing()

/// Sampled MIDI note-off must fade its voice and preserve releases across a repeat.
/datum/unit_test/music_midi_release
	parent_type = /datum/unit_test/music_with_test_minds

/datum/unit_test/music_midi_release/Run()
	var/mob/living/carbon/human/consistent/player = allocate_player()
	player.mind.assigned_role = allocate(/datum/job/donor/musician)
	var/obj/item/instrument/guitar/instrument = allocate(/obj/item/instrument/guitar, run_loc_floor_bottom_left)
	if(!player.put_in_active_hand(instrument))
		return Fail("The release fixture could not hold its instrument.", __FILE__, __LINE__)
	var/datum/song/handheld/music_envelope_test/song = allocate(/datum/song/handheld/music_envelope_test, instrument, list("cshbassgt"))
	if(!song.load_sequence(list("version" = 1, "title" = "Release", "notes" = list(list("time" = 0, "duration" = 1, "key" = 48, "velocity" = 100, "channel" = 0, "track" = 0)), "tempos" = list(list("time" = 0, "bpm" = 120)), "tracks" = list(list("id" = 0, "name" = "Bass")))))
		return Fail("The release fixture document was rejected.", __FILE__, __LINE__)
	song.playback_mode = "sequence"
	song.start_playing(player)
	song.hearing_mobs[player] = 0
	song.last_hearcheck = world.time
	song.process_sequence()
	if(length(song.voice_ends) != 1)
		return Fail("The MIDI attack did not allocate its voice.", __FILE__, __LINE__)
	var/channel = song.voice_ends[1]
	var/initial_level = song.get_output_volume(song.volume * song.voice_levels[channel])
	// Place the real voice inside its release interval without yielding to unrelated subsystems.
	song.voice_ends[channel] = world.time - MUSIC_MIDI_RELEASE / 2
	song.process_sequence_voices()
	if(!(channel in song.channels_playing) || song.channels_playing[channel] <= 0 || song.channels_playing[channel] >= 100 || length(song.dispatched_levels) != 1)
		return Fail("MIDI note-off cut the voice instead of releasing it.", __FILE__, __LINE__)
	song.refresh_music_spatial()
	if(song.music_voice_levels_sent[channel] >= initial_level)
		return Fail("A spatial refresh restored a releasing MIDI voice to full gain.", __FILE__, __LINE__)
	song.voice_ends[channel] = world.time - MUSIC_MIDI_RELEASE * 2
	song.process_sequence_voices()
	if(length(song.voice_ends) || length(song.channels_playing))
		return Fail("A released MIDI voice retained its playback state.", __FILE__, __LINE__)
	song.stop_playing()
	// A repeat must overlap releases rather than hard-stop them or delay the score clock.
	song.repeat = 1
	song.start_playing(player)
	song.hearing_mobs[player] = 0
	song.last_hearcheck = world.time
	song.process_sequence()
	channel = song.voice_ends[1]
	song.voice_ends[channel] = world.time
	song.playback_started_at = world.time - 1 SECONDS
	song.process_sequence()
	song.process_sequence()
	if(song.repeat || !(channel in song.channels_playing) || length(song.channels_playing) != 2)
		Fail("The MIDI repeat cut its previous release or failed to start the next attack.", __FILE__, __LINE__)
	song.stop_playing()

/// A received OGG must be registered on the first commit, independent of client-side warm-up.
/datum/unit_test/music_first_ogg_upload
	parent_type = /datum/unit_test/music_with_test_minds

/datum/unit_test/music_first_ogg_upload/Run()
	var/mob/living/carbon/human/consistent/player = allocate_player()
	player.mind.assigned_role = allocate(/datum/job/donor/musician)
	var/obj/item/instrument/guitar/instrument = allocate(/obj/item/instrument/guitar, run_loc_floor_bottom_left)
	var/datum/song/song = instrument.song
	if(!song.set_file_track('sound/items/bikehorn.ogg', player))
		return Fail("The first received OGG was not committed.", __FILE__, __LINE__)
	var/list/data = song.ui_data(player)
	if(length(song.loaded_file_tracks) != 1 || length(data["loaded_file_tracks"]) != 1 || !data["file_track_name"])
		return Fail("The first OGG commit was missing from the library or UI data.", __FILE__, __LINE__)
	var/original = song.file_track
	if(song.set_file_track('sound/items/barcodebeep.ogg', player) || song.file_track != original || length(song.loaded_file_tracks) != 1)
		Fail("An overlapping retry bypassed the cooldown or changed the committed recording.", __FILE__, __LINE__)

/// Cue sheets are reusable across recordings, while timing and lyric limits remain enforced.
/datum/unit_test/music_ogg_cues

/datum/unit_test/music_ogg_cues/Run()
	var/obj/item/instrument/guitar/instrument = allocate(/obj/item/instrument/guitar, run_loc_floor_bottom_left)
	var/datum/song/song = instrument.song
	var/list/document = list("version" = 1, "audio_hash" = "another-track", "cues" = list(list("time" = 0, "text" = "\[Verse\]"), list("time" = 3, "text" = "\[quiet\] First")))
	if(song.load_song_cues(document))
		return Fail("Lyrics imported without a selected OGG.", __FILE__, __LINE__)
	song.file_track = 'sound/items/bikehorn.ogg'
	song.file_track_hash = "current-track"
	song.file_track_length = 10 SECONDS
	if(!song.load_song_cues(document) || length(song.song_cues) != 1 || song.song_cues[1]["text"] != "First" || song.song_cues[1]["time"] != 3)
		return Fail("A reusable cue sheet was rejected or bracketed annotations were not skipped.", __FILE__, __LINE__)
	document.Remove("audio_hash")
	if(!song.load_song_cues(document))
		return Fail("A cue sheet without an audio hash was rejected.", __FILE__, __LINE__)
	var/list/accepted = song.song_cues
	document["cues"] = list(list("time" = 11, "text" = "Too late"))
	if(song.load_song_cues(document) || song.song_cues != accepted)
		Fail("An out-of-range cue replaced the accepted lyrics.", __FILE__, __LINE__)

/// Removing groups must preserve MIDI unison and release the follower on stop.
/datum/unit_test/music_midi_unison
	parent_type = /datum/unit_test/music_with_test_minds

/datum/unit_test/music_midi_unison/Run()
	var/datum/job/musician = allocate(/datum/job/donor/musician)
	var/list/players = list()
	var/list/songs = list()
	for(var/index in 1 to 2)
		var/mob/living/carbon/human/consistent/player = allocate_player()
		player.mind.assigned_role = musician
		var/obj/item/instrument/guitar/instrument = allocate(/obj/item/instrument/guitar, run_loc_floor_bottom_left)
		if(!player.put_in_active_hand(instrument))
			Fail("The MIDI fixture could not hold its instrument.", __FILE__, __LINE__)
			return
		players += player
		songs += instrument.song
		instrument.song.playback_mode = "sequence"
		instrument.song.id = "midi-unison"
		if(!instrument.song.load_sequence(list("version" = 1, "title" = "Own part [index]", "notes" = list(list("time" = 0, "duration" = 60, "key" = 60 + index, "velocity" = 100, "channel" = 0, "track" = 0)), "tempos" = list(list("time" = 0, "bpm" = 120)), "tracks" = list(list("id" = 0, "name" = "Part")))))
			Fail("The MIDI fixture document was rejected.", __FILE__, __LINE__)
			return
	var/datum/song/leader = songs[1]
	var/datum/song/follower = songs[2]
	leader.start_playing(players[1])
	if(!leader.playing || !follower.playing || follower.sequence_master != leader || !(follower in leader.sequence_followers))
		Fail("The legacy ID-based MIDI unison did not start its follower.", __FILE__, __LINE__)
	if(follower.midi_title != "Own part 2")
		Fail("MIDI unison overwrote the follower's saved composition.", __FILE__, __LINE__)
	follower.stop_playing()
	if(follower.sequence_master || (follower in leader.sequence_followers))
		Fail("Stopping MIDI unison retained a follower reference.", __FILE__, __LINE__)
	leader.stop_playing()
