extends Control
# Kontrol sentuh: joystick kiri (tetap/melayang), geser area bebas untuk memutar kamera, tombol aksi.
# Posisi & ukuran tombol dibaca dari HudLayout (bisa diubah di Pengaturan > Atur Tampilan Tombol).
# Semua digambar & dideteksi manual (tanpa node Button) agar multi-touch lancar.

const HudLayout = preload("res://scripts/hud_layout.gd")

var move: Vector2 = Vector2.ZERO
var look: Vector2 = Vector2.ZERO
var fire: bool = false
var aim: bool = false
var crouch: bool = false
var sprint: bool = false
var _flags: Dictionary = {}
var _touches: Dictionary = {}

var stick_c: Vector2 = Vector2(170, 540)
var stick_r: float = 95.0
var stick_active: bool = false
var float_stick: bool = false
var alpha: float = 0.55


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	reload_layout()


func reload_layout() -> void:
	stick_r = HudLayout.radius("stick")
	float_stick = HudLayout.floating()
	alpha = HudLayout.alpha()
	if not stick_active:
		stick_c = HudLayout.pos("stick")
	queue_redraw()


func consume(flag: String) -> bool:
	if _flags.get(flag, false):
		_flags[flag] = false
		return true
	return false


func _role_at(pos: Vector2) -> String:
	for k in HudLayout.BUTTONS:
		if pos.distance_to(HudLayout.pos(k)) <= HudLayout.radius(k) * 1.15:
			return String(k)
	if float_stick:
		if pos.x < 560.0 and pos.y > 200.0:
			return "stick"
	elif pos.distance_to(HudLayout.pos("stick")) <= stick_r * 2.2:
		return "stick"
	return "look"


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			var role_down: String = _role_at(e.position)
			_touches[e.index] = role_down
			_press(role_down, e.position)
		else:
			var role_up: String = String(_touches.get(e.index, ""))
			_release(role_up)
			_touches.erase(e.index)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		var role: String = String(_touches.get(d.index, ""))
		if role == "stick":
			_stick(d.position)
			queue_redraw()
		elif role == "look":
			look += d.relative


func _press(role: String, pos: Vector2) -> void:
	match role:
		"stick":
			stick_active = true
			if float_stick:
				stick_c = Vector2(clampf(pos.x, stick_r, 1280.0 - stick_r), clampf(pos.y, 200.0, 720.0 - stick_r))
			else:
				stick_c = HudLayout.pos("stick")
			_stick(pos)
		"fire":
			fire = true
		"aim":
			aim = true
		"crouch":
			crouch = not crouch
		"sprint":
			sprint = not sprint
		"jump", "reload", "ability", "swap", "pause":
			_flags[role] = true


func _release(role: String) -> void:
	match role:
		"stick":
			stick_active = false
			move = Vector2.ZERO
			sprint = false
			stick_c = HudLayout.pos("stick")
		"fire":
			fire = false
		"aim":
			aim = false


func _stick(pos: Vector2) -> void:
	var v: Vector2 = (pos - stick_c) / stick_r
	if v.length() > 1.0:
		v = v.normalized()
	if v.length() < 0.12:
		v = Vector2.ZERO
	move = v


func _draw() -> void:
	var a: float = alpha
	var c: Vector2 = stick_c
	if float_stick and not stick_active:
		c = HudLayout.pos("stick")
		a *= 0.5
	HudLayout.draw_stick(self, c, stick_r, move, a)
	for k in HudLayout.BUTTONS:
		var on: bool = (k == "fire" and fire) or (k == "aim" and aim) or (k == "crouch" and crouch) or (k == "sprint" and sprint)
		HudLayout.draw_button(self, String(k), alpha, on)
