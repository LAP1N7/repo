class_name LoadoutScreen
extends Control

## 2단계 - 편성 · 자리 지정 · 규칙 장착.
##
## 조작 문법을 하나로 통일했다: "왼쪽에서 대상을 고르고, 그 다음 붙일 것을 누른다."
## 유닛 배치도 카드 장착도 같은 문법이라 새로 배울 게 없다. (DESIGN 2.2.1)
##
## 손패는 화면 바닥을 통째로 쓴다. 카드가 9장까지 늘어나므로 다른 위젯과
## 세로로 겹치지 않게 이 구역은 비워 둔다.

signal fight()
signal back()

## 튜토리얼이 붙어 있으면 앵커를 등록하고 행동을 알린다.
var tut: Tutorial = null

const TILE: float = 62.0
## 배치 격자. 제목·대원 선택과 같은 왼쪽 선에 맞춘다.
##
## 가운데로 옮겨 봤는데, 이 화면의 왼쪽 칸은 제목 -> 격자 -> 대원 선택이
## 위에서 아래로 읽히는 한 덩어리다. 가운데 것 하나만 들여쓰면 그 줄기가 끊긴다.
const GRID_AT := Vector2(48, 124)
const RIGHT_X: float = 560.0
## ── 보유 모듈 줄 ────────────────────────────────────────────────────────
## 화면 맨 아래를 가로로 다 쓴다. 명일방주 하단 오퍼레이터 바와 같은 자리이고,
## 같은 이유다 - **고르는 것**은 늘 바닥에 있고 위는 판이다.
##
## 500 으로 올렸다가 오른쪽 모듈 슬롯 3번째 대원 행(바닥 y=534)을 카드가
## 덮었다. 화면 아래가 비어 보인다고 올렸던 것인데, 비어 보이는 것보다
## 가려지는 쪽이 훨씬 나쁘다. 대원 선택 칸을 키워 그 여백을 대신 채운다.
## 얼굴 칸이 y=352 에서 시작해 100 높이로 끝나면 452 다. 거기서 여백 한 뼘만
## 두고 바로 잇는다 - 사이가 비면 화면이 두 동강 난 것처럼 보인다.
const HAND_Y: float = 530.0

## 유닛 한 명이 차지하는 세로 높이. 헤더 28 + 슬롯 3×27 + 기본기 줄 18 + 여백.
## 줄이면 기본기 줄이 다음 유닛 헤더를 덮는다.
## 오른쪽 모듈 슬롯 3인분이 손패 위에서 끝나야 한다.
##   ROSTER_Y + ROW_H*2 + 128(행 바닥) <= HAND_Y - 26(손패 머리)
##   124 + 260 + 128 = 512 <= 504 ... 이 아니라 512 이므로 행 바닥이 머리와
##   8px 겹친다. 머리글은 x=48 에서 시작하고 슬롯은 x=560 부터라 가로로는
##   안 만난다.
const ROSTER_Y: float = 124.0
## ── 행 내부 간격 ────────────────────────────────────────────────────────
## 대원 3명이 보유 목록(HAND_Y-30 = 542) 위에 다 들어가야 한다.
##
##   행 시작        y
##   슬롯 3칸       y+30, y+55, y+80   (높이 24)
##   기본 알고리즘   y+110              (높이 18)  -> 행 바닥 y+128
##
## ROSTER_Y(138) + ROW_H*2 + 128 <= 542 이어야 하므로 ROW_H 는 최대 134 다.
## 그리고 ROW_H 는 행 바닥(128)보다 커야 행끼리 안 겹친다.
## 판 하나가 담아야 하는 것: 머리줄(28) + 슬롯 3칸(30~104) + 기본기 줄.
## 기본기 줄이 판 밖으로 삐져나가면 판으로 감싼 의미가 없다.
const ROW_H: float = 140.0
const SLOT_H: float = 24.0
const SLOT_STEP: float = 25.0
const INNATE_DY: float = 106.0

var run: RunState

var sel_type: String = ""     # 배치하려고 고른 유닛 종류
var sel_member: int = -1      # 카드를 꽂을 대상 유닛

var type_buttons: Dictionary = {}
var grid_root: Control
var roster_root: Control
var hand_root: Control
var lbl_warn: Label
var btn_fight: Button


