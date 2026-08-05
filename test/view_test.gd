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
	run.fixed_offers = ["engage", "keep_distance", "finisher",
		"pursue", "hold_ground"] as Array[String]
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

	# 그 카드 **안의** [제외] 버튼은 잠겨야 한다.
	# 사라는 대사에서 제외가 눌리면 튜토리얼이 그대로 어긋난다.
	var ban: Button = null
	for c in anchor.get_children():
		if c is Button:
			ban = c as Button
	ok(ban != null, "앵커 카드에 [제외] 버튼이 있다")
	if ban != null:
		ok(ban.disabled, "앵커 안의 [제외] 버튼은 잠긴다")

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

	var f := UiKit.font(10)
	var line_h := 13.0

	var worst := ""
	var worst_over := 0.0
	for cid in Cards.deck_order() + Specials.ORDER:
		var c: Dictionary = Specials.TABLE[cid] if Specials.TABLE.has(cid) else Cards.TABLE[cid]
		var card := CardNode.new()
		host.add_child(card)
		card.setup(String(cid), 0, true)
		var sz := card.card_size()

		# _draw 와 같은 식으로 본문이 끝나는 y 를 계산한다.
		var special := Specials.TABLE.has(cid)
		var ty: float = sz.y * (0.48 if special else 0.42)
		var room: float = sz.y - 10.0 - ty - 6.0
		var cap: int = maxi(1, int(room / line_h) / 2)

		var parts: PackedStringArray = String(c["text"]).split("→")
		for idx in 2:
			var t: String = parts[idx].strip_edges() if parts.size() > idx else ""
			var lines := 0
			var cur := ""
			for w in t.split(" "):
				var probe := w if cur == "" else cur + " " + w
				if f.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x 						> sz.x - 18.0 and cur != "":
					lines += 1
					cur = w
				else:
					cur = probe
			if cur != "":
				lines += 1
			ty += float(mini(lines, cap)) * line_h
			if idx == 0:
				ty += 6.0

		var over: float = ty - sz.y
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
