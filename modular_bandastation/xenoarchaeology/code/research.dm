/// Чертежи ручных археологических инструментов для протолатов науки и снабжения.
/datum/design/xenoarch
	abstract_type = /datum/design/xenoarch
	build_type = PROTOLATHE | AWAY_LATHE
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO
	materials = list(
		/datum/material/iron = SMALL_MATERIAL_AMOUNT * 2,
		/datum/material/glass = SMALL_MATERIAL_AMOUNT,
	)
	category = list(RND_CATEGORY_TOOLS + "/Ксеноархеология")

/datum/design/xenoarch/hammer
	name = "archaeological hammer (1 cm)"
	desc = "Снятие слоя породы толщиной 1 см."
	build_path = /obj/item/xenoarch/hammer

/datum/design/xenoarch/hammer/cm2
	name = "archaeological hammer (2 cm)"
	desc = "Снятие слоя породы толщиной 2 см."
	build_path = /obj/item/xenoarch/hammer/cm2

/datum/design/xenoarch/hammer/cm3
	name = "archaeological hammer (3 cm)"
	desc = "Снятие слоя породы толщиной 3 см."
	build_path = /obj/item/xenoarch/hammer/cm3

/datum/design/xenoarch/hammer/cm4
	name = "archaeological hammer (4 cm)"
	desc = "Снятие слоя породы толщиной 4 см."
	build_path = /obj/item/xenoarch/hammer/cm4

/datum/design/xenoarch/hammer/cm5
	name = "archaeological hammer (5 cm)"
	desc = "Снятие слоя породы толщиной 5 см."
	build_path = /obj/item/xenoarch/hammer/cm5

/datum/design/xenoarch/hammer/cm6
	name = "archaeological hammer (6 cm)"
	desc = "Снятие слоя породы толщиной 6 см."
	build_path = /obj/item/xenoarch/hammer/cm6

/datum/design/xenoarch/hammer/cm10
	name = "archaeological hammer (10 cm)"
	desc = "Снятие слоя породы толщиной 10 см."
	build_path = /obj/item/xenoarch/hammer/cm10

/datum/design/xenoarch/brush
	name = "archaeological brush"
	desc = "Точная раскопка и удаление осадочной оболочки находок."
	build_path = /obj/item/xenoarch/brush

/datum/design/xenoarch/measuring_tape
	name = "archaeological measuring tape"
	desc = "Отметка текущей глубины раскопки образца."
	build_path = /obj/item/xenoarch/measuring_tape

/datum/design/xenoarch/scanner
	name = "archaeological handheld scanner"
	desc = "Определение максимальной глубины и безопасного интервала образца."
	build_path = /obj/item/xenoarch/handheld_scanner

/// Стартовый узел даёт полный набор инструментов без зависимости от отложенных машин.
/datum/techweb_node/basic_xenoarch
	display_name = "Базовая ксеноархеология"
	description = "Ручное извлечение древних находок из минеральных образцов."
	node_flags = parent_type::node_flags | TECHWEB_NODE_STARTER | TECHWEB_NODE_WIKI
	unlocked_designs = list(
		/datum/design/xenoarch/hammer,
		/datum/design/xenoarch/hammer/cm2,
		/datum/design/xenoarch/hammer/cm3,
		/datum/design/xenoarch/hammer/cm4,
		/datum/design/xenoarch/hammer/cm5,
		/datum/design/xenoarch/hammer/cm6,
		/datum/design/xenoarch/hammer/cm10,
		/datum/design/xenoarch/brush,
		/datum/design/xenoarch/measuring_tape,
		/datum/design/xenoarch/scanner,
		/datum/design/xenoarch/radar,
		/datum/design/xenoarch/bag,
		/datum/design/xenoarch/belt,
		/datum/design/board/xenoarch/scanner,
		/datum/design/board/xenoarch/researcher,
		/datum/design/xenoarch/core_sampler,
		/datum/design/xenoarch/stabilizer,
		/datum/design/xenoarch/particle_battery,
		/datum/design/xenoarch/particle_utilizer,
		/datum/design/xenoarch/wave_scanner,
	)
	announce_channels = list(RADIO_CHANNEL_SCIENCE, RADIO_CHANNEL_SUPPLY)

/datum/design/xenoarch/radar
	name = "archaeological radar"
	desc = "Поиск персональных участков раскопок в природных добывающих секторах."
	build_path = /obj/item/xenoarch/radar
	materials = /obj/item/xenoarch/radar::custom_materials

/datum/design/xenoarch/bag
	name = "archaeological sample bag"
	desc = "Сумка для 25 образцов."
	build_path = /obj/item/storage/bag/xenoarch

/datum/design/xenoarch/belt
	name = "archaeological toolbelt"
	desc = "Пояс для инструментов археолога."
	build_path = /obj/item/storage/belt/utility/xenoarch

/datum/design/xenoarch/advanced
	abstract_type = /datum/design/xenoarch/advanced
	materials = /obj/item/xenoarch/hammer/advanced::custom_materials

