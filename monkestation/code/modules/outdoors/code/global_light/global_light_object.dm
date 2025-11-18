//todo: handle moving sunlight turfs - see various uses of get_turf in lighting_object


/*
Sunlight System
	Objects + Details
		Sunlight Objects (this file)
			- Grayscale version of lighting_object
			- Has 3 states
				- SKY_BLOCKED  (0)
					- Turfs that have an opaque turf above them. Has no light themselves but is affected by SKY_VISIBLE_BORDER
				- SKY_VISIBLE (1)
					- Turfs that with no opaque turfs above it (no roof, glass roof, etc), with no neighbouring SKY_BLOCKED tiles
					  Emits no light, but is fully white to display the overlay color
				- SKY_VISIBLE_BORDER  (2)
					- Turfs that with no opaque turfs above it (no roof, glass roof, etc), which neighbour at least one SKY_BLOCKED tile.
				     Emits light to SKY_BLOCKED tiles, and fully white to display the overlay color
*/

// Keep in mind. Lighting corners accept the bottom left (northwest) set of cords to them as input
#define GENERATE_MISSING_CORNERS(gen_for) \
	if (!gen_for.lighting_corner_NE) { \
		gen_for.lighting_corner_NE = new /datum/lighting_corner(gen_for.x, gen_for.y, gen_for.z); \
	} \
	if (!gen_for.lighting_corner_SE) { \
		gen_for.lighting_corner_SE = new /datum/lighting_corner(gen_for.x, gen_for.y - 1, gen_for.z); \
	} \
	if (!gen_for.lighting_corner_SW) { \
		gen_for.lighting_corner_SW = new /datum/lighting_corner(gen_for.x - 1, gen_for.y - 1, gen_for.z); \
	} \
	if (!gen_for.lighting_corner_NW) { \
		gen_for.lighting_corner_NW = new /datum/lighting_corner(gen_for.x - 1, gen_for.y, gen_for.z); \
	} \
	gen_for.lighting_corners_initialised = TRUE;

//TODO: turn it into datum (I'm doing opti, not fucking fuckery around)
/atom/movable/outdoor_effect
	name = ""
	mouse_opacity = FALSE
	anchored = TRUE
	move_resist = INFINITY
	resistance_flags = parent_type::resistance_flags|SHUTTLE_CRUSH_PROOF

	/* misc vars */
	var/mutable_appearance/sunlight_overlay
	var/state = SKY_VISIBLE	// If we can see the see the sky, are blocked, or we have a blocked neighbour (SKY_BLOCKED/VISIBLE/VISIBLE_BORDER)
	var/turf/source_turf
	var/list/datum/lighting_corner/affecting_corners

/atom/movable/outdoor_effect/Destroy(force)
	if(!force)
		return QDEL_HINT_LETMELIVE

	//If we are a source of light - disable it, to fix out corner refs
	disable_global_light()

	//Remove ourselves from our turf
	if(source_turf && source_turf.outdoor_effect == src)
		source_turf.outdoor_effect = null

	return ..()

/atom/movable/outdoor_effect/singularity_pull(obj/singularity/singularity, current_size)
	return

/atom/movable/outdoor_effect/singularity_act()
	return

/atom/movable/outdoor_effect/Initialize(mapload)
	. = ..()
	source_turf = loc
	if(source_turf.outdoor_effect)
		qdel(source_turf.outdoor_effect, force = TRUE)
		source_turf.outdoor_effect = null //No qdel_null force
	source_turf.outdoor_effect = src

/atom/movable/outdoor_effect/proc/disable_global_light()
	var/turf/turf = list()
	for(var/datum/lighting_corner/corner as anything in affecting_corners)
		corner.glob_affect -= src
		corner.get_global_light_falloff()
		if(corner.master_NE)
			turf |= corner.master_NE
		if(corner.master_SE)
			turf |= corner.master_SE
		if(corner.master_SW)
			turf |= corner.master_SW
		if(corner.master_NW)
			turf |= corner.master_NW
	turf |= source_turf /* get our calculated indoor lighting */
	GLOB.global_light_queue_corner += turf

	//Empty our affecting_corners list
	affecting_corners = null

