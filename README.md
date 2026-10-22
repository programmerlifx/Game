# Arena Nusantara (Godot 4.3+)

Game 3D battle royale terinspirasi Free Fire. Karakter memakai model rigged `assets/characters/hero.glb`
dengan animasi jalan/lari/lompat/bidik yang dibuat lewat kode (model tidak punya animasi bawaan).

## Cara buka
1. Install Godot 4.3+ (versi standar, bukan .NET).
2. Project Manager -> Import -> pilih `project.godot`.
3. Tunggu import selesai (model 32 MB, butuh beberapa menit pertama kali), lalu F5.

## Yang baru di versi ini
- **Senjata asli 3D** dari `assets/weapons/gun_pack.glb`: FN Five-seveN (pistol), HK MP5 (SMG), M16A1 (AR), AK-47 (baru, menggantikan shotgun) dan Barrett M82 (sniper). Senjata muncul di tangan karakter (pinggang / bahu saat zoom), di loot tanah, dan di tangan bot, lengkap dengan recoil dan kilatan moncong.
- **Karakter tidak kaku**: badan berputar halus mengikuti arah joystick/WASD. Kamera tetap bebas, dan saat menembak/zoom badan menghadap arah bidik.
- **Gerakan lebih pelan** ala game tembak taktis: jalan 4,2 m/s (dulu 7), lari x1,5 lewat tombol LARI, jongkok x0,5. Dorong joystick pelan = jalan pelan. Bot juga diperlambat (3,3 m/s).
- **Pengaturan lengkap** (lobi > PENGATURAN, dan di game lewat II > PENGATURAN):
  sensitivitas kamera, sensitivitas saat zoom, sensitivitas vertikal, invert Y, mode kontrol sentuh,
  joystick melayang, transparansi tombol, kualitas grafis (Rendah/Sedang/Tinggi).
- **Custom UI**: tombol ATUR TAMPILAN TOMBOL. Seret tiap tombol (joystick, tembak, lompat, zoom, reload, skill, jongkok, ganti, jeda, lari) ke posisi nyaman, ubah ukuran per tombol, atur transparansi, RESET untuk kembali ke bawaan. Tersimpan otomatis.
- **Lebih realistis**: tonemap filmic, langit prosedural, matahari hangat + bayangan, tanah rumput bertekstur, pohon dan semak lebih rimbun, percikan peluru, lubang peluru, darah saat kena, MSAA.

## Lobi (seperti Free Fire)
- Karakter 3D berputar di tengah (geser mouse/jari untuk memutar)
- Profil: nama, bio, avatar, ID, level + XP, rank, statistik (match, menang, win rate, kill, mati, K/D, terbaik BR)
- Karakter & Skill: pilih skill aktif (tombol Q)
- Misi harian + hadiah login harian
- Peringkat (Bronze sampai Heroic) + statistik per mode
- Pengaturan: sensitivitas, kontrol sentuh (otomatis/nyala/mati), reset data
- Pilih mode lalu tekan MULAI. Data tersimpan otomatis di user://profile.json

## Mode
Battle Royale (zona menyempit), Clash Squad 4v4, Lone Wolf 1v1, Team DM, Deathmatch, Latihan.
Selesai main: dapat XP, koin, dan RP (kecuali Latihan).

## Kontrol
PC: WASD gerak | mouse bidik | klik kiri tembak | klik kanan zoom | Spasi lompat | Shift lari | C jongkok | R reload | 1-5 senjata | Q skill | ESC jeda
HP: joystick kiri, geser layar kanan untuk melihat, tombol TEMBAK/LOMPAT/ZOOM/RELOAD/SKILL/JONGKOK/GANTI/LARI/II (jeda)

## Struktur
- scripts/lobby.gd          : lobi
- scripts/profile.gd        : data profil, XP, rank, misi, simpan
- scripts/game_data.gd      : mode, skill, senjata (edit di sini)
- scripts/game.gd           : dunia, spawn, zona, ronde, HUD
- scripts/player.gd / bot.gd: pemain & AI
- scripts/character_anim.gd : animasi tulang prosedural
- scripts/touch_controls.gd : kontrol sentuh (baca tata letak dari hud_layout.gd)
- scripts/hud_layout.gd     : posisi/ukuran tombol yang bisa diubah pemain
- scripts/ui_editor.gd      : layar "Atur Tampilan Tombol"
- scripts/settings_panel.gd : isi menu Pengaturan (dipakai lobi + menu jeda)
- scripts/weapon_models.gd  : memecah gun_pack.glb jadi 5 senjata (arah laras, ukuran, titik pegang)
- scripts/weapon_view.gd    : senjata di tangan: posisi, recoil, kilatan moncong
- scripts/model_util.gd     : loader GLB (auto-skala tinggi 1,8 m)

## Atur kecepatan & rasa gerak
- `player.gd`: `WALK_SPEED` (jalan), `SPRINT_MULT` (lari), `JUMP_VELOCITY`, `TURN_SPEED` (kecepatan badan berputar).
- `bot.gd`: `MOVE_SPEED`.
- Damage/rate/magasin senjata: `game_data.gd` (id: pistol, smg, ar, ak47, sniper). Ukuran tiap senjata: `weapon_models.gd` (`len`, meter).

## Jika animasi/model terlihat aneh
- Model menghadap mundur: ubah `PI` jadi `0.0` pada `make_model(..., PI)` di player.gd dan bot.gd.
- Lengan terlalu miring/menembus badan: ubah `ARM_DOWN` di character_anim.gd.
- Posisi tangan saat membidik: ubah `AIM_YAW` di character_anim.gd.
- Posisi senjata di tangan: ubah `HIP` (pinggang) dan `AIM` (bahu saat zoom) di weapon_view.gd.
- Senjata terbalik/menghadap belakang: cek matriks `rot` di `_build` pada weapon_models.gd.
- Lag di HP: kurangi `enemies` di game_data.gd (model detail tinggi).

## Ekspor Android
Project > Install Android Build Template, atur Export Preset Android, orientasi landscape sudah diset.

## Catatan model
Model karakter dan paket senjata (`gun_pack.glb`, Sketchfab "Free Pack - Gun") adalah aset buatan pihak lain: cek lisensinya sebelum dirilis publik.
Import pertama kali memakan waktu karena `hero.glb` besar (32 MB); setelah itu cepat.
