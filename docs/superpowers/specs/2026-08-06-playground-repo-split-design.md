# Playground 모노레포 → Organization 저장소 분할 설계

- 작성일: 2026-08-06
- 대상: `christian289/Playground` → `christian289-playground` Organization
- 결과 규모: 저장소 15개 (분할 13 + 이관 2)

## 1. 목표와 배경

`christian289/Playground`는 서로 무관한 프로젝트들이 한 저장소에 쌓여 비대해졌다.
`main`에 폴더 10개, 미병합 브랜치에 3개가 더 있고, 이 중 셋은 한 프로젝트의 개명 이력이라
독립 저장소로는 12개가 된다(§2.1). 각 프로젝트를 떼어내되 **커밋 히스토리를 각 저장소에 정확히 귀속**시킨다.

분할 대상 외에 두 부류를 같은 조직으로 모은다.

- 이미 독립 저장소인 `wonderland`, `MewUiBadApple` → 이관
- `christian289/dotnet-with-claudecode`의 `samples/PolyLab3DStudio/` → 분할 (§2.3)

따라서 분할은 Playground 12개 + 외부 1개 = 13개다.

성공 기준:

1. 분할된 각 저장소의 파일 내용이 원본과 **blob SHA 단위로 동일**하다.
2. 각 저장소의 커밋 개수·저자·날짜·메시지가 원본에서 해당 폴더를 건드린 커밋과 일치한다.
3. 원본 저장소는 삭제되지 않고 아카이브로 남아 언제든 대조 가능하다.

## 2. 원본 저장소 실측

| 항목 | 값 |
|---|---|
| `main` 커밋 수 | 50 (2025-09-28 ~ 2026-08-05) |
| `main` 프로젝트 폴더 | 10 + `docs` |
| 미병합 브랜치의 추가 프로젝트 | 3 |
| 단일 프로젝트만 건드리는 커밋 | 50 중 45 |

교차 커밋 5개(`love2d-mario`+`love2d-tetris` 3, `MewUIPixelAnimation`+`WpfAutomationDemo` 1,
`.claude`+`DotNetOAuth2Learning`+루트 1)는 filter-repo가 각 저장소에 해당 변경분만 남기므로 손실이 없다.

### 2.1 `love2d-serverdev` 계보

`feature/serverdev`는 별개 프로젝트가 아니라 `love2d-codedefense`의 직계 후속이다.

```
main:              ... → love2d-codedefense (1abc4b8, 2026-07-21)  ← merge-base
feature/serverdev:      love2d-codedefense → love2d-thisfar → love2d-serverdev (8af5cd4, 2026-08-05)
```

폴더명이 두 번 바뀌었을 뿐 한 프로젝트의 시간축이다. 따라서 저장소 하나로 통합하며,
세 경로를 모두 루트로 승격시켜 개명 이력을 포함한 연속 히스토리를 복원한다.

`feature/serverdev-2`는 `feature/serverdev`의 직계 조상(1커밋 뒤)이라 별도로 가져올 내용이 없다.

### 2.2 제외 대상

| 브랜치 | 제외 사유 |
|---|---|
| `origin/claude/analyze-riter-drawing-vdC2o` | 루트 `.gitignore`에 3줄 추가한 커밋 1개. 프로젝트 내용 없음 |
| `pr-simyunsup-playground/feature/hotfix` | `feature/serverdev` 히스토리의 조상. 이미 포함됨 |
| `pr-simyunsup-playground/feature/pretext_wpf` | PR #2로 병합 완료. `main` 대비 0커밋 |

포크 `SimYunSup/Playground`는 원본 히스토리를 자체 보유하므로 분할·아카이브의 영향을 받지 않는다.

### 2.3 외부 소스 — `dotnet-with-claudecode`

`christian289/dotnet-with-claudecode`(PUBLIC, "ClaudeCode와 함께하는 .NET 개발 튜토리얼")의
`samples/PolyLab3DStudio/`를 독립 저장소로 분리한다.

