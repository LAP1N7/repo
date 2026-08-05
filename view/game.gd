extends Node2D

## 루트. 화면을 갈아 끼우고 RunState 하나를 런 내내 들고 있다.
##
##   상점 → 편성/배치 → 전투 ──승리──→ 보상 ──→ (다음 스테이지) 상점 …
##                        ↑                              마지막이면 런 종료
##                        └── 패배 시 편성으로 되돌아가 재도전
##
## ── 로그라이트의 핵심은 "무엇이 남는가" 다 ─────────────────────────────
## 스테이지를 넘어갈 때 RunState 를 버리지 않는다. 남는 것:
##   손패(덱) · 유닛 강화 단계 · 정제권 · 누적 예산
## 리셋되는 것: 편성/배치, 상점 제시 목록
## 예전에는 스테이지를 바꿀 때마다 전부 초기화해서 "쌓아 올린다" 는 감각이 없었다.

## 화면은 전부 별도 씬 파일이다.
##
## 예전에는 game.gd 가 X.new() 로 직접 만들었는데, 그러면 Godot 에디터에서 화면을
## 열어 볼 수도, 스프라이트를 얹을 수도 없다. 아트를 붙이려면 씬이 있어야 한다.
## 로직은 그대로 스크립트가 들고 있고, 씬은 "에디터에서 만질 수 있는 껍데기" 다.
const SCN_TITLE := preload("res://scenes/title_screen.tscn")
const SCN_HELP := preload("res://scenes/help_screen.tscn")
const SCN_SHOP := preload("res://scenes/shop_screen.tscn")
const SCN_LOADOUT := preload("res://scenes/loadout_screen.tscn")
const SCN_BATTLE := preload("res://scenes/battle_view.tscn")
const SCN_REWARD := preload("res://scenes/reward_screen.tscn")
const SCN_RUN_CLEAR := preload("res://scenes/run_clear_screen.tscn")
const SCN_TUT_INTRO := preload("res://scenes/tutorial_intro_screen.tscn")
const SCN_LOADING := preload("res://scenes/loading_screen.tscn")

var run: RunState
var current: Node = null

## 튜토리얼. 화면을 가로질러 진행되므로 루트가 하나만 들고 다닌다.
## 평상시에는 active 가 false 라 모든 화면이 무시한다.
var tut := Tutorial.new()

## 방금 전투에 내보낸 유닛 종류. 강화 보상은 이 중에서만 고른다.
var last_used_types: Array[String] = []


func _ready() -> void:
	run = RunState.new()
	run.start_run(1)

	if OS.get_environment("GG_STAGE") != "":
		run.start_run(int(OS.get_environment("GG_STAGE")))

	# 개발용 훅. 화면 캡처와 백업 영상 촬영에 쓴다.
	#   GG_SCREEN=loadout | loadout_full | battle | reward
	match OS.get_environment("GG_SCREEN"):
		"loadout":
			_autofill_shop()
			goto_loadout()
		"loadout_full":
			_autofill_shop()
			_autofill_party()
			goto_loadout()
		"battle":
			_autofill_shop()
			_autofill_party()
			goto_battle()
		"reward":
			_autofill_shop()
			_autofill_party()
			last_used_types = ["warrior", "archer"] as Array[String]
			run.on_stage_cleared()
			goto_reward()
		"tutorial":
			start_tutorial()
		_:
			# 부팅 직후에는 로딩 연출을 넣지 않는다.
			#
			# 웹에서는 셸(assets/web/shell.html)이 wasm 38MB 를 받는 동안 같은
			# 연출을 이미 10~30초 보여 준다. 게임이 뜨자마자 또 2초를 붙이면
			# 같은 화면을 두 번 보는 셈이다. 데스크톱은 즉시 뜨므로 애초에
			# 기다릴 것이 없다.
			#
			# 로딩 연출이 값을 하는 자리는 **전투 직전**뿐이다. 거기는 실제로
			# 국면이 바뀌는 지점이라 호흡이 필요하다.
			goto_title()


func _swap(node: Node) -> void:
	if current != null:
		current.queue_free()
	current = node
	add_child(node)


# ── 화면 ─────────────────────────────────────────────────────────────────

## 로딩 연출을 한 번 끼우고 next 를 부른다.
##
## 실제로 로딩할 것은 없다(씬이 전부 코드다). 세계관 톤과 TIP 전달이 목적이고,
## 아무 키나 눌러 즉시 건너뛸 수 있다. (view/loading_screen.gd 주석 참조)
func goto_loading(next: Callable) -> void:
	var s := SCN_LOADING.instantiate() as LoadingScreen
	_swap(s)
	s.setup()
	s.done.connect(next)


func goto_title() -> void:
	var s := SCN_TITLE.instantiate() as TitleScreen
	_swap(s)
	s.setup()
	s.start_run.connect(func():
		run.start_run(1)
		goto_shop()
	)
	s.show_help.connect(func(): goto_help(true))
	s.start_tutorial.connect(start_tutorial)


## from_title 이 참이면 돌아갈 곳이 타이틀, 아니면 상점이다.
func goto_help(from_title: bool) -> void:
	var s := SCN_HELP.instantiate() as HelpScreen
	_swap(s)
	s.setup()
	s.back.connect(goto_title if from_title else goto_shop)


