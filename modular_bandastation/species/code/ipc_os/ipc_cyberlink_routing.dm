/// Only current masks are sent to the client; the canonical path stays on the server.
/datum/ipc_routing_cell
	var/mask
	var/blocked = FALSE
	var/locked = FALSE
	var/output_dir = NONE

/datum/ipc_routing_cell/proc/rotate()
	var/rotated = NONE
	for(var/direction in GLOB.cardinals)
		if(mask & direction)
			rotated |= turn(direction, -90)
	mask = rotated
	if(output_dir)
		output_dir = turn(output_dir, -90)

/// A retained board is independent of an attempt's deadline, authorization and energy debit.
/datum/ipc_routing_board
	var/datum/weakref/target_ref
	var/advanced = FALSE
	var/phase = 1
	var/size
	var/cell_count
	var/list/datum/ipc_routing_cell/cells = list()
	var/list/path = list()
	var/list/required_nodes = list()
	var/list/initial_cells

/datum/ipc_routing_board/New(advanced = FALSE)
	. = ..()
	src.advanced = advanced
	size = advanced ? 8 : 7
	cell_count = size * size
	generate()

/datum/ipc_routing_board/Destroy()
	target_ref = null
	QDEL_LIST(cells)
	cells = null
	path = null
	required_nodes = null
	return ..()

/datum/ipc_routing_board/proc/neighbor(index, direction)
	switch(direction)
		if(NORTH)
			return index > size ? index - size : 0
		if(SOUTH)
			return index <= cell_count - size ? index + size : 0
		if(EAST)
			return index % size ? index + 1 : 0
		if(WEST)
			return (index - 1) % size ? index - 1 : 0
	return 0

/datum/ipc_routing_board/proc/direction_between(first, second)
	for(var/direction in GLOB.cardinals)
		if(neighbor(first, direction) == second)
			return direction
	return NONE

/datum/ipc_routing_board/proc/generate()
	// The fixed straight prefix remains a valid fragment when the second phase locks it.
	for(var/attempt in 1 to 20)
		var/list/parents = list("2" = 1, "3" = 2)
		var/list/visited = list("1" = TRUE, "2" = TRUE, "3" = TRUE)
		var/list/stack = list(3)
		while(length(stack))
			var/current = stack[length(stack)]
			var/list/options = list()
			for(var/direction in GLOB.cardinals)
				var/next = neighbor(current, direction)
				if(next && !visited["[next]"])
					options += next
			if(!length(options))
				stack.Cut(length(stack), length(stack) + 1)
				continue
			var/next = pick(options)
			visited["[next]"] = TRUE
			parents["[next]"] = current
			stack += next
		path = list()
		var/current = cell_count
		while(current)
			path.Insert(1, current)
			current = parents["[current]"]
		if(length(path) <= (advanced ? 48 : 32))
			break
	if(length(path) > (advanced ? 48 : 32))
		path = list()
		for(var/column in 1 to size)
			path += column
		for(var/row in 2 to size)
			path += row * size
	for(var/index in 1 to cell_count)
		var/datum/ipc_routing_cell/cell = new
		cell.mask = pick(NORTH|SOUTH, NORTH|EAST, NORTH|EAST|WEST)
		cells += cell
	for(var/position in 1 to length(path))
		var/index = path[position]
		var/datum/ipc_routing_cell/cell = cells[index]
		cell.mask = (position == 1 ? WEST : direction_between(index, path[position-1])) | (position == length(path) ? EAST : direction_between(index, path[position+1]))
	var/list/outside = list()
	for(var/index in 1 to cell_count)
		if(!(index in path))
			outside += index
	for(var/number in 1 to (advanced ? rand(8,10) : rand(4,6)))
		var/index = pick_n_take(outside)
		var/datum/ipc_routing_cell/cell = cells[index]
		cell.blocked = TRUE
	var/list/inside = path.Copy(4, length(path))
	for(var/number in 1 to (advanced ? rand(4,6) : rand(2,3)))
		var/datum/ipc_routing_cell/cell = cells[pick_n_take(inside)]
		cell.locked = TRUE
	for(var/number in 1 to (advanced ? rand(2,3) : 1))
		var/index = pick_n_take(inside)
		var/datum/ipc_routing_cell/cell = cells[index]
		cell.output_dir = direction_between(index, path[path.Find(index)+1])
	if(advanced)
		required_nodes += path[round(length(path)/2)]
	for(var/datum/ipc_routing_cell/cell as anything in cells)
		if(!cell.locked && !cell.blocked)
			for(var/rotation in 1 to rand(1,3))
				cell.rotate()
	// A valid input always needs its horizontal prefix, so this prevents a solved initial board.
	var/datum/ipc_routing_cell/entry = cells[1]
	entry.mask = NORTH|SOUTH
	initial_cells = cell_data()