| 항목 | 값 |
|---|---|
| 소스 ref | `main` |
| 경로 | `samples/PolyLab3DStudio/` (파일 104개) |
| docs | `docs/superpowers/*/*polylab*` (2개) |
| 커밋 | 폴더 10 + docs 2 = **12** |
| 내용 | WPF `Viewport3D` 3D 학습 스튜디오. Core / ViewModels / WpfApp 3프로젝트, `net10.0-windows` |

요청에 나온 `feat/polylab3d-learning-studio` 브랜치는 `main`과 **동일하다**(0 ahead / 0 behind).
이미 병합되어 있으므로 `main`을 소스로 쓴다.

**소스 저장소 `dotnet-with-claudecode`는 수정하지 않는다.** 폴더를 그대로 둔 채 복제 추출만 한다.
나중에 원본에서 제거하고 싶어지면 히스토리 재작성 없이 일반 `git rm` 커밋으로 처리할 수 있으므로,
지금 되돌리기 어려운 변경을 가할 이유가 없다.

이 프로젝트 때문에 매니페스트에 **소스 저장소** 개념이 필요해진다(§4). 그 외에는 갈래 A와 완전히 같다.

## 3. 저장소 매핑

### 3.1 갈래 A — 분할 13개 (`git filter-repo`)

소스 저장소 표기가 없는 행은 전부 `christian289/Playground`다.

| 저장소 | 소스 ref | 가져올 경로 | 폴더 커밋 |
|---|---|---|---|
| `love2d-serverdev` | `feature/serverdev` → `main`<br>`main` → `legacy/codedefense-0.1` | `love2d-codedefense/`, `love2d-thisfar/`, `love2d-serverdev/` (전부 루트로), `docs/superpowers/*/*codedefense*` (16) | 99 |
| `PolyLab3DStudio` | **소스: `dotnet-with-claudecode`**<br>`main` → `main` | `samples/PolyLab3DStudio/` (루트로), `docs/superpowers/*/*polylab*` (2) | 10 |
| `PretextWpf` | `main` | `PretextWpf/` (루트로), `docs/superpowers/*/*pretext*` (3) | 12 |
| `love2d-mario` | `main` | `love2d-mario/` | 3 |
| `love2d-tetris` | `main` | `love2d-tetris/` | 3 |
| `MultiProcessTabbedBrowser` | `claude/multi-process-tabbed-browser-BIML2` → `main` | `MultiProcessTabbedBrowser/` | 3 |
| `DotNetOAuth2Learning` | `main` | `DotNetOAuth2Learning/` | 1 |
| `WpfOnnxWinUI3Demo` | `main` | `WpfOnnxWinUI3Demo/` | 1 |
| `WpfAutomationDemo` | `main` | `WpfAutomationDemo/` | 1 |
| `WinAppCliOcr` | `main` | `WinAppCliOcr/` | 1 |
| `MewUIPixelAnimation` | `main` | `MewUIPixelAnimation/` | 1 |
| `Wpf3DTutorial` | `main` | `Wpf3DTutorial/` | 1 |
| `OldNewThingMcpServer` | `add-old-new-thing-mcp-server` → `main` | `OldNewThingMcpServer/` | 1 |

"폴더 커밋"은 해당 폴더만 기준으로 센 값이다. docs가 붙는 세 저장소는 docs 전용 커밋이 더해져
`love2d-serverdev` **125**, `PretextWpf` **14**, `PolyLab3DStudio` **12**가 된다(실측).
`love2d-serverdev`의 `legacy/codedefense-0.1` 브랜치는 그중 24커밋이며 전부 `main`의 조상이다.

**`love2d-serverdev` 기본 브랜치:** `feature/serverdev` 결과를 `main`으로 승격한다.
구 `main`의 codedefense 0.1 시점은 `legacy/codedefense-0.1`로 보존한다.
두 갈래가 모두 남으므로 잃는 것은 없고 기본 진입점만 최신이 된다.

**미병합 브랜치 출신 2개:** 새 저장소에서 브랜치로 남길 이유가 없으므로 `main`으로 승격한다.

### 3.2 갈래 B — 이관 2개 (`gh api .../transfer`)

| 저장소 | 현재 | 비고 |
|---|---|---|
| `christian289/wonderland` | PUBLIC, C#, 99 KB | 이관만 |
| `christian289/MewUiBadApple` | PUBLIC, C#, 13.8 MB | 이관만 |

