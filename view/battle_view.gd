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

## 기여도 막대와 숫자가 쓰는 폭. 오른쪽 끝(x=1264)에 붙는다.
const CONTRIB_W: float = 176.0

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

## 대원별 기여도 막대. unit index -> { "bar": ColorRect, "label": Label }
##
## 롤토체스처럼 "누가 실제로 일했는가" 를 한눈에 보여 준다. 이 게임은 조작이
## 없으므로 전투가 끝난 뒤 남는 질문이 "내 알고리즘이 통했는가" 하나뿐인데,
## 로그를 한 줄씩 세는 것 말고는 답할 방법이 없었다.
var contrib_rows: Dictionary = {}

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

	# 이 줄은 x=600(로그 패널) 전에 끝나야 한다. 셋을 176 폭으로 줄이면
	# 48 + 176*3 + 8*2 = 592 로 딱 들어간다.
	var b1 := UiKit.button(ui, Vector2(48, cy + 52), Vector2(176, 36), UiText.t("battle.to_loadout", "←  편성 고치기"), 14)
	b1.pressed.connect(func(): to_loadout.emit())
	var b2 := UiKit.button(ui, Vector2(232, cy + 52), Vector2(176, 36), UiText.t("battle.to_shop", "←  덱부터 다시"), 14)
	b2.pressed.connect(func(): to_shop.emit())

	# 이기면 보상 화면으로. 아직 못 이겼으면 숨긴다.
	btn_next = UiKit.button(ui, Vector2(416, cy + 52), Vector2(176, 36), UiText.t("battle.to_reward", "보상 받기  →"), 15)
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
	contrib_rows.clear()
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

		# ── 기여도 막대 ───────────────────────────────────────────────
		# 헤더 줄 오른쪽 끝, 화면 가장자리에 붙인다.
		#
		# 처음에는 숫자를 막대 **오른쪽**에 뒀는데, 악사처럼 피해와 회복이 둘 다
		# 찍히고 세 자리가 되면 (1070+126+140=1336) 1280 을 넘어 잘렸다.
		# 숫자를 위, 막대를 그 아래에 깔고 둘 다 오른쪽 끝(1264)에 맞춘다.
		# 이러면 자릿수가 늘어나도 왼쪽으로만 자라므로 다시는 안 잘린다.
		var bar_x := 1264.0 - CONTRIB_W
		var clab := UiKit.label(rules_root, Vector2(bar_x, y),
			Vector2(CONTRIB_W, 16), "", 11, UiKit.MUTED)
		clab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		var track := ColorRect.new()
		track.color = Color(0.16, 0.17, 0.21)
		track.position = Vector2(bar_x, y + 16)
		track.size = Vector2(CONTRIB_W, 5)
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rules_root.add_child(track)

		var bar := ColorRect.new()
		bar.color = UiKit.BAD
		bar.position = Vector2(bar_x, y + 16)
		bar.size = Vector2(0, 5)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rules_root.add_child(bar)
		contrib_rows[i] = { "bar": bar, "label": clab }

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
## 대원별 기여도 막대를 갱신한다.
##
## 절대 수치가 아니라 **아군 중 최대치 대비 비율**로 그린다. 전투마다 총 피해량이
## 다르므로 절대 길이로 그리면 어떤 판에서는 전부 꽉 차고 어떤 판에서는 전부
## 비어 보인다. 알고 싶은 것은 "이 대원이 우리 팀에서 얼마나 일했는가" 다.
func _refresh_contrib() -> void:
	if battle == null:
		return
	var top := 1
	for u in battle.units:
		if u.team == Unit.TEAM_PLAYER:
			top = maxi(top, u.damage_dealt + u.healing_done)

	for i in contrib_rows:
		if i >= battle.units.size():
			continue
		var u: Unit = battle.units[i]
		var row: Dictionary = contrib_rows[i]
		var bar: ColorRect = row["bar"]
		var lab: Label = row["label"]
		if not is_instance_valid(bar) or not is_instance_valid(lab):
			continue
		var total := u.damage_dealt + u.healing_done
		bar.size.x = CONTRIB_W * float(total) / float(top)
		# 회복형은 피해가 0이라도 일한 것이다. 색으로 구분한다.
		bar.color = UiKit.GOOD if u.healing_done > u.damage_dealt else UiKit.BAD
		if u.healing_done > 0 and u.damage_dealt > 0:
			lab.text = UiText.t("battle.m17", "피해 %d · 회복 %d") % [
				u.damage_dealt, u.healing_done]
		elif u.healing_done > 0:
			lab.text = UiText.t("battle.m18", "회복 %d") % u.healing_done
		else:
			lab.text = UiText.t("battle.m19", "피해 %d") % u.damage_dealt


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
				_refresh_contrib()

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

	var v := unit_views[e["unit"]]
	if has_cutin:
		# ── 컷인은 내 대원만 ──────────────────────────────────────────────
		# 적 궁극기까지 1.9초짜리 컷인을 물리면 3스테이지처럼 적에게 궁극기가
		# 붙은 판에서 전투가 통째로 멎는다. 게다가 컷인은 "해냈다" 를 보여 주는
		# 연출이라, 당하는 쪽에 쓰면 의미가 반대로 붙는다.
		#
		# 그렇다고 조용히 넘길 수는 없다. 적 회복이 아무 예고 없이 터지면
		# 플레이어는 자기 알고리즘이 왜 안 통했는지 되짚을 단서를 잃는다.
		# 무슨 기술이 터졌는지만 그 자리에 짧게 띄운다.
		if v.unit.team == Unit.TEAM_PLAYER:
			await _cutin(String(e.get("name", "")), v.unit.color, v.unit.type_id)
		else:
			await _enemy_special_tag(v, String(e.get("name", "")))

	# 이동이 있었으면(후퇴사격·도약) 실제 위치로 옮긴다.
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


