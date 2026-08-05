class_name BattleScreen
extends Node2D

## 3단계 - 전투. 여기서는 아무것도 조작하지 않는다. 결과만 본다.
##
## Battle(코어)은 이 파일을 전혀 모른다. battle.step() 을 한 틱씩 돌리고 그 틱에
## 쌓인 이벤트를 순서대로 재생할 뿐이다. 연출을 아무리 바꿔도 전투 결과는 안 변한다.

signal to_loadout()
signal to_shop()
signal won()

## 튜토리얼이 붙어 있으면 앵커를 등록하고 행동을 알린다.
var tut: Tutorial = null

const BOARD_ORIGIN := Vector2(48, 176)
const TILE: int = Grid.TILE
const ACT_TIME: float = 0.22
const SPEEDS: Array[float] = [1.0, 2.0, 4.0]

## 규칙 패널 한 유닛이 차지하는 높이와 한 줄 높이.
## ROW_H = 헤더 22 + 5줄 × ROW_LINE. 줄이면 다음 유닛 헤더를 덮는다.
const ROW_LINE: float = 18.0
const ROW_H: float = 112.0

const COL_TILE_A := Color(0.16, 0.17, 0.22)
const COL_TILE_B := Color(0.13, 0.14, 0.19)
const COL_PLAYER_ZONE := Color(0.25, 0.5, 0.8, 0.15)
const COL_ENEMY_ZONE := Color(0.8, 0.3, 0.28, 0.15)

enum Phase { READY, PLAYING, RESULT }

var run: RunState
var battle: Battle
var speed: float = 1.0
var phase: int = Phase.READY
var run_id: int = 0

var font: Font

## 효과음. 화면마다 하나씩 만들고, 음소거·볼륨만 Sfx 의 정적 변수로 공유한다.
## (AudioStreamPlayer 는 트리에 들어가 있어야 소리가 나서 화면 자식으로 둔다)
var sfx: Sfx
var btn_sound: Button
var board: Node2D
var fx: Node2D
var ui: Control
var unit_views: Array[UnitView] = []

var lbl_stage: Label
var lbl_tick: Label
var lbl_status: Label
var btn_start: Button
var btn_next: Button
var speed_buttons: Array[Button] = []
var result_panel: Control
var lbl_result: Label
var lbl_result_sub: Label
var rules_root: Control

## 규칙 슬롯 줄의 배경판. 방금 발동한 슬롯을 밝혀서 "어느 규칙이 지금 터졌는지" 를
## 목록 위에서 직접 짚어 준다. key: "%d:%d" % [유닛번호, 슬롯번호] (기본기는 슬롯 -1)
var slot_rows: Dictionary = {}

## 전투 로그. 무슨 일이 왜 일어났는지 글로 남는다.
var log_root: Control
var log_lines: Array[String] = []
var log_label: Label


func setup(p_run: RunState) -> void:
	sfx = Sfx.new()
	add_child(sfx)
	run = p_run
	# UnitView 가 이 폰트로 머리 위 규칙 칩(12px)과 이름을 그린다. 둘 다 작은 글씨다.
	font = UiKit.font(UnitView.CHIP_SIZE)

	board = Node2D.new()
	board.position = BOARD_ORIGIN
	# 세로로 긴 스프라이트는 위 칸을 침범한다. Y 정렬을 켜면 화면 아래쪽 유닛이
	# 항상 앞에 그려져서 앞줄이 뒷줄을 가리는 올바른 겹침이 나온다.
	board.y_sort_enabled = true
	add_child(board)

	fx = Node2D.new()
	fx.position = BOARD_ORIGIN
	add_child(fx)

	_build_ui()
	_reset()

	# 개발용 훅. 무인 재생으로 프레임을 뽑아 백업 영상을 찍을 때 쓴다. (DESIGN D4)
	#   GG_SPEED=2      배속
	#   GG_AUTOSTART=1  화면이 뜨자마자 전투 시작
	if OS.get_environment("GG_SPEED") != "":
		speed = float(OS.get_environment("GG_SPEED"))
		_refresh_ui()
	if OS.get_environment("GG_AUTOSTART") == "1":
		_start_battle()


