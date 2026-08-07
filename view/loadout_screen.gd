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

## ── 화면 구획 ───────────────────────────────────────────────────────────
## 왼쪽은 **어디에 세울까**, 오른쪽은 **어떻게 판단하게 할까** 다. 질문이 다르니
## 자리도 갈라야 한다. 예전에는 오른쪽 판이 가로로 길게 누워 왼쪽 얼굴 칸과
## 겹쳤고, 세 대원이 세로로 쌓이면서 손패까지 밀고 내려갔다.
##
## 니케의 캐릭터 카드처럼 대원 하나를 **세로 카드 한 장**으로 세운다. 셋이
## 나란히 서면 우선순위 세 벌을 한눈에 비교할 수 있고, 그게 이 게임에서
## 편성 화면이 존재하는 이유다.
##
##   x  40 ~ 424   배치 격자 · 대원 선택
##   x 440 ~ 1240  대원 카드 3장 (254 폭, 266 간격)
##   y 548 ~       보유 모듈
const TILE: float = 66.0
const GRID_AT := Vector2(48, 124)

## 대원 카드
const CARD_X: float = 440.0
const CARD_W: float = 254.0
const CARD_STEP: float = 266.0
const CARD_Y: float = 116.0
const CARD_H: float = 360.0

## ── 대원 선택 ───────────────────────────────────────────────────────────
## 3열 2행. 한 줄에 여섯을 늘어놓으면 칸 하나가 62px 까지 좁아져 얼굴이
## 우표만 해진다. 두 줄로 접으면 같은 폭에서 칸이 두 배 가까이 커진다.
const PICK_X: float = 48.0
const PICK_Y: float = 366.0
const PICK_W: float = 116.0
const PICK_H: float = 86.0
const PICK_STEP: Vector2 = Vector2(122.0, 92.0)
const PICK_COLS: int = 3

const HAND_Y: float = 540.0

## 손패 카드 배율. 상점(0.72)보다 크게 잡는다 - 여기서는 **읽고 고르는** 것이
## 아니라 이미 산 것을 어디에 꽂을지 정하는 일이라, 카드가 눈에 들어와야 한다.
const HAND_SCALE: float = 0.85