func setup(p_run: RunState) -> void:
	run = p_run
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Arknights 계열의 인상은 장식이 아니라 **정렬**에서 온다. 얇은 가로선 하나가
	# 화면 위를 가로지르면 아래 요소가 전부 그 선에 맞춰 정렬된 것처럼 읽힌다.
	UiKit.frame(self, Axes.color(Axes.POSITION))

	UiKit.phase_header(self, Vector2(48, 18), 1)
	UiKit.label(self, Vector2(48, 58), Vector2(820, 22),
		UiText.t("loadout.sub", "유닛을 고르고 진영의 빈 칸을 누른다. 그 다음 유닛을 골라 손패의 카드를 꽂는다."),
		13, UiKit.MUTED)

	# 조작 버튼은 위로 올린다. 바닥은 손패 전용이다.
	var b_back := UiKit.button(self, Vector2(880, 26), Vector2(160, 40), UiText.t("loadout.back", "←  상점으로"), 14)
	b_back.pressed.connect(func(): back.emit())
	btn_fight = UiKit.button(self, Vector2(1052, 26), Vector2(188, 40), UiText.t("loadout.fight", "전투 시작  →"), 16)
	btn_fight.pressed.connect(func():
		if tut != null:
			tut.notify_action("fight")
		fight.emit()
	)
	if tut != null:
		tut.register_anchor("fight_button", btn_fight)

	grid_root = Control.new()
	grid_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid_root)

	roster_root = Control.new()
	roster_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(roster_root)

	hand_root = Control.new()
	hand_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hand_root)

	# 유닛 종류 - 격자 아래 한 줄.
	# 성장 곡선(초반형/후반형)은 여기에 적지 않는다.
	# 로딩 화면의 TIP 이 그 역할을 한다 - 유닛 버튼 아래에 태그를 달면 정보가
	# 늘어난 만큼 화면이 빽빽해지고, 정작 고를 때 읽는 건 HP·공격력이다.
	_head(Vector2(48, 344), UiText.t("loadout.unit_pick", "대원 선택"))
	var x := 48.0
	for tid in UnitData.playable():
		var s: Dictionary = UnitData.TABLE[tid]
		# 얼굴을 세운 카드다. 이름과 숫자만 있던 버튼은 여섯 개가 나란히 놓이면
		# 전부 같은 회색 상자로 보여서, 고르는 일이 읽는 일이 됐다. 얼굴이
		# 있으면 고르는 일이 다시 보는 일이 된다.
		var b := _Tile.new()
		# 얼굴 칸을 세로로 키웠다. 가로는 못 늘린다 - 여섯 개가 오른쪽 모듈
		# 슬롯(x=560) 앞에서 끝나야 한다.
		# 그림은 정사각이라 칸 폭이 곧 그림 높이다. 칸을 그보다 높이 잡으면
		# 그림 아래에 빈 띠가 남고, 이름 칸이 그 아래에서 시작하니 "그림이
		# 끝난 선" 과 "글이 시작하는 선" 이 어긋난다. 칸 높이를 그림 높이 +
		# 이름띠로 딱 맞춘다.
		b.position = Vector2(x, 366)
		b.size = Vector2(82, 82 - 12 + 30)
		b.type_id = String(tid)
		b.label = String(s["name"])
		b.sub = UiText.t("loadout.unit_stat", "HP%d ATK%d") % [s["hp"], s["atk"]]
		b.tint = s["color"]
		add_child(b)
		b.pressed.connect(_on_type_pressed.bind(String(tid)))
		type_buttons[tid] = b
		if tut != null:
			tut.register_anchor("unit_%s" % tid, b)
		x += 84.0


	# 손패가 바닥을 다 쓰고 규칙 슬롯이 y=520 까지 내려오므로, 경고는 헤더 옆에 둔다.
	# 진영 라벨이 y=96 에 온다. 경고문을 82 에 두면 두 줄이 붙어 읽기 힘들고,
	# 경고문이 길어지면 그대로 겹친다. 부제(y=62) 바로 아래로 올린다.
	lbl_warn = UiKit.label(self, Vector2(48, 74), Vector2(1180, 20), "", 12, UiKit.BAD)

	refresh()


