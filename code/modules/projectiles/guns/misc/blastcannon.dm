/obj/item/gun/blastcannon
	name = "pipe gun"
	desc = ""
	icon_state = "empty_blastcannon"
	var/icon_state_loaded = "loaded_blastcannon"
	item_state = "blastcannon_empty"
	w_class = WEIGHT_CLASS_NORMAL
	force = 10
	fire_sound = 'sound/blank.ogg'
	item_flags = NONE
	clumsy_check = FALSE
	randomspread = FALSE

	var/hugbox = TRUE
	var/max_power = INFINITY
	var/reaction_volume_mod = 0
	var/reaction_cycles = 3				//How many times gases react() before calculation. Very finnicky value, do not mess with without good reason.
	var/prereaction = TRUE

	var/bombcheck = TRUE
	var/debug_power = 0

	var/obj/item/transfer_valve/bomb

/obj/item/gun/blastcannon/debug
	debug_power = 80
	bombcheck = FALSE

/obj/item/gun/blastcannon/Initialize()
	. = ..()
	if(!pin)
		pin = new

/obj/item/gun/blastcannon/Destroy()
	QDEL_NULL(bomb)
	return ..()

/obj/item/gun/blastcannon/attack_self(mob/user)
	if(bomb)
		bomb.forceMove(user.loc)
		user.put_in_hands(bomb)
		user.visible_message(span_warning("[user] detaches [bomb] from [src]."))
		bomb = null
	update_icon()
	return ..()

/obj/item/gun/blastcannon/update_icon()
	if(bomb)
		icon_state = icon_state_loaded
		name = "blast cannon"
		desc = ""
	else
		icon_state = initial(icon_state)
		name = initial(name)
		desc = initial(desc)

/obj/item/gun/blastcannon/attackby(obj/O, mob/user)
	if(istype(O, /obj/item/transfer_valve))
		var/obj/item/transfer_valve/T = O
		if(!T.tank_one || !T.tank_two)
			to_chat(user, span_warning("What good would an incomplete bomb do?"))
			return FALSE
		if(!user.transferItemToLoc(T, src))
			to_chat(user, span_warning("[T] seems to be stuck to your hand!"))
			return FALSE
		user.visible_message(span_warning("[user] attaches [T] to [src]!"))
		bomb = T
		update_icon()
		return TRUE
	return ..()

//returns the third value of a bomb blast
/obj/item/gun/blastcannon/proc/calculate_bomb()
	if(!istype(bomb) || !istype(bomb.tank_one) || !istype(bomb.tank_two))
		return 0
	var/datum/gas_mixture/temp = new(max(reaction_volume_mod, 0))
	bomb.merge_gases(temp)
	if(prereaction)
		temp.react(src)
		var/prereaction_pressure = temp.return_pressure()
		if(prereaction_pressure < TANK_FRAGMENT_PRESSURE)
			return 0
	for(var/i in 1 to reaction_cycles)
		temp.react(src)
	var/pressure = temp.return_pressure()
	qdel(temp)
	if(pressure < TANK_FRAGMENT_PRESSURE)
		return 0
	return ((pressure - TANK_FRAGMENT_PRESSURE) / TANK_FRAGMENT_SCALE)

/obj/item/gun/blastcannon/afterattack(atom/target, mob/user, flag, params)
	if((!bomb && bombcheck) || (!target) || (get_dist(get_turf(target), get_turf(user)) <= 2))
		return ..()
	var/power = bomb? calculate_bomb() : debug_power
	power = min(power, max_power)
	QDEL_NULL(bomb)
	update_icon()
	var/heavy = power * 0.25
	var/medium = power * 0.5
	var/light = power
	user.visible_message(span_danger("[user] opens [bomb] on [user.p_their()] [name] and fires a blast wave at [target]!"),span_danger("I open [bomb] on your [name] and fire a blast wave at [target]!"))
	playsound(user, "explosion", 100, TRUE)
	var/turf/starting = get_turf(user)
	var/turf/targturf = get_turf(target)
	message_admins("Blast wave fired from [ADMIN_VERBOSEJMP(starting)] at [ADMIN_VERBOSEJMP(targturf)] ([target.name]) by [ADMIN_LOOKUPFLW(user)] with power [heavy]/[medium]/[light].")
	log_game("Blast wave fired from [AREACOORD(starting)] at [AREACOORD(targturf)] ([target.name]) by [key_name(user)] with power [heavy]/[medium]/[light].")
	var/obj/projectile/blastwave/BW = new(loc, heavy, medium, light)
	BW.hugbox = hugbox
	BW.preparePixelProjectile(target, get_turf(src), params, 0)
	BW.fire()

/obj/projectile/blastwave
	name = "blast wave"
	icon_state = "blastwave"
	damage = 0
	nodamage = FALSE
	movement_type = FLYING | UNSTOPPABLE
	var/heavyr = 0
	var/mediumr = 0
	var/lightr = 0
	var/hugbox = TRUE
	range = 150

/obj/projectile/blastwave/Initialize(mapload, _h, _m, _l)
	heavyr = _h
	mediumr = _m
	lightr = _l
	return ..()

/obj/projectile/blastwave/Range()
	..()
	var/amount_destruction = EXPLODE_NONE
	var/wallbreak_chance = 0
	if(heavyr)
		amount_destruction = EXPLODE_DEVASTATE
		wallbreak_chance = 99
	else if(mediumr)
		amount_destruction = EXPLODE_HEAVY
		wallbreak_chance = 66
	else if(lightr)
		amount_destruction = EXPLODE_LIGHT
		wallbreak_chance = 33
	if(amount_destruction)
		if(hugbox)
			loc.contents_explosion(EXPLODE_HEAVY, loc)
			if(istype(loc, /turf/closed/wall))
				var/turf/closed/wall/W = loc
				if(prob(wallbreak_chance))
					W.dismantle_wall(TRUE, TRUE)
		else
			loc.ex_act(amount_destruction)
	else
		qdel(src)

	heavyr = max(heavyr - 1, 0)
	mediumr = max(mediumr - 1, 0)
	lightr = max(lightr - 1, 0)

/obj/projectile/blastwave/ex_act()
	return
