extends SceneTree

## 모듈 표 감사.
##
## ── 무엇을 검사하는가 ────────────────────────────────────────────────────
## 밸런스 수치가 아니라 **표의 무결성**을 본다. 예전 감사는 "이 모듈이 저 모듈을
## 지배한다" 같은 밸런스 판정을 했는데, 밸런스를 고칠 때마다 검사가 깨져서
## 결국 검사를 고치게 됐다. 그건 검사가 아니라 스냅샷이다.
##
## 여기서는 **밸런스를 어떻게 바꿔도 참이어야 하는 것**만 본다. 축이 유효한가,
## 페이로드가 그 축의 것인가, 엔진 어휘에 있는 값인가, 태그가 교리와 맞물리는가.

var fails: int = 0


func _init() -> void:
	print("=== 모듈 표 감사 ===")
	_check_axis_and_payload()
	_check_vocabulary()
	_check_tags()
	_check_doctrine_reachable()
	_check_stage_modules()
	_check_wave_reachable()
	print("=== 지적 사항 %d건 ===" % fails)
	quit(1 if fails > 0 else 0)


func _fail(msg: String) -> void:
	fails += 1
	print("  [FAIL] ", msg)


# ── 축과 페이로드 ────────────────────────────────────────────────────────

## 모든 모듈은 축이 있고, 그 축이 요구하는 페이로드 키를 정확히 하나 갖는다.
##
## 페이로드가 없으면 그 모듈은 장착해도 아무 일도 안 일어난다. 화면에는 멀쩡히
## 뜨고 코스트도 나가므로 플레이 중에는 절대 못 잡는다.
func _check_axis_and_payload() -> void:
	for cid in Cards.TABLE:
		var c: Dictionary = Cards.TABLE[cid]
		var axis := String(c.get("axis", ""))
		if not Axes.ALL.has(axis):
			_fail("%s: 축이 없거나 알 수 없다 ('%s')" % [cid, axis])
			continue
		var want := String(Axes.PAYLOAD[axis])
		if not c.has(want):
			_fail("%s: %s 축인데 '%s' 가 없다" % [cid, axis, want])
		# 다른 축의 페이로드가 섞여 있으면 안 된다.
		for other in Axes.ORDER:
			var key := String(Axes.PAYLOAD[other])
			if other != axis and c.has(key):
				_fail("%s: %s 축인데 '%s' 도 들고 있다" % [cid, axis, key])
		for must in ["tag", "tier", "cost", "name", "cond", "cond_arg", "text"]:
			if not c.has(must):
				_fail("%s: '%s' 가 없다" % [cid, must])


# ── 엔진 어휘 ────────────────────────────────────────────────────────────

## 표가 쓰는 조건·표적·태세·자리 이름이 전부 엔진이 아는 값인가.
##
## 오타 하나면 그 모듈은 조용히 죽는다. push_error 가 나긴 하지만 전투 로그에
## 묻히고, 플레이어에게는 "산 모듈이 안 먹는다" 로만 보인다.
const CONDS := [
	"always", "never", "enemy_in_range", "enemy_out_of_range", "enemy_within",
	"enemy_out_of_range_closing",
	"self_hp_below", "was_hit_last_tick", "enemies_adjacent_at_least",
	"ally_hp_below", "other_ally_hp_below", "ally_engaged", "killed_last_tick",
	"team_killed_last_tick", "kept_distance_for", "tick_above", "tick_below",
	"ally_died_last_tick", "enemy_special_ready", "target_hp_below",
]
const PICKS := [
	"nearest_enemy", "farthest_enemy", "farthest_in_range_enemy", "backline_enemy",
	"lowest_hp_enemy", "lowest_hp_abs_enemy", "toughest_enemy", "healer_enemy",
	"ranged_enemy", "melee_enemy", "unguarded_enemy", "strongest_enemy",
	"focused_enemy", "unfocused_enemy", "far_from_allies_enemy",
	"highest_threat_enemy", "locked_backline_enemy", "special_ready_enemy",
]
const STANCES := ["engage", "wait", "defend", "ambush",
	"avoid_near", "avoid_mid", "avoid_boost", "taunt", "aggressive", "stealth"]
