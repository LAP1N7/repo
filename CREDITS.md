# 사용 에셋 출처

제출물 4번(AI 활용 기술 문서)에 그대로 옮길 목록. **쓰는 순간 바로 여기 기록한다.**

공모전 유의사항: *"외부 에셋(이미지·사운드 등) 사용 시 출처와 라이선스를
AI 활용 기술 문서에 반드시 명시해야 합니다."*

## 폰트

| 이름 | 출처 | 라이선스 | 용도 |
|---|---|---|---|
| 던파 비트비트체 (DNFBitBitTTF) | 넥슨 던전앤파이터 | SIL Open Font License 1.1 | 14px 이상 — 제목·유닛 이름 |
| 던파 비트비트체 v2 (DNFBitBitv2) | 넥슨 던전앤파이터 | SIL Open Font License 1.1 | 13px 이하 — 카드 설명·전투 로그 |
| Pretendard 1.3.9 (Regular) | https://github.com/orioncactus/pretendard | SIL Open Font License 1.1 | 폴백 (번들 폰트를 못 읽을 때) |

- 라이선스 전문: `assets/fonts/*-LICENSE.txt`
- OFL 1.1은 임베딩·재배포를 허용한다. 표기 의무만 지키면 된다.
- **두 가지를 쓰는 이유**: 비트비트체는 큰 글씨에서 성격이 살지만 9~13px 로
  들어가면 획이 뭉쳐 못 읽는다. v2 가 작은 크기를 훨씬 잘 버틴다.
  크기별 선택은 `UiKit.font(size)` 가 자동으로 한다.
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
