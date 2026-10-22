extends Node3D
# Pengatur pertandingan: dunia, spawn, zona, ronde, HUD.

const PlayerScript = preload("res://scripts/player.gd")
const BotScript = preload("res://scripts/bot.gd")
const MinimapScript = preload("res://scripts/minimap.gd")
const TouchScript = preload("res://scripts/touch_controls.gd")
const WeaponModels = preload("res://scripts/weapon_models.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const UiEditor = preload("res://scripts/ui_editor.gd")

const BOT_NAMES := ["Raka", "Dewi", "Joko", "Sinta", "Budi", "Wati", "Agus", "Putri", "Eko", "Maya", "Tono", "Lestari", "Fajar", "Ayu", "Hendra", "Mawar", "Dimas", "Nina", "Rudi", "Citra", "Bayu", "Intan", "Yoga", "Sekar"]
const ZONE_PHASES := [0.31, 0.19, 0.09, 0.035]

var cfg: Dictionary
var map_size: float = 100.0
var player = null
var obstacles: Array[Rect2] = []
var houses: Array[Vector3] = []
var team_kills: Dictionary = {}
var score: Array = [0, 0]
var round_no: int = 1
var round_over: bool = false
var ended: bool = false
var menu_open: bool = false
var name_idx: int = 0
var _tracer_mat: StandardMaterial3D
var _spark_mesh: SphereMesh
var _spark_mat: StandardMaterial3D
var _blood_mat: StandardMaterial3D
var _hole_mat: StandardMaterial3D
var sun: DirectionalLight3D
var settings_ui: Panel = null

var zone_active: bool = false
var zone_radius: float = 100.0
var zone_from: float = 100.0
var zone_to: float = 100.0
var zone_phase: int = 0
var zone_state: String = "wait"
var zone_timer: float = 30.0
var zone_mesh: MeshInstance3D

# HUD
var hud_root: Control
var bar_hp: ProgressBar
var bar_armor: ProgressBar
var lbl_info: Label
var lbl_ammo: Label
var lbl_slots: Label
var lbl_ability: Label
var lbl_feed: Label
var lbl_msg: Label
var lbl_cross: Label
var flash: ColorRect
var panel: Panel
var lbl_title: Label
var btn_resume: Button
var btn_settings: Button
var feed: Array = []
var msg_t: float = 0.0
var flash_a: float = 0.0
var hit_t: float = 0.0
var touch_mode: bool = false
var touch = null


func _ready() -> void:
	randomize()
	cfg = GameData.MODES[GameData.selected_mode]
	map_size = float(cfg.map)
	_tracer_mat = StandardMaterial3D.new()
	_tracer_mat.albedo_color = Color(1.0, 0.9, 0.4)
	_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mesh = SphereMesh.new()
	_spark_mesh.radius = 0.06
	_spark_mesh.height = 0.12
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.albedo_color = Color(1.0, 0.85, 0.4)
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blood_mat = StandardMaterial3D.new()
	_blood_mat.albedo_color = Color(0.8, 0.1, 0.1)
	_blood_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hole_mat = StandardMaterial3D.new()
	_hole_mat.albedo_color = Color(0.05, 0.05, 0.05)
	_hole_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tm: int = int(Profile.data.settings.touch)
	touch_mode = tm == 1 or (tm == 0 and DisplayServer.is_touchscreen_available())
	_build_world()
	_build_hud()
	if cfg.zone:
		_setup_zone()
	_spawn_all()
	if touch_mode:
		touch = TouchScript.new()
		touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hud_root.add_child(touch)
		player.touch = touch
	if int(cfg.loot) > 0:
		_spawn_loot()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if touch_mode else Input.MOUSE_MODE_CAPTURED
	_apply_quality()
	_msg("MODE: %s" % str(cfg.name))


# ---------------------------------------------------------------- Dunia
func _build_world() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.42, 0.78)
	sky_mat.sky_horizon_color = Color(0.68, 0.78, 0.9)
	sky_mat.ground_horizon_color = Color(0.62, 0.68, 0.7)
	sky_mat.ground_bottom_color = Color(0.28, 0.32, 0.28)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.06
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.8, 0.9)
	env.fog_density = 0.0025
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -30.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.2
	sun.shadow_enabled = false
	add_child(sun)

	# tanah rumput bertekstur (noise prosedural)
	_add_ground()
	# tembok batas
	var hw: float = map_size * 0.5
	_add_box(Vector3(0, 4, -hw - 1), Vector3(map_size + 4, 8, 2), Color(0.2, 0.2, 0.25), false)
	_add_box(Vector3(0, 4, hw + 1), Vector3(map_size + 4, 8, 2), Color(0.2, 0.2, 0.25), false)
	_add_box(Vector3(-hw - 1, 4, 0), Vector3(2, 8, map_size + 4), Color(0.2, 0.2, 0.25), false)
	_add_box(Vector3(hw + 1, 4, 0), Vector3(2, 8, map_size + 4), Color(0.2, 0.2, 0.25), false)

	var half: float = hw - 8.0
	# rumah berongga
	var placed := 0
	var tries := 0
	var want: int = maxi(2, int(map_size / 12.0))
	while placed < want and tries < 300:
		tries += 1
		var w: float = randf_range(6.0, 11.0)
		var d: float = randf_range(6.0, 11.0)
		var h: float = randf_range(4.2, 6.0)
		var cx: float = randf_range(-half + w * 0.5, half - w * 0.5)
		var cz: float = randf_range(-half + d * 0.5, half - d * 0.5)
		if _rect_free(Rect2(cx - w * 0.5, cz - d * 0.5, w, d).grow(3.0)):
			_add_house(Vector3(cx, 0, cz), w, d, h, Color.from_hsv(randf(), 0.25, 0.75))
			placed += 1
	# peti
	tries = 0
	placed = 0
	var crates: int = int(map_size / 5.0)
	while placed < crates and tries < 400:
		tries += 1
		var s: float = randf_range(1.2, 2.5)
		var x: float = randf_range(-half, half)
		var z: float = randf_range(-half, half)
		if _rect_free(Rect2(x - s * 0.5, z - s * 0.5, s, s).grow(1.0)):
			_add_box(Vector3(x, s * 0.5, z), Vector3(s, s, s), Color(0.55, 0.38, 0.2), true)
			placed += 1
	# pohon
	tries = 0
	placed = 0
	var trees: int = int(map_size / 3.0)
	while placed < trees and tries < 600:
		tries += 1
		var x2: float = randf_range(-half, half)
		var z2: float = randf_range(-half, half)
		if _rect_free(Rect2(x2 - 1.0, z2 - 1.0, 2.0, 2.0).grow(1.0)):
			_add_tree(Vector3(x2, 0, z2))
			placed += 1
	# semak (hiasan, tanpa tabrakan)
	tries = 0
	placed = 0
	var bushes: int = int(map_size / 3.5)
	while placed < bushes and tries < 300:
		tries += 1
		var bx: float = randf_range(-half, half)
		var bz: float = randf_range(-half, half)
		if _rect_free(Rect2(bx - 1.0, bz - 1.0, 2.0, 2.0)):
			_add_bush(Vector3(bx, 0, bz))
			placed += 1


