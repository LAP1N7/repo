class_name RewardScreen
extends Control

## 스테이지 클리어 보상 - 3장 중 1장을 고른다.
##
## ── 왜 3택 1인가 ────────────────────────────────────────────────────────
## 전부 주면 선택이 아니다. 하나만 주면 보상이 아니라 지급이다.
## 셋 중 하나여야 "무엇을 포기했는가" 가 남고, 그게 런마다 다른 빌드를 만든다.
##
## ── 왜 정제권을 예산과 묶었나 ──────────────────────────────────────────
## 정제(카드 영구 삭제)를 상시 무료로 열어두면 누구나 덱을 최적으로 깎아서
## 오히려 빌드가 획일화된다. 보상 슬롯 하나를 써야 하는 자원으로 만들면
## "지금 덱을 다듬을까, 유닛을 키울까" 라는 진짜 저울질이 생긴다.

signal chosen()

enum Kind { UPGRADE, RARE, ECONOMY }

const CARD_Y: float = 210.0
## 카드가 좁아지면 줄이 더 접혀서 세로가 길어진다. 성장 힌트 한 줄이 패널 밖으로
## 흘러나가던 만큼 늘렸다.
const PANEL_H: float = 300.0

var run: RunState
var used_types: Array[String] = []

var root: Control
var lbl_head: Label


## used 는 방금 전투에 나갔던 유닛 종류들. 강화 보상은 이 중에서만 고른다.
func setup(p_run: RunState, used: Array) -> void:
	run = p_run
	used_types.clear()
	for t in used:
		if not used_types.has(String(t)):
			used_types.append(String(t))

	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Arknights 계열의 인상은 장식이 아니라 **정렬**에서 온다. 얇은 가로선 하나가
	# 화면 위를 가로지르면 아래 요소가 전부 그 선에 맞춰 정렬된 것처럼 읽힌다.
	UiKit.frame(self, UiKit.GOOD)

	var head := UiText.t("reward.head", "스테이지 %d 클리어") % run.stage_id
	if run.last_speed_bonus > 0:
		head += UiText.t("reward.speed_bonus", "     신속 제압  예산 +%d") % run.last_speed_bonus
	UiKit.label(self, Vector2(48, 40), Vector2(900, 40), head, 30, UiKit.GOOD)
	lbl_head = UiKit.label(self, Vector2(48, 84), Vector2(900, 24),
		UiText.t("reward.sub", "보상 하나를 고른다. 고르지 않은 것은 전부 사라진다."), 14, UiKit.MUTED)

	UiKit.label(self, Vector2(48, 116), Vector2(900, 22), "", 13, UiKit.FAINT)

	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	if run.pending_rewards.is_empty():
		run.pending_rewards = _roll_rewards()
	_build()


# ── 보상 뽑기 ────────────────────────────────────────────────────────────

