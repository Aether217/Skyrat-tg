#define DUALWIELD_PENALTY_EXTRA_MULTIPLIER 1.4

// Master file for cell loadable energy guns. PROCS ONLY YOU MONKEYS!
// This file is a copy/paste of _energy.dm with extensive modification.

/obj/item/gun/microfusion
	name = "prototype detatchable cell energy projection aparatus"
	desc = "The coders have obviously failed to realise this is broken."
	icon = 'modular_skyrat/modules/microfusion/icons/microfusion_gun40x32.dmi'
	icon_state = "mcr01"
	lefthand_file = 'modular_skyrat/modules/microfusion/icons/guns_lefthand.dmi'
	righthand_file = 'modular_skyrat/modules/microfusion/icons/guns_lefthand.dmi'
	has_gun_safety = TRUE
	can_flashlight = FALSE
	can_bayonet = FALSE
	zoomable = FALSE

	w_class = WEIGHT_CLASS_BULKY

	/// What type of power cell this uses
	var/obj/item/stock_parts/cell/microfusion/cell
	var/cell_type = /obj/item/stock_parts/cell/microfusion
	///if the weapon has custom icons for individual ammo types it can switch between. ie disabler beams, taser, laser/lethals, ect.
	var/modifystate = FALSE
	var/list/ammo_type = list(/obj/item/ammo_casing/energy/laser/microfusion)
	///The state of the select fire switch. Determines from the ammo_type list what kind of shot is fired next.
	var/select = 1
	///If the user can select the firemode through attack_self.
	var/can_select = TRUE
	///Can it be charged in a recharger?
	var/can_charge = TRUE
	///Do we handle overlays with base update_icon()?
	var/automatic_charge_overlays = TRUE
	var/charge_sections = 4
	ammo_x_offset = 2
	///if this gun uses a stateful charge bar for more detail
	var/shaded_charge = FALSE
	///If this gun has a "this is loaded with X" overlay alongside chargebars and such
	var/single_shot_type_overlay = TRUE
	///Should we give an overlay to empty guns?
	var/display_empty = TRUE
	///whether the gun's cell drains the cyborg user's cell to recharge
	var/dead_cell = FALSE

	// MICROFUSION SPECIFIC VARS

	/// The time it takes for someone to (tactically) reload this gun. In deciseconds.
	var/reload_time = 2 SECONDS
	/// The sound played when you insert a cell.
	var/sound_cell_insert = 'modular_skyrat/modules/microfusion/sound/mag_insert.ogg'
	/// Should the insertion sound played vary?
	var/sound_cell_insert_vary = TRUE
	/// The volume at which we will play the insertion sound.
	var/sound_cell_insert_volume = 100
	/// The sound played when you remove a cell.
	var/sound_cell_remove = 'modular_skyrat/modules/microfusion/sound/mag_insert.ogg'
	/// Should the removal sound played vary?
	var/sound_cell_remove_vary = TRUE
	/// The volume at which we will play the removal sound.
	var/sound_cell_remove_volume = 100
	/// A list of attached upgrades
	var/list/attachments = list()
	/// How many attachments can this gun hold?
	var/max_attachments = 2
	/// The starting phase emitter in this weapon.
	var/phase_emitter_type = /obj/item/microfusion_phase_emitter
	/// The phase emitter that this gun currently has.
	var/obj/item/microfusion_phase_emitter/phase_emitter
	/// The amount of heat produced per shot
	var/heat_per_shot = 100
	/// The heat dissipation bonus granted by the weapon.
	var/heat_dissipation_bonus = 0

/obj/item/gun/microfusion/emp_act(severity)
	. = ..()
	if(!(. & EMP_PROTECT_CONTENTS))
		cell.use(round(cell.charge / severity))
		chambered = null //we empty the chamber
		recharge_newshot() //and try to charge a new shot
		update_appearance()

/obj/item/gun/microfusion/get_cell()
	return cell