이미 독립 저장소이므로 재작성하지 않는다. 이관은 히스토리·이슈·PR·스타·위키를 보존하고
**커밋 해시가 유지**되며 옛 URL에서 자동 리다이렉트가 걸린다. filter-repo를 쓰면 이 모두를 잃으므로 순손해다.

갈래 A와 B는 배타적 선택지가 아니라 **대상이 겹치지 않는 동시 진행 작업**이다.
`PolyLab3DStudio`가 이관이 아니라 분할인 이유도 같은 기준이다 — 저장소가 아니라 폴더이므로
이관 단위가 될 수 없다.

### 3.3 루트 파일 처리

| 파일 | 처리 |
|---|---|
| `README.md` (`# Playground` 한 줄) | 승계하지 않음. 각 저장소에 새로 작성 |
| `package.json` (`{}`), `package-lock.json` | 폐기. npm 잔재 |
| `.gitignore` (Visual Studio용) | 승계하지 않음. 각 저장소에 맞게 재작성 |
| `.claude/CLAUDE.md` | 모노레포 전제로 쓰인 글이라 그대로는 부적합. WPF 저장소에 문맥 맞춰 재작성 |
| `.claude/settings.json` | 승계하지 않음 |

이들은 히스토리로 옮기지 않고, 각 저장소에 **부트스트랩 커밋 1개**를 히스토리 맨 위에 얹어 처리한다.
기존 커밋 이력은 그대로 보존된다.

부트스트랩 커밋 내용:

- `.gitignore` — .NET 프로젝트는 루트 Visual Studio 규칙 이식, love2d 프로젝트는 Lua/LÖVE용 신규 작성
- `README.md` — 없는 5곳(`MewUIPixelAnimation`, `Wpf3DTutorial`, `WpfAutomationDemo`, `OldNewThingMcpServer`, `PretextWpf`)에 생성
- `CLAUDE.md` — WPF 저장소에 루트 CLAUDE.md의 WPF/WinUI 판단 기준을 프로젝트 문맥으로 재작성

기존 보유 현황:

| 프로젝트 | 보유 |
|---|---|
| `love2d-serverdev`, `love2d-mario`, `love2d-tetris`, `WpfOnnxWinUI3Demo` | README, CLAUDE |
| `WinAppCliOcr` | README, .gitignore |
| `DotNetOAuth2Learning`, `MultiProcessTabbedBrowser`, `PolyLab3DStudio` | README |
| `PretextWpf` | .gitignore |
| `MewUIPixelAnimation`, `Wpf3DTutorial`, `WpfAutomationDemo`, `OldNewThingMcpServer` | 없음 |

`PretextWpf` 추가 항목: `upstream-manifest.json`이 `LICENSE-PRETEXT`와 `LICENSE-WPF-SAMPLES`를
산출물로 선언하는데 두 파일이 저장소에 없다. 모노레포 안에 있을 때보다 독립 public 저장소가 되면
문제가 커지므로(chenglou/pretext와 microsoft/WPF-Samples의 MIT 코드를 고지 없이 배포)
부트스트랩 커밋에서 상류 라이선스 전문을 함께 넣는다.

`PolyLab3DStudio` 추가 항목: README가 "this repository's WPF coding rules"로
`dotnet-with-claudecode`의 규칙을 참조하는데, 분리되면 이 참조가 끊긴다.
부트스트랩 CLAUDE.md에 해당 규칙(CommunityToolkit.Mvvm + GenericHost, UI 비의존 ViewModel,
`net10.0-windows`)을 옮겨 적는다.

## 4. 분할 파이프라인

프로젝트마다 독립적으로, scratchpad 안에서 수행한다.

**소스 저장소는 둘이다.** 매니페스트의 각 항목이 어느 쪽에서 나오는지 선언한다.

| 키 | 위치 | 대상 |
|---|---|---|
| `Playground` | `C:\Users\chris\personal\Playground` (로컬) | 12개 |
| `DotnetWithClaudeCode` | `<scratch>/_sources/dotnet-with-claudecode.git` (bare 복제) | `PolyLab3DStudio` |

후자는 로컬에 없으므로 파이프라인 시작 전에 bare 복제를 한 번 만든다.
검증도 이 로컬 복제를 기준값 원천으로 쓴다.

