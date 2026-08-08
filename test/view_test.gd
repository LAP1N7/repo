extends SceneTree

## 화면 조작 검사. 헤드리스로 실제 노드를 띄워서 "눌리는가" 를 본다.
##
## ── 왜 필요한가 ──────────────────────────────────────────────────────────
## 튜토리얼에서 카드를 눌러도 안 사지는 버그가 났는데, 스크린샷으로는 멀쩡했다.
## 카드는 밝게 강조돼 있고 안내 문구도 정상이고 오류도 없었다. 클릭이 오버레이에
## 먹히고 있다는 건 화면에 절대 안 나타난다.
##
## 규칙 엔진 검사(headless_test)도, 파싱 검사(parse_check)도 이걸 못 잡는다.
## "그려지는가" 와 "눌리는가" 는 다른 문제다.

var pass_n: int = 0
var fail_n: int = 0


func _init() -> void:
	print("=== 화면 조작 검사 ===\n")
	await process_frame
	# await 를 빼먹으면 안 된다. 이 함수들은 안에 await 가 있어서 코루틴이고,
	# 그냥 호출하면 즉시 반환돼 아래 quit() 이 먼저 돌아 검사가 통째로 사라진다.
	# 실제로 그렇게 되어 "1개 검사 / 실패 0개" 라는 거짓 통과가 나왔다.
	await test_overlay_hitbox()
	await test_shop_card_click()
	await test_reward_options()
	await test_gate_lock()
	await test_card_fit()
	await test_sfx()
	await test_death_lag()
	test_music_files()
	await test_unit_scale()
	await test_opening_video()
	await test_typewriter()
	print("\n=== %d개 검사 / 실패 %d개 ===" % [pass_n + fail_n, fail_n])
	quit(1 if fail_n > 0 else 0)


func ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		pass_n += 1
		print("  [PASS] %s" % label)
	else:
		fail_n += 1
		print("  [FAIL] %s  %s" % [label, detail])


## 오버레이는 앵커 위에서만 클릭을 통과시켜야 한다.
func test_overlay_hitbox() -> void:
	print("\n[1] 튜토리얼 오버레이 히트박스")

	var tut := Tutorial.new()
	ok(tut.load_script(), "대본을 읽는다")
	tut.start()

	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)

	# 앵커로 쓸 가짜 버튼.
	var btn := Button.new()
	btn.position = Vector2(400, 300)
	btn.size = Vector2(120, 40)
	host.add_child(btn)

	var ov := TutorialOverlay.new()
	host.add_child(ov)
	ov.setup(tut)
	await process_frame

	ok(ov.size.x > 1000 and ov.size.y > 600,
		"오버레이가 화면 크기를 갖는다 — 0이면 암막도 입력 차단도 안 된다", str(ov.size))

	# 앵커가 없는 대사: 화면 어디든 오버레이가 먹는다.
	tut.anchors.clear()
	ok(ov._has_point(Vector2(460, 320)), "앵커가 없으면 전부 막는다")

	# 앵커를 걸면 그 위만 뚫린다.
	tut.register_anchor(tut.anchor_name() if tut.anchor_name() != "" else "t", btn)
	tut.anchors["__t__"] = btn
	var s := tut.current()
	s["anchor"] = "__t__"

	ok(not ov._has_point(Vector2(460, 320)),
		"앵커 위는 통과시킨다 — 여기서 막으면 지정한 곳을 눌러도 반응이 없다")
	ok(ov._has_point(Vector2(100, 100)), "앵커 밖은 계속 막는다")

	host.queue_free()


## 상점 카드는 BaseButton 이 아니다. 실제로 클릭 신호가 도는지 본다.
func test_shop_card_click() -> void:
	print("\n[2] 상점 카드 클릭")

	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)

	var card := CardNode.new()
	card.position = Vector2(200, 200)
	host.add_child(card)
	await process_frame

	# 정적 타입으로 이미 아는 사실이라 `is` 로는 못 쓴다(파서가 거부한다).
	# 클래스 이름으로 확인한다.
	var base := (card.get_script() as GDScript).get_instance_base_type()
	ok(base != "BaseButton" and base != "Button",
		"카드는 BaseButton 이 아니다 — pressed 를 쏴 주는 방식이 통하지 않는다", base)

	var got: Array = []
	card.clicked.connect(func(n): got.append(n))

	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = card.size * 0.5
	card._on_gui_input(e)

	ok(got.size() == 1, "카드 클릭 신호가 돈다", "%d회" % got.size())

	host.queue_free()