func refresh() -> void:
	_build_grid()
	_build_roster()
	_build_hand()

	for tid in type_buttons:
		var b = type_buttons[tid]
		b.disabled = run.party_full()
		# 고른 것은 타일이 스스로 표시한다. modulate 로 전체를 물들이면 얼굴까지
		# 노랗게 변해서 누구인지 안 보인다.
		b.selected = sel_type == tid
		b.queue_redraw()

	var reason := run.blocking_reason()
	btn_fight.disabled = not run.ready_to_fight()

	if reason != "":
		lbl_warn.text = reason
		lbl_warn.add_theme_color_override("font_color", UiKit.BAD)
		lbl_warn.visible = true
	else:
		# 막지는 않는다. 기본기만으로도 싸울 수 있으니 알려만 준다.
		var bare := run.bare_units()
		lbl_warn.visible = not bare.is_empty()
		lbl_warn.text = UiText.t("loadout.m01", "%s 는 카드 없이 기본기만으로 싸운다.") % ", ".join(bare)
		lbl_warn.add_theme_color_override("font_color", UiKit.MUTED)


# ── 진영 격자 ────────────────────────────────────────────────────────────

func _build_grid() -> void:
	for c in grid_root.get_children():
		c.queue_free()

	_head(Vector2(48, 96),
		UiText.t("loadout.field", "아군 진영 - %d칸 중 %d칸에 배치") % [
			Grid.PLAYER_SLOTS.size(), run.required_party()], grid_root)

	var can_place := sel_type != "" and not run.party_full()

	for i in Grid.PLAYER_SLOTS.size():
		var p: Vector2i = Grid.PLAYER_SLOTS[i]
		# 진영은 격자의 x=1,2 를 쓰므로 표시용으로만 원점을 당겨 놓는다.
		var col := p.x - Grid.PLAYER_SLOTS[0].x
		var row := p.y - 1
		var at := GRID_AT + Vector2(col * TILE, row * TILE)

		var b := _Tile.new()
		b.position = at
		b.size = Vector2(TILE - 6, TILE - 6)
		grid_root.add_child(b)

		var member := _member_at(i)
		if member >= 0:
			var tid: String = run.roster[member]["type"]
			b.type_id = tid
			b.label = String(UnitData.TABLE[tid]["name"])
			b.tint = UnitData.TABLE[tid]["color"]
			b.tooltip_text = UiText.t("loadout.m02", "누르면 배치를 무른다 (꽂은 카드는 손패로 돌아온다)")
			b.pressed.connect(_on_slot_remove.bind(member))
		else:
			# 빈 칸도 항상 보여야 한다. 어디에 놓을 수 있는지가 안 보이면 조작을 못 한다.
			b.empty = true
			b.tint = UiKit.TEAM_P if can_place else UiKit.LINE
			b.disabled = not can_place
			b.pressed.connect(_on_slot_place.bind(i))
		if tut != null:
			tut.register_anchor("grid_slot_%d" % i, b)

	# 격자를 왼쪽 칸 가운데로 옮겼으므로 방향 안내도 같이 간다. 캡션이
	# 대상에서 떨어지면 무엇을 설명하는 글인지 알 수 없다.
	UiKit.label(grid_root, Vector2(GRID_AT.x, 314), Vector2(460, 20),
		UiText.t("loadout.m03", "←  뒤         앞  →        (적은 오른쪽에서 온다)"), 11, UiKit.MUTED)


func _member_at(slot: int) -> int:
	for i in run.roster.size():
		if int(run.roster[i]["slot"]) == slot:
			return i
	return -1


func _on_type_pressed(tid: String) -> void:
	sel_type = "" if sel_type == tid else tid
	if tut != null and sel_type != "":
		tut.notify_action("pick_type")
	refresh()


func _on_slot_place(slot: int) -> void:
	if sel_type == "":
		return
	if run.place(sel_type, slot):
		if tut != null:
			tut.notify_action("place")
		sel_type = ""
		# 방금 놓은 유닛을 바로 카드 대상으로 잡아 준다. 클릭 한 번을 아낀다.
		sel_member = run.roster.size() - 1
		refresh()


func _on_slot_remove(member: int) -> void:
	if run.remove_member(member):
		sel_member = mini(sel_member, run.roster.size() - 1)
		refresh()


