class_name Unit
extends RefCounted

## 유닛의 순수 상태. 렌더링/노드를 전혀 모른다.
##
## 뷰는 이 객체를 읽기만 하는 별도 노드로 붙인다. (DESIGN 6장: 아트 교체를 위해
## 처음부터 노드를 분리)

const TEAM_PLAYER: int = 0
const TEAM_ENEMY: int = 1

## index 는 전 유닛에 걸친 고정 행동 순서이자 모든 동점 처리의 최종 기준이다.
## 한 번 정해지면 전투가 끝날 때까지 바뀌지 않는다. (DESIGN 2.1 난수 없음)
var index: int = 0
var type_id: String = ""
var display_name: String = ""
var team: int = TEAM_PLAYER
var pos: Vector2i = Vector2i.ZERO

var hp: int = 0
var max_hp: int = 0
var atk: int = 0
## 기본 사거리. 상시 효과 보정은 range_bonus 에 따로 있다.
var atk_range_base: int = 1

## 실제 사거리. 규칙 엔진과 전투가 전부 이 값을 본다.
var atk_range: int = 1
var move_range: int = 1
var color: Color = Color.WHITE

## 규칙 슬롯. 우선순위 순서대로 카드 id 가 들어간다. 이 배열의 순서가 곧 전략.
var cards: Array[String] = []

## 위 카드들의 **레벨이 반영된** 규칙. cards 와 같은 순서다.
##
## 규칙 엔진은 Cards.TABLE 을 직접 보면 안 된다. 합성 단계가 반영 안 된 원본을
## 읽게 되어, 화면에는 "교전++ 위력 140%" 라고 떠 있는데 실제로는 100% 로 때린다.
var card_rules: Array[Dictionary] = []

## 직업 기본기. cards 를 전부 검사한 뒤에야 평가되는 폴백이다.
## 이게 있어서 카드가 하나도 없어도 유닛이 멍하니 서 있지 않는다.
var innate: Array[Dictionary] = []

## 특수 스킬 id. 규칙 슬롯과 별개인 특수 슬롯 1칸에 들어가며, 슬롯 1보다 먼저
## 평가된다(우선발동). 빈 문자열이면 없음.
var special: String = ""

## 특수를 규칙 슬롯보다 먼저 평가할지. 플레이어가 정한다.
##
## 예전에는 특수가 무조건 최우선이었다. 그러면 특수가 준비된 동안 슬롯 1~3 이
## 통째로 무시되어 "우선순위가 곧 전략" 이라는 이 게임의 명제와 정면으로 모순된다.
## 실제로 관통사격을 낀 궁수가 거리 유지를 영영 발동하지 못하고 제자리에서
## 계속 쏘기만 하는 문제가 났다. 순서는 플레이어가 정해야 한다.
var special_first: bool = false

## 궁극기를 이미 썼는가. 궁극기는 **페이즈당 1회**다 - 페이즈가 넘어가면
## Battle._spawn_wave 가 이 값을 되돌린다.
##
## 예전엔 쿨다운이었는데, 그러면 조건이 유지되는 동안 계속 터져서 밸런스가
## 쿨다운 수치 하나에 매달렸다. 1회로 못 박으니 위력을 마음껏 줄 수 있게 됐다.
## (암살자 [비영천참] 은 강화 시 사망마다 이 값이 다시 false 가 된다)
var special_used: bool = false

## [집중사격] 이 붙인 공격 위력 가산치(%p). 0 이면 없음. 전투 끝까지 유지된다.
var focus_bonus: int = 0

## 적과 일정 거리 이상을 연속으로 유지한 틱 수. [집중사격] 조건이 읽는다.
var far_streak: int = 0

## [불굴의 의지] 로 HP 0 에서 버티는 중인가. 남은 틱 수와, 버티기 시작한 뒤
## 이 유닛이 적에게 누적으로 넣은 피해량.
## 궁극기 합성 단계(0~3). 보조 지휘에서 산 값이 편성 때 실려 온다.
var special_level: int = 0

## 이번 틱에 [불굴의 의지] 가 막 발동했는가. 전투가 읽고 지운다.
##
## take_damage 는 유닛 안에 있어서 사건을 못 낸다. 그래서 표시만 남기고,
## 전투가 안전한 지점에서 컷인을 띄운다. 이게 없어서 **발동 순간에는 컷인이
## 아예 안 떴다** - 3틱 뒤 부활할 때만 떴다.
var undying_started: bool = false