func _add_ground() -> void:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.2, 0.34, 0.13), Color(0.4, 0.54, 0.22)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = 0.02
	var tex := NoiseTexture2D.new()
	tex.noise = nz
	tex.color_ramp = grad
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	var g := _add_box(Vector3(0, -1, 0), Vector3(map_size + 60.0, 2.0, map_size + 60.0), Color(0.3, 0.5, 0.25), false)
	for ch in g.get_children():
		var mi := ch as MeshInstance3D
		if mi != null:
			var gm := StandardMaterial3D.new()
			gm.albedo_texture = tex
			gm.uv1_triplanar = true
			gm.uv1_world_triplanar = true
			gm.uv1_scale = Vector3(0.12, 0.12, 0.12)
			gm.roughness = 1.0
			mi.material_override = gm


func _add_bush(pos: Vector3) -> void:
	var bush := Node3D.new()
	for i in 3:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var r: float = randf_range(0.45, 0.8)
		sm.radius = r
		sm.height = r * 1.6
		mi.mesh = sm
		mi.position = Vector3(randf_range(-0.5, 0.5), r * 0.6, randf_range(-0.5, 0.5))
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color.from_hsv(randf_range(0.25, 0.34), 0.6, randf_range(0.3, 0.5))
		bm.roughness = 1.0
		mi.material_override = bm
		bush.add_child(mi)
	bush.position = pos
	add_child(bush)