# ── 그리기 ───────────────────────────────────────────────────────────────

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), UiKit.BG)

	for y in Grid.H:
		for x in Grid.W:
			var r := Rect2(BOARD_ORIGIN + Vector2(x * TILE, y * TILE), Vector2(TILE, TILE))
			draw_rect(r, COL_TILE_A if (x + y) % 2 == 0 else COL_TILE_B)

	for p in Grid.PLAYER_SLOTS:
		draw_rect(Rect2(BOARD_ORIGIN + Vector2(p.x * TILE, p.y * TILE),
			Vector2(TILE, TILE)), COL_PLAYER_ZONE)
	for p in Grid.ENEMY_SLOTS:
		draw_rect(Rect2(BOARD_ORIGIN + Vector2(p.x * TILE, p.y * TILE),
			Vector2(TILE, TILE)), COL_ENEMY_ZONE)

	for x in Grid.W + 1:
		draw_line(BOARD_ORIGIN + Vector2(x * TILE, 0),
			BOARD_ORIGIN + Vector2(x * TILE, Grid.H * TILE), UiKit.LINE, 1.0)
	for y in Grid.H + 1:
		draw_line(BOARD_ORIGIN + Vector2(0, y * TILE),
			BOARD_ORIGIN + Vector2(Grid.W * TILE, y * TILE), UiKit.LINE, 1.0)


func tile_center(p: Vector2i) -> Vector2:
	return Vector2(p.x * TILE + TILE * 0.5, p.y * TILE + TILE * 0.5)


# ── UI ───────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)

	UiKit.phase_header(ui, Vector2(48, 16), 2)
	lbl_stage = UiKit.label(ui, Vector2(48, 56), Vector2(700, 24), "", 14, UiKit.BAD)
	lbl_tick = UiKit.label(ui, Vector2(400, 22), Vector2(160, 24), "", 15, UiKit.MUTED)
	lbl_tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_status = UiKit.label(ui, Vector2(48, 80), Vector2(700, 22), "", 13, UiKit.MUTED)

	var cy := 592.0
	btn_start = UiKit.button(ui, Vector2(48, cy), Vector2(200, 42), UiText.t("battle.start", "▶  전투 시작"), 15)
	btn_start.pressed.connect(_on_start_pressed)
	if tut != null:
		tut.register_anchor("start_button", btn_start)

	UiKit.label(ui, Vector2(260, cy + 11), Vector2(46, 22), UiText.t("battle.speed", "배속"), 13, UiKit.MUTED)
	var sx := 304.0
	for m in SPEEDS:
		var b := UiKit.button(ui, Vector2(sx, cy + 5), Vector2(54, 32), "%dx" % int(m), 14)
		b.pressed.connect(_on_speed_pressed.bind(m))
		speed_buttons.append(b)
		sx += 58.0

	# 소리 토글. 설정은 Sfx 의 정적 변수라 화면을 넘어가도 유지된다.
	btn_sound = UiKit.button(ui, Vector2(sx + 8, cy + 5), Vector2(86, 32), "", 12)
	btn_sound.pressed.connect(func():
		Sfx.enabled = not Sfx.enabled
		_refresh_sound_button()
		# 켜는 순간 한 번 들려 줘야 "켜졌다" 가 확인된다.
		sfx.play("click")
	)
	_refresh_sound_button()

	var b1 := UiKit.button(ui, Vector2(48, cy + 52), Vector2(190, 36), UiText.t("battle.to_loadout", "←  편성 고치기"), 14)
	b1.pressed.connect(func(): to_loadout.emit())
	var b2 := UiKit.button(ui, Vector2(246, cy + 52), Vector2(190, 36), UiText.t("battle.to_shop", "←  덱부터 다시"), 14)
	b2.pressed.connect(func(): to_shop.emit())

	# 이기면 보상 화면으로. 아직 못 이겼으면 숨긴다.
	btn_next = UiKit.button(ui, Vector2(444, cy + 52), Vector2(190, 36), UiText.t("battle.to_reward", "보상 받기  →"), 15)
	btn_next.visible = false
	btn_next.pressed.connect(func(): won.emit())

	rules_root = Control.new()
	rules_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(rules_root)

	# 전투 로그. 규칙 라벨은 0.6초면 사라져서 놓치면 끝이고, 6명이 동시에 움직이면
	# 어차피 다 못 읽는다. 글로 남겨야 "내 전술이 무슨 일을 했는지" 를 따라갈 수 있다.
	log_root = Control.new()
	log_root.position = Vector2(600, 436)
	log_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(log_root)
	UiKit.label(log_root, Vector2(0, 0), Vector2(300, 22), UiText.t("battle.log_head", "전투 로그"), 15, UiKit.MUTED)
	var logbg := Panel.new()
	logbg.position = Vector2(0, 24)
	logbg.size = Vector2(660, 236)
	logbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logbg.add_theme_stylebox_override("panel",
		UiKit.box(Color(0.08, 0.09, 0.12), UiKit.LINE, 5))
	log_root.add_child(logbg)
	log_label = UiKit.label(logbg, Vector2(10, 6), Vector2(640, 224), "", 12)
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# 기본 줄간격이 넓어서 7줄이 패널 밖으로 넘쳐 잘렸다. 좁힌다.
	log_label.add_theme_constant_override("line_spacing", -6)
	if tut != null:
		tut.register_anchor("log_panel", logbg)

	_build_result_panel()