var undying_ticks: int = 0
var undying_damage: int = 0

var alive: bool = true

## 방어 태세. 자기 행동 직전에 해제되므로 정확히 한 바퀴 유지된다.
var defending: bool = false

## 방어 태세의 합성 단계. 0 이면 절반, 오를수록 더 깎는다.
var defend_level: int = 0

## 직전 틱에 맞았는가 (반격 카드용). hit_pending 이 이번 틱 누적분이고,
## 틱이 끝날 때 was_hit 으로 옮긴다.
var was_hit: bool = false
var hit_pending: bool = false

## 직전 틱에 내가 적을 처치했는가.
## was_hit 과 똑같은 2단 구조다. 같은 틱에 죽이고 같은 틱에 반응하면
## "처치 직후" 가 아니라 "처치와 동시에" 가 되어 한 틱에 두 행동을 하게 된다.
var killed_last_tick: bool = false
var kill_pending: bool = false

## 마지막으로 나를 때린 유닛의 index. 없으면 -1.
##
## Unit 참조를 직접 들면 안 된다. A가 B를 때리고 B가 A를 때리는 순간 두 객체가
## 서로를 참조하는데, RefCounted 에는 순환 수집기가 없어서 전투가 끝나도 절대
## 해제되지 않는다. 재시도할 때마다 유닛 한 세트씩 새는 것을 실측으로 확인했다.
## 인덱스로 들면 순환이 생기지 않는다.
var last_attacker_index: int = -1

## 이 대원에게 활성화된 교리. { 태그: 교리 } 형태다.
##
## 한 축의 모듈이 전부 같은 태그일 때만 켜진다. 편성이 확정될 때 한 번 계산하고
## 전투 내내 안 바뀐다 - 모듈은 전투 중에 못 바꾸기 때문이다.


## 위협도 보정. 교전 수칙(도발·전투태세·은신)이 매 틱 채운다.
##
## 적이 표적을 고를 때 이 값을 본다. 이게 있어야 "방패병이 붙잡는 동안 원거리가
## 갉는다" 같은 전술이 성립한다. (core/threat.gd 참조)
var threat_mod: int = 0

## 상시 효과가 이번 틱에 만든 보정. Battle 이 틱마다 다시 채운다.
## (core/passives.gd 의 "왜 매 틱 다시 계산되는가" 주석 참조)
var passive_atk_pct: int = 0
var passive_def: int = 0
var passive_taken_pct: int = 0

## 직전 틱에 움직였는가. [조준경] 이 "제자리를 지킨 다음 틱" 을 판정한다.
var moved_last_tick: bool = false
var moved_this_tick: bool = false

## 상시 효과가 주는 사거리 보정. [조준경] 이 쓴다.
var range_bonus: int = 0

## 이번 틱에 한 번 더 행동할 수 있는가. [연쇄] 가 처치 시 켠다.
var extra_action: bool = false

## 잠복 남은 틱. 0보다 크면 맞지도 때리지도 않는다.
var ambush_ticks: int = 0

## 잠복이 풀린 뒤 첫 공격에 실릴 보너스. 해제되면 켜지고 한 번 쓰면 꺼진다.
##
## **유효 기간이 있다.** 예전에는 한 번 켜지면 공격할 때까지 영원히 남아서,
## 잠복 후 열 틱을 걸어간 뒤 때려도 보너스가 그대로 실렸다. 그러면 이 태세는
## "3틱을 버리고 한 방을 산다" 가 아니라 그냥 "공짜 강화" 다.
var ambush_ready: bool = false
var ambush_bonus_ticks: int = 0

## 이번 전투에서 이미 잠복했는가. 한 번뿐이다 - 안 그러면 조건이 참인 동안
## 계속 숨었다 나왔다 하며 아무 일도 안 한다.
var ambush_done: bool = false

## ── 교전당 한 번만 쓰는 모듈 ────────────────────────────────────────────
## 키는 모듈 id, 값은 true. 전투가 시작될 때 유닛이 새로 만들어지므로 따로
## 초기화할 곳이 없다 - 페이즈를 넘어가도 같은 유닛이라 "교전당 1회" 가 된다.
##
## 궁극기(페이즈당 1회)와 다르다. 이쪽은 페이즈가 바뀌어도 안 찬다 - 판을
## 뒤집는 한 수가 아니라 **위기를 한 번 넘기는 수**이기 때문이다.
var once_used: Dictionary = {}