## 궁극기 컷인. 좌측 30% 에 일러스트, 우측에 기술 이름.
##
## ── 참조: 세븐나이츠류 턴제 MMORPG ──────────────────────────────────
## 그쪽 궁극기 연출을 뜯어 보면 네 가지가 항상 같이 온다.
##   1) 사선 프레임   일러스트 판이 직사각형이 아니라 기울어진 평행사변형이다.
##                   화면을 가로로 반듯하게 자르지 않아서 정지 화면처럼 안 보인다.
##   2) 방사 집중선   인물 뒤에서 바깥으로 터져 나간다. 시선이 얼굴에 박힌다.
##   3) 줌 인 착지     판이 살짝 큰 상태로 들어와 제자리로 조여든다.
##                   "쾅" 하고 멈추는 무게가 여기서 나온다.
##   4) 색 잔상       본 판 뒤로 직업 색 판이 어긋나 깔린다. 잔상처럼 읽힌다.
## 넷 다 넣었다. 하나만 빼도 그냥 그림이 뜬 것처럼 밋밋해진다.
##
## ── 왜 시간이 실초로 흐르는가 ────────────────────────────────────────
## 예전에는 Engine.time_scale 을 0.3 으로 내려놓고 그 아래에서 트윈을 돌렸다.
## 트윈도 같이 3.3배 느려지므로 0.12초라고 적은 연출이 실제로는 0.4초 걸렸고,
## 전체가 1초에 육박해 "무겁다" 가 아니라 "느리다" 가 됐다.
## 지금은 배경만 늦추고(뒤에서 유닛이 천천히 움직이는 맛), 컷인 자체는
## set_ignore_time_scale 로 실초를 쓴다. 여기 적힌 숫자가 곧 보이는 시간이다.
##
## ── 도입부: 카메라가 훑는다 ──────────────────────────────────────────
## 판이 그냥 슬라이드해 들어오면 "그림이 떴다" 로 끝난다. 앞에 카메라 이동을
## 세 박자 붙이면 같은 그림이 "무언가 벌어지고 있다" 가 된다.
##   1) 무기 끝     총구·화살촉·칼끝. 이름을 읽기 전에 누구 궁극긴지 알린다
##   2) 얼굴로 위로  같은 인물이라는 것이 이 이동 하나로 이어 붙는다
##   3) 눈 확대     가장 좁은 화각. 여기서 멈췄다가 번쩍이며 터진다
## 지점은 data/cutin_shots.gd 에 있다. 여기서 수치를 잡으면 일러스트를 갈 때마다
## 연출 코드를 고쳐야 한다.
##
## 도입부 1.11초 + 공개 1.53초 = 총 2.6초. 절반 이상이 이름을 읽는 시간이다.
const CUTIN_X: float = 384.0        ## 1280 의 30%. 일러스트가 차지하는 폭.
const CUTIN_SKEW: float = 44.0      ## 사선 프레임의 기울기(위가 넓고 아래가 좁다).
const CUTIN_ART: Vector2 = Vector2(600, 900)

