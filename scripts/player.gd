extends CharacterBody3D
# Pemain: third-person over-the-shoulder. Kamera/bidikan (rotasi node ini) dipisah dari arah badan:
# badan berputar halus mengikuti arah joystick/WASD, dan menghadap arah bidik saat menembak/zoom.
# Model GLB berrig + animasi prosedural + senjata 3D asli (weapon_view.gd).

const ModelUtil = preload("res://scripts/model_util.gd")
const CharAnim = preload("res://scripts/character_anim.gd")
const WeaponView = preload("res://scripts/weapon_view.gd")
const MODEL_PATH := "res://assets/characters/hero.glb"
const MODEL_YAW := PI
const GRAVITY := 24.0
const WALK_SPEED := 4.2       # kecepatan jalan (m/s), sengaja lambat
const SPRINT_MULT := 1.5      # pengali saat lari
const JUMP_VELOCITY := 7.0
const TURN_SPEED := 9.0       # kecepatan badan berputar (makin besar makin cepat)

signal died(victim, killer)

var game
var touch = null
var skill_idx: int = 0
var team: int = 0
var loadout: Array = []
var infinite: bool = false
var display_name: String = "Kamu"
var kills: int = 0
var deaths: int = 0
var skill: Dictionary = {}

var hp: float = 100.0
var max_hp: float = 100.0
var armor: float = 0.0
var alive: bool = true
var speed_mult: float = 1.0
var dmg_mult: float = 1.0
var effect_time: float = 0.0
var heal_left: float = 0.0
var ability_cd: float = 0.0
var dash_t: float = 0.0

var weapons: Array = []
var ammo: Dictionary = {}
var reserve: Dictionary = {}
var cur: int = 0
var cooldown: float = 0.0
var reloading: float = 0.0
var prev_fire: bool = false
var shoot_t: float = 0.0

var pitch: float = 0.0
var head: Node3D
var arm: SpringArm3D
var cam: Camera3D
var body: Node3D
var visual: Node3D
var view
var anim
var body_yaw: float = 0.0
var crouch_w: float = 0.0
var aiming: bool = false


func _ready() -> void:
	add_to_group("fighters")
	skill = GameData.SKILLS[clampi(skill_idx, 0, GameData.SKILLS.size() - 1)]
	display_name = str(Profile.data.name)

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	body = Node3D.new()
	add_child(body)
	visual = ModelUtil.make_model(MODEL_PATH, 1.8, MODEL_YAW)
	if visual == null:
		visual = _fallback_body()
	body.add_child(visual)
	anim = CharAnim.new()
	anim.setup(visual)

	view = WeaponView.new()
	body.add_child(view)

	head = Node3D.new()
	head.position = Vector3(0.6, 1.5, 0.0)
	add_child(head)
	arm = SpringArm3D.new()
	arm.spring_length = 3.2
	arm.margin = 0.25
	arm.add_excluded_object(get_rid())
	head.add_child(arm)
	cam = Camera3D.new()
	cam.fov = 75.0
	arm.add_child(cam)
	cam.current = true

	body_yaw = rotation.y
	for id in loadout:
		_add_weapon(str(id))
	_equip(0)


func _fallback_body() -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	mi.mesh = cm
	mi.position.y = 0.9
	n.add_child(mi)
	return n


func _add_weapon(id: String) -> void:
	if id in weapons:
		reserve[id] += int(GameData.WEAPONS[id].mag) * 2
		return
	var w: Dictionary = GameData.WEAPONS[id]
	weapons.append(id)
	ammo[id] = int(w.mag)
	reserve[id] = int(w.mag) * 3


func _equip(i: int) -> void:
	if i < 0 or i >= weapons.size():
		return
	cur = i
	reloading = 0.0
	view.set_weapon(str(weapons[i]))


# Putar kamera. base = radian per piksel; sensitivitas dibaca langsung dari pengaturan.
func _look(dx: float, dy: float, base: float) -> void:
	var st: Dictionary = Profile.data.settings
	var k: float = float(st.get("sens", 1.0))
	if aiming:
		k *= float(st.get("sens_ads", 0.7))
	var vy: float = float(st.get("sens_v", 1.0))
	var inv: float = -1.0 if bool(st.get("invert_y", false)) else 1.0
	rotate_y(-dx * base * k)
	pitch = clampf(pitch - dy * base * k * vy * inv, -1.1, 0.9)
	head.rotation.x = pitch


# Hadapkan kamera + badan ke arah tertentu (dipakai saat spawn).
func face(yaw: float) -> void:
	rotation.y = yaw
	body_yaw = yaw


func muzzle_global() -> Vector3:
	return view.muzzle_global()


