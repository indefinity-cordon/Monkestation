GLOBAL_LIST_EMPTY(siren_objects)

#define GLE_STAGE_NONE		FALSE
#define GLE_STAGE_FIRST		1
#define GLE_STAGE_SECOND	2
#define GLE_STAGE_THIRD		3
#define GLE_STAGE_FOUR		4
#define GLE_TAGE_FIVE		5
#define GLE_STAGE_SIX		6

/turf
	var/obj/structure/snow/snow

//TODO: Do in right way events, without shitcode (some day in far-far future I'll do it) //EDIT: never happened, project died (lego falling apart sound download, free no ADs)

//SPECIAL EVENTS
/datum/weather_event
	var/name = ""
	var/affecting_value
	var/duration = 0
	var/started_at = 0
	var/repeats = 0
	var/max_stages = 0
	var/stage = GLE_STAGE_NONE
	var/datum/particle_weather/initiator_ref

/datum/weather_event/New(datum/particle_weather/particle_weather)
	. = ..()
	initiator_ref = particle_weather
	start_process()

/datum/weather_event/Destroy(force)
	if(initiator_ref)
		initiator_ref.weather_additional_ongoing_events -= src
		initiator_ref = null

	. = ..()

/datum/weather_event/proc/start_process()
	return

/datum/weather_event/proc/stage_process()
	return

/datum/weather_event/thunder
	name = "Thunder"
	duration = 1 SECONDS
	affecting_value = list("#74DFF7", "#81A7DB", "#7997FC", "#5b73c3", "#2e5fff")
	max_stages = 3
	stage = GLE_STAGE_FIRST
	var/sound_effects = list(
		'monkestation/code/modules/outdoors/sound/weather/rain/thunder_1.ogg', 'monkestation/code/modules/outdoors/sound/weather/rain/thunder_2.ogg', 'monkestation/code/modules/outdoors/sound/weather/rain/thunder_3.ogg', 'monkestation/code/modules/outdoors/sound/weather/rain/thunder_4.ogg',
		'monkestation/code/modules/outdoors/sound/weather/rain/thunder_5.ogg', 'monkestation/code/modules/outdoors/sound/weather/rain/thunder_6.ogg', 'monkestation/code/modules/outdoors/sound/weather/rain/thunder_7.ogg',
	)

/datum/weather_event/thunder/Destroy(force)
	if(SSglobal_light.weather_light_affecting_event && SSglobal_light.weather_light_affecting_event == src)
		SSglobal_light.weather_light_affecting_event = null

	. = ..()

/datum/weather_event/thunder/start_process()
	repeats = rand(1, 3)
	duration = duration + rand(-duration*5, duration*10)/10
	SSglobal_light.weather_light_affecting_event = src
	stage_process()

//TODO: If I or some body else come around, better really do it normal way, not the way of "Третий час ночи, я в тылу врага, они странно изменять своя внешность, один из них отрастить рога"
/datum/weather_event/thunder/stage_process()
	var/color_animating
	var/animate_flags = CIRCULAR_EASING
	switch(stage)
		if(GLE_STAGE_FIRST)
			color_animating = pick(affecting_value)
			animate_flags = ELASTIC_EASING | EASE_IN | EASE_OUT
			spawn(duration - rand(0, duration * 10) / 10)
			playsound_z(SSmapping.levels_by_trait(initiator_ref.plane_type), pick(sound_effects), 50, _mixer_channel = CHANNEL_WEATHER)

		if(GLE_STAGE_THIRD)
			if(SSglobal_light.enabled)
				color_animating = SSglobal_light.current_color
			animate_flags = CIRCULAR_EASING | EASE_IN

	if(color_animating && SSglobal_light.enabled)
		for(var/atom/movable/screen/fullscreen/lighting_backdrop/sunlight/plane in GLOB.global_light_planes_need_vis)
			animate(plane, color = color_animating, easing = animate_flags, time = duration)

	sleep(duration)
	stage++
	if(repeats && stage > max_stages)
		repeats--
		stage = GLE_STAGE_FIRST
		sleep(duration)

	else if(stage > max_stages)
		SSglobal_light.weather_light_affecting_event = null
		if(SSglobal_light.enabled)
			for(var/atom/movable/screen/fullscreen/lighting_backdrop/sunlight/plane in GLOB.global_light_planes_need_vis)
				SSglobal_light.update_color(plane)
		qdel(src)
		return

	stage_process()