# ── 배치된 유닛의 규칙 슬롯 ──────────────────────────────────────────────

func _build_roster() -> void:
	for c in roster_root.get_children():
		c.queue_free()

	UiKit.label(roster_root, Vector2(RIGHT_X, 82), Vector2(700, 22),
		UiText.t("loadout.slots_head", "규칙 슬롯 - 위에서부터 처음 맞는 규칙 하나가 실행된다"), 15, UiKit.MUTED)

	if run.roster.is_empty():
		UiKit.label(roster_root, Vector2(RIGHT_X, 112), Vector2(600, 22),
			UiText.t("loadout.no_unit", "아직 배치된 유닛이 없다. 왼쪽에서 유닛을 고르고 빈 칸을 눌러라."),
			13, UiKit.MUTED)
		return

	# 기본 AI 는 직업마다 다르므로 범례로 한 번에 못 적는다. 대원 줄마다 붙인다.
	UiKit.label(roster_root, Vector2(RIGHT_X, 104), Vector2(700, 18),
		UiText.t("loadout.base_hint",
			"대원은 모듈이 없어도 자기 직업의 일을 합니다. 모듈은 그 판단을 수정합니다."),
		10, UiKit.FAINT)

	for i in run.roster.size():
		var y := ROSTER_Y + i * ROW_H
		var tid: String = run.roster[i]["type"]
		var s: Dictionary = UnitData.TABLE[tid]

		# ── 대원마다 판 하나 ────────────────────────────────────────────
		# 슬롯·기본기·특수 칸이 배경 없이 떠 있어서, 어디까지가 한 대원의
		# 것인지 줄 간격으로만 짐작해야 했다. 셋을 판으로 감싸면 "이 덩어리가
		# 이 대원" 이 한 번에 읽힌다.
		#
		# 고른 대원은 테두리에 그 대원 고유색을 두른다. 왼쪽 배치판에서 고른
		# 얼굴과 오른쪽 이 판이 같은 색으로 묶여야, 지금 무엇을 만지고 있는지
		# 눈으로 이어진다.
		var card := _SlotCard.new()
		card.position = Vector2(RIGHT_X - 12, y - 10)
		card.size = Vector2(660, 134)
		card.tint = s["color"]
		card.selected = sel_member == i
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		roster_root.add_child(card)

		var pick := UiKit.button(roster_root, Vector2(RIGHT_X, y), Vector2(140, 28),
			String(s["name"]), 14)
		pick.modulate = UiKit.ACCENT if sel_member == i else Color(1, 1, 1)
		pick.tooltip_text = UiText.t("loadout.m04", "이 유닛에게 카드를 꽂는다")
		pick.pressed.connect(func(): sel_member = i; refresh())

		UiKit.label(roster_root, Vector2(RIGHT_X + 150, y + 6), Vector2(280, 20),
			UiText.t("loadout.m05", "HP %d · ATK %d · RNG %d · MOV %d") % [
				s["hp"], s["atk"], s["range"], s["move"]], 11, UiKit.MUTED)

		# 특수 슬롯은 규칙 3칸과 별개다. 그래서 규칙 목록 안이 아니라 헤더 줄에 둔다.
		var sid: String = String(run.unit_special[i])
		var sb_text := UiText.t("loadout.m06", "특수: 없음")
		if sid != "":
			sb_text = UiText.t("loadout.m07", "특수: %s") % Specials.TABLE[sid]["name"]
		var sb := UiKit.button(roster_root, Vector2(RIGHT_X + 380, y), Vector2(160, 28),
			sb_text, 12)
		sb.modulate = UiKit.ACCENT if sid != "" else Color(0.62, 0.64, 0.72)
		if sid != "":
			sb.tooltip_text = "%s