func _apply_quality() -> void:
	var q: int = int(Profile.data.settings.get("quality", 1))
	if q >= 2:
		get_viewport().msaa_3d = Viewport.MSAA_4X
	elif q == 1:
		get_viewport().msaa_3d = Viewport.MSAA_2X
	else:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	if sun != null:
		sun.shadow_enabled = q >= 1
		sun.directional_shadow_max_distance = 120.0 if q >= 2 else 60.0


func _rect_free(r: Rect2) -> bool:
	for o in obstacles:
		if o.intersects(r):
			return false
	return true


func _add_box(pos: Vector3, size: Vector3, color: Color, register: bool = true) -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mi.material_override = mat
	b.add_child(mi)
	b.position = pos
	add_child(b)
	if register:
		obstacles.append(Rect2(pos.x - size.x * 0.5, pos.z - size.z * 0.5, size.x, size.z))
	return b


func _add_house(c: Vector3, w: float, d: float, h: float, col: Color) -> void:
	var t := 0.5
	_add_box(Vector3(c.x, h * 0.5, c.z - d * 0.5), Vector3(w, h, t), col, false)
	_add_box(Vector3(c.x - w * 0.5, h * 0.5, c.z), Vector3(t, h, d), col, false)
	_add_box(Vector3(c.x + w * 0.5, h * 0.5, c.z), Vector3(t, h, d), col, false)
	var seg: float = (w - 3.0) * 0.5
	_add_box(Vector3(c.x - w * 0.5 + seg * 0.5, h * 0.5, c.z + d * 0.5), Vector3(seg, h, t), col, false)
	_add_box(Vector3(c.x + w * 0.5 - seg * 0.5, h * 0.5, c.z + d * 0.5), Vector3(seg, h, t), col, false)
	_add_box(Vector3(c.x, 3.0 + (h - 3.0) * 0.5, c.z + d * 0.5), Vector3(3.0, h - 3.0, t), col, false)
	_add_box(Vector3(c.x, h + 0.2, c.z), Vector3(w + 0.6, 0.4, d + 0.6), col.darkened(0.35), false)
	obstacles.append(Rect2(c.x - w * 0.5, c.z - d * 0.5, w, d))
	houses.append(c)


func _add_tree(pos: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.4
	sh.height = 5.0
	cs.shape = sh
	cs.position.y = 2.5
	b.add_child(cs)
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.4
	cm.height = 5.0
	trunk.mesh = cm
	trunk.position.y = 2.5
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.4, 0.27, 0.15)
	trunk.material_override = tm
	b.add_child(trunk)
	var leaf_col := Color.from_hsv(randf_range(0.27, 0.36), 0.6, randf_range(0.3, 0.45))
	for i in 3:
		var top := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var rr: float = 2.0 - i * 0.35
		sm.radius = rr
		sm.height = rr * 1.8
		top.mesh = sm
		top.position = Vector3(randf_range(-0.5, 0.5) * i, 4.8 + i * 1.1, randf_range(-0.5, 0.5) * i)
		var lm := StandardMaterial3D.new()
		lm.albedo_color = leaf_col.lightened(i * 0.08)
		lm.roughness = 1.0
		top.material_override = lm
		b.add_child(top)
	b.position = pos
	add_child(b)
	obstacles.append(Rect2(pos.x - 0.5, pos.z - 0.5, 1.0, 1.0))


func _setup_zone() -> void:
	zone_active = true
	zone_radius = map_size * 0.72
	zone_mesh = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 60.0
	cm.cap_top = false
	cm.cap_bottom = false
	zone_mesh.mesh = cm
	var zm := StandardMaterial3D.new()
	zm.albedo_color = Color(0.2, 0.5, 1.0, 0.25)
	zm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zm.cull_mode = BaseMaterial3D.CULL_DISABLED
	zm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zone_mesh.material_override = zm
	zone_mesh.position.y = 30.0
	add_child(zone_mesh)
	zone_mesh.scale = Vector3(zone_radius, 1.0, zone_radius)


# ---------------------------------------------------------------- Spawn
func team_color(t: int) -> Color:
	if cfg.ffa:
		return Color.from_hsv(fmod(t * 0.137, 1.0), 0.7, 0.95)
	return Color(0.2, 0.6, 1.0) if t == 0 else Color(1.0, 0.25, 0.2)