func _cutin(skill_name: String, tint: Color, type_id: String) -> void:
	Engine.time_scale = 0.35

	var layer := Control.new()
	layer.size = Vector2(1280, 720)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(layer)

	# ── 암막 ─────────────────────────────────────────────────────────────
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.02, 0.04, 0.0)
	veil.size = Vector2(1280, 720)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(veil)

	# ── 도입부: 무기 → 얼굴 → 눈 ─────────────────────────────────────────
	# 아트가 없으면 통째로 건너뛴다. 훑을 것이 없는데 카메라만 움직이면
	# 빈 화면이 1초 가까이 흐른다.
	var shot_tex := UiKit.art(["cutin", "standing"], type_id)
	if shot_tex != null:
		await _cutin_intro(layer, shot_tex, CutinShots.of(type_id), tint)

	# ── 2) 우측 전술 HUD ─────────────────────────────────────────────────
	# 예전에는 방사 집중선을 깔았는데, 이름이 뜨는 자리와 정면으로 겹쳐서
	# 글자를 읽는 동안 선이 계속 지나갔다. 읽을 것이 있는 구역에 움직이는
	# 것을 두면 안 된다. 대신 얇은 육각형 HUD 를 깔았다 - 이 게임은 대원을
	# 조종하는 게 아니라 판단 규칙을 짜는 쪽이라, 전술 계기판 톤이 맞는다.
	var hud := _CutinHud.new()
	hud.size = Vector2(1280, 720)
	hud.tint = tint
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.modulate.a = 0.0
	layer.add_child(hud)

	# 불티. 오른쪽 아래에서 위로 천천히 흐른다. 정지 화면이 되는 것만 막으면 된다.
	var spark := CPUParticles2D.new()
	spark.position = Vector2(900, 760)
	spark.amount = 40
	spark.lifetime = 1.6
	spark.explosiveness = 0.0
	spark.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	spark.emission_rect_extents = Vector2(340, 12)
	spark.direction = Vector2(0, -1)
	spark.spread = 14.0
	spark.gravity = Vector2.ZERO
	spark.initial_velocity_min = 90.0
	spark.initial_velocity_max = 240.0
	spark.scale_amount_min = 1.0
	spark.scale_amount_max = 2.6
	spark.color = Color(tint.r, tint.g, tint.b, 0.55)
	layer.add_child(spark)

	# ── 1)+4) 사선 프레임 + 색 잔상 ────────────────────────────────────────
	# 판을 Node2D 로 만든다. 평행사변형은 Control 로는 못 오려낸다
	# (clip_contents 는 직사각형만 자른다). Polygon2D 로 모양을 직접 준다.
	var frame := Node2D.new()
	frame.position = Vector2(-CUTIN_X - CUTIN_SKEW, 0)   # 화면 밖 왼쪽에서 출발
	frame.scale = Vector2(1.06, 1.06)                    # 3) 큰 상태로 시작
	layer.add_child(frame)

	var shape := PackedVector2Array([
		Vector2(0, 0), Vector2(CUTIN_X + CUTIN_SKEW, 0),
		Vector2(CUTIN_X - CUTIN_SKEW, 720), Vector2(0, 720),
	])

	# 4) 잔상: 같은 모양을 직업 색으로 어긋나게 깐다.
	var ghost := Polygon2D.new()
	ghost.polygon = shape
	ghost.color = Color(tint.r, tint.g, tint.b, 0.55)
	ghost.position = Vector2(26, -10)
	frame.add_child(ghost)

	# 바탕판. 아트가 없어도 이 판만으로 자리가 읽힌다.
	var plate := Polygon2D.new()
	plate.polygon = shape
	plate.color = Color(tint.r * 0.30, tint.g * 0.30, tint.b * 0.30, 0.95)
	frame.add_child(plate)

	var tex := UiKit.art(["cutin", "standing"], type_id)
	if tex != null:
		# 판을 꽉 채우도록 아트를 확대하고(COVER), 남는 좌우는 폴리곤이 잘라 준다.
		var box := Vector2(CUTIN_X + CUTIN_SKEW, 720.0)
		var k: float = maxf(box.x / CUTIN_ART.x, box.y / CUTIN_ART.y)
		var off := (box - CUTIN_ART * k) * 0.5
		var uv := PackedVector2Array()
		for pt in shape:
			uv.append((pt - off) / k)
		var art := Polygon2D.new()
		art.polygon = shape
		art.uv = uv
		art.texture = tex
		frame.add_child(art)

	# 사선 모서리. 직업 색이라 글자를 안 읽어도 누구 궁극긴지 색으로 먼저 읽힌다.
	var edge := Line2D.new()
	edge.points = PackedVector2Array([shape[1], shape[2]])
	edge.width = 5.0
	edge.default_color = Color(tint.r, tint.g, tint.b, 1.0)
	frame.add_child(edge)

	# ── 우측: 기술 이름 ──────────────────────────────────────────────────
	# 이름판은 사선, 글자는 수평이다. 글자까지 기울이면 읽는 데 시간이 걸린다.
	var name_x := CUTIN_X + 72.0
	var bw := 1280.0 - name_x - 36.0
	var band := Node2D.new()
	band.position = Vector2(name_x, 296)
	band.scale = Vector2(0.0, 1.0)          # 왼쪽에서 오른쪽으로 펴진다
	layer.add_child(band)
	# 끝을 크게 깎는다. 14px 로는 그냥 직사각형으로 보였다.
	# 왼쪽은 아래를, 오른쪽은 위를 깎아 평행사변형이 아니라 비스듬한 띠가 된다.
	var band_shape := PackedVector2Array([
		Vector2(46, 0), Vector2(bw, 0), Vector2(bw - 46, 92), Vector2(0, 92),
	])
	var bandpoly := Polygon2D.new()
	bandpoly.polygon = band_shape
	bandpoly.color = Color(tint.r * 0.5, tint.g * 0.5, tint.b * 0.5, 0.55)
	band.add_child(bandpoly)

	# 노이즈. 단색 판은 아무리 기울여도 평평해 보인다. 아주 옅게 얹으면
	# 같은 색이 재질을 얻는다.
	var grain := Polygon2D.new()
	grain.polygon = band_shape
	grain.texture = _noise_tex()
	grain.texture_scale = Vector2(0.5, 0.5)
	grain.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	grain.color = Color(1, 1, 1, 0.16)
	band.add_child(grain)

	# 위아래 얇은 선. 띠의 사선이 어디서 끝나는지 눈에 걸리게 한다.
	for edge_pts in [[band_shape[0], band_shape[1]], [band_shape[3], band_shape[2]]]:
		var ln := Line2D.new()
		ln.points = PackedVector2Array(edge_pts)
		ln.width = 2.0
		ln.default_color = Color(tint.r, tint.g, tint.b, 0.85)
		band.add_child(ln)

	var lbl := Label.new()
	lbl.text = skill_name
	lbl.position = Vector2(name_x + 96.0, 302)      # 오른쪽에서 밀려 들어온다
	lbl.size = Vector2(bw - 40.0, 80)
	lbl.add_theme_font_override("font", UiKit.title_font())
	lbl.add_theme_font_size_override("font_size", 64)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_shadow_color", Color(tint.r, tint.g, tint.b, 0.95))
	lbl.add_theme_constant_override("shadow_offset_x", 4)
	lbl.add_theme_constant_override("shadow_offset_y", 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 크게 나타났다가 줄어드는 연출을 하려면 기준점이 글자 한가운데여야 한다.
	# 기본값(왼쪽 위)이면 커질 때 오른쪽 아래로 밀려 나간다.
	lbl.pivot_offset = Vector2(60, 40)
	lbl.scale = Vector2(1.18, 1.18)
	layer.add_child(lbl)

	# 누구 궁극기인지. 색만으로는 여섯 직업을 다 못 가른다.
	var unit_name := String(UnitData.TABLE.get(type_id, {}).get("name", ""))
	var sub := UiKit.label(layer, Vector2(name_x + 30.0, 266), Vector2(bw, 22),
		unit_name, 14, Color(1, 1, 1, 0.85))
	sub.modulate.a = 0.0

	# ── 들어온다 (0.34초) ────────────────────────────────────────────────
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(veil, "color", Color(0.02, 0.02, 0.04, 0.86), 0.08)
	tw.tween_property(frame, "position", Vector2.ZERO, 0.18)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# 3) 줌 인 착지. 이동보다 길게 끌어 멈춘 뒤에도 아주 잠깐 더 조여든다.
	tw.tween_property(frame, "scale", Vector2.ONE, 0.34)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "position", Vector2(10, -4), 0.30)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(band, "scale", Vector2.ONE, 0.14)\
		.set_delay(0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position", Vector2(name_x + 30.0, 302), 0.20)\
		.set_delay(0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate", Color(1, 1, 1, 1), 0.12)\
		.set_delay(0.06).from(Color(1, 1, 1, 0))
	tw.tween_property(sub, "modulate", Color(1, 1, 1, 1), 0.12).set_delay(0.12)
	# 궁극기다. 큰 채로 0.1초 버틴 다음 제자리로 줄어든다.
	# 바로 줄이면 그냥 튀어나온 글자가 되고, 버티는 동안만 "크다" 가 읽힌다.
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.16)\
		.set_delay(0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(hud, "modulate", Color(1, 1, 1, 1), 0.16).set_delay(0.08)
	await tw.finished

	# 이름이 뜬 채 머무는 시간. 도입부에서 이미 충분히 뜸을 들였으므로 짧게 끊는다.
	# 이름이 뜬 채 머무는 시간.
	#
	# 0.10 이었을 때는 이름이 보이는 구간이 다 합쳐 0.5초쯤이라 읽기 전에
	# 사라졌다. 여기만 늘리면 앞뒤 연출은 그대로 두고 읽는 시간만 벌 수 있다.
	await get_tree().create_timer(0.85, true, false, true).timeout

	# ── 나간다 (0.20초) ──────────────────────────────────────────────────
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.size = Vector2(1280, 720)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)

	var tw2 := create_tween()
	tw2.set_ignore_time_scale(true)
	tw2.set_parallel(true)
	tw2.tween_property(flash, "color", Color(1, 1, 1, 0.9), 0.05)
	tw2.tween_property(frame, "position", Vector2(-CUTIN_X - CUTIN_SKEW, 0), 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw2.tween_property(band, "scale", Vector2(0.0, 1.0), 0.12)
	tw2.tween_property(lbl, "modulate", Color(1, 1, 1, 0), 0.10)
	tw2.tween_property(sub, "modulate", Color(1, 1, 1, 0), 0.08)
	tw2.tween_property(veil, "color", Color(0.02, 0.02, 0.04, 0.0), 0.20)
	tw2.tween_property(hud, "modulate", Color(1, 1, 1, 0), 0.12)
	tw2.tween_property(spark, "modulate", Color(1, 1, 1, 0), 0.12)
	await tw2.finished

	var tw3 := create_tween()
	tw3.set_ignore_time_scale(true)
	tw3.tween_property(flash, "color", Color(1, 1, 1, 0.0), 0.14)
	await tw3.finished

	layer.queue_free()
	Engine.time_scale = 1.0


## 컷인 도입부. 무기 끝 → 얼굴 → 눈 순서로 카메라가 훑고 번쩍인다.
##
## 카메라는 없다. 아트를 크게 키워 놓고 위치를 옮기는 것이 전부다. 보여 줄
## 지점 p(정규화)를 화면 한가운데에 놓으려면 아트를 그 반대로 밀면 된다.
func _cutin_intro(layer: Control, tex: Texture2D, shot: Dictionary,
		tint: Color) -> void:
	var view := Control.new()
	view.size = Vector2(1280, 720)
	view.clip_contents = true          # 확대된 아트가 화면 밖으로 새는 것을 막는다
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(view)

	var art := TextureRect.new()
	art.texture = tex
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.size = CUTIN_ART
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(art)

	# 위아래 검은 띠. 화각이 좁다는 신호이자, 확대된 아트의 위아래 끝을 가린다.
	var bars: Array[ColorRect] = []
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color(0.02, 0.02, 0.04, 1.0)
		bar.size = Vector2(1280, 0)
		bar.position = Vector2(0, 0 if i == 0 else 720)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.add_child(bar)
		bars.append(bar)

	var weapon: Vector2 = shot["weapon"]
	var eye: Vector2 = shot["eye"]
	# 얼굴은 눈보다 조금 아래를 잡는다. 눈만 노리면 턱이 잘려 얼굴로 안 읽힌다.
	var face := Vector2(eye.x, eye.y + 0.055)

	_cam(art, weapon, 4.6)

	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(bars[0], "size", Vector2(1280, 76), 0.12)
	tw.parallel().tween_property(bars[1], "position", Vector2(0, 644), 0.12)
	tw.parallel().tween_property(bars[1], "size", Vector2(1280, 76), 0.12)

	# 1) 무기 끝. 완전히 정지시키지 않고 아주 천천히 밀어 준다.
	#    멈춘 그림은 정지 화면으로 읽히고, 조금이라도 흐르면 살아 있는 것으로 읽힌다.
	tw.parallel()
	_cam_to(tw, art, weapon, 4.2, 0.34, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)

	# 2) 얼굴까지 위로. 이 구간이 가장 길다 - 두 지점이 한 인물이라는 것을
	#    이어 붙이는 게 목적이라, 끊기면 딴 그림 두 장으로 보인다.
	_cam_to(tw, art, face, 3.4, 0.44, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)

	# 3) 눈. 짧고 세게 박는다.
	_cam_to(tw, art, eye, 5.4, 0.26, Tween.TRANS_EXPO, Tween.EASE_OUT)
	await tw.finished

	# 번쩍. 이 흰 화면이 도입부와 전체 공개 사이의 이음매를 덮는다.
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.size = Vector2(1280, 720)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)

	var tw2 := create_tween()
	tw2.set_ignore_time_scale(true)
	tw2.set_parallel(true)
	tw2.tween_property(flash, "color", Color(1, 1, 1, 1.0), 0.07)
	tw2.tween_property(art, "modulate", Color(1, 1, 1, 0), 0.07)
	await tw2.finished

	view.queue_free()

	# 흰 화면을 남긴 채 돌려준다. 뒤이어 판이 들어오는 동안 이게 걷힌다.
	var tw3 := create_tween()
	tw3.set_ignore_time_scale(true)
	tw3.tween_property(flash, "color", Color(tint.r, tint.g, tint.b, 0.0), 0.18)
	tw3.tween_callback(flash.queue_free)


