extends RefCounted
# Animasi prosedural untuk rig Character Creator (tulang "CC_Base_*"):
# idle, jalan/lari, melompat, dan pose membidik. Model GLB tidak punya animasi bawaan,
# jadi tulang digerakkan lewat kode setiap frame.

const PREFIX := {
	"l_thigh": "CC_Base_L_Thigh", "l_calf": "CC_Base_L_Calf", "l_foot": "CC_Base_L_Foot",
	"r_thigh": "CC_Base_R_Thigh", "r_calf": "CC_Base_R_Calf", "r_foot": "CC_Base_R_Foot",
	"l_up": "CC_Base_L_Upperarm", "l_fore": "CC_Base_L_Forearm",
	"r_up": "CC_Base_R_Upperarm", "r_fore": "CC_Base_R_Forearm",
	"spine": "CC_Base_Spine02",
}
# Model berpose A: lengan perlu diturunkan sebesar ini (radian) agar menggantung.
# Jika lengan terlihat terlalu miring, ubah nilai ini.
const ARM_DOWN := 0.9
const AIM_YAW := 1.45

var skel: Skeleton3D
var bones: Dictionary = {}
var phase: float = 0.0
var move_w: float = 0.0
var aim_w: float = 0.0
var air_w: float = 0.0
var t: float = 0.0


func setup(root: Node) -> bool:
	skel = _find_skel(root)
	if skel == null:
		return false
	for key in PREFIX.keys():
		var idx: int = _find_bone(String(PREFIX[key]))
		if idx < 0:
			continue
		var p: int = skel.get_bone_parent(idx)
		var gp := Basis.IDENTITY
		if p >= 0:
			gp = skel.get_bone_global_rest(p).basis.orthonormalized()
		var rq: Quaternion = skel.get_bone_rest(idx).basis.orthonormalized().get_rotation_quaternion()
		bones[key] = [idx, gp.inverse(), gp, rq]
	return not bones.is_empty()


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var r: Skeleton3D = _find_skel(c)
		if r != null:
			return r
	return null


func _find_bone(prefix: String) -> int:
	for i in skel.get_bone_count():
		var n: String = skel.get_bone_name(i)
		if n.begins_with(prefix) and not n.contains("Twist") and not n.contains("scaleCompensation") and not n.contains("Share"):
			return i
	return -1


# rot = rotasi dalam sumbu model (X = kanan/kiri, Y = atas, Z = depan), relatif terhadap pose istirahat.
func _apply(key: String, rot: Basis) -> void:
	if not bones.has(key):
		return
	var b: Array = bones[key]
	var gp_inv: Basis = b[1]
	var gp: Basis = b[2]
	var rest_q: Quaternion = b[3]
	var q: Quaternion = (gp_inv * rot * gp).get_rotation_quaternion() * rest_q
	skel.set_bone_pose_rotation(int(b[0]), q)


func update(delta: float, speed: float, on_floor: bool, aiming: bool) -> void:
	if bones.is_empty():
		return
	t += delta
	move_w = lerpf(move_w, clampf(speed / 2.5, 0.0, 1.0), minf(1.0, 10.0 * delta))
	aim_w = lerpf(aim_w, 1.0 if aiming else 0.0, minf(1.0, 12.0 * delta))
	air_w = lerpf(air_w, 0.0 if on_floor else 1.0, minf(1.0, 10.0 * delta))
	phase += delta * (2.0 + speed * 1.9)

	var amp: float = move_w * clampf(0.7 + speed / 14.0, 0.7, 1.15)
	var s: float = sin(phase)
	var c: float = cos(phase)

	# --- kaki (negatif = maju, positif = mundur)
	var l_sw: float = -s * 0.55 * amp
	var r_sw: float = s * 0.55 * amp
	var l_kn: float = maxf(0.0, c) * 0.95 * amp
	var r_kn: float = maxf(0.0, -c) * 0.95 * amp
	l_sw = lerpf(l_sw, -0.5, air_w)
	r_sw = lerpf(r_sw, 0.25, air_w)
	l_kn = lerpf(l_kn, 0.9, air_w)
	r_kn = lerpf(r_kn, 0.5, air_w)
	_apply("l_thigh", Basis(Vector3.RIGHT, l_sw))
	_apply("l_calf", Basis(Vector3.RIGHT, l_kn))
	_apply("l_foot", Basis(Vector3.RIGHT, -(l_sw + l_kn) * 0.6))
	_apply("r_thigh", Basis(Vector3.RIGHT, r_sw))
	_apply("r_calf", Basis(Vector3.RIGHT, r_kn))
	_apply("r_foot", Basis(Vector3.RIGHT, -(r_sw + r_kn) * 0.6))

	# --- lengan: turun + berayun, atau terangkat ke depan saat membidik
	var arm_sw: float = 0.45 * amp * (1.0 - air_w)
	var l_walk := Basis(Vector3.RIGHT, s * arm_sw) * Basis(Vector3.BACK, -ARM_DOWN)
	var r_walk := Basis(Vector3.RIGHT, -s * arm_sw) * Basis(Vector3.BACK, ARM_DOWN)
	var l_aim := Basis(Vector3.UP, -AIM_YAW)
	var r_aim := Basis(Vector3.UP, AIM_YAW)
	_apply("l_up", Basis(Quaternion(l_walk).slerp(Quaternion(l_aim), aim_w)))
	_apply("r_up", Basis(Quaternion(r_walk).slerp(Quaternion(r_aim), aim_w)))

	var fl: float = 0.3 + 0.25 * amp
	var l_fw := Basis(Vector3.UP, -fl)
	var r_fw := Basis(Vector3.UP, fl)
	var l_fa := Basis(Vector3.UP, -0.6)
	var r_fa := Basis(Vector3.UP, 0.6)
	_apply("l_fore", Basis(Quaternion(l_fw).slerp(Quaternion(l_fa), aim_w)))
	_apply("r_fore", Basis(Quaternion(r_fw).slerp(Quaternion(r_fa), aim_w)))

	_apply("spine", Basis(Vector3.RIGHT, sin(t * 2.0) * 0.015))
