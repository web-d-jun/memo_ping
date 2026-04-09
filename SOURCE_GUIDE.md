# memo_ping 소스 가이드

직접 소스 수정 시 참고용 문서입니다.

---

## 전체 구조

```
lib/
├── main.dart                          ← 앱 진입점
├── models/
│   └── memo_item.dart                 ← 메모 데이터 구조 정의
├── screens/
│   ├── home_screen.dart               ← 메인 화면 (메모 목록)
│   └── add_memo_screen.dart           ← 메모 추가/수정 화면
├── services/
│   ├── location_monitor_service.dart  ← 포그라운드 위치 감시
│   ├── background_location_service.dart ← 백그라운드 위치 감시
│   └── geofence_manager.dart          ← 미사용 (재설계 예정)
└── widgets/
    ├── memo_card.dart                 ← 메모 목록의 카드 1개
    └── photo_label_picker.dart        ← AI 사진 인식 위젯
```

---

## 파일별 상세 설명

### `main.dart`

앱 시작 시 실행되는 파일.

| 항목 | 설명 |
|---|---|
| `notificationsPlugin` | 전역 알림 플러그인. `home_screen.dart`에서 import해서 공유 사용 |
| `main()` | 알림 플러그인 초기화 → 백그라운드 서비스 초기화 → 앱 실행 |
| `MemoPingApp` | 앱 전체 테마 설정, `HomeScreen`을 첫 화면으로 지정 |

---

### `models/memo_item.dart`

메모 1개의 데이터 구조. DB나 SharedPreferences에 저장될 때 이 형태로 변환됨.

#### `TriggerType` (enum)
```
location  → 위치 기반 알림
time      → 시간 기반 알림
```

#### `MemoItem` (class) - 주요 필드

| 필드 | 타입 | 설명 |
|---|---|---|
| `id` | String | 고유 식별자. 저장 시 `DateTime.now().millisecondsSinceEpoch.toString()` 사용 |
| `title` | String | 메모 제목 (예: "머리핀 사기") |
| `description` | String | 상세 내용 (선택 입력) |
| `triggerType` | TriggerType | 위치 or 시간 알림 구분 |
| `locationName` | String | 장소 이름 (예: "다이소", "버거킹"). **⚠️ 현재는 좌표 없이 이름만 저장됨** |
| `radius` | double | 알림 반경 (단위: 미터). 기본값 200m |
| `latitude` | double? | 위도. **⚠️ 현재 저장 방법 없음 → 항상 null** |
| `longitude` | double? | 경도. **⚠️ 현재 저장 방법 없음 → 항상 null** |
| `triggerTime` | TimeOfDay? | 시간 알림 시각 |
| `repeatDays` | List\<bool\> | 반복 요일. 인덱스 0=월 ~ 6=일 |
| `isActive` | bool | 알림 활성화 여부 (토글 가능) |

#### `MemoItem` - 주요 메서드

| 메서드 | 설명 |
|---|---|
| `triggerLabel` (getter) | 카드에 표시되는 요약 텍스트 반환. 위치면 "다이소 · 100m 이내", 시간이면 "오전 9:00 · 평일" |
| `_daysSummary` (getter) | 반복 요일을 "매일", "평일", "주말", "월, 수, 금" 형태 문자열로 반환 |
| `copyWith()` | 일부 필드만 바꿔서 새 MemoItem 반환 (수정 시 사용) |
| `toJson()` | Map으로 직렬화 (SharedPreferences 저장용) |
| `fromJson()` | Map에서 MemoItem 복원 (SharedPreferences 읽기용) |

---

### `screens/home_screen.dart`

앱 실행 시 가장 먼저 보이는 메인 화면.

#### 상태 변수

| 변수 | 설명 |
|---|---|
| `_selectedFilter` | 0=전체, 1=위치, 2=시간. 상단 필터 칩과 연동 |
| `_locationMonitor` | `LocationMonitorService` 인스턴스. 포그라운드 위치 감시 담당 |
| `_memos` | 전체 메모 목록. **⚠️ 현재는 앱 재시작 시 하드코딩된 샘플 데이터로 초기화됨 (영구 저장 미구현)** |

#### 주요 메서드

| 메서드 | 설명 |
|---|---|
| `initState()` | 화면 최초 로드 시: 위치 권한 요청 → 포그라운드/백그라운드 감시 시작 |
| `_requestLocationPermission()` | 위치 권한 요청. 거부 시 스낵바로 안내 |
| `_toggleMemo(id)` | 메모 활성/비활성 토글. 변경 후 서비스들에 목록 갱신 전달 |
| `_deleteMemo(id)` | 메모 삭제. 변경 후 서비스들에 목록 갱신 전달 |
| `_openAddMemo()` | 추가 화면으로 이동. 결과 받으면 목록 맨 앞에 추가 |
| `_openEditMemo(memo)` | 수정 화면으로 이동. 결과 받으면 기존 메모 교체 |
| `_preRequestCameraPermission()` | 추가 화면 열기 전 카메라 권한 미리 요청 |
| `_filteredMemos` (getter) | `_selectedFilter`에 따라 목록 필터링해서 반환 |
| `_activeCount` / `_locationCount` / `_timeCount` | 상단 통계 카드에 표시되는 숫자 |

