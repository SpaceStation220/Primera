#ifndef BANDASTATION_XENOARCH_DEFINES
#define BANDASTATION_XENOARCH_DEFINES
///artifact energy release method
#define XENO_EFFECT_TOUCH 0
#define XENO_EFFECT_AURA 1
#define XENO_EFFECT_PULSE 2

///list of possible release methods to get
#define XENO_ALL_RELEASE_METHODS list(\
	XENO_EFFECT_TOUCH,\
	XENO_EFFECT_AURA,\
	XENO_EFFECT_PULSE,\
)

///artifact trigger types
#define XENO_TRIGGER_TOUCH (1<<2)
#define XENO_TRIGGER_WATER (1<<3)
#define XENO_TRIGGER_ACID (1<<4)
#define XENO_TRIGGER_VOLATILE (1<<5)
#define XENO_TRIGGER_TOXIN (1<<6)
#define XENO_TRIGGER_FORCE (1<<7)
#define XENO_TRIGGER_ENERGY (1<<8)
#define XENO_TRIGGER_HEAT (1<<9)
#define XENO_TRIGGER_COLD (1<<10)
#define XENO_TRIGGER_PLASMA (1<<11)
#define XENO_TRIGGER_OXY (1<<12)
#define XENO_TRIGGER_CO2 (1<<13)
#define XENO_TRIGGER_NITRO (1<<14)
#define XENO_TRIGGER_PROXY (1<<15)
#define XENO_TRIGGER_TEMP (XENO_TRIGGER_COLD | XENO_TRIGGER_HEAT)
#define XENO_TRIGGER_GASES (XENO_TRIGGER_PLASMA | XENO_TRIGGER_OXY | XENO_TRIGGER_CO2 | XENO_TRIGGER_NITRO)
#define XENO_TRIGGER_ATMOS (XENO_TRIGGER_HEAT | XENO_TRIGGER_COLD | XENO_TRIGGER_GASES)

///list of possible artifact triggers
#define XENO_POSSIBLE_TRIGGERS list(\
	XENO_TRIGGER_TOUCH,\
	XENO_TRIGGER_WATER,\
	XENO_TRIGGER_ACID,\
	XENO_TRIGGER_VOLATILE,\
	XENO_TRIGGER_TOXIN,\
	XENO_TRIGGER_FORCE,\
	XENO_TRIGGER_ENERGY,\
	XENO_TRIGGER_HEAT,\
	XENO_TRIGGER_COLD,\
	XENO_TRIGGER_PLASMA,\
	XENO_TRIGGER_OXY,\
	XENO_TRIGGER_CO2,\
	XENO_TRIGGER_NITRO,\
)

///artifact type_name

///unknown/none
#define XENO_EFFECT_UNKNOWN 0
///concentrated energy
#define XENO_EFFECT_ENERGY 1
///untermittent psionic wavefront
#define XENO_EFFECT_PSIONIC 2
///electromagnetic energy
#define XENO_EFFECT_ELECTRO 3
///particle field
#define XENO_EFFECT_PARTICLE 4
///organically reactive exotic particles
#define XENO_EFFECT_ORGANIC 5
///bluespace
#define XENO_EFFECT_BLUESPACE 6
///atomic synthesis
#define XENO_EFFECT_SYNTH 7

GLOBAL_LIST_INIT(xenoarch_primary_effects, list(
	/datum/xenoartifact_effect/temperature/cold,
	/datum/xenoartifact_effect/temperature/heat,
	/datum/xenoartifact_effect/dnaswitch,
	/datum/xenoartifact_effect/emp,
	/datum/xenoartifact_effect/gas,
	/datum/xenoartifact_effect/gravity,
	/datum/xenoartifact_effect/radiate,
	/datum/xenoartifact_effect/sleepy,
	/datum/xenoartifact_effect/stun,
	/datum/xenoartifact_effect/tesla,
	/datum/xenoartifact_effect/teleport,
	/datum/xenoartifact_effect/bodyswap,
	/datum/xenoartifact_effect/bodyhorror,
	/datum/xenoartifact_effect/machinery_mess,
	/datum/xenoartifact_effect/blood_regen,
	/datum/xenoartifact_effect/blood_drain,
))

GLOBAL_LIST_INIT(xenoarch_secondary_effects, list(
	/datum/xenoartifact_effect/feelings/bad,
	/datum/xenoartifact_effect/feelings/good,
	/datum/xenoartifact_effect/cellcharge,
	/datum/xenoartifact_effect/celldrain,
	/datum/xenoartifact_effect/heal,
	/datum/xenoartifact_effect/hurt,
	/datum/xenoartifact_effect/light,
	/datum/xenoartifact_effect/light/darkness,
	/datum/xenoartifact_effect/noise,
	/datum/xenoartifact_effect/roboheal,
	/datum/xenoartifact_effect/robohurt,
	/datum/xenoartifact_effect/disgust,
	/datum/xenoartifact_effect/drugs,
))

GLOBAL_LIST_INIT(xenoarch_volatile_reagents, list(
	/datum/reagent/thermite,
	/datum/reagent/toxin/plasma,
	/datum/reagent/nitroglycerin,
	/datum/reagent/clf3,
	/datum/reagent/sorium,
	/datum/reagent/liquid_dark_matter,
	/datum/reagent/gunpowder,
	/datum/reagent/rdx,
	/datum/reagent/tatp,
	/datum/reagent/flash_powder,
	/datum/reagent/phlogiston,
	/datum/reagent/napalm,
	/datum/reagent/pyrosium,
	/datum/reagent/teslium,
))

#endif