누르면 손패로 돌아온다" % Specials.TABLE[sid]["text"]
			sb.pressed.connect(func(): run.unequip_special(i); refresh())
		else:
			var own_sid := Specials.for_unit(String(tid))
			sb.tooltip_text = UiText.t("loadout.m08", "이 유닛 전용: %s (손패에 있어야 꽂을 수 있다)") % (
				Specials.TABLE[own_sid]["name"] if own_sid != "" else UiText.t("loadout.m09", "없음"))
			sb.disabled = true

		# 특수를 전술보다 먼저 볼지. 이 순서 자체가 전략이라 플레이어가 정한다.
		# 무조건 최우선으로 두면 특수가 준비된 동안 슬롯 1~3 이 통째로 무시된다.
		var first: bool = bool(run.unit_special_first[i])
		var fb := UiKit.button(roster_root, Vector2(RIGHT_X + 546, y), Vector2(86, 28),
			UiText.t("loadout.m10", "전술 먼저") if not first else UiText.t("loadout.m11", "특수 먼저"), 11, 3)
		fb.disabled = sid == ""
		fb.modulate = UiKit.ACCENT if first else Color(0.72, 0.74, 0.82)
		fb.tooltip_text = "특수를 규칙 슬롯보다 먼저 볼지 정한다.
'특수 먼저' 면 준비된 동안 슬롯 1~3 이 무시된다."
		fb.pressed.connect(func(): run.toggle_special_first(i); refresh())

		var slots: Array = run.unit_cards[i]
		var slot_buttons_row: Dictionary = {}
		for k in RunState.SLOTS_PER_UNIT:
			var by := y + 30.0 + k * SLOT_STEP
			if k < slots.size():
				var c: Dictionary = Cards.TABLE[slots[k]]
				# 축 표시. 슬롯 왼쪽에 영문 축 라벨과 축 색 막대를 세운다.
				# 무슨 종류의 모듈이 어느 칸에 있는지가 목록만 봐도 읽혀야 한다.
				var ax := String(c.get("axis", ""))
				if ax != "":
					var bar := ColorRect.new()
					bar.color = Axes.color(ax)
					bar.position = Vector2(RIGHT_X + 4, by + 2)
					bar.size = Vector2(3, SLOT_H - 4)
					bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
					roster_root.add_child(bar)
					var al := UiKit.label(roster_root, Vector2(RIGHT_X + 12, by + 4),
						Vector2(72, 14), Axes.label(ax), 9, Axes.color(ax))
					al.mouse_filter = Control.MOUSE_FILTER_IGNORE

				var b := UiKit.button(roster_root, Vector2(RIGHT_X + 86, by), Vector2(486, SLOT_H),
					"%d.  %s  ·  %s" % [k + 1, c["name"], c["text"]], 12)
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
				b.tooltip_text = UiText.t("loadout.m12", "누르면 손패로 돌아온다")
				b.pressed.connect(func(): run.unequip(i, k); refresh())
				slot_buttons_row[k] = b

				var up := UiKit.button(roster_root, Vector2(RIGHT_X + 576, by), Vector2(28, SLOT_H), "▲", 11, 2)
				up.disabled = k == 0
				up.tooltip_text = UiText.t("loadout.m13", "우선순위를 올린다")
				up.pressed.connect(func(): run.move_slot(i, k, -1); refresh())

				var dn := UiKit.button(roster_root, Vector2(RIGHT_X + 606, by), Vector2(28, SLOT_H), "▼", 11, 2)
				dn.disabled = k >= slots.size() - 1
				dn.tooltip_text = UiText.t("loadout.m14", "우선순위를 내린다")
				dn.pressed.connect(func(): run.move_slot(i, k, 1); refresh())
			else:
				var e := UiKit.label(roster_root, Vector2(RIGHT_X + 16, by + 4), Vector2(400, 22),
					UiText.t("loadout.m15", "%d.  비어 있음") % (k + 1), 12, UiKit.LINE)
				e.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# 위 슬롯에 가려 절대 발동하지 못하는 카드를 표시한다.
		# 이걸 전투를 돌려 보고 나서 깨닫게 하면 안 된다.
		var dead := Shadow.shadowed_slots(slots, int(s["range"]))
		for k2 in dead:
			if slot_buttons_row.has(k2):
				var row: Button = slot_buttons_row[k2]
				row.modulate = Color(1.0, 0.45, 0.42)
		if not dead.is_empty():
			var note := Shadow.warnings(slots, int(s["range"]))[0]
			var wl := UiKit.label(roster_root, Vector2(RIGHT_X + 12, y + INNATE_DY - 8),
				Vector2(660, 18), "[!] " + note, 10, UiKit.BAD)
			wl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# 직업 고유 기본기를 슬롯 바로 아래에 회색으로 붙인다.
		# "카드 3장이 전부 어긋나면 여기로 떨어진다" 는 관계가 화면에 그대로 보여야 한다.
		var own_text := Innates.describe(tid)
		var iy := y + INNATE_DY
		var txt := UiText.t("loadout.m16", "기본기 ↓  ")
		if own_text == "":
			txt += UiText.t("loadout.m17", "(없음)")
		else:
			txt += own_text
		var il := UiKit.label(roster_root, Vector2(RIGHT_X + 16, iy), Vector2(640, 18),
			txt, 10, UiKit.FAINT)
		il.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ── 손패 ─────────────────────────────────────────────────────────────────