/datum/weather_event/wind
	name = "Wind"
	duration = 10 SECONDS
	affecting_value = list("min_value" = 10, "max_value" = 60)
	max_stages = 2
	stage = GLE_STAGE_FIRST

/datum/weather_event/wind/start_process()
	duration = duration + rand(-duration, duration)
	stage_process()

/datum/weather_event/wind/stage_process()
	switch(stage)
		if(GLE_STAGE_FIRST)
			initiator_ref.wind_severity = rand(affecting_value["min_value"], affecting_value["max_value"])
		if(GLE_STAGE_SECOND)
			initiator_ref.wind_severity = rand(0, affecting_value["max_value"])
		if(GLE_STAGE_THIRD)
			initiator_ref.wind_severity = rand(0, affecting_value["min_value"])

	initiator_ref.change_severity(FALSE)

	sleep(duration)
	stage++
	if(repeats)
		repeats--
		stage = initial(stage)
		start_process()
		return

	else if(stage > max_stages)
		initiator_ref.wind_severity = 0
		qdel(src)
		return

	stage_process()


/datum/weather_effect
	var/name = "effect"
	var/probability = 0
	var/datum/particle_weather/initiator_ref

/datum/weather_effect/proc/effect_affect(turf/target_turf)
	return FALSE

/datum/weather_effect/rain
	name = "rain effect"
	probability = 60

/datum/weather_effect/rain/effect_affect(turf/target_turf)
	for(var/obj/effect/decal/cleanable/decal in target_turf)
		qdel(decal)

//	if(target_turf.snow && prob(probability * 0.25))
//		target_turf.snow.damage_act(1)

/datum/weather_effect/snow
	name = "snow effect"
	probability = 20

/datum/weather_effect/snow/effect_affect(turf/target_turf)
//	if(!target_turf.snow)
//		new /obj/structure/snow(target_turf, 1)
//	else
//		target_turf.snow.weathered(src)

