# 사용 에셋 출처

제출물 4번(AI 활용 기술 문서)에 그대로 옮길 목록. **쓰는 순간 바로 여기 기록한다.**

공모전 유의사항: *"외부 에셋(이미지·사운드 등) 사용 시 출처와 라이선스를
AI 활용 기술 문서에 반드시 명시해야 합니다."*

## 폰트

배정은 `data/fonts.json` 한 곳에서 관리한다. 역할별 우선순위 목록이라
앞엣것이 없으면 뒤로 내려간다 — 파일을 지워도 게임이 안 깨진다.

| 역할 | 이름 | 저작권자 | 이용 조건 |
|---|---|---|---|
| **title** (게임 이름 · 로딩 제목 · 궁극기 컷인) | DNF 단조된 검체 Bold (DNFForgedBlade-Bold) | ㈜네오플 | 무료 · 상업적 이용 가능 · **임베딩 가능** |
| **large** (14px+) | 던파 비트비트체 (DNFBitBitTTF) | ㈜네오플 | 무료 · 상업적 이용 가능 · **임베딩 가능** |
| **small** (13px 이하) | 넥슨 Lv2 고딕 Bold / Regular | ㈜넥슨코리아 | 무료 · 상업적 이용 가능 · **임베딩 가능** |
| **story** (스토리 본문) | 넥슨 Lv2 고딕 Bold / Regular | ㈜넥슨코리아 | 무료 · 상업적 이용 가능 · **임베딩 가능** |
| 폴백 | Pretendard 1.3.9 | orioncactus | SIL Open Font License 1.1 |
| 동봉(현재 미사용) | 던파 비트비트체 v2 | ㈜네오플 | 무료 · 상업적 이용 가능 |
| 동봉(현재 미사용) | Neo둥근모 (DungGeunMo) | 둥근모꼴 프로젝트 | SIL Open Font License 1.1 |

### 네오플 글꼴 (DNF 단조된 검체 · 던파 비트비트체)

