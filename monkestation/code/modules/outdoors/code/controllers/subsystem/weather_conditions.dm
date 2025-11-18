SUBSYSTEM_DEF(weather_conditions)
	name = "Particle Weather"
	flags = SS_BACKGROUND
	wait = 30 SECONDS
	runlevels = RUNLEVEL_GAME
	var/list/eligible_weathers = list(ZTRAIT_STATION = list(), ZTRAIT_ECLIPSE = list())

	var/list/datum/particle_weather/running_weathers = list(ZTRAIT_STATION = null, ZTRAIT_ECLIPSE = null)

	var/list/datum/particle_weather/next_hits = list(ZTRAIT_STATION = null, ZTRAIT_ECLIPSE = null)
	var/list/datum/particle_weather/next_weathers_start = list(ZTRAIT_STATION = null, ZTRAIT_ECLIPSE = null)

	var/list/weathered_turfs = list()

	var/enabled = TRUE

//This has been mangled - currently only supports 1 weather effect serverwide so I can finish this
/datum/controller/subsystem/weather_conditions/Initialize()
	for(var/particle_weather_type in subtypesof(/datum/particle_weather))
		var/datum/particle_weather/particle_weather = new particle_weather_type
		if(particle_weather.target_trait in SSmapping.current_map.particle_weathers)
			eligible_weathers[ZTRAIT_STATION][particle_weather_type] = particle_weather.probability

		if(particle_weather.eclipse)
			eligible_weathers[ZTRAIT_ECLIPSE][particle_weather_type] = particle_weather.probability

	if(CONFIG_GET(flag/disable_particle_weather))
		disable()
		return SS_INIT_NO_NEED
	return SS_INIT_SUCCESS

/datum/controller/subsystem/weather_conditions/Recover()
	eligible_weathers = SSweather_conditions.eligible_weathers

	running_weathers = SSweather_conditions.running_weathers

	next_hits = SSweather_conditions.next_hits
	next_weathers_start = SSweather_conditions.next_weathers_start

	weathered_turfs = SSweather_conditions.weathered_turfs

	enabled = SSweather_conditions.enabled

/datum/controller/subsystem/weather_conditions/stat_entry(msg)
	. = ..()
	if(!enabled)
		msg = "Disabled"
		return

	for(var/type in running_weathers)
		var/datum/particle_weather/weather = running_weathers[type]
		var/datum/particle_weather/next_weather = next_hits[type]
		var/msg_event = "Idle"
		if(weather)
			if(weather.running)
				var/time_left = COOLDOWN_TIMELEFT(weather, time_left)
				msg_event = "[weather.display_name], [DisplayTimeText(time_left)] left"
			else
				msg_event = "[weather.display_name], lasted [DisplayTimeText(weather.weather_start_time + weather.weather_duration)]"

		if(next_weather)
			var/time_left = COOLDOWN_TIMELEFT(next_weather, time_left)
			msg_event = "Next event: [next_weather.display_name] hits in [DisplayTimeText(time_left)]"

		msg = "([type]: [msg_event]) "

/datum/controller/subsystem/weather_conditions/fire()
	// process active weather
	for(var/type in running_weathers)
		var/datum/particle_weather/weather = running_weathers[type]
		if(!(length(SSmapping.levels_by_trait(ZTRAIT_ECLIPSE)) && type == ZTRAIT_ECLIPSE))
			continue

		if(weather)
			weather.tick()
			continue

		var/datum/particle_weather/next_weather = next_hits[type]
		if(next_weather && COOLDOWN_TIMELEFT(next_weather, time_left))
			run_weather(next_weather, type)
			continue

		if(!next_weather && length(eligible_weathers[type]))
			for(var/our_event in eligible_weathers[type])
				if(!our_event)
					continue
				if(!prob(eligible_weathers[type][our_event]))
					continue
				next_weather = new our_event(type)
				COOLDOWN_START(next_weather, time_left, rand(-3000, 3000) + initial(next_weather.weather_duration_upper) / 5)
				next_hits[type] = next_weather
				break

/datum/controller/subsystem/weather_conditions/proc/disable()
	flags |= SS_NO_FIRE
	enabled = FALSE
	stop_weather("Station")
	stop_weather("Eclipse")

/datum/controller/subsystem/weather_conditions/proc/run_weather(datum/particle_weather/weather_datum, type = ZTRAIT_STATION, force = FALSE)
	if(!enabled)
		return

	if(!istype(weather_datum, /datum/particle_weather))
		CRASH("run_weather called with invalid weather_datum: [weather_datum || "null"]")

	if(running_weathers[type])
		if(!running_weathers[type].running)
			qdel(running_weathers[type])
			return

		if(!force)
			return

		running_weathers[type].wind_down(TRUE)
		if(running_weathers[type].particle_effect)
			sleep(running_weathers[type].particle_effect.lifespan + running_weathers[type].particle_effect.fade)

	running_weathers[type] = weather_datum
	weather_datum.start()
	next_hits[type] = null

/datum/controller/subsystem/weather_conditions/proc/make_eligible(datum/particle_weather/weather_datum, probability = 10)
	eligible_weathers[weather_datum] = probability

/datum/controller/subsystem/weather_conditions/proc/stop_weather(z_type)
	if(running_weathers[type])
		running_weathers[type].wind_down(TRUE)


//get our weather overlay
/datum/controller/subsystem/weather_conditions/proc/get_weather_overlay(z_level)
	var/plane_level =  WEATHER_OVERLAY_PLANE
	if(SSmapping.level_has_all_traits(z_level, list(ZTRAIT_ECLIPSE)))
		plane_level = WEATHER_OVERLAY_PLANE_ECLIPSE

	var/mutable_appearance/appearance = new /mutable_appearance()
	appearance.blend_mode = BLEND_OVERLAY
	appearance.icon = 'monkestation/code/modules/outdoors/icons/effects/weather_overlay.dmi'
	appearance.icon_state = "weather_overlay"
	appearance.plane = plane_level /* we put this on a lower level than lighting so we dont multiply anything */
	appearance.invisibility = INVISIBILITY_LIGHTING
	return appearance

/obj/weather_effect
	plane = LIGHTING_PLANE
