# MouseRun

MouseRun은 블루투스 마우스 연결 상태에 따라 macOS의 자연스러운 스크롤을 자동 전환하는 작은 메뉴 막대 앱입니다.

- 제작자: MUNCH
- GitHub: [@MUNCHHHHH](https://github.com/MUNCHHHHH)
- macOS 13 이상
- Apple Silicon/Intel Universal 앱
- 블루투스 마우스 연결됨: 자연스러운 스크롤 꺼짐, 메뉴 막대 마우스가 달립니다.
- 블루투스 마우스 없음: 자연스러운 스크롤 켜짐, 메뉴 막대 마우스가 멈춥니다.
- 앱 종료: 자연스러운 스크롤 켜짐.
- 로그인 실행은 LaunchAgent로 자동 설치됩니다.
- 상단바에서는 RunCat 오른쪽에 MouseRun을 위치시키는 것을 권장합니다.

## 직접 배포용 빌드

```sh
./build.sh
```

생성되는 파일:

- `dist/MouseRun-0.1.0+1-macOS-universal.dmg`
- `dist/SHA256SUMS.txt`
- `dist/RELEASE_NOTES.md`

DMG를 열고 `MouseRun.app`을 `Applications`로 드래그하면 설치됩니다.

## GitHub 배포

GitHub Release를 만들 때:

- Tag: `v0.1.0`
- Release title: `MouseRun 0.1.0`
- Release notes: `dist/RELEASE_NOTES.md`
- Asset: `dist/MouseRun-0.1.0+1-macOS-universal.dmg`

## 로컬 설치까지 한 번에 하기

```sh
./build.sh --install
open /Applications/MouseRun.app
```

## 직접 배포 실행 안내

이 빌드는 Apple Developer ID 인증서 없이 ad-hoc 서명됩니다. 다른 Mac에서 처음 실행할 때 macOS가 개발자를 확인할 수 없다고 표시하면 Finder에서 `MouseRun.app`을 Control-클릭한 뒤 `열기`를 선택하세요.

Developer ID 인증서가 있으면 아래처럼 서명된 배포물을 만들 수 있습니다.

```sh
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build.sh
```