## 튜토리얼 시작. 고정된 상점·편성·스테이지로 한 판을 끝까지 같이 치른다.
func start_tutorial() -> void:
	run.start_run(Stages.TUTORIAL_ID)
	# 대본이 특정 카드를 지목하므로 상점을 고정한다. 무작위면 대사가 헛돈다.
	run.fixed_offers = ["engage", "keep_distance", "finisher", "pursue", "hold_ground"] as Array[String]
	run.budget = 12
	run.offers.clear()
	run._fill_offers()
	tut.load_script()
	tut.start()
	if not tut.finished.is_connected(_on_tutorial_finished):
		tut.finished.connect(_on_tutorial_finished)
	# 개발용: GG_TUTSTEP 으로 특정 대사부터 시작한다. 캡처와 검증에 쓴다.
	var jump := OS.get_environment("GG_TUTSTEP")
	if jump != "":
		tut.index = clampi(int(jump), 0, tut.steps.size() - 1)
		var scr := String(tut.current().get("screen", "tutorial"))
		match scr:
			"shop": goto_shop()
			"loadout": goto_loadout()
			"battle": goto_battle()
			_: goto_tutorial_intro()
		return

	goto_tutorial_intro()


func _on_tutorial_finished() -> void:
	tut.stop()
	goto_title()


func goto_tutorial_intro() -> void:
	var s := SCN_TUT_INTRO.instantiate() as TutorialIntroScreen
	_swap(s)
	s.setup(tut)
	s.done.connect(goto_shop)


## 화면이 바뀔 때마다 앵커를 새로 등록해야 한다. 이전 화면의 노드는 이미 사라졌다.
func _bind_tutorial(screen: Node, screen_name: String) -> void:
	if not tut.active:
		return
	tut.clear_anchors()
	screen.set("tut", tut)


## 튜토리얼 오버레이를 화면 위에 얹는다. 화면 UI 가 다 만들어진 뒤에 불러야 한다.
func _attach_overlay(screen: Node, screen_name: String) -> void:
	if not tut.active or not tut.is_for_screen(screen_name):
		return
	# 반드시 별도 CanvasLayer 에 올린다. BattleView 는 자기 UI 를 CanvasLayer 에
	# 담는데, 캔버스 레이어끼리는 z_index 로 순서를 못 뒤집는다. 화면에 그냥
	# add_child 하면 오버레이가 z_index 200 이어도 조작 버튼 밑으로 깔린다.
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	screen.add_child(canvas)
	var ov := TutorialOverlay.new()
	canvas.add_child(ov)
	# 잠글 대상은 canvas 가 아니라 screen 이다. canvas 를 넘기면 그 밑에 오버레이
	# 하나뿐이라 아무것도 안 잠긴다.
	ov.setup(tut, screen)
	var refresh := func():
		if tut.active and tut.is_for_screen(screen_name):
			ov.refresh()
		else:
			ov.visible = false
	tut.step_changed.connect(refresh)


func goto_shop() -> void:
	var s := SCN_SHOP.instantiate() as ShopScreen
	_swap(s)
	_bind_tutorial(s, "shop")
	s.setup(run)
	_attach_overlay(s, "shop")
	s.done.connect(goto_loadout)
	s.help.connect(func(): goto_help(false))


func goto_loadout() -> void:
	var s := SCN_LOADOUT.instantiate() as LoadoutScreen
	_swap(s)
	_bind_tutorial(s, "loadout")
	s.setup(run)
	_attach_overlay(s, "loadout")
	s.back.connect(goto_shop)
	s.fight.connect(func():
		# 강화 보상 후보를 만들려면 누가 나갔는지 기억해야 한다.
		last_used_types.clear()
		for m in run.roster:
			last_used_types.append(String(m["type"]))
		goto_battle()
	)


## 전투 직전에도 한 번 끼운다. 시뮬레이션이 새로 도는 순간이라 세계관상 자리가 맞고,
## 편성 화면에서 전투 화면으로 바로 튀는 것보다 호흡이 생긴다.
## 튜토리얼 중에는 건너뛴다 - 대본이 화면 순서를 세고 있어서 끼면 어긋난다.
func goto_battle() -> void:
	if not tut.active:
		goto_loading(_do_goto_battle)
		return
	_do_goto_battle()


func _do_goto_battle() -> void:
	var s := SCN_BATTLE.instantiate() as BattleScreen
	_swap(s)
	_bind_tutorial(s, "battle")
	s.setup(run)
	_attach_overlay(s, "battle")
	s.to_loadout.connect(goto_loadout)
	s.to_shop.connect(func():
		# 덱부터 다시 = 이번 스테이지의 상점만 다시. 런 상태는 유지된다.
		run.start(run.stage_id)
		goto_shop()
	)
	s.won.connect(func():
		# 튜토리얼은 보상 화면을 거치지 않는다. 마무리 대사만 하고 타이틀로 돌아간다.
		if tut.active:
			tut.advance()
			return
		run.on_stage_cleared(s.battle.tick)
		goto_reward()
	)


func goto_reward() -> void:
	var s := SCN_REWARD.instantiate() as RewardScreen
	_swap(s)
	s.setup(run, last_used_types)
	s.chosen.connect(func():
		if run.advance():
			goto_shop()
		else:
			goto_run_clear()
	)


func goto_run_clear() -> void:
	var s := SCN_RUN_CLEAR.instantiate() as RunClearScreen
	_swap(s)
	s.setup(run)
	s.restart.connect(goto_title)


# ── 개발용 자동 채우기 ───────────────────────────────────────────────────
# 캡처 편의 기능일 뿐 게임 규칙이 아니다.

func _autofill_shop() -> void:
	var guard := 0
	while run.hand.size() < 9 and guard < 60:
		guard += 1
		var bought := false
		for i in run.offers.size():
			if run.can_buy(i):
				run.buy(i)
				bought = true
				break
		if not bought and not run.reroll():
			break


func _autofill_party() -> void:
	run.place("musketeer", 0)
	run.place("archer", 2)
	run.place("warrior", 4)
	var m := 0
	while not run.hand.is_empty() and m < 3:
		if not run.equip(m, run.hand[0]):
			m += 1
