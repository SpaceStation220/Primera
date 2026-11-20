/// Owns the temporary characters and their role references for music tests.
/datum/unit_test/music_with_test_minds
	abstract_type = /datum/unit_test/music_with_test_minds

/datum/unit_test/music_with_test_minds/Destroy()
	for(var/mob/living/carbon/human/player in allocated)
		var/datum/mind/test_mind = player.mind
		if(test_mind in allocated)
			player.mind = null
			test_mind.assigned_role = null
	return ..()

/// Create a body and mind owned by the test without registering a round participant.
/datum/unit_test/music_with_test_minds/proc/allocate_player()
	var/mob/living/carbon/human/consistent/player = allocate(/mob/living/carbon/human/consistent)
	player.mind = allocate(/datum/mind)
	return player

/// Profession eligibility and the final boundary of a delayed document transfer.
/datum/unit_test/musician_access
	parent_type = /datum/unit_test/music_with_test_minds

/datum/unit_test/musician_access/Run()
	var/datum/job/musician = allocate(/datum/job/donor/musician)
	var/datum/client_interface/player_client = allocate(/datum/client_interface)
	player_client.donator_level = DONATOR_TIER_4
	if(musician.can_access_donor_job(player_client))
		Fail("T4 unlocked Musician.", __FILE__, __LINE__)
	player_client.donator_level = DONATOR_TIER_5
	if(!musician.can_access_donor_job(player_client))
		Fail("T5 did not unlock Musician.", __FILE__, __LINE__)
	var/obj/item/instrument/guitar/instrument = allocate(/obj/item/instrument/guitar, run_loc_floor_bottom_left)
	var/datum/song/song = instrument.song
	var/mob/living/carbon/human/consistent/player = allocate_player()
	var/list/ordinary_ui = song.ui_data(player)
	if(!islist(ordinary_ui["lines"]) || !("advanced_music_access" in ordinary_ui) || ordinary_ui["advanced_music_access"])
		Fail("The modular UI lost base song data or exposed advanced controls to a normal profession.", __FILE__, __LINE__)
	if(song.can_use_advanced_music(player))
		Fail("A normal profession unlocked advanced music.", __FILE__, __LINE__)
	if(song.authorize_music_action("play_music", list("mode" = "midi"), player))
		Fail("A normal profession unlocked Notes playback.", __FILE__, __LINE__)
	if(!song.authorize_music_action("select_music_mode", list("mode" = "midi"), player))
		Fail("Notes were locked for a normal profession.", __FILE__, __LINE__)
	if(song.authorize_music_action("set_sequence_document", list(), player))
		Fail("A forged MIDI action bypassed the profession check.", __FILE__, __LINE__)
	if(song.authorize_music_action("begin_native_music_upload", list(), player) || song.authorize_music_action("read_native_music_upload", list(), player))
		Fail("Native MIDI transport bypassed the profession check.", __FILE__, __LINE__)
	player.mind.assigned_role = musician
	if(!song.can_use_advanced_music(player))
		Fail("Musician did not unlock advanced music.", __FILE__, __LINE__)
	song.lines = list("C4,D4")
	if(!player.put_in_active_hand(instrument))
		return Fail("The access fixture could not hold its instrument.", __FILE__, __LINE__)
	song.start_playing(player)
	if(!song.playing)
		return Fail("Musician could not start Notes.", __FILE__, __LINE__)
	player.mind.assigned_role = null
	song.process(SSinstruments.wait)
	if(song.playing)
		Fail("Notes kept playing after losing the Musician profession.", __FILE__, __LINE__)
	player.mind.assigned_role = musician
	var/list/musician_ui = song.ui_data(player)
	var/list/metadata = song.ui_static_data(player)
	if(!musician_ui["advanced_music_access"] || !islist(metadata["possible_instruments"]) || !islist(metadata["sequence_document"]))
		Fail("The modular UI lost base instrument metadata or the MIDI document.", __FILE__, __LINE__)
	var/raw = json_encode(list("version" = 1, "title" = "Forbidden upload", "notes" = list(), "tempos" = list(list("time" = 0, "bpm" = 120)), "tracks" = list()))
	var/split = round(length(raw) / 2)
	song.receive_music_document(list("id" = "role-change", "kind" = "sequence", "index" = 0, "count" = 2, "part" = copytext(raw, 1, split)), player)
	if(song.music_document_upload?["next"] != 1)
		Fail("The first upload part was not accepted.", __FILE__, __LINE__)
	player.mind.assigned_role = null
	song.receive_music_document(list("id" = "role-change", "kind" = "sequence", "index" = 1, "count" = 2, "part" = copytext(raw, split)), player)
	if(song.music_document_upload?["state"] != "error")
		Fail("A changed profession did not reject the final upload.", __FILE__, __LINE__)
	if(song.midi_title == "Forbidden upload")
		Fail("The rejected upload changed the composition.", __FILE__, __LINE__)

