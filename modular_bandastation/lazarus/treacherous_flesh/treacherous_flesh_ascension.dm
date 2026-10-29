// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/** The final body keeps the colony-building abilities and gains a ranged grapple. */
/mob/living/basic/flesh_biomorph/high
	name = "Высший биоморф"
	desc = "Отвратительное насекомоподобное существо."
	icon = 'modular_bandastation/lazarus/icons/high_biomorph.dmi'
	icon_state = "high"
	icon_living = "high"
	maxHealth = 400
	health = 400
	obj_damage = 50
	melee_damage_lower = 35
	melee_damage_upper = 35
	move_resist = MOVE_FORCE_STRONG
	weeds_heal_amount = 10
	speed = 0.8
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	death_sound = 'modular_bandastation/lazarus/sound/shadowdeath.ogg'

/mob/living/basic/flesh_biomorph/high/Initialize(mapload)
	. = ..()
	GRANT_ACTION(/datum/action/cooldown/biomorph/plant_weeds)
	GRANT_ACTION(/datum/action/cooldown/biomorph/build_structure)
	GRANT_ACTION(/datum/action/cooldown/spell/pointed/projectile/biomorph_tentacle)
	grant_language(/datum/language/common, source = LANGUAGE_ATOM)

/datum/action/cooldown/spell/pointed/projectile/biomorph_tentacle
	name = "Выстрел щупальцем"
	desc = "Притягивает жертву и ранит её. При попадании в стену притягивает самого биоморфа."
	button_icon = 'modular_bandastation/lazarus/icons/lazarus_actions.dmi'
	button_icon_state = "tentacle"
	background_icon = 'modular_bandastation/lazarus/icons/lazarus_actions.dmi'
	background_icon_state = "bg_flesh"
	cooldown_time = 10 SECONDS
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	cast_range = 10
	projectile_type = /obj/projectile/biomorph_tentacle

/obj/projectile/biomorph_tentacle
	name = "щупальце биоморфа"
	icon = 'modular_bandastation/lazarus/icons/projectiles.dmi'
	icon_state = "tentacle_end"
	damage = 40
	damage_type = BRUTE
	range = 10
	/// Ensures one collision cannot start repeated pulls.
	var/has_pulled = FALSE
	/// Beam is deleted with the projectile.
	var/datum/beam/tentacle_beam

/obj/projectile/biomorph_tentacle/fire(setAngle)
	if(firer)
		tentacle_beam = firer.Beam(src, icon_state = "tentacle", emissive = NONE)
	return ..()

/obj/projectile/biomorph_tentacle/Destroy()
	QDEL_NULL(tentacle_beam)
	return ..()

/obj/projectile/biomorph_tentacle/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	if(has_pulled || blocked >= 100 || !isliving(firer) || QDELETED(target))
		return
	has_pulled = TRUE
	if(isliving(target))
		var/mob/living/victim = target
		victim.Immobilize(2 SECONDS)
		victim.throw_at(get_step_towards(firer, victim), 10, 2, firer, gentle = TRUE)
	else if(target.density)
		firer.throw_at(get_step_towards(target, firer), 10, 2)
// AI EDIT END
