# MouseRun 릴리스 절차

이 문서는 GitHub의 소스, 태그, DMG가 같은 버전의 같은 코드를 가리키도록 유지하기 위한 체크리스트입니다.

## 다음 릴리스

다음 권장 버전은 `1.0.2`이며 빌드 번호는 `102`입니다.

기존 `v1.0.1` 태그는 GitHub에 공개된 과거 커밋을 가리키고 있으므로 이동하거나 강제로 덮어쓰지 않습니다. 최신 canonical 소스를 새 커밋으로 병합한 뒤 새 `v1.0.2` 태그를 만듭니다.

## 1. 버전 확인

`Resources/Info.plist`:

```text
CFBundleShortVersionString = 1.0.2
CFBundleVersion = 102
```

## 2. 테스트와 빌드

```sh
./test.sh
./compatibility_test.sh
./build.sh direct --no-package
./build.sh appstore
./build.sh direct
```

모든 명령이 성공한 뒤 다음 산출물을 확인합니다.

```text
dist/direct/MouseRun-1.0.2+102-macOS-universal.dmg
dist/direct/SHA256SUMS.txt
dist/direct/RELEASE_NOTES.md
```

## 3. Git 정합성

- 변경사항을 검토하고 `main`에 병합합니다.
- 릴리스용 빌드가 완료된 정확한 커밋에만 태그를 만듭니다.
- 기존 태그는 다시 만들거나 강제로 이동하지 않습니다.

```sh
git tag -a v1.0.2 -m "MouseRun 1.0.2"
git push origin main
git push origin v1.0.2
```

## 4. GitHub Release

- Tag: `v1.0.2`
- Title: `MouseRun 1.0.2`
- Notes: `dist/direct/RELEASE_NOTES.md`
- Asset: `dist/direct/MouseRun-1.0.2+102-macOS-universal.dmg`
- Checksum: `dist/direct/SHA256SUMS.txt`

Release를 공개한 뒤 [최신 릴리스 링크](https://github.com/MUNCHHHHH/MouseRun/releases/latest)가 `v1.0.2`로 이동했는지 확인합니다.

## 5. GitHub 저장소 정보

권장 설명:

```text
Automatically switch macOS natural scrolling when a Bluetooth mouse connects.
```

권장 Topics:

```text
macos
menubar-app
swift
bluetooth
mouse
scroll-direction
natural-scrolling
productivity
macos-utility
```

홈페이지 URL은 실제 GitHub Pages 배포가 검증된 뒤에만 설정합니다.

## 6. 깃밥 등록 전

- README의 다운로드·호환성·개인정보 설명 확인
- 공개 소스와 최신 릴리스 버전 일치 확인
- 루트 `LICENSE`가 표준 MIT 문구로 유지되는지 확인
- 모든 이미지·시각 자산이 `ASSET_LICENSE.md`의 보호 범위에 포함되는지 확인
- 실제 사용자 피드백 반영
- 깃밥 커뮤니티 등록에 필요한 별 수 확인
