/// Account-wide rolling cooldown. SQL performs timestamp arithmetic and compare-and-set.
/datum/antag_coin_store

/datum/antag_coin_store/proc/server_id()
	return "[CONFIG_GET(string/serversqlname)]:[world.port]"

/// Recover unfinished operations belonging to an older process on this server only.
/datum/antag_coin_store/proc/recover()
	if(!SSdbcore.IsConnected() || isnull(GLOB.round_id))
		return FALSE
	var/datum/db_query/query = SSdbcore.NewQuery({"
		UPDATE [format_table_name("antag_coin_accounts")] AS coin
		LEFT JOIN [format_table_name("round")] AS game_round ON game_round.id = coin.round_id
		SET coin.next_available = IF(game_round.start_datetime IS NULL, coin.previous_available, coin.next_available),
			coin.state = IF(game_round.start_datetime IS NULL, 'refunded', 'used')
		WHERE coin.state = 'pending' AND coin.server_id = :server_id AND coin.round_id <> :round_id
	"}, list("server_id" = server_id(), "round_id" = GLOB.round_id))
	var/success = query.Execute()
	qdel(query)
	return success

/// Null means unavailable storage; a missing account has never spent a coin.
/datum/antag_coin_store/proc/read_account(player_ckey)
	if(!SSdbcore.IsConnected())
		return null
	var/datum/db_query/query = SSdbcore.NewQuery({"
		SELECT GREATEST(CAST(next_available AS SIGNED) - UNIX_TIMESTAMP(), 0), state, request_id
		FROM [format_table_name("antag_coin_accounts")] WHERE ckey = :ckey
	"}, list("ckey" = player_ckey))
	if(!query.Execute())
		qdel(query)
		return null
	var/list/result = list("remaining" = 0, "pending" = FALSE)
	if(query.NextRow())
		result["remaining"] = text2num("[query.item[1]]")
		result["pending"] = query.item[2] == "pending"
		result["request_id"] = query.item[3]
	qdel(query)
	return result

/// An atomic conditional update prevents concurrent use on different servers, too.
/datum/antag_coin_store/proc/claim(datum/antag_coin_request/request)
	var/datum/db_query/create_account = SSdbcore.NewQuery({"
		INSERT IGNORE INTO [format_table_name("antag_coin_accounts")] (ckey) VALUES (:ckey)
	"}, list("ckey" = request.player_ckey))
	if(!create_account.Execute())
		qdel(create_account)
		return FALSE
	qdel(create_account)
	var/datum/db_query/query = SSdbcore.NewQuery({"
		UPDATE [format_table_name("antag_coin_accounts")]
		SET previous_available = next_available, next_available = UNIX_TIMESTAMP() + :cooldown,
			approved_at = UNIX_TIMESTAMP(), request_id = :request_id, state = 'pending',
			server_id = :server_id, round_id = :round_id
		WHERE ckey = :ckey AND next_available <= UNIX_TIMESTAMP() AND state <> 'pending'
	"}, list(
		"ckey" = request.player_ckey,
		"cooldown" = ANTAG_COIN_COOLDOWN_SECONDS,
		"request_id" = request.id,
		"server_id" = server_id(),
		"round_id" = GLOB.round_id,
	))
	var/success = query.Execute() && query.affected == 1
	qdel(query)
	return success

/// Safe to retry after a timeout: only this pending request can be refunded.
/datum/antag_coin_store/proc/refund(datum/antag_coin_request/request)
	return resolve_request(request, TRUE)

/datum/antag_coin_store/proc/commit(datum/antag_coin_request/request)
	return resolve_request(request, FALSE)

/datum/antag_coin_store/proc/resolve_request(datum/antag_coin_request/request, refund)
	if(!SSdbcore.IsConnected())
		return FALSE
	var/datum/db_query/query = SSdbcore.NewQuery({"
		UPDATE [format_table_name("antag_coin_accounts")]
		SET next_available = IF(:refund, previous_available, next_available), state = :state
		WHERE ckey = :ckey AND request_id = :request_id AND state = 'pending'
	"}, list("refund" = refund, "state" = refund ? "refunded" : "used", "ckey" = request.player_ckey, "request_id" = request.id))
	if(!query.Execute())
		qdel(query)
		return FALSE
	qdel(query)
	// A zero-row update may be an already completed retry or a claim that never happened.
	var/list/account = read_account(request.player_ckey)
	return !isnull(account) && (!account["pending"] || account["request_id"] != request.id)
