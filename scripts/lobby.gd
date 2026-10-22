extends Control
# Lobi ala Free Fire: karakter 3D di tengah, profil, mode, misi, peringkat, pengaturan.

const ModelUtil = preload("res://scripts/model_util.gd")
const CharAnim = preload("res://scripts/character_anim.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const UiEditor = preload("res://scripts/ui_editor.gd")
const MODEL_PATH := "res://assets/characters/hero.glb"
const ORANGE := Color(1.0, 0.55, 0.1)
const PANEL := Color(0.08, 0.1, 0.16, 0.9)
const GREY := Color(0.2, 0.23, 0.3)
const AVATARS := [Color(1.0, 0.55, 0.1), Color(0.25, 0.7, 1.0), Color(0.3, 0.85, 0.45), Color(0.8, 0.4, 0.95), Color(0.95, 0.3, 0.3), Color(0.95, 0.85, 0.25)]

var pivot: Node3D
var anim
var drag_yaw: float = 0.0
var t: float = 0.0
var popup: Control = null
var mode_btns: Dictionary = {}
var avatar: Panel
var avatar_letter: Label
var lbl_name: Label
var lbl_level: Label
var lbl_rank_small: Label
var lbl_uid: Label
var bar_xp: ProgressBar
var lbl_gold: Label
var lbl_dia: Label
var lbl_mode_name: Label
var lbl_mode_desc: Label
var lbl_mode_meta: Label
var lbl_rank: Label
var lbl_rp: Label
var bar_rank: ProgressBar
var daily_btn: Button
var lbl_sens: Label
var reset_btn: Button
var reset_armed: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	Profile.ensure_daily()
	if not GameData.MODES.has(str(Profile.data.mode)):
		Profile.data.mode = "br"
	_build_bg()
	_build_3d()
	_build_top()
	_build_left()
	_build_right()
	_build_bottom()
	_refresh()


func _process(delta: float) -> void:
	t += delta
	if pivot != null:
		pivot.rotation.y = drag_yaw + sin(t * 0.5) * 0.3
	if anim != null:
		anim.update(delta, 0.0, true, false)


# ------------------------------------------------------------ Helper UI
func _sb(col: Color, radius: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	return s


func _panel(parent: Node, pos: Vector2, sz: Vector2, col: Color = PANEL, radius: int = 12) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = sz
	p.add_theme_stylebox_override("panel", _sb(col, radius))
	parent.add_child(p)
	return p


func _lbl(parent: Node, text: String, pos: Vector2, sz: Vector2, font: int = 16, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _btn(parent: Node, text: String, pos: Vector2, sz: Vector2, col: Color, cb: Callable, font: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", font)
	b.add_theme_stylebox_override("normal", _sb(col, 10))
	b.add_theme_stylebox_override("hover", _sb(col.lightened(0.15), 10))
	b.add_theme_stylebox_override("pressed", _sb(col.darkened(0.2), 10))
	b.add_theme_stylebox_override("disabled", _sb(Color(0.25, 0.27, 0.32), 10))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _bar(parent: Node, pos: Vector2, sz: Vector2, col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = pos
	b.size = sz
	b.show_percentage = false
	b.max_value = 100.0
	b.add_theme_stylebox_override("fill", _sb(col, 6))
	b.add_theme_stylebox_override("background", _sb(Color(0, 0, 0, 0.45), 6))
	parent.add_child(b)
	return b


# ------------------------------------------------------------ Bangun layar
func _build_bg() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var p1 := Polygon2D.new()
	p1.polygon = PackedVector2Array([Vector2(0, 720), Vector2(0, 360), Vector2(560, 720)])
	p1.color = Color(1.0, 0.5, 0.1, 0.18)
	add_child(p1)
	var p2 := Polygon2D.new()
	p2.polygon = PackedVector2Array([Vector2(1280, 0), Vector2(1280, 340), Vector2(800, 0)])
	p2.color = Color(0.2, 0.5, 1.0, 0.16)
	add_child(p2)


func _build_3d() -> void:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.position = Vector2(300, 80)
	svc.size = Vector2(680, 560)
	svc.gui_input.connect(_on_view_input)
	add_child(svc)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(680, 560)
	vp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.9)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var cam := Camera3D.new()
	cam.fov = 32.0
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.0, 4.2), Vector3(0, 0.95, 0))
	cam.current = true

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25.0, 25.0, 0.0)
	sun.light_energy = 1.2
	root.add_child(sun)

	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.95
	cm.bottom_radius = 0.95
	cm.height = 0.05
	disc.mesh = cm
	disc.position.y = -0.025
	var dm := StandardMaterial3D.new()
	dm.albedo_color = ORANGE
	dm.emission_enabled = true
	dm.emission = ORANGE
	dm.emission_energy_multiplier = 0.8
	disc.material_override = dm
	root.add_child(disc)

	pivot = Node3D.new()
	root.add_child(pivot)
	var model: Node3D = ModelUtil.make_model(MODEL_PATH, 1.8, 0.0)
	if model != null:
		pivot.add_child(model)
		anim = CharAnim.new()
		anim.setup(model)
	else:
		var warn := _lbl(self, "Model hero.glb belum ter-import. Buka project di Godot dulu.", Vector2(320, 340), Vector2(640, 60), 18, HORIZONTAL_ALIGNMENT_CENTER)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		drag_yaw += event.relative.x * 0.01


func _build_top() -> void:
	var card := _panel(self, Vector2(16, 12), Vector2(400, 98))
	avatar = _panel(card, Vector2(14, 15), Vector2(68, 68), AVATARS[0], 34)
	avatar_letter = _lbl(avatar, "P", Vector2(0, 10), Vector2(68, 50), 34, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_name = _lbl(card, "", Vector2(96, 6), Vector2(290, 30), 24)
	lbl_level = _lbl(card, "", Vector2(96, 36), Vector2(90, 24), 17, HORIZONTAL_ALIGNMENT_LEFT, ORANGE)
	lbl_rank_small = _lbl(card, "", Vector2(190, 36), Vector2(190, 24), 17, HORIZONTAL_ALIGNMENT_LEFT, Color(0.6, 0.85, 1.0))
	bar_xp = _bar(card, Vector2(96, 64), Vector2(280, 12), Color(0.3, 0.8, 1.0))
	lbl_uid = _lbl(card, "", Vector2(96, 76), Vector2(280, 20), 12, HORIZONTAL_ALIGNMENT_LEFT, Color(0.7, 0.7, 0.75))
	var hit := Button.new()
	hit.flat = true
	hit.position = card.position
	hit.size = card.size
	hit.pressed.connect(_show_profile)
	add_child(hit)

	var gp := _panel(self, Vector2(870, 14), Vector2(190, 42), PANEL, 21)
	_lbl(gp, "KOIN", Vector2(16, 9), Vector2(60, 24), 14, HORIZONTAL_ALIGNMENT_LEFT, Color(1.0, 0.85, 0.3))
	lbl_gold = _lbl(gp, "", Vector2(70, 6), Vector2(110, 30), 20, HORIZONTAL_ALIGNMENT_RIGHT)
	var dp := _panel(self, Vector2(1074, 14), Vector2(190, 42), PANEL, 21)
	_lbl(dp, "DIAMOND", Vector2(16, 9), Vector2(80, 24), 14, HORIZONTAL_ALIGNMENT_LEFT, Color(0.4, 0.8, 1.0))
	lbl_dia = _lbl(dp, "", Vector2(90, 6), Vector2(90, 30), 20, HORIZONTAL_ALIGNMENT_RIGHT)


func _build_left() -> void:
	var items := [["PROFIL", _show_profile], ["KARAKTER", _show_character], ["MISI", _show_missions], ["PERINGKAT", _show_rank], ["PENGATURAN", _show_settings]]
	for i in items.size():
		_btn(self, items[i][0], Vector2(16, 130 + i * 62), Vector2(210, 52), Color(0.12, 0.15, 0.23, 0.95), items[i][1], 20)
	daily_btn = _btn(self, "HADIAH HARIAN", Vector2(16, 620), Vector2(210, 56), ORANGE, _quick_claim, 18)


func _build_right() -> void:
	var mc := _panel(self, Vector2(1000, 130), Vector2(264, 220))
	_lbl(mc, "MODE", Vector2(16, 8), Vector2(100, 20), 13, HORIZONTAL_ALIGNMENT_LEFT, Color(0.7, 0.7, 0.75))
	lbl_mode_name = _lbl(mc, "", Vector2(16, 28), Vector2(232, 32), 24, HORIZONTAL_ALIGNMENT_LEFT, ORANGE)
	lbl_mode_desc = _lbl(mc, "", Vector2(16, 66), Vector2(232, 110), 15)
	lbl_mode_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_mode_meta = _lbl(mc, "", Vector2(16, 186), Vector2(232, 24), 14, HORIZONTAL_ALIGNMENT_LEFT, Color(0.7, 0.7, 0.75))

	var rc := _panel(self, Vector2(1000, 366), Vector2(264, 130))
	_lbl(rc, "PERINGKAT", Vector2(16, 8), Vector2(120, 20), 13, HORIZONTAL_ALIGNMENT_LEFT, Color(0.7, 0.7, 0.75))
	lbl_rank = _lbl(rc, "", Vector2(16, 28), Vector2(232, 36), 28, HORIZONTAL_ALIGNMENT_LEFT, Color(0.6, 0.85, 1.0))
	bar_rank = _bar(rc, Vector2(16, 76), Vector2(232, 14), Color(0.6, 0.85, 1.0))
	lbl_rp = _lbl(rc, "", Vector2(16, 96), Vector2(232, 24), 15, HORIZONTAL_ALIGNMENT_LEFT, Color(0.8, 0.8, 0.85))


func _build_bottom() -> void:
	var i := 0
	for id in GameData.MODES.keys():
		var b := _btn(self, str(GameData.MODES[id].name), Vector2(300 + i * 114, 656), Vector2(108, 48), GREY, _set_mode.bind(str(id)), 14)
		mode_btns[str(id)] = b
		i += 1
	_btn(self, "MULAI", Vector2(1000, 520), Vector2(264, 120), ORANGE, _on_start, 40)


# ------------------------------------------------------------ Aksi utama
func _refresh() -> void:
	var d: Dictionary = Profile.data
	lbl_name.text = str(d.name)
	lbl_level.text = "Lv %d" % int(d.level)
	lbl_rank_small.text = Profile.rank_title()
	bar_xp.max_value = Profile.xp_needed(int(d.level))
	bar_xp.value = int(d.xp)
	lbl_uid.text = "ID: %s" % str(d.uid)
	avatar.add_theme_stylebox_override("panel", _sb(AVATARS[int(d.avatar) % AVATARS.size()], 34))
	avatar_letter.text = str(d.name).substr(0, 1).to_upper()
	lbl_gold.text = str(int(d.gold))
	lbl_dia.text = str(int(d.diamonds))

	var mid: String = str(d.mode)
	var m: Dictionary = GameData.MODES[mid]
	lbl_mode_name.text = str(m.name)
	lbl_mode_desc.text = str(m.desc)
	lbl_mode_meta.text = "Peta %dm  |  Lawan: %d" % [int(m.map), int(m.enemies)]
	for id in mode_btns.keys():
		var b: Button = mode_btns[id]
		var col: Color = ORANGE if id == mid else GREY
		b.add_theme_stylebox_override("normal", _sb(col, 10))

	var rp: Array = Profile.rank_progress()
	lbl_rank.text = Profile.rank_title()
	bar_rank.value = float(rp[0]) * 100.0
	lbl_rp.text = "%d / %d RP" % [int(rp[1]), int(rp[2])]

	var can: bool = Profile.can_claim_login()
	daily_btn.text = "HADIAH HARIAN" if can else "SUDAH DIAMBIL"
	daily_btn.disabled = not can


func _set_mode(id: String) -> void:
	Profile.data.mode = id
	Profile.save()
	_refresh()


func _on_start() -> void:
	GameData.selected_mode = str(Profile.data.mode)
	Profile.save()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _quick_claim() -> void:
	Profile.claim_login()
	_refresh()


# ------------------------------------------------------------ Popup
func _popup(title: String, sz: Vector2) -> Panel:
	_close_popup(false)
	popup = Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(popup)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(dim)
	var p := _panel(popup, (Vector2(1280, 720) - sz) * 0.5, sz, Color(0.1, 0.12, 0.19, 0.98))
	_lbl(p, title, Vector2(24, 12), Vector2(sz.x - 120, 40), 26, HORIZONTAL_ALIGNMENT_LEFT, ORANGE)
	_btn(p, "X", Vector2(sz.x - 68, 12), Vector2(52, 40), Color(0.8, 0.25, 0.25), _close_popup.bind(true), 20)
	return p


func _close_popup(refresh: bool = true) -> void:
	if popup != null:
		popup.queue_free()
		popup = null
	if refresh:
		_refresh()


# --- Profil
func _show_profile() -> void:
	var p := _popup("PROFIL", Vector2(900, 580))
	var d: Dictionary = Profile.data
	var av := _panel(p, Vector2(30, 70), Vector2(100, 100), AVATARS[int(d.avatar) % AVATARS.size()], 50)
	_lbl(av, str(d.name).substr(0, 1).to_upper(), Vector2(0, 16), Vector2(100, 70), 48, HORIZONTAL_ALIGNMENT_CENTER)
	for i in AVATARS.size():
		_btn(p, "", Vector2(30 + i * 46, 184), Vector2(38, 38), AVATARS[i], _set_avatar.bind(i))
	_lbl(p, "NAMA", Vector2(30, 232), Vector2(100, 20), 13, HORIZONTAL_ALIGNMENT_LEFT, Color(0.7, 0.7, 0.75))
	var le_name := LineEdit.new()
	le_name.text = str(d.name)
	le_name.max_length = 14
	le_name.position = Vector2(30, 254)
	le_name.size = Vector2(270, 42)
	p.add_child(le_name)
	_lbl(p, "BIO", Vector2(30, 306), Vector2(100, 20), 13, HORIZONTAL_ALIGNMENT_LEFT, Color(0.7, 0.7, 0.75))
	var le_bio := LineEdit.new()
	le_bio.text = str(d.bio)
	le_bio.max_length = 30
	le_bio.position = Vector2(30, 328)
	le_bio.size = Vector2(270, 42)
	p.add_child(le_bio)
	_btn(p, "SIMPAN", Vector2(30, 386), Vector2(270, 46), ORANGE, _save_profile.bind(le_name, le_bio))
	_lbl(p, "ID: %s" % str(d.uid), Vector2(30, 450), Vector2(270, 24), 16, HORIZONTAL_ALIGNMENT_LEFT, Color(0.8, 0.8, 0.85))
	_lbl(p, "Rank: %s (%d RP)" % [Profile.rank_title(), int(d.rp)], Vector2(30, 476), Vector2(270, 24), 16, HORIZONTAL_ALIGNMENT_LEFT, Color(0.6, 0.85, 1.0))

	var matches: int = int(d.matches)
	var wins: int = int(d.wins)
	var kills: int = int(d.kills)
	var deaths: int = int(d.deaths)
	var wr: int = 0 if matches == 0 else int(round(100.0 * wins / matches))
	var kd: float = float(kills) / maxf(1.0, float(deaths))
	var best: String = "-" if int(d.best_rank) == 0 else "#%d" % int(d.best_rank)
	var stats := [
		["LEVEL", str(int(d.level))], ["PERTANDINGAN", str(matches)], ["MENANG", str(wins)],
		["WIN RATE", "%d%%" % wr], ["KILL", str(kills)], ["MATI", str(deaths)],
		["K/D", "%.2f" % kd], ["TERBAIK BR", best], ["RANK", Profile.rank_title()],
		["RP", str(int(d.rp))], ["KOIN", str(int(d.gold))], ["DIAMOND", str(int(d.diamonds))],
	]
	for i in stats.size():
		var box := _panel(p, Vector2(340 + (i % 3) * 180, 80 + floori(i / 3.0) * 104), Vector2(170, 92), Color(0.15, 0.18, 0.26))
		_lbl(box, str(stats[i][0]), Vector2(12, 8), Vector2(150, 20), 13, HORIZONTAL_ALIGNMENT_LEFT, Color(0.7, 0.7, 0.75))
		_lbl(box, str(stats[i][1]), Vector2(12, 32), Vector2(150, 50), 30)


func _set_avatar(i: int) -> void:
	Profile.data.avatar = i
	Profile.save()
	_show_profile()


func _save_profile(le_name: LineEdit, le_bio: LineEdit) -> void:
	var n: String = le_name.text.strip_edges()
	if n != "":
		Profile.data.name = n
	Profile.data.bio = le_bio.text.strip_edges()
	Profile.save()
	_show_profile()


# --- Karakter & skill
func _show_character() -> void:
	var p := _popup("KARAKTER & SKILL", Vector2(820, 540))
	_lbl(p, "Pilih skill aktif (tombol Q saat bermain):", Vector2(24, 60), Vector2(700, 26), 17, HORIZONTAL_ALIGNMENT_LEFT, Color(0.8, 0.8, 0.85))
	for i in GameData.SKILLS.size():
		var s: Dictionary = GameData.SKILLS[i]
		var sel: bool = int(Profile.data.skill) == i
		var b := _btn(p, "%s  -  %s  (CD %ds)" % [s.name, s.desc, int(s.cd)], Vector2(24, 96 + i * 70), Vector2(772, 62), ORANGE if sel else GREY, _select_skill.bind(i), 16)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT


func _select_skill(i: int) -> void:
	Profile.data.skill = i
	Profile.save()
	_show_character()


# --- Misi
func _show_missions() -> void:
	var p := _popup("MISI HARIAN", Vector2(780, 480))
	var can: bool = Profile.can_claim_login()
	_lbl(p, "Hadiah login harian: 200 Koin + 10 Diamond", Vector2(24, 70), Vector2(540, 30), 18)
	var lb := _btn(p, "AMBIL" if can else "DIAMBIL", Vector2(600, 62), Vector2(150, 44), ORANGE, _claim_login)
	lb.disabled = not can
	for i in Profile.MISSIONS.size():
		var m: Dictionary = Profile.MISSIONS[i]
		var row := _panel(p, Vector2(24, 130 + i * 106), Vector2(732, 92), Color(0.15, 0.18, 0.26))
		_lbl(row, str(m.text), Vector2(16, 8), Vector2(480, 28), 20)
		var prog: int = Profile.mission_progress(i)
		var bar := _bar(row, Vector2(16, 52), Vector2(420, 16), Color(0.3, 0.8, 1.0))
		bar.max_value = float(m.goal)
		bar.value = float(prog)
		_lbl(row, "%d/%d" % [prog, int(m.goal)], Vector2(446, 46), Vector2(80, 26), 18)
		_lbl(row, "+%d Koin" % int(m.gold), Vector2(520, 10), Vector2(110, 26), 16, HORIZONTAL_ALIGNMENT_LEFT, Color(1.0, 0.85, 0.3))
		var done: bool = Profile.mission_done(i)
		var claimed: bool = Profile.mission_claimed(i)
		var cb := _btn(row, "SELESAI" if claimed else "AMBIL", Vector2(594, 24), Vector2(126, 46), ORANGE, _claim_mission.bind(i))
		cb.disabled = claimed or not done


func _claim_login() -> void:
	Profile.claim_login()
	_show_missions()


func _claim_mission(i: int) -> void:
	Profile.claim_mission(i)
	_show_missions()


# --- Peringkat
func _show_rank() -> void:
	var p := _popup("PERINGKAT", Vector2(760, 620))
	var idx: int = Profile.rank_index()
	for i in Profile.RANKS.size():
		var r: Array = Profile.RANKS[i]
		var col: Color = ORANGE if i == idx else Color(0.15, 0.18, 0.26)
		var row := _panel(p, Vector2(24, 68 + i * 40), Vector2(712, 34), col, 8)
		_lbl(row, str(r[0]), Vector2(14, 3), Vector2(300, 28), 18)
		_lbl(row, "%d RP" % int(r[1]), Vector2(500, 3), Vector2(190, 28), 18, HORIZONTAL_ALIGNMENT_RIGHT)
	_lbl(p, "RP kamu: %d  (menang +25, tiap kill +2, kalah -8)" % int(Profile.data.rp), Vector2(24, 318), Vector2(712, 26), 16, HORIZONTAL_ALIGNMENT_LEFT, Color(0.8, 0.8, 0.85))
	_lbl(p, "STATISTIK PER MODE", Vector2(24, 356), Vector2(400, 26), 18, HORIZONTAL_ALIGNMENT_LEFT, ORANGE)
	_lbl(p, "MODE", Vector2(24, 388), Vector2(260, 22), 13, HORIZONTAL_ALIGNMENT_LEFT, Color(0.7, 0.7, 0.75))
	_lbl(p, "MAIN", Vector2(400, 388), Vector2(100, 22), 13, HORIZONTAL_ALIGNMENT_LEFT, Color(0.7, 0.7, 0.75))
	_lbl(p, "MENANG", Vector2(500, 388), Vector2(100, 22), 13, HORIZONTAL_ALIGNMENT_LEFT, Color(0.7, 0.7, 0.75))
	_lbl(p, "KILL", Vector2(620, 388), Vector2(100, 22), 13, HORIZONTAL_ALIGNMENT_LEFT, Color(0.7, 0.7, 0.75))
	var i2 := 0
	for id in GameData.MODES.keys():
		if id == "train":
			continue
		var ms: Dictionary = Profile.data.modes.get(id, {"matches": 0, "wins": 0, "kills": 0})
		var y: float = 414.0 + i2 * 34.0
		_lbl(p, str(GameData.MODES[id].name), Vector2(24, y), Vector2(360, 28), 18)
		_lbl(p, str(int(ms.matches)), Vector2(400, y), Vector2(100, 28), 18)
		_lbl(p, str(int(ms.wins)), Vector2(500, y), Vector2(100, 28), 18)
		_lbl(p, str(int(ms.kills)), Vector2(620, y), Vector2(100, 28), 18)
		i2 += 1


# --- Pengaturan
func _show_settings() -> void:
	var p := _popup("PENGATURAN", Vector2(1140, 580))
	SettingsPanel.fill(p, _open_ui_editor)
	reset_armed = false
	reset_btn = _btn(p, "RESET DATA PROFIL", Vector2(30, 506), Vector2(280, 50), Color(0.7, 0.2, 0.2), _on_reset, 17)


func _open_ui_editor() -> void:
	_close_popup(false)
	var ed := UiEditor.new()
	ed.closed.connect(_on_editor_closed)
	add_child(ed)


func _on_editor_closed() -> void:
	_show_settings()


func _on_reset() -> void:
	if not reset_armed:
		reset_armed = true
		reset_btn.text = "YAKIN? KLIK LAGI"
		return
	Profile.reset_data()
	_close_popup(true)
