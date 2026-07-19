# MouseRun

> 트랙패드와 블루투스 마우스를 오갈 때, 스크롤 방향도 자동으로.

MouseRun은 Mac의 블루투스 마우스 연결 상태를 감지해 **자연스러운 스크롤** 방향을 자동으로 바꾸는 작은 메뉴 막대 앱입니다.

<p align="center">
  <img src="Resources/MouseMenuPreview.png" width="450" alt="MouseRun 메뉴 막대 애니메이션 프레임">
</p>

<p align="center">
  <a href="https://github.com/MUNCHHHHH/MouseRun/releases/latest"><strong>최신 버전 다운로드</strong></a>
  ·
  <a href="#설치">설치 방법</a>
  ·
  <a href="PRIVACY.md">개인정보 안내</a>
</p>

RunCat은 별도의 앱이며 MouseRun에 포함되지 않습니다. 원한다면 메뉴 막대에서 MouseRun 아이콘을 RunCat 옆으로 직접 옮겨 사용할 수 있습니다.

## 무엇을 해결하나요?

트랙패드에서는 자연스러운 스크롤이 편하지만, 일반 마우스에서는 반대 방향이 익숙한 경우가 많습니다. MouseRun은 기기를 바꿀 때마다 시스템 설정을 여는 일을 없애줍니다.

| 현재 입력 기기 | MouseRun 동작 |
| --- | --- |
| 트랙패드만 사용 | 자연스러운 스크롤 켜짐 · 아이콘 멈춤 |
| 블루투스 마우스 연결 | 자연스러운 스크롤 꺼짐 · 아이콘 달림 |
| 메뉴에서 정상 종료 | 자연스러운 스크롤 켜짐 |

## 주요 기능

- 블루투스 및 Bluetooth Low Energy 마우스 감지
- 연결·해제 이벤트에 맞춘 즉시 스크롤 방향 전환
- 놓친 이벤트를 복구하는 15초 간격 백업 확인
- 앱을 실행할 때 로그인 실행 항목 자동 등록
- 중복 실행 방지
- 문제 해결 정보를 한 번에 복사하는 메뉴
- Apple Silicon과 Intel Mac을 모두 포함한 Universal 앱

## 설치

1. [최신 GitHub Release](https://github.com/MUNCHHHHH/MouseRun/releases/latest)에서 `.dmg` 파일을 다운로드합니다.
2. DMG를 열고 `MouseRun.app`을 `Applications` 폴더로 드래그합니다.
3. `Applications`에서 MouseRun을 실행합니다.

현재 직접 배포 버전은 ad-hoc 서명되어 있습니다. macOS가 개발자를 확인할 수 없다고 표시하면 Finder에서 `MouseRun.app`을 Control-클릭한 뒤 **열기**를 선택하세요.

메뉴 막대 아이콘은 `Command` 키를 누른 채 드래그해 원하는 위치로 옮길 수 있습니다.

## 배포 모드

| 모드 | 자동 스크롤 전환 | 용도 |
| --- | --- | --- |
| Direct | 지원 | GitHub Release에서 받는 전체 기능 버전 |
| App Store | 지원하지 않음 | 샌드박스 안에서 마우스 연결 상태만 표시하는 빌드 경로 |

Direct 빌드는 실제 스크롤 동작을 즉시 바꾸기 위해 macOS의 비공개 `PreferencePanesSupport` 기능을 사용하고, 사용할 수 없을 때 시스템 기본값 변경 방식으로 대체합니다. macOS 업데이트에 따라 이 동작이 영향을 받을 수 있습니다.

## 호환성

- Intel Mac: macOS 10.15 이상
- Apple Silicon Mac: macOS 11 이상
- 블루투스 마우스 대상
- USB 전용 마우스는 자동 전환 대상이 아님

## 개인정보

MouseRun에는 계정, 광고, 분석 도구 또는 네트워크 전송 기능이 없습니다. 최근 동작 기록 최대 50개를 Mac 안에 저장하며, 사용자가 **문제 해결 정보 복사**를 선택할 때만 상태와 기록을 클립보드에 복사합니다.

저장 항목과 삭제 방법은 [PRIVACY.md](PRIVACY.md)에서 확인할 수 있습니다.

## 소스에서 빌드

Xcode 프로젝트나 외부 패키지 없이 macOS에 포함된 Swift 도구로 빌드합니다.

```sh
./build.sh direct --no-package
```

DMG까지 만들려면:

```sh
./build.sh direct
```

App Store용 테스트 번들:

```sh
./build.sh appstore
```

## 테스트

블루투스 마우스 분류 테스트:

```sh
./test.sh
```

Direct/App Store 빌드와 macOS 대상 버전 호환성 검사:

```sh
./compatibility_test.sh
```

## 문제 해결

- 마우스가 감지되지 않으면 메뉴 막대의 MouseRun 아이콘을 열어 현재 상태를 확인합니다.
- **문제 해결 정보 복사**를 선택하면 감지된 기기와 최근 이벤트가 클립보드에 복사됩니다.
- 새 이슈를 등록할 때 macOS 버전과 마우스 모델을 함께 알려주세요.

[문제 제보하기](https://github.com/MUNCHHHHH/MouseRun/issues)

## 알려진 제한

- Direct 빌드는 시스템 전체의 자연스러운 스크롤 설정을 변경합니다.
- App Store 빌드 경로는 연결 상태만 표시하며 스크롤 설정을 바꾸지 않습니다.
- 정상 종료 시에는 자연스러운 스크롤을 켜지만, 강제 종료나 충돌 시에는 종료 정리 코드가 실행되지 않을 수 있습니다.
- 로그인 실행 항목 등록은 macOS 설정이나 권한 상태에 따라 실패할 수 있습니다.
- 모든 블루투스 마우스 모델의 실제 기기 동작을 보장하지는 않습니다.

## 릴리스

새 릴리스의 버전·태그·빌드 검증 절차는 [RELEASING.md](RELEASING.md)에 정리되어 있습니다.

## 라이선스

- 소스 코드, 빌드·테스트 스크립트, 설정 파일과 문서 텍스트는 [MIT License](LICENSE)로 공개합니다.
- `Resources/*.png`를 포함한 이미지·아이콘·캐릭터·기타 시각 자산은 MIT 대상이 아니며 MUNCH가 모든 권리를 보유합니다. 개인적인 평가·사용을 위해 수정하지 않은 MouseRun을 빌드하고 실행하는 범위 외의 재사용은 별도 허가가 필요합니다. 자세한 범위는 [ASSET_LICENSE.md](ASSET_LICENSE.md)를 확인하세요.

<details>
<summary>English overview</summary>

MouseRun is a small macOS menu bar app that switches natural scrolling automatically:

- Trackpad only: natural scrolling on
- Bluetooth mouse connected: natural scrolling off
- Normal app quit: natural scrolling on

The direct-distribution build provides automatic switching. The sandboxed App Store build path is monitor-only.

[Download the latest release](https://github.com/MUNCHHHHH/MouseRun/releases/latest)

Source code is available under the [MIT License](LICENSE). MouseRun image and
visual assets are excluded from MIT and remain protected under the
[MouseRun Visual Asset License](ASSET_LICENSE.md).

</details>