func _free_spot(p: Vector2, margin: float) -> bool:
	for o in obstacles:
		if o.grow(margin).has_point(p):
			return false
	return true


func _spawn_point(t: int) -> Vector3:
	var half: float = map_size * 0.5 - 8.0
	for i in 40:
		var p: Vector2
		if cfg.ffa:
			p = Vector2(randf_range(-half, half), randf_range(-half, half))
		else:
			var zs: float = 1.0 if t == 0 else -1.0
			p = Vector2(randf_range(-half, half), zs * randf_range(half * 0.5, half))
		if _free_spot(p, 2.0):
			return Vector3(p.x, 1.0, p.y)
	return Vector3(0, 1.0, 0)


func _bot_weapon() -> String:
	if cfg.passive:
		return "pistol"
	var pool: Array = ["pistol", "smg", "ar", "ak47"] if cfg.zone else ["smg", "ar", "ak47", "sniper"]
	return String(pool.pick_random())


func _spawn_bot(t: int, pos: Vector3, weapon: String, passive: bool):
	var b = BotScript.new()
	b.game = self
	b.team = t
	b.weapon_id = weapon
	b.passive = passive
	b.display_name = "Target" if passive else str(BOT_NAMES[name_idx % BOT_NAMES.size()])
	name_idx += 1
	b.add_to_group("bots")
	add_child(b)
	b.global_position = pos
	b.died.connect(_on_died)
	return b


func _spawn_all() -> void:
	for b in get_tree().get_nodes_in_group("bots"):
		b.remove_from_group("fighters")
		b.queue_free()
	var loadout: Array = cfg.loadout
	if player == null:
		player = PlayerScript.new()
		player.game = self
		player.skill_idx = int(Profile.data.skill)
		player.team = 0
		player.loadout = loadout
		player.infinite = bool(cfg.passive)
		add_child(player)
		player.died.connect(_on_died)
		player.global_position = _spawn_point(0)
	else:
		player.respawn(_spawn_point(0))
	if cfg.ffa:
		player.face(randf() * TAU)
	for i in int(cfg.allies):
		_spawn_bot(0, _spawn_point(0), _bot_weapon(), false)
	for i in int(cfg.enemies):
		var t: int = (i + 1) if cfg.ffa else 1
		_spawn_bot(t, _spawn_point(t), _bot_weapon(), bool(cfg.passive))


func _spawn_loot() -> void:
	var half: float = map_size * 0.5 - 4.0
	for i in int(cfg.loot):
		var pos: Vector3
		if houses.size() > 0 and randf() < 0.4:
			var h: Vector3 = houses.pick_random()
			pos = Vector3(h.x + randf_range(-2.0, 2.0), 0.7, h.z + randf_range(-2.0, 2.0))
		else:
			var p := Vector2(randf_range(-half, half), randf_range(-half, half))
			if not _free_spot(p, 1.0):
				continue
			pos = Vector3(p.x, 0.7, p.y)
		_spawn_random_pickup(pos)


func _spawn_random_pickup(pos: Vector3) -> void:
	var r: float = randf()
	if r < 0.45:
		var pool: Array = ["pistol", "smg", "smg", "ar", "ak47", "ak47", "sniper"]
		_spawn_pickup(pos, "weapon", String(pool.pick_random()))
	elif r < 0.65:
		_spawn_pickup(pos, "medkit")
	elif r < 0.8:
		_spawn_pickup(pos, "armor")
	else:
		_spawn_pickup(pos, "ammo")