func _build_result_panel() -> void:
	result_panel = Control.new()
	result_panel.position = Vector2(48, 300)
	result_panel.size = Vector2(512, 180)
	result_panel.visible = false
	result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(result_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.045, 0.07, 0.9)
	bg.size = Vector2(512, 180)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_panel.add_child(bg)

	lbl_result = UiKit.label(result_panel, Vector2(0, 34), Vector2(512, 60), "", 46)
	lbl_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_result_sub = UiKit.label(result_panel, Vector2(0, 104), Vector2(512, 30), "", 15, UiKit.MUTED)
	lbl_result_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## 전투 중에는 규칙을 못 바꾸지만, 무엇이 꽂혀 있는지는 계속 보여야 한다.
## 화면에서 벌어지는 일과 규칙 목록을 눈으로 대조하는 게 이 게임의 재미다.
func _build_rules_panel() -> void:
	for c in rules_root.get_children():
		c.queue_free()

	var px := 600.0
	UiKit.label(rules_root, Vector2(px, 20), Vector2(400, 26), UiText.t("battle.rules_head", "출전 규칙"), 20)
	UiKit.label(rules_root, Vector2(px, 48), Vector2(640, 20),
		UiText.t("battle.rules_sub", "위에서부터 처음 맞는 규칙 하나가 실행된다."), 12, UiKit.MUTED)

	var base_names := PackedStringArray()
	for r in Innates.BASE:
		base_names.append(String(r["text"]))
	UiKit.label(rules_root, Vector2(px, 66), Vector2(660, 18),
		UiText.t("battle.m01", "모든 유닛 공통 기본기:  %s") % "   /   ".join(base_names), 10, UiKit.FAINT)

	slot_rows.clear()
	var party := run.to_party()
	# 유닛당 세로 높이는 고정이어야 한다. 특수가 있는 유닛만 한 줄이 더 생기게 두면
	# 그 유닛 블록이 다음 유닛 헤더를 덮는다. 그래서 특수 칸은 비어 있어도 자리를 잡는다.
	#   헤더 22 + (특수 + 슬롯3 + 기본기) 5줄 × 18 = 112
	for i in party.size():
		var y := 96.0 + i * ROW_H
		var s: Dictionary = UnitData.TABLE[party[i]["type"]]
		var up := int(party[i].get("upgrade", 0))
		var first: bool = bool(party[i].get("special_first", false))
		UiKit.label(rules_root, Vector2(px, y), Vector2(560, 20),
			UiText.t("battle.m02", "%s%s   HP %d · 공격 %d · 사거리 %d · 이동 %d") % [
				s["name"], "" if up == 0 else " +%d" % up,
				run.upgraded_stat(party[i]["type"], "hp", int(s["hp"])),
				run.upgraded_stat(party[i]["type"], "atk", int(s["atk"])),
				s["range"], s["move"]], 14)

		var cards: Array = party[i]["cards"]
		var sp: String = String(party[i].get("special", ""))
		var ry := y + 22.0

		# 특수가 "전술보다 먼저" 면 맨 위, 아니면 슬롯 3 아래에 그린다.
		# 화면 순서가 곧 평가 순서여야 한다. 안 그러면 목록을 읽어도 예측이 안 된다.
		if sp != "" and first:
			_slot_row(i, -2, px, ry, "특", String(Specials.TABLE[sp]["name"]),
				String(Specials.TABLE[sp]["text"]), UiKit.ACCENT)
			ry += ROW_LINE

		for k in RunState.SLOTS_PER_UNIT:
			if k < cards.size():
				var c: Dictionary = Cards.TABLE[cards[k]]
				_slot_row(i, k, px, ry, "%d" % (k + 1), String(c["name"]),
					String(c["text"]), UiKit.TEXT)
			else:
				UiKit.label(rules_root, Vector2(px + 10, ry), Vector2(300, 18),
					"%d. -" % (k + 1), 11, UiKit.LINE)
			ry += ROW_LINE

		if sp != "" and not first:
			_slot_row(i, -2, px, ry, "특", String(Specials.TABLE[sp]["name"]),
				String(Specials.TABLE[sp]["text"]), UiKit.ACCENT)
			ry += ROW_LINE
		elif sp == "":
			UiKit.label(rules_root, Vector2(px + 10, ry), Vector2(300, 18),
				UiText.t("battle.m03", "특 -"), 11, UiKit.LINE)
			ry += ROW_LINE

		var own: Array = Innates.TABLE.get(String(party[i]["type"]), [])
		_slot_row(i, -1, px, ry, "기", UiText.t("battle.m04", "기본기"),
			UiText.t("battle.m05", "공통 골격만") if own.is_empty() else String(own[0]["text"]), UiKit.FAINT)


