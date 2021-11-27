/*
MICROFUSION GUN UPGRADE ATTACHMENTS

For adding unique abilities to microfusion guns, these can directly interact with the gun!
*/

/obj/item/microfusion_gun_attachment
	name = "microfusion gun attachment"
	desc = "broken"
	icon = 'modular_skyrat/modules/microfusion/icons/microfusion_gun_attachments.dmi'
	w_class = WEIGHT_CLASS_NORMAL
	/// The attachment overlay icon state.
	var/attachment_overlay_icon_state
	/// Any incompatable upgrade types.
	var/list/incompatable_attachments = list()
	/// The added heat produced by having this module installed.
	var/heat_addition = 0

/obj/item/microfusion_gun_attachment/proc/run_attachment(obj/item/gun/microfusion/microfusion_gun)
	SHOULD_CALL_PARENT(TRUE)
	microfusion_gun.heat_per_shot += heat_addition
	microfusion_gun.update_appearance()
	return

/obj/item/microfusion_gun_attachment/proc/process_attachment(obj/item/gun/microfusion/microfusion_gun)
	return

//Firing the gun right before we let go of it, tis is called.
/obj/item/microfusion_gun_attachment/proc/process_fire(obj/item/gun/microfusion/microfusion_gun, obj/item/ammo_casing/chambered)
	return

/obj/item/microfusion_gun_attachment/proc/remove_attachment(obj/item/gun/microfusion/microfusion_gun)
	SHOULD_CALL_PARENT(TRUE)
	microfusion_gun.heat_per_shot -= heat_addition
	microfusion_gun.update_appearance()
	return

/obj/item/microfusion_gun_attachment/proc/get_modify_data()
	return

/obj/item/microfusion_gun_attachment/proc/run_modify_data(params, mob/living/user)
	return

/obj/item/microfusion_gun_attachment/proc/get_information_data()
	return

/*
SCATTER ATTACHMENT

The cell is stable and will not emit sparks when firing.
*/
/obj/item/microfusion_gun_attachment/scatter
	name = "diffuser microfusion lens upgrade"
	desc = "Splits the microfusion laser beam entering the lens!"
	icon_state = "attachment_scatter"
	attachment_overlay_icon_state = "attachment_scatter"
	incompatable_attachments = list(/obj/item/microfusion_gun_attachment/repeater, /obj/item/microfusion_gun_attachment/xray)
	/// How many pellets are we going to add to the existing amount on the gun?
	var/pellets_to_add = 2
	/// The variation in pellet scatter.
	var/variance_to_add = 10
	/// How much recoil are we adding?
	var/recoil_to_add = 1
	/// Have we been 'hacked?'
	var/hacked = FALSE

/obj/item/microfusion_gun_attachment/scatter/multitool_act(mob/living/user, obj/item/tool)
	if(hacked)
		to_chat(user, span_warning("[src] is already overriden!"))
		return
	to_chat(user, span_notice("You begin to override the automatic variance control..."))
	if(do_after(user, 5 SECONDS, src))
		hacked = TRUE
		to_chat(user, span_notice("You override the automatic variance control."))

/obj/item/microfusion_gun_attachment/scatter/proc/set_variance(mob/living/user)
	variance_to_add = clamp(input(user, "Please input a new lens variance adjustment (5-30):", "Lens Adjustment") as null|num, 5, 30)
	to_chat(user, span_notice("Lens variance percent set to: [variance_to_add]."))

/obj/item/microfusion_gun_attachment/scatter/attack_self(mob/user, modifiers)
	. = ..()
	set_variance(user)

/obj/item/microfusion_gun_attachment/scatter/get_information_data()
	return "Variance: [variance_to_add] | [hacked ? "UNLOCKED" : "LOCKED"]"

/obj/item/microfusion_gun_attachment/scatter/get_modify_data()
	if(!hacked)
		return
	var/list/params = list()
	params["variance"] = "Variance"
	return params

/obj/item/microfusion_gun_attachment/scatter/run_modify_data(params, mob/living/user)
	if(params == "variance")
		set_variance(user)

/obj/item/microfusion_gun_attachment/scatter/run_attachment(obj/item/gun/microfusion/microfusion_gun)
	. = ..()
	microfusion_gun.recoil += recoil_to_add
	for(var/obj/item/ammo_casing/ammo_casing in microfusion_gun.ammo_type)
		ammo_casing.pellets += pellets_to_add
		ammo_casing.variance += variance_to_add

/obj/item/microfusion_gun_attachment/scatter/process_fire(obj/item/gun/microfusion/microfusion_gun, obj/item/ammo_casing/chambered)
	. = ..()
	chambered.loaded_projectile?.damage = chambered.loaded_projectile.damage / chambered.pellets

