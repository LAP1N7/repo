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
const GRID_AT := Vector2(48, 124)
const RIGHT_X: float = 560.0
const HAND_Y: float = 556.0

## 유닛 한 명이 차지하는 세로 높이. 헤더 28 + 슬롯 3×27 + 기본기 줄 18 + 여백.
## 줄이면 기본기 줄이 다음 유닛 헤더를 덮는다.
const ROSTER_Y: float = 138.0
const ROW_H: float = 136.0

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
	UiKit.label(self, Vector2(48, 340), Vector2(460, 22),
		UiText.t("loadout.unit_pick", "유닛 선택"), 15, UiKit.MUTED)
	var x := 48.0
	for tid in UnitData.playable():
		var s: Dictionary = UnitData.TABLE[tid]
		# 유닛이 6종이 되면서 폭을 줄였다. 이 행은 RIGHT_X(560) 전에 끝나야 한다.
		# 안 그러면 오른쪽 규칙 슬롯 위를 덮어 3번 슬롯이 안 보인다.
		var b := UiKit.button(self, Vector2(x, 364), Vector2(79, 44),
			"%s
HP%d 공%d" % [s["name"], s["hp"], s["atk"]], 10, 3)
		b.pressed.connect(_on_type_pressed.bind(String(tid)))
		type_buttons[tid] = b


		if tut != null:
			tut.register_anchor("unit_%s" % tid, b)
		x += 84.0


	# 손패가 바닥을 다 쓰고 규칙 슬롯이 y=520 까지 내려오므로, 경고는 헤더 옆에 둔다.
	lbl_warn = UiKit.label(self, Vector2(48, 82), Vector2(820, 22), "", 13, UiKit.BAD)

	refresh()


func refresh() -> void:
	_build_grid()
	_build_roster()
	_build_hand()

	for tid in type_buttons:
		var b: Button = type_buttons[tid]
		b.disabled = run.party_full()
		b.modulate = UiKit.ACCENT if sel_type == tid else Color(1, 1, 1)

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

	UiKit.label(grid_root, Vector2(48, 96), Vector2(460, 22),
		UiText.t("loadout.field", "아군 진영 - %d칸 중 %d칸에 배치") % [Grid.PLAYER_SLOTS.size(), run.required_party()],
		15, UiKit.MUTED)

	var can_place := sel_type != "" and not run.party_full()

	for i in Grid.PLAYER_SLOTS.size():
		var p: Vector2i = Grid.PLAYER_SLOTS[i]
		# 진영은 격자의 x=1,2 를 쓰므로 표시용으로만 원점을 당겨 놓는다.
		var col := p.x - Grid.PLAYER_SLOTS[0].x
		var row := p.y - 1
		var at := GRID_AT + Vector2(col * TILE, row * TILE)

		var b := Button.new()
		b.position = at
		b.size = Vector2(TILE - 6, TILE - 6)
		b.add_theme_font_override("font", UiKit.font(11))
		b.add_theme_font_size_override("font_size", 12)
		grid_root.add_child(b)

		var member := _member_at(i)
		if member >= 0:
			var tid: String = run.roster[member]["type"]
			var s: Dictionary = UnitData.TABLE[tid]
			var uc: Color = s["color"]
			b.text = String(s["name"])
			b.add_theme_stylebox_override("normal", UiKit.box(uc.darkened(0.5), uc, 5))
			b.add_theme_stylebox_override("hover", UiKit.box(uc.darkened(0.3), Color.WHITE, 5))
			b.add_theme_stylebox_override("pressed", UiKit.box(uc.darkened(0.2), Color.WHITE, 5))
			b.tooltip_text = UiText.t("loadout.m02", "누르면 배치를 무른다 (꽂은 카드는 손패로 돌아온다)")
			b.pressed.connect(_on_slot_remove.bind(member))
		else:
			# 빈 칸도 항상 보여야 한다. 어디에 놓을 수 있는지가 안 보이면 조작을 못 한다.
			var edge: Color = UiKit.TEAM_P if can_place else UiKit.LINE
			b.text = ""
			b.add_theme_stylebox_override("normal", UiKit.box(Color(0.145, 0.17, 0.215), edge, 5))
			b.add_theme_stylebox_override("hover",
				UiKit.box(Color(0.22, 0.28, 0.36), Color.WHITE, 5))
			b.add_theme_stylebox_override("disabled",
				UiKit.box(Color(0.115, 0.125, 0.155), UiKit.LINE, 5))
			b.disabled = not can_place
			b.pressed.connect(_on_slot_place.bind(i))
		if tut != null:
			tut.register_anchor("grid_slot_%d" % i, b)

	UiKit.label(grid_root, Vector2(48, 314), Vector2(460, 20),
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

	UiKit.label(roster_root, Vector2(RIGHT_X, 96), Vector2(700, 22),
		UiText.t("loadout.slots_head", "규칙 슬롯 - 위에서부터 처음 맞는 규칙 하나가 실행된다"), 15, UiKit.MUTED)

	if run.roster.is_empty():
		UiKit.label(roster_root, Vector2(RIGHT_X, 128), Vector2(600, 22),
			UiText.t("loadout.no_unit", "아직 배치된 유닛이 없다. 왼쪽에서 유닛을 고르고 빈 칸을 눌러라."),
			13, UiKit.MUTED)
		return

	# 공통 골격은 유닛마다 반복하면 줄이 길어져 잘린다. 한 번만 범례로 적는다.
	var base_names := PackedStringArray()
	for r in Innates.BASE:
		base_names.append(String(r["text"]))
	UiKit.label(roster_root, Vector2(RIGHT_X, 116), Vector2(700, 18),
		UiText.t("battle.m01", "모든 유닛 공통 기본기:  %s") % "   /   ".join(base_names), 10, UiKit.FAINT)

	for i in run.roster.size():
		var y := ROSTER_Y + i * ROW_H
		var tid: String = run.roster[i]["type"]
		var s: Dictionary = UnitData.TABLE[tid]

		var pick := UiKit.button(roster_root, Vector2(RIGHT_X, y), Vector2(140, 28),
			String(s["name"]), 14)
		pick.modulate = UiKit.ACCENT if sel_member == i else Color(1, 1, 1)
		pick.tooltip_text = UiText.t("loadout.m04", "이 유닛에게 카드를 꽂는다")
		pick.pressed.connect(func(): sel_member = i; refresh())

		UiKit.label(roster_root, Vector2(RIGHT_X + 150, y + 6), Vector2(280, 20),
			UiText.t("loadout.m05", "HP %d · 공격 %d · 사거리 %d · 이동 %d") % [
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
			var by := y + 30.0 + k * 27.0
			if k < slots.size():
				var c: Dictionary = Cards.TABLE[slots[k]]
				var b := UiKit.button(roster_root, Vector2(RIGHT_X + 12, by), Vector2(560, 26),
					"%d.  %s  ·  %s" % [k + 1, c["name"], c["text"]], 12)
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
				b.tooltip_text = UiText.t("loadout.m12", "누르면 손패로 돌아온다")
				b.pressed.connect(func(): run.unequip(i, k); refresh())
				slot_buttons_row[k] = b

				var up := UiKit.button(roster_root, Vector2(RIGHT_X + 576, by), Vector2(28, 26), "^", 11, 2)
				up.disabled = k == 0
				up.tooltip_text = UiText.t("loadout.m13", "우선순위를 올린다")
				up.pressed.connect(func(): run.move_slot(i, k, -1); refresh())

				var dn := UiKit.button(roster_root, Vector2(RIGHT_X + 606, by), Vector2(28, 26), "v", 11, 2)
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
			var warn := Shadow.warnings(slots, int(s["range"]))
			var wl := UiKit.label(roster_root, Vector2(RIGHT_X + 12, y + 30.0 + 3 * 27.0 - 8),
				Vector2(640, 18), "[!] " + warn[0], 10, UiKit.BAD)
			wl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# 직업 고유 기본기를 슬롯 바로 아래에 회색으로 붙인다.
		# "카드 3장이 전부 어긋나면 여기로 떨어진다" 는 관계가 화면에 그대로 보여야 한다.
		var own: Array = Innates.TABLE.get(tid, [])
		var iy := y + 30.0 + RunState.SLOTS_PER_UNIT * 27.0
		var txt := UiText.t("loadout.m16", "기본기 ↓  ")
		if own.is_empty():
			txt += UiText.t("loadout.m17", "(공통 골격만)")
		else:
			txt += "%s · %s" % [own[0]["name"], own[0]["text"]]
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

	var who := UiText.t("loadout.pick_unit_first", "유닛을 먼저 고르면 꽂을 수 있다.")
	var picked := sel_member >= 0 and sel_member < run.roster.size()
	var tid := ""
	if picked:
		tid = String(run.roster[sel_member]["type"])
		var room := (run.unit_cards[sel_member] as Array).size() < RunState.SLOTS_PER_UNIT
		var uname: String = UnitData.TABLE[tid]["name"]
		if room:
			who = UiText.t("loadout.equip_to", "%s 에게 꽂는다 - 카드는 다음 빈 슬롯, 특수는 특수 칸으로.") % uname
		else:
			who = UiText.t("loadout.equip_full", "%s 는 규칙 3칸이 다 찼다. 특수는 아직 꽂을 수 있다.") % uname

	UiKit.label(hand_root, Vector2(48, HAND_Y - 30), Vector2(1100, 24),
		UiText.t("loadout.hand_head", "손패 (카드 %d · 특수 %d)   ·   %s") % [
			run.hand.size(), run.special_hand.size(), who], 14,
		UiKit.TEXT if picked else UiKit.MUTED)

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
