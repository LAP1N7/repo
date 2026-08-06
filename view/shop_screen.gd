class_name ShopScreen
extends Control

## 1단계 - 덱 구성. 예산 안에서 규칙 카드를 사 모은다.
##
## 여기서 사기 카드가 통제된다. 예산이 하나뿐이라 강한 카드를 여러 장 사면
## 슬롯 9칸을 채울 값싼 카드가 모자란다.

signal done()
signal help()
signal command()

## 튜토리얼이 붙어 있으면 앵커를 등록하고 행동을 알린다. 없으면 전부 무시된다.
var tut: Tutorial = null

const SHOP_Y: float = 156.0
## 상점 카드(156~352)와 안내문(366) 아래.
const HAND_Y: float = 500.0

## 조작 버튼 줄의 y. 카드 아래끝(156+196=352)에서 넉넉히 띄운다.
## 카드는 호버하면 위로 떠오르므로 바짝 붙이면 손이 겹친다.
const BAR_Y: float = 374.0

var run: RunState

var lbl_budget: Label
var lbl_note: Label
var lbl_hint: Label
var lbl_strategy: Label
var btn_reroll: Button
var btn_refine: Button
var btn_merge: Button
var btn_command: Button
var sfx: Sfx
## 정제 모드: 손패 카드를 누르면 사는 게 아니라 영구히 버린다.
var refining: bool = false
var merging: bool = false
var btn_next: Button
var shop_root: Control
var hand_root: Control


func setup(p_run: RunState) -> void:
	run = p_run
	sfx = Sfx.new()
	add_child(sfx)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Arknights 계열의 인상은 장식이 아니라 **정렬**에서 온다. 얇은 가로선 하나가
	# 화면 위를 가로지르면 아래 요소가 전부 그 선에 맞춰 정렬된 것처럼 읽힌다.
	UiKit.frame(self, Axes.color(Axes.TARGET))

	UiKit.phase_header(self, Vector2(40, 20), 0)
	UiKit.label(self, Vector2(40, 60), Vector2(760, 22),
		UiText.t("shop.sub", "예산 안에서 규칙 카드를 산다. 산 카드만 유닛에게 꽂을 수 있다."), 13, UiKit.MUTED)

	lbl_budget = UiKit.label(self, Vector2(900, 26), Vector2(340, 34), "", 24, UiKit.ACCENT)
	lbl_budget.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# ── 스테이지 선택기는 뺐다 ───────────────────────────────────────────
	# 다섯 칸짜리 버튼 줄이 화면 위를 가로질렀는데, 런은 1부터 5까지 순서대로만
	# 간다. 고를 수 없는 것을 고를 수 있게 그려 놓으면 그 줄은 정보가 아니라
	# 소음이다. 지금 어느 판인지는 머리말이 이미 말하고 있다.
	#
	# 대신 그 자리를 적 정보에 준다. 적 알고리즘은 숨기지 않고 그대로 공개한다 -
	# 숨기면 시행착오 게임이 되고, 공개하면 추리 게임이 된다. (DESIGN 2.4)
	lbl_strategy = UiKit.label(self, Vector2(40, 90), Vector2(1000, 22), "", 13, UiKit.BAD)
	lbl_note = UiKit.label(self, Vector2(40, 116), Vector2(900, 22), "", 13, UiKit.MUTED)

	shop_root = Control.new()
	shop_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shop_root)

	hand_root = Control.new()
	hand_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hand_root)

	# ── 조작 줄은 손패보다 **나중에** 만든다 ─────────────────────────────
	# 자식은 나중에 붙은 것이 위에 그려진다. 예전에는 버튼을 hand_root 보다
	# 먼저 만들어서, 손패가 늘어나면 카드가 버튼을 덮고 클릭까지 먹었다.
	# 만드는 순서 한 줄이 곧 레이어 순서다.
	var bar := Control.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	# 카드는 SHOP_Y(156)에서 시작해 높이 196 이므로 352 에서 끝난다.
	# 카드 아래 여백을 넉넉히 둬야 호버로 카드가 떠오를 때 버튼과 안 겹친다.
	btn_reroll = UiKit.button(bar, Vector2(40, BAR_Y), Vector2(190, 38), "", 14)
	btn_reroll.pressed.connect(_on_reroll)

	btn_refine = UiKit.button(bar, Vector2(240, BAR_Y), Vector2(210, 38), "", 14)
	btn_refine.pressed.connect(_on_refine_toggle)

	# 합성은 축 개편에서 빠졌다. 자리를 되살릴 계획(환전·교환)이 있으므로
	# 노드는 남기고 보이지만 않게 한다. 지우면 배치를 다시 잡아야 한다.
	btn_merge = UiKit.button(bar, Vector2(460, BAR_Y), Vector2(210, 38), "", 14)
	btn_merge.pressed.connect(_on_merge_toggle)
	btn_merge.visible = false
	btn_merge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 보조 지휘는 정제 옆이다. 셋 다 "예산을 어디에 쓸까" 라서, 재검색·정제와
	# 나란히 놓여야 같은 저울에 올려놓고 고르게 된다.
	btn_command = UiKit.button(bar, Vector2(460, BAR_Y), Vector2(210, 38),
		UiText.t("shop.command", "보조 지휘  →"), 14)
	btn_command.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))
	btn_command.pressed.connect(func(): command.emit())

	lbl_hint = UiKit.label(bar, Vector2(40, BAR_Y + 46), Vector2(1200, 22),
		"", 12, UiKit.MUTED)

	var b_help := UiKit.button(self, Vector2(880, 630), Vector2(140, 36), UiText.t("shop.help", "게임 방법"), 14)
	b_help.pressed.connect(func(): help.emit())

	btn_next = UiKit.button(self, Vector2(1040, 650), Vector2(200, 44), UiText.t("shop.next", "편성하러 가기  →"), 16)
	btn_next.pressed.connect(func():
		if tut != null:
			tut.notify_action("next")
		done.emit()
	)
	if tut != null:
		tut.register_anchor("shop_reroll", btn_reroll)
		tut.register_anchor("shop_next", btn_next)

	refresh()


