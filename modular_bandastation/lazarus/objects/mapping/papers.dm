// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/obj/item/documents/syndicate/red/lazarus
	name = "'Отчёт касательно проекта ''Лазарь''"
	desc = "Большая часть документов представляет из себя набор бессвязных символов, вероятно, содержащий зашифрованное сообщение. Тем не менее, сопоставив изображения с некоторыми читаемыми заготовками и отрывками из незашифронных писем, вам удаётся понять, что проект \"Лазарь\" представляет из себя целую программу по разработке средств для реанимации мёртвой биоматерии с сохранением сознания. Похоже, Нанотрейзен не брезговали опытами над людьми - большая часть испытуемых страдало от множества мутаций и наростов плоти. Вас тошнит."

/obj/item/paper/lazarus/rod_maint
	name = "Записка"
	default_raw_text = "Я затащил внутрь всё полезное и запер вход. Нельзя позволить чтобы чёртовы колонисты получили доступ к оружию. Я точно видел как у Моргана шла кровь из носа."
	layer = ABOVE_WINDOW_LAYER

/obj/item/paper/lazarus/crusader
	name = "Записка Крестоносца"
	default_raw_text = "Светит мне пусть Крест Святой,\nДревний змий да сгинет злой.\nСатана пускай отыдет,\nСуета в меня - не внидет.\nЗлом меня да не искусит,\nЧашу яда сам да вкусит."

/obj/item/paper/lazarus/ce
	name = "Заметки СЕ"
	default_raw_text = "В последнее время генераторы стали очень быстро выходить из строя. Если раньше их приходилось обслуживать раз в пару недель, то сейчас они могут сломаться раз этак 5 за день. Что вообще происходит там, подземлёй, что давление прыгаёт как ёбанная блоха?"

/obj/item/paper/lazarus/cmo
	name = "Жалоба Хирурга"
	default_raw_text = "Шэф, сегодня уже третий тестер на космо-ковид взорвался у меня в руках. В последний раз и вовсе из обломков тестера вылезла какая-то тварь, которая откусила пациенту ПАЛЕЦ! Если я не получу ответа что вообще происходит сегодня, то уже завтра я пойду жаловаться администратору."

/obj/item/paper/lazarus/blood
	icon_state = "scrap_bloodied"
	show_written_words = FALSE

/obj/item/paper/lazarus/blood/mutant
	name = "Кровавая заметка"
	icon_state = "scrap_bloodied"
	default_raw_text = "Мы заперли там одну из тварей, что вылезла из химика. Несколько наших остались лежать там мёртвые. НИ В КОЕМ СЛУЧАЕ НЕ ОТКРЫВАЙТЕ."
	layer = ABOVE_WINDOW_LAYER

/obj/item/paper/lazarus/blood/cannibals
	name = "Записка от друга"
	icon_state = "scrap_bloodied"
	default_raw_text = "Устроиться здесь было неплохой идеей. Бункер давно заброшен и, судя по слою пыли, никто не появлялся здесь уже пару лет. Тут можно организовать неплохую кухню для наших нужд. Я попросил моего друга угнать сюда мясорубку с ''Рода''. Скоро мы сможем начать.\nУ меня было очередное видение. Великая Мать сказала, что близится час, когда её дети пробудятся. Всё что требуется от нас - насладиться дарованным ею пиром. И её собственной плотью, разумеется.\n(Я сделал фальшивую в том углу возле входа. Пользуйтесь ею вместо основных дверей)."
	layer = ABOVE_WINDOW_LAYER

/obj/item/paper/lazarus/blood/tourist
	name = "Записка последнего туриста"
	icon_state = "scrap_bloodied"
	default_raw_text = "Джелли, Мэтью, простите, я подвёл вас. Я либо погибну в отчайной попытке бегства, подобно вам, либо обращусь в одно из чудовищ. Уж лучше уйти на своих условиях.\n\nПрощайте."

/obj/item/paper/lazarus/map
	parent_type = /obj/item/photo
	name = "Карта колонии \"Перун\""
	desc = "Схематичный план поверхности колонии, напечатанный на дешёвой бумаге. Подземелья и частные убежища не нанесены."
	icon = 'icons/obj/service/bureaucracy.dmi'
	icon_state = "paper"

/obj/item/paper/lazarus/map/Initialize(mapload)
	var/static/datum/picture/colony_picture
	if(isnull(colony_picture))
		colony_picture = new(image = icon('modular_bandastation/lazarus/icons/colony_map.png'), size_x = 1350, size_y = 1181)
	return ..(mapload, colony_picture, datum_name = FALSE, datum_desc = FALSE)

/obj/item/paper/lazarus/map/update_icon_state()
	. = ..()
	icon_state = "paper"

/** Use the native photo's picture resource in a scrollable window large enough for the plan. */
/obj/item/paper/lazarus/map/show(mob/user)
	if(!user.client || (!in_range(src, user) && !isobserver(user)) || user.is_blind() || !user.can_read(src))
		return
	user << browse_rsc(picture.picture_image, "lazarus_colony_map.png")
	var/datum/browser/popup = new(user, "lazarus_colony_map", name, 1400, 1000)
	popup.set_content("<img src='lazarus_colony_map.png' width='1350' height='1181' alt='Карта колонии Перун' />")
	popup.open()
// AI EDIT END