/atom/movable/outdoor_effect/proc/process_state()
	switch(state)
		if(SKY_BLOCKED)
			disable_global_light() /* Do our indoor processing */
		if(SKY_VISIBLE_BORDER)
			calc_global_light_spread()

#define HARDGLOBALLIGHT 0.5 /* our hyperboloidy modifyer funky times - I wrote this in like, 2020 and can't remember how it works - I think it makes a 3D cone shape with a flat top */
/* calculate the indoor corners we are affecting */
#define GLOBAL_LIGHT_FALLOFF(C, T) (1 - CLAMP01(sqrt((C.x - T.x) ** 2 + (C.y - T.y) ** 2 - HARDGLOBALLIGHT) / max(1, GLOB.global_light_range)))


/atom/movable/outdoor_effect/proc/calc_global_light_spread()
	var/list/turf/turfs = list()
	var/datum/lighting_corner/corner
	var/turf/turf
	var/list/temp_master_list = list() /* to mimimize double ups */
	var/list/corners  = list() /* corners we are currently affecting */

	//Set lum so we can see things
	var/oldLum = luminosity
	luminosity = GLOB.global_light_range

	for(turf in view(CEILING(GLOB.global_light_range, 1), source_turf))
		if(IS_OPAQUE_TURF(turf)) /* get_corners used to do opacity checks for arse */
			continue
		if (!turf.lighting_corners_initialised)
			GENERATE_MISSING_CORNERS(turf)
		corners |= turf.lighting_corner_NE
		corners |= turf.lighting_corner_SE
		corners |= turf.lighting_corner_SW
		corners |= turf.lighting_corner_NW
		turfs += turf

	//restore lum
	luminosity = oldLum

	/* fix up the lists */
	/* add ourselves and our distance to the corner */
	if(!affecting_corners)
		affecting_corners = list()
	var/list/corners_list = corners - affecting_corners
	affecting_corners += corners_list
	for(corner in corners_list)
		corner.glob_affect[src] = GLOBAL_LIGHT_FALLOFF(corner, source_turf)
		if(corner.glob_affect[src] > corner.global_light_falloff) /* if are closer than current dist, update the corner */
			corner.global_light_falloff = corner.glob_affect[src]
			if(corner.master_NE)
				temp_master_list |= corner.master_NE
			if(corner.master_SE)
				temp_master_list |= corner.master_SE
			if(corner.master_SW)
				temp_master_list |= corner.master_SW
			if(corner.master_NW)
				temp_master_list |= corner.master_NW

	corners_list = affecting_corners - corners // Now-gone corners, remove us from the affecting.
	affecting_corners -= corners_list
	for(corner in corners_list)
		corner.glob_affect -= src
		corner.get_global_light_falloff()
		if(corner.master_NE)
			temp_master_list |= corner.master_NE
		if(corner.master_SE)
			temp_master_list |= corner.master_SE
		if(corner.master_SW)
			temp_master_list |= corner.master_SW
		if(corner.master_NW)
			temp_master_list |= corner.master_NW

	GLOB.global_light_queue_corner += temp_master_list /* update the boys */

/* Related object changes */
/* I moved this here to consolidate sunlight changes as much as possible, so its easily disabled */

/* area fuckery */
/area
	var/turf/pseudo_roof

/* turf fuckery */
/turf
	var/tmp/atom/movable/outdoor_effect/outdoor_effect /* a turf's sunlight overlay */
	var/turf/pseudo_roof /* our roof turf - may be a path for top z level, or a ref to the turf above*/

	turf_flags = TURF_WEATHER_PROOF|TURF_EFFECT_AFFECTABLE
	var/ceiling_status = NONE

//non-weatherproof turfs
/turf/var/weatherproof = TRUE
/turf/open/space/weatherproof = FALSE
/turf/open/floor/plating/ocean/weatherproof = FALSE
/turf/open/openspace/weatherproof = FALSE