## 시드는 런 상태에서 파생시킨다. 같은 진행이면 같은 보상이 나와야
## 영상을 다시 찍을 수 있다.
func _roll_rewards() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + run.stage_id * 131 + run.cleared * 17

	var out: Array = []

	# 1) 강화 - 이번 전투에 나갔던 유닛마다 한 장씩. 누구를 키울지는 플레이어가 정한다.
	#
	# 후반 스테이지는 한 번에 2단계씩 준다. 강화가 이 게임의 파워 곡선인데
	# 런 전체에서 받을 수 있는 횟수가 스테이지 수(4~5회)로 묶여 있어서,
	# 1단계씩만 주면 뒤로 갈수록 적의 성장을 못 따라간다.
	var levels: int = 1 if run.cleared < 3 else 2
	for t in used_types:
		if run.can_upgrade(t):
			out.append({ "kind": Kind.UPGRADE, "type": t, "levels": levels })

	# 2) 희귀 보상 - 상점에서 잘 안 나오는 것을 여기서 준다.
	#
	# 예전엔 `weight <= 1` 로 골랐는데, 카드의 weight 를 tier 로 바꾸면서 이 조건이
	# 조용히 무너졌다. get("weight", 3) 이 항상 3 을 돌려줘서 카드 쪽 풀이 통째로
	# 비었고, 희귀 보상이 매번 궁극기 하나(비영천참)로 고정됐다. 오류도 안 났다.
	#
	# 이제 상점과 같은 기준을 본다: 3티어 카드 + 궁극기 전부.
	# 궁극기는 뒤로 갈수록 더 자주 섞인다 - 상점의 등장 곡선과 방향을 맞춘다.
	var rare_pool: Array[String] = []
	for cid in Cards.deck_order():
		if int(Cards.TABLE[cid].get("tier", 1)) >= 3:
			rare_pool.append(cid)
	var special_copies: int = 1 + run.cleared / 2
	for sid in Specials.ORDER:
		for _i in special_copies:
			rare_pool.append(sid)
	if not rare_pool.is_empty():
		out.append({
			"kind": Kind.RARE,
			"id": rare_pool[rng.randi_range(0, rare_pool.size() - 1)],
		})

	# 3) 예산 + 정제권 - 항상 나온다. 앞의 둘이 비어도 고를 게 남아야 한다.
	#    금액은 방금 깬 스테이지에 따라 는다. (RunState.REWARD_BUDGET)
	out.append({
		"kind": Kind.ECONOMY,
		"budget": RunState.reward_budget(run.stage_id),
		"tokens": RunState.reward_tokens(run.stage_id),
	})
	return out


# ── 그리기 ───────────────────────────────────────────────────────────────

func _build() -> void:
	for c in root.get_children():
		c.queue_free()

	# 강화 후보가 유닛 수만큼 붙어서 최대 5장이 된다. 폭을 고정하면 화면을 넘친다.
	var n := run.pending_rewards.size()
	var gap := 40.0 if n <= 3 else 22.0
	var w: float = minf(300.0, (1200.0 - (n - 1) * gap) / maxf(1.0, float(n)))
	var span := n * w + (n - 1) * gap
	var x0 := (1280.0 - span) * 0.5

	for i in n:
		var r: Dictionary = run.pending_rewards[i]
		var x := x0 + i * (w + gap)
		_build_option(r, Vector2(x, CARD_Y), w)

	var summary := UiText.t("reward.summary", "현재 · 강화 %s · 정제권 %d · 다음 스테이지 예산 %d") % [
		_upgrade_summary(), run.refine_tokens,
		RunState.stage_budget(run.cleared + 1) + run.bonus_budget]
	UiKit.label(root, Vector2(48, 116), Vector2(1000, 22), summary, 13, UiKit.FAINT)


## 이 유닛이 어느 쪽으로 크는가. 성장 계수를 사람 말로 옮긴다.
func _growth_hint(tid: String) -> String:
	var gh := UnitData.growth(tid, "hp")
	var ga := UnitData.growth(tid, "atk")
	if ga >= gh + 30:
		return UiText.t("reward.growth_atk", "강화할수록 화력이 가파르게 는다.")
	if gh >= ga + 30:
		return UiText.t("reward.growth_hp", "강화할수록 벽이 두꺼워진다.")
	return UiText.t("reward.growth_even", "체력과 화력이 고르게 는다.")


func _upgrade_summary() -> String:
	var parts := PackedStringArray()
	for t in run.upgrades:
		if int(run.upgrades[t]) > 0:
			parts.append("%s+%d" % [UnitData.TABLE[t]["name"], int(run.upgrades[t])])
	return UiText.t("loadout.m09", "없음") if parts.is_empty() else " ".join(parts)