/// Notes imports use the bounded transfer without requiring a donor profession.
/datum/unit_test/music_notes_transfer/Run()
	var/mob/living/carbon/human/consistent/player = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/instrument/guitar/instrument = allocate(/obj/item/instrument/guitar)
	var/datum/song/song = instrument.song
	var/text = repeat_string(200, "[repeat_string(66, "C4,")]C\n")
	if(length_char(text) != 40000)
		return Fail("Notes fixture must contain exactly 40000 characters.", __FILE__, __LINE__)
	if(!song.authorize_music_action("upload_music_document", list("kind" = "notes"), player))
		return Fail("Ordinary players cannot import Notes.", __FILE__, __LINE__)
	if(!song.authorize_music_action("begin_native_music_upload", list("kind" = "notes"), player))
		return Fail("Ordinary players cannot use native Notes import.", __FILE__, __LINE__)
	song.music_document_upload = list("kind" = "sequence")
	if(song.authorize_music_action("read_native_music_upload", list("kind" = "notes"), player))
		return Fail("A forged Notes kind bypassed native MIDI access.", __FILE__, __LINE__)
	song.music_document_upload = list("kind" = "notes")
	if(!song.authorize_music_action("read_native_music_upload", list(), player))
		return Fail("Ordinary players cannot finish native Notes import.", __FILE__, __LINE__)
	song.music_document_upload = null
	var/raw = json_encode(list("version" = 1, "text" = text))
	var/count = CEILING(length(raw) / 750, 1)
	for(var/index in 0 to count - 1)
		song.receive_music_document(list("id" = "large-notes", "kind" = "notes", "index" = index, "count" = count, "part" = copytext(raw, index * 750 + 1, (index + 1) * 750 + 1)), player)
	if(song.music_document_upload?["state"] != "complete" || song.lines.Join("\n") != text || song.playback_mode != "midi")
		return Fail("A 40000-character Notes transfer was not applied losslessly.", __FILE__, __LINE__)
	var/list/original = song.lines
	if(song.apply_music_document("import_notes_document", json_encode(list("version" = 1, "text" = "[text]C")), player))
		return Fail("Oversized Notes were accepted.", __FILE__, __LINE__)
	if(song.apply_music_document("import_notes_document", json_encode(list("version" = 1, "text" = repeat_string(301, "C"))), player) || song.lines != original)
		return Fail("Invalid Notes replaced the previous composition.", __FILE__, __LINE__)

/// Compact wire notes still pass the normal sequence field and track validation.
/datum/unit_test/music_compact_sequence/Run()
	var/obj/item/instrument/guitar/instrument = allocate(/obj/item/instrument/guitar)
	var/datum/song/song = instrument.song
	var/list/note = list(0.1234, 0.2345, 60, 90, 0, 0)
	var/list/document = list("version" = 1, "note_format" = "tuple-v1", "title" = "Compact", "notes" = list(note), "tempos" = list(list("time" = 0, "bpm" = 92.0001)), "tracks" = list(list("id" = 0, "name" = "Guitar")))
	if(!song.load_sequence(document))
		return Fail("Valid compact MIDI was rejected.", __FILE__, __LINE__)
	var/list/imported = song.midi_notes[1]
	if(imported["time"] != note[1] || imported["duration"] != note[2] || imported["key"] != 60 || imported["velocity"] != 90 || imported["track"] != 0)
		return Fail("Compact note fields or fractional timings changed.", __FILE__, __LINE__)
	note[3] = 128
	if(song.load_sequence(document))
		return Fail("Compact notes bypassed the key bounds.", __FILE__, __LINE__)
	note.len = 5
	if(song.load_sequence(document))
		return Fail("Truncated compact notes were accepted.", __FILE__, __LINE__)

/// A queued action must check whether the real instrument window still allows interaction.
/datum/unit_test/instrument_ui_interactivity/Run()
	var/mob/living/carbon/human/consistent/player = allocate(/mob/living/carbon/human/consistent)
	ADD_TRAIT(player, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/item/instrument/guitar/instrument = allocate(/obj/item/instrument/guitar)
	var/datum/song/song = instrument.song
	var/datum/tgui/ui = allocate(/datum/tgui, player, song, "InstrumentEditor220")
	ui.process_status()
	if(ui.status != UI_INTERACTIVE)
		return Fail("The instrument window must be interactive before the action is queued.", __FILE__, __LINE__)

	player.SetUnconscious(5 SECONDS)
	ui.on_act_message("toggle_multi_sync", list(), ui.state)
	if(song.multi_sync_enabled)
		return Fail("A queued action changed sync settings after the instrument window became non-interactive.", __FILE__, __LINE__)

	player.SetUnconscious(0)
	ui.on_act_message("toggle_multi_sync", list(), ui.state)
	if(!song.multi_sync_enabled)
		Fail("An interactive instrument window could not change sync settings.", __FILE__, __LINE__)