## 아트를 지점 p(정규화)가 화면 한가운데 오도록 즉시 옮긴다. z 는 배율.
func _cam(art: Control, p: Vector2, z: float) -> void:
	var k := (720.0 / CUTIN_ART.y) * z
	art.scale = Vector2(k, k)
	art.position = _cam_pos(p, k)


## 같은 계산을 트윈으로. 배율과 위치는 반드시 같은 시간·같은 곡선이어야 한다 -
## 하나만 어긋나면 확대하면서 화면이 미끄러진다.
func _cam_to(tw: Tween, art: Control, p: Vector2, z: float, sec: float,
		trans: Tween.TransitionType, ease_t: Tween.EaseType) -> void:
	var k := (720.0 / CUTIN_ART.y) * z
	tw.tween_property(art, "scale", Vector2(k, k), sec).set_trans(trans).set_ease(ease_t)
	tw.parallel().tween_property(art, "position", _cam_pos(p, k), sec)\
		.set_trans(trans).set_ease(ease_t)


## 지점 p 를 화면 한가운데 두되, 아트 바깥이 보이지 않도록 안으로 당긴다.
##
## 아트 가장자리를 찍으면 화면 절반이 빈 채로 뜬다. 4.6배로 당겼을 때 보이는
## 폭이 원화의 348px 뿐이라, 정규화 0.9 같은 값은 물리적으로 화면 안에 못 온다.
## 데이터를 잘 잡는 게 우선이지만(data/cutin_shots.gd), 일러스트를 교체하면
## 좌표는 그대로 두고 그림만 바뀌기 마련이라 여기서도 한 번 막는다.
## 옅은 노이즈 텍스처. 한 번 만들어 두고 계속 쓴다.
##
## 난수를 쓰지 않는다. 고정 시드 LCG 라 실행할 때마다 같은 무늬가 나온다 -
## 이 프로젝트는 전투가 완전히 결정론적이고, 화면도 같은 규칙을 따른다.
static var _noise_cache: ImageTexture = null

