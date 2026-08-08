extends SceneTree

## 위협도가 실제로 작동하는가.
##
##   godot --headless --path . --script res://test/threat_lab.gd
##
## ── 왜 필요한가 ──────────────────────────────────────────────────────────
## 위협도는 표에 값이 적혀 있다고 작동하는 것이 아니다. 적이 **그 값을 보고
## 표적을 고르는지**, 그리고 그 선택이 실제로 바뀌는지를 봐야 한다.
##
## 조용히 죽기 쉬운 자리다. 도발을 꽂아도 화면에는 아무 표시가 안 나고, 적이
## 원래 그 대원을 칠 상황이었으면 "작동한 것처럼" 보인다.
##
## 그래서 셋을 따로 센다.
##   1. 적의 표적 선택이 위협도 최고와 일치하는가
##   2. 도발·은신을 붙이면 실제로 **맞는 사람이 바뀌는가**
##   3. 표적을 매 틱 갈아타지는 않는가 (SWITCH_MARGIN 이 하는 일)

const STAGES: Array[int] = [1, 2, 3, 4, 5]

var fails := 0
var checks := 0


func _init() -> void:
	print("\n=== 위협도 검사 ===\n")
	_agreement()
	_taunt_moves_damage()
	_stealth_moves_damage()
	_no_flapping()
	_forced_reaches_locked()
	print("\n=== %d개 검사 / 실패 %d개 ===" % [checks, fails])
	quit(1 if fails > 0 else 0)


## 1. 적이 고른 표적이 위협도 최고인가.
##
## 100% 일 필요는 없다 - 표적 모듈을 든 적은 자기 규칙으로 고르고, 전환
## 마진(125%) 때문에 하던 대상을 유지하는 틱도 있다. 그 둘을 뺀 나머지가
## 위협도를 따라야 한다.
func _agreement() -> void:
	var total := 0
	var agree := 0
	for stage in STAGES:
		var b := _battle(stage, ["", "", ""])
		for _t in b.max_ticks():
			if b.result != Battle.RESULT_ONGOING:
				break
			b.step()
			for e in b.units:
				if e.team != Unit.TEAM_ENEMY or not e.alive:
					continue
				if e.last_target == null or not e.last_target.alive:
					continue
				# 표적 모듈을 든 적은 제 규칙으로 고른다. 여기서는 뺀다.
				if _has_target_module(e):
					continue
				total += 1
				var best: Unit = null
				var bs := -9999
				for a in b.living_enemies_of(e):
					var sc := Threat.score(e, a)
					if sc > bs:
						bs = sc
						best = a
				# 하던 대상을 유지하는 것도 규칙이다(SWITCH_MARGIN). 둘 중
				# 하나면 통과로 본다.
				if best != null and (e.last_target.index == best.index
						or Threat.score(e, e.last_target) * Threat.SWITCH_MARGIN >= bs * 100):
					agree += 1
	var pct: int = 0 if total == 0 else agree * 100 / total
	print("  적의 표적 선택이 위협도와 일치: %d / %d  (%d%%)" % [agree, total, pct])
	_ok(total > 50, "표본이 충분하다")
	_ok(pct >= 95, "위협도를 따르지 않는 선택이 5%% 미만")


## 2. [도발] 을 꽂으면 그 대원이 실제로 더 맞는가.
##
## ── 피해량이 아니라 피격 횟수를 센다 ────────────────────────────────────
## 처음에는 받은 **피해량** 비중으로 쟀는데 74% -> 74% 로 꿈쩍도 안 했다.
## 도발이 안 먹는 줄 알았지만 아니었다 - 방패병은 방어가 높아 같은 횟수를
## 맞아도 피해량이 적게 잡힌다. 피해량은 "누가 표적이 됐나" 를 흐린다.
##
## 위협도가 정하는 것은 **누구를 칠 것인가**이므로, 재야 할 것은 맞은 횟수다.
func _taunt_moves_damage() -> void:
	var base := _hit_share(["", "", ""], 0)
	var with_t := _hit_share(["taunt", "", ""], 0)
	print("  방패병이 맞은 비중:  기본 %d%% -> [도발] %d%%  (참고)" % [base, with_t])
	# ── 이 값에는 단언을 걸지 않는다 ────────────────────────────────────
	# 도발을 켜면 방패병이 더 많은 적의 표적이 되고, 그래서 **더 일찍 죽는다.**
	# 죽은 뒤의 피격은 전부 남에게 가므로 "전체 피격 중 비중" 은 오히려 내려갈
	# 수 있다. 실제로 78% -> 71% 로 내려갔다.
	#
	# 이 지표는 표적 선택이 아니라 생존 시간을 재고 있다. 기제가 작동하는지는
	# 아래 _forced_reaches_locked() 가 격리해서 잰다.