// Do you like the sonw?
// No
// Why not?
// sobs ... sobs
// Can you say snooooow?
// Waaaaaaaaaaaaaaaaaaaaaaaaaa
/* idk I don't know this codebase and don't want waste more time
/obj/structure/snow
	name = "Snow"
	desc = "Big pile of snow"
	icon = 'core_ru/icons/effects/snow.dmi'
	icon_state = "snow_1"
	var/icon_prefix = "snow"
	anchored = TRUE
	density = FALSE
	throwpass = TRUE
	plane = GAME_PLANE
	layer = BELOW_TABLE_LAYER
	var/bleed_layer = 0
	var/progression = 0
	var/turf/snowed_turf
	var/list/snows_connections = list(list("0", "0", "0", "0"), list("0", "0", "0", "0"), list("0", "0", "0", "0"))
	var/list/diged = list("2" = 0, "1" = 0, "8" = 0, "4" = 0)

/obj/structure/snow/Initialize(mapload, bleed_layers)
	. = ..()
	icon_state = "blank"
	bleed_layer = bleed_layers
	if(!bleed_layer)
		bleed_layer = rand(1, 3)

	update_visuals_effects()
	RegisterSignal(src, COMSIG_ATOM_TURF_CHANGE, PROC_REF(update_visuals_effects))

	START_PROCESSING(SSslowobj, src)

	update_corners(TRUE)
	update_overlays()

/obj/structure/snow/Destroy(force)
	update_visuals_effects(src, FALSE)
	STOP_PROCESSING(SSslowobj, src)
	snowed_turf.snow = null
	snowed_turf = null

	. = ..()

/obj/structure/snow/process()
	if(!SSweather_conditions.running_weather)
		damage_act(3)
	else if(SSweather_conditions.running_weather.weather_special_effect != /datum/weather_effect/snow)
		damage_act(6)
	update_overlays()

/obj/structure/snow/proc/update_visuals_effects(datum/source, replace = TRUE)
	SIGNAL_HANDLER

	var/list/contained_mobs = list()
	for(var/mob/living/contained_mob in contents)
		contained_mobs += contained_mob
		SEND_SIGNAL(src, COMSIG_MOB_OVERLAY_FORCE_REMOVE, contained_mob)

	RemoveElement(/datum/element/mob_overlay_effect)
	if(replace)
		AddElement(/datum/element/mob_overlay_effect, bleed_layer * 2.4, bleed_layer * 1.2, 100)
		for(var/mob/living/contained_mob as anything in contained_mobs)
			SEND_SIGNAL(src, COMSIG_MOB_OVERLAY_FORCE_UPDATE, contained_mob)

/obj/structure/snow/proc/update_corners(propagate = FALSE)
	var/list/snow_dirs = list(list(), list(), list())
	var/turf/turf = get_turf(src)
	if(!turf)
		return
	if(turf != snowed_turf)
		if(snowed_turf)
			snowed_turf.snow = null
		snowed_turf = turf
		snowed_turf.snow = src

	if(snowed_turf.weeds)
		snowed_turf.weeds.Destroy()

	for(var/obj/structure/snow/bordered_snow in orange(src, 1))
		if(!bordered_snow)
			continue

		if(propagate)
			bordered_snow.update_corners()
			bordered_snow.update_overlays()

		var/direction = get_dir(src, bordered_snow)
		for(var/deep = 1 to length(snow_dirs))
			if(deep > bleed_layer)
				continue

			if(deep > bordered_snow.bleed_layer)
				continue

			snow_dirs[deep] += direction

	for(var/deep = 1 to length(snow_dirs))
		snows_connections[deep] = dirs_to_corner_states(snow_dirs[deep])

/obj/structure/snow/proc/update_overlays()
	if(overlays)
		overlays.Cut()

	for(var/deep = 1 to length(snows_connections))
		if(deep > bleed_layer)
			continue

		for(var/i = 1 to 4)
			overlays += image(icon, "[icon_prefix]_[deep]_[snows_connections[deep][i]]", dir = 1<<(i-1))

	var/new_overlay = ""
	for(var/i in diged)
		if(diged[i] > world.time)
			new_overlay += i
	overlays += "[new_overlay]"

/obj/structure/snow/proc/damage_act(damage)
	var/remaining = progression - damage
	if(remaining > 0 )
		progression = remaining
	else
		if(remaining < -(bleed_layer * 4))
			changing_layer(0)
		else
			changing_layer(bleed_layer - 1)
			progression = bleed_layer * 4

/obj/structure/snow/get_projectile_hit_boolean(obj/projectile/proj)
	return FALSE

/obj/structure/snow/bullet_act(obj/projectile/proj)
	return FALSE

/obj/structure/snow/flamer_fire_act(damage)
	damage_act(damage)

/obj/structure/snow/proc/weathered(datum/weather_effect/effect)
	if(progression < bleed_layer * 8)
		progression++
	else
		if(bleed_layer >= 3)
			for(var/direction in GLOB.alldirs)
				var/turf/turf = get_step(loc, direction)
				if(!turf.snow)
					turf.apply_weather_effect(effect)
					break

				else if(turf.snow && turf.snow.bleed_layer != 3)
					turf.snow.progression += progression
					break
		else
			changing_layer(min(bleed_layer + 1, MAX_LAYER_SNOW_LEVELS))

		progression = 0

/obj/structure/snow/proc/changing_layer(new_layer)
	if(isnull(new_layer) || new_layer == bleed_layer)
		return

	bleed_layer = max(0, new_layer)

	if(!bleed_layer)
		qdel(src)
		return

	switch(bleed_layer)
		if(1)
			throwpass= TRUE
			layer = BELOW_TABLE_LAYER
		if(2)
			throwpass= TRUE
			layer = BELOW_OBJ_LAYER
		if(3)
			throwpass= FALSE
			layer = OBJ_LAYER

	update_corners(TRUE)
	update_overlays()

	update_visuals_effects()

/obj/structure/snow/ex_act(severity)
	damage_act(severity)

/obj/structure/snow/Crossed(atom/movable/arrived)
	. = ..()
	if(isliving(arrived))
		var/mob/living/living = arrived
		if(bleed_layer > 1)
			var/new_slowdown = living.next_move_slowdown + (0.35 * bleed_layer)
			if(prob(10))
				to_chat(living, SPAN_WARNING("Moving through [src] slows you down.")) //Warning only
				new_slowdown += 2 SECONDS
			else if(bleed_layer == 3 && prob(2))
				to_chat(living, SPAN_WARNING("You get stuck in [src] for a moment!"))
				new_slowdown += 4 SECONDS
			living.next_move_slowdown = new_slowdown
		set_diged_ways(GLOB.reverse_dir[living.dir])

/obj/structure/snow/Uncrossed(atom/movable/gone)
	. = ..()
	if(isliving(gone))
		set_diged_ways(gone.dir)

/obj/structure/snow/proc/set_diged_ways(dir)
	diged["[dir]"] = world.time + 1 MINUTES
	update_overlays()

/obj/structure/snow/attack_alien(mob/living/carbon/xenomorph/xenomorph)
	if(xenomorph.a_intent == INTENT_HARM) //Missed slash.
		return
	if(xenomorph.a_intent == INTENT_HELP || !bleed_layer)
		return ..()

	xenomorph.visible_message(SPAN_NOTICE("[xenomorph] starts clearing out \the [src]..."), SPAN_NOTICE("You start clearing out \the [src]..."), null, 5, CHAT_TYPE_XENO_COMBAT)
	playsound(xenomorph.loc, 'sound/weapons/alien_claw_swipe.ogg', 25, 1)

	while(bleed_layer > 0)
		xeno_attack_delay(xenomorph)
		if(!do_after(xenomorph, 12, INTERRUPT_ALL, BUSY_ICON_FRIENDLY))
			return XENO_NO_DELAY_ACTION

		if(!bleed_layer)
			to_chat(xenomorph, SPAN_WARNING("There is nothing to clear out!"))
			return XENO_NO_DELAY_ACTION

		var/new_layer = bleed_layer - 1
		changing_layer(new_layer)

	return XENO_NO_DELAY_ACTION
*/


