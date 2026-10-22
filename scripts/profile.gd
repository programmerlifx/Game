extends Node
# Profil pemain + penyimpanan (user://profile.json): level, XP, koin, statistik, rank, misi harian, pengaturan.

const SAVE_PATH := "user://profile.json"
const RANKS := [["Bronze", 0], ["Silver", 200], ["Gold", 500], ["Platinum", 900], ["Diamond", 1400], ["Heroic", 2000]]
const MISSIONS := [
	{"id": "matches", "text": "Mainkan 3 pertandingan", "goal": 3, "gold": 150},
	{"id": "kills", "text": "Kalahkan 8 musuh", "goal": 8, "gold": 250},
	{"id": "wins", "text": "Menangkan 1 pertandingan", "goal": 1, "gold": 300},
]

var data: Dictionary = {}


func _ready() -> void:
	load_data()


func _default() -> Dictionary:
	return {
		"name": "Pemain", "uid": str(randi_range(100000000, 999999999)), "bio": "Siap tempur!",
		"avatar": 0, "level": 1, "xp": 0, "gold": 1000, "diamonds": 50,
		"matches": 0, "wins": 0, "kills": 0, "deaths": 0, "best_rank": 0, "rp": 0,
		"skill": 0, "mode": "br", "modes": {},
		"daily": {"date": "", "matches": 0, "kills": 0, "wins": 0, "claimed": [false, false, false]},
		"login_date": "",
		"settings": {"sens": 1.0, "sens_ads": 0.7, "sens_v": 1.0, "invert_y": false, "touch": 0, "float_stick": false, "ui_alpha": 0.55, "quality": (0 if OS.has_feature("mobile") else 1), "ui": {}},
	}


func load_data() -> void:
	data = _default()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			for k in parsed.keys():
				if k == "settings" and parsed[k] is Dictionary:
					for sk in parsed[k].keys():
						data.settings[sk] = parsed[k][sk]
				else:
					data[k] = parsed[k]
	else:
		save()
	ensure_daily()


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


func reset_data() -> void:
	data = _default()
	save()


func today() -> String:
	return Time.get_date_string_from_system()


func ensure_daily() -> void:
	var d: Dictionary = data.daily
	if d.get("date", "") != today():
		data.daily = {"date": today(), "matches": 0, "kills": 0, "wins": 0, "claimed": [false, false, false]}


# ---- Level / XP
func xp_needed(level: int) -> int:
	return 100 + level * 50


func add_xp(amount: int) -> int:
	var ups := 0
	data.xp = int(data.xp) + amount
	while int(data.xp) >= xp_needed(int(data.level)):
		data.xp = int(data.xp) - xp_needed(int(data.level))
		data.level = int(data.level) + 1
		data.gold = int(data.gold) + 100
		data.diamonds = int(data.diamonds) + 5
		ups += 1
	return ups


# ---- Rank
func rank_index() -> int:
	var idx := 0
	for i in RANKS.size():
		if int(data.rp) >= int(RANKS[i][1]):
			idx = i
	return idx


func rank_title() -> String:
	return str(RANKS[rank_index()][0])


func rank_progress() -> Array:
	var i: int = rank_index()
	var cur: int = int(RANKS[i][1])
	if i >= RANKS.size() - 1:
		return [1.0, int(data.rp), cur]
	var nxt: int = int(RANKS[i + 1][1])
	return [float(int(data.rp) - cur) / float(nxt - cur), int(data.rp), nxt]


# ---- Pertandingan
func record_match(mode_id: String, kills: int, deaths: int, win: bool, rank: int) -> Dictionary:
	ensure_daily()
	data.matches = int(data.matches) + 1
	data.kills = int(data.kills) + kills
	data.deaths = int(data.deaths) + deaths
	if win:
		data.wins = int(data.wins) + 1
	if mode_id == "br" and rank > 0 and (int(data.best_rank) == 0 or rank < int(data.best_rank)):
		data.best_rank = rank
	var ms: Dictionary = data.modes.get(mode_id, {"matches": 0, "wins": 0, "kills": 0})
	ms.matches = int(ms.matches) + 1
	ms.kills = int(ms.kills) + kills
	if win:
		ms.wins = int(ms.wins) + 1
	data.modes[mode_id] = ms
	data.daily.matches = int(data.daily.matches) + 1
	data.daily.kills = int(data.daily.kills) + kills
	if win:
		data.daily.wins = int(data.daily.wins) + 1

	var xp_gain: int = 20 + kills * 10 + (60 if win else 0)
	var gold_gain: int = 40 + kills * 15 + (120 if win else 0)
	var rp_delta: int = (25 if win else -8) + kills * 2
	if mode_id == "br" and rank > 0 and rank <= 5:
		rp_delta += 10
	var new_rp: int = maxi(0, int(data.rp) + rp_delta)
	rp_delta = new_rp - int(data.rp)
	data.rp = new_rp
	data.gold = int(data.gold) + gold_gain
	var ups: int = add_xp(xp_gain)
	save()
	return {"xp": xp_gain, "gold": gold_gain, "rp": rp_delta, "levels": ups}


# ---- Misi & login harian
func can_claim_login() -> bool:
	return data.login_date != today()


func claim_login() -> bool:
	if not can_claim_login():
		return false
	data.login_date = today()
	data.gold = int(data.gold) + 200
	data.diamonds = int(data.diamonds) + 10
	save()
	return true


func mission_progress(i: int) -> int:
	ensure_daily()
	return mini(int(data.daily.get(MISSIONS[i].id, 0)), int(MISSIONS[i].goal))


func mission_done(i: int) -> bool:
	return mission_progress(i) >= int(MISSIONS[i].goal)


func mission_claimed(i: int) -> bool:
	return bool(data.daily.claimed[i])


func claim_mission(i: int) -> bool:
	if not mission_done(i) or mission_claimed(i):
		return false
	data.daily.claimed[i] = true
	data.gold = int(data.gold) + int(MISSIONS[i].gold)
	save()
	return true
