/datum/time_of_day
	var/name = ""
	var/color = ""
	var/start_at = 0.25	// 06:00:00
	var/position_number = FALSE

/datum/time_of_day/midnight
	name = "Midnight"
	color = "#000000"
	start_at = 0		//12:00:00
	position_number = 1

/datum/time_of_day/night
	name = "Night"
	color = "#050D29"
	start_at = 0.083	//02:00:00
	position_number = 2

/datum/time_of_day/dawn
	name = "Dawn"
	color = "#31211b"
	start_at = 0.16		//04:00:00
	position_number = 3

/datum/time_of_day/sunrise
	name = "Sunrise"
	color = "#F598AB"
	start_at = 0.25		//06:00:00
	position_number = 4

/datum/time_of_day/sunrise_morning
	name = "Sunrise-Morning"
	color = "#7e874a"
	start_at = 0.29		//07:00:00
	position_number = 5

/datum/time_of_day/morning
	name = "Morning"
	color = "#808599"
	start_at = 0.33		//08:00:00
	position_number = 6

/datum/time_of_day/daytime
	name = "Daytime"
	color = "#FFFFFF"
	start_at = 0.416	//10:00:00
	position_number = 7

/datum/time_of_day/evening
	name = "Evening"
	color = "#AFAFAF"
	start_at = 0.66		//14:00:00
	position_number = 8

/datum/time_of_day/sunset
	name = "Sunset"
	color = "#ff8a63"
	start_at = 0.7916	//17:00:00
	position_number = 9

/datum/time_of_day/dusk
	name = "Dusk"
	color = "#221f33"
	start_at = 0.916	//22:00:00
	position_number = 10

GLOBAL_VAR_INIT(global_light_range, 5)
GLOBAL_LIST_EMPTY(global_light_queue_work) /* turfs to be stateChecked */
GLOBAL_LIST_EMPTY(global_light_queue_update) /* turfs to have their colors updated via corners (filter out the unroofed dudes) */
GLOBAL_LIST_EMPTY(global_light_queue_corner) /* turfs to have their color/lights/etc updated */
GLOBAL_LIST_EMPTY(global_light_planes_need_vis)
GLOBAL_LIST_INIT(weather_planes, list(
	"Station" = list(),
	"Eclipse" = list(),
	"Misc" = list()
))

SUBSYSTEM_DEF(global_light)
	name = "Global Lighting"
	wait = 1 SECONDS
	flags = SS_TICKER
	init_order = INIT_ORDER_OUTDOOR_EFFECTS

	var/datum/time_of_day/current_step_datum
	var/datum/time_of_day/next_step_datum
	var/list/mutable_appearance/sunlight_overlays

	var/datum/particle_weather/weather_datum
	var/datum/weather_event/weather_light_affecting_event

	var/list/datum/time_of_day/steps = list()
	var/game_time_length = 24 HOURS

	var/current_color = null
	var/time_to_animate = 0
	var/min_weather_blend_amount = 0.3

	var/enabled = TRUE // Micro-optimization to avoid having to check config or bitflags

/datum/controller/subsystem/global_light/Recover()
	current_step_datum = SSglobal_light.current_step_datum
	next_step_datum = SSglobal_light.next_step_datum
	sunlight_overlays = SSglobal_light.sunlight_overlays?.Copy()

	weather_datum = SSglobal_light.weather_datum
	weather_light_affecting_event = SSglobal_light.weather_light_affecting_event

	steps = SSglobal_light.steps
	game_time_length = SSglobal_light.game_time_length

	current_color = SSglobal_light.current_color
	time_to_animate = SSglobal_light.time_to_animate
	min_weather_blend_amount = SSglobal_light.min_weather_blend_amount

	enabled = SSglobal_light.enabled

/datum/controller/subsystem/global_light/stat_entry(msg)
	msg = "W:[length(GLOB.global_light_queue_work)]|U:[length(GLOB.global_light_queue_update)]|C:[length(GLOB.global_light_queue_corner)]"
	return ..()

/datum/controller/subsystem/global_light/Initialize(timeofday)
	if(!initialized)
		create_steps()
		set_time_of_day()
	if(CONFIG_GET(flag/disable_sunlight_visuals))
		disable()
		return SS_INIT_NO_NEED
	return SS_INIT_SUCCESS

/datum/controller/subsystem/global_light/proc/create_steps()
	for(var/path in typesof(/datum/time_of_day))
		var/datum/time_of_day/time_of_day = new path()
		if(time_of_day.position_number)
			steps["[time_of_day.position_number]"] = time_of_day

	current_step_datum = steps["1"]
	next_step_datum = steps["2"]

/datum/controller/subsystem/global_light/proc/check_cycle()
	if(!next_step_datum)
		set_time_of_day()
		return TRUE

	if(station_time() > next_step_datum.start_at * game_time_length)
		set_time_of_day()
		return TRUE
	return FALSE