## 카드 안쪽 세로 배치. 전부 카드 원점 기준이다.
const IN_FACE_H: float = 110.0
const IN_NAME_Y: float = 118.0
const IN_STAT_Y: float = 142.0
const IN_SLOT_Y: float = 162.0
const IN_SLOT_H: float = 34.0
const IN_ULT_Y: float = 272.0
const IN_INNATE_Y: float = 306.0

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
	_head(Vector2(48, PICK_Y - 26), UiText.t("loadout.unit_pick", "대원 선택"))
	var pi := 0
	for tid in UnitData.playable():
		var s2: Dictionary = UnitData.TABLE[tid]
		# 여기는 **고르는 자리**다. 능력치는 오른쪽 대원 카드가 크게 말하므로
		# 얼굴과 이름만 둔다. 좁은 칸에 숫자까지 밀어 넣으면 둘 다 안 읽힌다.
		var b := _Tile.new()
		b.position = Vector2(
			PICK_X + float(pi % PICK_COLS) * PICK_STEP.x,
			PICK_Y + float(pi / PICK_COLS) * PICK_STEP.y)
		b.size = Vector2(PICK_W, PICK_H)
		b.type_id = String(tid)
		b.label = String(s2["name"])
		b.tint = s2["color"]
		b.tooltip_text = UiText.t("loadout.unit_stat", "HP %d · ATK %d") % [
			s2["hp"], s2["atk"]]
		add_child(b)
		b.pressed.connect(_on_type_pressed.bind(String(tid)))
		type_buttons[tid] = b
		if tut != null:
			tut.register_anchor("unit_%s" % tid, b)
		pi += 1


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
	UiKit.label(grid_root, Vector2(GRID_AT.x, GRID_AT.y + TILE * 3.0 + 6.0),
		Vector2(460, 20),
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

	UiKit.label(roster_root, Vector2(CARD_X, 82), Vector2(700, 22),
		UiText.t("loadout.slots_head", "규칙 슬롯 - 위에서부터 처음 맞는 규칙 하나가 실행된다"),
		14, UiKit.MUTED)

	if run.roster.is_empty():
		UiKit.label(roster_root, Vector2(CARD_X, CARD_Y + 20), Vector2(600, 22),
			UiText.t("loadout.no_unit", "아직 배치된 유닛이 없다. 왼쪽에서 유닛을 고르고 빈 칸을 눌러라."),
			13, UiKit.MUTED)
		return

	for i in run.roster.size():
		_unit_card(i, Vector2(CARD_X + float(i) * CARD_STEP, CARD_Y))


## 대원 하나를 세로 카드 한 장으로 세운다.
##
## 위에서부터 얼굴 · 이름 · 능력치 · 슬롯 3칸 · 궁극기 · 기본기. 읽는 순서가
## 곧 "이 대원이 무엇이고, 무엇을 하게 될 것인가" 의 순서다.
func _unit_card(i: int, at: Vector2) -> void:
	var tid: String = run.roster[i]["type"]
	var s: Dictionary = UnitData.TABLE[tid]
	var picked: bool = sel_member == i

	var card := _UnitCard.new()
	card.position = at
	card.size = Vector2(CARD_W, CARD_H)
	card.tint = s["color"]
	card.selected = picked
	card.type_id = tid
	card.unit_name = String(s["name"])
	card.stat = UiText.t("loadout.m05", "HP %d · ATK %d · RNG %d · MOV %d") % [
		s["hp"], s["atk"], s["range"], s["move"]]
	card.tooltip_text = UiText.t("loadout.m04", "이 유닛에게 카드를 꽂는다")
	card.pressed.connect(func(): sel_member = i; refresh())
	roster_root.add_child(card)

	# ── 슬롯 3칸 ────────────────────────────────────────────────────────
	var slots: Array = run.unit_cards[i]
	var rows: Dictionary = {}
	for k in RunState.SLOTS_PER_UNIT:
		var by := at.y + IN_SLOT_Y + float(k) * IN_SLOT_H
		if k >= slots.size():
			var e := UiKit.label(roster_root, Vector2(at.x + 14, by + 6),
				Vector2(CARD_W - 28, 20),
				UiText.t("loadout.m15", "%d.  비어 있음") % (k + 1), 11, UiKit.LINE)
			e.mouse_filter = Control.MOUSE_FILTER_IGNORE
			continue

		var c: Dictionary = Cards.TABLE[slots[k]]
		var ax := String(c.get("axis", ""))
		var row := _SlotRow.new()
		row.position = Vector2(at.x + 10, by)
		row.size = Vector2(CARD_W - 20 - 46, IN_SLOT_H - 4)
		row.idx = k
		row.title = String(c["name"])
		row.body = String(c["text"])
		row.tint = Axes.color(ax) if ax != "" else UiKit.MUTED
		row.axis_label = Axes.label(ax) if ax != "" else ""
		row.tooltip_text = "%s\n%s" % [c["text"],
			UiText.t("loadout.m12", "누르면 손패로 돌아온다")]
		row.pressed.connect(func(): run.unequip(i, k); refresh())
		roster_root.add_child(row)
		rows[k] = row

		var bx := at.x + CARD_W - 54.0
		var up := UiKit.button(roster_root, Vector2(bx, by), Vector2(22, 26), "▲", 10, 2)
		up.disabled = k == 0
		up.tooltip_text = UiText.t("loadout.m13", "우선순위를 올린다")
		up.pressed.connect(func(): run.move_slot(i, k, -1); refresh())
		var dn := UiKit.button(roster_root, Vector2(bx + 24, by), Vector2(22, 26), "▼", 10, 2)
		dn.disabled = k >= slots.size() - 1
		dn.tooltip_text = UiText.t("loadout.m14", "우선순위를 내린다")
		dn.pressed.connect(func(): run.move_slot(i, k, 1); refresh())

	# 위 슬롯에 가려 절대 발동하지 못하는 카드. 전투를 돌려 보고 나서 깨닫게
	# 하면 안 된다.
	var dead := Shadow.shadowed_slots(slots, int(s["range"]))
	for k2 in dead:
		if rows.has(k2):
			(rows[k2] as _SlotRow).dead = true

	# ── 궁극기 · 순서 ───────────────────────────────────────────────────
	var sid: String = String(run.unit_special[i])
	var sb_text := UiText.t("loadout.m06", "특수: 없음")
	if sid != "":
		sb_text = UiText.t("loadout.m07", "특수: %s") % Specials.TABLE[sid]["name"]
	var sb := UiKit.button(roster_root, Vector2(at.x + 10, at.y + IN_ULT_Y),
		Vector2(148, 26), sb_text, 11)
	sb.modulate = UiKit.ACCENT if sid != "" else Color(0.62, 0.64, 0.72)
	if sid != "":
		sb.tooltip_text = "%s\n%s" % [Specials.TABLE[sid]["text"],
			UiText.t("loadout.m12", "누르면 손패로 돌아온다")]
		sb.pressed.connect(func(): run.unequip_special(i); refresh())
	else:
		var own_sid := Specials.for_unit(String(tid))
		sb.tooltip_text = UiText.t("loadout.m08", "이 유닛 전용: %s (손패에 있어야 꽂을 수 있다)") % (
			Specials.TABLE[own_sid]["name"] if own_sid != "" else UiText.t("loadout.m09", "없음"))
		sb.disabled = true

	var first: bool = bool(run.unit_special_first[i])
	var fb := UiKit.button(roster_root, Vector2(at.x + 162, at.y + IN_ULT_Y),
		Vector2(82, 26),
		UiText.t("loadout.m10", "전술 먼저") if not first else UiText.t("loadout.m11", "특수 먼저"),
		10, 3)
	fb.disabled = sid == ""
	fb.modulate = UiKit.ACCENT if first else Color(0.72, 0.74, 0.82)
	fb.tooltip_text = UiText.t("loadout.first_hint",
		"특수를 규칙 슬롯보다 먼저 볼지 정합니다. '특수 먼저' 면 준비된 동안 슬롯 1~3 이 무시됩니다.")
	fb.pressed.connect(func(): run.toggle_special_first(i); refresh())

	# ── 기본기 ──────────────────────────────────────────────────────────
	# "모듈 셋이 전부 어긋나면 여기로 떨어진다" 는 관계가 화면에 그대로 보여야
	# 한다. 그래서 슬롯 **바로 아래**에 붙인다.
	var own_text := Innates.describe(tid)
	var txt := UiText.t("loadout.m16", "기본기 ↓  ")
	txt += own_text if own_text != "" else UiText.t("loadout.m17", "(없음)")
	var il := UiKit.label(roster_root, Vector2(at.x + 12, at.y + IN_INNATE_Y),
		Vector2(CARD_W - 24, 40), txt, 9, UiKit.FAINT, true)
	il.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not dead.is_empty():
		var note := Shadow.warnings(slots, int(s["range"]))[0]
		var wl := UiKit.label(roster_root, Vector2(at.x + 12, at.y + CARD_H - 24),
			Vector2(CARD_W - 24, 20), "[!] " + note, 9, UiKit.BAD)
		wl.mouse_filter = Control.MOUSE_FILTER_IGNORE


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

	var mini_w := CardNode.W * HAND_SCALE
	var step: float = minf(mini_w + 14.0, (1160.0 - mini_w) / maxf(1.0, float(n - 1)))
	var span := mini_w + step * (n - 1)
	var x0 := (1280.0 - span) * 0.5
	var mid := (n - 1) * 0.5

	for i in n:
		var id: String = owned[i]
		var card := CardNode.new()
		hand_root.add_child(card)
		card.mini_scale = HAND_SCALE
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
		# ── 이름 칸을 그림 위로 올린다 ────────────────────────────────
		# 예전에는 그림이 이름띠 **위에서** 끝났다. 그러면 칸 안이 위아래로
		# 나뉘어 얼굴이 앉을 자리가 그만큼 줄고, 얼굴과 이름 사이에 쓸데없는
		# 빈 줄이 생긴다.
		#
		# 그림을 칸 끝까지 채우고 이름띠를 그 위에 얹는다. 얼굴은 커지고
		# 이름은 올라온다.
		# 이름띠가 얼굴을 조금만 물게 한다. 칸 끝까지 채우면 띠가 턱을 통째로
		# 덮는다 - 올리라는 것이지 가리라는 것이 아니다.
		_clip.position = Vector2(4, 4)
		_clip.size = Vector2(size.x - 8, size.y - band + 4.0)
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
			var ly: float = s.y - band - 3.0
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


## ── 대원 카드 ────────────────────────────────────────────────────────────
## 니케의 캐릭터 카드 어법이다. 얼굴을 위에 크게 두고 이름띠로 끊은 뒤, 그 아래
## 판단 규칙을 쌓는다. 고른 대원은 그 대원 고유색으로 테두리·왼쪽 띠·바탕이
## 물든다 - 왼쪽 배치판 얼굴 테두리와 같은 색이라 눈으로 이어진다.
##
## 카드 전체가 버튼이다. 이름 옆의 작은 버튼을 찾아 누르게 하면, 정작 크게
## 그려 놓은 얼굴이 아무 일도 안 하는 그림이 된다.
class _UnitCard extends Button:
	const CUT: float = 16.0

	var tint: Color = Color(0.6, 0.6, 0.6)
	var selected: bool = false
	var type_id: String = ""
	var unit_name: String = ""
	var stat: String = ""

	var _clip: Control
	var _tr: TextureRect
	var _ov: Control

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		var blank := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(st, blank)

		# 얼굴은 노드로 붙인다. _draw() 안의 draw_texture_rect 는 이 프로젝트에서
		# 회색 사각형이 된다(네 번 겪었다). 자르는 일은 감싸는 Control 이 한다.
		_clip = Control.new()
		_clip.clip_contents = true
		_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_clip.position = Vector2(3, 3)
		_clip.size = Vector2(size.x - 6, LoadoutScreen.IN_FACE_H)
		add_child(_clip)
		_tr = TextureRect.new()
		_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tr.texture = UiKit.art(["portraits", "units"], type_id)
		# ── 얼굴은 통째로 ────────────────────────────────────────────
		# 폭에 맞춰 채워 봤더니 정수리와 턱이 잘려 눈만 남았다. 이 초상들은
		# 이미 얼굴로 꽉 찬 정사각이라, 더 확대할 여지가 없다.
		#
		# 칸 높이에 맞추고 살짝만 키운다(1.15). 좌우에 남는 여백은 카드가
		# 세로로 긴 데서 오는 것이고, 그 여백이 있어야 이름띠의 사선이 보인다.
		var k := _clip.size.y * 1.15
		_tr.size = Vector2(k, k)
		_tr.position = Vector2((_clip.size.x - k) * 0.5, -k * 0.06)
		_clip.add_child(_tr)

		# 이름띠·테두리는 얼굴 위에 떠야 하므로 별도 노드다.
		_ov = _UnitCardFace.new()
		_ov.set("card", self)
		_ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ov.position = Vector2.ZERO
		_ov.size = size
		add_child(_ov)

	func shape(s: Vector2) -> PackedVector2Array:
		return PackedVector2Array([
			Vector2(CUT, 0), Vector2(s.x, 0), Vector2(s.x, s.y - CUT),
			Vector2(s.x - CUT, s.y), Vector2(0, s.y), Vector2(0, CUT),
		])

	func _draw() -> void:
		var s := size
		draw_colored_polygon(shape(s),
			Color(0.085, 0.10, 0.135) if selected else Color(0.062, 0.072, 0.095))
		if selected:
			draw_colored_polygon(shape(s), Color(tint.r, tint.g, tint.b, 0.06))
		if _ov != null:
			_ov.queue_redraw()


## 대원 카드의 이름띠 · 능력치 · 테두리.
class _UnitCardFace extends Control:
	var card

	func _draw() -> void:
		if card == null:
			return
		var s := size
		var t: Color = card.tint
		var on: bool = card.selected
		var hot: bool = card.is_hovered()

		# 얼굴 아래를 사선 띠로 끊는다. 이름이 그림 위에 그냥 얹히면 배경에
		# 묻히고, 네모 띠를 두르면 이 화면의 다른 판들과 어법이 어긋난다.
		var fy: float = LoadoutScreen.IN_FACE_H
		# 띠는 얼굴 **아래**에서 시작한다. 얼굴 위로 올라오면 턱이 잘린다.
		var band := PackedVector2Array([
			Vector2(3, fy + 2), Vector2(s.x - 3, fy - 8),
			Vector2(s.x - 3, fy + 32), Vector2(3, fy + 32),
		])
		draw_colored_polygon(band, Color(0.03, 0.035, 0.05, 0.92))
		draw_line(Vector2(3, fy + 2), Vector2(s.x - 3, fy - 8),
			Color(t.r, t.g, t.b, 0.9), 2.0)

		draw_string(UiKit.font(16), Vector2(14, LoadoutScreen.IN_NAME_Y + 14),
			String(card.unit_name), HORIZONTAL_ALIGNMENT_LEFT, int(s.x - 28), 16,
			Color(1, 1, 1) if on else Color(0.88, 0.90, 0.95))
		draw_string(UiKit.font(9), Vector2(14, LoadoutScreen.IN_STAT_Y + 10),
			String(card.stat), HORIZONTAL_ALIGNMENT_LEFT, int(s.x - 28), 9,
			Color(t.r, t.g, t.b, 0.95))

		var line := PackedVector2Array(card.shape(s))
		line.append(line[0])
		draw_polyline(line,
			Color(t.r, t.g, t.b, 1.0 if on else (0.6 if hot else 0.26)),
			2.0 if on else 1.0, true)
		# 왼쪽 색 띠. 고른 대원만 굵고 진하다.
		draw_rect(Rect2(0, card.CUT, 5.0 if on else 3.0, s.y - card.CUT),
			Color(t.r, t.g, t.b, 0.95 if on else 0.30))


## ── 모듈 슬롯 한 줄 ──────────────────────────────────────────────────────
## 축 색 막대 · 순번 · 이름 · 설명. 좁은 카드 안이라 버튼 대신 직접 그린다 -
## Button 은 제 글자를 먼저 그리고 그 위에 _draw() 가 얹히기 때문이다.
class _SlotRow extends Button:
	var idx: int = 0
	var title: String = ""
	var body: String = ""
	var axis_label: String = ""
	var tint: Color = Color(0.6, 0.6, 0.6)
	var dead: bool = false

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		var blank := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(st, blank)

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var s := size
		var hot := is_hovered()
		draw_rect(Rect2(0, 0, s.x, s.y), Color(0.10, 0.12, 0.16, 0.9 if hot else 0.55))
		draw_rect(Rect2(0, 0, 3, s.y), Color(tint.r, tint.g, tint.b, 0.95))
		var name_col: Color = UiKit.BAD if dead else (
			Color(1, 1, 1) if hot else Color(0.88, 0.91, 0.96))
		draw_string(UiKit.font(11), Vector2(10, 13),
			"%d. %s" % [idx + 1, title], HORIZONTAL_ALIGNMENT_LEFT,
			int(s.x - 56), 11, name_col)
		if axis_label != "":
			draw_string(UiKit.font(8), Vector2(s.x - 48, 12), axis_label,
				HORIZONTAL_ALIGNMENT_RIGHT, 44, 8,
				Color(tint.r, tint.g, tint.b, 0.9))
		draw_string(UiKit.font(9), Vector2(10, 25), body,
			HORIZONTAL_ALIGNMENT_LEFT, int(s.x - 14), 9,
			UiKit.BAD if dead else UiKit.FAINT)