## 규칙 한 줄. 배경판을 깔아 두고 발동할 때 밝힌다.
func _slot_row(unit_i: int, slot: int, px: float, y: float,
		tag: String, name: String, text: String, col: Color) -> void:
	var bgp := Panel.new()
	bgp.position = Vector2(px + 4, y)
	bgp.size = Vector2(660, 19)
	bgp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bgp.add_theme_stylebox_override("panel",
		UiKit.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 3))
	rules_root.add_child(bgp)
	slot_rows["%d:%d" % [unit_i, slot]] = bgp

	UiKit.label(bgp, Vector2(6, 0), Vector2(20, 18), tag, 10, UiKit.MUTED)
	UiKit.label(bgp, Vector2(26, 0), Vector2(96, 18), name, 11, col)
	UiKit.label(bgp, Vector2(126, 0), Vector2(530, 18), text, 11,
		UiKit.TEXT if col != UiKit.FAINT else UiKit.FAINT)


## 그 규칙 줄을 잠깐 밝힌다. 목록 위에서 "지금 이게 터졌다" 를 짚어 주는 장치.
func _flash_slot(unit_i: int, slot: int) -> void:
	var key := "%d:%d" % [unit_i, slot]
	if not slot_rows.has(key):
		return
	var p: Panel = slot_rows[key]
	if not is_instance_valid(p):
		return
	var on := UiKit.box(Color(0.28, 0.34, 0.46), Color(0.6, 0.7, 0.9), 3)
	p.add_theme_stylebox_override("panel", on)
	var tw := create_tween()
	tw.tween_method(func(a: float):
		if is_instance_valid(p):
			var sb := UiKit.box(Color(0.28, 0.34, 0.46, a), Color(0.6, 0.7, 0.9, a), 3)
			p.add_theme_stylebox_override("panel", sb),
		1.0, 0.0, 0.9 / speed)


# ── 전투 로그 ────────────────────────────────────────────────────────────

func _log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 7:
		log_lines.remove_at(0)
	if log_label != null:
		log_label.text = "
".join(log_lines)


func _clear_log() -> void:
	log_lines.clear()
	if log_label != null:
		log_label.text = ""


func _refresh_ui() -> void:
	var st := Stages.get_stage(run.stage_id)
	lbl_stage.text = UiText.t("battle.m06", "스테이지 %d/%d - %s     적 전략: %s") % [
		run.stage_id, Stages.count(), st["name"], st["strategy_text"]]

	# 마지막 스테이지에서도 보상은 받는다. 그 뒤에 런 클리어 화면으로 간다.
	btn_next.visible = phase == Phase.RESULT and battle.result == Battle.RESULT_VICTORY

	for i in speed_buttons.size():
		var m: float = SPEEDS[i]
		speed_buttons[i].modulate = Color(1, 1, 1) if speed == m else Color(0.6, 0.6, 0.66)

	match phase:
		Phase.PLAYING:
			btn_start.text = UiText.t("battle.stop", "■  중단")
			lbl_status.text = st["hint"]
		Phase.RESULT:
			btn_start.text = UiText.t("battle.m07", "▶  같은 규칙으로 다시")
			lbl_status.text = UiText.t("battle.m08", "규칙을 고치려면 아래 '편성 고치기'.")
		_:
			btn_start.text = UiText.t("battle.start", "▶  전투 시작")
			lbl_status.text = st["hint"]