/datum/controller/subsystem/global_light/proc/set_time_of_day()
	for(var/worked_length = 1 to length(steps))
		if(station_time() < steps["[worked_length]"].start_at * game_time_length)
			continue

		current_step_datum = steps["[worked_length]"]
		next_step_datum = worked_length == length(steps) ? steps["1"] : steps["[worked_length + 1]"]

//TODO: If yall need separated cycles for maps, need to do multi map handling for personal global light sections, for now I don't see anywhere potential need in this functional, so yea
/datum/controller/subsystem/global_light/proc/change_configuration_of_steps(list/data)
	for(var/worked_length = 1 to length(steps))
		var/datum/time_of_day/step = steps["worked_length"]
		if(data["cycle_modificator"][step.name])
			step.start_at = data["cycle_modificator"][step.name]
		if(data["cycle_colors"][step.name])
			step.color = data["cycle_colors"][step.name]

//Transition from our last color to our current color (i.e if it is going from daylight (white) to sunset (red), we transition to red in the first hour of sunset)
/datum/controller/subsystem/global_light/proc/update_color(atom/movable/screen/fullscreen/lighting_backdrop/sunlight/player_screen)
	player_screen.color = current_color
	animate(player_screen, color = next_step_datum.color, time = time_to_animate)

// OOD?
/datum/controller/subsystem/global_light/proc/fullPlonk()
	var/list/zs = SSmapping.levels_by_trait(ZTRAIT_DAYCYCLE) | SSmapping.levels_by_trait(ZTRAIT_STARLIGHT)
	for(var/area/area as anything in GLOB.areas)
		if(!area.static_lighting)
			continue
		for(var/z in zs)
			GLOB.global_light_queue_work += area.get_turfs_by_zlevel(z)

// Gotcha be OOD soon
/datum/controller/subsystem/global_light/proc/InitializeTurfs()
	var/list/zs = SSmapping.levels_by_trait(ZTRAIT_DAYCYCLE) | SSmapping.levels_by_trait(ZTRAIT_STARLIGHT)
	for(var/area/area as anything in GLOB.areas)
		if(!area.static_lighting && !istype(area, /area/space))
			continue
		for(var/z in zs)
			GLOB.global_light_queue_work += area.get_turfs_by_zlevel(z)

//Idk wtf is that and why
/// Disables the subsystem, cleaning up its vars and preventing it from firing.
/datum/controller/subsystem/global_light/proc/disable()
	enabled = FALSE
	flags |= SS_NO_FIRE
	weather_light_affecting_event = null

/* set sunlight color + add weather effect to clients */
/datum/controller/subsystem/global_light/fire(resumed, init_tick_checks)
	if(!enabled)
		return

	MC_SPLIT_TICK_INIT(2)
	if(!init_tick_checks)
		MC_SPLIT_TICK

	var/worked_length = 0

	for(worked_length in 1 to length(GLOB.global_light_queue_update))
		var/atom/movable/outdoor_effect/outdoor_effect = GLOB.global_light_queue_update[worked_length]
		if(outdoor_effect)
			outdoor_effect.process_state()
			update_outdoor_effect_overlays(outdoor_effect)

		if(MC_TICK_CHECK)
			break

	if(worked_length)
		GLOB.global_light_queue_update.Cut(1, worked_length+1)
		worked_length = 0


	MC_SPLIT_TICK

	for(worked_length in 1 to length(GLOB.global_light_queue_corner))
		var/turf/turf = GLOB.global_light_queue_corner[worked_length]
		var/atom/movable/outdoor_effect/outdoor_effect = turf.outdoor_effect

		/* if we haven't initialized but we are affected, create new and check state */
		if(!outdoor_effect)
			turf.outdoor_effect = new /atom/movable/outdoor_effect(turf)
			turf.get_sky_and_weather_states()
			outdoor_effect = turf.outdoor_effect

			/* in case we aren't indoor somehow, wack us into the proc queue, we will be skipped on next indoor check */
			if(outdoor_effect.state != SKY_BLOCKED)
				GLOB.global_light_queue_update += turf.outdoor_effect

		if(outdoor_effect.state != SKY_BLOCKED)
			continue

		//This might need to be run more liberally
		update_outdoor_effect_overlays(outdoor_effect)


		if(MC_TICK_CHECK)
			break

	if(worked_length)
		GLOB.global_light_queue_corner.Cut(1, worked_length+1)
		worked_length = 0

	//TODO: Better to add global color object, that they take color from, and we have only to change it once for everyone
	//https://github.com/RU-CMSS13/RU-CMSS13/pull/260/files#diff-b22b29eaf2da600d07a83d146e281e018c438e7b9b668aca863ac1f9f09fe222 (File: core_ru/code/controllers/subsystem/global_light.dm Line: 88)
	//Can be made solution like this, but theres a catch, variant provided had some issues when I last time ran it at prod scale with client byond dying very rarely and unpredictebly
	var/time_percented = station_time() / 24 HOURS
	var/blend_amount = (time_percented - current_step_datum.start_at) / (next_step_datum.start_at - current_step_datum.start_at)
	current_color = BlendRGB(current_step_datum.color, next_step_datum.color, blend_amount)
	if(weather_datum && weather_datum.weather_color_offset)
		var/weather_blend_amount = (time_percented - weather_datum.weather_start_time) / (weather_datum.weather_start_time + (weather_datum.weather_duration / 12) - weather_datum.weather_start_time)
		current_color = BlendRGB(current_color, weather_datum.weather_color_offset, min(weather_blend_amount, min_weather_blend_amount))

	if(time_percented > next_step_datum.start_at)
		time_to_animate = 24 + next_step_datum.start_at - time_percented
	else
		time_to_animate = time_percented - next_step_datum.start_at

	if(!weather_light_affecting_event)
		for(var/atom/movable/screen/fullscreen/lighting_backdrop/sunlight/screen as anything in GLOB.global_light_planes_need_vis)
			update_color(screen)

	check_cycle()

