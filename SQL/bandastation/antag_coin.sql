-- Additive migration. For prefixed installations, replace antag_coin_accounts
-- with <feedback_tableprefix>antag_coin_accounts before applying.
CREATE TABLE IF NOT EXISTS `antag_coin_accounts` (
  `ckey` VARCHAR(32) NOT NULL,
  `next_available` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `previous_available` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `approved_at` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `request_id` VARCHAR(36) NOT NULL DEFAULT '',
  `state` ENUM('unused', 'pending', 'used', 'refunded') NOT NULL DEFAULT 'unused',
  `server_id` VARCHAR(255) NOT NULL DEFAULT '',
  `round_id` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`ckey`),
  KEY `pending_server` (`state`, `server_id`, `round_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `schema_revision_220` (`major`, `minor`) VALUES (1, 4);