func _build_option(r: Dictionary, at: Vector2, w: float) -> void:
	var panel := _RewardCard.new()
	panel.position = at
	panel.size = Vector2(w, PANEL_H)
	root.add_child(panel)

	var title := ""
	var body := ""
	var accent := UiKit.TEXT
	# 카드가 자기 색을 알아야 외곽선을 그린다. 아래 match 가 accent 를 정한 뒤
	# 실제로 넘기는 것은 이 함수 끝이다.

	match int(r["kind"]):
		Kind.UPGRADE:
			var tid: String = r["type"]
			var s: Dictionary = UnitData.TABLE[tid]
			var lv := run.upgrade_level(tid)
			var up := int(r.get("levels", 1))
			var to: int = mini(RunState.MAX_UPGRADE, lv + up)
			title = UiText.t("reward.upgrade_title", "%s 강화") % s["name"]
			accent = s["color"]
			body = UiText.t("reward.m01", "+%d → +%d\n\nHP %d → %d\n공격 %d → %d\n\n%s") % [
				lv, to,
				run.upgraded_stat(tid, "hp", int(s["hp"])),
				UnitData.scaled(tid, "hp", int(s["hp"]), to),
				run.upgraded_stat(tid, "atk", int(s["atk"])),
				UnitData.scaled(tid, "atk", int(s["atk"]), to),
				# 어느 쪽으로 크는 유닛인지 한 줄로 알려 준다. 이게 없으면
				# 숫자만 보고 "그냥 제일 큰 거" 를 고르게 된다.
				_growth_hint(tid),
			]

		Kind.RARE:
			var id: String = r["id"]
			var is_sp := RunState.is_special(id)
			var d: Dictionary = Specials.TABLE[id] if is_sp else Cards.TABLE[id]
			# 궁극기는 직업 전용이다. 어느 대원 것인지 모르면 고를 수가 없다.
			if is_sp:
				title = UiText.t("reward.rare_special", "희귀 궁극기 · %s") 					% UnitData.TABLE[d["unit"]]["name"]
			else:
				title = UiText.t("reward.rare_card", "희귀 전술 모듈")
			accent = UiKit.ACCENT
			# 이미 가진 카드면 합성된다는 걸 고르기 **전에** 알려 준다.
			var fate := UiText.t("reward.m02", "규칙 슬롯에 꽂는다")
			if is_sp:
				fate = UiText.t("reward.m03", "%s 전용 · 전투당 1회") % UnitData.TABLE[d["unit"]]["name"]
			elif run.can_merge(id):
				fate = UiText.t("reward.m04", "이미 가지고 있다 → 받으면 %d단계로 합성") % (run.card_level(id) + 1)
			# 제목이 이미 "희귀 ..." 라 본문에서 또 희귀하다고 말할 필요가 없다.
			# 한 줄이 더 붙으면 패널 밖으로 흘러나간다.
			body = UiText.t("reward.m05", "%s

%s

%s") % [
				d["name"], d["text"], fate,
			]

		Kind.ECONOMY:
			title = UiText.t("reward.economy", "보급")
			accent = UiKit.GOOD
			body = UiText.t("reward.economy_body", "예산 +%d\n정제권 +%d\n\n정제권은 손패에서 카드를\n영구히 버릴 때 쓴다.\n\n덱이 두꺼워지면 원하는 카드가\n덜 나온다. 그때 깎아라.") % [
				int(r["budget"]), int(r["tokens"])]

	panel.accent = accent
	panel.queue_redraw()

	UiKit.label(panel, Vector2(16, 14), Vector2(w - 32, 26), title, 18, accent, true)
	UiKit.label(panel, Vector2(16, 48), Vector2(w - 32, PANEL_H - 108), body, 13,
		UiKit.TEXT, true)

	var b := UiKit.button(panel, Vector2(16, PANEL_H - 50), Vector2(w - 32, 34), UiText.t("reward.take", "이걸로"), 15)
	b.pressed.connect(_pick.bind(r))


