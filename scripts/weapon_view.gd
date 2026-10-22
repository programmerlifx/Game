extends Node3D
# Senjata yang dipegang karakter: model asli, posisi pinggang/bidik, recoil, goyang jalan,
# dan kilatan moncong. Dipakai oleh player.gd dan bot.gd (anak dari node "body").

const WeaponModels = preload("res://scripts/weapon_models.gd")
# Posisi titik pegang senjata relatif badan (kaki = 0, depan = -Z, kanan = +X)
const HIP := Vector3(0.26, 1.02, -0.22)
const AIM := Vector3(0.12, 1.37, -0.32)

var weapon_id: String = ""
var model: Node3D = null
var flash: MeshInstance3D
var flash_t: float = 0.0
var kick: float = 0.0
var muzzle_local: Vector3 = Vector3(0, 0, -0.5)


func _init() -> void:
	flash = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.055
	sm.height = 0.11
	flash.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.8, 0.35)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.65, 0.2)
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.material_override = m
	flash.visible = false
	add_child(flash)


func set_weapon(id: String) -> void:
	if id == weapon_id and model != null:
		return
	weapon_id = id
	if model != null:
		model.queue_free()
		model = null
	model = WeaponModels.make(id)
	if model == null:
		model = _fallback()
	add_child(model)
	muzzle_local = Vector3(0, 0, float(model.get_meta("muzzle_z", -0.5)))
	flash.position = muzzle_local


func _fallback() -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.1, 0.6)
	mi.mesh = bm
	mi.position = Vector3(0, 0, -0.15)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.12, 0.12, 0.14)
	mi.material_override = gm
	n.add_child(mi)
	n.set_meta("muzzle_z", -0.45)
	n.set_meta("rear_z", 0.15)
	return n


func fire() -> void:
	kick = 1.0
	flash_t = 0.045
	flash.visible = true
	flash.rotation.z = randf() * TAU
	var s: float = randf_range(0.8, 1.5)
	flash.scale = Vector3(s, s, s)


func update(delta: float, aim_w: float, pitch: float, crouch_w: float, walk_w: float, t: float) -> void:
	kick = maxf(0.0, kick - delta * 9.0)
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0:
			flash.visible = false
	var p: Vector3 = HIP.lerp(AIM, aim_w)
	p.y -= 0.2 * crouch_w
	p.y += sin(t * 8.0) * 0.012 * walk_w * (1.0 - aim_w * 0.8)
	p.z += kick * 0.07
	position = p
	rotation.x = pitch * aim_w + kick * 0.06
	rotation.y = 0.12 * (1.0 - aim_w)


func muzzle_global() -> Vector3:
	return to_global(muzzle_local)
