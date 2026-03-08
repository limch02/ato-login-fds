# ATO Login FDS - Requirements

## 1. 목표(1문장)
로그인/계정변경 이벤트를 수집(append-only)하고 룰 기반 리스크 점수(0~100)를 산출하여, 관리자가 위험 이벤트를 관제하고 계정 잠금/세션 무효화/IP 차단으로 대응할 수 있는 시스템을 만든다.

## 2. 핵심 사용자(Personas)
- USER: 일반 사용자(로그인/로그아웃/비밀번호 변경)
- ADMIN: 관제 담당자(리스크 이벤트 조회/조치/감사로그 확인)

## 3. MVP 범위
### 3.1 기능(MVP)
- 인증
    - 로그인(Access/Refresh)
    - 토큰 갱신(Refresh)
    - 로그아웃(Refresh 세션 revoke)
    - 비밀번호 변경(현재 비밀번호 검증 포함)
- 이벤트 로깅(append-only)
    - 로그인 성공/실패 이벤트 기록
    - 비밀번호 변경 이벤트 기록
    - (관리자 조치 관련 이벤트 기록은 선택 또는 admin_actions로만 기록)
- 리스크 산정
    - 룰 기반 점수(0~100), level(LOW/MED/HIGH)
    - hitRules(왜 위험한지 근거) JSON 저장
- 관리자 기능
    - 리스크 목록/상세 조회
    - 계정 잠금/해제
    - 강제 로그아웃(세션 무효화)
    - IP 차단/해제
    - 관리자 조치 감사로그 조회
- 기본 보안
    - 로그인 실패 응답 메시지 일반화(계정 열거 방지)
    - 레이트리밋(로그인/refresh) 적용(권장)

### 3.2 비기능(MVP)
- API 문서: OpenAPI(YAML) + Swagger UI로 확인 가능
- 로컬 실행: Docker Compose로 MySQL(+Redis) 실행 가능
- 데이터 무결성: auth_events/admin_actions는 append-only 원칙

## 4. 확장 범위(2달 이후/선택)
- 실시간 관제(SSE/WebSocket)
- Access Token 즉시 무효화(블랙리스트/버전 체크 강화)
- GeoIP ASN/Anonymous IP DB 적용(VPN/Proxy 탐지 고도화)
- 룰 관리 UI/DB 기반 룰 편집
- ML 스코어링 서비스(FastAPI) 분리
- 멀티테넌트/조직별 정책 적용

## 5. 사용자 시나리오(Use Cases)
### UC-01 정상 로그인
1) 사용자가 로그인 요청
2) 서버가 인증 성공
3) AuthEvent(LOGIN_SUCCESS) 저장
4) RiskAssessment 생성(LOW 또는 히트 없음)
5) 토큰 발급

### UC-02 공격: 실패 로그인 폭증(브루트포스)
1) 동일 IP에서 5분 내 실패 10회
2) AuthEvent(LOGIN_FAILURE) 누적
3) RiskAssessment에서 FAIL_BURST 룰 히트 → MED/HIGH

### UC-03 공격: 새 기기 + 새 국가 로그인(ATO 의심)
1) 새 deviceId로 로그인 성공
2) GeoIP 국가가 이전과 다름
3) RiskAssessment에서 NEW_DEVICE + NEW_COUNTRY 히트 → 점수 상승

### UC-04 관리자 대응
1) ADMIN이 HIGH 목록 확인
2) 사용자 계정 잠금 + 강제 로그아웃 수행
3) AdminAction에 조치 기록
4) 이후 해당 사용자는 로그인 실패/세션 무효화 확인 가능

## 6. 정책(리스크 레벨)
- score: 0~100 (sum(weights) 후 100으로 clamp)
- level:
    - LOW: 0~49
    - MED: 50~79
    - HIGH: 80~100

## 7. 성공 기준(Definition of Done)
- 설계 문서만 보고 구현 가능(ERD/DDL/OpenAPI/룰/시나리오가 서로 일관)
- “새 기기 로그인 → HIGH 생성 → 관리자 잠금/강제 로그아웃” 데모 시나리오 가능