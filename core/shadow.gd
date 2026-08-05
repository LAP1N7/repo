class_name Shadow

## 가려진 슬롯 찾기 - "이 카드는 위 카드에 가려 절대 발동하지 않는다" 를 미리 알려준다.
##
## ── 왜 필요한가 ────────────────────────────────────────────────────────
## 규칙은 위에서부터 처음 맞는 하나만 실행된다. 그래서 슬롯 1의 조건이 헐거우면
## 슬롯 2, 3 은 영영 발동하지 않는다. 그런데 화면에는 멀쩡히 꽂혀 있는 것으로
## 보이므로, 플레이어는 "내 전술이 왜 아무 일도 안 하지" 를 알 수 없다.
##
## 실제 사례: 궁수에게 [1 저격, 2 거리 유지] 를 꽂으면 저격의 조건이
## `적이 사거리 안` 이라 적이 사거리에 들어오는 순간 항상 참이 되고,
## 거리 유지는 단 한 번도 발동하지 못한다. 궁수는 물러나지 않고 계속 쏘다 죽는다.
##
## ── 왜 사거리를 받아야 하는가 ──────────────────────────────────────────
## `사거리 안` 과 `2칸 이내` 는 조건 이름이 다르지만, 사거리 3인 궁수에게는
## "2칸 이내" 가 "사거리 안" 에 완전히 포함된다. 반대로 사거리 1인 전사에게는
## 포함되지 않는다. 즉 가림 여부가 유닛마다 다르므로 사거리를 알아야 한다.
## 그래서 모든 거리 조건을 `enemy_within <칸수>` 하나로 정규화한 뒤 비교한다.

const FAR := "enemy_beyond"
const NEAR := "enemy_within"


## 행동의 실행 가능성과 유닛 사거리를 반영한 "실제로 발동하는 조건".
## 반환: [조건이름, 인자]
static func effective(card: Dictionary, atk_range: int) -> Array:
	var cond := String(card["cond"])
	var arg := int(card["cond_arg"])

	# 거리 조건을 한 축으로 정규화한다.
	match cond:
		"enemy_in_range":
			return [NEAR, atk_range]
		"enemy_out_of_range":
			return [FAR, atk_range]
		"enemy_within":
			return [NEAR, arg]
	return [cond, arg]


## a 가 참인 모든 상황에서 b 도 참인가 (a ⊆ b).
## b 가 위 슬롯, a 가 아래 슬롯일 때 참이면 a 는 절대 발동하지 못한다.
static func implies(a: String, a_arg: int, b: String, b_arg: int) -> bool:
	if b == "always":
		return true
	if a != b:
		return false
	match a:
		# 반경이 클수록 더 자주 참이다. 2칸 이내 ⊆ 3칸 이내.
		NEAR, "self_hp_below", "ally_hp_below":
			return a_arg <= b_arg
		# 문턱이 작을수록 더 자주 참이다. 인접 3명 ⊆ 인접 2명.
		FAR, "enemies_adjacent_at_least", "tick_below":
			return a_arg >= b_arg
		_:
			return true


## 위 슬롯이 아래를 확실히 가리는가.
##
## 이동·회복 카드는 벽에 몰리거나 대상이 없으면 실행 불가가 되어 아래로 양보한다.
## 그래서 "조건이 맞으면 거의 항상 실행되는" 행동만 가림으로 본다.
## 이 제한이 없으면 정상적인 카이팅 빌드에 오경보가 뜬다.
## ── 축이 다르면 절대 안 가린다 ───────────────────────────────────────────
## 예전에는 모듈 하나가 조건과 행동을 다 들고 있어서 목록 전체가 한 줄로
## 경쟁했다. 그래서 `항상` 조건 하나가 아래 전부를 죽였다.
##
## 이제는 축마다 따로 읽는다. [저격](표적)과 [거리 유지](위치)는 애초에 서로
## 다투지 않으므로 위아래에 있어도 둘 다 산다. 축을 무시하고 가림을 계산하면
## 정상적인 편성에 오경보가 쏟아진다.
static func same_axis(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("axis", "")) == String(b.get("axis", ""))


## 가려진 슬롯 번호들. cards 는 우선순위 순서의 카드 id 배열.
static func shadowed_slots(cards: Array, atk_range: int) -> Array[int]:
	var out: Array[int] = []
	for i in cards.size():
		if _shadowed_by(cards, i, atk_range) != "":
			out.append(i)
	return out


## i 번 슬롯을 가리는 위 카드의 이름. 안 가려지면 "".
static func _shadowed_by(cards: Array, i: int, atk_range: int) -> String:
	if i >= cards.size() or not Cards.TABLE.has(cards[i]):
		return ""
	var le := effective(Cards.TABLE[cards[i]], atk_range)
	for j in i:
		if not Cards.TABLE.has(cards[j]):
			continue
		var upper: Dictionary = Cards.TABLE[cards[j]]
		if not same_axis(Cards.TABLE[cards[i]], upper):
			continue
		var ue := effective(upper, atk_range)
		if implies(String(le[0]), int(le[1]), String(ue[0]), int(ue[1])):
			return String(upper["name"])
	return ""


## 사람이 읽는 경고 문장. 없으면 빈 배열.
static func warnings(cards: Array, atk_range: int) -> Array[String]:
	var out: Array[String] = []
	for i in cards.size():
		var by := _shadowed_by(cards, i, atk_range)
		if by != "":
			out.append("%d번 '%s' 는 위의 '%s' 에 가려 발동하지 않는다" % [
				i + 1, Cards.TABLE[cards[i]]["name"], by])
	return out