/datum/particle_weather
	var/name = "set this"
	var/display_name = "set this"
	var/desc = "set this"

	var/list/weather_messages = list()
	var/list/weather_warnings = list("siren" = null, "message" = TRUE)
	var/list/weather_sounds = list()
	var/list/indoor_weather_sounds = list()
	var/list/wind_sounds = list(/datum/looping_sound/wind)
	var/scale_vol_with_severity = TRUE

	var/particle_effect_type = /particles/weather/rain
	var/particles/weather/particle_effect = null

	var/weather_duration_lower = 5 MINUTES
	var/weather_duration_upper = 20 MINUTES

	var/damage_type = null
	var/damage_per_tick = 0
	var/wind_severity = 0
	var/min_severity = 1
	var/max_severity = 100
	var/max_severity_change = 20
	var/severity_steps = 5
	var/immunity_type = TRAIT_WEATHER_IMMUNE
	var/probability = 0

	var/target_trait = PARTICLEWEATHER_RAIN
	var/severity_steps_taken = 0
	var/running = FALSE
	var/severity = 0
	var/barometer_predictable = FALSE

	COOLDOWN_DECLARE(time_left)
	var/weather_duration = 0
	var/weather_start_time = 0

	var/weather_special_effect_path
	var/datum/weather_effect/weather_special_effect

	var/weather_color_offset
	var/list/weather_additional_events = list()
	var/list/datum/weather_event/weather_additional_ongoing_events = list()
	var/list/mob/living/messaged_mobs = list()
	var/list/datum/looping_sound/current_sounds = list()
	var/list/datum/looping_sound/current_wind_sounds = list()
	var/list/affected_zlevels = list()
	var/fire_smothering_strength = 0

	var/last_message = ""

	var/plane_type = "Default"
	var/eclipse = FALSE

/datum/particle_weather/New(set_plane_type)
	if(weather_special_effect)
		weather_special_effect = new weather_special_effect(src)

	. = ..()

	if(set_plane_type)
		plane_type = set_plane_type