#### UI 빌더 메서드

| 메서드 | 설명 |
|---|---|
| `_buildHeader()` | 상단 "메모핑 🔔" 제목 + 알림 아이콘 버튼 |
| `_buildStats()` | 파란 그라데이션 카드. 전체/위치/시간 메모 개수 표시 |
| `_buildFilterChips()` | 전체/위치알림/시간알림 필터 칩 |
| `_buildEmptyState()` | 메모가 없을 때 표시되는 안내 화면 |

---

### `screens/add_memo_screen.dart`

메모 추가 및 수정 화면. `Navigator.push`로 열리고 결과를 `Navigator.pop(context, memo)`으로 반환.

#### Props

| 파라미터 | 설명 |
|---|---|
| `initialMemo` | null이면 새 메모 추가, 값이 있으면 수정 모드 |

#### 상태 변수

| 변수 | 설명 |
|---|---|
| `_titleController` | 제목 입력 필드 컨트롤러 |
| `_descController` | 상세 내용 입력 필드 컨트롤러 |
| `_locationController` | 장소 이름 입력 필드 컨트롤러 |
| `_triggerType` | 현재 선택된 알림 방식 (위치/시간) |
| `_radius` | 선택된 반경 값 (50/100/200/500/1000m) |
| `_selectedTime` | 선택된 시간 알림 시각 |
| `_repeatDays` | 반복 요일 체크 상태 |

#### 주요 메서드

| 메서드 | 설명 |
|---|---|
| `_canSave` (getter) | 저장 가능 여부. 제목 필수 + 위치탭이면 장소명도 필수 |
| `_save()` | MemoItem 생성 후 `Navigator.pop`으로 반환 |
| `_pickTime()` | 시간 피커 다이얼로그 표시 |
| `_buildLocationFields()` | 장소 이름 입력 + 반경 슬라이더 UI |
| `_buildTimeFields()` | 시간 선택 버튼 + 요일 반복 선택 UI |

---

### `services/location_monitor_service.dart`

**포그라운드** (앱이 화면에 있는 동안) 위치 감시 서비스.

#### 멤버 변수

| 변수 | 설명 |
|---|---|
| `_positionSub` | GPS 스트림 구독 객체. `stop()` 시 취소 |
| `_notifiedIds` | 이미 알림을 보낸 메모 ID 집합. 중복 알림 방지용 |
| `_exitedIds` | 반경 밖으로 나간 메모 ID 집합. 재진입 시 재알림 허용용 |
| `_memos` | 현재 감시 중인 메모 목록 |

#### 주요 메서드

| 메서드 | 설명 |
|---|---|
| `start(memos)` | GPS 스트림 시작. 이미 실행 중이면 목록만 갱신 |
| `updateMemos(memos)` | 메모 목록 갱신 (추가/삭제/수정 시 호출) |
| `stop()` | GPS 스트림 중지 + 알림 기록 초기화 |
| `_onPosition(position)` | GPS 위치 이벤트 수신 시 모든 메모와 거리 계산 → 반경 내 진입 시 알림 |
| `_sendNotification(memo)` | 로컬 알림 발송 (채널 ID: `memo_ping_location_fg`) |

#### ⚠️ 현재 한계
`latitude`/`longitude`가 null인 메모는 감시 대상에서 제외됨. 현재 모든 메모가 좌표 없이 저장되므로 **실제로는 아무 알림도 발송되지 않음**.

---

### `services/background_location_service.dart`

**백그라운드** (앱이 꺼져 있어도) 위치 감시 서비스. `flutter_foreground_task` 패키지로 Android 포그라운드 서비스(상태바 알림 포함) 형태로 실행됨. 별도 isolate에서 실행되어 메인 앱과 메모리를 공유하지 않음.

#### 아키텍처

```
메인 앱 (메인 isolate)
│
│  saveMemos() → SharedPreferences에 JSON 저장
│  start()     → 포그라운드 서비스 시작
│
▼
_BackgroundLocationHandler (별도 isolate)
│
│  onStart()       → 알림 초기화 + 메모 로드 + GPS 스트림 시작
│  onRepeatEvent() → 30초마다 메모 목록 최신화
│  onReceiveData() → 메인 앱이 'refresh' 메시지 보내면 메모 재로드
│  _onPosition()   → 위치 이벤트마다 반경 계산 → 알림 발송
```

