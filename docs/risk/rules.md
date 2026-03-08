# Risk Rules & Scoring

## 1. 목적
- 로그인/계정변경 이벤트로부터 ATO 의심 신호를 룰로 평가하여 score(0~100) 및 level을 산출한다.
- “왜 위험한지”를 hitRules(JSON)로 저장하여 설명 가능하게 한다.

## 2. 점수 정책
- score = min(100, sum(rule.weight))
- level:
    - LOW: 0~49
    - MED: 50~79
    - HIGH: 80~100

## 3. hitRules 저장 포맷(JSON)
- risk_assessments.hit_rules
```json
[
  {
    "ruleId": "R001_NEW_DEVICE",
    "weight": 25,
    "evidence": {
      "deviceIdHash": "...",
      "knownDevice": false
    }
  }
]
```
## 4. 룰 목록(MVP 6개)
### R001_NEW_DEVICE (weight=25)
- 조건: user_devices에 (user_id, device_id_hash)가 없음
- 적용 이벤트: LOGIN_SUCCESS, LOGIN_FAILURE
- evidence: deviceIdHash, knownDevice(boolean)

### R002_NEW_COUNTRY (weight=20)
- 조건: 최근 성공 로그인 국가 != 현재 국가
- 적용 이벤트: LOGIN_SUCCESS
- evidence: prevCountry, currentCountry, prevOccurredAt

### R003_FAIL_BURST (weight=30)
- 조건: 5분 내 실패 로그인 횟수 >= N(예: 10)
- 적용 이벤트: LOGIN_FAILURE
- evidence: windowSeconds, failCount, key(ip or identifier)

### R004_IMPOSSIBLE_TRAVEL (weight=35)
- 조건: prevLoginGeo와 currentGeo 간 거리 대비 경과 시간이 비현실적
- 적용 이벤트: LOGIN_SUCCESS
- evidence: prev(lat,lon,time), curr(lat,lon,time), distanceKm, minutes

### R005_IP_BLOCKLIST (weight=90)
- 조건: ip_blocklist에 active로 존재(만료 전)
- 적용 이벤트: LOGIN_SUCCESS/FAIL 시도 자체(또는 BLOCKED_IP_LOGIN)
- evidence: blockId, ip, expiresAt

### R006_SENSITIVE_AFTER_LOGIN (weight=25)
- 조건: 로그인 직후(예: 10분 이내) 비밀번호 변경 시도
- 적용 이벤트: PASSWORD_CHANGE
- evidence: lastLoginAt, deltaSeconds, lastRiskLevel(optional)

## 5. 룰 평가 순서(권장)
- BLOCKLIST 관련은 가장 먼저(즉시 HIGH 수준)
- 나머지는 독립적으로 hit 가능(합산)
