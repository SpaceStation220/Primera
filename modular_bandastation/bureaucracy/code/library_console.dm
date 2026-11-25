/// Publication of paged documents never falls back to the legacy SQL table.
/obj/machinery/computer/libraryconsole/bookmanagement/upload_from_scanner(upload_category)
	var/obj/machinery/libraryscanner/scan = get_scanner()
	if(!scan)
		say("No nearby scanner detected.")
		return
	if(!scan.cache)
		say("No cached book found. Aborting upload.")
		return
	if (!SSdbcore.Connect())
		say("Connection to Archive has been severed. Aborting.")
		return
	var/datum/book_info/book = scan.cache
	if(!book.title)
		say("No title detected. Aborting")
		return
	if(!book.author)
		say("No author detected. Aborting")
		return
	if(!book.has_content())
		say("No content detected. Aborting")
		return
	if(book.photo_count() > MAX_BOOK_PHOTOS)
		say("This book contains more than 10 pictures. Aborting.")
		return
	var/msg = "has uploaded the book titled [book.title], [length(book.content)] signs"
	var/archived_content = book.to_archive()
	if(length(archived_content) > MAX_BOOK_ARCHIVE_LENGTH)
		say("This book exceeds the archive size limit. Aborting.")
		return
	var/archive_table = SSlibrary.archive_table()
	if(!archive_table)
		say("The paged book archive is unavailable. Ask an administrator to apply its database migration.")
		return
	var/datum/db_query/query_library_upload = SSdbcore.NewQuery({"
		INSERT INTO [archive_table] (author, title, content, category, ckey, datetime, round_id_created)
		VALUES (:author, :title, :content, :category, :ckey, Now(), :round_id)
	"}, list("title" = book.title, "author" = book.author, "content" = archived_content, "category" = upload_category, "ckey" = usr.ckey, "round_id" = GLOB.round_id))
	if(!query_library_upload.Execute())
		qdel(query_library_upload)
		say("Database error encountered uploading to Archive")
		return
	usr.log_message(msg, LOG_GAME)
	qdel(query_library_upload)
	library_updated()
	say("Upload Complete. Uploaded title will be available for printing in a moment")
	update_db_info()