// Updates overlays and vis_contents for outdoor effects
/datum/controller/subsystem/global_light/proc/update_outdoor_effect_overlays(atom/movable/outdoor_effect/effect)
	var/turf/source = get_turf(effect)
	var/mutable_appearance/appearance
	if(effect.state != SKY_BLOCKED)
		appearance = get_sunlight_overlay(1,1,1,1, GET_TURF_PLANE_OFFSET(source)) /* fully lit */
	else //Indoor - do proper corner checks
		/* check if we are globally affected or not */
		var/static/datum/lighting_corner/dummy/dummy_lighting_corner = new

		var/datum/lighting_corner/cr = effect.source_turf.lighting_corner_SW || dummy_lighting_corner
		var/datum/lighting_corner/cg = effect.source_turf.lighting_corner_SE || dummy_lighting_corner
		var/datum/lighting_corner/cb = effect.source_turf.lighting_corner_NW || dummy_lighting_corner
		var/datum/lighting_corner/ca = effect.source_turf.lighting_corner_NE || dummy_lighting_corner

		var/fr = cr.global_light_falloff
		var/fg = cg.global_light_falloff
		var/fb = cb.global_light_falloff
		var/fa = ca.global_light_falloff

		appearance = get_sunlight_overlay(fr, fg, fb, fa, GET_TURF_PLANE_OFFSET(source))

	effect.sunlight_overlay = appearance
	//Get weather overlay if not weatherproof
	effect.overlays = effect.source_turf.ceiling_status & WEATHERVISIBLE ? list(effect.sunlight_overlay, SSweather_conditions.get_weather_overlay(effect.z)) : list(effect.sunlight_overlay)
	effect.luminosity = appearance.luminosity

//Retrieve an overlay from the list - create if necessary
/datum/controller/subsystem/global_light/proc/get_sunlight_overlay(fr, fg, fb, fa, offset)
	var/index = "[fr]|[fg]|[fb]|[fa][offset]"
	LAZYINITLIST(sunlight_overlays)
	if(!sunlight_overlays[index])
		sunlight_overlays[index] = create_global_light_overlay(fr, fg, fb, fa, offset)
	return sunlight_overlays[index]

//Create an overlay appearance from corner values
/datum/controller/subsystem/global_light/proc/create_global_light_overlay(fr, fg, fb, fa, offset)

	var/mutable_appearance/appearance = new /mutable_appearance()

	appearance.blend_mode = BLEND_OVERLAY
	appearance.icon = LIGHTING_ICON
	appearance.icon_state = null
	appearance.plane = SUNLIGHTING_PLANE - (PLANE_RANGE * offset) /* we put this on a lower level than lighting so we dont multiply anything */
	appearance.invisibility = INVISIBILITY_LIGHTING


	//appearance gets applied as an overlay, but we pull luminosity out to set our outdoor_effect object's lum
	#if LIGHTING_SOFT_THRESHOLD != 0
	appearance.luminosity = max(fr, fg, fb, fa) > LIGHTING_SOFT_THRESHOLD
	#else
	appearance.luminosity = max(fr, fg, fb, fa) > 1e-6
	#endif

	if((fr & fg & fb & fa) && (fr + fg + fb + fa == 4)) /* this will likely never happen */
		appearance.color = LIGHTING_BASE_MATRIX
	else if(!appearance.luminosity)
		appearance.color = SUNLIGHT_DARK_MATRIX
	else
		appearance.color = list(
					fr, fr, fr,  00 ,
					fg, fg, fg,  00 ,
					fb, fb, fb,  00 ,
					fa, fa, fa,  00 ,
					00, 00, 00,  01 )
	return appearance
