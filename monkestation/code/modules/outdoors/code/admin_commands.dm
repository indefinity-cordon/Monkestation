ADMIN_VERB(run_particle_weather, R_ADMIN, FALSE, "Run Particle Weather", "Triggers a particle weather.", ADMIN_CATEGORY_EVENTS)
	if(!SSweather_conditions.enabled)
		to_chat(user, span_warning("Particle weather is currently disabled!"), type = MESSAGE_TYPE_ADMINLOG)
		return

	var/weather_type = input(user, "Choose a weather", "Weather")  as null|anything in sort_list(subtypesof(/datum/particle_weather), /proc/cmp_typepaths_asc)
	if(!weather_type)
		return

	var/where = input(user, "Choose Where", "Weather") as null|anything in list(ZTRAIT_STATION, ZTRAIT_ECLIPSE)
	if(!where)
		return

	SSweather_conditions.run_weather(new weather_type(where), where)

	message_admins("[key_name_admin(user)] started weather of type [weather_type].")
	log_admin("[key_name(user)] started weather of type [weather_type].")
	BLACKBOX_LOG_ADMIN_VERB("Run Particle Weather")