const STANDS := ["keep_range", "frontline", "behind_guard", "cluster", "march", "chase",
	"follow_guard", "follow_lead", "protect_support", "escort", "rally"]

## 상시 효과 이름. core/passives.gd 가 이 이름으로 분기한다.
const PASSIVES := ["scatter", "bombard", "whirl", "riposte", "scope", "lone_armor",
	"fast_heal", "assault", "plating", "chain", "aegis", "vigil"]


func _check_vocabulary() -> void:
	for cid in Cards.TABLE:
		var c: Dictionary = Cards.TABLE[cid]
		if not CONDS.has(String(c.get("cond", ""))):
			_fail("%s: 알 수 없는 조건 '%s'" % [cid, c.get("cond", "")])
		match String(c.get("axis", "")):
			Axes.TARGET:
				if not PICKS.has(String(c.get("pick", ""))):
					_fail("%s: 알 수 없는 표적 '%s'" % [cid, c.get("pick", "")])
			Axes.DOCTRINE:
				if not STANCES.has(String(c.get("stance", ""))):
					_fail("%s: 알 수 없는 태세 '%s'" % [cid, c.get("stance", "")])
			Axes.PASSIVE:
				if not PASSIVES.has(String(c.get("passive", ""))):
					_fail("%s: 알 수 없는 상시 효과 '%s'" % [cid, c.get("passive", "")])
			Axes.POSITION:
				if not STANDS.has(String(c.get("stand", ""))):
					_fail("%s: 알 수 없는 자리 '%s'" % [cid, c.get("stand", "")])


# ── 교리 ─────────────────────────────────────────────────────────────────

## 교리가 참조하는 모듈이 실제로 존재하는가.
##
## 모듈 id 를 바꾸면 여기가 조용히 끊긴다. 끊긴 교리는 영원히 활성화되지 않는데,
## 화면에는 멀쩡히 표에 남아 있어서 플레이어가 완성하려고 계속 시도하게 된다.
func _check_tags() -> void:
	for key in Doctrines.TABLE:
		var d: Dictionary = Doctrines.TABLE[key]
		var core: Array = d["core"]
		if core.size() != Doctrines.CORE_SIZE:
			_fail("교리 '%s': 핵심 모듈이 %d개다 (기대 %d)"
				% [key, core.size(), Doctrines.CORE_SIZE])
		for cid in core:
			if not Cards.TABLE.has(String(cid)):
				_fail("교리 '%s': 없는 모듈 '%s'" % [key, cid])
		for must in ["name", "effect", "value", "text", "flavor"]:
			if not d.has(must):
				_fail("교리 '%s': '%s' 가 없다" % [key, must])


## 교리를 슬롯 안에 담을 수 있는가.
##
## 핵심 모듈 수가 대원 슬롯 수를 넘으면 그 교리는 물리적으로 완성 불가다.
## 슬롯 수를 줄이는 밸런스 조정을 하면 여기서 먼저 걸린다.
func _check_doctrine_reachable() -> void:
	for key in Doctrines.TABLE:
		var core: Array = Doctrines.TABLE[key]["core"]
		if core.size() > RunState.SLOTS_PER_UNIT:
			_fail("교리 '%s': 핵심 %d개가 슬롯 %d개를 넘는다"
				% [key, core.size(), RunState.SLOTS_PER_UNIT])
		# 같은 축 모듈 둘로 이뤄진 교리는 위아래로 겹쳐 아래가 죽을 수 있다.
		var axes: Dictionary = {}
		for cid in core:
			if not Cards.TABLE.has(String(cid)):
				continue
			var ax := String(Cards.TABLE[String(cid)]["axis"])
			if axes.has(ax):
				_fail("교리 '%s': %s 축 모듈이 둘이라 하나가 가려질 수 있다" % [key, ax])
			axes[ax] = true


# ── 스테이지 ─────────────────────────────────────────────────────────────

