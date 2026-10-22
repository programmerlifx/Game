extends RefCounted
# Isi menu Pengaturan (dipakai di lobi dan di menu jeda dalam game).
# Semua nilai tersimpan langsung ke Profile.data.settings, sehingga langsung berlaku.

const ORANGE := Color(1.0, 0.55, 0.1)

static var _grabber: ImageTexture = null


# host = Panel/Control tempat menaruh kontrol. Butuh area minimal 1100 x 470 (mulai dari y = 64).
# on_edit_ui = fungsi yang dipanggil saat tombol "ATUR TAMPILAN TOMBOL" ditekan.
static func fill(host: Control, on_edit_ui: Callable) -> void:
	var lx: float = 30.0
	var rx: float = 570.0
	_title(host, "KAMERA & BIDIK", Vector2(lx, 62))
	_slider_row(host, "Sensitivitas kamera (umum)", "sens", Vector2(lx, 96), 480.0, 0.3, 3.0, 0.1, 1.0, "x%.1f")
	_slider_row(host, "Sensitivitas saat zoom / membidik", "sens_ads", Vector2(lx, 170), 480.0, 0.2, 2.0, 0.05, 0.7, "x%.2f")
	_slider_row(host, "Sensitivitas vertikal (atas-bawah)", "sens_v", Vector2(lx, 244), 480.0, 0.3, 1.5, 0.05, 1.0, "x%.2f")
	_check_row(host, "Balik sumbu Y (invert)", "invert_y", Vector2(lx, 322), false)
	_label(host, "Kontrol sentuh (joystick di layar)", Vector2(lx, 380), Vector2(480, 26), 18, Color.WHITE)
	_option_row(host, "touch", Vector2(lx, 412), Vector2(480, 46), ["Otomatis (aktif di HP/tablet)", "Selalu nyala", "Mati (keyboard + mouse)"], 0)

	_title(host, "TAMPILAN & GRAFIS", Vector2(rx, 62))
	_slider_row(host, "Transparansi tombol layar", "ui_alpha", Vector2(rx, 96), 480.0, 0.15, 1.0, 0.05, 0.55, "%.2f")
	_check_row(host, "Joystick melayang (muncul di tempat jari)", "float_stick", Vector2(rx, 176), false)
	_label(host, "Kualitas grafis", Vector2(rx, 232), Vector2(480, 26), 18, Color.WHITE)
	_option_row(host, "quality", Vector2(rx, 264), Vector2(480, 46), ["Rendah (hemat baterai / HP kentang)", "Sedang (bayangan + anti-pecah)", "Tinggi (bayangan jauh + MSAA 4x)"], 1)
	var b := Button.new()
	b.text = "ATUR TAMPILAN TOMBOL (CUSTOM UI)"
	b.position = Vector2(rx, 340)
	b.size = Vector2(480, 62)
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(on_edit_ui)
	host.add_child(b)
	_label(host, "Geser tombol ke posisi nyaman, ubah ukuran,\nlalu tekan SELESAI. Tombol LARI = lari (toggle).", Vector2(rx, 410), Vector2(480, 56), 15, Color(0.7, 0.72, 0.78))


static func _title(host: Control, text: String, p: Vector2) -> void:
	_label(host, text, p, Vector2(480, 28), 17, ORANGE)


static func _label(host: Control, text: String, p: Vector2, s: Vector2, font: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = p
	l.size = s
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", col)
	host.add_child(l)
	return l


static func _make_grabber() -> ImageTexture:
	if _grabber != null:
		return _grabber
	var d: int = 36
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d * 0.5, d * 0.5)
	for y in d:
		for x in d:
			var dist: float = Vector2(x + 0.5, y + 0.5).distance_to(c)
			if dist <= d * 0.5 - 1.5:
				img.set_pixel(x, y, ORANGE)
			elif dist <= d * 0.5:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.9))
	_grabber = ImageTexture.create_from_image(img)
	return _grabber


static func _slider_row(host: Control, title: String, key: String, p: Vector2, w: float, lo: float, hi: float, step: float, def: float, fmt: String) -> void:
	_label(host, title, p, Vector2(w, 26), 18, Color.WHITE)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = float(Profile.data.settings.get(key, def))
	sl.position = p + Vector2(0, 32)
	sl.size = Vector2(w - 90.0, 36)
	var g: ImageTexture = _make_grabber()
	sl.add_theme_icon_override("grabber", g)
	sl.add_theme_icon_override("grabber_highlight", g)
	sl.add_theme_icon_override("grabber_disabled", g)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.25, 0.28, 0.36)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4.0
	track.content_margin_bottom = 4.0
	sl.add_theme_stylebox_override("slider", track)
	host.add_child(sl)
	var vl := _label(host, fmt % sl.value, p + Vector2(w - 80.0, 32), Vector2(80, 32), 20, ORANGE)
	sl.value_changed.connect(_on_slider.bind(key, vl, fmt))


static func _on_slider(v: float, key: String, vl: Label, fmt: String) -> void:
	Profile.data.settings[key] = v
	vl.text = fmt % v
	Profile.save()


static func _check_row(host: Control, title: String, key: String, p: Vector2, def: bool) -> void:
	var cb := CheckButton.new()
	cb.text = title
	cb.button_pressed = bool(Profile.data.settings.get(key, def))
	cb.position = p
	cb.size = Vector2(500, 44)
	cb.add_theme_font_size_override("font_size", 18)
	cb.toggled.connect(_on_check.bind(key))
	host.add_child(cb)


static func _on_check(on: bool, key: String) -> void:
	Profile.data.settings[key] = on
	Profile.save()


static func _option_row(host: Control, key: String, p: Vector2, s: Vector2, items: Array, def: int) -> void:
	var ob := OptionButton.new()
	for it in items:
		ob.add_item(String(it))
	ob.selected = clampi(int(Profile.data.settings.get(key, def)), 0, items.size() - 1)
	ob.position = p
	ob.size = s
	ob.add_theme_font_size_override("font_size", 17)
	ob.item_selected.connect(_on_option.bind(key))
	host.add_child(ob)


static func _on_option(i: int, key: String) -> void:
	Profile.data.settings[key] = i
	Profile.save()
