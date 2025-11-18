
/* Our sunlight planemaster mashes all of our sunlight overlays together into one             */
/* The fullscreen then grabs the plane_master with a layer filter, and colours it             */
/* We do this so the sunlight fullscreen acts as a big lighting object, in our lighting plane */
/atom/movable/screen/fullscreen/lighting_backdrop/sunlight
	icon_state  = ""
	screen_loc = "CENTER"
	transform = null
	plane = LIGHTING_PLANE
	layer = LIGHTING_PRIMARY_LAYER
	blend_mode = BLEND_ADD
	show_when_dead = TRUE
	needs_offsetting = FALSE


/atom/movable/screen/fullscreen/lighting_backdrop/sunlight/Initialize(mapload, datum/hud/hud_owner)
	. = ..()
	if(!SSglobal_light.enabled)
		return

	GLOB.global_light_planes_need_vis |= src
	SSglobal_light.update_color(src)

/atom/movable/screen/fullscreen/lighting_backdrop/sunlight/Destroy()
	GLOB.global_light_planes_need_vis -= src
	return ..()