func _spawn_pickup(pos: Vector3, kind: String, value: String = "") -> void:
	var mi := MeshInstance3D.new()
	var col := Color.WHITE
	var lab: String = kind
	match kind:
		"weapon":
			lab = str(GameData.WEAPONS[value].name)
			col = Color(1.0, 0.85, 0.2)
			var gm: Node3D = WeaponModels.make(value)
			if gm != null:
				gm.scale = Vector3(1.3, 1.3, 1.3)
				mi.add_child(gm)
				var disc := MeshInstance3D.new()
				var dcm := CylinderMesh.new()
				dcm.top_radius = 0.6
				dcm.bottom_radius = 0.6
				dcm.height = 0.02
				disc.mesh = dcm
				disc.position.y = -0.62
				var dmat := StandardMaterial3D.new()
				dmat.albedo_color = Color(1.0, 0.85, 0.2, 0.35)
				dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				disc.material_override = dmat
				mi.add_child(disc)
			else:
				var bm := BoxMesh.new()
				bm.size = Vector3(0.7, 0.2, 0.25)
				mi.mesh = bm
		"medkit":
			var bm2 := BoxMesh.new()
			bm2.size = Vector3(0.45, 0.45, 0.45)
			mi.mesh = bm2
			col = Color(0.2, 0.9, 0.35)
			lab = "Medkit"
		"armor":
			var sm := SphereMesh.new()
			sm.radius = 0.3
			sm.height = 0.6
			mi.mesh = sm
			col = Color(0.3, 0.55, 1.0)
			lab = "Armor"
		_:
			var bm3 := BoxMesh.new()
			bm3.size = Vector3(0.35, 0.35, 0.35)
			mi.mesh = bm3
			col = Color(1.0, 0.55, 0.15)
			lab = "Amunisi"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.6
	if mi.mesh != null:
		mi.material_override = mat
	mi.set_meta("kind", kind)
	mi.set_meta("value", value)
	mi.set_meta("label", lab)
	mi.add_to_group("pickups")
	add_child(mi)
	mi.global_position = pos


# ---------------------------------------------------------------- Tembak
func fire_ray(shooter, origin: Vector3, dir: Vector3, rng: float, dmg: float) -> void:
	var space := get_world_3d().direct_space_state
	var end_p: Vector3 = origin + dir * rng
	var q := PhysicsRayQueryParameters3D.create(origin, end_p)
	q.exclude = [shooter.get_rid()]
	var r := space.intersect_ray(q)
	if r.size() > 0:
		end_p = r.position
		var c = r.collider
		var hit_char: bool = false
		if c != null and c.has_method("take_damage"):
			hit_char = true
			if c.team != shooter.team:
				var d: float = dmg
				var head_shot: bool = r.position.y > c.global_position.y + 1.45
				if head_shot:
					d *= 2.0
				c.take_damage(d, shooter)
				if shooter == player:
					hit_t = 0.15
		_impact(r.position, r.normal, hit_char, shooter == player)
	_tracer(origin, end_p, shooter == player)


# Percikan/darah di titik kena + lubang peluru (hanya tembakan pemain) agar terasa nyata.
func _impact(pos: Vector3, normal: Vector3, hit_char: bool, own: bool) -> void:
	if player != null and pos.distance_to(player.global_position) > 60.0:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _spark_mesh
	mi.material_override = _blood_mat if hit_char else _spark_mat
	add_child(mi)
	mi.global_position = pos + normal * 0.03
	get_tree().create_timer(0.1).timeout.connect(mi.queue_free)
	if own and not hit_char:
		var hole := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.14, 0.14)
		hole.mesh = qm
		hole.material_override = _hole_mat
		add_child(hole)
		hole.global_position = pos + normal * 0.02
		var up: Vector3 = Vector3.UP if absf(normal.y) < 0.95 else Vector3.RIGHT
		hole.look_at(pos - normal, up)
		get_tree().create_timer(8.0).timeout.connect(hole.queue_free)


func _tracer(a: Vector3, b: Vector3, own: bool) -> void:
	var delta_v: Vector3 = b - a
	var dist: float = delta_v.length()
	if dist < 2.0:
		return
	var dir: Vector3 = delta_v / dist
	var start: Vector3 = a + dir * 1.0
	if own and player != null:
		start = player.muzzle_global()
	var seg_len: float = start.distance_to(b)
	if seg_len < 0.5:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.03, 0.03, seg_len)
	mi.mesh = bm
	mi.material_override = _tracer_mat
	add_child(mi)
	mi.global_position = (start + b) * 0.5
	var up: Vector3 = Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	mi.look_at(b, up)
	get_tree().create_timer(0.06).timeout.connect(mi.queue_free)


func on_player_hit() -> void:
	flash_a = 0.35


# ---------------------------------------------------------------- Logika
func _alive_count(t: int) -> int:
	var n := 0
	for f in get_tree().get_nodes_in_group("fighters"):
		if f.alive and f.team == t:
			n += 1
	return n