## 보상 화면은 출전한 유닛마다 강화 선택지를 깔아야 한다.
func test_reward_options() -> void:
	print("
[3] 스테이지 보상 선택지")

	var run := RunState.new()
	run.fixed_seed = 1
	run.start_run(1)
	run.on_stage_cleared()

	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)

	var rs := RewardScreen.new()
	host.add_child(rs)
	rs.setup(run, ["archer", "shieldman", "assassin"])
	await process_frame

	var ups: Array[String] = []
	var kinds: Dictionary = {}
	for r in run.pending_rewards:
		kinds[int(r["kind"])] = true
		if int(r["kind"]) == RewardScreen.Kind.UPGRADE:
			ups.append(String(r["type"]))

	# 예전엔 후보 중 무작위로 하나만 깔아서, 누구를 키울지를 게임이 정했다.
	# 유닛마다 강화 곡선을 다르게 만든 의미가 통째로 사라진다.
	ok(ups.size() == 3, "출전 유닛 3종 모두 강화 선택지가 뜬다", str(ups))
	ok(ups.has("archer") and ups.has("shieldman") and ups.has("assassin"),
		"고를 수 있는 유닛이 실제 출전 유닛과 같다", str(ups))

	# 희귀·보급도 함께 떠야 "강화만 계속 먹는" 외길이 안 된다.
	ok(kinds.has(RewardScreen.Kind.RARE), "희귀 보상도 함께 뜬다")
	ok(kinds.has(RewardScreen.Kind.ECONOMY), "보급 보상도 함께 뜬다")

	# 희귀 풀이 비면 안 된다. weight → tier 교체 때 조용히 비었던 자리다.
	var rare_ok := false
	for r in run.pending_rewards:
		if int(r["kind"]) == RewardScreen.Kind.RARE:
			rare_ok = String(r["id"]) != ""
	ok(rare_ok, "희귀 보상에 실제 항목이 들어 있다")

	# 후반 스테이지는 2단계씩 준다.
	run.pending_rewards.clear()
	run.cleared = 4
	var rs2 := RewardScreen.new()
	host.add_child(rs2)
	rs2.setup(run, ["archer"])
	await process_frame
	var late := 1
	for r in run.pending_rewards:
		if int(r["kind"]) == RewardScreen.Kind.UPGRADE:
			late = int(r.get("levels", 1))
	ok(late == 2, "후반 스테이지는 한 번에 2단계 강화", str(late))

	host.queue_free()