static func _noise_tex() -> ImageTexture:
	if _noise_cache != null:
		return _noise_cache
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var seed_v: int = 987654321
	for y in n:
		for x in n:
			seed_v = (seed_v * 1103515245 + 12345) & 0x7FFFFFFF
			var v := float(seed_v % 256) / 255.0
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	_noise_cache = ImageTexture.create_from_image(img)
	return _noise_cache


## 컷인 오른쪽에 까는 전술 HUD.
##
## 얇은 육각형 격자와 모서리 괄호, 눈금. 화면을 채우는 게 목적이 아니라
## "여기는 계기판이다" 를 깔아 주는 것이 목적이라 선은 최대한 가늘게 둔다.
## 굵어지는 순간 이름을 읽는 데 방해가 된다.
class _CutinHud extends Control:
	var tint: Color = Color.WHITE

	func _draw() -> void:
		var c := Color(tint.r, tint.g, tint.b, 0.30)
		var faint := Color(tint.r, tint.g, tint.b, 0.14)

		# 육각 격자. 오른쪽 위와 오른쪽 아래, 글자 줄(y 266~394)은 피한다.
		for band_y in [120.0, 470.0]:
			for i in 7:
				var cx := 560.0 + i * 104.0
				for j in 2:
					_hex(Vector2(cx + (52.0 if j == 1 else 0.0),
						band_y + j * 60.0), 34.0, faint)

		# 모서리 괄호. 화면 오른쪽이 한 덩어리로 묶인 것처럼 보이게 한다.
		var box := Rect2(548, 88, 700, 552)
		for corner in [
			[box.position, Vector2(1, 0), Vector2(0, 1)],
			[Vector2(box.end.x, box.position.y), Vector2(-1, 0), Vector2(0, 1)],
			[Vector2(box.position.x, box.end.y), Vector2(1, 0), Vector2(0, -1)],
			[box.end, Vector2(-1, 0), Vector2(0, -1)],
		]:
			var o: Vector2 = corner[0]
			draw_line(o, o + corner[1] * 46.0, c, 2.0)
			draw_line(o, o + corner[2] * 46.0, c, 2.0)

		# 눈금. 오른쪽 세로선에 일정 간격으로 짧게.
		for i in 13:
			var y := 108.0 + i * 44.0
			var w := 16.0 if i % 3 == 0 else 8.0
			draw_line(Vector2(1240, y), Vector2(1240 - w, y), faint, 1.0)

	func _hex(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 7:
			var a := TAU * float(i) / 6.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, col, 1.0)


