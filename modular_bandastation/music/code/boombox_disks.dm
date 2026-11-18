/** Concert disks share the cassette bay, but keep ownership of their recordings. */
/obj/item/boombox
	/// Inserted physical disk, mutually exclusive with the original cassette.
	var/obj/item/concert_disk/music_disk
	/// Borrowed only while a disk track is playing.
	var/datum/track/concert_recording/disk_track
	/// Lazily created disk engine; it owns channels, never recordings.
	var/datum/song/concert/boombox/disk_song

/obj/item/boombox/Destroy(force)
	eject_music_disk()
	QDEL_NULL(disk_song)
	QDEL_NULL(music_particles)
	return ..()

/obj/item/boombox/handle_deconstruct(disassembled)
	eject_music_disk()
	return ..()

/obj/item/boombox/examine(mob/user)
	. = ..()
	if(music_disk)
		. -= "It has no tapedeck inside."
		. += span_notice("It contains [music_disk], with [length(music_disk.tracks)] recorded tracks.")

/** Disk audio can play on the floor or in a hand, never inside a bag. */
/obj/item/boombox/proc/disk_source_available()
	if(isturf(loc))
		return TRUE
	var/mob/holder = loc
	return istype(holder) && holder.is_holding(src)

/** Rechecked after every radial/list input before touching the inserted medium. */
/obj/item/boombox/proc/can_use_music_disk(mob/living/user)
	return !QDELETED(src) && !QDELETED(user) && check_menu(user) && user.Adjacent(src) && user.can_perform_action(src, NEED_DEXTERITY) && disk_source_available()

/obj/item/boombox/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/concert_disk))
		if(music_disk || tapedeck)
			balloon_alert(user, "eject first!")
			return ITEM_INTERACT_BLOCKING
		if(!can_use_music_disk(user) || !user.transferItemToLoc(tool, src))
			return ITEM_INTERACT_BLOCKING
		music_disk = tool
		if(!disk_song)
			disk_song = new(src)
			RegisterSignals(src, list(COMSIG_INSTRUMENT_START, COMSIG_INSTRUMENT_END), PROC_REF(on_disk_playback_changed))
		RegisterSignals(music_disk, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING), PROC_REF(on_music_disk_removed))
		update_available_icons()
		balloon_alert(user, "disk inserted")
		playsound(src, 'sound/items/taperecorder/taperecorder_close.ogg', 50, FALSE)
		return ITEM_INTERACT_SUCCESS
	if(music_disk && istype(tool, /obj/item/music_tape))
		balloon_alert(user, "eject first!")
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/item/boombox/update_available_icons()
	. = ..()
	if(music_disk)
		boombox_acts["Eject"] = image(radial_icon_file, "eject")

/obj/item/boombox/display_radial_menu(mob/living/user)
	if(!music_disk)
		return ..()
	if(!can_use_music_disk(user))
		return FALSE
	var/obj/item/concert_disk/disk = music_disk
	var/choice = show_radial_menu(user, src, boombox_acts, radius = 36, require_near = TRUE)
	if(!choice || music_disk != disk || !can_use_music_disk(user))
		return FALSE
	switch(choice)
		if("Play")
			if(active)
				return FALSE
			if(!length(disk.tracks))
				balloon_alert(user, "empty disk!")
				return FALSE
			var/datum/track/concert_recording/track = disk.tracks[1]
			if(length(disk.tracks) > 1)
				var/list/choices = list()
				for(var/index in 1 to length(disk.tracks))
					var/datum/track/concert_recording/recording = disk.tracks[index]
					choices["[index]. [recording.song_name]"] = recording
				var/selected = tgui_input_list(user, "Select a recorded track.", name, choices)
				if(!selected || music_disk != disk || !can_use_music_disk(user))
					return FALSE
				track = choices[selected]
			if(!play_disk_track(track, user))
				return FALSE
		if("Stop")
			stop_music(user)
		if("Eject")
			eject_music_disk(user)
		else
			return FALSE
	playsound(src, 'sound/machines/click.ogg', 40, TRUE)
	return TRUE

/** Public playback consumes only the currently inserted disk's own recording. */
/obj/item/boombox/proc/play_disk_track(datum/track/concert_recording/track, mob/living/user)
	if(!can_use_music_disk(user) || active || QDELETED(track) || QDELETED(music_disk) || music_disk.loc != src || !(track in music_disk.tracks) || !track.song_path || track.song_length <= 0)
		return FALSE
	disk_track = track
	RegisterSignal(track, COMSIG_QDELETING, PROC_REF(on_music_disk_removed))
	disk_song.start_playing(src)
	if(!disk_song.playing && disk_track)
		UnregisterSignal(disk_track, COMSIG_QDELETING)
		disk_track = null
		disk_song.clear_file_track()
	return disk_song.playing

/** The selected track must stay on the disk and the device must stay audible. */
/obj/item/boombox/proc/can_play_music_disk()
	return !QDELETED(music_disk) && music_disk.loc == src && !QDELETED(disk_track) && (disk_track in music_disk.tracks) && disk_source_available()

/obj/item/boombox/stop_music(mob/user)
	disk_song?.stop_playing()
	return ..()

/obj/item/boombox/proc/on_disk_playback_changed()
	SIGNAL_HANDLER
	active = !!disk_song?.playing
	if(!active)
		if(disk_track)
			UnregisterSignal(disk_track, COMSIG_QDELETING)
			disk_track = null
		disk_song?.clear_file_track()
		QDEL_NULL(music_particles)
	else if(!music_particles)
		music_particles = new(src, /particles/musical_notes, PARTICLE_ATTACH_MOB)
	icon_state = active ? "boombox_on" : "boombox"
	update_appearance()
	update_available_icons()

/obj/item/boombox/proc/on_music_disk_removed(datum/source)
	SIGNAL_HANDLER
	if(source == disk_track)
		stop_music()
	else if(QDELETED(source) || music_disk?.loc != src)
		eject_music_disk()

/** Ejection never deletes recordings and does not move a forcibly removed disk. */
/obj/item/boombox/proc/eject_music_disk(mob/living/user)
	if(!music_disk)
		return
	stop_music(user)
	var/obj/item/concert_disk/disk = music_disk
	UnregisterSignal(disk, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
	if(disk_track)
		UnregisterSignal(disk_track, COMSIG_QDELETING)
	disk_track = null
	music_disk = null
	disk_song?.clear_file_track()
	if(!QDELETED(disk) && disk.loc == src && (!user || !user.put_in_active_hand(disk)))
		disk.forceMove(drop_location())
	if(!QDELING(src))
		update_available_icons()

/** Reuse the disk engine's channel allocation, stereo/falloff and jukebox preferences. */
/datum/song/concert/boombox
	volume = 50
	auto_repeat = TRUE
	instrument_range = SOUND_RANGE + MEDIUM_RANGE_SOUND_EXTRARANGE

/datum/song/concert/boombox/start_playing(atom/user)
	var/obj/item/boombox/player = parent
	if(playing || !player.can_play_music_disk())
		return
	playback_mode = "file"
	file_track = player.disk_track.song_path
	file_track_name = player.disk_track.song_name
	file_track_length = player.disk_track.song_length
	start_file_playing(parent)

/datum/song/concert/boombox/should_stop_playing(atom/user)
	var/obj/item/boombox/player = parent
	return QDELETED(player) || !player.can_play_music_disk() ? STOP_PLAYING : NONE

/datum/song/concert/boombox/get_instrument_sources()
	var/list/sources = list()
	var/turf/origin = get_turf(parent)
	if(origin)
		sources[origin] = 1
	return sources