```
0. (외부 소스만) git clone --bare <URL> <scratch>/_sources/<name>.git
1. git init --bare <scratch>/<repo>.git
2. git -C <repo>.git fetch <소스 저장소> <소스 ref>:refs/heads/<대상 브랜치>   (필요한 ref 수만큼 반복)
3. git -C <repo>.git filter-repo --force \
       --path <폴더>/ --path-rename <폴더>/: \
       --path-glob '<docs 글로브>'
4. 검증
```

`love2d-serverdev`만 2단계에서 ref를 둘 가져온다
(`feature/serverdev`→`main`, `main`→`legacy/codedefense-0.1`).
filter-repo는 저장소의 모든 ref를 한 번에 필터링하므로 3단계는 그대로 한 번만 실행한다.

두 소스 저장소 모두 **fetch 소스로 읽기만** 한다. 13개 저장소가 서로 독립이므로 하나가 잘못되면
해당 폴더만 지우고 다시 돌린다.

경로 목록은 PowerShell 해시테이블 매니페스트 하나에 선언하고 거기서 filter-repo 인자를 생성한다.
`love2d-serverdev`처럼 폴더 3개 + docs 글로브가 붙는 경우를 손으로 관리하지 않기 위함이다.

**docs 매칭은 글로브로.** 파일을 나열하는 대신 세 패턴을 쓴다.

| 패턴 | 소스 | 개수 | 귀속 |
|---|---|---|---|
| `docs/superpowers/*/*codedefense*` | Playground | 16 | `love2d-serverdev` |
| `docs/superpowers/*/*pretext*` | Playground | 3 | `PretextWpf` |
| `docs/superpowers/*/*polylab*` | dotnet-with-claudecode | 2 | `PolyLab3DStudio` |

같은 소스 안에서 패턴끼리 겹치지 않고, Playground의 docs 19개 전부를 덮는다(파일명으로 확인).
docs 파일은 경로를 유지한다 — superpowers 스킬의 기본 경로이므로 각 저장소에서 그대로 이어 쓸 수 있다.

`dotnet-with-claudecode`의 나머지 docs는 그 저장소에 그대로 남는다. 우리가 가져오는 것은
polylab 관련 2개뿐이며, 원본에서 삭제하지 않으므로 양쪽에 존재하게 된다.

본 설계서(`2026-08-06-playground-repo-split-design.md`)는 어느 글로브에도 매칭되지 않으므로
아카이브된 Playground에만 남는다. 분할 자체에 관한 메타 문서이므로 의도된 결과다.

## 5. 검증

푸시 전에 13개 전부 자동 대조한다. **전부 통과하기 전에는 아무것도 푸시하지 않는다.**

| 검사 | 방법 | 통과 기준 |
|---|---|---|
| 파일 무결성 | 원본 `git ls-tree -r <ref> -- <폴더>`(접두사 제거) vs 새 저장소 `git ls-tree -r <브랜치>` | 경로·모드·blob SHA 완전 일치 |
| 커밋 개수 | 원본 `git rev-list --count <ref> -- <경로들>` vs 새 저장소 커밋 수 | 일치 |
| 히스토리 내용 | 저자·날짜·메시지 시퀀스 대조 | 순서까지 일치 |

`<경로들>`은 §4 매니페스트가 filter-repo에 넘긴 것과 **동일한 경로 집합**을 쓰고,
비교 원천은 해당 항목의 **소스 저장소**다(§4 표). docs가 붙는 저장소는 docs 글로브까지 포함한다.
기준값은 `love2d-serverdev` 125, `PretextWpf` 14, `PolyLab3DStudio` 12,
나머지는 §3.1 "폴더 커밋" 열과 같다.

blob SHA까지 비교하므로 파일 한 바이트가 달라져도 잡힌다.
결과는 12행짜리 표 하나로 출력하고 사용자 확인을 받는다.

**빌드 검증은 하지 않는다.** 현재 모노레포에서도 전부 빌드된다는 보장이 없어
(`WpfOnnxWinUI3Demo`는 Windows App SDK + Visual Studio MSBuild 필요) 실패해도
분할 탓인지 원래 그런지 구분되지 않는다. blob 단위 동일성이 "내용은 한 글자도 안 바뀌었다"를 보장한다.