/datum/particle_weather/Destroy()
	if(SSweather_conditions.running_weathers[type] == src)
		SSweather_conditions.running_weathers[type] = null
	messaged_mobs = null
	for(var/atom/movable/screen/plane_master/weather_effect/plane in GLOB.weather_planes[plane_type])
		plane.particles = null
	QDEL_NULL(particle_effect)
	QDEL_NULL(weather_special_effect)
	QDEL_LIST(weather_additional_ongoing_events)
	QDEL_LIST_ASSOC_VAL(current_sounds)
	QDEL_LIST_ASSOC_VAL(current_wind_sounds)

	. = ..()

/datum/particle_weather/proc/severity_mod()
	return severity / max_severity

/datum/particle_weather/proc/tick()
	if(weather_additional_events && prob(max(severity, 10)))
		for(var/event in weather_additional_events)
			if(!prob(weather_additional_events[event][1]))
				continue
			var/str = weather_additional_events[event][2]
			weather_additional_ongoing_events += new str(src)

/datum/particle_weather/proc/start()
	if(running)
		return
	weather_duration = rand(weather_duration_lower, weather_duration_upper)
	COOLDOWN_START(src, time_left, weather_duration)
	weather_start_time = world.time
	running = TRUE
	addtimer(CALLBACK(src, PROC_REF(wind_down)), weather_duration)
	weather_warnings()
	if(particle_effect_type)
		particle_effect = new particle_effect_type
		for(var/atom/movable/screen/plane_master/weather_effect/plane in GLOB.weather_planes[plane_type])
			plane.particles = particle_effect

	change_severity()

/datum/particle_weather/proc/change_severity(as_step = TRUE)
	if(!running)
		return
	if(as_step)
		severity_steps_taken++

	if(max_severity_change == 0)
		severity = rand(min_severity, max_severity)
	else
		var/new_severity = severity + rand(-max_severity_change, max_severity_change)
		new_severity = clamp(new_severity, min_severity, max_severity)
		severity = new_severity

	severity = clamp(severity + wind_severity, min_severity, max_severity)

	if(particle_effect)
		particle_effect.animate_severity(severity_mod())

	if(last_message != scale_range_pick(min_severity, max_severity, severity, weather_messages))
		messaged_mobs = list()

	if(severity_steps_taken < severity_steps && as_step)
		addtimer(CALLBACK(src, PROC_REF(change_severity)), weather_duration / severity_steps)

/datum/particle_weather/proc/wind_down(destroy_after)
	severity = 0
	if(particle_effect)
		particle_effect?.animate_severity(severity_mod())
	//Wait for the last particle to fade, then qdel yourself
	if(destroy_after)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(qdel), src), particle_effect.lifespan + particle_effect.fade)
	else
		addtimer(VARSET_CALLBACK(src, running, FALSE), particle_effect.lifespan + particle_effect.fade)

/datum/particle_weather/proc/can_weather(mob/living/mob_to_check)
	var/turf/mob_turf = get_turf(mob_to_check)
	var/area/mob_area = get_area(mob_turf)
	if(istype(mob_area, /area/shuttle))
		return
	if(!mob_turf)
		return

	if(mob_turf.turf_flags & TURF_WEATHER)
		return TRUE

	return FALSE

/datum/particle_weather/proc/can_weather_effect(mob/living/mob_to_check)

	//If mob is not in a turf
	var/turf/mob_turf = get_turf(mob_to_check)

	if((immunity_type && HAS_TRAIT(mob_to_check, immunity_type)) || HAS_TRAIT(mob_to_check, TRAIT_WEATHER_IMMUNE))
		return

	var/atom/loc_to_check = mob_to_check.loc
	while(loc_to_check != mob_turf)
		if((immunity_type && HAS_TRAIT(loc_to_check, immunity_type)) || HAS_TRAIT(loc_to_check, TRAIT_WEATHER_IMMUNE))
			return
		loc_to_check = loc_to_check.loc

	return TRUE

/datum/particle_weather/proc/process_mob_effect(mob/living/target, delta_time)
	if(!islist(messaged_mobs))
		messaged_mobs = list()
	messaged_mobs |= target
	weather_sound_effect(target)
	if(can_weather(target) && running)
		if(!can_weather_effect(target))
			return

		if((last_message || weather_messages) && (!messaged_mobs[target] || world.time > messaged_mobs[target]))
			weather_message(target)
		affect_mob_effect(target, delta_time)
	else
		var/turf/mob_turf = get_turf(target)
		if(mob_turf)
			if(!SSmapping.level_trait(mob_turf.z, plane_type))
				stop_weather_sound_effect(target)

		messaged_mobs -= target