/obj/item/gun/microfusion/Initialize(mapload)
	. = ..()
	if(cell_type)
		cell = new cell_type(src)
	else
		cell = new(src)
	cell.parent_gun = src
	if(!dead_cell)
		cell.give(cell.maxcharge)
	if(phase_emitter_type)
		phase_emitter = new phase_emitter_type(src)
	else
		phase_emitter = new(src)
	phase_emitter.parent_gun = src
	update_ammo_types()
	recharge_newshot(TRUE)
	update_appearance()
	RegisterSignal(src, COMSIG_ITEM_RECHARGED, .proc/instant_recharge)

/obj/item/gun/microfusion/ComponentInitialize()
	. = ..()
	AddElement(/datum/element/update_icon_updates_onmob)

/obj/item/gun/microfusion/add_weapon_description()
	AddElement(/datum/element/weapon_description, attached_proc = .proc/add_notes_energy)

/obj/item/gun/microfusion/Destroy()
	if(cell)
		cell.parent_gun = null
		QDEL_NULL(cell)
	if(attachments.len)
		for(var/obj/item/iterating_item in attachments)
			qdel(iterating_item)
		attachments = null
	if(phase_emitter)
		QDEL_NULL(phase_emitter)
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/gun/microfusion/handle_atom_del(atom/A)
	if(A == cell)
		cell = null
		update_appearance()
	if(A == phase_emitter)
		phase_emitter = null
		update_appearance()
	return ..()

/obj/item/gun/microfusion/attack_self(mob/living/user as mob)
	. = ..()
	if(ammo_type.len > 1 && can_select)
		select_fire(user)

/obj/item/gun/microfusion/can_shoot()
	var/obj/item/ammo_casing/energy/shot = ammo_type[select]
	return !QDELETED(cell) ? (cell.charge >= shot.e_cost) : FALSE

/obj/item/gun/microfusion/recharge_newshot()
	if (!ammo_type || !cell || !phase_emitter)
		return
	if(!chambered)
		var/obj/item/ammo_casing/energy/AC = ammo_type[select]
		if(cell.charge >= AC.e_cost) //if there's enough power in the cell...
			chambered = AC //...prepare a new shot based on the current ammo type selected
			if(!chambered.loaded_projectile)
				chambered.newshot()

/obj/item/gun/microfusion/handle_chamber()
	if(chambered && !chambered.loaded_projectile) //if loaded_projectile is null, i.e the shot has been fired...
		var/obj/item/ammo_casing/energy/shot = chambered
		cell.use(shot.e_cost)//... drain the cell
	chambered = null //either way, released the prepared shot
	recharge_newshot() //try to charge a new shot

/obj/item/gun/microfusion/process_fire(atom/target, mob/living/user, message = TRUE, params = null, zone_override = "", bonus_spread = 0)
	if(!chambered && can_shoot())
		process_chamber() // If the gun was drained and then recharged, load a new shot.
	return ..()

/obj/item/gun/microfusion/process_burst(mob/living/user, atom/target, message = TRUE, params = null, zone_override="", sprd = 0, randomized_gun_spread = 0, randomized_bonus_spread = 0, rand_spr = 0, iteration = 0)
	if(!chambered && can_shoot())
		process_chamber() // Ditto.
	return ..()

/obj/item/gun/microfusion/update_icon_state()
	var/skip_inhand = initial(inhand_icon_state) //only build if we aren't using a preset inhand icon
	var/skip_worn_icon = initial(worn_icon_state) //only build if we aren't using a preset worn icon

	if(skip_inhand && skip_worn_icon) //if we don't have either, don't do the math.
		return ..()

	var/ratio = get_charge_ratio()
	var/temp_icon_to_use = initial(icon_state)
	if(modifystate)
		var/obj/item/ammo_casing/energy/shot = ammo_type[select]
		temp_icon_to_use += "[shot.select_name]"

	temp_icon_to_use += "[ratio]"
	if(!skip_inhand)
		inhand_icon_state = temp_icon_to_use
	if(!skip_worn_icon)
		worn_icon_state = temp_icon_to_use
	return ..()