func refresh() -> void:
	# 가산금과 리롤값은 이번 스테이지에 산 만큼 오른다. 값이 왜 올랐는지
	# 화면에 안 적히면 "버그인가?" 가 된다.
	var sur := run.surcharge()
	lbl_budget.text = UiText.t("shop.budget", "예산  %d") % run.budget
	if sur > 0:
		# 자리 표시 개수와 인자 개수가 반드시 같아야 한다. 하나라도 어긋나면
		# 치환이 통째로 실패해 "%d" 가 화면에 그대로 뜬다.
		lbl_budget.text += UiText.t("shop.budget_surcharge", "  (+%d)") % sur
	# 제외권이 몇 장 남았는지 안내문에 적는다. 카드마다 숫자가 붙지만,
	# 지금 몇 장인지를 한 곳에서도 말해 줘야 "쓸까 말까" 를 결정할 수 있다.
	lbl_hint.text = UiText.t("shop.hint",
		"카드를 누르면 구매.  [제외] 는 그 모듈을 작전 전체에서 없앤다 - 제외권 %d장 남음") 		% run.ban_tokens
	btn_reroll.text = UiText.t("shop.reroll", "리롤  (-%d)") % run.reroll_cost()
	btn_reroll.disabled = not run.can_reroll()

	# ── 다음 판이 어떤 판인지 한 줄로 다 말한다 ──────────────────────────
	# 편성을 짜기 전에 알아야 할 것은 "이 판이 무엇을 요구하는가" 하나다.
	# 적 알고리즘 · 페이즈 수 · 지형 기믹 · 등장 특성을 한 줄에 모은다.
	# 나눠 놓으면 읽는 순서가 정해지지 않아서 결국 아무도 안 읽는다.
	var st := Stages.get_stage(run.stage_id)
	var line := UiText.t("shop.enemy_strategy", "적 전략:  %s") % st["strategy_text"]
	var waves: int = Stages.waves(st).size()
	if waves > 1:
		line += UiText.t("shop.waves", "     %d 페이즈") % waves
	var hz := Stages.hazard(run.stage_id)
	if not hz.is_empty():
		line += UiText.t("shop.hazard", "     %s") % String(hz.get("name", ""))
	for t in Stages.trait_list(run.stage_id):
		line += "     " + Traits.describe(t).split(" - ")[0]
	lbl_strategy.text = line

	# 정제권이 없으면 정제 모드로 들어갈 수 없다.
	if run.refine_tokens <= 0:
		refining = false
	btn_refine.text = UiText.t("shop.refine", "덱 정제  (정제권 %d)") % run.refine_tokens
	btn_refine.disabled = run.refine_tokens <= 0 		or (run.hand.is_empty() and run.special_hand.is_empty())
	btn_refine.modulate = UiKit.BAD if refining else Color(1, 1, 1)

	# 합성 가능한 카드가 하나라도 있어야 켜진다.
	var mergeable := 0
	for cid in run.hand:
		if run.can_merge(String(cid)):
			mergeable += 1
	if mergeable == 0:
		merging = false
	btn_merge.text = UiText.t("shop.merge", "카드 합성  (%d장 가능)") % mergeable
	btn_merge.disabled = mergeable == 0
	btn_merge.modulate = UiKit.GOOD if merging else Color(1, 1, 1)

	_build_shop()
	_build_hand()

	var n := run.hand.size() + run.special_hand.size()
	if n == 0:
		lbl_note.text = UiText.t("shop.empty_hand", "아직 산 카드가 없다. 카드가 없으면 유닛은 직업 기본기만으로 싸운다.")
		lbl_note.add_theme_color_override("font_color", UiKit.MUTED)
	else:
		lbl_note.text = UiText.t("shop.hand_summary", "손패 %d장 (특수 %d) · 사용한 예산 %d") % [
			n, run.special_hand.size(), run.spent()]
		lbl_note.add_theme_color_override("font_color", UiKit.GOOD if n >= 3 else UiKit.MUTED)

	# 손패 장수로 진행을 막지 않는다.
	# 예전에는 3장 미만이면 막았는데, 코스트 0 카드(사수)가 1코가 되면서
	# "예산을 리롤로 다 태우고 손패가 2장" 이면 되돌릴 방법이 없는 소프트락이 됐다.
	# 기본기가 있으니 빈손으로도 전투는 성립한다. 막을 이유가 없다.
	btn_next.disabled = false