## 적 편성이 참조하는 모듈·궁극기가 실제로 존재하는가.
##
## 모듈 id 를 바꿀 때마다 여기가 조용히 끊긴다. 끊기면 그 적은 빈손이 되는데
## 전투는 정상적으로 굴러가므로 승률이 이상해질 때까지 아무도 모른다.
## 축 개편 때 실제로 다섯 판 전부가 그렇게 됐다.
func _check_stage_modules() -> void:
	var stages: Array = []
	for st in Stages.TABLE:
		stages.append(st)
	stages.append(Stages.TUTORIAL)

	for st in stages:
		for w in Stages.waves(st):
			for e in w:
				if not UnitData.TABLE.has(String(e["type"])):
					_fail("%s단계: 없는 개체 '%s'" % [st["id"], e["type"]])
					continue
				for t in e.get("traits", []):
					if not Traits.TEXT.has(String(t)):
						_fail("%s단계 %s: 없는 특성 '%s'" % [st["id"], e["type"], t])
				for cid in e.get("cards", []):
					if not Cards.TABLE.has(String(cid)):
						_fail("%s단계 %s: 없는 모듈 '%s'" % [st["id"], e["type"], cid])
				var sp := String(e.get("special", ""))
				if sp == "":
					continue
				if not Specials.TABLE.has(sp):
					_fail("%s단계 %s: 없는 궁극기 '%s'" % [st["id"], e["type"], sp])
					continue
				# 궁극기는 직업 전용이다. 남의 것을 붙이면 조용히 안 나간다.
				if String(Specials.TABLE[sp].get("unit", "")) != String(e["type"]):
					_fail("%s단계: 궁극기 '%s' 는 %s 전용인데 %s 에게 붙었다"
						% [st["id"], sp, Specials.TABLE[sp].get("unit", "?"), e["type"]])

	# 모듈 id 와 궁극기 id 가 겹치면 안 된다. card_node 가 Specials 를 먼저
	# 보므로, 겹치면 전술 모듈이 궁극기 모양으로 그려진다.
	# 실제로 [협공] 이 궁수 궁극기로 뜰 뻔했다.
	for cid in Cards.TABLE:
		if Specials.TABLE.has(cid):
			_fail("id 충돌: '%s' 가 모듈과 궁극기 양쪽에 있다" % cid)


## ── 모든 페이즈에 "다가오는 개체" 가 있는가 ──────────────────────────────
##
## 한 페이즈의 적이 전부 고정이거나 전부 거리를 지키면, 플레이어가 물러났을 때
## **양쪽 다 피해를 못 낸다.** 그러면 정체 판정(STALL_LIMIT)이 걸려 플레이어가
## 진다. 알고리즘이 나빠서가 아니라 판이 굴러갈 수 없어서 지는 것이다.
##
## 실제로 그렇게 만들었다가 2단계 승률이 61% -> 2% 로 무너졌다. 전투는 멀쩡히
## 돌아가므로 승률을 재기 전까지 아무도 모른다. 그래서 표 단계에서 막는다.
##
## 공격력 0 짜리 개체(유인 신호기)는 특히 위험하다. 고정까지 붙으면 그 개체는
## 아무와도 상호작용하지 않는다.
func _check_wave_reachable() -> void:
	var stages: Array = []
	for st in Stages.TABLE:
		stages.append(st)
	stages.append(Stages.TUTORIAL)

	for st in stages:
		var waves := Stages.waves(st)
		for i in waves.size():
			var closes := false
			for e in waves[i]:
				var tid := String(e["type"])
				if (e.get("traits", []) as Array).has(Traits.IMMOBILE):
					continue
				if int(UnitData.TABLE[tid]["move"]) <= 0:
					continue
				# 기본기가 접근이거나, 접근을 시키는 위치 모듈이 붙어 있으면 다가온다.
				if String(Innates.base_ai(tid)["stand"]) == "advance":
					closes = true
					break
				for cid in e.get("cards", []):
					var stand := String(Cards.TABLE.get(cid, {}).get("stand", ""))
					if stand in ["frontline", "march", "chase", "flank"]:
						closes = true
						break
				if closes:
					break
			if not closes:
				_fail("%s단계 %d페이즈: 다가오는 개체가 하나도 없다 (정체 패배가 확정된다)"
					% [st["id"], i + 1])