func _build_hand() -> void:
	for c in hand_root.get_children():
		c.queue_free()

	# 규칙 카드와 특수 스킬을 한 줄에 같이 깐다. 특수를 누르면 특수 슬롯으로,
	# 카드를 누르면 규칙 슬롯으로 들어간다. 어디로 갈지는 카드 종류가 정한다.
	var owned: Array[String] = []
	for cid in run.hand:
		owned.append(cid)
	for sid in run.special_hand:
		owned.append(sid)

	# ── 안내문을 지웠다 ─────────────────────────────────────────────────
	# "보유 모듈 (전술 1 · 궁극기 0) · 총사 에게 장착합니다. 전술 모듈은 다음
	# 빈 슬롯, 궁극기는 전용 칸에 들어갑니다." 한 줄이 화면 폭을 다 먹고 있었다.
	# 같은 내용이 화면 위 부제에 이미 있고, 꽂을 수 있는지는 카드가 밝은지
	# 어두운지로 이미 말한다. 세 번째로 또 말할 이유가 없다.
	#
	# 지운 자리는 여백으로 둔다. 이 화면은 이미 빽빽하다.
	var picked := sel_member >= 0 and sel_member < run.roster.size()
	var tid := ""
	if picked:
		tid = String(run.roster[sel_member]["type"])

	var n := owned.size()
	if n == 0:
		UiKit.label(hand_root, Vector2(48, HAND_Y + 10), Vector2(800, 22),
			UiText.t("loadout.hand_empty", "손패가 비었다. 상점으로 돌아가 더 사거나, 꽂은 것을 눌러 되돌려라."),
			12, UiKit.MUTED)
		return

	var mini_w := CardNode.W * 0.72
	var step: float = minf(mini_w + 14.0, (1150.0 - mini_w) / maxf(1.0, float(n - 1)))
	var span := mini_w + step * (n - 1)
	var x0 := (1280.0 - span) * 0.5
	var mid := (n - 1) * 0.5

	for i in n:
		var id: String = owned[i]
		var card := CardNode.new()
		hand_root.add_child(card)
		card.setup(id, i, true, false)

		# 꽂을 수 있는 것만 밝게. 특수는 직업이 맞아야 하고, 카드는 빈 슬롯이 있어야 한다.
		if not picked:
			card.enabled = false
		elif RunState.is_special(id):
			card.enabled = Specials.usable_by(id, tid)
			if not card.enabled:
				card.note = UiText.t("loadout.m18", "직업 불일치")
		else:
			card.enabled = (run.unit_cards[sel_member] as Array).size() < RunState.SLOTS_PER_UNIT

		var offset := float(i) - mid
		card.place(Vector2(x0 + i * step, HAND_Y + absf(offset) * 3.0), offset * 0.02)
		card.clicked.connect(_on_hand_clicked)
		if tut != null:
			tut.register_anchor("hand_card_%d" % i, card)


func _on_hand_clicked(card: CardNode) -> void:
	if sel_member < 0:
		return
	var done := false
	if RunState.is_special(card.card_id):
		done = run.equip_special(sel_member, card.card_id)
	else:
		done = run.equip(sel_member, card.card_id)
	if done:
		if tut != null:
			tut.notify_action("equip")
		refresh()