func _alive_all() -> int:
	var n := 0
	for f in get_tree().get_nodes_in_group("fighters"):
		if f.alive:
			n += 1
	return n


func _on_died(victim, killer) -> void:
	if ended:
		return
	if killer != null and is_instance_valid(killer) and killer != victim:
		killer.kills += 1
		team_kills[killer.team] = int(team_kills.get(killer.team, 0)) + 1
		_feed("%s > %s" % [killer.display_name, victim.display_name])
	else:
		_feed("%s gugur" % victim.display_name)
	if victim != player and int(cfg.loot) > 0:
		_spawn_random_pickup(victim.global_position + Vector3(0, 0.7, 0))

	if cfg.zone:
		_check_br()
	elif int(cfg.rounds) > 0:
		_check_round()
	elif float(cfg.respawn) > 0.0:
		_after_death_respawn(victim)


func _check_br() -> void:
	if not player.alive:
		var rank: int = _alive_all() + 1
		_end_match("GUGUR - Peringkat #%d" % rank, false, rank)
	elif _alive_all() <= 1:
		_end_match("JUARA! Kamu bertahan terakhir", true, 1)


func _check_round() -> void:
	if round_over:
		return
	var a: int = _alive_count(0)
	var b: int = _alive_count(1)
	if a > 0 and b > 0:
		return
	round_over = true
	var win: int = 0 if a > 0 else 1
	score[win] += 1
	_msg("Ronde %d: %s menang" % [round_no, "TIM KAMU" if win == 0 else "LAWAN"])
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree() or ended:
		return
	if int(score[win]) >= int(cfg.rounds):
		if win == 0:
			_end_match("MENANG! Skor %d - %d" % [score[0], score[1]], true)
		else:
			_end_match("KALAH. Skor %d - %d" % [score[0], score[1]], false)
	else:
		round_no += 1
		round_over = false
		_spawn_all()


func _after_death_respawn(victim) -> void:
	var target: int = int(cfg.kill_target)
	if target > 0:
		for t in team_kills.keys():
			if int(team_kills[t]) >= target:
				if int(t) == 0:
					_end_match("MENANG! Target kill tercapai", true)
				else:
					_end_match("KALAH. Lawan mencapai target kill", false)
				return
	var tm: int = victim.team
	var is_p: bool = victim == player
	if is_p:
		_msg("Kamu gugur - respawn %d detik" % int(cfg.respawn))
	await get_tree().create_timer(float(cfg.respawn)).timeout
	if not is_inside_tree() or ended:
		return
	if is_p:
		player.respawn(_spawn_point(0))
	else:
		_spawn_bot(tm, _spawn_point(tm), _bot_weapon(), bool(cfg.passive))


func _update_zone(delta: float) -> void:
	zone_timer -= delta
	match zone_state:
		"wait":
			if zone_timer <= 0.0:
				if zone_phase >= ZONE_PHASES.size():
					zone_state = "done"
				else:
					zone_state = "shrink"
					zone_timer = 25.0
					zone_from = zone_radius
					zone_to = map_size * float(ZONE_PHASES[zone_phase])
		"shrink":
			zone_radius = lerpf(zone_to, zone_from, clampf(zone_timer / 25.0, 0.0, 1.0))
			if zone_timer <= 0.0:
				zone_phase += 1
				zone_state = "wait"
				zone_timer = 25.0
	zone_mesh.scale = Vector3(zone_radius, 1.0, zone_radius)
	var dps: float = 3.0 + 3.0 * zone_phase
	for f in get_tree().get_nodes_in_group("fighters"):
		if f.alive and Vector2(f.global_position.x, f.global_position.z).length() > zone_radius:
			f.take_damage(dps * delta, null, true)


func _end_match(text: String, win: bool = false, rank: int = 99) -> void:
	if ended:
		return
	ended = true
	var msg: String = text
	if GameData.selected_mode != "train":
		var r: Dictionary = Profile.record_match(GameData.selected_mode, player.kills, player.deaths, win, rank)
		msg += "\n+%d XP   +%d Koin   %+d RP" % [int(r.xp), int(r.gold), int(r.rp)]
		if int(r.levels) > 0:
			msg += "\nNAIK LEVEL! Lv %d" % int(Profile.data.level)
	_show_panel(msg, false)