## 자폭 도화선. -1 이면 아직 안 붙었다. 0 이 되면 스스로 터진다.
var fuse_ticks: int = -1

## 한 번 정하면 끝까지 쫓는 표적. [후열 침투] 가 쓴다.
var locked_target: Unit = null

## 이 대원이 마지막으로 고른 표적.
##
## 협력 축이 이걸 읽는다. [협공] 은 아군의 표적을 그대로 쓰고 [분산] 은 그
## 표적을 후보에서 뺀다. 부대가 서로를 참조하려면 "누가 누구를 보고 있는가" 가
## 어딘가에 남아 있어야 하는데, 그 자리가 여기다.
var last_target: Unit = null

## 이번 교전에서 이 대원이 **입힌** 피해와 **회복시킨** 양의 누적.
##
## 순수 표시용이라 전투 판정에는 쓰지 않는다. 그런데 이게 없으면 "누가 실제로
## 일했는가" 를 알 방법이 없다. 로그를 한 줄씩 세는 것 말고는.
## 방어 태세로 깎인 뒤의 **실제 적용치**를 센다.
var damage_dealt: int = 0
var healing_done: int = 0

## 강화 단계. 표시용이며 스탯에는 이미 반영되어 있다.
var upgrade: int = 0

## 이번 틱에 발동한 규칙. 머리 위 라벨(DESIGN 1-2)이 이 값을 읽는다.
var last_card_id: String = ""
var last_rule_text: String = ""

## ── 개체 특성 ────────────────────────────────────────────────────────────
## 스테이지 표가 적에게 붙이는 성질. 플레이어 대원은 항상 비어 있다.
## (data/traits.gd 참조)
var traits: Array[String] = []

## 절대 움직이지 않는가. 이동력이 0 이어도 이동 보너스를 주는 모듈이 붙으면
## 한 칸씩 기어가므로, "고정" 은 별도 플래그로 못 박아야 한다.
var immobile: bool = false

## 특성이 상시로 얹는 위협도. 태세가 채우는 threat_mod 와 별개다.
##
## 나누지 않으면 안 된다. threat_mod 는 매 틱 교전 수칙이 덮어쓰는 값이라,
## 거기에 유인 장치의 값을 넣으면 첫 틱에 지워진다.
var threat_base: int = 0

## 특성이 이번 틱에 만든 공격력 보정(%p). Battle 이 틱마다 다시 채운다.
var trait_atk_pct: int = 0

## 자폭 특성이 이미 터졌는가. 두 번 터지는 것을 막는다.
var exploded: bool = false

## 직전 틱에 가장 가까운 적까지의 거리. -1 이면 아직 모른다.
##
## "적이 다가오는 중인가" 를 판정하려면 과거가 필요한데 규칙 엔진은 현재
## 상태밖에 못 본다. 그래서 Battle 이 틱 끝에 여기 적어 둔다.
var prev_near_dist: int = -1


## 스테이지가 준 특성을 얹는다. 적에게만 붙는다.
func apply_traits(list: Array) -> void:
	for t in list:
		var name := String(t)
		if not traits.has(name):
			traits.append(name)
	if traits.has(Traits.IMMOBILE):
		immobile = true
	if traits.has(Traits.BEACON):
		threat_base += Traits.BEACON_THREAT