func _reset() -> void:
	run_id += 1
	phase = Phase.READY
	result_panel.visible = false

	# 마지막 일격 연출 도중에 중단/재시작하면 줌과 슬로우가 걸린 채로 남는다.
	# 매 초기화마다 원복해 둔다.
	Engine.time_scale = 1.0
	board.scale = Vector2.ONE
	board.position = BOARD_ORIGIN
	fx.scale = Vector2.ONE
	fx.position = BOARD_ORIGIN
	for c in fx.get_children():
		c.queue_free()

	battle = Battle.new()
	battle.setup(run.stage_id, run.to_party())
	_build_unit_views()
	_build_rules_panel()
	_clear_log()
	lbl_tick.text = UiText.t("battle.m09", "틱 0 / %d") % Battle.MAX_TICKS
	_refresh_ui()
	queue_redraw()


func _build_unit_views() -> void:
	for v in unit_views:
		v.queue_free()
	unit_views.clear()
	for u in battle.units:
		var v := UnitView.new()
		board.add_child(v)
		v.setup(u, font)
		v.position = tile_center(u.pos)
		unit_views.append(v)


func _refresh_sound_button() -> void:
	if btn_sound != null:
		btn_sound.text = UiText.t("battle.sound_on", "소리 켬") if Sfx.enabled else UiText.t("battle.sound_off", "소리 끔")


func _on_start_pressed() -> void:
	if tut != null and phase != Phase.PLAYING:
		tut.notify_action("start")
	if phase == Phase.PLAYING:
		run_id += 1
		phase = Phase.RESULT
		_refresh_ui()
		return
	_reset()
	_start_battle()


func _on_speed_pressed(m: float) -> void:
	speed = m
	_refresh_ui()


# ── 재생 ─────────────────────────────────────────────────────────────────

func _wait(t: float) -> void:
	await get_tree().create_timer(t / speed).timeout


func _start_battle() -> void:
	run_id += 1
	var my_id := run_id
	phase = Phase.PLAYING
	_refresh_ui()

	while my_id == run_id:
		# 튜토리얼이 이 틱을 설명하겠다면 여기서 멈춘다.
		# 대사가 넘어갈 때까지 다음 틱을 진행하지 않는다.
		if tut != null and tut.active and tut.pauses_at_tick(battle.tick + 1):
			await _await_tutorial_step()
			if my_id != run_id:
				return

		var from := battle.events.size()
		var cont := battle.step()
		await _play_events(battle.events.slice(from), my_id)
		if my_id != run_id:
			return
		if not cont:
			break

	phase = Phase.RESULT
	_show_result()
	_refresh_ui()


## 지금 튜토리얼 대사가 넘어갈 때까지 기다린다.
func _await_tutorial_step() -> void:
	var waited := tut.index
	while tut.active and tut.index == waited:
		await get_tree().process_frame


