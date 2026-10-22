extends Node
# Data global: mode, skill, senjata + registrasi input.

var selected_mode: String = "br"

const MODES := {
	"br": {
		"name": "Battle Royale",
		"desc": "15 petarung di peta luas. Cari senjata, bertahan di zona aman yang terus menyempit. Yang terakhir hidup menang.",
		"map": 160.0, "enemies": 14, "allies": 0, "ffa": true, "zone": true,
		"loot": 90, "loadout": ["pistol"], "rounds": 0, "respawn": 0.0,
		"kill_target": 0, "passive": false,
	},
	"cs": {
		"name": "Clash Squad",
		"desc": "Tim 4 vs 4 berbasis ronde. Semua mulai dengan senjata lengkap. Menangkan 3 ronde.",
		"map": 70.0, "enemies": 4, "allies": 3, "ffa": false, "zone": false,
		"loot": 0, "loadout": ["pistol", "smg", "ar", "ak47"], "rounds": 3, "respawn": 0.0,
		"kill_target": 0, "passive": false,
	},
	"lw": {
		"name": "Lone Wolf",
		"desc": "Duel 1 lawan 1 di arena kecil. Menangkan 2 ronde.",
		"map": 40.0, "enemies": 1, "allies": 0, "ffa": false, "zone": false,
		"loot": 0, "loadout": ["pistol", "smg", "ak47"], "rounds": 2, "respawn": 0.0,
		"kill_target": 0, "passive": false,
	},
	"tdm": {
		"name": "Team DM",
		"desc": "5 vs 5, respawn otomatis. Tim pertama yang mencapai 30 kill menang.",
		"map": 90.0, "enemies": 5, "allies": 4, "ffa": false, "zone": false,
		"loot": 0, "loadout": ["pistol", "smg", "ar", "ak47", "sniper"], "rounds": 0, "respawn": 3.0,
		"kill_target": 30, "passive": false,
	},
	"dm": {
		"name": "Deathmatch",
		"desc": "Semua lawan semua (7 pemain), respawn otomatis. Capai 20 kill duluan.",
		"map": 80.0, "enemies": 6, "allies": 0, "ffa": true, "zone": false,
		"loot": 0, "loadout": ["pistol", "smg", "ar", "ak47", "sniper"], "rounds": 0, "respawn": 3.0,
		"kill_target": 20, "passive": false,
	},
	"train": {
		"name": "Latihan",
		"desc": "Berlatih menembak target diam. Peluru tak terbatas. Tidak mengubah statistik.",
		"map": 60.0, "enemies": 6, "allies": 0, "ffa": false, "zone": false,
		"loot": 0, "loadout": ["pistol", "smg", "ar", "ak47", "sniper"], "rounds": 0, "respawn": 2.0,
		"kill_target": 0, "passive": true,
	},
}

# Skill aktif (tombol Q). Dipilih di menu Karakter pada lobi.
const SKILLS := [
	{"name": "Aura Musik", "desc": "Pulihkan 40 HP bertahap + lari 15% lebih cepat selama 8 detik.", "type": "aura", "cd": 30.0},
	{"name": "Medis Lapangan", "desc": "Memulihkan 45 HP secara bertahap.", "type": "heal", "cd": 30.0},
	{"name": "Sprint Kilat", "desc": "Kecepatan +60% selama 6 detik.", "type": "speed", "cd": 25.0},
	{"name": "Perisai Baja", "desc": "Menambah 60 armor.", "type": "shield", "cd": 35.0},
	{"name": "Lompat Bayangan", "desc": "Dash melompat ke depan.", "type": "dash", "cd": 15.0},
	{"name": "Mode Brutal", "desc": "Damage +50% selama 6 detik.", "type": "damage", "cd": 30.0},
]

# Model 3D senjata diambil dari assets/weapons/gun_pack.glb (lihat scripts/weapon_models.gd).
const WEAPONS := {
	"pistol": {"name": "FN Five-seveN", "dmg": 18, "rate": 0.28, "mag": 12, "reload": 1.2, "range": 60.0, "spread": 0.012, "auto": false, "pellets": 1},
	"smg": {"name": "HK MP5", "dmg": 12, "rate": 0.075, "mag": 30, "reload": 1.6, "range": 45.0, "spread": 0.035, "auto": true, "pellets": 1},
	"ar": {"name": "M16A1", "dmg": 22, "rate": 0.11, "mag": 30, "reload": 2.0, "range": 90.0, "spread": 0.02, "auto": true, "pellets": 1},
	"ak47": {"name": "AK-47", "dmg": 27, "rate": 0.125, "mag": 30, "reload": 2.3, "range": 85.0, "spread": 0.028, "auto": true, "pellets": 1},
	"sniper": {"name": "Barrett M82", "dmg": 95, "rate": 1.4, "mag": 5, "reload": 2.6, "range": 250.0, "spread": 0.0, "auto": false, "pellets": 1},
}


func _ready() -> void:
	_key("move_forward", KEY_W)
	_key("move_back", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("jump", KEY_SPACE)
	_key("sprint", KEY_SHIFT)
	_key("crouch", KEY_C)
	_key("reload", KEY_R)
	_key("ability", KEY_Q)
	_key("slot1", KEY_1)
	_key("slot2", KEY_2)
	_key("slot3", KEY_3)
	_key("slot4", KEY_4)
	_key("slot5", KEY_5)
	_mouse("shoot", MOUSE_BUTTON_LEFT)
	_mouse("aim", MOUSE_BUTTON_RIGHT)


func _key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _mouse(action: String, btn: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = btn
	InputMap.action_add_event(action, ev)