## p_upgrade 는 강화 단계. HP·공격력만 오른다. 전투는 이 값이 이미 반영된
## 스탯만 보고, 강화 체계 자체는 전혀 모른다.
static func create(p_index: int, p_type_id: String, p_team: int, p_pos: Vector2i,
		p_cards: Array, p_special: String = "", p_upgrade: int = 0,
		p_special_first: bool = false, p_levels: Dictionary = {},
		p_special_level: int = 0) -> Unit:
	var u := Unit.new()
	u.index = p_index
	u.type_id = p_type_id
	u.team = p_team
	u.pos = p_pos

	var s: Dictionary = UnitData.TABLE[p_type_id]
	u.display_name = s["name"]
	u.upgrade = p_upgrade
	u.max_hp = UnitData.scaled(p_type_id, "hp", int(s["hp"]), p_upgrade)
	u.hp = u.max_hp
	u.atk = UnitData.scaled(p_type_id, "atk", int(s["atk"]), p_upgrade)
	u.atk_range_base = int(s["range"])
	u.atk_range = u.atk_range_base
	u.move_range = s["move"]
	# 직업이 상시로 지니는 위협도. 방패병처럼 "서 있는 것 자체가 일" 인
	# 직업에 붙는다.
	u.threat_base += int(s.get("threat", 0))
	u.color = s["color"]

	# 슬롯 수를 넘겨 꽂는 것은 허용하지 않는다.
	var limit: int = s["slots"]
	for c in p_cards:
		if u.cards.size() >= limit:
			break
		var cid := String(c)
		if not Cards.TABLE.has(cid):
			continue
		u.cards.append(cid)
		# id 를 같이 넣는다. 교리는 "어떤 모듈들을 함께 꽂았는가" 로 판정되므로
		# 규칙 사전만 봐서는 알 수가 없다. (data/doctrines.gd 참조)
		var rule: Dictionary = Cards.leveled(cid, int(p_levels.get(cid, 1))).duplicate()
		rule["id"] = cid
		u.card_rules.append(rule)
	# 교리는 편성이 확정되는 이 순간 한 번만 계산한다. 전투 중에는 모듈을
	# 못 바꾸므로 매 틱 다시 셀 이유가 없다.


	# 기본 AI 는 이제 규칙 목록이 아니라 직업별 표다. 파이프라인이 직접 읽으므로
	# 유닛이 들고 다닐 이유가 없다. (data/innates.gd 참조)
	u.innate = [] as Array[Dictionary]

	# 직업이 안 맞는 특수 스킬은 조용히 버린다. UI 가 이미 막지만 여기서도 지킨다.
	if p_special != "" and Specials.usable_by(p_special, p_type_id):
		u.special = p_special
		u.special_first = p_special_first
		u.special_level = p_special_level
	return u


## 궁극기를 지금 쓸 수 있는가 (장착 + 미사용 + 패시브가 아님).
##
## 패시브를 여기서 걸러야 한다. 안 그러면 [불굴의 의지] 가 규칙 후보로 올라가서
## 전사가 매 틱 "무엇도 아닌 것" 을 고르고 실제 행동을 못 한다.
func special_ready() -> bool:
	return special != "" and not special_used and not Specials.is_passive(special)


## 위력 백분율을 실제 피해로. 교리 보너스가 여기서 얹힌다.
##
## 맹진(공격 +15%)과 집중(같은 표적 아군 1명당 +8%)이 곱이 아니라 **합**으로
## 들어간다. 곱으로 두면 교리를 둘 겹쳤을 때 수치가 갑자기 튀어서, 밸런스를
## 잡을 때 어느 쪽을 깎아야 하는지 알 수 없게 된다.
## 보조 지휘 강화를 얹는다. 편성이 확정된 뒤 한 번만.
##
## 축 강화는 **그 축 모듈을 장착한 대원만** 받는다. 빌드 방향을 정한 뒤 그쪽을
## 미는 자리라, 아무나 받으면 방향을 정한 의미가 없다.
func apply_command(cmd: Dictionary) -> void:
	if cmd.is_empty():
		return
	var atk_pct := int(cmd.get("atk", 0))
	var def_add := int(cmd.get("def", 0))
	var hp_pct := int(cmd.get("hp", 0))

	var axes: Dictionary = {}
	for r in card_rules:
		var ax := String((r as Dictionary).get("axis", ""))
		if ax != "":
			axes[ax] = true
	if axes.has("target"):
		atk_pct += int(cmd.get("axis_target", 0))
	if axes.has("position"):
		def_add += int(cmd.get("axis_position", 0))
	if axes.has("doctrine"):
		hp_pct += int(cmd.get("axis_doctrine", 0))

	if atk_pct != 0:
		atk = maxi(1, atk * (100 + atk_pct) / 100)
	if hp_pct != 0:
		max_hp = maxi(1, max_hp * (100 + hp_pct) / 100)
		hp = max_hp
	command_def = def_add


## 보조 지휘가 준 방어 단계. take_damage 가 읽는다.
var command_def: int = 0