func _play_events(evs: Array, my_id: int) -> void:
	# 이 틱에 전투가 끝난다면, 마지막 사망 하나만 슬로우 + 줌으로 크게 친다.
	# (DESIGN R2 연출 순서 6번) 결과 이벤트는 틱의 모든 행동 뒤에 붙으므로
	# 여기서 미리 훑어 "마지막 일격" 을 특정할 수 있다.
	var final_death := -1
	var ends_here := false
	for e0 in evs:
		if e0["type"] == "result":
			ends_here = true
	if ends_here:
		for i in range(evs.size() - 1, -1, -1):
			if evs[i]["type"] == "death":
				final_death = i
				break

	for idx in evs.size():
		var e: Dictionary = evs[idx]
		if my_id != run_id:
			return
		match e["type"]:
			"tick_begin":
				lbl_tick.text = UiText.t("battle.m10", "틱 %d / %d") % [e["tick"], Battle.MAX_TICKS]

			"rule":
				var innate := bool(e.get("innate", false))
				unit_views[e["unit"]].show_rule(String(e["text"]), innate)
				_flash_slot(int(e["unit"]), int(e["slot"]))
				var who := unit_views[e["unit"]].unit
				var src := UiText.t("battle.m11", "특수") if bool(e.get("special", false)) 					else (UiText.t("battle.m04", "기본기") if innate else UiText.t("battle.m12", "슬롯%d") % (int(e["slot"]) + 1))
				# 구분자로 │(U+2502)를 쓰면 프리텐다드에 글리프가 없어 네모로 뜬다.
				_log(UiText.t("battle.m13", "[틱 %d] %s %s · %s - %s") % [
					battle.tick, "" if who.team == Unit.TEAM_PLAYER else "적",
					who.display_name, src, e.get("rule_name", "")])
				await _wait(ACT_TIME * 0.45)

			"move":
				sfx.play("step")
				var mv := unit_views[e["unit"]]
				var steps: int = maxi(0, (e.get("path", []) as Array).size() - 1)
				_log(UiText.t("battle.m14", "        → %d칸 이동") % steps)
				await _walk(mv, e.get("path", []), e["to"])

			"attack":
				var a := unit_views[e["unit"]]
				var t := unit_views[e["target"]]
				var home := a.position
				var toward := home + (t.position - home).normalized() * 14.0
				# 공격 모션이 있으면 찌르기 시간에 맞춰 한 번 재생한다.
				# 공격과 피격을 나눠 낸다. 하나로 묶으면 "때렸다" 와 "맞았다" 가
				# 구분이 안 돼서 누가 이기고 있는지 소리로는 안 읽힌다.
				# 근접(사거리 1)과 원거리도 가른다.
				sfx.play("attack_melee" if a.unit.atk_range <= 1 else "attack_ranged")
				sfx.play("hit", 0.92 if e["damage"] >= 20 else 1.08)
				var atk_time := ACT_TIME * 0.75 / speed
				a.play_motion(UnitView.ANIM_ATTACK, atk_time)
				var tw2 := create_tween()
				tw2.tween_property(a, "position", toward, ACT_TIME * 0.3 / speed)
				tw2.tween_property(a, "position", home, ACT_TIME * 0.45 / speed)
				t.hit()
				_pop_number(t.position, "-%d" % e["damage"], UiKit.ACCENT)
				_log(UiText.t("battle.m15", "        → %s 에게 %d 피해 (HP %d)") % [
					t.unit.display_name, e["damage"], e["target_hp"]])
				_shake(3.0)
				await tw2.finished
				a.rest_motion()

			"heal":
				sfx.play("heal")
				_pop_number(unit_views[e["target"]].position, "+%d" % e["amount"], UiKit.GOOD)
				await _wait(ACT_TIME * 0.6)

			"special":
				sfx.play("special")
				await _play_special(e)

			"defend":
				sfx.play("defend")
				await _wait(ACT_TIME * 0.4)

			"hold", "idle":
				await _wait(ACT_TIME * 0.2)

			"death":
				# ☠(U+2620)는 프리텐다드에 없어 네모로 떴다. 글리프 검사(test/glyph_check.gd)가
				# 잡아낸다 - 눈으로 찾지 말 것.
				sfx.play("death")
				_log(UiText.t("battle.m16", "        [사망] %s") % unit_views[e["unit"]].unit.display_name)
				if idx == final_death:
					await _finisher(e["unit"])
				else:
					var d := unit_views[e["unit"]]
					_burst(d.position, d.unit.color)
					var tw3 := create_tween()
					tw3.tween_property(d, "scale", Vector2(1.35, 1.35), 0.10 / speed)
					tw3.tween_property(d, "scale", Vector2(1.0, 1.0), 0.14 / speed)
					_shake(7.0)
					await tw3.finished

			"result":
				await _wait(ACT_TIME)


## 특수 스킬 재생. cutin 플래그가 붙은 희귀 스킬만 컷인 연출을 탄다.
##
## 궁극기를 없애고 그 연출을 여기로 옮겼다. 궁극기는 게이지가 찰 때까지 기다려야
## 해서 언제 터질지 예측이 안 됐고, 그래서 영상에 담기도 어려웠다. 특수 스킬은
## 조건이 명시돼 있어 "이 상황에서 터진다" 를 보여줄 수 있다.
func _play_special(e: Dictionary) -> void:
	var sid := String(e.get("skill", ""))
	var has_cutin := sid != "" and Specials.TABLE.has(sid) \
		and bool(Specials.TABLE[sid].get("cutin", false))

	if has_cutin:
		await _cutin(String(e.get("name", "")), unit_views[e["unit"]].unit.color,
			unit_views[e["unit"]].unit.type_id)

	# 이동이 있었으면(후퇴사격·도약) 실제 위치로 옮긴다.
	var v := unit_views[e["unit"]]
	if e["from"] != e["to"]:
		var tw := create_tween()
		tw.tween_property(v, "position", tile_center(e["to"]), ACT_TIME * 0.8 / speed)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tw.finished
	else:
		v.position = tile_center(e["to"])

	for h in e["hits"]:
		unit_views[h["target"]].hit()
		_pop_number(unit_views[h["target"]].position, "-%d" % h["damage"],
			Color(1.0, 0.55, 0.9))
	for hv in e.get("heals", []):
		_pop_number(unit_views[hv["target"]].position, "+%d" % hv["amount"], UiKit.GOOD)

	_shake(10.0 if (e["hits"] as Array).size() > 1 else 5.0)
	await _wait(ACT_TIME)