/* check ourselves and neighbours to see what outdoor effects we need */
/* turf won't initialize an outdoor_effect if sky_blocked*/
/turf/proc/get_sky_and_weather_states()
	var/temp_state
	update_ceiling_status()
	if(ceiling_status & SKYVISIBLE)
		temp_state = SKY_VISIBLE
		for(var/turf/neighbour_turf in RANGE_TURFS(1, src))
			neighbour_turf.update_ceiling_status()
			if(!(neighbour_turf.ceiling_status & SKYVISIBLE)) /* if we have a single roofed/indoor neighbour, we are a border */
				temp_state = SKY_VISIBLE_BORDER
				break
	else /* roofed, so turn off the lights */
		temp_state = SKY_BLOCKED

	/* if border or indoor, initialize. Set global light state if valid */
	if(!outdoor_effect && (temp_state <> SKY_BLOCKED || ceiling_status & WEATHERVISIBLE))
		outdoor_effect = new /atom/movable/outdoor_effect(src)

	if(outdoor_effect)
		outdoor_effect.state = temp_state
		turf_flags &= ~TURF_WEATHER
		SSweather_conditions.weathered_turfs -= src
		if(ceiling_status & WEATHERVISIBLE)
			turf_flags |= TURF_WEATHER
			SSweather_conditions.weathered_turfs |= src

/* runs up the Z stack for this turf, returns a assoc (SKYVISIBLE, WEATHERPROOF)*/
/* pass recursion_started=TRUE when we are checking our ceiling's stats */
/turf/proc/update_ceiling_status(recursion, skyvisible = TRUE, weathervisible = TRUE)
	ceiling_status = NONE
	if(!skyvisible)
		return

	if(!recursion)
		if(pseudo_roof)
			return

		var/turf/above = get_step_multiz(src, UP)
		if(above)
			above.update_ceiling_status(TRUE)

	if(isclosedturf(src)) //Closed, but we might be transparent
		skyvisible = turf_flags & TURF_TRANSPARENT // a column of glass should still let the sun in
		weathervisible = FALSE
	else
		if(recursion)
			// This src is acting as a ceiling - so if we are a floor we WEATHER_PROOF + block the global light of our down-Z turf
			skyvisible = turf_flags & TURF_TRANSPARENT //If we are glass floor, we don't block
			weathervisible = !(turf_flags & TURF_WEATHER_PROOF) //If we are air or space, we aren't WEATHER_PROOF

	if(!skyvisible)
		return

	if(skyvisible)
		ceiling_status |= SKYVISIBLE
	if(weathervisible)
		ceiling_status |= WEATHERVISIBLE

	var/turf/below = get_step_multiz(src, DOWN)
	if(below)
		below.update_ceiling_status(TRUE, skyvisible, weathervisible)

/* Need to explain that to me what is the heck is that
	var/area/turf_area = get_area(src)
	var/turf/above_turf = GET_TURF_ABOVE(src)
	if((!isspaceturf(src) && !istype(src, /turf/open/floor/plating/ocean) && !above_turf && !SSmapping.level_trait(src.z, ZTRAIT_UP) && !turf_area.outdoors && !turf_area.false_outdoors) || (!SSmapping.level_trait(src.z, ZTRAIT_DAYCYCLE) && !SSmapping.level_trait(src.z, ZTRAIT_STARLIGHT)))
		.["SKYVISIBLE"]   =  FALSE
		.["WEATHERPROOF"] =  TRUE
*/

/turf/proc/apply_weather_effect(datum/weather_effect/effect)
	if(!(turf_flags & TURF_EFFECT_AFFECTABLE) || density)
		return
//ADD here objects that can stop it from happening, better via adding/removing flags
	effect.effect_affect(src)