## 게이트가 걸린 대사에서 앵커 외의 조작이 실제로 잠기는가.
func test_gate_lock() -> void:
	print("
[4] 튜토리얼 입력 잠금")

	var tut := Tutorial.new()
	tut.load_script()
	tut.start()
	# 상점에서 [교전] 을 사는 대사(gate: true, anchor: shop_card_0)로 이동한다.
	for i in tut.steps.size():
		if String(tut.steps[i].get("id", "")) == "shop_2":
			tut.index = i
	ok(tut.gates_input(), "이 대사는 게이트가 걸려 있다")

	var run := RunState.new()
	run.fixed_seed = 1
	run.start_run(Stages.TUTORIAL_ID)
	run.fixed_offers = ["near_first", "keep_range", "finisher",
		"run_down", "guard_stance"] as Array[String]
	run.offers.clear()
	run._fill_offers()

	var screen := ShopScreen.new()
	root.add_child(screen)
	screen.set("tut", tut)
	screen.setup(run)

	# 게임과 똑같이 CanvasLayer 를 끼워서 붙인다. 이 한 겹이 예전에 _lock 을
	# 통째로 무력화했다 — get_parent() 가 화면이 아니라 CanvasLayer 였기 때문이다.
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	screen.add_child(canvas)
	var ov := TutorialOverlay.new()
	canvas.add_child(ov)
	ov.setup(tut, screen)
	await process_frame
	ov._apply_gate()
	await process_frame

	var anchor := tut.anchor_node()
	ok(anchor != null, "앵커(상점 카드 0)가 등록돼 있다")

	# 앵커 카드 자신은 살아 있어야 한다. 이게 잠기면 살 수가 없다.
	ok(anchor is CardNode and (anchor as CardNode).enabled,
		"앵커 카드는 눌린다")

	# 앵커가 아닌 다른 카드도 잠겨야 한다.
	var others := 0
	var locked := 0
	for name in ["shop_card_1", "shop_card_2"]:
		var n = tut.anchors.get(name)
		if n is CardNode:
			others += 1
			if not (n as CardNode).enabled:
				locked += 1
	ok(others > 0 and locked == others, "앵커가 아닌 카드는 전부 잠긴다",
		"%d/%d" % [locked, others])

	# 리롤·다음 같은 일반 버튼도 잠겨야 한다.
	var rr = tut.anchors.get("shop_reroll")
	ok(rr is BaseButton and (rr as BaseButton).disabled, "리롤 버튼도 잠긴다")

	screen.queue_free()


## 카드 안의 글자가 카드 밖으로 나가지 않는가.
func test_card_fit() -> void:
	print("
[5] 카드 텍스트가 카드 안에 들어가는가")

	# 화면으로는 "좀 넘쳤네" 로 보이지만 실제로는 옆 카드 위에 글자가 얹혀서
	# 둘 다 못 읽는 상태가 된다. 사람 눈으로 매번 확인할 일이 아니다.
	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)

	# ── 블록 레이아웃 기준으로 잰다 ─────────────────────────────────────
	# 세로 카드 시절 좌표(0.42 · line_h 13)로 재고 있었다. 카드가 가로 블록이
	# 되면서 본문 시작점과 줄 높이가 전부 달라졌으므로 여기도 같이 바뀌어야
	# 한다 - 안 그러면 있지도 않은 자리를 재고 통과·실패를 말한다.
	var worst := ""
	var worst_over := 0.0
	for cid in Cards.deck_order() + Specials.ORDER:
		var c: Dictionary = Specials.TABLE[cid] if Specials.TABLE.has(cid) else Cards.TABLE[cid]
		var card := CardNode.new()
		host.add_child(card)
		card.setup(String(cid), 0, true)
		var sz := card.card_size()
		var k: float = sz.x / CardNode.W
		var pad := 14.0 * k
		var text_size: int = int(10.0 * k) + 1
		var line_h := float(text_size) + 3.0
		var f := UiKit.font(11)
		var ty := 53.0 * k
		var body_w := sz.x - pad * 2.0
		var room: float = sz.y - ty - 8.0 * k
		var cap: int = maxi(1, int(room / line_h))

		var parts: PackedStringArray = String(c["text"]).split("→")
		var used := 0
		for idx in 2:
			var t: String = parts[idx].strip_edges() if parts.size() > idx else ""
			if t == "":
				continue
			var lines := 0
			var cur := ""
			for w in t.split(" "):
				var probe := w if cur == "" else cur + " " + w
				if f.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x 						> body_w and cur != "":
					lines += 1
					cur = w
				else:
					cur = probe
			if cur != "":
				lines += 1
			used += mini(lines, 1 if idx == 0 and parts.size() > 1 else cap)
		var over: float = ty + float(used) * line_h - sz.y
		if over > worst_over:
			worst_over = over
			worst = "%s (%.0fpx 넘침)" % [c["name"], over]
		card.queue_free()

	ok(worst_over <= 0.0, "미니 카드 %d종 전부 글자가 안 넘친다"
		% (Cards.deck_order().size() + Specials.ORDER.size()), worst)

	host.queue_free()


## GDScript 에 mini() 가 없어서 직접 쓴다.
func mini(a: int, b: int) -> int:
	return a if a < b else b


## 효과음 슬롯이 전부 소리를 내는가.
func test_sfx() -> void:
	print("
[6] 효과음")

	var bus := Sfx.new()
	root.add_child(bus)
	await process_frame

	# 게임이 실제로 부르는 이름 전부. 하나라도 null 이면 그 순간만 무음이 되는데,
	# 화면에는 아무 표시도 안 나서 눈으로는 절대 못 잡는다.
	var names := ["step", "attack_melee", "attack_ranged", "hit", "death",
		"heal", "special", "defend", "click", "buy", "victory", "defeat", "opening"]
	var missing := ""
	var from_file := 0
	for n in names:
		var st: AudioStream = bus._stream_for(n)
		if st == null:
			missing += n + " "
		elif not (st is AudioStreamWAV) or ResourceLoader.exists(Sfx.DIR + n + ".wav"):
			# 파일에서 온 것인지 합성한 것인지 센다. 둘 다 정상이다.
			if ResourceLoader.exists(Sfx.DIR + n + ".wav") 					or ResourceLoader.exists(Sfx.DIR + n + ".ogg"):
				from_file += 1
	print("      %d종 중 %d종이 파일, 나머지는 합성" % [names.size(), from_file])
	ok(missing == "", "모든 효과음 슬롯이 소리를 낸다", missing)
	ok(from_file > 0, "제공된 파일이 실제로 쓰인다", "%d종" % from_file)

	# 같은 소리를 연속으로 부르면 겹치지 않게 걸러야 한다.
	bus.play("hit")
	var blocked := bus._clock - float(bus._last_at.get("hit", -99.0)) < Sfx.DEDUPE
	ok(blocked, "같은 소리는 짧은 시간 안에 한 번만 난다")

	bus.queue_free()


## ── 규칙의 시간과 화면의 시간 ────────────────────────────────────────────
## battle.step() 은 틱 전체를 한 번에 계산한다. 여섯이 다 움직이고 죽을 사람이
## 다 죽은 다음에야 뷰가 그 틱의 이벤트를 하나씩 재생한다.
##
## 그래서 UnitView 가 Unit.alive 를 직접 보면, 그 틱 어딘가에서 죽은 대원이
## **재생이 시작되기도 전에** 사라진다. 화면에는 빈 칸을 계속 때리고 피해
## 숫자가 뜨는 그림이 남는다 - 실제로 그렇게 보고됐다.
##
## 스크린샷으로는 절대 못 잡는다. 어느 한 장을 봐도 그냥 "빈 칸에 숫자" 이고,
## 그게 틀렸다는 것은 앞뒤 프레임을 알아야만 보인다.
func test_death_lag() -> void:
	print("
[7] 사망 표시가 재생을 앞지르지 않는가")
	var u := Unit.create(0, "warrior", Unit.TEAM_PLAYER, Vector2i(1, 1), [])
	var v := UnitView.new()
	get_root().add_child(v)
	v.setup(u, UiKit.font(11))
	await process_frame

	ok(v.shown_alive(), "처음에는 살아 있는 것으로 보인다")

	# 코어가 먼저 죽인다. 뷰는 아직 그 이벤트를 재생하지 않았다.
	u.alive = false
	await process_frame
	ok(v.shown_alive(),
		"규칙에서 죽어도 재생이 닿기 전에는 화면에 남아 있다")

	# 재생이 사망 이벤트에 닿았다.
	v.view_dead = true
	await process_frame
	ok(not v.shown_alive(), "사망 이벤트를 재생하면 사라진다")
	v.queue_free()


## ── 음원이 실제로 로드되는가 ─────────────────────────────────────────────
## 파일을 넣고 이름만 적어 두면 "있는 줄 알았는데 없는" 상태가 조용히 생긴다.
## 배경음악은 안 나와도 게임이 안 죽으므로 아무도 모른 채 넘어간다 - 실제로
## 그렇게 한참을 갔다.
##
## wav 를 쓰는 이유는 웹이 모든 소리를 Sample 로 재생하기 때문이다. 스트리밍
## 음원(mp3·ogg)은 그 경로에서 소리 없이 죽는다. (core/sfx.gd 주석)
func test_music_files() -> void:
	print("\n[8] 배경음악 음원")
	for name in ["opening_theme", "boss_theme", "story_stage4"]:
		var path := "res://assets/music/%s.wav" % name
		var found := ResourceLoader.exists(path)
		ok(found, "%s.wav 가 있다" % name)
		if not found:
			continue
		var res = load(path)
		ok(res is AudioStream, "%s 가 음원으로 읽힌다" % name)

	# 대본이 부르는 곡이 전부 실재하는가. 이름 오타는 조용히 무음이 된다.
	var missing := ""
	for b in Story.all_beats():
		var m := String((b as Dictionary).get("music", ""))
		if m != "" and not ResourceLoader.exists("res://assets/music/%s.wav" % m):
			missing += m + " "
	ok(missing == "", "대본이 부르는 곡이 전부 있다", missing)


## ── 대원 크기가 직업마다 다르면 안 된다 ──────────────────────────────────
## 예전에는 가로 폭으로 맞춰서, 활을 당겨 세로로 긴 궁수는 81px 이고 도끼를
## 옆으로 벌린 전사는 49px 이었다. 같은 부대인데 한 명이 다른 한 명의 1.65배로
## 보였다.
##
## 스크린샷으로는 안 잡힌다. 한 장만 보면 그냥 "궁수가 좀 크네" 이고, 그게
## 틀렸다는 것은 여섯을 나란히 재 봐야 안다. 그래서 숫자로 못 박는다.
func test_unit_scale() -> void:
	print("\n[9] 대원 크기가 직업마다 같은가")
	var lo := 99999.0
	var hi := 0.0
	var worst := ""
	for tid in UnitData.playable():
		var u := Unit.create(0, tid, Unit.TEAM_PLAYER, Vector2i(1, 1), [])
		var v := UnitView.new()
		get_root().add_child(v)
		v.setup(u, UiKit.font(11))
		await process_frame
		if v.rig != null:
			if v.rig_height < lo:
				lo = v.rig_height
			if v.rig_height > hi:
				hi = v.rig_height
				worst = tid
		v.queue_free()
	ok(hi > 0.0, "리그가 하나라도 붙는다")
	if hi > 0.0:
		ok(hi / lo <= 1.05, "가장 큰 대원이 가장 작은 대원의 1.05배 이내",
			"%.0f ~ %.0f (%s)" % [lo, hi, worst])
		# 칸(81px) 안에 서면서도 충분히 커야 한다.
		ok(hi <= 81.0 and lo >= 60.0, "칸 안에 들어가되 작지 않다",
			"%.0f ~ %.0f" % [lo, hi])


## ── 오프닝 영상 ──────────────────────────────────────────────────────────
## Godot 은 Ogg Theora(.ogv) 만 재생한다. mp4 를 그대로 넣으면 임포트조차 안
## 되는데, 화면은 "영상이 없으면 격자만" 으로 조용히 넘어가므로 아무도 모른다.
## 파일이 실제로 VideoStream 으로 읽히는지 못 박는다.
func test_opening_video() -> void:
	print("\n[10] 오프닝 영상")
	var path := "res://assets/video/opening_scene.ogv"
	var found := ResourceLoader.exists(path)
	ok(found, "opening_scene.ogv 가 있다")
	if not found:
		return
	var res = load(path)
	ok(res is VideoStream, "VideoStream 으로 읽힌다",
		"null" if res == null else res.get_class())

	# 제목 화면이 실제로 붙이는지. 붙였다면 인물(오른쪽)을 안 가리는 자리에
	# 글이 있어야 한다 - 영상만 깔고 배치를 안 바꾸면 얼굴 위에 제목이 얹힌다.
	var t = load("res://scenes/title_screen.tscn").instantiate()
	get_root().add_child(t)
	t.setup()
	await process_frame
	ok(t._video != null, "제목 화면이 영상을 붙인다")
	if t._video != null:
		ok(t._video.position.x + t._video.size.x >= 1280.0,
			"영상이 오른쪽 끝까지 닿는다", str(t._video.position))
		# 인물은 영상 한가운데에 서 있다. 글 기둥의 오른쪽 끝이 거기서
		# 넉넉히 떨어져 있어야 얼굴 위에 글자가 안 얹힌다.
		var face_x: float = t._video.position.x + t._video.size.x * 0.5
		ok(t.TEXT_X + 300.0 < face_x - 100.0,
			"글 기둥이 인물에서 떨어져 있다",
			"글 끝 %d / 인물 %d" % [int(t.TEXT_X + 300.0), int(face_x)])
	t.queue_free()


## ── 타자기 ───────────────────────────────────────────────────────────────
## 대사가 한 글자씩 찍히고, 소리가 같이 나고, 한 번 누르면 다 찍히고 두 번째에
## 넘어간다. 셋 중 하나만 어긋나도 "누르면 대사가 통째로 날아가는" 화면이 된다.
func test_typewriter() -> void:
	print("\n[11] 대사 타자기")
	ok(ResourceLoader.exists("res://assets/sfx/typing.wav"), "타이핑 소리가 있다")

	var s = load("res://scenes/story_screen.tscn").instantiate()
	get_root().add_child(s)
	s.setup([
		{ "speaker": "MIRA", "text": "0123456789012345678901234567890123456789" },
		{ "speaker": "대원 A", "text": "다음" },
	])
	await process_frame
	ok(s._lbl_text.text.length() < 40, "처음에는 다 안 나와 있다",
		str(s._lbl_text.text.length()))

	# 한 번 누르면 나머지가 다 찍힌다.
	s._advance()
	ok(s._lbl_text.text.length() == 40, "한 번 누르면 다 찍힌다",
		str(s._lbl_text.text.length()))
	ok(s.index == 0, "아직 안 넘어간다", str(s.index))

	# 두 번째에 넘어간다.
	s._advance()
	ok(s.index == 1, "두 번 누르면 넘어간다", str(s.index))
	s.queue_free()
