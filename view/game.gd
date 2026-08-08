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
const SCN_COMMAND := preload("res://scenes/command_screen.tscn")
const SCN_LOADOUT := preload("res://scenes/loadout_screen.tscn")
const SCN_BATTLE := preload("res://scenes/battle_view.tscn")
const SCN_REWARD := preload("res://scenes/reward_screen.tscn")
const SCN_RUN_CLEAR := preload("res://scenes/run_clear_screen.tscn")
const SCN_TUT_INTRO := preload("res://scenes/tutorial_intro_screen.tscn")
const SCN_LOADING := preload("res://scenes/loading_screen.tscn")
const SCN_STORY := preload("res://scenes/story_screen.tscn")

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
	#   GG_SCREEN=shop | loadout | loadout_full | battle | reward
	match OS.get_environment("GG_SCREEN"):
		"shop":
			# 상점 자체를 찍기 위한 훅. 예산을 반쯤 쓴 상태로 둔다.
			_autofill_shop()
			run.start(run.stage_id)
			goto_shop()
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
			play_story("post", run.stage_id, goto_reward)
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


## 오디오 잠금 해제용.
##
## 화면은 계속 갈리지만 Game 은 처음부터 끝까지 살아 있다. 조작을 여기서
## 세야 로딩 화면의 스킵 클릭도 놓치지 않는다. (core/sfx.gd 의 _unlocked 참조)
func _input(e: InputEvent) -> void:
	Sfx.mark_gesture(e)


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
		play_story("pre", run.stage_id, goto_shop)
	)
	s.show_help.connect(goto_story_preview)
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
	# ── 상점을 고정한다 ────────────────────────────────────────────────
	# 대본이 "0번을 사라 · 2번을 제외하라" 처럼 자리를 지목하므로 무작위면
	# 대사가 통째로 헛돈다.
	#
	# 여기 있던 다섯 개(engage / keep_distance / pursue / hold_ground)는
	# **지금 표에 없는 이름**이었다. 축을 도입하면서 모듈 표를 갈아엎었는데
	# 이 줄이 안 따라왔다 - 튜토리얼 상점이 통째로 빈 것이 그 때문이다.
	#
	# 지금 이름으로 다시 짠다. 세 축을 한 번씩 보여 주는 배치다.
	#   0 근접 추적(TARGET 1)   - 사서 꽂는다
	#   1 거리 유지(POSITION 3) - 사서 꽂는다. 카이팅이 여기서 나온다
	#   2 방어 태세(DOCTRINE 2) - 제외로 버리는 시범
	#   3 처형(TARGET 3) · 4 전열 유지(POSITION 2) - 예산이 모자라 못 산다
	run.fixed_offers = ["near_first", "keep_range", "guard_stance",
		"execute", "front_line"] as Array[String]
	run.budget = 12
	# ── 정제권 한 장 ────────────────────────────────────────────────────
	# 대본이 "[제외] 를 누르십시오" 라고 시키는데 정제권이 0 이라 버튼이
	# 꺼져 있었다. 시키는 대로 해도 안 되는 튜토리얼은 튜토리얼이 아니다.
	#
	# 딱 한 장만 준다. 그리고 그 한 장을 엉뚱한 카드에 쓰는 일은 대본이
	# 막는다 - 앞 두 대사는 gate 가 걸려 있고 앵커가 카드 본체(shop_card_0/1)
	# 라, 그동안 [제외] 버튼은 아예 안 눌린다. 눌리는 순간은 앵커가
	# shop_ban_2 인 그 대사 하나뿐이다.
	#
	# 튜토리얼이 끝나면 start_run() 이 refine_tokens 를 0 으로 되돌리므로
	# 본편으로 새어 나가지 않는다.
	run.refine_tokens = 1
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
	# 튜토리얼은 상점·편성·교전이 한 덩어리다. 화면마다 곡이 바뀌면 그 덩어리가
	# 쪼개져 보인다. (같은 곡이면 play_music 이 아무것도 안 한다)
	var sp: Variant = screen.get("sfx")
	if sp == null:
		sp = screen.get("_sfx")
	if sp is Sfx:
		(sp as Sfx).play_music("tutorial_theme")


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


## 스토리 한 대목을 재생하고 끝나면 next 를 부른다. 대본에 없으면 바로 next.
##
## ── 왜 여기에 끼우는가 ───────────────────────────────────────────────────
## 스토리는 화면이 아니라 **화면 사이**에 있다. 상점에 들어가기 직전과 판을
## 깬 직후가 그 자리다. 각 화면이 자기 안에서 스토리를 재생하게 만들면, 그
## 화면이 다시 열릴 때마다(편성으로 갔다가 돌아오는 등) 또 나온다.
func play_story(when: String, stage: int, next: Callable) -> void:
	if not Story.has(when, stage):
		next.call()
		return
	var s := SCN_STORY.instantiate() as StoryScreen
	_swap(s)
	s.setup(Story.beats(when, stage))
	s.done.connect(next)


## 대본 전체를 처음부터 끝까지 재생한다. 타이틀에서만 들어온다.
##
## 게임을 거치지 않고 이야기만 본다. 대사를 고치는 동안 다섯 판을 다시 이길
## 수는 없다. (core/story.gd 의 all_beats 주석 참조)
func goto_story_preview() -> void:
	var s := SCN_STORY.instantiate() as StoryScreen
	_swap(s)
	s.setup(Story.all_beats())
	s.done.connect(goto_title)


func goto_shop() -> void:
	var s := SCN_SHOP.instantiate() as ShopScreen
	_swap(s)
	_bind_tutorial(s, "shop")
	s.setup(run)
	_attach_overlay(s, "shop")
	s.done.connect(goto_loadout)
	s.help.connect(func(): goto_help(false))
	s.command.connect(goto_command)


func goto_command() -> void:
	var s := SCN_COMMAND.instantiate() as CommandScreen
	_swap(s)
	s.setup(run)
	s.back.connect(goto_shop)
	# ── 여기서도 튜토리얼이 이어져야 한다 ────────────────────────────────
	# 대본이 [보조 지휘] 를 가리키는데, 정작 그 버튼을 누르면 오버레이가 없는
	# 화면으로 넘어가서 튜토리얼이 통째로 끊겼다. 시키는 대로 눌렀더니 안내가
	# 사라지는 것은 가장 나쁜 종류의 단절이다.
	#
	# 이 화면 전용 대사(cmd_1)를 두고, 상점으로 돌아가면 다시 상점 대사가
	# 뜬다 - Tutorial 은 화면을 넘어가도 진행도를 그대로 들고 있다.
	_attach_overlay(s, "command")


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
	# ── BRANCH B ────────────────────────────────────────────────────────
	# 작전을 접으면 루프 대본이 재생되고 런이 처음으로 돌아간다. 대본이
	# "기억을 다듬고 다시 한 번" 이라고 말하는 그대로다 - 화면 밖의 진행도
	# 초기화와 화면 안의 기억 소거가 같은 동작이 된다.
	s.gave_up.connect(func():
		play_story("loop", 0, func():
			run.start_run(1)
			goto_title()
		)
	)
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
			# 새 단계의 도입 대사를 먼저 재생한다.
			play_story("pre", run.stage_id, goto_shop)
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
