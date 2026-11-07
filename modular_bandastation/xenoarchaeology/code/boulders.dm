/// Крупная находка использует те же проверки глубины, блокировки и инструменты, что и малый образец.
/obj/item/xenoarch/strange_rock/boulder
	name = "archaeological boulder"
	desc = "Крупный фрагмент породы с древним устройством внутри. Перед извлечением возьмите керн, определите требуемое поле и стабилизируйте находку."
	icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/mining.dmi'
	icon_state = "boulder1"
	w_class = WEIGHT_CLASS_GIGANTIC
	anchored = TRUE
	density = TRUE
	interaction_flags_item = NONE
	/// Стабилизация сохраняет устройство при извлечении.
	var/stabilised = FALSE
	/// Повторное переключение полей не должно давать бесконечный опыт.
	var/stabilization_experience_awarded = FALSE
	/// Индекс поля; в керн копируются только значения, не ссылка на валун.
	var/stabilising_field
	/// Идентификатор связывает керн, отчёт и валун.
	var/artifact_id
	/// Возраст в годах.
	var/artifact_age
	/// Тип крупной награды, выбранный до начала раскопки.
	var/artifact_type

/obj/item/xenoarch/strange_rock/boulder/Initialize(mapload)
	. = ..()
	icon_state = "boulder[rand(1, 4)]"
	item_depth = rand(25, 200)
	max_depth = item_depth + rand(0, 30)
	safe_depth = 30
	dug_depth = 0
	hidden_item = null
	stabilising_field = rand(1, 8)
	artifact_id = "[pick("Каппа", "Сигма", "Бета", "Омега", "Гамма", "Альфа")]-[rand(1000, 9999)]"
	artifact_age = rand(1000, 9000000000)
	artifact_type = pick_weight(list(
		/obj/machinery/power/supermatter_crystal/shard = 10,
		/obj/structure/constructshell = 150,
		/obj/machinery/xenoartifact/bluespace_crystal = 200,
		/obj/machinery/power/xenoarch_crystal = 200,
		/obj/machinery/xenoartifact/cloner = 200,
		/obj/machinery/xenoartifact/replicator = 200,
		/obj/machinery/xenoartifact = 2000,
		/obj/vehicle/sealed/mecha/reticence/loaded/xenoarch = 25,
		/obj/vehicle/sealed/mecha/odysseus/xenoarch = 25,
		/obj/vehicle/sealed/mecha/savannah_ivanov/xenoarch = 25,
		/obj/vehicle/sealed/mecha/durand/xenoarch = 25,
	))

/obj/item/xenoarch/strange_rock/boulder/examine(mob/user)
	. = ..()
	. += span_notice("Метка: [artifact_id]. Прикрепите GPS-метку сканером минералов. Для анализа поля нужен керн и спектрометр.")

/// Выдача награды происходит только здесь; удаление или уборка карты не создаёт новых машин.
/obj/item/xenoarch/strange_rock/boulder/try_uncover()
	if(QDELETED(src) || resolved)
		return FALSE
	if(dug_depth != item_depth)
		return ..()
	resolved = TRUE
	if(stabilised || prob(50))
		var/obj/artifact = new artifact_type(drop_location())
		if(!stabilised && !QDELETED(artifact))
			artifact.update_integrity(10)
	qdel(src)
	return TRUE

