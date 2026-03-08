# ADR-0001: auth_events / admin_actions are append-only

## Status
Accepted

## Context
- 본 프로젝트는 로그인/보안 이벤트 및 관리자 조치를 기반으로 “탐지→대응”을 수행한다.
- 보안 운영 관점에서 이벤트/조치 로그는 사후 분석과 책임 추적에 핵심이며,
  수정/삭제가 가능하면 공격자가 증거를 지우거나 조작할 수 있다.

## Decision
- `auth_events`와 `admin_actions`는 운영 원칙으로 **append-only**로 관리한다.
- 애플리케이션 레벨에서 UPDATE/DELETE API를 제공하지 않는다.
- (선택) DB 트리거로 UPDATE/DELETE를 차단하여 강제한다.

## Consequences
### Pros
- 감사 추적성(audit trail) 강화, 포렌식 친화적
- 운영/보안 관점에서 신뢰 가능한 로그 기반

### Cons / Trade-offs
- 잘못 기록된 이벤트를 “수정”할 수 없음 → 보정 이벤트로 처리해야 함
- 저장 용량 증가(추후 파티셔닝/보관 정책 필요)

## Alternatives considered
- A) 소프트 딜리트 + 수정 허용
- B) 별도 로그 저장소(예: Elasticsearch/SIEM)
- 결론: MVP에서는 DB에 append-only로 단순/명확하게 시작한다.