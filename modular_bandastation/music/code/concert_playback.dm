/datum/song
	/// Installed stage transmitter, detached before this playback engine is destroyed.
	var/obj/item/circuit_component/concert_master/concert_master
	/// Loudest audible origin per listener, selected only during the spatial pass.
	var/list/music_listener_sources = list()

/datum/song/handheld/New(atom/parent, list/instrument_ids, new_range)
	. = ..()
	// The folded kit is a carrying case; its deployed structure retains the board.
	if(istype(parent, /obj/item/instrument/drumskit_folded))
		return
	if(!parent.GetComponent(/datum/component/shell))
		parent.AddComponent(/datum/component/shell, list(), SHELL_CAPACITY_SMALL)

/datum/song/stationary/New(atom/parent, list/instrument_ids, new_range)
	. = ..()
	if(!parent.GetComponent(/datum/component/shell))
		parent.AddComponent(/datum/component/shell, list(), SHELL_CAPACITY_SMALL)

/** Only a powered master installed alongside this engine may provide external sources. */
/datum/song/proc/get_concert_receivers()
	var/obj/item/concert_remote/remote = concert_master?.remote
	if(remote?.get_song() == src)
		return remote.receivers
	return list()

/** Keep remote changes on the existing spatial cadence rather than scanning for every circuit signal. */
/datum/song/proc/refresh_concert_sources()
	if(playing && world.time >= last_hearcheck + MUSIC_SPATIAL_UPDATE_INTERVAL)
		do_hearcheck()
	update_data_for_all_viewers()
	parent?.update_data_for_all_viewers()

/** External speakers retain their five-tile full-volume plateau. */
/datum/song/proc/get_source_falloff_distance(turf/origin)
	if(origin && origin != get_turf(parent))
		return min(CONCERT_STEREO_RADIUS, max(0, instrument_range - 1))
	return get_sound_falloff_distance()

/** Concert playback borrows disk resources and uses the instrument channel allocator. */
/datum/song/concert
	allowed_instrument_ids = list()
	playback_mode = "file"
	min_volume = 0
	max_sound_channels = 1

/datum/song/concert/start_playing(atom/user)
	var/obj/machinery/concert_player/player = parent
	if(playing || !player.can_play() || !player.selected_track)
		return
	playback_mode = "file"
	file_track = player.selected_track.song_path
	file_track_name = player.selected_track.song_name
	file_track_length = player.selected_track.song_length
	start_file_playing(parent, ismob(user) ? user : null)

/datum/song/concert/should_stop_playing(atom/user)
	var/obj/machinery/concert_player/player = parent
	return QDELETED(player) || !player.can_play() ? STOP_PLAYING : NONE

/datum/song/concert/can_use_advanced_music(atom/user)
	// Only the physical player drives this engine; disk writes use is_music_artist().
	return user == parent && !QDELETED(parent)

/datum/song/concert/get_file_output_volume(base_volume = volume)
	return base_volume

/datum/song/concert/get_sound_falloff_distance()
	return min(CONCERT_STEREO_RADIUS, max(0, instrument_range - 1))

/datum/song/concert/get_listener_volume_multiplier(mob/listener)
	return (listener?.client?.prefs.read_preference(/datum/preference/numeric/volume/sound_jukebox) || 0) / 100

/datum/song/concert/ui_interact(mob/user, datum/tgui/ui)
	parent.ui_interact(user)

/datum/song/concert/authorize_music_action(action, list/params, mob/user)
	return FALSE

/** Coalesce moving receivers into the same maintenance interval as periodic hearing checks. */
/obj/machinery/concert_player/proc/refresh_sources()
	song?.refresh_concert_sources()
