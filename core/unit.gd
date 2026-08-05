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

## 궁극기를 이미 썼는가. 궁극기는 **전투당 1회**다.
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


## p_upgrade 는 강화 단계. HP·공격력만 오른다. 전투는 이 값이 이미 반영된
## 스탯만 보고, 강화 체계 자체는 전혀 모른다.
static func create(p_index: int, p_type_id: String, p_team: int, p_pos: Vector2i,
		p_cards: Array, p_special: String = "", p_upgrade: int = 0,
		p_special_first: bool = false, p_levels: Dictionary = {}) -> Unit:
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
	u.atk_range = s["range"]
	u.move_range = s["move"]
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
		u.card_rules.append(Cards.leveled(cid, int(p_levels.get(cid, 1))))

	# 기본 AI 는 이제 규칙 목록이 아니라 직업별 표다. 파이프라인이 직접 읽으므로
	# 유닛이 들고 다닐 이유가 없다. (data/innates.gd 참조)
	u.innate = [] as Array[Dictionary]

	# 직업이 안 맞는 특수 스킬은 조용히 버린다. UI 가 이미 막지만 여기서도 지킨다.
	if p_special != "" and Specials.usable_by(p_special, p_type_id):
		u.special = p_special
		u.special_first = p_special_first
	return u


## 궁극기를 지금 쓸 수 있는가 (장착 + 미사용 + 패시브가 아님).
##
## 패시브를 여기서 걸러야 한다. 안 그러면 [불굴의 의지] 가 규칙 후보로 올라가서
## 전사가 매 틱 "무엇도 아닌 것" 을 고르고 실제 행동을 못 한다.
func special_ready() -> bool:
	return special != "" and not special_used and not Specials.is_passive(special)


func power_damage(percent: int) -> int:
	# 정수 연산만 쓴다. 결정론을 깨지 않기 위해서다.
	# focus_bonus 는 [집중사격] 이 붙인 영구 가산치다.
	return maxi(1, atk * (percent + focus_bonus) / 100)


func is_enemy_of(other: Unit) -> bool:
	return team != other.team


func hp_percent_below(pct: int) -> bool:
	# 정수 연산만 쓴다. 부동소수점은 플랫폼별 오차로 결정론을 깰 수 있다.
	return hp * 100 < max_hp * pct


func take_damage(amount: int, from: Unit) -> int:
	var dealt: int = amount
	if defending:
		# 정수 나눗셈. 기본은 절반이고, 합성 단계마다 한 몫씩 더 깎는다.
		# 2 -> 3 -> 4 로 나누므로 50% -> 33% -> 25% 가 된다.
		#
		# 최소 1 은 남긴다. 안 그러면 [방어 태세] 3단계(4로 나눔) 앞에서 공격력
		# 3 이하가 통째로 0 이 되어 **면역**이 된다. 뎀감은 줄이는 것이지
		# 무효로 만드는 것이 아니다.
		dealt = maxi(1, dealt / (2 + defend_level))
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
			return dealt
		alive = false
	return dealt


func heal(amount: int) -> int:
	var before: int = hp
	hp = mini(max_hp, hp + amount)
	return hp - before


func missing_hp() -> int:
	return max_hp - hp
