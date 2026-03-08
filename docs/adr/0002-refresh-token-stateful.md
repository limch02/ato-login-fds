# ADR-0002: Refresh Token is stored statefully (revocable sessions)

## Status
Accepted

## Context
- JWT Access Token은 만료 전까지 원칙적으로 무효화가 어렵다.
- ATO 대응에서 중요한 액션은 "강제 로그아웃/세션 무효화"이며,
  이를 즉시 반영하려면 서버가 세션 상태를 알아야 한다.

## Decision
- Refresh Token은 DB(`user_sessions`)에 해시로 저장하고,
  로그아웃/강제 로그아웃 시 revoke한다.
- Access Token은 짧은 만료 + Refresh 기반 재발급을 기본으로 한다.
- (선택) 즉시 Access 무효화가 필요하면 `security_version` 또는 blacklist를 추가한다.

## Consequences
### Pros
- 특정 디바이스/세션 단위로 revoke 가능
- 관리자 force-logout 기능 구현이 쉬움

### Cons / Trade-offs
- 완전한 stateless가 아님(DB 조회 또는 캐시 필요)
- 세션 테이블 관리/청소(만료 세션 정리) 필요

## Alternatives considered
- A) Refresh도 stateless로 운영(회수 어려움)
- B) Access 블랙리스트만 운영(캐시/키 관리 부담)
- 결론: MVP는 "운영/대응"이 우선이므로 stateful refresh를 채택한다.