/obj/item/gun/microfusion/update_overlays()
	. = ..()

	if(automatic_charge_overlays && cell)
		var/overlay_icon_state = "[icon_state]_charge"
		if(modifystate)
			var/obj/item/ammo_casing/energy/shot = ammo_type[select]
			if(single_shot_type_overlay)
				. += "[icon_state]_[shot.select_name]"
			overlay_icon_state += "_[shot.select_name]"

		var/ratio = get_charge_ratio()
		if(ratio == 0 && display_empty)
			. += "[icon_state]_empty"
		else if(shaded_charge)
			. += "[icon_state]_charge[ratio]"
		else
			var/mutable_appearance/charge_overlay = mutable_appearance(icon, overlay_icon_state)
			for(var/i = ratio, i >= 1, i--)
				charge_overlay.pixel_x = ammo_x_offset * (i - 1)
				charge_overlay.pixel_y = ammo_y_offset * (i - 1)
				. += new /mutable_appearance(charge_overlay)
	for(var/obj/item/microfusion_gun_attachment/microfusion_gun_attachment in attachments)
		. += "[icon_state]_[microfusion_gun_attachment.attachment_overlay_icon_state]"
	if(phase_emitter)
		. += "[icon_state]_[phase_emitter.icon_state]"

/obj/item/gun/microfusion/ignition_effect(atom/A, mob/living/user)
	if(!can_shoot() || !ammo_type[select])
		shoot_with_empty_chamber()
		. = ""
	else
		var/obj/item/ammo_casing/energy/E = ammo_type[select]
		var/obj/projectile/energy/loaded_projectile = E.loaded_projectile
		if(!loaded_projectile)
			. = ""
		else if(loaded_projectile.nodamage || !loaded_projectile.damage || loaded_projectile.damage_type == STAMINA)
			user.visible_message(span_danger("[user] tries to light [A.loc == user ? "[user.p_their()] [A.name]" : A] with [src], but it doesn't do anything. Dumbass."))
			playsound(user, E.fire_sound, 50, TRUE)
			playsound(user, loaded_projectile.hitsound, 50, TRUE)
			cell.use(E.e_cost)
			. = ""
		else if(loaded_projectile.damage_type != BURN)
			user.visible_message(span_danger("[user] tries to light [A.loc == user ? "[user.p_their()] [A.name]" : A] with [src], but only succeeds in utterly destroying it. Dumbass."))
			playsound(user, E.fire_sound, 50, TRUE)
			playsound(user, loaded_projectile.hitsound, 50, TRUE)
			cell.use(E.e_cost)
			qdel(A)
			. = ""
		else
			playsound(user, E.fire_sound, 50, TRUE)
			playsound(user, loaded_projectile.hitsound, 50, TRUE)
			cell.use(E.e_cost)
			. = span_danger("[user] casually lights [A.loc == user ? "[user.p_their()] [A.name]" : A] with [src]. Damn.")

/obj/item/gun/microfusion/attackby(obj/item/attacking_item, mob/user, params)
	. = ..()
	if (.)
		return
	if(istype(attacking_item, cell_type))
		insert_cell(user, attacking_item)
	if(istype(attacking_item, /obj/item/microfusion_gun_attachment))
		add_attachment(attacking_item, user)
	if(istype(attacking_item, /obj/item/microfusion_phase_emitter))
		insert_emitter(attacking_item, user)

/obj/item/gun/microfusion/process_chamber(empty_chamber, from_firing, chamber_next_round)
	. = ..()
	if(!cell.stabilised && prob(40))
		do_sparks(2, FALSE, src) //Microfusion guns create sparks!

/obj/item/gun/microfusion/attack_hand(mob/user, list/modifiers)
	if(loc == user && user.is_holding(src) && cell)
		eject_cell(user)
		return
	return ..()

/obj/item/gun/microfusion/crowbar_act(mob/living/user, obj/item/tool)
	if(!phase_emitter)
		to_chat(user, span_danger("There is no phase emitter for you to remove!"))
		return
	playsound(src, 'sound/items/crowbar.ogg', 70, TRUE)
	remove_emitter()