func _unhandled_input(event: InputEvent) -> void:
	if not alive:
		return
	if touch == null and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative.x, event.relative.y, 0.0025)
	for i in 5:
		if event.is_action_pressed("slot%d" % (i + 1)):
			_equip(i)
	if event.is_action_pressed("reload"):
		_start_reload()
	if event.is_action_pressed("ability"):
		_use_ability()


func _physics_process(delta: float) -> void:
	if not alive:
		return
	cooldown = maxf(0.0, cooldown - delta)
	ability_cd = maxf(0.0, ability_cd - delta)
	dash_t = maxf(0.0, dash_t - delta)
	shoot_t = maxf(0.0, shoot_t - delta)
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			_finish_reload()
	if effect_time > 0.0:
		effect_time -= delta
		if effect_time <= 0.0:
			speed_mult = 1.0
			dmg_mult = 1.0
	if heal_left > 0.0:
		var h: float = minf(heal_left, 15.0 * delta)
		hp = minf(max_hp, hp + h)
		heal_left -= h

	var mouse_ok: bool = touch == null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var fire_hold: bool = false
	var aim_hold: bool = false
	var crouch: bool = false
	var sprint: bool = false
	var jump_req: bool = false
	var in_vec := Vector2.ZERO

	if mouse_ok:
		in_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		fire_hold = Input.is_action_pressed("shoot")
		aim_hold = Input.is_action_pressed("aim")
		crouch = Input.is_action_pressed("crouch")
		sprint = Input.is_action_pressed("sprint")
		jump_req = Input.is_action_just_pressed("jump")
	if touch != null:
		aim_hold = touch.aim
		aiming = aim_hold
		var ld: Vector2 = touch.look
		touch.look = Vector2.ZERO
		_look(ld.x, ld.y, 0.0048)
		in_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if touch.move.length() > 0.05:
			in_vec = touch.move
		fire_hold = touch.fire
		crouch = touch.crouch or Input.is_action_pressed("crouch")
		sprint = touch.sprint or Input.is_action_pressed("sprint")
		jump_req = touch.consume("jump") or Input.is_action_just_pressed("jump")
		if touch.consume("reload"):
			_start_reload()
		if touch.consume("ability"):
			_use_ability()
		if touch.consume("swap") and weapons.size() > 0:
			_equip((cur + 1) % weapons.size())
	aiming = aim_hold

	# arah gerak (relatif kamera) + kecepatan analog (dorong joystick pelan = jalan pelan)
	var mag: float = clampf(in_vec.length(), 0.0, 1.0)
	var dir: Vector3 = Vector3.ZERO
	if mag > 0.01:
		dir = (global_transform.basis * Vector3(in_vec.x, 0.0, in_vec.y)).normalized()
	var spd: float = WALK_SPEED * speed_mult * lerpf(0.45, 1.0, mag)
	if sprint:
		spd *= SPRINT_MULT
	if crouch:
		spd *= 0.5
	head.position.y = lerpf(head.position.y, 1.0 if crouch else 1.5, 10.0 * delta)
	visual.scale.y = lerpf(visual.scale.y, 0.8 if crouch else 1.0, 10.0 * delta)
	crouch_w = lerpf(crouch_w, 1.0 if crouch else 0.0, 10.0 * delta)

	# badan mengikuti arah joystick; saat membidik/menembak menghadap arah kamera
	var face_aim: bool = aim_hold or fire_hold or shoot_t > 0.0
	var target_yaw: float = body_yaw
	if face_aim:
		target_yaw = rotation.y
	elif mag > 0.01:
		target_yaw = atan2(-dir.x, -dir.z)
	body_yaw = lerp_angle(body_yaw, target_yaw, minf(1.0, TURN_SPEED * delta))
	body.rotation.y = body_yaw - rotation.y

	if dash_t <= 0.0:
		var accel: float = 10.0 if is_on_floor() else 3.0
		velocity.x = lerpf(velocity.x, dir.x * spd, accel * delta)
		velocity.z = lerpf(velocity.z, dir.z * spd, accel * delta)
	if is_on_floor():
		if jump_req:
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	# kamera zoom
	var fov_t: float = 75.0
	if aim_hold:
		fov_t = 30.0 if weapons[cur] == "sniper" else 55.0
	cam.fov = lerpf(cam.fov, fov_t, 12.0 * delta)
	arm.spring_length = lerpf(arm.spring_length, 1.8 if aim_hold else 3.2, 10.0 * delta)

	# tembak
	if (mouse_ok or touch != null) and weapons.size() > 0:
		var w: Dictionary = GameData.WEAPONS[weapons[cur]]
		var fire: bool = fire_hold
		if not w.auto:
			fire = fire_hold and not prev_fire
		prev_fire = fire_hold
		if fire:
			_shoot(w, aim_hold)

	# animasi
	var hspeed: float = Vector2(velocity.x, velocity.z).length()
	anim.update(delta, hspeed, is_on_floor(), aim_hold or shoot_t > 0.0 or reloading > 0.0)
	view.update(delta, anim.aim_w, pitch, crouch_w, anim.move_w, anim.t)