/obj/item/microfusion_gun_attachment/scatter/remove_attachment(obj/item/gun/microfusion/microfusion_gun)
	. = ..()
	microfusion_gun.recoil -= recoil_to_add
	for(var/obj/item/ammo_casing/ammo_casing in microfusion_gun.ammo_type)
		ammo_casing.pellets -= ammo_casing.pellets
		ammo_casing.variance -= ammo_casing.variance

/*
FOCUSING ATTACHMENT

The cell is stable and will not emit sparks when firing.
*/
/obj/item/microfusion_gun_attachment/focus
	name = "focusing microfusion lens upgrade"
	desc = "Focuses the microfusion beam into a more concentrated lane, increasing accuracy!"
	icon_state = "attachment_focus"
	attachment_overlay_icon_state = "attachment_focus"
	/// How much recoil are we removing?
	var/recoil_to_remove = 1
	var/spread_to_remove = 5

/obj/item/microfusion_gun_attachment/focus/run_attachment(obj/item/gun/microfusion/microfusion_gun)
	. = ..()
	microfusion_gun.recoil -= recoil_to_remove

/obj/item/microfusion_gun_attachment/focus/remove_attachment(obj/item/gun/microfusion/microfusion_gun)
	. = ..()
	microfusion_gun.recoil += recoil_to_remove

/*
REPEATER ATTACHMENT

The gun can fire volleys of shots.
*/
/obj/item/microfusion_gun_attachment/repeater
	name = "repeating phase emitter upgrade"
	desc = "Upgrades the central phase emitter to repeat twice."
	icon_state = "attachment_repeater"
	attachment_overlay_icon_state = "attachment_repeater"
	incompatable_attachments = list(/obj/item/microfusion_gun_attachment/scatter)
	heat_addition = 40
	var/recoil_to_add = 1
	var/burst_to_add = 1
	var/delay_to_add = 2

/obj/item/microfusion_gun_attachment/repeater/run_attachment(obj/item/gun/microfusion/microfusion_gun)
	. = ..()
	microfusion_gun.recoil += recoil_to_add
	microfusion_gun.burst_size += burst_to_add
	microfusion_gun.fire_delay += delay_to_add

/obj/item/microfusion_gun_attachment/repeater/remove_attachment(obj/item/gun/microfusion/microfusion_gun)
	. = ..()
	microfusion_gun.recoil -= recoil_to_add
	microfusion_gun.burst_size -= burst_to_add
	microfusion_gun.fire_delay -= delay_to_add

/*
X-RAY ATTACHMENT

The gun can fire X-RAY shots.
*/
/obj/item/microfusion_gun_attachment/xray
	name = "quantum phase inverter emitter array" //Yes quantum makes things sound cooler.
	desc = "Experimental technology that inverts the central phase emitter causing the wave frequency to shift into X-ray. CAUTION: Phase emitter heats up very quickly."
	icon_state = "attachment_xray"
	attachment_overlay_icon_state = "attachment_xray"
	incompatable_attachments = list(/obj/item/microfusion_gun_attachment/scatter)
	heat_addition = 90

/obj/item/microfusion_gun_attachment/xray/run_attachment(obj/item/gun/microfusion/microfusion_gun)
	. = ..()
	microfusion_gun.heat_per_shot += heat_addition

/obj/item/microfusion_gun_attachment/xray/process_fire(obj/item/gun/microfusion/microfusion_gun, obj/item/ammo_casing/chambered)
	. = ..()
	chambered.loaded_projectile.projectile_piercing = PASSCLOSEDTURF|PASSGRILLE|PASSGLASS

/obj/item/microfusion_gun_attachment/xray/remove_attachment(obj/item/gun/microfusion/microfusion_gun)
	. = ..()
	microfusion_gun.heat_per_shot -= heat_addition

/*
RAIL ATTACHMENT

Allows for flashlights bayonets and adds 1 slot to equipment.
*/
/obj/item/microfusion_gun_attachment/rail
	name = "gun rail attachment"
	desc = "A simple set of rails that attaches to weapon hardpoints. Allows for 3 more attachment slots."
	icon_state = "attachment_rail"
	attachment_overlay_icon_state = "attachment_rail"
	incompatable_attachments = list(/obj/item/microfusion_gun_attachment/grip)
	var/attachment_slots_to_add = 3

/obj/item/microfusion_gun_attachment/rail/run_attachment(obj/item/gun/microfusion/microfusion_gun)
	. = ..()
	microfusion_gun.can_flashlight = TRUE
	microfusion_gun.can_bayonet = TRUE
	microfusion_gun.max_attachments += attachment_slots_to_add