/obj/item/gun/microfusion/AltClick(mob/user)
	. = ..()
	if(can_interact(user))
		var/obj/item/microfusion_gun_attachment/to_remove = input(user, "Please select what part you'd like to remove.", "Remove attachment")  as null|obj in sort_names(attachments)
		if(!to_remove)
			return
		remove_attachment(to_remove, user)

/obj/item/gun/microfusion/proc/remove_all_attachments()
	if(attachments.len)
		for(var/obj/item/microfusion_gun_attachment/attachment in attachments)
			attachment.remove_attachment(src)
			attachment.forceMove(get_turf(src))
			attachments -= attachment
		update_appearance()

/obj/item/gun/microfusion/examine(mob/user)
	. = ..()
	. += span_notice("It can hold <b>[max_attachments]</b> attachments.")
	if(attachments.len)
		for(var/obj/item/microfusion_gun_attachment/microfusion_gun_attachment in attachments)
			. += span_notice("It has a [microfusion_gun_attachment.name] installed.")
		. += span_notice("<b>Alt+click</b> it to remove an upgrade.")
	if(phase_emitter)
		. += span_notice("It has a [phase_emitter.name] installed, at <b>[phase_emitter.get_heat_percent()]%</b> heat capacity.")
		. += span_notice("The [phase_emitter.name] is at <b>[phase_emitter.integrity]%</b> integrity.")
		. += span_notice("The [phase_emitter.name] will thermal throttle at <b>[phase_emitter.throttle_percentage]%</b> heat capacity.")
		. += span_notice("Use a crowbar to remove the phase emitter.")
	else
		. += span_danger("It does not have a phase emitter installed!")

	if(cell)
		. += span_notice("It has a [cell.name] installed, with a capacity of <b>[cell.charge]/[cell.maxcharge] MF</b>.")

/obj/item/gun/microfusion/suicide_act(mob/living/user)
	if (istype(user) && can_shoot() && can_trigger_gun(user) && user.get_bodypart(BODY_ZONE_HEAD))
		user.visible_message(span_suicide("[user] is putting the barrel of [src] in [user.p_their()] mouth. It looks like [user.p_theyre()] trying to commit suicide!"))
		sleep(25)
		if(user.is_holding(src))
			user.visible_message(span_suicide("[user] melts [user.p_their()] face off with [src]!"))
			playsound(loc, fire_sound, 50, TRUE, -1)
			var/obj/item/ammo_casing/energy/shot = ammo_type[select]
			cell.use(shot.e_cost)
			update_appearance()
			return(FIRELOSS)
		else
			user.visible_message(span_suicide("[user] panics and starts choking to death!"))
			return(OXYLOSS)
	else
		user.visible_message(span_suicide("[user] is pretending to melt [user.p_their()] face off with [src]! It looks like [user.p_theyre()] trying to commit suicide!</b>"))
		playsound(src, dry_fire_sound, 30, TRUE)
		return (OXYLOSS)

