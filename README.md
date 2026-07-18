# MapRibbon iOS MVP

사진의 촬영 날짜와 위치 메타데이터를 이용해 하루 여행 포토보드를 자동 생성하는 SwiftUI 앱입니다.

## 실행

1. `MapRibbon.xcodeproj`를 Xcode에서 엽니다.
2. Signing & Capabilities에서 개발팀을 지정합니다.
3. 실제 iPhone에서 실행합니다. 시뮬레이터는 사진 위치 메타데이터 테스트가 제한적입니다.
4. 영구 구매 테스트를 하려면 App Store Connect 또는 StoreKit Configuration에 `com.eiraworks.mapribbon.lifetime` 비소모성 상품을 등록합니다.

## MVP 포함 범위

- 사진 보관함 권한 및 제한 접근
- 위치 사진 날짜 자동 탐색
- 시간·거리 기반 장소 클러스터링
- 역지오코딩과 대표 사진 자동 선택
- MapKit 정적 지도 생성
- 리본 / 에디토리얼 / 포스트카드 / 스크랩 템플릿
- 장소명, 순서, 대표 사진, 표시 여부 수정
- 9:16 / 4:5 / 3:4 렌더링
- 사진 저장 및 공유 시트
- SwiftData 보드 아카이브
- 한국 17개 지역 Memory Atlas
- StoreKit 2 영구 구매 골격
- 한국어 우선 및 일본어 핵심 문자열

## 의도적으로 제외한 범위

GPS 백그라운드 추적, 실제 도로 경로, 계정, 서버, 광고, 공개 피드, 여행 일정, 영상 생성, 자유형 캔버스 편집.

## 검증 상태

macOS/Xcode에서 iOS 시뮬레이터용 빌드와 `PhotoClustererTests` 2건을 통과했습니다. 실제 iPhone의 사진 위치 메타데이터, 권한 흐름, iCloud 원본 다운로드, 지도 스냅샷, StoreKit 상품은 기기·스토어 환경에서 별도 확인이 필요합니다.
