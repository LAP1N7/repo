extends SceneTree

## 배경음악이 실제로 울리는지 **부팅 경로 그대로** 따라가며 계측한다.
##
## ── 왜 이 검사가 한 번 실패했는가 ────────────────────────────────────────
## 예전 판은 process_frame 을 한 번 돌린 **뒤에** 타이틀을 붙였다. 그러면 루트가
## 한가한 상태라 add_child 가 성공하고, 매번 "정상" 이 찍혔다.
##
## 실제 게임은 Game._swap() 의 add_child(화면) **안에서** setup() 이 돌고, 그
## 안에서 play_music 이 불린다. 그 순간 루트는 자식을 세팅하는 중이라 새 자식을
## 거절한다. 재생기가 트리 밖에 남아 play() 가 영원히 실패했다.
##
## 그래서 이제 **한 프레임 안에서 붙이고 곧바로 setup 을 부른다.** 실제와 같은
## 순서여야 같은 실패를 잡는다.

func _init() -> void:
	print("=== 오디오 경로 계측 ===")
	print("  버스 %d개 · [0] %s vol %+.1fdB mute %s" % [
		AudioServer.bus_count, AudioServer.get_bus_name(0),
		AudioServer.get_bus_volume_db(0), AudioServer.is_bus_mute(0)])

	var path := "res://assets/music/opening_theme.wav"
	print("  exists(%s) = %s" % [path, ResourceLoader.exists(path)])
	var st = load(path)
	print("  load -> %s  %.1f초" % [st, st.get_length() if st is AudioStream else -1.0])

	Sfx._unlocked = true

	# 실제 부팅과 같은 순서. 프레임을 먼저 돌리지 않는다.
	var title: TitleScreen = load("res://scenes/title_screen.tscn").instantiate()
	root.add_child(title)
	title.setup()

	# 여기서 바로 확인하면 안 된다. play_music 은 자기가 트리 밖이면 한 프레임
	# 미루고, 재생기를 붙이는 것도 또 한 번 미룬다. 미룸이 두 겹이다.
	print("  붙자마자: 재생기 %s" % ("있음" if Sfx._music != null else "없음 (미룬 중)"))
	for i in 4:
		await process_frame

	var m: AudioStreamPlayer = Sfx._music
	if m == null or not is_instance_valid(m):
		print("  [FAIL] 몇 프레임 뒤에도 재생기가 없다")
		quit(1)
		return
	print("  한 프레임 뒤: in_tree=%s  playing=%s  bus=%s  %.0fdB" % [
		m.is_inside_tree(), m.playing, m.bus, m.volume_db])

	var t0 := m.get_playback_position()
	for i in 30:
		await process_frame
	var t1 := m.get_playback_position()
	print("  30프레임 뒤 pos=%.3f (%+.3f)" % [t1, t1 - t0])

	var okay := m.is_inside_tree() and m.playing and t1 > t0
	print("=== %s ===" % ("정상" if okay else "실패 - " + Sfx.diagnose()))
	quit(0 if okay else 1)