/datum/particle_weather/proc/affect_mob_effect(mob/living/target, delta_time, calculated_damage)
	var/base_damage = calculate_base_damage_for_mob(target)
	if(base_damage)
		calculated_damage = base_damage * delta_time
		target.apply_damage(calculated_damage, damage_type)

/datum/particle_weather/proc/calculate_base_damage_for_mob(mob/living/target)
	return damage_per_tick || 0

/datum/particle_weather/proc/weather_sound_effect(mob/living/hearer)
	var/datum/looping_sound/current_sound = current_sounds[hearer]
	var/turf/mob_turf = get_turf(hearer)
	if(!mob_turf)
		return


	if(mob_turf.turf_flags & TURF_WEATHER)
		if(current_sound?.type in weather_sounds)
			if(scale_vol_with_severity)
				current_sound.volume = initial(current_sound.volume) * severity_mod()
			if(!current_sound.loop_started) //don't restart already playing sounds
				current_sound.start()
			return
		current_sound?.stop()
		var/temp_sound = scale_range_pick(min_severity, max_severity, severity, weather_sounds)
		if(temp_sound)
			current_sound = new temp_sound(hearer, FALSE, TRUE, FALSE, CHANNEL_WEATHER)
			current_sounds[hearer] = current_sound
			//SET VOLUME
			if(scale_vol_with_severity)
				current_sound.volume = initial(current_sound.volume) * severity_mod()
			current_sound.start()
	else
		if(current_sound?.type in indoor_weather_sounds)
			if(scale_vol_with_severity)
				current_sound.volume = initial(current_sound.volume) * severity_mod()
			if(!current_sound.loop_started) //don't restart already playing sounds
				current_sound.start()
			return
		current_sound?.stop()
		var/temp_sound = scale_range_pick(min_severity, max_severity, severity, indoor_weather_sounds)
		if(temp_sound)
			current_sound = new temp_sound(hearer, FALSE, TRUE, FALSE, CHANNEL_WEATHER)
			current_sounds[hearer] = current_sound
			//SET VOLUME
			if(scale_vol_with_severity)
				current_sound.volume = initial(current_sound.volume) * severity_mod()
			current_sound.start()

	if(wind_severity && weather_sounds)
		var/datum/looping_sound/current_wind_sound = current_wind_sounds[hearer]
		if(current_wind_sound)
			//SET VOLUME
			if(scale_vol_with_severity)
				current_wind_sound.volume = initial(current_wind_sound.volume) * severity_mod()
			if(!current_wind_sound.loop_started) //don't restart already playing sounds
				current_wind_sound.start()
			return

		var/temp_wind_sound = scale_range_pick(min_severity, max_severity, severity, wind_sounds)
		if(temp_wind_sound)
			current_wind_sound = new temp_wind_sound(hearer, FALSE, TRUE, FALSE, CHANNEL_WEATHER)
			current_wind_sounds[hearer] = current_wind_sound
			//SET VOLUME
			if(scale_vol_with_severity)
				current_wind_sound.volume = initial(current_wind_sound.volume) * severity_mod()
			current_wind_sound.start()


/datum/particle_weather/proc/stop_weather_sound_effect(mob/living/hearer)
	current_sounds[hearer]?.stop()
	current_wind_sounds[hearer]?.stop()

/datum/particle_weather/proc/weather_message(mob/living/target)
	messaged_mobs[target] = world.time + WEATHER_MESSAGE_DELAY
	last_message = scale_range_pick(min_severity, max_severity, severity, weather_messages)
	if(last_message)
		to_chat(target, span_danger(last_message))

