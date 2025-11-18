/area
	/// Whether roundstart lockers should be anchored by default in this area, if eligible.
	var/anchor_roundstart_lockers = TRUE


/area/Entered(atom/movable/arrived, area/old_area)
	. = ..()
	if(isliving(arrived))
		var/turf/arrived_turf = get_turf(arrived)
		if(!arrived_turf?.z)
			return

		for(var/type in list(ZTRAIT_ECLIPSE, ZTRAIT_STATION))
			if(SSweather_conditions.running_weathers[type] && SSmapping.level_trait(arrived_turf.z, type))
				SSweather_conditions.running_weathers[type].weather_sound_effect(arrived)
