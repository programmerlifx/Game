extends RefCounted
# Utilitas memuat model GLB: skala otomatis ke tinggi tertentu, kaki di y=0,
# dan putar agar menghadap -Z (arah depan Godot).

static func make_model(path: String, height: float = 1.8, yaw_offset: float = PI) -> Node3D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res = load(path)
	if res == null or not (res is PackedScene):
		return null
	var inst: Node3D = (res as PackedScene).instantiate() as Node3D
	if inst == null:
		return null
	var holder := Node3D.new()
	holder.add_child(inst)
	var boxes: Array = []
	_collect(inst, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		return holder
	var box: AABB = boxes[0]
	for i in range(1, boxes.size()):
		box = box.merge(boxes[i])
	if box.size.y > 0.0001:
		var s: float = height / box.size.y
		inst.scale = Vector3(s, s, s)
		var c := box.get_center()
		inst.position = Vector3(-c.x * s, -box.position.y * s, -c.z * s)
	holder.rotation.y = yaw_offset
	return holder


static func _collect(node: Node, xf: Transform3D, out: Array) -> void:
	for ch in node.get_children():
		var t: Transform3D = xf
		var n3 := ch as Node3D
		if n3 != null:
			t = xf * n3.transform
		var mi := ch as MeshInstance3D
		if mi != null and mi.mesh != null:
			out.append(t * mi.mesh.get_aabb())
		_collect(ch, t, out)


static func tint(root: Node, color: Color) -> void:
	if root == null or color.a <= 0.01:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_apply(root, mat)


static func _apply(node: Node, mat: Material) -> void:
	for ch in node.get_children():
		var mi := ch as MeshInstance3D
		if mi != null:
			mi.material_overlay = mat
		_apply(ch, mat)