# ---------------------------------------------------------------- Loop
func _process(delta: float) -> void:
	if ended:
		return
	if touch != null and touch.consume("pause") and not menu_open:
		_show_panel("JEDA", true)
		return
	for p in get_tree().get_nodes_in_group("pickups"):
		p.rotate_y(delta * 1.6)
		if player != null and player.alive:
			var dv: Vector3 = p.global_position - player.global_position
			dv.y = 0.0
			if dv.length() < 2.0:
				if player.give(str(p.get_meta("kind")), str(p.get_meta("value"))):
					_feed("Mengambil " + str(p.get_meta("label")))
					p.remove_from_group("pickups")
					p.queue_free()
	if zone_active:
		_update_zone(delta)
	_update_hud(delta)


func _unhandled_input(event: InputEvent) -> void:
	if ended:
		return
	if event.is_action_pressed("ui_cancel") and not menu_open:
		_show_panel("JEDA", true)
	elif not touch_mode and event is InputEventMouseButton and event.pressed and not menu_open and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------- HUD
func _mk_label(parent: Node, text: String, pos: Vector2, sz: Vector2, font: int = 16, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l


func _mk_bar(pos: Vector2, col: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = Vector2(260, 18)
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	bar.add_theme_stylebox_override("fill", sb)
	hud_root.add_child(bar)
	return bar


func _mk_button(parent: Node, text: String, pos: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(200, 44)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud_root)

	flash = ColorRect.new()
	flash.color = Color(1, 0, 0, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(flash)

	lbl_cross = _mk_label(hud_root, "+", Vector2(620, 340), Vector2(40, 40), 30, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	bar_hp = _mk_bar(Vector2(20, 670), Color(0.2, 0.85, 0.3))
	bar_armor = _mk_bar(Vector2(20, 646), Color(0.3, 0.55, 1.0))
	lbl_ability = _mk_label(hud_root, "", Vector2(20, 200), Vector2(420, 28), 17)
	lbl_info = _mk_label(hud_root, "", Vector2(340, 10), Vector2(600, 30), 20, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_ammo = _mk_label(hud_root, "", Vector2(940, 650), Vector2(320, 40), 28, HORIZONTAL_ALIGNMENT_RIGHT)
	lbl_slots = _mk_label(hud_root, "", Vector2(340, 685), Vector2(600, 28), 16, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_feed = _mk_label(hud_root, "", Vector2(880, 10), Vector2(380, 160), 15, HORIZONTAL_ALIGNMENT_RIGHT)
	lbl_msg = _mk_label(hud_root, "", Vector2(240, 150), Vector2(800, 60), 34, HORIZONTAL_ALIGNMENT_CENTER)
	if touch_mode:
		lbl_ammo.position = Vector2(440, 40)
		lbl_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_slots.visible = false

	var mm = MinimapScript.new()
	mm.game = self
	mm.position = Vector2(20, 20)
	mm.size = Vector2(170, 170)
	mm.clip_contents = true
	mm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(mm)

	panel = Panel.new()
	panel.position = Vector2(440, 150)
	panel.size = Vector2(400, 420)
	panel.visible = false
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_root.add_child(panel)
	lbl_title = _mk_label(panel, "", Vector2(10, 16), Vector2(380, 114), 24, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn_resume = _mk_button(panel, "LANJUT", Vector2(100, 140), _resume)
	btn_settings = _mk_button(panel, "PENGATURAN", Vector2(100, 200), _open_settings)
	_mk_button(panel, "MAIN LAGI", Vector2(100, 260), _again)
	_mk_button(panel, "LOBI", Vector2(100, 320), _to_menu)


func _msg(t: String) -> void:
	lbl_msg.text = t
	msg_t = 3.0


func _feed(t: String) -> void:
	feed.append([t, Time.get_ticks_msec() / 1000.0 + 5.0])
	if feed.size() > 6:
		feed.pop_front()


func _update_hud(delta: float) -> void:
	if player == null:
		return
	bar_hp.value = player.hp / player.max_hp * 100.0
	bar_armor.value = player.armor

	if player.weapons.size() > 0:
		var id: String = player.weapons[player.cur]
		var w: Dictionary = GameData.WEAPONS[id]
		var res_txt: String = "INF" if player.infinite else str(player.reserve[id])
		lbl_ammo.text = "%s  %d / %s" % [w.name, player.ammo[id], res_txt]
		if player.reloading > 0.0:
			lbl_ammo.text += "  (RELOAD)"
		var s := ""
		for i in player.weapons.size():
			var nm: String = GameData.WEAPONS[player.weapons[i]].name
			if i == player.cur:
				s += "[%d:%s] " % [i + 1, nm]
			else:
				s += " %d:%s  " % [i + 1, nm]
		lbl_slots.text = s

	if player.ability_cd > 0.0:
		lbl_ability.text = "[Q] %s: %d detik" % [player.skill.name, int(ceil(player.ability_cd))]
	else:
		lbl_ability.text = "[Q] %s: SIAP" % player.skill.name

	lbl_info.text = _info_text()

	var now: float = Time.get_ticks_msec() / 1000.0
	var keep: Array = []
	var txt := ""
	for e in feed:
		if now < float(e[1]):
			keep.append(e)
			txt += str(e[0]) + "\n"
	feed = keep
	lbl_feed.text = txt

	if msg_t > 0.0:
		msg_t -= delta
		if msg_t <= 0.0:
			lbl_msg.text = ""
	flash_a = maxf(0.0, flash_a - delta * 1.5)
	flash.color.a = flash_a
	hit_t -= delta
	lbl_cross.modulate = Color(1.0, 0.2, 0.2) if hit_t > 0.0 else Color.WHITE


func _info_text() -> String:
	var kills: int = player.kills
	if cfg.zone:
		var z := ""
		match zone_state:
			"wait":
				z = "menyempit %d dtk" % int(ceil(zone_timer)) if zone_phase < ZONE_PHASES.size() else "zona akhir"
			"shrink":
				z = "MENYEMPIT!"
			_:
				z = "zona akhir"
		return "ZONA: %s | HIDUP: %d | KILL: %d" % [z, _alive_all(), kills]
	if int(cfg.rounds) > 0:
		return "RONDE %d | KAMU %d - %d LAWAN | HIDUP %d vs %d" % [round_no, score[0], score[1], _alive_count(0), _alive_count(1)]
	if int(cfg.kill_target) > 0:
		if cfg.ffa:
			return "KILL KAMU %d | TARGET %d" % [kills, int(cfg.kill_target)]
		return "TIM KAMU %d - %d LAWAN | TARGET %d KILL" % [int(team_kills.get(0, 0)), int(team_kills.get(1, 0)), int(cfg.kill_target)]
	return "LATIHAN | KILL %d | ESC = menu" % kills


func _show_panel(title: String, can_resume: bool) -> void:
	lbl_title.text = title
	btn_resume.visible = can_resume
	btn_settings.visible = can_resume
	panel.visible = true
	menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func _resume() -> void:
	_apply_quality()
	if touch != null:
		touch.reload_layout()
	panel.visible = false
	menu_open = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if touch_mode else Input.MOUSE_MODE_CAPTURED


func _again() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


# ---------------------------------------------------------------- Pengaturan dalam game
func _open_settings() -> void:
	panel.visible = false
	if settings_ui != null:
		settings_ui.queue_free()
	settings_ui = Panel.new()
	settings_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_ui.position = Vector2(70, 50)
	settings_ui.size = Vector2(1140, 540)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.19, 0.98)
	sb.set_corner_radius_all(12)
	settings_ui.add_theme_stylebox_override("panel", sb)
	hud_root.add_child(settings_ui)
	_mk_label(settings_ui, "PENGATURAN", Vector2(24, 12), Vector2(500, 40), 26)
	_mk_button(settings_ui, "TUTUP", Vector2(900, 10), _close_settings)
	SettingsPanel.fill(settings_ui, _open_ui_editor)


func _close_settings() -> void:
	if settings_ui != null:
		settings_ui.queue_free()
		settings_ui = null
	_apply_quality()
	if touch != null:
		touch.reload_layout()
	panel.visible = true


func _open_ui_editor() -> void:
	if settings_ui != null:
		settings_ui.queue_free()
		settings_ui = null
	var ed := UiEditor.new()
	ed.process_mode = Node.PROCESS_MODE_ALWAYS
	ed.closed.connect(_on_editor_closed)
	hud_root.add_child(ed)


func _on_editor_closed() -> void:
	if touch != null:
		touch.reload_layout()
	_open_settings()