/obj/item/xenoarch/strange_rock/boulder/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/mining_scanner) || istype(tool, /obj/item/t_scanner/adv_mining_scanner))
		if(!can_work(user, tool))
			return ITEM_INTERACT_BLOCKING
		if(!GetComponent(/datum/component/gps))
			AddComponent(/datum/component/gps, "[artifact_id]: археологический валун")
		balloon_alert(user, "установлена GPS-метка")
		return ITEM_INTERACT_SUCCESS
	if(istype(tool, /obj/item/xenoarch/core_sampler))
		var/obj/item/xenoarch/core_sampler/sampler = tool
		if(sampler.sample_data || !can_work(user, tool) || working)
			return ITEM_INTERACT_BLOCKING
		sampler.sample_data = list("id" = artifact_id, "age" = artifact_age, "field" = stabilising_field)
		sampler.update_appearance()
		balloon_alert(user, "керн извлечён")
		return ITEM_INTERACT_SUCCESS
	if(istype(tool, /obj/item/xenoarch/stabilizer))
		var/obj/item/xenoarch/stabilizer/stabilizer = tool
		var/field = stabilizer.selected_field
		if(!(field in 1 to 8))
			balloon_alert(user, "выберите поле!")
			return ITEM_INTERACT_BLOCKING
		var/speed = user.mind?.get_skill_modifier(/datum/skill/xenoarchaeology, SKILL_SPEED_MODIFIER) || 1
		if(work(user, tool, 5 SECONDS * speed) && stabilizer.selected_field == field)
			stabilised = field == stabilising_field
			if(stabilised && !stabilization_experience_awarded)
				stabilization_experience_awarded = TRUE
				user.mind?.adjust_experience(/datum/skill/xenoarchaeology, 10)
			balloon_alert(user, "поле применено")
		return ITEM_INTERACT_SUCCESS
	if(istype(tool, /obj/item/pickaxe))
		if(work(user, tool, 2.5 SECONDS))
			try_dig(25)
		return ITEM_INTERACT_SUCCESS
	return ..()

/// Керн хранит снимок измерений и не удерживает валун после удаления.
/obj/item/xenoarch/core_sampler
	name = "archaeological core sampler"
	desc = "Одноразовый керноотборник. Примените к археологическому валуну, затем вставьте в спектрометр."
	icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/tools.dmi'
	icon_state = "sampler_empty"
	/// Снимок идентификатора, возраста и требуемого поля.
	var/list/sample_data

/obj/item/xenoarch/core_sampler/examine(mob/user)
	. = ..()
	if(sample_data)
		. += span_notice("Загружен керн: [sample_data["id"]].")

/obj/item/xenoarch/stabilizer
	name = "archaeological anomaly stabilizer"
	desc = "Проектор стабилизирующего поля. Активируйте в руке и выберите поле из отчёта спектрометра."
	icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/tools.dmi'
	icon_state = "anoscanner_borg"
	/// Индекс выбранного поля; ноль означает отсутствие настройки.
	var/selected_field = 0
	/// Терминология исходного прибора сохранена в русском переводе.
	var/static/list/fields = list("Дифракционный углекислотный лазер", "Азотное трассирующее поле", "Облако калиевого хладагента", "Ртутная дисперсионная волна", "Проводящее поле железных пластин", "Кальциевый бинарный деоксидатор", "Диффузионное излучение хлора", "Насыщенное фороном поле")

/obj/item/xenoarch/stabilizer/attack_self(mob/user, list/modifiers)
	var/field = tgui_input_list(user, "Выберите стабилизирующее поле", "Стабилизатор", fields)
	if(QDELETED(src) || QDELETED(user) || !user.is_holding(src) || !user.can_perform_action(src, NEED_DEXTERITY|NEED_HANDS))
		return
	if(field in fields)
		selected_field = fields.Find(field)

/// Крупные включения имеют отдельную долю, а typed mineral_type остаётся пустым.
/turf/closed/mineral/xenoarchaeology
	/// Выбрано один раз при создании породы, до любой попытки добычи.
	var/contains_artifact = FALSE

/turf/closed/mineral/xenoarchaeology/Initialize(mapload)
	. = ..()
	contains_artifact = prob(50)
	if(contains_artifact)
		AddElement(/datum/element/point_of_interest)

/obj/item/xenoarch/core_sampler/update_icon_state()
	. = ..()
	icon_state = sample_data ? "sampler" : "sampler_empty"