## 암전 → 스킬 이름 → 플래시.
## TODO(아트): assets/art/cutin/<skill>.png 가 들어오면 여기에 얹는다.
##             지금은 아트 없이도 성립하게 색과 글자만으로 만들어 뒀다. (DESIGN 2.5)
func _cutin(skill_name: String, tint: Color, type_id: String) -> void:
	Engine.time_scale = 0.3

	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.02, 0.04, 0.0)
	veil.size = Vector2(1280, 720)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(veil)

	var band := ColorRect.new()
	band.color = Color(tint.r, tint.g, tint.b, 0.0)
	band.size = Vector2(1280, 4)
	band.position = Vector2(0, 330)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(band)

	# ── 캐릭터 일러스트 (레이어: 암막 위, 글자 아래)
	# assets/art/cutin/<type_id>.png 가 있으면 오른쪽에서 밀려 들어온다.
	# 없으면 색 띠와 글자만으로 성립한다.
	var portrait: TextureRect = null
	var cut_path := "res://assets/art/cutin/%s.png" % type_id
	if ResourceLoader.exists(cut_path):
		var tex := load(cut_path)
		if tex is Texture2D:
			portrait = TextureRect.new()
			portrait.texture = tex
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.size = Vector2(720, 720)
			portrait.position = Vector2(1280, 0)      # 화면 밖에서 출발
			portrait.modulate = Color(1, 1, 1, 0)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ui.add_child(portrait)

	var lbl := UiKit.label(ui, Vector2(0, 300), Vector2(1280, 60), skill_name, 52, Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(veil, "color", Color(0.02, 0.02, 0.04, 0.82), 0.12)
	tw.tween_property(band, "size", Vector2(1280, 96), 0.12)
	tw.tween_property(band, "position", Vector2(0, 284), 0.12)
	tw.tween_property(band, "color", Color(tint.r, tint.g, tint.b, 0.30), 0.12)
	tw.tween_property(lbl, "modulate", Color(1, 1, 1, 1), 0.16)
	if portrait != null:
		tw.tween_property(portrait, "position", Vector2(600, 0), 0.20)			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(portrait, "modulate", Color(1, 1, 1, 1), 0.16)
	await tw.finished
	await get_tree().create_timer(0.30).timeout

	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.size = Vector2(1280, 720)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash)

	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(flash, "color", Color(1, 1, 1, 0.9), 0.08)
	tw2.tween_property(veil, "color", Color(0.02, 0.02, 0.04, 0.0), 0.20)
	tw2.tween_property(band, "color", Color(tint.r, tint.g, tint.b, 0.0), 0.20)
	tw2.tween_property(lbl, "modulate", Color(1, 1, 1, 0), 0.16)
	if portrait != null:
		tw2.tween_property(portrait, "modulate", Color(1, 1, 1, 0), 0.16)
	await tw2.finished

	var tw3 := create_tween()
	tw3.tween_property(flash, "color", Color(1, 1, 1, 0.0), 0.22)
	await tw3.finished

	veil.queue_free()
	band.queue_free()
	lbl.queue_free()
	flash.queue_free()
	if portrait != null:
		portrait.queue_free()
	Engine.time_scale = 1.0


## 경로를 한 칸씩 밟아 이동한다.
##
## 도착점까지 직선으로 보간하면 L자 경로에서 모서리를 가로질러 다른 유닛을
## 뚫고 지나가는 것처럼 보인다. 이동이 2칸이 되면서 실제로 그렇게 보였다.
## path 가 비어 있으면(도약 같은 순간이동) 직선으로 슉 옮긴다.
func _walk(v: UnitView, path: Array, dest: Vector2i) -> void:
	# 걷기 애니메이션은 "한 칸당 한 사이클" 로 속도를 맞춘다.
	# 배속과 이동 칸 수가 바뀌어도 항상 온전한 걸음이 보인다.
	var steps: int = maxi(1, path.size() - 1)
	var per := (ACT_TIME / float(steps)) / speed
	v.play_motion(UnitView.ANIM_WALK, per)
	await _walk_steps(v, path, dest)
	v.rest_motion()


