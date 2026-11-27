/// The room volume slider governs private environmental cues as well as the continuous room tone.
/datum/ipc_os_program/humanity/proc/private_volume()
	if(!private_session() || !body.client?.prefs || HAS_TRAIT(body, TRAIT_DEAF))
		return 0
	return body.client.prefs.read_preference(/datum/preference/numeric/volume/sound_ambience_volume) / 100

/datum/ipc_os_program/humanity/proc/play_cue(file, volume, channel = 0)
	var/gain = private_volume()
	if(gain > 0)
		SEND_SOUND(body, sound(file, volume = volume * gain, channel = channel))

/datum/ipc_os_program/humanity/proc/play_archive_sound()
	var/static/list/cues = list('modular_bandastation/species/sound/ipc/humanity_relay.wav', 'modular_bandastation/species/sound/ipc/humanity_relay.wav', 'modular_bandastation/species/sound/ipc/humanity_echo.wav', 'modular_bandastation/species/sound/ipc/humanity_archive_iv.ogg')
	play_cue(cues[stage], 58)

/datum/ipc_os_program/humanity/proc/sync_ambience()
	var/volume = stage == 4 ? private_volume() * 10 : 0
	if(!volume)
		release_ambience()
		return
	var/client/listener = body.client
	if(!listener.humanity_ambience)
		listener.humanity_ambience = new /datum/humanity_ambience(listener)
	ambience = listener.humanity_ambience
	ambience.owner = src
	ambience.fade_to(volume)

/datum/ipc_os_program/humanity/proc/release_ambience()
	if(ambience?.owner == src)
		ambience.owner = null
		ambience.fade_to(0)
	ambience = null

/client/var/datum/humanity_ambience/humanity_ambience

/// Belongs to the listening client so a fading channel survives a body swap and can be reclaimed.
/datum/humanity_ambience
	var/client/listener
	var/datum/ipc_os_program/humanity/owner
	var/sound/loop_track
	var/volume = 0
	var/target_volume
	var/steps_left
	var/fade_timer

/datum/humanity_ambience/New(client/recipient)
	listener = recipient
	RegisterSignal(listener, COMSIG_QDELETING, PROC_REF(client_gone))
	loop_track = sound('modular_bandastation/species/sound/ipc/humanity_ambient.ogg', repeat = TRUE, channel = CHANNEL_HUMANITY_AMBIENT, volume = 0)
	SEND_SOUND(listener, loop_track)

/datum/humanity_ambience/proc/fade_to(target)
	if(target == target_volume && (fade_timer || volume == target))
		return
	target_volume = target
	steps_left = 5
	if(!fade_timer)
		fade_timer = addtimer(CALLBACK(src, PROC_REF(fade_step)), 3, TIMER_STOPPABLE)

/datum/humanity_ambience/proc/fade_step()
	fade_timer = null
	if(QDELETED(listener))
		qdel(src)
		return
	volume += (target_volume - volume) / steps_left
	steps_left--
	if(!steps_left && !target_volume)
		qdel(src)
		return
	loop_track.volume = volume
	loop_track.status = SOUND_UPDATE
	SEND_SOUND(listener, loop_track)
	if(steps_left)
		fade_timer = addtimer(CALLBACK(src, PROC_REF(fade_step)), 3, TIMER_STOPPABLE)

/datum/humanity_ambience/proc/client_gone()
	SIGNAL_HANDLER
	qdel(src)

/datum/humanity_ambience/Destroy()
	if(fade_timer)
		deltimer(fade_timer)
	if(listener)
		UnregisterSignal(listener, COMSIG_QDELETING)
		if(listener.humanity_ambience == src)
			listener.humanity_ambience = null
			if(!QDELETED(listener))
				SEND_SOUND(listener, sound(null, channel = CHANNEL_HUMANITY_AMBIENT))
	if(owner?.ambience == src)
		owner.ambience = null
	owner = null
	loop_track = null
	listener = null
	return ..()