func _cam_pos(p: Vector2, k: float) -> Vector2:
	var half := Vector2(640.0, 360.0) / k              # 보이는 영역의 절반(원화 픽셀)
	var lo := half / CUTIN_ART
	var q := Vector2(
		clampf(p.x, minf(lo.x, 0.5), maxf(1.0 - lo.x, 0.5)),
		clampf(p.y, minf(lo.y, 0.5), maxf(1.0 - lo.y, 0.5)))
	return Vector2(640, 360) - Vector2(q.x * CUTIN_ART.x, q.y * CUTIN_ART.y) * k


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


## 적 궁극기 표시. 컷인 대신 쓰는 짧은 연출이다. (위 _play_special 주석 참조)
##
## 0.5초. 유닛 위에 기술 이름이 붉게 떠올랐다 사라지고 화면이 한 번 흔들린다.
## "뭔가 큰 게 터졌다" 와 "그게 무엇이었나" 만 전달되면 충분하다.
func _enemy_special_tag(v: UnitView, skill_name: String) -> void:
	var l := Label.new()
	l.text = skill_name
	l.add_theme_font_override("font", UiKit.title_font())
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", UiKit.BAD)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 7)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(220, 28)
	l.position = v.position + Vector2(-110, -62)
	l.pivot_offset = Vector2(110, 14)
	l.scale = Vector2(1.25, 1.25)
	l.modulate.a = 0.0
	fx.add_child(l)

	_shake(7.0)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "modulate", Color(1, 1, 1, 1), 0.08 / speed)
	tw.tween_property(l, "scale", Vector2.ONE, 0.16 / speed)		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position", l.position + Vector2(0, -18), 0.50 / speed)		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(l, "modulate", Color(1, 1, 1, 0), 0.14 / speed)
	await tw.finished
	l.queue_free()


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