/datum/particle_weather/proc/weather_warnings()
	switch(weather_warnings)
		if("siren")
			for(var/obj/machinery/siren/weather/weather_siren in GLOB.siren_objects["weather"])
				if(weather_siren.z in affected_zlevels)
					weather_siren.siren_warning(weather_warnings["siren"])
		if("message")
			var/message = "Incoming [display_name]"
			if(length(weather_warnings["message"]))
				var/weather_message = weather_warnings["message"]
				message += weather_message
			for(var/mob/living/carbon/human/affected_human in GLOB.alive_mob_list)
				if(affected_human.stat || QDELETED(affected_human.client))
					continue
				var/turf/affected_turf = get_turf(affected_human)
				if(!(affected_turf?.z in affected_zlevels))
					continue
				affected_human.playsound_local('monkestation/code/modules/outdoors/sound/effects/radiostatic.ogg', affected_human.loc, 25, FALSE, mixer_channel = CHANNEL_MACHINERY)
				affected_human.play_screen_text("<span class='langchat' style=font-size:16pt;text-align:center valign='top'><u>Weather Alert:</u></span><br>" + message["human"], /atom/movable/screen/text/screen_text/command_order, rgb(103, 214, 146))
    return FALSE

/datum/looping_sound/dust_storm
	mid_sounds = 'monkestation/code/modules/outdoors/sound/weather/dust/weather_dust.ogg'
	mid_length = 80
	volume = 150

/datum/looping_sound/rain
	mid_sounds = 'monkestation/code/modules/outdoors/sound/weather/rain/weather_rain.ogg'
	mid_length = 40 SECONDS
	volume = 200

/datum/looping_sound/indoor_rain
	mid_sounds = 'monkestation/code/modules/outdoors/sound/weather/rain/weather_rain_indoors.ogg'
	mid_length = 15 SECONDS
	volume = 200

/datum/looping_sound/storm
	mid_sounds = 'monkestation/code/modules/outdoors/sound/weather/rain/weather_storm.ogg'
	mid_length = 30 SECONDS
	volume = 150

/datum/looping_sound/snow
	mid_sounds = 'monkestation/code/modules/outdoors/sound/weather/snow/weather_snow.ogg'
	mid_length = 50 SECONDS
	volume = 150

/datum/looping_sound/wind
	mid_sounds = 'monkestation/code/modules/outdoors/sound/weather/rain/wind_1.ogg'
	mid_sounds = list(
		'monkestation/code/modules/outdoors/sound/weather/rain/wind_1.ogg'=1,
		'monkestation/code/modules/outdoors/sound/weather/rain/wind_2.ogg'=1,
		'monkestation/code/modules/outdoors/sound/weather/rain/wind_3.ogg'=1,
		'monkestation/code/modules/outdoors/sound/weather/rain/wind_4.ogg'=1,
		'monkestation/code/modules/outdoors/sound/weather/rain/wind_5.ogg'=1,
		'monkestation/code/modules/outdoors/sound/weather/rain/wind_6.ogg'=1
		)
	mid_length = 30 SECONDS
	volume = 150

//IDK WHERE SUPPOSED TO PUT
/obj/machinery/siren
	name = "Siren"
	desc = "A siren used to play warnings for the station."
	icon = 'monkestation/code/modules/outdoors/icons/obj/machines/loudspeaker.dmi'
	icon_state = "loudspeaker"
	density = FALSE
	anchored = TRUE
	use_power = NO_POWER_USE
	processing_flags = START_PROCESSING_MANUALLY
	var/message = "BLA BLA BLA"
	var/sound = 'monkestation/code/modules/outdoors/sound/effects/weather_warning.ogg'

/obj/machinery/siren/proc/siren_warning(var/msg = "WARNING, bla bla bla bluh.", var/sound_ch = 'monkestation/code/modules/outdoors/sound/effects/weather_warning.ogg')
	playsound(loc, sound_ch, 50, 0, mixer_channel = CHANNEL_MACHINERY)
	visible_message(span_danger("[src] makes a signal. [msg]."))

/obj/machinery/siren/proc/siren_warning_start(var/msg, var/sound_ch = 'monkestation/code/modules/outdoors/sound/effects/weather_warning.ogg')
	if(!msg)
		return
	message = msg
	sound = sound_ch
	begin_processing()

/obj/machinery/siren/proc/siren_warning_stop()
	end_processing()

/obj/machinery/siren/process()
	if(prob(2))
		playsound(loc, sound, 80, 0, mixer_channel = CHANNEL_MACHINERY)
		visible_message(span_danger("[src] makes a signal. [message]."))

/obj/machinery/siren/weather
	name = "Weather Siren"
	desc = "A siren used to play weather warnings for the station."
