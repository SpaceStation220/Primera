-- Additive migration from fork schema 1.4 or 1.5 to 1.6.
-- Back up first, select the database in your client and apply the deployment
-- prefix to all THREE table names. Existing library/library_action are untouched.
CREATE TABLE IF NOT EXISTS `library_paged` (
	`id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
	`author` VARCHAR(45) NOT NULL,
	`title` VARCHAR(45) NOT NULL,
	`content` MEDIUMTEXT NOT NULL,
	`category` ENUM('Any','Fiction','Non-Fiction','Adult','Reference','Religion') NOT NULL,
	`ckey` VARCHAR(32) NOT NULL DEFAULT 'LEGACY',
	`datetime` DATETIME NOT NULL,
	`deleted` TINYINT UNSIGNED DEFAULT NULL,
	`round_id_created` INT UNSIGNED DEFAULT NULL,
	PRIMARY KEY (`id`),
	KEY `deleted_idx` (`deleted`),
	KEY `idx_lib_del_title` (`deleted`,`title`),
	KEY `idx_lib_search` (`deleted`,`author`,`title`,`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `library_paged_action` (
	`id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
	`book` INT UNSIGNED NOT NULL,
	`reason` LONGTEXT DEFAULT NULL,
	`ckey` VARCHAR(32) NOT NULL DEFAULT '',
	`datetime` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	`action` VARCHAR(11) NOT NULL DEFAULT '',
	`ip_addr` INT UNSIGNED NOT NULL,
	PRIMARY KEY (`id`),
	KEY `book_idx` (`book`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `schema_revision_220` (`major`, `minor`)
SELECT 1, 6
WHERE NOT EXISTS (
	SELECT 1 FROM `schema_revision_220` WHERE `major` > 1 OR (`major` = 1 AND `minor` >= 6)
);