## 3. [은신] 을 꽂으면 그 대원이 덜 맞는가.
func _stealth_moves_damage() -> void:
	var base := _hit_share(["", "", ""], 1)
	var with_s := _hit_share(["", "stealth", ""], 1)
	print("  궁수가 맞은 비중:    기본 %d%% -> [은신] %d%%" % [base, with_s])
	_ok(with_s <= base, "[은신] 이 표적을 남에게 넘긴다")


## 4. 표적을 매 틱 갈아타지는 않는가.
##
## 전환 마진이 없으면 두 대원의 위협이 엎치락뒤치락하는 동안 적이 매 틱
## 표적을 바꾸며 제자리에서 떤다. 화면에는 아무 일도 안 일어난다.
func _no_flapping() -> void:
	var switches := 0
	var ticks := 0
	for stage in STAGES:
		var b := _battle(stage, ["taunt", "stealth", ""])
		var prev: Dictionary = {}
		for _t in b.max_ticks():
			if b.result != Battle.RESULT_ONGOING:
				break
			b.step()
			for e in b.units:
				if e.team != Unit.TEAM_ENEMY or not e.alive or e.last_target == null:
					continue
				ticks += 1
				var was := int(prev.get(e.index, -1))
				if was >= 0 and was != e.last_target.index:
					switches += 1
				prev[e.index] = e.last_target.index
	var pct: int = 0 if ticks == 0 else switches * 100 / ticks
	print("  적이 표적을 바꾼 틱 비율:   %d / %d  (%d%%)" % [switches, ticks, pct])
	_ok(pct <= 25, "표적 전환이 25%% 이하 (떨림 없음)")


## 5. 표적 모듈을 든 적에게도 도발이 통하는가.
##
## 여기가 이번 변경의 핵심이다. 스테이지 전체 적 42 중 16(38%)이 표적 모듈을
## 들고 있고, 예전에는 그 적들에게 도발이 통하지 않았다 - 우리 방패병이
## 투명인간이었다.
func _forced_reaches_locked() -> void:
	var locked_hits_base := 0
	var locked_hits_taunt := 0
	var locked_all_base := 0
	var locked_all_taunt := 0
	for spec in [["", 0], ["taunt", 1]]:
		for stage in STAGES:
			var b := _battle(stage, [String(spec[0]), "", ""])
			b.run()
			for e in b.events:
				if String(e.get("type", "")) != "attack":
					continue
				var src := int(e.get("unit", -1))
				var t := int(e.get("target", -1))
				if src < 0 or t < 0 or b.units[src].team != Unit.TEAM_ENEMY:
					continue
				if not _has_target_module(b.units[src]):
					continue
				if int(spec[1]) == 0:
					locked_all_base += 1
					if t == 0:
						locked_hits_base += 1
				else:
					locked_all_taunt += 1
					if t == 0:
						locked_hits_taunt += 1
	var a: int = 0 if locked_all_base == 0 else locked_hits_base * 100 / locked_all_base
	var c: int = 0 if locked_all_taunt == 0 else locked_hits_taunt * 100 / locked_all_taunt
	print("  표적 모듈 든 적이 방패병을 친 비중: 기본 %d%% -> [도발] %d%%" % [a, c])
	_ok(locked_all_base > 20, "표본이 충분하다")
	_ok(c > a, "도발이 표적 모듈을 든 적에게도 통한다")


# ── 도구 ─────────────────────────────────────────────────────────────────

func _battle(stage: int, cards: Array) -> Battle:
	var party: Array = []
	var types := ["shieldman", "archer", "bard"]
	var slots := [1, 2, 4]
	for i in 3:
		party.append({
			"type": types[i], "slot": slots[i],
			"cards": [] if String(cards[i]) == "" else [String(cards[i])],
			"special": "", "special_first": false, "card_levels": {},
			"upgrade": 2, "cmd": {},
		})
	var b := Battle.new()
	b.setup(stage, party)
	return b


## who 번 대원이 맞은 횟수가 아군 전체 피격의 몇 %인가.
func _hit_share(cards: Array, who: int) -> int:
	var mine := 0
	var all := 0
	for stage in STAGES:
		var b := _battle(stage, cards)
		b.run()
		for e in b.events:
			if String(e.get("type", "")) != "attack":
				continue
			var t := int(e.get("target", -1))
			if t < 0 or b.units[t].team != Unit.TEAM_PLAYER:
				continue
			all += 1
			if t == who:
				mine += 1
	return 0 if all == 0 else mine * 100 / all


func _has_target_module(u: Unit) -> bool:
	for r in u.card_rules:
		if not (r as Dictionary).is_empty() and String(r.get("axis", "")) == Axes.TARGET:
			return true
	return false


func _ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("  [FAIL] %s" % msg)
