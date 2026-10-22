extends CharacterBody3D
# Bot musuh/sekutu: model GLB + animasi jalan, cari target, tembak, strafe, jelajah.

const ModelUtil = preload("res://scripts/model_util.gd")
const CharAnim = preload("res://scripts/character_anim.gd")
const WeaponView = preload("res://scripts/weapon_view.gd")
const MODEL_PATH := "res://assets/characters/hero.glb"
const GRAVITY := 24.0
const MOVE_SPEED := 3.3   # lebih lambat dari sebelumnya (4.8)

signal died(victim, killer)

var game
var team: int = 1
var weapon_id: String = "smg"
var passive: bool = false
var display_name: String = "Bot"
var kills: int = 0
var hp: float = 100.0
var armor: float = 0.0
var alive: bool = true

var target = null
var retarget: float = 0.0
var cooldown: float = 0.0
var strafe_dir: float = 1.0
var strafe_t: float = 0.0
var wander_to: Vector3 = Vector3.ZERO
var wander_t: float = 0.0
var shoot_t: float = 0.0
var cs: CollisionShape3D
var visual: Node3D
var label: Label3D
var view
var anim


func _ready() -> void:
	add_to_group("fighters")
	var col: Color = game.team_color(team)

	cs = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	visual = ModelUtil.make_model(MODEL_PATH, 1.8, PI)
	if visual == null:
		visual = Node3D.new()
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.4
		cm.height = 1.8
		mi.mesh = cm
		mi.position.y = 0.9
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		mi.material_override = m
		visual.add_child(mi)
	add_child(visual)
	anim = CharAnim.new()
	anim.setup(visual)

	# cincin warna tim di kaki
	var ring := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.55
	rm.bottom_radius = 0.55
	rm.height = 0.03
	ring.mesh = rm
	ring.position.y = 0.03
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = col
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rmat
	add_child(ring)

	view = WeaponView.new()
	add_child(view)
	view.set_weapon(weapon_id)

	label = Label3D.new()
	label.text = display_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.2
	label.pixel_size = 0.008
	label.font_size = 40
	label.modulate = col
	add_child(label)

	hp = 100.0
	_pick_wander()


func _find_target():
	var best = null
	var best_d: float = 55.0
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == self or not f.alive or f.team == team:
			continue
		var d: float = global_position.distance_to(f.global_position)
		if d < best_d:
			best_d = d
			best = f
	return best


func _has_los(t) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.5, 0), t.global_position + Vector3(0, 1.1, 0))
	q.exclude = [get_rid()]
	var r := space.intersect_ray(q)
	return r.size() > 0 and r.collider == t


func _pick_wander() -> void:
	wander_t = randf_range(4.0, 8.0)
	var lim: float = float(game.map_size) * 0.5 - 6.0
	if game.zone_active:
		lim = maxf(3.0, minf(lim, float(game.zone_radius) - 5.0))
	wander_to = Vector3(randf_range(-lim, lim), 0.0, randf_range(-lim, lim))


func _shoot_at(t) -> void:
	var w: Dictionary = GameData.WEAPONS[weapon_id]
	cooldown = float(w.rate) * 2.2 + randf() * 0.3
	shoot_t = 0.7
	view.fire()
	var origin: Vector3 = global_position + Vector3(0, 1.5, 0)
	var aim: Vector3 = t.global_position + Vector3(0, 1.1, 0)
	var base: Vector3 = (aim - origin).normalized()
	var err: float = float(w.spread) + 0.04
	for i in int(w.pellets):
		var d: Vector3 = (base + Vector3(randf_range(-err, err), randf_range(-err, err), randf_range(-err, err))).normalized()
		game.fire_ray(self, origin, d, float(w.range), float(w.dmg) * 0.55)


func _animate(delta: float) -> void:
	var near: bool = true
	if game.player != null and is_instance_valid(game.player):
		near = global_position.distance_to(game.player.global_position) < 80.0
	if near:
		anim.update(delta, Vector2(velocity.x, velocity.z).length(), is_on_floor(), shoot_t > 0.0 or target != null)
		var gp: float = 0.0
		if target != null and is_instance_valid(target):
			var tv: Vector3 = target.global_position - global_position
			gp = atan2(tv.y - 0.4, maxf(Vector2(tv.x, tv.z).length(), 1.0))
		view.update(delta, anim.aim_w, gp, 0.0, anim.move_w, anim.t)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	shoot_t = maxf(0.0, shoot_t - delta)
	if passive:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_animate(delta)
		return

	cooldown -= delta
	retarget -= delta
	if retarget <= 0.0:
		retarget = 0.4
		target = _find_target()
	if target != null and (not is_instance_valid(target) or not target.alive):
		target = null

	var move := Vector3.ZERO
	if target != null:
		var to: Vector3 = target.global_position - global_position
		to.y = 0.0
		var dist: float = to.length()
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 8.0 * delta)
		strafe_t -= delta
		if strafe_t <= 0.0:
			strafe_t = randf_range(0.8, 2.0)
			strafe_dir = -1.0 if randf() < 0.5 else 1.0
		if dist > 16.0:
			move = to.normalized()
		elif dist < 7.0:
			move = -to.normalized()
		move += global_transform.basis.x * strafe_dir * 0.7
		if cooldown <= 0.0 and dist < 60.0 and _has_los(target):
			_shoot_at(target)
	else:
		wander_t -= delta
		var flat := Vector3(global_position.x, 0.0, global_position.z)
		if game.zone_active and Vector2(flat.x, flat.z).length() > float(game.zone_radius) - 4.0:
			wander_to = Vector3.ZERO
		elif wander_t <= 0.0 or flat.distance_to(wander_to) < 2.0:
			_pick_wander()
		var to2: Vector3 = wander_to - flat
		if to2.length() > 0.5:
			move = to2.normalized()
			rotation.y = lerp_angle(rotation.y, atan2(-move.x, -move.z), 5.0 * delta)

	move = move.limit_length(1.0)
	velocity.x = move.x * MOVE_SPEED
	velocity.z = move.z * MOVE_SPEED
	if is_on_wall():
		wander_t = 0.0
		if is_on_floor():
			velocity.y = 6.5
	move_and_slide()
	_animate(delta)


func take_damage(amount: float, attacker, true_damage: bool = false) -> void:
	if not alive:
		return
	var dmg: float = amount
	if not true_damage:
		var absorbed: float = minf(armor, amount * 0.5)
		armor -= absorbed
		dmg -= absorbed
	hp -= dmg
	if attacker != null and not passive and attacker.team != team:
		target = attacker
	label.text = "%s (%d)" % [display_name, maxi(0, int(hp))]
	if hp <= 0.0:
		_die(attacker)


func _die(attacker) -> void:
	alive = false
	remove_from_group("fighters")
	cs.set_deferred("disabled", true)
	label.text = ""
	view.visible = false
	died.emit(self, attacker)
	var tw := create_tween()
	tw.tween_property(visual, "rotation_degrees:x", -90.0, 0.4)
	tw.tween_interval(0.5 if passive else 3.0)
	tw.tween_callback(queue_free)