/datum/ipc_routing_board/proc/reset_progress()
	if(phase == 2)
		required_nodes.Cut(2)
	phase = 1
	for(var/index in 1 to cell_count)
		var/datum/ipc_routing_cell/cell = cells[index]
		var/list/initial = initial_cells[index]
		cell.mask = initial["mask"]
		cell.locked = initial["locked"]
		cell.output_dir = initial["output"]

/datum/ipc_routing_board/proc/rotate_cell(index)
	if(!isnum(index) || index != round(index) || index < 1 || index > length(cells))
		return FALSE
	var/datum/ipc_routing_cell/cell = cells[index]
	if(cell.blocked || cell.locked)
		return FALSE
	cell.rotate()
	return TRUE

/// Search carries the visited authorization nodes; client assertions are never trusted.
/datum/ipc_routing_board/proc/solved()
	var/datum/ipc_routing_cell/entry = cells[1]
	if(!(entry.mask & WEST))
		return FALSE
	var/list/queue = list(list("index" = 1, "nodes" = 0))
	var/list/visited = list()
	var/all_nodes = (1 << length(required_nodes)) - 1
	while(length(queue))
		var/list/step = queue[1]
		queue.Cut(1,2)
		var/index = step["index"]
		var/nodes = step["nodes"]
		var/required = required_nodes.Find(index)
		if(required)
			nodes |= 1 << (required - 1)
		var/key = "[index]:[nodes]"
		if(visited[key])
			continue
		visited[key] = TRUE
		var/datum/ipc_routing_cell/cell = cells[index]
		if(index == cell_count && (cell.mask & EAST) && nodes == all_nodes)
			return TRUE
		for(var/direction in GLOB.cardinals)
			if(!(cell.mask & direction) || (cell.output_dir && cell.output_dir != direction))
				continue
			var/next = neighbor(index, direction)
			if(!next)
				continue
			var/datum/ipc_routing_cell/other = cells[next]
			var/incoming = turn(direction, 180)
			if(other.blocked || !(other.mask & incoming) || other.output_dir == incoming)
				continue
			queue += list(list("index" = next, "nodes" = nodes))
	return FALSE

/datum/ipc_routing_board/proc/advance_phase()
	if(!advanced || phase != 1 || !solved())
		return FALSE
	phase = 2
	required_nodes += path[length(path)-2]
	for(var/index in 1 to 2)
		var/datum/ipc_routing_cell/cell = cells[index]
		cell.locked = TRUE
	for(var/index in 3 to cell_count)
		var/datum/ipc_routing_cell/cell = cells[index]
		if(!cell.locked && !cell.blocked)
			for(var/rotation in 1 to rand(1,3))
				cell.rotate()
	// Canonical position 3 is rotatable and has two ports: force a required adjustment.
	var/datum/ipc_routing_cell/third = cells[3]
	// Preserve the shape of the path's third cell when forcing it away from its solution.
	third.mask = WEST | direction_between(3, path[4])
	third.rotate()
	return TRUE

/datum/ipc_routing_board/proc/cell_data()
	var/list/data = list()
	for(var/index in 1 to length(cells))
		var/datum/ipc_routing_cell/cell = cells[index]
		data += list(list("index" = index, "mask" = cell.mask, "blocked" = cell.blocked, "locked" = cell.locked, "output" = cell.output_dir, "required" = !!required_nodes.Find(index)))
	return data