// To maintain modularity, I am moving this proc override here.
/obj/item/gun/microfusion/fire_gun(atom/target, mob/living/user, flag, params)
	if(QDELETED(target))
		return
	if(firing_burst)
		return
	if(flag) //It's adjacent, is the user, or is on the user's person
		if(target in user.contents) //can't shoot stuff inside us.
			return
		if(!ismob(target) || user.combat_mode) //melee attack
			return
		if(target == user && user.zone_selected != BODY_ZONE_PRECISE_MOUTH) //so we can't shoot ourselves (unless mouth selected)
			return
		if(iscarbon(target))
			var/mob/living/carbon/C = target
			for(var/i in C.all_wounds)
				var/datum/wound/W = i
				if(W.try_treating(src, user))
					return // another coward cured!

	if(istype(user))//Check if the user can use the gun, if the user isn't alive(turrets) assume it can.
		var/mob/living/L = user
		if(!can_trigger_gun(L))
			return
	if(flag)
		if(user.zone_selected == BODY_ZONE_PRECISE_MOUTH)
			handle_suicide(user, target, params)
			return

	if(!can_shoot()) //Just because you can pull the trigger doesn't mean it can shoot.
		shoot_with_empty_chamber(user)
		return

	if(check_botched(user))
		return

	var/obj/item/bodypart/other_hand = user.has_hand_for_held_index(user.get_inactive_hand_index()) //returns non-disabled inactive hands
	if(weapon_weight == WEAPON_HEAVY && (user.get_inactive_held_item() || !other_hand))
		to_chat(user, span_warning("You need two hands to fire [src]!"))
		return

	var/attempted_shot = process_emitter()
	if(attempted_shot != SHOT_SUCCESS)
		if(attempted_shot)
			to_chat(user, span_danger(attempted_shot))
		return

	//DUAL (or more!) WIELDING
	var/bonus_spread = 0
	var/loop_counter = 0
	if(ishuman(user) && user.combat_mode)
		var/mob/living/carbon/human/H = user
		for(var/obj/item/gun/G in H.held_items)
			if(G == src || G.weapon_weight >= WEAPON_MEDIUM)
				continue
			else if(G.can_trigger_gun(user))
				bonus_spread += dual_wield_spread
				loop_counter++
				addtimer(CALLBACK(G, /obj/item/gun.proc/process_fire, target, user, TRUE, params, null, bonus_spread), loop_counter)

	return process_fire(target, user, TRUE, params, null, bonus_spread)

// To maintain modularity, I am moving this proc override here.
/obj/item/gun/microfusion/process_fire(atom/target, mob/living/user, message = TRUE, params = null, zone_override = "", bonus_spread = 0)
	if(user)
		SEND_SIGNAL(user, COMSIG_MOB_FIRED_GUN, user, target, params, zone_override)

	SEND_SIGNAL(src, COMSIG_GUN_FIRED, user, target, params, zone_override)

	add_fingerprint(user)

	if(semicd)
		return

	//Vary by at least this much
	var/base_bonus_spread = 0
	var/sprd = 0
	var/randomized_gun_spread = 0
	var/rand_spr = rand()
	if(user && HAS_TRAIT(user, TRAIT_POOR_AIM)) //Nice job hotshot
		bonus_spread += 35
		base_bonus_spread += 10

	if(spread)
		randomized_gun_spread =	rand(0,spread)
	var/randomized_bonus_spread = rand(base_bonus_spread, bonus_spread)

	if(burst_size > 1)
		firing_burst = TRUE
		for(var/i = 1 to burst_size)
			addtimer(CALLBACK(src, .proc/process_burst, user, target, message, params, zone_override, sprd, randomized_gun_spread, randomized_bonus_spread, rand_spr, i), fire_delay * (i - 1))
	else
		if(chambered)
			if(HAS_TRAIT(user, TRAIT_PACIFISM)) // If the user has the pacifist trait, then they won't be able to fire [src] if the round chambered inside of [src] is lethal.
				if(chambered.harmful) // Is the bullet chambered harmful?
					to_chat(user, span_warning("[src] is lethally chambered! You don't want to risk harming anyone..."))
					return
			sprd = round((rand(0, 1) - 0.5) * DUALWIELD_PENALTY_EXTRA_MULTIPLIER * (randomized_gun_spread + randomized_bonus_spread))
			before_firing(target,user)
			process_microfusion()
			if(!chambered.fire_casing(target, user, params, , suppressed, zone_override, sprd, src))
				shoot_with_empty_chamber(user)
				return
			else
				if(get_dist(user, target) <= 1) //Making sure whether the target is in vicinity for the pointblank shot
					shoot_live_shot(user, 1, target, message)
				else
					shoot_live_shot(user, 0, target, message)
		else
			shoot_with_empty_chamber(user)
			return
		process_chamber()
		update_appearance()
		semicd = TRUE
		addtimer(CALLBACK(src, .proc/reset_semicd), fire_delay)

	if(user)
		user.update_inv_hands()
	SSblackbox.record_feedback("tally", "gun_fired", 1, type)

	SEND_SIGNAL(src, COMSIG_UPDATE_AMMO_HUD)

	return TRUE

