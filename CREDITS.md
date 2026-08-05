# 사용 에셋 출처

제출물 4번(AI 활용 기술 문서)에 그대로 옮길 목록. **쓰는 순간 바로 여기 기록한다.**

공모전 유의사항: *"외부 에셋(이미지·사운드 등) 사용 시 출처와 라이선스를
AI 활용 기술 문서에 반드시 명시해야 합니다."*

## 폰트

배정은 `data/fonts.json` 한 곳에서 관리한다. 역할별 우선순위 목록이라
앞엣것이 없으면 뒤로 내려간다 — 파일을 지워도 게임이 안 깨진다.

| 역할 | 이름 | 출처 | 라이선스 |
|---|---|---|---|
| **title** (게임 이름) | 빛의 계승자 Bold (HeirofLightBold) | 넥슨 히트 | SIL Open Font License 1.1 |
| **large** (14px+) | 던파 비트비트체 (DNFBitBitTTF) | 넥슨 던전앤파이터 | SIL Open Font License 1.1 |
| **small** (13px 이하) | 둥근모꼴 (DungGeunMo) | 개인 제작 (둥근모꼴 프로젝트) | SIL Open Font License 1.1 |
| 폴백 | 던파 비트비트체 v2 / Pretendard 1.3.9 | 넥슨 / orioncactus | SIL Open Font License 1.1 |

- 라이선스 전문: `assets/fonts/*-LICENSE.txt`
- OFL 1.1은 임베딩·재배포를 허용한다. 표기 의무만 지키면 된다.
- **세 가지를 쓰는 이유**: 하나로 통일하면 반드시 어딘가가 깨진다. 장식적인
  제목용 서체는 9~13px 로 들어가면 획이 뭉쳐 못 읽고, 반대로 가독성 위주 서체로
  제목을 뽑으면 밋밋하다. 역할별 선택은 `UiKit.font(size)` / `UiKit.title_font()` 가
  자동으로 한다.
- 둥근모꼴에는 `▲ ▼ ▶` 글리프가 없어서 `^ v >` 로 바꿨다. 이건 눈으로 찾은 게
  아니라 `test/glyph_check.gd` 가 폰트 교체 직후 바로 잡아냈다.
- **맑은 고딕(malgun.ttf)은 절대 빌드에 포함하지 말 것** — 재배포 불가.
  개발 중 시스템 폰트를 빌려 쓰던 경로는 폴백으로만 남겨 두었다.

## 효과음

| 파일 | 출처 | 라이선스 | 용도 |
|---|---|---|---|
| `step.wav` | 제작자 직접 제작 | 본인 저작 | 유닛 이동 |
| `attack_melee.wav` | 제작자 직접 제작 | 본인 저작 | 근접 공격 (사거리 1) |
| `attack_ranged.wav` | 제작자 직접 제작 | 본인 저작 | 원거리 공격 (사거리 2+) |
| `click.wav` | 제작자 직접 제작 | 본인 저작 | 버튼·리롤 |
| `special.wav` | 제작자 직접 제작 | 본인 저작 | 궁극기 발동 · 카드 합성 |
| `defeat.wav` | 제작자 직접 제작 | 본인 저작 | 패배 |
| `opening.wav` | 제작자 직접 제작 | 본인 저작 | 타이틀 진입 |

**나머지 6종(`hit` `heal` `defend` `buy` `victory` `death`)은 외부 에셋이 아니다.**
`core/sfx.gd` 가 실행 시점에 파형을 직접 합성한다(사인·구형파·필터드 노이즈).
난수를 쓰지 않는 고정 시드 방식이라 매번 같은 소리가 난다.

> 제출 문서에 "합성 6종은 코드가 생성하며 외부 저작물이 아님" 을 명시할 것.
> 파일로 교체하는 규격은 `assets/sfx/README.md` 에 있다.

## 배경음악

| 파일 | 출처 | 라이선스 | 용도 |
|---|---|---|---|
| `assets/music/opening_theme.mp3` | PaulYudin (Pixabay) | Pixabay Content License (무료·상업 이용 가능·출처 표기 불필요하나 명시함) | 타이틀 오프닝 테마 |

> Say 'thanks' to **PaulYudin**! This helps keep the creative spirit going!
> By downloading, you agree to our License.
>
> 원본: Pixabay 무료 음악 (`paulyudin-game-game-music-573991`)

## 아트

아직 없음. 전부 도형·색으로 렌더된다. 필요 규격은 `ASSETS.md` 참조.

## 엔진 · 도구

| 이름 | 버전 | 라이선스 |
|---|---|---|
| Godot Engine | 4.7.1 stable | MIT |