/* moved this out of reconsider lights so we can call it in multiz refresh  */
/turf/proc/reconsider_global_light()
	if(!SSlighting.initialized)
		return

	var/atom/movable/outdoor_effect/effect
	var/list/global_light_updates = list()

	//Add ourselves (we might not have corners initialized, and this handles it)
	global_light_updates += src

	//AHHHHGGGGGHHHHHHHHHHHHHHH
	if(lighting_corner_NE)
		if(lighting_corner_NE.master_NE)
			global_light_updates |= lighting_corner_NE.master_NE
		if(lighting_corner_NE.master_SE)
			global_light_updates |= lighting_corner_NE.master_SE
		if(lighting_corner_NE.master_SW)
			global_light_updates |= lighting_corner_NE.master_SW
		if(lighting_corner_NE.master_NW)
			global_light_updates |= lighting_corner_NE.master_NW
		for(effect as anything in lighting_corner_NE.glob_affect)
			global_light_updates |= effect.source_turf

	if(lighting_corner_SE)
		if(lighting_corner_SE.master_NE)
			global_light_updates |= lighting_corner_SE.master_NE
		if(lighting_corner_SE.master_SE)
			global_light_updates |= lighting_corner_SE.master_SE
		if(lighting_corner_SE.master_SW)
			global_light_updates |= lighting_corner_SE.master_SW
		if(lighting_corner_SE.master_NW)
			global_light_updates |= lighting_corner_SE.master_NW
		for(effect as anything in lighting_corner_SE.glob_affect)
			global_light_updates |= effect.source_turf

	if(lighting_corner_SW)
		if(lighting_corner_SW.master_NE)
			global_light_updates |= lighting_corner_SW.master_NE
		if(lighting_corner_SW.master_SE)
			global_light_updates |= lighting_corner_SW.master_SE
		if(lighting_corner_SW.master_SW)
			global_light_updates |= lighting_corner_SW.master_SW
		if(lighting_corner_SW.master_NW)
			global_light_updates |= lighting_corner_SW.master_NW
		for(effect as anything in lighting_corner_SW.glob_affect)
			global_light_updates |= effect.source_turf

	if(lighting_corner_NW)
		if(lighting_corner_NW.master_NE)
			global_light_updates |= lighting_corner_NW.master_NE
		if(lighting_corner_NW.master_SE)
			global_light_updates |= lighting_corner_NW.master_SE
		if(lighting_corner_NW.master_SW)
			global_light_updates |= lighting_corner_NW.master_SW
		if(lighting_corner_NW.master_NW)
			global_light_updates |= lighting_corner_NW.master_NW
		for(effect as anything in lighting_corner_NW.glob_affect)
			global_light_updates |= effect.source_turf

	GLOB.global_light_queue_work += global_light_updates

	var/turf/T = GET_TURF_BELOW(src)
	if(T)
		T.reconsider_global_light()

/* corner fuckery */
/datum/lighting_corner
	var/list/glob_affect = list() /* list of sunlight objects affecting this corner */
	var/global_light_falloff = 0 /* smallest distance to sunlight turf, for sunlight falloff */

/* loop through and find our strongest sunlight value */
/datum/lighting_corner/proc/get_global_light_falloff()
	global_light_falloff = 0

	var/atom/movable/outdoor_effect/effect
	for(effect as anything in glob_affect)
		global_light_falloff = global_light_falloff < glob_affect[effect] ? glob_affect[effect] : global_light_falloff


/* Effect Fuckery */
/* these bits are to set the roof on a top-z level, as there is no turf above to act as a roof */
/obj/effect/mapping_helpers/sunlight/pseudo_roof_setter
	var/turf/pseudo_roof

/obj/effect/mapping_helpers/sunlight/pseudo_roof_setter/Initialize(mapload)
	. = ..()
	// Disabled mapload catch - somebody might want to wangle this l8r
	// if(!mapload)
	// 	log_mapping("[src] spawned outside of mapload!")
	// 	return
	if(isturf(loc) && !get_step_multiz(loc, UP))
		var/turf/T = loc
		T.pseudo_roof = pseudo_roof



#undef GLOBAL_LIGHT_FALLOFF
#undef HARDGLOBALLIGHT
#undef GENERATE_MISSING_CORNERS