func _walk_steps(v: UnitView, path: Array, dest: Vector2i) -> void:
	if path.size() < 2:
		var tw0 := create_tween()
		tw0.tween_property(v, "position", tile_center(dest), ACT_TIME * 0.7 / speed)			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw0.finished
		return

	var steps := path.size() - 1
	var per := (ACT_TIME / float(steps)) / speed
	var tw := create_tween()
	for i in range(1, path.size()):
		tw.tween_property(v, "position", tile_center(path[i]), per)			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _burst(at: Vector2, col: Color) -> void:
	var b := Burst.new()
	b.position = at
	fx.add_child(b)
	b.setup(col)


## 마지막 일격: 슬로우 + 죽는 유닛으로 줌 + 파티클.
##
## 줌은 board / fx 를 통째로 확대하고, 죽는 지점이 판 한가운데로 오도록 위치를
## 역산해 맞춘다. 이 동안에는 흔들기를 걸지 않는다 - 같은 position 을 두 Tween 이
## 동시에 건드리면 카메라가 튄다.
func _finisher(unit_index: int) -> void:
	var d := unit_views[unit_index]
	var focus := d.position
	var zoom := 1.7
	var center := Vector2(Grid.W * TILE, Grid.H * TILE) * 0.5 + BOARD_ORIGIN
	var zoom_pos := center - focus * zoom

	Engine.time_scale = 0.3

	_burst(focus, d.unit.color)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(board, "scale", Vector2(zoom, zoom), 0.18)
	tw.tween_property(board, "position", zoom_pos, 0.18)
	tw.tween_property(fx, "scale", Vector2(zoom, zoom), 0.18)
	tw.tween_property(fx, "position", zoom_pos, 0.18)

	var pop := create_tween()
	pop.tween_property(d, "scale", Vector2(1.5, 1.5), 0.10)
	pop.tween_property(d, "scale", Vector2(1.0, 1.0), 0.16)

	await tw.finished
	await get_tree().create_timer(0.35).timeout

	var back := create_tween()
	back.set_parallel(true)
	back.tween_property(board, "scale", Vector2.ONE, 0.22)
	back.tween_property(board, "position", BOARD_ORIGIN, 0.22)
	back.tween_property(fx, "scale", Vector2.ONE, 0.22)
	back.tween_property(fx, "position", BOARD_ORIGIN, 0.22)
	await back.finished

	Engine.time_scale = 1.0


func _pop_number(at: Vector2, text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 6)
	l.position = at + Vector2(-20, -46)
	fx.add_child(l)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", l.position + Vector2(0, -30), 0.55 / speed)
	tw.tween_property(l, "modulate", Color(col.r, col.g, col.b, 0.0), 0.55 / speed)
	tw.chain().tween_callback(l.queue_free)


func _shake(amount: float) -> void:
	var tw := create_tween()
	tw.tween_property(board, "position", BOARD_ORIGIN + Vector2(amount, -amount * 0.6), 0.04 / speed)
	tw.tween_property(board, "position", BOARD_ORIGIN + Vector2(-amount * 0.7, amount * 0.4), 0.05 / speed)
	tw.tween_property(board, "position", BOARD_ORIGIN, 0.06 / speed)


func _show_result() -> void:
	result_panel.visible = true
	# 승패는 소리로 먼저 안다. 화면을 안 보고 있어도 결과가 전달돼야 한다.
	sfx.play("victory" if battle.is_won() else "defeat")
	match battle.result:
		Battle.RESULT_VICTORY:
			lbl_result.text = UiText.t("battle.victory", "VICTORY")
			lbl_result.add_theme_color_override("font_color", UiKit.GOOD)
			lbl_result_sub.text = UiText.t("battle.victory_sub", "%d틱에 제압.  아군 %d명 생존.") % [
				battle.tick, battle.living_count(Unit.TEAM_PLAYER)]
		Battle.RESULT_DEFEAT:
			lbl_result.text = UiText.t("battle.defeat", "DEFEAT")
			lbl_result.add_theme_color_override("font_color", UiKit.BAD)
			lbl_result_sub.text = UiText.t("battle.defeat_sub", "%d틱에 전멸.  규칙을 고쳐서 다시.") % battle.tick
		Battle.RESULT_TIMEOUT:
			lbl_result.text = UiText.t("battle.timeout", "TIME OUT")
			lbl_result.add_theme_color_override("font_color", UiKit.ACCENT)
			lbl_result_sub.text = UiText.t("battle.timeout_sub", "%d틱 안에 끝내지 못했다.  적 %d명 생존.") % [
				Battle.MAX_TICKS, battle.living_count(Unit.TEAM_ENEMY)]