func _shoot(w: Dictionary, aiming: bool) -> void:
	if cooldown > 0.0 or reloading > 0.0:
		return
	var id: String = weapons[cur]
	if int(ammo[id]) <= 0:
		_start_reload()
		return
	ammo[id] = int(ammo[id]) - 1
	cooldown = float(w.rate)
	shoot_t = 0.6
	var spread: float = float(w.spread)
	if aiming:
		spread *= 0.4
	var b := cam.global_transform.basis
	for i in int(w.pellets):
		var d: Vector3 = (-b.z + b.x * randf_range(-spread, spread) + b.y * randf_range(-spread, spread)).normalized()
		game.fire_ray(self, cam.global_position, d, float(w.range), float(w.dmg) * dmg_mult)
	view.fire()
	pitch = clampf(pitch + 0.004 + float(w.dmg) * 0.00008, -1.1, 0.9)
	head.rotation.x = pitch
	if int(ammo[id]) <= 0:
		_start_reload()


func _start_reload() -> void:
	if weapons.is_empty() or reloading > 0.0:
		return
	var id: String = weapons[cur]
	var w: Dictionary = GameData.WEAPONS[id]
	if int(ammo[id]) >= int(w.mag):
		return
	if not infinite and int(reserve[id]) <= 0:
		return
	reloading = float(w.reload)


func _finish_reload() -> void:
	var id: String = weapons[cur]
	var w: Dictionary = GameData.WEAPONS[id]
	var need: int = int(w.mag) - int(ammo[id])
	var take: int = need if infinite else mini(need, int(reserve[id]))
	ammo[id] = int(ammo[id]) + take
	if not infinite:
		reserve[id] = int(reserve[id]) - take


func _use_ability() -> void:
	if ability_cd > 0.0 or not alive:
		return
	ability_cd = float(skill.cd)
	match str(skill.type):
		"aura":
			heal_left += 40.0
			speed_mult = 1.15
			effect_time = 8.0
		"heal":
			heal_left += 45.0
		"speed":
			speed_mult = 1.6
			effect_time = 6.0
		"shield":
			armor = minf(100.0, armor + 60.0)
		"dash":
			var f: Vector3 = -body.global_transform.basis.z
			velocity.x = f.x * 14.0
			velocity.z = f.z * 14.0
			velocity.y = 7.0
			dash_t = 0.3
		"damage":
			dmg_mult = 1.5
			effect_time = 6.0
	game._feed("Skill: %s" % str(skill.name))


func give(kind: String, value: String) -> bool:
	match kind:
		"weapon":
			if value in weapons:
				_add_weapon(value)
				return true
			if weapons.size() >= 5:
				return false
			_add_weapon(value)
			_equip(weapons.size() - 1)
			return true
		"medkit":
			if hp >= max_hp:
				return false
			heal_left += 50.0
			return true
		"armor":
			if armor >= 100.0:
				return false
			armor = minf(100.0, armor + 50.0)
			return true
		"ammo":
			if weapons.is_empty():
				return false
			var id: String = weapons[cur]
			reserve[id] = int(reserve[id]) + int(GameData.WEAPONS[id].mag)
			return true
	return false


func take_damage(amount: float, attacker, true_damage: bool = false) -> void:
	if not alive:
		return
	var dmg: float = amount
	if not true_damage:
		var absorbed: float = minf(armor, amount * 0.5)
		armor -= absorbed
		dmg -= absorbed
		game.on_player_hit()
	hp -= dmg
	if hp <= 0.0:
		hp = 0.0
		alive = false
		deaths += 1
		head.position.y = 0.6
		visual.rotation.x = -1.4
		view.visible = false
		died.emit(self, attacker)


func respawn(pos: Vector3) -> void:
	alive = true
	hp = max_hp
	armor = 0.0
	speed_mult = 1.0
	dmg_mult = 1.0
	heal_left = 0.0
	reloading = 0.0
	velocity = Vector3.ZERO
	global_position = pos
	rotation.y = 0.0
	body_yaw = 0.0
	body.rotation.y = 0.0
	pitch = 0.0
	head.rotation.x = 0.0
	head.position = Vector3(0.6, 1.5, 0.0)
	visual.rotation = Vector3(0.0, MODEL_YAW, 0.0)
	view.visible = true
	for id in weapons:
		var w: Dictionary = GameData.WEAPONS[id]
		ammo[id] = int(w.mag)
		reserve[id] = int(w.mag) * 3