## ── 머리말 ───────────────────────────────────────────────────────────────
## 글자 앞에 짧은 색 막대를 세운다. NIKKE·명일방주 계열의 인상은 장식이 아니라
## **정렬**에서 온다 - 막대가 왼쪽 기준선을 만들면 아래 요소가 전부 그 선에
## 맞춰 정렬된 것처럼 읽힌다. 선 하나로 화면이 정리되는 이유가 그것이다.
func _head(at: Vector2, text: String, parent: Node = null) -> void:
	var host: Node = parent if parent != null else self
	var bar := ColorRect.new()
	bar.color = Axes.color(Axes.POSITION)
	bar.position = at + Vector2(0, 4)
	bar.size = Vector2(3, 16)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(bar)
	UiKit.label(host, at + Vector2(11, 0), Vector2(520, 22), text, 15, UiKit.TEXT)


## ── 얼굴 타일 ────────────────────────────────────────────────────────────
## 진영 칸과 유닛 선택이 같은 물건을 쓴다. 둘 다 "이 대원을 고른다" 이므로
## 생김새가 달라야 할 이유가 없다.
##
## 왼쪽 위·오른쪽 아래를 사선으로 깎는다. 모듈 카드와 전황판이 이미 쓰는
## 어법이라, 같은 모양을 두르면 화면 전체가 한 벌로 읽힌다.
##
## ── 세 겹으로 그린다 ─────────────────────────────────────────────────────
##   _draw()   바탕 사선 판
##   _tr       얼굴 (TextureRect 자식)
##   _ov       이름띠 · 테두리 · 선택 표시
##
## 얼굴을 _draw() 안에서 draw_texture_rect 로 그리면 이 프로젝트에서는 회색
## 사각형이 나온다. SD 얼굴·지형 배경·스토리 초상에서 이미 세 번 겪었다.
## 그리고 얼굴이 노드가 되면 자식이 부모보다 나중에 그려지므로, 이름띠와
## 테두리도 같이 노드로 올려야 얼굴에 안 가린다.
class _Tile extends Button:
	var type_id: String = ""
	var label: String = ""
	var sub: String = ""
	var tint: Color = Color(0.4, 0.5, 0.6)
	var empty: bool = false
	var selected: bool = false

	const CUT: float = 11.0

	var _clip: Control
	var _tr: TextureRect
	var _ov: Control

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		var blank := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(st, blank)

		# 자르는 일은 **감싸는 Control** 이 한다. TextureRect 의
		# KEEP_ASPECT_COVERED 는 제 칸 밖까지 그려서, 얼굴 하나가 화면 절반을
		# 덮어 버렸다. 크기 계산을 직접 하면 그런 일이 없다.
		_clip = Control.new()
		_clip.clip_contents = true
		_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_clip)
		_tr = TextureRect.new()
		# 최소 크기를 텍스처 크기로 잡지 않게 한다. 이걸 안 하면 size 를 아무리
		# 작게 줘도 192x192 로 되돌아가서, 75px 칸 안에 192px 그림의 왼쪽 위
		# 귀퉁이만 보인다.
		_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_clip.add_child(_tr)

		_ov = _TileFace.new()
		_ov.set("tile", self)
		_ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_ov)
		_layout()

	func _layout() -> void:
		if _clip == null:
			return
		var band := band_h()
		# 얼굴 그림 자체가 캔버스 끝까지 꽉 차게 그려져 있다(머리카락이 위
		# 가장자리에 닿는다). 칸에 딱 붙여 놓으면 그 잘린 단면이 테두리와
		# 만나서 "잘렸다" 로 읽힌다. 안쪽으로 한 겹 물려 여백을 만든다.
		_clip.position = Vector2(6, 6)
		_clip.size = Vector2(size.x - 12, size.y - band - 6)
		var tex := null if (empty or type_id == "") 			else UiKit.art(["portraits", "units"], type_id)
		_tr.texture = tex
		_tr.modulate = Color(1, 1, 1, 0.45 if disabled else 1.0)
		# 얼굴은 **통째로** 보여야 한다. 채워서 자르면 192x192 짜리 정사각
		# 초상이 머리카락만 남는다 - 여섯이 나란히 놓였을 때 누가 누구인지
		# 구별이 안 되면 얼굴을 넣은 의미가 없다.
		_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_tr.position = Vector2.ZERO
		_tr.size = _clip.size
		_ov.position = Vector2.ZERO
		_ov.size = size
		_ov.queue_redraw()

	## 아래쪽 이름띠 높이.
	func band_h() -> float:
		return 26.0 if sub != "" else 16.0

	func shape(s: Vector2) -> PackedVector2Array:
		return PackedVector2Array([
			Vector2(CUT, 0), Vector2(s.x, 0), Vector2(s.x, s.y - CUT),
			Vector2(s.x - CUT, s.y), Vector2(0, s.y), Vector2(0, CUT),
		])

	func _draw() -> void:
		_layout()
		var body := Color(0.10, 0.115, 0.15) if empty else tint.darkened(0.72)
		if disabled:
			body = Color(0.085, 0.09, 0.11)
		draw_colored_polygon(shape(size), body)


