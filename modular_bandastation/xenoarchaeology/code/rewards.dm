/// Базовые археологические находки; таблицы адаптированы к предметам BandaStation.
/obj/effect/spawner/random/xenoarch
	abstract_type = /obj/effect/spawner/random/xenoarch

/obj/effect/spawner/random/xenoarch/tier1
	loot = list(
		/obj/item/xenoarch/broken_item/animal = 5,
		/obj/item/xenoarch/broken_item/plant = 3,
		/obj/item/xenoarch/broken_item/basic_tools = 2,
	)

/obj/effect/spawner/random/xenoarch/tier2
	loot = list(
		/obj/item/xenoarch/broken_item = 4,
		/obj/item/xenoarch/broken_item/plant = 2,
		/obj/item/xenoarch/broken_item/animal = 2,
	)

/obj/effect/spawner/random/xenoarch/tier3
	loot = list(
		/obj/item/assembly/relic/lavaland = 4,
		/obj/item/xenoarch/broken_item/weapon = 1,
	)

/obj/effect/spawner/random/xenoarch/basic_tools
	loot = list(
		/obj/item/multitool = 1,
		/obj/item/flashlight = 1,
		/obj/item/t_scanner = 1,
		/obj/item/stock_parts/power_store/cell = 1,
	)

/obj/effect/spawner/random/xenoarch/tools
	loot = list(
		/obj/item/construction/rcd = 1,
		/obj/item/pipe_dispenser = 1,
		/obj/item/anomaly_neutralizer = 1,
		/obj/item/bodybag/bluespace = 1,
		/obj/item/megaphone = 1,
		/obj/item/construction/plumbing = 1,
		/obj/item/stock_parts/power_store/cell/high = 1,
		/obj/item/storage/portable_chem_mixer = 1,
	)

/obj/effect/spawner/random/xenoarch/plant
	spawn_loot_count = 2
	loot = list(
		/obj/item/seeds/random = 2,
		/obj/item/seeds/amauri = 1,
		/obj/item/seeds/gelthi = 1,
		/obj/item/seeds/jurlmah = 1,
		/obj/item/seeds/nofruit = 1,
		/obj/item/seeds/shand = 1,
		/obj/item/seeds/surik = 1,
		/obj/item/seeds/telriis = 1,
		/obj/item/seeds/thaadra = 1,
		/obj/item/seeds/vale = 1,
		/obj/item/seeds/vaporsac = 1,
	)

/obj/effect/spawner/random/xenoarch/animal
	loot = list(
		/obj/item/stack/sheet/sinew = 1,
		/obj/item/stack/sheet/bone = 1,
		/obj/item/stack/sheet/animalhide/goliath_hide = 1,
	)

/obj/effect/spawner/random/xenoarch/weapon
	loot = list(
		/obj/item/spear/bonespear = 6,
		/obj/item/claymore/cutlass = 2,
		/obj/item/shield/riot = 1,
		/obj/item/gun/ballistic/automatic/pistol = 1,
	)

/obj/item/xenoarch/broken_item/basic_tools
	icon_state = "basic_recover"
	loot = /obj/effect/spawner/random/xenoarch/basic_tools

/obj/item/xenoarch/broken_item/plant
	icon_state = "recover_plant"
	name = "sediment encased seeds"
	desc = "Семена в осадочной оболочке. Очистите их археологической кисточкой."
	loot = /obj/effect/spawner/random/xenoarch/plant

/obj/item/xenoarch/broken_item/animal
	icon_state = "recover_animal"
	name = "sediment encased animal remains"
	desc = "Останки животного в осадочной оболочке. Очистите их археологической кисточкой."
	loot = /obj/effect/spawner/random/xenoarch/animal

/obj/item/xenoarch/broken_item/weapon
	icon_state = "recover_weapon"
	name = "sediment encased weapon"
	desc = "Предмет, похожий на оружие, под слоем отложений. Очистите его археологической кисточкой."
	loot = /obj/effect/spawner/random/xenoarch/weapon