#### `BackgroundLocationService` (정적 클래스) - 메인 앱에서 사용

| 메서드 | 설명 |
|---|---|
| `init()` | 앱 시작 시 1회. 서비스 설정값 초기화 (채널 이름, 반복 주기 등) |
| `start(memos)` | 메모 저장 후 서비스 시작. 이미 실행 중이면 메모만 갱신 |
| `saveMemos(memos)` | 메모를 JSON으로 인코딩 → SharedPreferences 저장 → 실행 중 서비스에 갱신 요청 |
| `stop()` | 서비스 중지 |
| `isRunning` | 현재 서비스 실행 여부 반환 |

---

### `widgets/memo_card.dart`

메모 목록에서 메모 1개를 표시하는 카드 위젯.

| Props | 설명 |
|---|---|
| `item` | 표시할 MemoItem |
| `onToggle` | 토글 스위치 변경 시 콜백 |
| `onTap` | 카드 탭 시 콜백 (수정 화면 열기) |
| `onDelete` | 좌→우 스와이프 삭제 시 콜백 |

- `Dismissible` 위젯으로 오른쪽 스와이프 삭제 구현
- `isActive`가 false면 `opacity 0.5` + 취소선 표시
- 위치 알림: 청록색(`#26C6DA`) / 시간 알림: 주황색(`#FF8A65`)

---

### `widgets/photo_label_picker.dart`

메모 추가 화면에서 사진을 찍거나 갤러리에서 선택하면 AI가 물건을 인식하여 메모 제목 후보를 제안하는 위젯.

#### 동작 흐름
```
사진 선택 (카메라/갤러리)
    ↓
Flask 서버(tools/server.py)에 이미지 POST
    ↓
서버: CLIP 모델 → 물건 라벨 인식
     BLIP 모델 → 신뢰도 낮을 때 캡셔닝 폴백
     OCR       → 텍스트 인식
    ↓
결과 수신: labels(최대 3개) + ocr_texts(최대 8개)
    ↓
한국어 변환(_kLabelMap) → 칩 형태로 표시
    ↓
유저가 칩 탭 → onLabelSelected 콜백으로 제목 필드에 자동 입력
```

#### 주요 멤버

| 항목 | 설명 |
|---|---|
| `_apiBaseUrl` | Android 에뮬레이터: `10.0.2.2:5000`, 그 외: `localhost:5000` |
| `_kLabelMap` | 영문 ML 레이블 → 한국어 변환 맵 (~200개 항목) |
| `_toKorean(label)` | 레이블을 한국어로 변환. 대소문자 무시, 없으면 영문 그대로 반환 |
| `_analyzeWithFlask(file)` | 이미지 파일을 Flask 서버에 multipart POST → JSON 응답 반환 |
| `_ensurePermission(source)` | 카메라 선택 시 권한 확인/요청. 거부 시 설정 안내 |
| `_pickAndAnalyze(source)` | 이미지 선택 → 서버 분석 → 결과 상태 업데이트 |
| `_showSourcePicker()` | 카메라 or 갤러리 선택 바텀시트 표시 |

---

## 데이터 흐름 요약

```
[사용자 입력]
    ↓
add_memo_screen.dart: MemoItem 생성
    ↓ Navigator.pop(memo)
home_screen.dart: _memos 리스트에 추가
    ↓
location_monitor_service.updateMemos()   ← 포그라운드 감시 갱신
BackgroundLocationService.saveMemos()    ← SharedPreferences 저장 + 백그라운드 서비스 갱신
```

---

## ⚠️ 현재 미구현 / 알려진 문제

| 문제 | 위치 | 설명 |
|---|---|---|
| 메모 영구 저장 안 됨 | `home_screen.dart` | `_memos`가 메모리에만 있어 앱 재시작 시 초기화됨. SharedPreferences 연동 필요 |
| 위치 알림 실제 동작 안 함 | `memo_item.dart` | `latitude`/`longitude`가 항상 null. Kakao/Google POI API 연동 필요 |
| 백그라운드 서비스에 메모 잘 안 전달됨 | `background_location_service.dart` | 위와 같은 이유로 좌표 없으면 실제 알림 없음 |
| geofence_manager.dart | `services/` | 내용 없음. 재설계 예정 파일 |

---

## 주요 패키지

| 패키지 | 용도 |
|---|---|
| `geolocator` | GPS 위치 조회, 거리 계산 |
| `flutter_local_notifications` | 로컬 푸시 알림 발송 |
| `flutter_foreground_task` | 백그라운드 포그라운드 서비스 (Android) |
| `permission_handler` | 위치/카메라 권한 요청 |
| `image_picker` | 카메라/갤러리 이미지 선택 |
| `http` | Flask 서버 API 호출 |
