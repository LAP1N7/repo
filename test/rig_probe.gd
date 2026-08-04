extends SceneTree

## 캐릭터 애니메이션 씬 진단.
##
##   godot --headless --script res://test/rig_probe.gd
##
## "애니메이션이 안 돈다" 를 추측하지 않고 실제로 재본다.

func _init() -> void:
	print("=== 캐릭터 리그 진단 ===\n")
	for tid in UnitData.TABLE.keys():
		var path := "res://assets/art/units/%s.tscn" % tid
		if not ResourceLoader.exists(path):
			continue
		probe(String(tid), path)
	quit(0)


func probe(tid: String, path: String) -> void:
	print("── %s  (%s)" % [UnitData.TABLE[tid]["name"], path])
	var packed := load(path)
	var inst: Node2D = packed.instantiate()
	root.add_child(inst)

	var ap := find_anim(inst)
	if ap == null:
		print("   ✗ AnimationPlayer 가 없다")
		inst.queue_free()
		return

	var names := ap.get_animation_list()
	print("   애니메이션 목록: %s" % str(names))

	for n in names:
		var a := ap.get_animation(n)
		print("   · %-8s 길이 %.3f초  루프 %s  트랙 %d개" % [
			n, a.length, "예" if a.loop_mode != 0 else "아니오", a.get_track_count()])

	if not ap.has_animation("walk"):
		print("   ✗ 'walk' 가 없다")
		inst.queue_free()
		return

	var walk := ap.get_animation("walk")

	# 실제로 노드를 움직이는지: 0초와 중간 지점의 자세를 비교한다.
	ap.play("walk")
	ap.seek(0.0, true)
	var pose_a := snapshot(inst)
	ap.seek(walk.length * 0.5, true)
	var pose_b := snapshot(inst)
	ap.seek(walk.length * 0.99, true)
	var pose_c := snapshot(inst)

	print("   0초   : %s" % pose_a)
	print("   중간  : %s" % pose_b)
	print("   끝    : %s" % pose_c)
	print("   → 애니메이션이 노드를 움직이는가: %s" % ("예" if pose_a != pose_b else "아니오"))

	# 루프가 아니면 한 번 돌고 멈춘다 — 걷기로 쓰려면 루프여야 한다.
	if walk.loop_mode == 0:
		print("   ⚠ 'walk' 가 루프가 아니다. 한 번 재생되고 멈춘다")

	# 전투에서 한 걸음에 주어지는 시간과 비교한다.
	var per_step := 0.22          # BattleScreen.ACT_TIME
	print("   ⚠ 전투 한 걸음 시간 %.2f초 vs 애니메이션 %.2f초 → %.0f%% 만 보인다"
		% [per_step, walk.length, per_step / walk.length * 100.0])

	# ── 실제 전투 조건에서 한 사이클이 다 도는지 ──────────────────────────
	# play_motion 이 하는 계산을 그대로 재현한다: 한 걸음 시간에 한 사이클.
	var eff := 0.0
	for t in walk.get_track_count():
		var kn := walk.track_get_key_count(t)
		if kn > 0:
			eff = maxf(eff, walk.track_get_key_time(t, kn - 1))
	if eff <= 0.001:
		eff = walk.length
	print("   실효 길이(마지막 키): %.3f초  (선언 길이 %.3f초)" % [eff, walk.length])

	for spd: float in [1.0, 4.0]:
		var per: float = 0.22 / spd        # BattleScreen.ACT_TIME / 배속
		var scale: float = eff / per
		print("   배속 %.0fx → 한 걸음 %.3f초, speed_scale %.1f" % [spd, per, scale])
		ap.speed_scale = scale
		ap.play("walk")
		ap.seek(0.0, true)
		var seen: Array[String] = []
		# 걸음 시간 동안 5등분해서 자세를 뽑는다
		for i in 5:
			ap.seek(eff * float(i) / 4.0, true)
			seen.append(snapshot(inst))
		var uniq := {}
		for x in seen:
			uniq[x] = true
		print("      → 걸음 중 서로 다른 자세 %d개 / 5개 표본  %s" % [
			uniq.size(), "정상" if uniq.size() >= 4 else "⚠ 자세 변화가 적다"])

	inst.queue_free()
	print("")


func snapshot(root_node: Node) -> String:
	var parts: PackedStringArray = []
	for n in all_sprites(root_node):
		parts.append("%s(%.0f,%.0f r%.2f)" % [n.name, n.position.x, n.position.y, n.rotation])
	return " ".join(parts)


func all_sprites(n: Node) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	if n is Sprite2D:
		out.append(n)
	for c in n.get_children():
		out.append_array(all_sprites(c))
	return out


func find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var f := find_anim(c)
		if f != null:
			return f
	return null
