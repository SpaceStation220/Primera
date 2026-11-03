// AI EDIT START - Preserve Avangarde's mapped render order without layer variable edits.
/// Event desk lamp drawn just above neighboring desktop objects.
/obj/item/flashlight/lamp/avangarde
	layer = 3.02

/// Event countertop microwave drawn above the counter.
/obj/machinery/microwave/avangarde
	layer = OBJ_LAYER

/// Event microwave drawn above the neighboring countertop equipment.
/obj/machinery/microwave/avangarde/raised
	layer = 3.1

/// Event Marx bust retaining its original position behind nearby objects.
/obj/structure/statue/bronze/marx/avangarde
	layer = 2.91

/// Event cargo pile retaining its original overlap with the surrounding scenery.
/obj/structure/shipping_container/kosmologistika/crates/avangarde
	layer = 4.71

/// Decorative base below Avangarde's eternal flame.
/obj/avangarde_eternal_flame_base
	layer = BELOW_OBJ_LAYER
// AI EDIT END
