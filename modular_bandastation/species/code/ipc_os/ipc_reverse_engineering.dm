/// Both the deduplication and discounts belong to the station's research state, never a scanner.
/datum/techweb
	var/list/ipc_scanned_types = list()
	var/list/ipc_reverse_discounts = list()

/datum/ipc_os_program/factory/reverse_engineering
	id = "factory_reverse_engineering"
	name = "Протоколы обратной инженерии"
	description = "Осмотрите технологический предмет или машину в пределах трёх тайлов. Исследовательское сканирование занимает 15 секунд и расходует 5% заряда при успехе. Данные автоматически удешевляют связанные доступные технологии на 10%."
	icon = "magnifying-glass"
	builtin_department = "science"
	var/scanning = FALSE

/datum/ipc_os_program/factory/reverse_engineering/start()
	if(!..())
		return FALSE
	RegisterSignal(os.host, COMSIG_MOB_EXAMINATE, PROC_REF(on_examine))
	return TRUE

/datum/ipc_os_program/factory/reverse_engineering/stop()
	if(running && os.host)
		UnregisterSignal(os.host, COMSIG_MOB_EXAMINATE)
	return ..()

/datum/ipc_os_program/factory/reverse_engineering/proc/on_examine(mob/source, atom/target)
	SIGNAL_HANDLER
	if(scanning || !running || (!isitem(target) && !ismachinery(target)))
		return
	var/datum/techweb/science/research = locate(/datum/techweb/science) in SSresearch.techwebs
	if(!valid_scan(target, research, activation_id))
		return
	scanning = TRUE
	INVOKE_ASYNC(src, PROC_REF(scan), target, research, activation_id)

/datum/ipc_os_program/factory/reverse_engineering/proc/scan_nodes(atom/target, datum/techweb/research)
	var/list/nodes = list()
	if(QDELETED(target) || QDELETED(research) || research.ipc_scanned_types[target.type])
		return nodes
	var/list/linked_nodes = SSresearch.techweb_unlock_items[target.type]
	linked_nodes = linked_nodes ? linked_nodes.Copy() : list()
	var/design_item = target.type
	if(ismachinery(target))
		var/obj/machinery/machine = target
		design_item = machine.circuit?.type
	for(var/design_path in SSresearch.item_to_design[design_item])
		var/datum/design/design = SSresearch.techweb_designs[design_path]
		linked_nodes |= design.unlocked_by
	for(var/node_path in linked_nodes)
		var/datum/techweb_node/node = SSresearch.techweb_nodes[node_path]
		if(node && research.available_nodes[node_path] && !research.hidden_nodes[node_path] && !research.researched_nodes[node_path] && !research.ipc_reverse_discounts[node_path] && research.have_experiments_for_node(node))
			nodes += node_path
	return nodes

/datum/ipc_os_program/factory/reverse_engineering/proc/valid_scan(atom/target, datum/techweb/research, activation)
	var/turf/target_turf = get_turf(target)
	return !QDELETED(src) && running && activation_id == activation && os?.can_use(os.host) && !QDELETED(target) && !QDELETED(research) && target_turf?.z == os.host.z && get_dist(os.host, target_turf) <= 3 && os.host.nutrition >= os.host.ipc_charge_capacity() * 0.05 && length(scan_nodes(target, research))

/datum/ipc_os_program/factory/reverse_engineering/proc/scan(atom/target, datum/techweb/research, activation)
	if(!valid_scan(target, research, activation))
		scanning = FALSE
		return
	if(do_after(os.host, 15 SECONDS, target, timed_action_flags = IGNORE_SLOWDOWNS|IGNORE_TARGET_LOC_CHANGE, extra_checks = CALLBACK(src, PROC_REF(valid_scan), target, research, activation), ipc_fixed_duration = TRUE) && valid_scan(target, research, activation))
		var/list/nodes = scan_nodes(target, research)
		// No yield between the shared once-per-type reservation, charge debit and discount commit.
		research.ipc_scanned_types[target.type] = TRUE
		var/obj/item/organ/heart/ipc/battery = os.working_battery()
		battery.adjust_charge(-os.host.ipc_charge_capacity() * 0.05)
		var/list/names = list()
		for(var/node_path in nodes)
			research.ipc_reverse_discounts[node_path] = TRUE
			var/datum/techweb_node/node = SSresearch.techweb_nodes[node_path]
			names += node.display_name
		to_chat(os.host, span_notice("Данные получены. Скидка 10% предоставлена технологиям: [english_list(names)]."))
	scanning = FALSE