/obj/item/gun/microfusion/proc/process_microfusion()
	if(attachments.len)
		for(var/obj/item/microfusion_gun_attachment/attachment in attachments)
			attachment.process_fire(src, chambered)

/obj/item/gun/microfusion/proc/process_emitter()
	if(!phase_emitter)
		return SHOT_FAILURE_NO_EMITTER
	var/phase_emitter_process = phase_emitter.generate_shot(heat_per_shot)
	if(phase_emitter_process != SHOT_SUCCESS)
		return phase_emitter_process
	return SHOT_SUCCESS

/obj/item/gun/microfusion/proc/instant_recharge()
	SIGNAL_HANDLER
	if(!cell)
		return
	cell.charge = cell.maxcharge
	recharge_newshot()
	update_appearance()

///Used by update_icon_state() and update_overlays()
/obj/item/gun/microfusion/proc/get_charge_ratio()
	return can_shoot() ? CEILING(clamp(cell.charge / cell.maxcharge, 0, 1) * charge_sections, 1) : 0
	// Sets the ratio to 0 if the gun doesn't have enough charge to fire, or if its power cell is removed.

/obj/item/gun/microfusion/proc/select_fire(mob/living/user)
	select++
	if (select > ammo_type.len)
		select = 1
	var/obj/item/ammo_casing/energy/shot = ammo_type[select]
	fire_sound = shot.fire_sound
	fire_sound_volume = shot.fire_sound_volume
	fire_delay = shot.delay
	if (shot.select_name && user)
		balloon_alert(user, "set to [shot.select_name]")
	chambered = null
	recharge_newshot(TRUE)
	update_appearance()
	SEND_SIGNAL(src, COMSIG_UPDATE_AMMO_HUD)

/**
 *
 * Outputs type-specific weapon stats for energy-based firearms based on its firing modes
 * and the stats of those firing modes. Esoteric firing modes like ion are currently not supported
 * but can be added easily
 *
 */
/obj/item/gun/microfusion/proc/add_notes_energy()
	var/list/readout = list()
	// Make sure there is something to actually retrieve
	if(!ammo_type.len)
		return
	var/obj/projectile/exam_proj
	readout += "\nStandard models of this projectile weapon have [span_warning("[ammo_type.len] mode\s")]"
	readout += "Our heroic interns have shown that one can theoretically stay standing after..."
	for(var/obj/item/ammo_casing/energy/for_ammo as anything in ammo_type)
		exam_proj = GLOB.proj_by_path_key[for_ammo?.projectile_type]
		if(!istype(exam_proj))
			continue

		if(exam_proj.damage > 0) // Don't divide by 0!!!!!
			readout += "[span_warning("[HITS_TO_CRIT(exam_proj.damage * for_ammo.pellets)] shot\s")] on [span_warning("[for_ammo.select_name]")] mode before collapsing from [exam_proj.damage_type == STAMINA ? "immense pain" : "their wounds"]."
			if(exam_proj.stamina > 0) // In case a projectile does damage AND stamina damage (Energy Crossbow)
				readout += "[span_warning("[HITS_TO_CRIT(exam_proj.stamina * for_ammo.pellets)] shot\s")] on [span_warning("[for_ammo.select_name]")] mode before collapsing from immense pain."
		else
			readout += "a theoretically infinite number of shots on [span_warning("[for_ammo.select_name]")] mode."

	return readout.Join("\n") // Sending over the singular string, rather than the whole list

/obj/item/gun/microfusion/proc/update_ammo_types()
	var/obj/item/ammo_casing/energy/shot
	for (var/i in 1 to ammo_type.len)
		var/shottype = ammo_type[i]
		shot = new shottype(src)
		ammo_type[i] = shot
	shot = ammo_type[select]
	fire_sound = shot.fire_sound
	fire_sound_volume = shot.fire_sound_volume
	fire_delay = shot.delay

// Cell, emitter and upgrade interactions

/obj/item/gun/microfusion/proc/remove_emitter()
	phase_emitter.forceMove(get_turf(src))
	phase_emitter.parent_gun = null
	phase_emitter = null
	update_appearance()