func _build_shop() -> void:
	for c in shop_root.get_children():
		c.queue_free()

	var total := run.offers.size()
	var gap := 18.0
	var w := CardNode.W
	var span := total * w + (total - 1) * gap
	var x0 := (1280.0 - span) * 0.5

	# 보유 모듈로 한 장만 더 채우면 켜지는 교리들. { 모듈 id: 교리 이름 }
	var near: Dictionary = {}
	# 손패만 보면 안 된다. 이미 대원에게 장착한 모듈은 손패에서 빠져 있어서,
	# 한 장 남은 교리가 있어도 "완성" 안내가 안 떴다. 보유 + 장착을 다 센다.
	var owned: Array = []
	owned.append_array(run.hand)
	for row in run.unit_cards:
		owned.append_array(row)
	for n in Doctrines.near_complete(owned):
		near[String(n["need"])] = String((n["doctrine"] as Dictionary)["name"])

	for i in total:
		var cid: String = run.offers[i]
		var card := CardNode.new()
		shop_root.add_child(card)
		card.setup(cid, i, false, cid != "", run.ban_tokens)
		card.enabled = run.can_buy(i)
		if cid != "" and not run.can_buy(i):
			card.note = UiText.t("shop.note_poor", "예산 부족 (%d)") % run.price_of(cid)
		elif cid != "" and near.has(cid):
			# ── 교리 완성 안내 ────────────────────────────────────────────
			# 이 게임은 모듈을 모으는 게 아니라 교리를 완성하는 게임이다.
			# 완성까지 한 장 남았다는 사실이 안 보이면 그 재미가 통째로 사라진다.
			card.note = UiText.t("shop.note_doctrine", "%s 완성") % near[cid]
		card.place(Vector2(x0 + i * (w + gap), SHOP_Y))
		card.clicked.connect(_on_buy)
		card.banned.connect(_on_ban)
		if tut != null:
			tut.register_anchor("shop_card_%d" % i, card)
			if card.get_child_count() > 0 and card.get_child(0) is Button:
				tut.register_anchor("shop_ban_%d" % i, card.get_child(0))


