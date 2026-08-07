extends SceneTree

## 화면을 실제로 렌더해서 PNG 로 남긴다.
##
##   godot --path . --script res://test/shots.gd
##   (헤드리스로는 못 돌린다. 렌더 결과가 필요하므로 창이 떠야 한다)
##
## ── 왜 필요한가 ──────────────────────────────────────────────────────────
## 지금까지 UI 를 좌표만 보고 고쳤다. "카드가 156 에서 시작해 높이 196 이니
## 352 에서 끝난다" 식으로 계산해서 옮겼는데, 그 계산은 한 요소만 본 것이라
## **옆 요소와 겹치는지는 아무도 안 봤다.** 실제로 판을 1.42배로 키우자마자
## 로그·하단 바·버튼이 한꺼번에 겹쳤다.
##
## 눈으로 볼 수 없으면 레이아웃은 고칠 수 없다. 이 스크립트는 그걸 대신한다.
## 찍은 그림은 .shots/ 에 들어가고 커밋하지 않는다.

const OUT := "res://.shots"


func _init() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	var run := RunState.new()
	run.fixed_seed = 7
	run.start_run(1)

	# 오프닝 영상이 첫 프레임을 그릴 시간을 준다.
	await _shot("01_title", load("res://scenes/title_screen.tscn").instantiate(),
		func(s): s.setup(), 30)

	# 서류첩은 든 것이 있어야 꽂힌 모습이 보인다.
	run.hand.append_array(["near_first", "backline", "keep_range", "front_line", "taunt"])
	await _shot("02_shop", load("res://scenes/shop_screen.tscn").instantiate(),
		func(s): s.setup(run))

	# 서류첩을 펼친 모습. 마우스를 못 쓰니 열림값을 직접 밀어 넣는다.
	await _shot("02b_dossier", load("res://scenes/shop_screen.tscn").instantiate(),
		func(s):
			s.setup(run)
			for c in s.hand_root.get_children():
				if c.has_method("force_open"):
					c.force_open(), 8)

	# 보조 지휘는 예산이 있어야 버튼이 살아 있는 모습을 볼 수 있다.
	run.budget = 40
	await _shot("09_command", load("res://scenes/command_screen.tscn").instantiate(),
		func(s): s.setup(run))

	# 편성·전투는 대원이 있어야 한다.
	run.place("musketeer", 0)
	run.place("assassin", 4)
	run.place("bard", 2)
	await _shot("03_loadout", load("res://scenes/loadout_screen.tscn").instantiate(),
		func(s): s.setup(run))

	await _shot("04_battle", load("res://scenes/battle_view.tscn").instantiate(),
		func(s): s.setup(run), 6)

	# 포격 예고가 실제로 칸에 칠해지는지. 좌표만 보고는 절대 알 수 없다.
	run.stage_id = 4
	await _shot("10_barrage", load("res://scenes/battle_view.tscn").instantiate(),
		func(s):
			s.setup(run)
			# 예고가 뜰 때까지 코어만 돌린다. 뷰 재생은 건너뛴다.
			for _i in 40:
				if not s.battle.hazard_cells.is_empty():
					break
				s.battle.step()
			s.queue_redraw(), 6)
	run.stage_id = 1

	# 실제로 몇 틱 굴린 화면. 로그 색·표적선·전황판은 전투가 돌아야 확인된다.
	run.stage_id = 1
	var mid: BattleScreen = load("res://scenes/battle_view.tscn").instantiate()
	root.add_child(mid)
	mid.setup(run)
	mid.speed = 4.0
	mid._start_battle()
	for _i in 150:
		await process_frame
	var n_t := 0
	for u in mid.battle.units:
		if u.alive and u.last_target != null:
			n_t += 1
	print("      표적 보유 유닛 %d / 생존 %d" % [n_t,
		mid.battle.living_count(0) + mid.battle.living_count(1)])
	var img2 := root.get_texture().get_image()
	img2.save_png("%s/11_midbattle.png" % OUT)
	print("  찍음: 11_midbattle")

	# 호버 정보가 유닛보다 위에 그려지는지. 마우스를 못 쓰니 값을 직접 넣는다.
	# _process 가 매 프레임 마우스로 다시 계산하므로 잠시 끈다.
	mid.set_process(false)
	mid.roster_root.set_process(false)
	for u in mid.battle.units:
		if u.alive and u.team == Unit.TEAM_ENEMY:
			mid.hover_unit = u
			break
	mid.top_layer.queue_redraw()
	for _i in 4:
		await process_frame
	root.get_texture().get_image().save_png("%s/12_hover.png" % OUT)
	print("  찍음: 12_hover")
	mid.queue_free()
	await process_frame

	# 궁극기 컷인. 실제로 재생시켜 잘리는 쪽을 눈으로 본다.
	var cut: BattleScreen = load("res://scenes/battle_view.tscn").instantiate()
	root.add_child(cut)
	cut.setup(run)
	cut.speed = 1.0
	cut._cutin("칸타빌레", Color(0.95, 0.85, 0.45), "bard", "cantabile")
	for _i in 380:
		await process_frame
	root.get_texture().get_image().save_png("%s/13_cutin.png" % OUT)
	print("  찍음: 13_cutin")
	cut.queue_free()
	await process_frame

	run.on_stage_cleared(10)
	await _shot("05_reward", load("res://scenes/reward_screen.tscn").instantiate(),
		func(s): s.setup(run, ["musketeer", "assassin", "bard"]))

	# 스토리는 대목마다 그림이 크게 달라서 대표 셋을 찍는다.
	for tag in [["pre", 1, "06_story_intro"], ["post", 3, "07_story_glitch"],
			["pre", 4, "08_story_log"]]:
		var beats := Story.beats(String(tag[0]), int(tag[1]))
		if beats.is_empty():
			continue
		# 연출이 걸린 장면을 골라 찍는다. 첫 장면은 대개 평범한 대사다.
		var pick := 0
		for i in beats.size():
			if String((beats[i] as Dictionary).get("fx", "")) != "":
				pick = i
				break
		await _shot(String(tag[2]), load("res://scenes/story_screen.tscn").instantiate(),
			func(s2): s2.setup(beats); s2.index = pick; s2._show(pick), 6)

	print("=== .shots/ 에 저장 완료 ===")
	quit(0)


## 화면 하나를 띄우고 프레임을 몇 번 돌린 뒤 찍는다.
##
## 프레임을 여러 번 돌리는 이유: 라벨의 최소 크기 계산, 트윈 첫 프레임,
## call_deferred 로 미룬 add_child 가 전부 다음 프레임에 반영된다.
func _shot(name: String, screen: Node, setup: Callable, frames: int = 4) -> void:
	root.add_child(screen)
	setup.call(screen)
	for i in frames:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT, name])
	print("  찍음: %s  (%dx%d)" % [name, img.get_width(), img.get_height()])
	screen.queue_free()
	await process_frame
