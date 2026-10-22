extends RefCounted
# Memuat model senjata dari assets/weapons/gun_pack.glb (5 senjata dalam satu file).
# Di file itu senjata "berbaring": laras sepanjang sumbu X, atas senjata = -Z, sisi = Y.
# Kode ini memisahkan tiap senjata, membuang peluru, memutar agar laras menghadap -Z (depan Godot),
# lalu mengatur titik pegang (grip) di dekat magasin sebagai titik pusat (0,0,0).

const PACK := "res://assets/weapons/gun_pack.glb"

# id senjata (GameData.WEAPONS) -> nama node di GLB + panjang senjata (meter)
const DEFS := {
	"pistol": {"node": "FN_Five_Seven", "len": 0.21},
	"smg": {"node": "HK_MP5", "len": 0.70},
	"ar": {"node": "M16A1", "len": 0.99},
	"ak47": {"node": "Ak47", "len": 0.88},
	"sniper": {"node": "Barrett_M82A1", "len": 1.35},
}

static var _protos: Dictionary = {}
static var _info: Dictionary = {}


# Mengembalikan Node3D baru (laras ke -Z, titik pegang di origin). null jika gagal.
# Meta: "muzzle_z" (posisi moncong), "rear_z" (ujung belakang/popor).
static func make(id: String) -> Node3D:
	if not DEFS.has(id):
		return null
	if not _protos.has(id):
		_protos[id] = _build(id)
	var proto = _protos[id]
	if proto == null:
		return null
	var n: Node3D = (proto as Node3D).duplicate() as Node3D
	var inf: Dictionary = _info[id]
	n.set_meta("muzzle_z", float(inf.muzzle_z))
	n.set_meta("rear_z", float(inf.rear_z))
	return n


static func _build(id: String):
	if not ResourceLoader.exists(PACK):
		return null
	var res = load(PACK)
	if res == null or not (res is PackedScene):
		return null
	var inst: Node = (res as PackedScene).instantiate()
	if inst == null:
		return null
	var d: Dictionary = DEFS[id]
	var grp: Node3D = inst.find_child(String(d.node), true, false) as Node3D
	if grp == null:
		inst.free()
		return null
	grp.get_parent().remove_child(grp)
	inst.free()

	var body_boxes: Array = []
	var mag_boxes: Array = []
	var all_boxes: Array = []
	for ch in grp.get_children():
		var nm: String = String(ch.name).to_lower()
		if nm.contains("bullet"):
			grp.remove_child(ch)
			ch.free()
			continue
		var xf: Transform3D = Transform3D.IDENTITY
		var c3 := ch as Node3D
		if c3 != null:
			xf = c3.transform
		var tmp: Array = []
		_bounds(ch, xf, tmp)
		if nm.contains("magazine"):
			mag_boxes.append_array(tmp)
		else:
			body_boxes.append_array(tmp)
		all_boxes.append_array(tmp)
	if all_boxes.is_empty():
		grp.free()
		return null

	# Putar: x_model -> -Z (laras), y_model -> +X (sisi), z_model -> -Y (z_model negatif = atas)
	var rot: Basis = Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0))
	var tf := Transform3D(rot, Vector3.ZERO)
	var all_b: AABB = _merge(all_boxes, tf)
	var body_b: AABB = all_b
	if not body_boxes.is_empty():
		body_b = _merge(body_boxes, tf)
	var mag_b: AABB = body_b
	if not mag_boxes.is_empty():
		mag_b = _merge(mag_boxes, tf)

	var s: float = float(d.len) / maxf(all_b.size.z, 0.0001)
	# titik pegang: sedikit di belakang magasin, setinggi garis laras
	var pz: float = mag_b.get_center().z + all_b.size.z * 0.03
	var pivot := Vector3(body_b.get_center().x, body_b.get_center().y, pz)
	grp.transform = Transform3D(rot.scaled(Vector3.ONE * s), -(pivot * s))
	_tune(grp)

	var holder := Node3D.new()
	holder.name = "Gun"
	holder.add_child(grp)
	_info[id] = {
		"muzzle_z": (all_b.position.z - pivot.z) * s,
		"rear_z": (all_b.end.z - pivot.z) * s,
	}
	return holder


static func _bounds(node: Node, xf: Transform3D, out: Array) -> void:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		out.append(xf * mi.mesh.get_aabb())
	for ch in node.get_children():
		var t: Transform3D = xf
		var n3 := ch as Node3D
		if n3 != null:
			t = xf * n3.transform
		_bounds(ch, t, out)


static func _merge(arr: Array, tf: Transform3D) -> AABB:
	var b: AABB = tf * (arr[0] as AABB)
	for i in range(1, arr.size()):
		b = b.merge(tf * (arr[i] as AABB))
	return b


# Material bawaan model terlalu mengkilap (roughness 0): buat lebih mirip logam bertekstur.
static func _tune(node: Node) -> void:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		for i in mi.mesh.get_surface_count():
			var m = mi.mesh.surface_get_material(i)
			if m is BaseMaterial3D:
				var m2: BaseMaterial3D = (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				m2.roughness = 0.55
				m2.metallic = 0.25
				mi.set_surface_override_material(i, m2)
	for ch in node.get_children():
		_tune(ch)
