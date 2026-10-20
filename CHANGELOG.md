# Changelog - EzWoW - Chat Translator

## v1.5.0
- 드래그 시 마우스 포인터와 아이콘/프레임 좌표가 어긋나거나 벌어지는 스케일 오차(`EffectiveScale`) 및 초기 점프 현상 수정
- **아키텍처 재구성 (`Core/`, `Data/`, `Modules/`, `UI/`) 및 성능 최적화**:
  - `Core/Init.lua`, `Core/LocaleCore.lua`, `Core/LocaleExtra.lua`, `Core/LocaleUI.lua`, `Core/UIKit.lua` 분리
  - `Modules/TranslatorEngine.lua`(인덱스·토크나이저·번역 캐시), `Modules/ChatFilter.lua`, `Modules/OutgoingAndDict.lua`, `Modules/TooltipTranslator.lua`, `Modules/PlayerTooltip.lua`, `Modules/BackgroundScanner.lua`, `Modules/UnknownChat.lua` 모듈화
  - 툴팁 번역 결과 메모이제이션 캐시 및 백그라운드 스캐너 제로 클로저 적용으로 프레임 드랍 방지
- **다국어 확장 및 기능 보강**:
  - 독일어(`de`)·프랑스어(`fr`) 대상 언어 번역표(각 965개 항목) 및 `/ezct de`, `/ezct fr` 발신 번역 추가 (총 9개 출력 언어 지원)
  - `/ezct search <단어>`(`/ezct 검색 <단어>`) 내장·사용자 사전 통합 검색 및 `/ezct on|off`(`켜기|끄기`) 빠른 토글 명령어 추가
  - 신규 던전, 공격대, 직업/특성, 전투/거래/소통 약어 등 전체 내장 사전 23,116개 항목으로 확장

## v1.4.10
- 발신 번역 혼합 문장 처리 개선 및 사용자 사전 복원 보강
- `Shift+좌클릭` 캐릭터 조회 툴팁 및 미등록 외국어 채팅 예문 수집 정밀도 개선
- 세트 효과 및 12개 전문기술 숙련도·재료·획득처 툴팁 번역 보강
