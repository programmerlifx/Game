extends Control
# Editor tampilan tombol layar sentuh: seret tombol untuk memindahkan, slider untuk ukuran,
# slider transparansi, dan tombol reset. Hasil tersimpan otomatis di profil.

const HudLayout = preload("res://scripts/hud_layout.gd")

signal closed

var sel: String = "fire"
var dragging: bool = false
var drag_off: Vector2 = Vector2.ZERO
var bar: Panel
var lbl_sel: Label
var lbl_size: Label
var lbl_alpha: Label
var size_slider: HSlider
var alpha_slider: HSlider


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	bar = Panel.new()
	bar.position = Vector2(190, 8)
	bar.size = Vector2(900, 124)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.19, 0.97)
	sb.set_corner_radius_all(12)
	bar.add_theme_stylebox_override("panel", sb)
	add_child(bar)

	_label(bar, "ATUR TAMPILAN TOMBOL  -  seret tombol untuk memindahkan", Vector2(16, 6), Vector2(868, 26), 19, Color(1.0, 0.55, 0.1))
	lbl_sel = _label(bar, "", Vector2(16, 40), Vector2(300, 24), 17, Color.WHITE)
	size_slider = _slider(Vector2(16, 70), 0.5, 2.0, 0.05, _on_size)
	lbl_size = _label(bar, "", Vector2(226, 66), Vector2(70, 26), 17, Color(1.0, 0.55, 0.1))
	_label(bar, "Transparansi tombol", Vector2(340, 40), Vector2(260, 24), 17, Color.WHITE)
	alpha_slider = _slider(Vector2(340, 70), 0.15, 1.0, 0.05, _on_alpha)
	alpha_slider.set_value_no_signal(HudLayout.alpha())
	lbl_alpha = _label(bar, "", Vector2(550, 66), Vector2(70, 26), 17, Color(1.0, 0.55, 0.1))
	lbl_alpha.text = "%d%%" % int(HudLayout.alpha() * 100.0)

	var b1 := Button.new()
	b1.text = "RESET"
	b1.position = Vector2(650, 44)
	b1.size = Vector2(110, 54)
	b1.pressed.connect(_on_reset)
	bar.add_child(b1)
	var b2 := Button.new()
	b2.text = "SELESAI"
	b2.position = Vector2(772, 44)
	b2.size = Vector2(112, 54)
	b2.pressed.connect(_on_done)
	bar.add_child(b2)

	_select("fire")


func _label(parent: Node, text: String, p: Vector2, s: Vector2, font: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = p
	l.size = s
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _slider(p: Vector2, lo: float, hi: float, step: float, cb: Callable) -> HSlider:
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.position = p
	sl.size = Vector2(200, 30)
	sl.value_changed.connect(cb)
	bar.add_child(sl)
	return sl


func _select(k: String) -> void:
	sel = k
	var sc: float = HudLayout.scale_of(k)
	lbl_sel.text = "Dipilih: %s" % HudLayout.label(k)
	size_slider.set_value_no_signal(sc)
	lbl_size.text = "%d%%" % int(sc * 100.0)
	queue_redraw()


func _pick(p: Vector2) -> String:
	var best: String = ""
	var best_d: float = 1e9
	for k in HudLayout.ALL:
		var d: float = p.distance_to(HudLayout.pos(String(k)))
		if d <= HudLayout.radius(String(k)) * 1.15 and d < best_d:
			best = String(k)
			best_d = d
	return best


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hit: String = _pick(event.position)
			if hit != "":
				_select(hit)
				dragging = true
				drag_off = HudLayout.pos(hit) - event.position
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		var p: Vector2 = event.position + drag_off
		p.x = clampf(p.x, 20.0, 1260.0)
		p.y = clampf(p.y, 20.0, 700.0)
		HudLayout.set_pos(sel, p)
		queue_redraw()


func _on_size(v: float) -> void:
	HudLayout.set_scale(sel, v)
	lbl_size.text = "%d%%" % int(v * 100.0)
	queue_redraw()


func _on_alpha(v: float) -> void:
	Profile.data.settings["ui_alpha"] = v
	lbl_alpha.text = "%d%%" % int(v * 100.0)
	queue_redraw()


func _on_reset() -> void:
	HudLayout.reset()
	alpha_slider.set_value_no_signal(HudLayout.alpha())
	_select(sel)


func _on_done() -> void:
	Profile.save()
	closed.emit()
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.06, 0.1, 0.94))
	var a: float = HudLayout.alpha()
	# garis bantu tengah layar
	draw_line(Vector2(640, 0), Vector2(640, 720), Color(1, 1, 1, 0.05), 1.0)
	draw_line(Vector2(0, 360), Vector2(1280, 360), Color(1, 1, 1, 0.05), 1.0)
	HudLayout.draw_stick(self, HudLayout.pos("stick"), HudLayout.radius("stick"), Vector2.ZERO, a, sel == "stick")
	for k in HudLayout.BUTTONS:
		HudLayout.draw_button(self, String(k), a, false, sel == k)