## 6. 실행 순서

| 단계 | 내용 | 되돌리기 |
|---|---|---|
| 0 | 사전 점검: 워크트리 미커밋 변경 확인 | — |
| 1 | **갈래 B** — `wonderland`, `MewUiBadApple` 이관 (권한 검증 겸용) | 역방향 이관 |
| 2 | `git-filter-repo` 설치 + 외부 소스 복제 + 매니페스트 작성 | 해당 없음 |
| 3 | **갈래 A** — scratchpad에서 13개 분할 (푸시 없음) | 폴더 삭제 |
| 4 | **검증 표 출력 → 정지, 사용자 확인** | — |
| 5 | 부트스트랩 커밋 | 커밋 되돌리기 |
| 6 | 조직에 13개 저장소 생성 + 푸시 | 저장소 삭제 |
| 7 | Playground README를 15개 색인으로 교체 후 푸시 | 커밋 되돌리기 |
| 8 | Playground 아카이브 | 언제든 해제 가능 |
| 9 | 로컬 작업 환경 재구성 안내 | — |

갈래 B를 먼저 하는 이유: API 호출 두 번으로 끝나면서 조직 저장소 생성 권한을 위험 없이 검증한다.
여기서 막히면 13개를 다 만들어 놓고 푸시 단계에서 실패하는 상황을 피할 수 있다.

**되돌릴 수 없는 지점은 없다.** 원본을 삭제하지 않기 때문이다.
단계 4가 유일한 필수 정지점이고 나머지는 연속 진행한다.

## 7. 사전 조건 (완료됨)

| 조건 | 상태 |
|---|---|
| Organization `christian289-playground` 생성 (Free) | 완료 — API로 생성 불가하여 웹에서 수동 수행 |
| `gh auth switch --user christian289` | 완료 — 활성 계정 확인 |
| 토큰 scope `admin:org` | 완료 — `admin:org, gist, repo, workflow` |
| `pip install git-filter-repo` | 단계 2에서 수행 (Python 3.14.3 확인) |

미커밋 변경은 `main-2` 워크트리의 `package-lock.json` 한 줄
(`"name": "Playground"` → `"main-2"`, npm이 워크트리 폴더명으로 덮어씀)뿐이며 폐기 대상이다.
`feature-serverdev-2` 워크트리는 디스크에 존재하지 않는 유령 등록이다.

## 8. 알려진 트레이드오프

- **분할 13개는 커밋 해시가 전부 바뀐다.** 저자·날짜·메시지·변경 내용·순서는 보존되지만
  기존 해시를 참조하는 링크와 로컬 클론은 무효가 된다. 히스토리 재작성의 본질적 성질이라 우회로가 없다.
  이관 2개는 해시가 유지된다.
- **`PolyLab3DStudio`는 원본과 사본이 동시에 존재하게 된다.** `dotnet-with-claudecode`를
  수정하지 않기로 했으므로 같은 코드가 두 곳에 있고, 이후 수정은 한쪽에만 반영된다.
  새 저장소를 정본으로 삼고, 원할 때 원본에서 `git rm` 커밋으로 정리하면 된다.
- **아카이브된 Playground와 새 저장소 사이에 내용 중복이 생긴다.** 아카이브는 읽기 전용이므로
  "어디에 커밋할지" 혼동은 발생하지 않는다.
- **`docs/` 문서가 프로젝트별로 흩어진다.** 전체를 한눈에 보려면 아카이브를 봐야 한다.
  단계 7의 README 색인이 이를 완화한다.

## 9. 단계 9 — 로컬 환경 재구성 (안내만)

현재 로컬에는 Playground 클론 1개와 워크트리 2개(1개는 유령)가 있다.
분할 후 이들은 아카이브된 저장소를 가리키게 된다.

권고: `C:\Users\chris\personal\playground\<프로젝트>` 아래에 필요한 저장소만 새로 클론하고,
기존 폴더는 `Playground.bak`으로 남긴다. 어느 프로젝트를 로컬에 둘지는 상황에 따라 다르므로 강제하지 않는다.
