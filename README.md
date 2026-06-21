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

## 설치

최신 GitHub Release에서 DMG 파일을 다운로드하세요.

DMG를 열고 `MouseRun.app`을 `Applications`로 드래그하면 설치됩니다.

## 직접 배포 실행 안내

이 빌드는 Apple Developer ID 인증서 없이 ad-hoc 서명됩니다. 다른 Mac에서 처음 실행할 때 macOS가 개발자를 확인할 수 없다고 표시하면 Finder에서 `MouseRun.app`을 Control-클릭한 뒤 `열기`를 선택하세요.

## 로컬 빌드

```sh
./build.sh
```

생성되는 파일:

- `dist/MouseRun-0.1.0+1-macOS-universal.dmg`
- `dist/SHA256SUMS.txt`
- `dist/RELEASE_NOTES.md`

Developer ID 인증서가 있으면 아래처럼 서명된 배포물을 만들 수 있습니다.

```sh
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build.sh
```
