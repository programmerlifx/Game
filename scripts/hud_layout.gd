extends RefCounted
# Tata letak kontrol sentuh yang bisa diatur pemain (posisi + ukuran tiap tombol),
# disimpan di Profile.data.settings.ui. Dipakai touch_controls.gd dan ui_editor.gd.

# nama: [posisi bawaan, radius bawaan, label]  (layar 1280 x 720)
const DEFS := {
	"stick": [Vector2(170, 540), 95.0, "STICK"],
	"fire": [Vector2(1150, 540), 66.0, "TEMBAK"],
	"jump": [Vector2(1020, 625), 44.0, "LOMPAT"],
	"aim": [Vector2(1035, 470), 38.0, "ZOOM"],
	"reload": [Vector2(1195, 410), 32.0, "RELOAD"],
	"ability": [Vector2(1100, 385), 34.0, "SKILL"],
	"crouch": [Vector2(910, 640), 32.0, "JONGKOK"],
	"swap": [Vector2(1210, 310), 30.0, "GANTI"],
	"pause": [Vector2(1236, 225), 22.0, "II"],
	"sprint": [Vector2(370, 625), 34.0, "LARI"],
}
const BUTTONS := ["fire", "jump", "aim", "reload", "ability", "crouch", "swap", "pause", "sprint"]
const ALL := ["stick", "fire", "jump", "aim", "reload", "ability", "crouch", "swap", "pause", "sprint"]


static func _ui() -> Dictionary:
	var st: Dictionary = Profile.data.settings
	var u = st.get("ui", null)
	if not (u is Dictionary):
		u = {}
		st["ui"] = u
	return u


static func label(k: String) -> String:
	var d: Array = DEFS[k]
	return String(d[2])


static func pos(k: String) -> Vector2:
	var u: Dictionary = _ui()
	if u.has(k):
		var a = u[k]
		if a is Array and a.size() >= 2:
			return Vector2(clampf(float(a[0]), 0.0, 1280.0), clampf(float(a[1]), 0.0, 720.0))
	var d: Array = DEFS[k]
	var v: Vector2 = d[0]
	return v


static func scale_of(k: String) -> float:
	var u: Dictionary = _ui()
	if u.has(k):
		var a = u[k]
		if a is Array and a.size() >= 3:
			return clampf(float(a[2]), 0.5, 2.0)
	return 1.0


static func radius(k: String) -> float:
	var d: Array = DEFS[k]
	return float(d[1]) * scale_of(k)


static func set_item(k: String, p: Vector2, sc: float) -> void:
	var u: Dictionary = _ui()
	u[k] = [p.x, p.y, sc]


static func set_pos(k: String, p: Vector2) -> void:
	set_item(k, p, scale_of(k))


static func set_scale(k: String, sc: float) -> void:
	set_item(k, pos(k), sc)


static func reset() -> void:
	Profile.data.settings["ui"] = {}
	Profile.save()


static func alpha() -> float:
	return clampf(float(Profile.data.settings.get("ui_alpha", 0.55)), 0.15, 1.0)


static func floating() -> bool:
	return bool(Profile.data.settings.get("float_stick", false))


# ---- Gambar (dipanggil dari _draw milik Control pemanggil)
static func draw_stick(c: CanvasItem, center: Vector2, r: float, knob: Vector2, a: float, selected: bool = false) -> void:
	c.draw_circle(center, r, Color(1, 1, 1, a * 0.3))
	c.draw_arc(center, r, 0.0, TAU, 48, Color(1, 1, 1, minf(1.0, a + 0.2)), 3.0)
	c.draw_circle(center + knob * r * 0.7, r * 0.4, Color(1, 1, 1, minf(1.0, a + 0.1)))
	if selected:
		c.draw_arc(center, r + 7.0, 0.0, TAU, 48, Color(0.3, 1.0, 0.5, 1.0), 4.0)


static func draw_button(c: CanvasItem, k: String, a: float, on: bool, selected: bool = false) -> void:
	var p: Vector2 = pos(k)
	var r: float = radius(k)
	var col := Color(1.0, 0.55, 0.1, a) if k == "fire" else Color(1, 1, 1, a * 0.4)
	if on:
		col = Color(1.0, 0.8, 0.2, minf(1.0, a + 0.15))
	c.draw_circle(p, r, col)
	c.draw_arc(p, r, 0.0, TAU, 40, Color(1, 1, 1, minf(1.0, a + 0.2)), 2.0)
	if selected:
		c.draw_arc(p, r + 7.0, 0.0, TAU, 40, Color(0.3, 1.0, 0.5, 1.0), 4.0)
	var fs: int = int(clampf(r * 0.34, 11.0, 22.0))
	var font: Font = ThemeDB.fallback_font
	c.draw_string(font, p + Vector2(-r, fs * 0.35), label(k), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color.WHITE)
