/// Availability is checked once at initialization, not on every catalogue query.
/datum/controller/subsystem/library
	var/paged_archive_ready = FALSE

/datum/controller/subsystem/library/Initialize()
	refresh_paged_archive()
	return ..()

/// Missing additive schema leaves legacy reads available but never redirects new writes to it.
/datum/controller/subsystem/library/proc/refresh_paged_archive()
	var/previous = paged_archive_ready
	paged_archive_ready = FALSE
	if(!SSdbcore.Connect())
		if(previous)
			library_updated()
		return FALSE
	var/datum/db_query/check = SSdbcore.NewQuery({"
		SELECT COUNT(*) FROM information_schema.tables
		WHERE table_schema = DATABASE() AND table_name IN (:books, :history)
	"}, list("books" = format_table_name("library_paged"), "history" = format_table_name("library_paged_action")))
	if(check.Execute() && check.NextRow())
		paged_archive_ready = text2num(check.item[1]) == 2
	qdel(check)
	if(previous != paged_archive_ready)
		library_updated()
	return paged_archive_ready

/datum/controller/subsystem/library/archive_source(include_content = FALSE)
	if(!paged_archive_ready)
		return ..()
	// Catalogue/count queries must not materialize potentially 2 MiB documents.
	var/columns = "author, title, [include_content ? "content" : "NULL AS content"], category, ckey, datetime, deleted, round_id_created"
	return "(SELECT id, [columns] FROM [..()] UNION ALL SELECT -CAST(id AS SIGNED) AS id, [columns] FROM [format_table_name("library_paged")]) AS book_archive"

/datum/controller/subsystem/library/archive_table(id = null, history = FALSE)
	if(isnull(id) || copytext("[id]", 1, 2) == "-")
		return paged_archive_ready ? format_table_name(history ? "library_paged_action" : "library_paged") : null
	return ..()