/obj/item/gun/microfusion/proc/insert_emitter(obj/item/microfusion_phase_emitter/inserting_phase_emitter, mob/living/user)
	if(phase_emitter)
		to_chat(user, span_danger("There is already a phase emitter installed!"))
		return FALSE
	to_chat(user, span_notice("You carefully insert [inserting_phase_emitter] into the slot."))
	playsound(src, 'sound/machines/terminal_eject.ogg', 50, TRUE)
	inserting_phase_emitter.forceMove(src)
	phase_emitter = inserting_phase_emitter
	phase_emitter.parent_gun = src
	update_appearance()


/// Try to insert the cell into the gun, if successful, return TRUE
/obj/item/gun/microfusion/proc/insert_cell(mob/user, obj/item/stock_parts/cell/microfusion/inserting_cell, display_message = TRUE)
	if(cell)
		if(reload_time && !HAS_TRAIT(user, TRAIT_INSTANT_RELOAD)) //This only happens when you're attempting a tactical reload, e.g. there's a mag already inserted.
			if(display_message)
				to_chat(user, span_notice("You start to insert [inserting_cell] into [src]!"))
			if(!do_after(user, reload_time, src))
				if(display_message)
					to_chat(user, span_warning("You fail to insert [inserting_cell] into [src]!"))
				return FALSE
		if(display_message)
			to_chat(user, span_notice("You tactically reload [src], replacing [cell] inside!"))
		eject_cell(user, FALSE)
	else if(display_message)
		to_chat(user, span_notice("You insert [inserting_cell] into [src]!"))
	if(sound_cell_insert)
		playsound(src, sound_cell_insert, sound_cell_insert_volume, sound_cell_insert_vary)
	cell = inserting_cell
	inserting_cell.forceMove(src)
	cell.parent_gun = src
	if(!chambered)
		recharge_newshot()
	update_appearance()
	return TRUE

/// Ejecting a cell.
/obj/item/gun/microfusion/proc/eject_cell(mob/user, display_message = TRUE)
	var/obj/item/stock_parts/cell/microfusion/old_cell = cell
	old_cell.forceMove(get_turf(src))
	if(user)
		user.put_in_hands(old_cell)
		if(display_message)
			to_chat(user, span_notice("You remove [old_cell] from [src]!"))
	if(sound_cell_remove)
		playsound(src, sound_cell_remove, sound_cell_remove_volume, sound_cell_remove_vary)
	old_cell.update_appearance()
	cell.parent_gun = null
	cell = null
	update_appearance()

/// Attatching an upgrade.
/obj/item/gun/microfusion/proc/add_attachment(obj/item/microfusion_gun_attachment/microfusion_gun_attachment, mob/living/user)
	if(attachments.len >= max_attachments)
		to_chat(user, span_warning("[src] cannot fit any more attachments!"))
		return FALSE
	if(is_type_in_list(microfusion_gun_attachment, attachments))
		to_chat(user, span_warning("[src] already has [microfusion_gun_attachment] installed!"))
		return FALSE
	for(var/obj/item/microfusion_gun_attachment/iterating_attachment in attachments)
		if(is_type_in_list(microfusion_gun_attachment, iterating_attachment.incompatable_attachments))
			to_chat(user, span_warning("[microfusion_gun_attachment] is not compatible with [iterating_attachment]!"))
			return FALSE
	attachments += microfusion_gun_attachment
	microfusion_gun_attachment.forceMove(src)
	microfusion_gun_attachment.run_attachment(src)
	to_chat(user, span_notice("You successfully install [microfusion_gun_attachment] onto [src]!"))
	playsound(src, 'sound/effects/structure_stress/pop2.ogg', 70, TRUE)
	return TRUE

/obj/item/gun/microfusion/proc/remove_attachment(obj/item/microfusion_gun_attachment/microfusion_gun_attachment, mob/living/user)
	to_chat(user, span_notice("You remove [microfusion_gun_attachment] from [src]!"))
	playsound(src, 'sound/items/screwdriver.ogg', 70)
	microfusion_gun_attachment.forceMove(get_turf(src))
	attachments -= microfusion_gun_attachment
	microfusion_gun_attachment.remove_attachment(src)
	update_appearance()