## 손패는 발라트로처럼 부채꼴로 겹쳐 깐다. 장수가 늘면 자동으로 더 겹친다.
func _build_hand() -> void:
	for c in hand_root.get_children():
		c.queue_free()

	# 규칙 카드와 특수 스킬을 한 줄에 같이 깐다. 둘 다 "산 것" 이고,
	# 어느 유닛에 무엇을 꽂을지는 2단계에서 정한다.
	var owned: Array[String] = []
	for cid in run.hand:
		owned.append(cid)
	for sid in run.special_hand:
		owned.append(sid)

	var head := UiText.t("shop.hand_head", "손패  (카드 %d · 특수 %d)") % [run.hand.size(), run.special_hand.size()]
	var head_col := UiKit.TEXT
	if refining:
		head += UiText.t("shop.hand_refining", "     <- 버릴 카드를 누른다 (정제권 %d)") % run.refine_tokens
		head_col = UiKit.BAD
	elif merging:
		head += UiText.t("shop.hand_merging", "     <- 같은 카드 2장을 1장으로 합쳐 한 단계 올린다")
		head_col = UiKit.GOOD
	UiKit.label(hand_root, Vector2(40, HAND_Y - 34), Vector2(760, 24), head, 17, head_col)

	var n := owned.size()
	if n == 0:
		return

	var mini_w := CardNode.W * 0.72
	var max_span := 1000.0
	var step: float = minf(mini_w + 12.0, (max_span - mini_w) / maxf(1.0, float(n - 1)))
	var span := mini_w + step * (n - 1)
	var x0 := (1280.0 - span) * 0.5
	var mid := (n - 1) * 0.5

	for i in n:
		var card := CardNode.new()
		hand_root.add_child(card)
		card.setup(owned[i], i, true, false)
		card.level = run.card_level(String(owned[i]))
		# 평소 손패는 보기 전용이다(장착은 2단계). 정제·합성 모드에서만 눌린다.
		card.enabled = refining or (merging and run.can_merge(String(owned[i])))
		if refining:
			card.note = UiText.t("shop.note_discard", "누르면 버림")
			card.clicked.connect(_on_hand_refine)
		elif merging:
			var cid2 := String(owned[i])
			if run.can_merge(cid2):
				card.note = UiText.t("shop.note_merge", "합성 -%d") % run.merge_price(cid2)
				card.clicked.connect(_on_hand_merge)
			else:
				card.note = run.merge_blocker(cid2)
		var offset := float(i) - mid
		# 가운데가 높고 양끝이 낮은 아치
		var arc := absf(offset) * 3.0
		card.place(Vector2(x0 + i * step, HAND_Y + arc), offset * 0.02)


func _on_merge_toggle() -> void:
	merging = not merging
	if merging:
		refining = false
	refresh()


func _on_hand_merge(card: CardNode) -> void:
	if run.merge(card.card_id):
		sfx.play("special")
		refresh()


func _on_buy(card: CardNode) -> void:
	if run.buy(card.index):
		sfx.play("buy")
		if tut != null:
			tut.notify_action("buy")
		refresh()


func _on_ban(card: CardNode) -> void:
	if run.ban(card.index):
		if tut != null:
			tut.notify_action("ban")
		refresh()


## 정제 = 손패에서 카드를 영구히 버린다.
##
## 덱이 두꺼워질수록 원하는 카드가 뽑힐 확률이 떨어진다. 정제는 그걸 되돌리는
## 유일한 수단이고, 정제권은 보상에서만 나온다. 상시 무료로 열어두면 누구나
## 덱을 최적으로 깎아서 오히려 빌드가 획일화된다.
func _on_refine_toggle() -> void:
	refining = not refining
	if refining:
		merging = false
	refresh()


func _on_hand_refine(card: CardNode) -> void:
	if run.refine(card.card_id):
		refresh()


func _on_reroll() -> void:
	if run.reroll():
		sfx.play("click")
		refresh()
