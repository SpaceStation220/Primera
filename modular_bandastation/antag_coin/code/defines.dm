#ifndef ANTAG_COIN_COOLDOWN_SECONDS
#define ANTAG_COIN_COOLDOWN_SECONDS (168 * 60 * 60)
#define ANTAG_COIN_REQUEST_TIMEOUT (30 SECONDS)
#define ANTAG_COIN_PENDING "pending"
#define ANTAG_COIN_APPROVING "approving"
#define ANTAG_COIN_APPROVED "approved"
#define ANTAG_COIN_CLOSED "closed"

GLOBAL_DATUM_INIT(antag_coins, /datum/antag_coin_manager, new)
#endif