> Copyright (c) 2023, NEOPLE Inc. (<https://www.neople.co.kr>),
> with Reserved Font Name ForgedBlade_TTF.ttf, ForgedBlade_OTF.otf,
> DNFBitBit_ver2_TTF.ttf, DNFBitBit_ver2_OTF.otf.

- 지적재산권을 포함한 모든 권리는 ㈜네오플에 있다.
- 개인·기업 모든 사용자에게 무료로 제공되며 **상업적 이용이 가능**하다.
  수정·변경하여 배포하는 것도 허용된다.
- 글꼴 자체를 유료로 판매하는 것은 금지된다.
- 저작권 안내를 포함하면 **다른 소프트웨어와 번들하거나 임베디드 폰트로
  사용할 수 있다.** 이 게임이 폰트를 빌드에 담는 근거가 이 조항이다.
- 출처 표기를 권장한다(이 문서와 제출 문서에 표기).

### 넥슨 글꼴 (넥슨 Lv2 고딕)

- 지적재산권을 포함한 모든 권리는 ㈜넥슨코리아에 있다.
- 개인·기업 모든 사용자에게 무료로 제공되며 **상업적 이용이 가능**하다.
- **임의 수정·편집은 불가하며 배포되는 형태 그대로 사용해야 한다.** 이 저장소는
  받은 파일을 그대로 담고 있고 손대지 않았다.
- 글꼴 자체의 유료 판매는 금지된다.
- 저작권 안내를 포함하면 **번들 또는 임베디드 폰트로 사용할 수 있다.**
- 이용 조건 원문: <https://brand.nexon.com/ko/ci-brand-guidelines/typeface>

### 빼낸 폰트 — 빛의계승자체

**저장소와 빌드에서 제거했다.** 지적재산권은 펀플로(<https://www.funflow.co.kr>)와
산돌 커뮤니케이션즈(<https://www.sandoll.co.kr>)에 있고, 라이선스가 다음을
권리자의 명시적 서면 동의 없이 금지한다.

> 3. 콘솔/PC/포터블/온라인/모바일 게임, 혹은 게임 관련 디바이스 또는 프로그램에
>    임베딩하여 사용하는 행위

이 게임은 웹 빌드 `.pck` 에 폰트를 담아 공개 배포하므로 정확히 이 경우에
해당한다. 제목 서체를 DNF 단조된 검체로 교체하고 파일을 지웠다. 폴백으로도
남기지 않았다 — 남겨 두면 언젠가 다시 빌드에 실려 나간다.

### 그 밖에

- 라이선스 전문(파일로 동봉된 것): `assets/fonts/*-LICENSE.txt`
- OFL 1.1은 임베딩·재배포를 허용한다. 표기 의무만 지키면 된다.
- **역할을 넷으로 나눈 이유**: 하나로 통일하면 반드시 어딘가가 깨진다. 장식적인
  제목용 서체는 9~13px 로 들어가면 획이 뭉쳐 못 읽고, 반대로 가독성 위주 서체로
  제목을 뽑으면 밋밋하다. 역할별 선택은 `UiKit.font(size)` / `UiKit.title_font()` 가
  자동으로 한다.
- 폰트를 갈아 끼울 때마다 `test/glyph_check.gd` 가 없는 글리프를 즉시 잡는다.
  실제로 둥근모꼴에 `▲ ▼ ▶` 가 없다는 것을 교체 직후 알려 줬다.
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
| `typing.wav` | Pixabay | Pixabay Content License | 스토리 타건음 |
| `beep.wav` | Pixabay | Pixabay Content License | 스토리 연출 · BSOD 로그 |

**나머지 6종(`hit` `heal` `defend` `buy` `victory` `death`)은 외부 에셋이 아니다.**
`core/sfx.gd` 가 실행 시점에 파형을 직접 합성한다(사인·구형파·필터드 노이즈).
난수를 쓰지 않는 고정 시드 방식이라 매번 같은 소리가 난다.

> 제출 문서에 "합성 6종은 코드가 생성하며 외부 저작물이 아님" 을 명시할 것.
> 파일로 교체하는 규격은 `assets/sfx/README.md` 에 있다.

## 배경음악

전부 **Pixabay** 무료 음원이다. 원본은 mp3 이고, 저장 형식만 바꿨다
(22.05kHz 모노 wav → 임포터 QOA 압축). 편곡·편집은 하지 않았다.

| 파일 | 쓰는 곳 | 출처 | 라이선스 |
|---|---|---|---|
| `opening_theme.wav` | 타이틀 · 1~2 스테이지 | PaulYudin (Pixabay) | Pixabay Content License |
| `ost2.wav` | 3~4 스테이지 | Pixabay | Pixabay Content License |
| `boss_theme.wav` | 5 스테이지 | Pixabay | Pixabay Content License |
| `story_stage4.wav` | ACT 4 스토리 | Pixabay | Pixabay Content License |
| `battle12.wav` | 1~2 스테이지 교전 | Pixabay | Pixabay Content License |
| `story12.wav` | ACT 1·2 스토리 | Pixabay | Pixabay Content License |
| `tutorial_theme.wav` | 튜토리얼 | Pixabay | Pixabay Content License |

> Say 'thanks' to **PaulYudin**! This helps keep the creative spirit going!
>
> `opening_theme` 원본: `paulyudin-game-game-music-573991.mp3`

**왜 wav 인가** — 웹 빌드는 소리를 Sample 경로로 내보내는데
(`audio/general/default_playback_type.web = 1`), 스트리밍 음원(mp3·ogg)은 그
경로에서 **소리 없이 죽는다.** 데스크톱에서는 멀쩡해서 계측할 때마다 "정상"
이 찍혔다. 음악도 효과음과 같은 종류의 자원(wav)으로 만들어야 웹에서 난다.

**Pixabay Content License 요약** — 상업적 이용 가능, 출처 표기 의무 없음,
개별 판매·재배포 형태의 이용만 금지. 표기 의무는 없으나 공모전 유의사항에
따라 명시한다.

## 아트

이미지 82장. **NovelAI 로 생성하고 Clip Studio Paint 에서 직접 후처리했다.**

| 분류 | 수량 | 비고 |
|---|---|---|
| 스탠딩 일러스트 | 9 | 대화·보조 지휘 화면 |
| SD 초상 | 6 | 편성·전황판 |
| 스토리 배경 | 6 | 지휘관실 2 · 설원 · 지하시설 · 중앙 코어 · 붕괴 |
| 리그 파츠 | 다수 | 대원·개체 8종의 애니메이션 부품 |
| 개체 그림 | 9 | 자동 포탑 · 자폭 개체 · 유인 신호기 · 전장 감독기 · 추격 자폭체 |

**생성이 작업의 시작이지 끝이 아니다.** 애니메이션이 필요한 8종은 파츠 단위로
분리했고(머리·몸통·팔·다리·무기), 분리하면 드러나는 가려진 영역은 직접
그려 넣었다. 생성 이미지는 한 장의 그림이라 관절이 없기 때문이다.

자세한 활용 내역은 `AI_USAGE.md` 3절 참조.

## 영상

| 파일 | 쓰는 곳 | 출처 |
|---|---|---|
| `assets/video/opening_scene.ogv` | 타이틀 배경 루프 | Kling AI 3.0 생성 후 직접 편집 |

워터마크가 박힌 하단을 잘라내고(928×576) Ogg Theora 로 변환했다. 게임 내
타이틀 화면 하단에 `opening video · KlingAI 3.0` 으로 표기하고 있다.
사용 프롬프트는 `AI_USAGE.md` 부록 C.

## 엔진 · 도구

| 이름 | 버전 | 라이선스 |
|---|---|---|
| Godot Engine | 4.7.1 stable | MIT |
