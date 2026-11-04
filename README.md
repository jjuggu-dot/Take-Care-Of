# Take Care Of

애플워치에서 까마귀를 돌보는 게임의 시험 앱입니다.

- `Sources/`: SwiftUI 코드
- `project.yml`: XcodeGen 프로젝트 설정
- `.github/workflows/build.yml`: GitHub Actions 빌드와 TestFlight 업로드

맥 없이 GitHub Actions에서 빌드합니다. TestFlight 업로드에는 저장소 Secrets(`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `TEAM_ID`)가 필요합니다.