## 타일의 이름띠와 테두리. 얼굴 위에 얹혀야 하므로 별도 노드다.
class _TileFace extends Control:
	var tile

	func _draw() -> void:
		if tile == null:
			return
		var s := size
		var on: bool = tile.is_hovered() or tile.selected
		var t: Color = tile.tint

		var band: float = tile.band_h()
		if String(tile.label) != "":
			var ly: float = s.y - band
			draw_rect(Rect2(2, ly, s.x - 4, band - 2), Color(0, 0, 0, 0.68))
			var fs := UiKit.font(11)
			draw_string(fs, Vector2(0, ly + 12), String(tile.label),
				HORIZONTAL_ALIGNMENT_CENTER, s.x, 12,
				UiKit.FAINT if tile.disabled else UiKit.TEXT)
			if String(tile.sub) != "":
				# 사선 모서리가 오른쪽 아래를 잘라 먹는다. 숫자 줄을 칸 폭
				# 그대로 가운데 맞추면 끝자리가 그 잘림에 걸린다.
				# 82px 칸에 "HP 125 · ATK 18" 은 9pt 로는 안 들어간다. 잘리면
				# 숫자가 아니라 잡음이 된다.
				draw_string(fs, Vector2(4, ly + 23), String(tile.sub),
					HORIZONTAL_ALIGNMENT_CENTER, s.x - 8, 8, UiKit.FAINT)

		var line := PackedVector2Array(tile.shape(s))
		line.append(line[0])
		draw_polyline(line, Color(t.r, t.g, t.b, 1.0 if on else 0.62), 2.0, true)
		# 고른 것은 왼쪽에 굵은 막대를 세운다. 테두리만으로는 호버와 구별이 안 된다.
		if tile.selected:
			draw_rect(Rect2(0, tile.CUT, 4, s.y - tile.CUT), t)


## ── 대원별 모듈 판 ───────────────────────────────────────────────────────
## 니케의 캐릭터 카드처럼, 왼쪽에 굵은 색 띠를 세우고 오른쪽 아래를 사선으로
## 자른다. 색은 대원 고유색이라 배치판의 얼굴 테두리와 같은 색으로 묶인다.
##
## 고르지 않은 대원은 띠와 테두리를 흐리게 둔다. 전부 같은 세기로 두르면
## 판 셋이 똑같이 소리쳐서 결국 아무것도 강조가 안 된다.
class _SlotCard extends Control:
	const CUT: float = 16.0

	var tint: Color = Color(0.6, 0.6, 0.6)
	var selected: bool = false

	func _draw() -> void:
		var s := size
		var shape := PackedVector2Array([
			Vector2(CUT, 0), Vector2(s.x, 0), Vector2(s.x, s.y - CUT),
			Vector2(s.x - CUT, s.y), Vector2(0, s.y), Vector2(0, CUT),
		])
		draw_colored_polygon(shape,
			Color(0.085, 0.10, 0.135, 0.95) if selected else Color(0.065, 0.075, 0.10, 0.9))
		var line := PackedVector2Array(shape)
		line.append(shape[0])
		draw_polyline(line,
			Color(tint.r, tint.g, tint.b, 0.95 if selected else 0.22),
			2.0 if selected else 1.0, true)
		# 왼쪽 색 띠. 고른 대원만 굵고 진하다.
		var bw: float = 5.0 if selected else 3.0
		draw_rect(Rect2(0, CUT, bw, s.y - CUT),
			Color(tint.r, tint.g, tint.b, 0.95 if selected else 0.30))
		if selected:
			# 고른 판에만 옅은 색을 깔아 준다. 테두리만으로는 셋 중 어느
			# 것인지 훑을 때 안 걸린다.
			draw_colored_polygon(shape, Color(tint.r, tint.g, tint.b, 0.07))