/obj/item/microfusion_gun_attachment/rail/remove_attachment(obj/item/gun/microfusion/microfusion_gun)
	. = ..()
	microfusion_gun.gun_light = initial(microfusion_gun.can_flashlight)
	if(microfusion_gun.gun_light)
		microfusion_gun.gun_light.forceMove(get_turf(microfusion_gun))
		microfusion_gun.clear_gunlight()
	microfusion_gun.can_bayonet = initial(microfusion_gun.can_bayonet)
	if(microfusion_gun.bayonet)
		microfusion_gun.bayonet.forceMove(get_turf(microfusion_gun))
		microfusion_gun.clear_bayonet()
	microfusion_gun.max_attachments -= attachment_slots_to_add
	microfusion_gun.remove_all_attachments()

/*
GRIP ATTACHMENT

Does nothing right now.
*/
/obj/item/microfusion_gun_attachment/grip
	name = "grip attachment"
	desc = "A simple grip that increases accuracy."
	icon_state = "attachment_grip"
	attachment_overlay_icon_state = "attachment_grip"
	incompatable_attachments = list(/obj/item/microfusion_gun_attachment/rail)


/*
HEATSINK ATTACHMENT

"Greatly increases the phase emitter cooling rate."
*/
/obj/item/microfusion_gun_attachment/heatsink
	name = "phase emitter heatsink"
	desc = "Greatly increases the phase emitter cooling rate."
	icon_state = "attachment_heatsink"
	attachment_overlay_icon_state = "attachment_heatsink"
	var/cooling_rate_increase = 50

/obj/item/microfusion_gun_attachment/heatsink/run_attachment(obj/item/gun/microfusion/microfusion_gun)
	. = ..()
	microfusion_gun.heat_dissipation_bonus += cooling_rate_increase

/obj/item/microfusion_gun_attachment/heatsink/remove_attachment(obj/item/gun/microfusion/microfusion_gun)
	. = ..()
	microfusion_gun.heat_dissipation_bonus -= cooling_rate_increase

/*
HEATSINK ATTACHMENT

"Greatly increases the phase emitter cooling rate."
*/
/obj/item/microfusion_gun_attachment/rgb
	name = "phase emitter spectrograph"
	desc = "Enables the phase emitter to change it's output color."
	icon_state = "attachment_rgb"
	attachment_overlay_icon_state = "attachment_rgb"
	var/color_to_apply = COLOR_MOSTLY_PURE_RED

/obj/item/microfusion_gun_attachment/rgb/process_fire(obj/item/gun/microfusion/microfusion_gun, obj/item/ammo_casing/chambered)
	. = ..()
	chambered.loaded_projectile.color = color_to_apply

/obj/item/microfusion_gun_attachment/rgb/proc/select_color(mob/living/user)
	var/new_color = input(user, "Please select your new projectile color", "Laser color", color_to_apply) as null|color

	if(!new_color)
		return

	color_to_apply = new_color

/obj/item/microfusion_gun_attachment/rgb/attack_self(mob/user, modifiers)
	. = ..()
	select_color(user)

/obj/item/microfusion_gun_attachment/rgb/get_modify_data()
	var/list/params = list()
	params["color"] = "Color: <span style='border: 1px solid #161616; background-color: #[color_to_apply];'>&nbsp;&nbsp;&nbsp;</span>"
	return params

/obj/item/microfusion_gun_attachment/rgb/run_modify_data(params, mob/living/user)
	if(params == "color")
		select_color(user)

/*
UNDERCHARGER ATTACHMENT

Massively decreases the output beam of the phase emitter.
Converts shots to STAMNINA damage.
*/
/obj/item/microfusion_gun_attachment/undercharger
	name = "phase emitter undercharger"
	desc = "Inverts the output beam of the phase emitter."
	icon_state = "attachment_undercharger"
	attachment_overlay_icon_state = "attachment_undercharger"
	var/cooling_rate_increase = 5

/obj/item/microfusion_gun_attachment/undercharger/run_attachment(obj/item/gun/microfusion/microfusion_gun)
	. = ..()
	microfusion_gun.heat_dissipation_bonus += cooling_rate_increase

/obj/item/microfusion_gun_attachment/undercharger/process_fire(obj/item/gun/microfusion/microfusion_gun, obj/item/ammo_casing/chambered)
	. = ..()
	chambered.loaded_projectile?.damage_type = STAMINA

/obj/item/microfusion_gun_attachment/undercharger/remove_attachment(obj/item/gun/microfusion/microfusion_gun)
	. = ..()
	microfusion_gun.heat_dissipation_bonus -= cooling_rate_increase