func power_damage(percent: int) -> int:
	# 정수 연산만 쓴다. 결정론을 깨지 않기 위해서다.
	# focus_bonus 는 [집중사격] 이 붙인 영구 가산치다.
	#
	# 잠복이 풀린 뒤 첫 공격. 멈춰 있던 값을 여기서 받는다.
	var amb := Specials.AMBUSH_POWER if ambush_ready else 0
	# [불굴의 의지] 합성. 버티는 3틱 동안만 얹힌다 - 부활 문턱(30 피해)을
	# 넘기는 것이 이 궁극기의 승부처라 거기에 값을 준다.
	var uny := 0
	if undying_ticks > 0 and special == "unyielding":
		uny = Specials.merge_amount("unyielding", special_level)
	return maxi(1, atk * (percent + focus_bonus + passive_atk_pct
		+ trait_atk_pct + amb + uny) / 100)


func is_enemy_of(other: Unit) -> bool:
	return team != other.team


func hp_percent_below(pct: int) -> bool:
	# 정수 연산만 쓴다. 부동소수점은 플랫폼별 오차로 결정론을 깰 수 있다.
	return hp * 100 < max_hp * pct


## 압박 증폭(%). 전투가 매 틱 채워 준다. 오래 끌수록 모두가 아프게 맞는다.
var pressure_pct: int = 0


func take_damage(amount: int, from: Unit) -> int:
	var dealt: int = amount
	# 압박은 제일 먼저 얹는다. 방어·감쇄 뒤에 얹으면 두꺼운 대원에게만
	# 효과가 남아서, "오래 끌면 양쪽 다 죽는다" 가 성립하지 않는다.
	if pressure_pct > 0:
		dealt = maxi(1, dealt * (100 + pressure_pct) / 100)
	# 감쇄는 방어 계산보다 **먼저** 건다. 나중에 걸면 방어 중일 때 정수
	# 나눗셈 때문에 거의 사라진다.
	var soak := passive_taken_pct
	if soak != 0:
		dealt = maxi(1, dealt * (100 + soak) / 100)
	# [철갑] - 한 방에 최대 HP 의 12% 를 넘게 맞으면 초과분은 절반만 받는다.
	# 큰 한 방을 무디게 하는 것이지 잔공격을 막는 게 아니다. 방패병처럼 HP 가
	# 두꺼운 대원이 "실제로 잘 안 죽는다" 를 체감하게 하는 자리다.
	if Passives.has(self, "plating"):
		var cap: int = maxi(1, max_hp * 12 / 100)
		if dealt > cap:
			dealt = cap + (dealt - cap) / 2
	if defending:
		# ── 방어는 감쇄지 무효가 아니다 ──────────────────────────────────
		# 나누는 값에 상한이 없었다. 합성 단계·패시브·보조 지휘가 겹치면
		# 6, 7 로 나뉘어서 웬만한 공격이 전부 1 로 떨어졌고, 화면에는 그것이
		# **무적**으로 보인다. 실제로 그렇게 보였다.
		#
		# 4 에서 끊는다. 최대 75% 감쇄 - 아무리 쌓아도 네 대 중 한 대분은
		# 들어온다. 그 이상은 수치가 아니라 상태(무적)라서, 이 게임이 다루는
		# 종류의 값이 아니다.
		var div: int = clampi(2 + defend_level + passive_def + command_def, 2, 4)
		dealt = maxi(1, dealt / div)
	hp -= dealt
	hit_pending = true
	last_attacker_index = from.index if from != null else -1
	if hp <= 0:
		hp = 0
		# [불굴의 의지]. 죽는 대신 버티기에 들어간다. 이미 버티는 중이면
		# 두 번 켜지 않는다 - 그러면 영원히 안 죽는다.
		if undying_ticks > 0:
			return dealt
		if special == "unyielding" and not special_used:
			special_used = true
			undying_ticks = int(Specials.TABLE["unyielding"]["act_arg"])
			undying_damage = 0
			undying_started = true
			return dealt
		alive = false
	return dealt


func heal(amount: int) -> int:
	# [빠른 치유] 는 **받는** 쪽에 붙는다. 악사가 아니라 살아남고 싶은 대원이
	# 드는 물건이라, 회복 편성이 아니어도 악사 하나로 값을 한다.
	if Passives.has(self, "fast_heal"):
		amount = amount * 140 / 100
	var before: int = hp
	hp = mini(max_hp, hp + amount)
	return hp - before


func missing_hp() -> int:
	return max_hp - hp