// Temporary HTML menu until I get it switched to

/obj/item/gun/microfusion/ui_interact(mob/user)
	var/list/dat = list("")

	dat += "<b>[name] Control Interface</b>"

	dat += "<br>"

	dat += "<b>Phase Emitter:</b>"
	if(phase_emitter)
		if(phase_emitter.damaged)
			dat += "Damaged!"
		else
			dat += "Type: [phase_emitter.name]"
			dat += "Integrity: [phase_emitter.integrity]"
			dat += "Heat: [phase_emitter.current_heat] C"
			dat += "Heat throttle percent: [phase_emitter.throttle_percentage]%[phase_emitter.hacked ? " | UNLOCKED" : ""]"
			if(phase_emitter.hacked)
				dat += "<b><a href='byond://?src=[REF(src)];function=overclock_phase_emitter'>Overclock</a></b>"
			dat += "Passive heat dissipation: [phase_emitter.heat_dissipation_per_tick] C"
			dat += "Maxmimum heat capacity: [phase_emitter.max_heat] C"

	else
		dat += "Not installed!"

	dat += "<br>"

	dat += "<b>Power Supply:</b>"
	if(cell)
		dat += "Type: [cell.name]"
		dat += "Charge: [cell.charge]/[cell.maxcharge] MF"
		dat += "Status: [cell.meltdown ? "INTEGRITY FAILURE" : "NOMINAL"]"
		if(cell.attachments.len)
			dat += "Attachments:"
			for(var/obj/item/microfusion_cell_attachment/attachment in cell.attachments)
				dat += " - [attachment.name]"
	else
		dat += "Not installed!"

	dat += "<br>"

	dat += "<b>Beam Analysis:</b>"
	if(chambered?.loaded_projectile)
		var/obj/projectile/loaded_projectile = chambered.loaded_projectile
		dat += "Predicted impact strength: [loaded_projectile.damage]"
		dat += "Predicted impact type: [loaded_projectile.damage_type]"
	else
		dat += "ERROR"

	dat += "<br>"

	if(attachments.len)
		dat += "<b>Installed Attachments:</b>"
		for(var/obj/item/microfusion_gun_attachment/attachment in attachments)
			dat += "<b>[uppertext(attachment.name)]</b>"
			dat += attachment.desc
			dat += attachment.get_information_data()
			var/list/attachment_params = attachment.get_modify_data()
			if(attachment_params) // We got stuff to change!
				for(var/param in attachment_params)
					dat += "<b><a href='byond://?src=[REF(src)];item=[REF(attachment)];function=modify_attachment;modify=[param]'>[attachment_params[param]]</a></b>"
			dat += "<b><a href='byond://?src=[REF(src)];item=[REF(attachment)];function=remove_attachment'>Detach</a></b>"
			dat += "<hr>"

	var/datum/browser/popup = new(user, "microfusion_gun_interface", "Micron Control Systems Incorporated: [name]", 600, 700, src)
	popup.set_content(dat.Join("<br>"))
	popup.open()
	onclose(user, "microfusion_gun_interface")

/obj/item/gun/microfusion/Topic(href, list/href_list)
	if(..())
		return

	var/operation = href_list["function"]

	if(href_list["close"])
		usr << browse(null, "window=microfusion_gun_interface")
		return

	if(operation == "remove_attachment")
		var/obj/item/microfusion_gun_attachment/to_remove = locate(href_list["item"]) in src
		remove_attachment(to_remove, usr)

	if(operation == "modify_attachment")
		var/obj/item/microfusion_gun_attachment/to_modify = locate(href_list["item"]) in src
		to_chat(world, href_list["modify"])
		to_modify.run_modify_data(href_list["modify"], usr)

	if(operation == "overclock_phase_emitter")
		if(!phase_emitter)
			return
		if(!phase_emitter.hacked)
			return

		phase_emitter.set_overclock(usr)


	updateUsrDialog()
