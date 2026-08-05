extends SceneTree

## 배경음악이 실제로 울리는지 부팅 경로 그대로 따라가며 계측한다.
##
## "안 들린다" 는 보고만으로는 원인을 못 좁힌다. 파일을 못 찾은 것인지,
## 재생기가 안 만들어진 것인지, 버스가 죽은 것인지, 소리는 나는데 볼륨이
## 바닥인지가 전부 다른 문제다. 하나씩 찍어 본다.

func _init() -> void:
	print("=== 오디오 경로 계측 ===")

	# ── 버스 ─────────────────────────────────────────────────────────────
	print("  버스 %d개" % AudioServer.bus_count)
	for i in AudioServer.bus_count:
		print("    [%d] %-10s vol %+.1fdB  mute %s  bypass %s" % [
			i, AudioServer.get_bus_name(i), AudioServer.get_bus_volume_db(i),
			AudioServer.is_bus_mute(i), AudioServer.is_bus_bypassing_effects(i)])
	print("  출력 장치: %s" % AudioServer.output_device)
	print("  믹스 레이트: %d" % AudioServer.get_mix_rate())

	# ── 파일 ─────────────────────────────────────────────────────────────
	var path := "res://assets/music/opening_theme.wav"
	print("  exists(%s) = %s" % [path, ResourceLoader.exists(path)])
	var st = load(path)
	print("  load -> %s  길이 %.1f초" % [
		st.get_class() if st != null else "null",
		st.get_length() if st is AudioStream else -1.0])
	if st is AudioStreamWAV:
		print("  (raw loop_mode = %d)" % (st as AudioStreamWAV).loop_mode)

	# ── 부팅 경로 ────────────────────────────────────────────────────────
	# 조작이 있었다고 치고 연다. 없으면 설계상 재생을 미루므로 여기서 막힌다.
	Sfx._unlocked = true
	await process_frame   # 트리가 완전히 설 때까지 기다린다

	var title: TitleScreen = load("res://scenes/title_screen.tscn").instantiate()
	root.add_child(title)
	title.setup()

	await process_frame
	await process_frame

	var m: AudioStreamPlayer = Sfx._music
	if m == null or not is_instance_valid(m):
		print("  [FAIL] 재생기가 없다. play_music 이 일찍 돌아왔다.")
		quit(1)
		return
	print("  재생기 부모: %s" % m.get_parent().name)
	print("  bus=%s  volume=%+.1fdB  autoplay=%s" % [m.bus, m.volume_db, m.autoplay])
	print("  playing=%s  paused=%s  pos=%.3f" % [
		m.playing, m.stream_paused, m.get_playback_position()])

	# 몇 프레임 더 돌려 재생 위치가 실제로 흐르는지 본다.
	var t0 := m.get_playback_position()
	for i in 30:
		await process_frame
	var t1 := m.get_playback_position()
	print("  30프레임 뒤 pos=%.3f (%+.3f)" % [t1, t1 - t0])

	var ok := m.playing and t1 > t0
	print("=== %s ===" % ("정상" if ok else "실패"))
	quit(0 if ok else 1)