/datum/design/xenoarch/advanced/hammer
	name = "advanced archaeological hammer"
	desc = "Регулируемая глубина 1–30 см."
	build_path = /obj/item/xenoarch/hammer/advanced

/datum/design/xenoarch/advanced/brush
	name = "advanced archaeological brush"
	desc = "Точная раскопка за полсекунды."
	build_path = /obj/item/xenoarch/brush/advanced

/datum/design/xenoarch/advanced/scanner
	name = "advanced archaeological scanner"
	desc = "Измерение точной глубины находки."
	build_path = /obj/item/xenoarch/handheld_scanner/advanced

/datum/design/xenoarch/advanced/bag
	name = "advanced archaeological sample bag"
	desc = "Сумка для 50 образцов."
	build_path = /obj/item/storage/bag/xenoarch/advanced
	materials = /obj/item/storage/bag/xenoarch/advanced::custom_materials

/datum/design/board/xenoarch
	abstract_type = /datum/design/board/xenoarch
	category = list(RND_CATEGORY_MACHINE + "/Ксеноархеология")
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/board/xenoarch/scanner
	name = "сканер археологических образцов"
	desc = "Плата сканера образцов."
	build_path = /obj/item/circuitboard/machine/xenoarch/scanner

/datum/design/board/xenoarch/digger
	name = "автоматический археологический раскопщик"
	desc = "Плата автоматического раскопщика."
	build_path = /obj/item/circuitboard/machine/xenoarch/digger

/datum/design/board/xenoarch/researcher
	name = "археологический исследователь"
	desc = "Плата переработчика образцов."
	build_path = /obj/item/circuitboard/machine/xenoarch/researcher

/datum/techweb_node/adv_xenoarch
	display_name = "Продвинутая ксеноархеология"
	description = "Ускоренные инструменты и автоматическое извлечение находок."
	prerequisite_nodes = list(/datum/techweb_node/basic_xenoarch)
	unlocked_designs = list(/datum/design/xenoarch/advanced/hammer, /datum/design/xenoarch/advanced/brush, /datum/design/xenoarch/advanced/scanner, /datum/design/xenoarch/advanced/bag, /datum/design/board/xenoarch/digger)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)
	announce_channels = list(RADIO_CHANNEL_SCIENCE, RADIO_CHANNEL_SUPPLY)

/datum/design/xenoarch/core_sampler
	name = "archaeological core sampler"
	desc = "Извлечение керна для определения стабилизирующего поля."
	build_path = /obj/item/xenoarch/core_sampler

/datum/design/xenoarch/stabilizer
	name = "archaeological anomaly stabilizer"
	desc = "Настраиваемое поле для сохранения крупных находок."
	build_path = /obj/item/xenoarch/stabilizer

/datum/design/xenoarch/particle_battery
	name = "exotic particle battery"
	desc = "Хранение скопированного излучения артефакта."
	build_path = /obj/item/xenoarch/particle_battery
	materials = /obj/item/xenoarch/particle_battery::custom_materials

/datum/design/xenoarch/particle_utilizer
	name = "exotic particle utilizer"
	desc = "Переносной излучатель с таймером и непрерывным режимом."
	build_path = /obj/item/xenoarch/particle_utilizer
	materials = /obj/item/xenoarch/particle_utilizer::custom_materials

/datum/design/xenoarch/wave_scanner
	name = "archaeological wave scanner"
	desc = "Поиск крупных включений по экзотическому излучению."
	build_path = /obj/item/xenoarch/wave_scanner
	materials = /obj/item/xenoarch/wave_scanner::custom_materials

/datum/design/board/xenoarch/pad
	name = "artifact analysis pad"
	desc = "Плата площадки анализа артефактов."
	build_path = /obj/item/circuitboard/machine/xenoarch/pad

/datum/design/board/xenoarch/analyzer
	name = "artifact radiation analyzer"
	desc = "Плата анализатора излучения артефактов."
	build_path = /obj/item/circuitboard/machine/xenoarch/analyzer

/datum/design/board/xenoarch/spectrometer
	name = "radiocarbon spectrometer"
	desc = "Плата спектрометра геологических кернов."
	build_path = /obj/item/circuitboard/machine/xenoarch/spectrometer

/datum/design/board/xenoarch/harvester
	name = "exotic particle harvester"
	desc = "Плата сборщика экзотических частиц."
	build_path = /obj/item/circuitboard/machine/xenoarch/harvester

/datum/techweb_node/xenoarch_machines
	display_name = "Лаборатория ксеноархеологии"
	description = "Стационарное изучение крупных артефактов и сбор их излучения."
	prerequisite_nodes = list(/datum/techweb_node/basic_xenoarch)
	unlocked_designs = list(/datum/design/board/xenoarch/pad, /datum/design/board/xenoarch/analyzer, /datum/design/board/xenoarch/spectrometer, /datum/design/board/xenoarch/harvester)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_1_POINTS)
	announce_channels = list(RADIO_CHANNEL_SCIENCE)