func _pick(r: Dictionary) -> void:
	match int(r["kind"]):
		Kind.UPGRADE:
			for _i in int(r.get("levels", 1)):
				run.apply_upgrade(String(r["type"]))
		Kind.RARE:
			# 이미 가진 카드면 손패에 쌓지 않고 합성한다. 슬롯이 차 있어도
			# 죽은 보상이 되지 않는다. (run_state.grant_card 주석 참조)
			run.grant_card(String(r["id"]))
		Kind.ECONOMY:
			# budget 이 아니라 bonus_budget 에 쌓는다. budget 은 다음 스테이지
			# start() 에서 재계산되므로 여기에 더하면 그대로 지워진다.
			run.bonus_budget += int(r["budget"])
			run.budget += int(r["budget"])
			run.refine_tokens += int(r["tokens"])

	# 고른 순간 나머지는 사라진다. 다음 보상은 새로 뽑는다.
	run.pending_rewards.clear()
	chosen.emit()


## 보상 한 장. 상점 모듈과 같은 어법으로 그린다.
##
## ── 왜 같은 모양이어야 하는가 ────────────────────────────────────────────
## 보상 고르기와 모듈 사기는 플레이어에게 같은 종류의 행위다 - 여러 장을 훑고
## 하나를 고르면 나머지는 사라진다. 그런데 생김새가 다르면 뇌가 다른 물건으로
## 분류해서, 상점에서 익힌 읽는 법을 여기서 다시 배워야 한다.
##
## 그래서 사선 프레임과 낮은 채도 네온을 그대로 가져왔다.
## (view/card_node.gd 의 _neon 주석 참조)
class _RewardCard extends Control:
	var accent: Color = Color(0.7, 0.7, 0.7)

	var _hover: bool = false
	var _k: float = 0.0

	## 상점 모듈과 같은 손맛을 준다. 여기도 "여러 장을 훑고 하나를 고르는" 화면이라
	## 만져지는 반응이 같아야 한다. 다만 카드 안 글자는 이미 다 보이므로 확대는
	## 상점만큼 크게 줄 필요가 없다 - 들어 올리는 정도면 충분하다.
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		pivot_offset = size * 0.5
		mouse_entered.connect(func(): _hover = true)
		mouse_exited.connect(func(): _hover = false)

	func _process(delta: float) -> void:
		var t: float = clampf(delta * 12.0, 0.0, 1.0)
		_k = lerp(_k, 1.0 if _hover else 0.0, t)
		scale = Vector2.ONE * (1.0 + 0.05 * _k)
		position.y = _base_y() - 10.0 * _k
		z_index = 20 if _hover else 0
		queue_redraw()

	var _by: float = -99999.0
	func _base_y() -> float:
		if _by < -9999.0:
			_by = position.y
		return _by

	func _draw() -> void:
		var s := size
		var cut := 16.0
		var shape := PackedVector2Array([
			Vector2(cut, 0), Vector2(s.x, 0), Vector2(s.x, s.y - cut),
			Vector2(s.x - cut, s.y), Vector2(0, s.y), Vector2(0, cut),
		])
		draw_colored_polygon(shape, Color(0.11, 0.13, 0.17, 0.96))

		# 채도를 눌러 쓴다. 다섯 장이 나란히 서므로 원색이면 화면이 요란해진다.
		var neon := Color.from_hsv(accent.h, minf(accent.s, 0.42),
			clampf(accent.v * 1.25 + 0.18, 0.0, 1.0), 1.0)
		var line := PackedVector2Array(shape)
		line.append(shape[0])
		draw_polyline(line, Color(neon.r, neon.g, neon.b, 0.55 + 0.45 * _k), 1.8, true)
		draw_polyline(line, Color(neon.r, neon.g, neon.b, 0.18), 4.0, true)

		# 상단 색 띠. 멀리서도 무슨 종류인지 갈린다.
		draw_colored_polygon(PackedVector2Array([
			Vector2(cut + 1, 1), Vector2(s.x - 1, 1),
			Vector2(s.x - 1, 5), Vector2(cut - 4, 5),
		]), neon)
