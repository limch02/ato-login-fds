# Demo Scenarios (with cURL)

## 공통 준비
- 로컬 실행: API `http://localhost:8080`
- ADMIN 계정 seed 존재 (예: `admin@example.com` / `Admin123!`)
- USER 계정 seed 존재 (예: `user@example.com` / `P@ssw0rd!`)
- (권장) 개발 환경에서는 `X-Forwarded-For`를 신뢰하도록 설정하거나, 테스트용으로 `X-Test-Client-Ip` 같은 헤더를 임시 지원해도 됩니다.

---

## S1. 새 기기 로그인 → HIGH 생성 → 관리자 잠금/강제 로그아웃

### 1) (USER) 새 deviceId로 로그인
> `deviceId`는 바디로 보내거나 헤더로 보내도 되는데, 여기서는 바디에 포함합니다.

```bash
curl -i -X POST "http://localhost:8080/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "user@example.com",
    "password": "P@ssw0rd!",
    "deviceId": "device-new-001"
  }'
  ```
- 기대 결과: 200 OK
- 응답에 accessToken, refreshToken이 포함되어야 함
- 내부적으로 auth_events에 LOGIN_SUCCESS가 저장되고, risk_assessments가 생성될 수 있음(룰 히트 여부에 따라)

### 2) (ADMIN) 토큰 준비
> '아래 값을 1)에서 받은 admin 토큰으로 교체하세요'
```bash
ADMIN_TOKEN="Bearer <ADMIN_ACCESS_TOKEN>"
```

### 3) (ADMIN) HIGH 위험 목록 확인
```bash
curl -s -X GET "http://localhost:8080/api/v1/admin/risks?level=HIGH" \
  -H "Authorization: ${ADMIN_TOKEN}"
```
- 기대효과: 200 OK
- item[]에 방금 발생한 위험 이벤트가 포함되어야 함(가중치/룰에 따라 MED일 수도 있음)

### 4) (ADMIN) 사용자 잠금
```bash
USER_ID=1

curl -i -X POST "http://localhost:8080/api/v1/admin/users/${USER_ID}/lock" \
  -H "Authorization: ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"reason":"ATO suspected"}'
```
- 기대효과: 204 No Content
- 내부적으로 users.status=LOCKED, admin_actions에 LOCK_USER 기록

### 5) (ADMIN) 강제 로그아웃
```bash
curl -i -X POST "http://localhost:8080/api/v1/admin/users/${USER_ID}/force-logout" \
  -H "Authorization: ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"reason":"force logout after lock"}'
```
- 기대 결과: 204 No Content
- 내부적으로 user_sessions revoke + (선택) security_version 증가
- admin_actions에 FORCE_LOGOUT 기록

### 6) (USER) 로그인 재시도 → 실패(일반화된 메시지)
```bash 
curl -i -X POST "http://localhost:8080/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "user@example.com",
    "password": "P@ssw0rd!",
    "deviceId": "device-new-001"
  }'
```
- 기대 결과: 401 Unauthorized (또는 정책에 따라 423 Locked를 쓰고 싶다면 그렇게 설계해도 됨)
- 중요한 점: 사용자에게 “잠금/존재 여부”를 과도하게 노출하지 않도록 메시지는 일반화 권장


## S2. IP 차단 → 로그인 즉시 거절
### 1) (ADMIN) IP 차단 등록
```bash 
curl -i -X POST "http://localhost:8080/api/v1/admin/blocklist/ip" \
  -H "Authorization: ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "ip":"203.0.113.10",
    "reason":"brute force suspected",
    "expiresAt": null
  }'
```
- 기대 결과: 201 Created
- 응답에 blockId, isActive=true

### 2) (USER) 차단된 IP에서 로그인 시도 (개발용 헤더 사용 예시)
> 로컬에서 실제 클라이언트 IP를 바꾸기 어려우므로, 개발 환경에서만 아래 중 하나를 택하세요.
    - (A) X-Forwarded-For를 신뢰하도록 설정 후 테스트
    - (B) X-Test-Client-Ip 같은 테스트용 헤더를 서버에 임시 구현
#### (A) X-Forwarded-For 사용 예시
```bash
curl -i -X POST "http://localhost:8080/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 203.0.113.10" \
  -d '{
    "identifier": "user@example.com",
    "password": "P@ssw0rd!",
    "deviceId": "device-new-002"
  }'
```
- 기대 결과: 401 Unauthorized 또는 403 Forbidden (정책 선택)
- 내부적으로: 로그인은 거절되고 auth_events에 BLOCKED_IP_LOGIN 또는 LOGIN_FAILURE(result=BLOCKED_IP) 같은 이벤트가 append-only로 저장되면 좋음

### 3) (ADMIN) 차단 해제
```bash
BLOCK_ID=1

curl -i -X DELETE "http://localhost:8080/api/v1/admin/blocklist/ip/${BLOCK_ID}" \
  -H "Authorization: ${ADMIN_TOKEN}"
```
- 기대 결과: 204 No Content
- 내부적으로 ip_blocklist.is_active=0 또는 비활성 처리
- admin_actions에 UNBLOCK_IP(혹은 BLOCK_IP 해제 타입) 기록

## S3. 실패 로그인 폭증(브루트포스) → FAIL_BURST 룰 히트

### 1) (ATTACKER) 같은 계정으로 실패 로그인 반복
> 아래는 예시로 12번 반복합니다.(룰이 10회 기준이면 MED/HIGH가 나와야함)
```bash
for i in $(seq 1 12); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -X POST "http://localhost:8080/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d '{
      "identifier": "user@example.com",
      "password": "wrong-password",
      "deviceId": "device-attacker-001"
    }'
done
```
- 기대 결과: 대부분 401
- 내부적으로 auth_events에 LOGIN_FAILURE 누적
- risk_assessments에 R003_FAIL_BURST 룰 히트가 저장되면 성공

### 2) (ADMIN) MED/HUGH 확인
```bash
curl -s -X GET "http://localhost:8080/api/v1/admin/risks?level=MED" \
  -H "Authorization: ${ADMIN_TOKEN}"
```