import Foundation
import Flutter
import SwiftUI
import AppIntents
#if canImport(AlarmKit)
import AlarmKit
#endif

/// iOS 26+ AlarmKit 브리지(plan §6 W4 3a). `after30/alarmkit` MethodChannel로
/// Dart의 `AlarmKitReminderScheduler`와 통신한다.
///
/// - 앱 배포 타깃은 iOS 16.0이므로 AlarmKit 관련 심볼은 전부
///   `if #available(iOS 26.0, *)`로 감싼다. iOS 26 미만에서는
///   `authorizationStatus`가 `"notSupported"`를 반환하고, Dart 쪽
///   `ReminderSchedulerSelector`가 이를 보고 로컬 알림(fallback)으로 전환한다.
/// - 하나의 복약 스케줄(요일 여러 개 + 시간 여러 개)은 "시간마다 AlarmKit
///   알람 1건"으로 매핑한다. AlarmKit의 `Alarm.Schedule.relative`가
///   `Recurrence.weekly([Weekday])`로 여러 요일을 한 번에 표현할 수 있어서,
///   Android/로컬 알림처럼 요일마다 별도 항목을 만들 필요가 없다(64개
///   pending 제한과 무관 — AlarmKit은 OS가 직접 관리하는 진짜 알람이다).
/// - "복용 완료" 보조 버튼은 `LiveActivityIntent`로 구현한다. 이 프로토콜의
///   인텐트는 앱을 포그라운드로 가져오지 않고 백그라운드에서 실행되도록
///   설계돼 있어, 기존 로컬 알림의 "복용 완료 = SilentAction(백그라운드)"
///   패턴과 동작이 일치한다(plan §6 W4 3b — "AlarmKit이 안정적으로
///   지원하는 방식"으로 이 쪽을 선택했다). 반대로 알림 본문(알럿)을 직접
///   탭해 앱을 여는 경우는 시스템이 앱을 포그라운드로 가져오므로, 그때는
///   `alertingAlarm()`으로 현재 울리고 있는 알람을 조회해 풀스크린 페이지로
///   라우팅한다(콜드 스타트 포함).
/// - 모든 읽기/쓰기(스케줄/취소/전체취소)는 `AlarmKitWorker` 액터를 거쳐
///   직렬화한다(리뷰 M3) — Dart 쪽에서 동시에 여러 요청이 들어와도(예:
///   포그라운드 복귀 재계산과 알람 추가가 겹치는 경우) `load → schedule →
///   save`가 원자적으로 실행돼 UUID가 중복 생성되지 않는다.
/// - **실기기 검증 필요(문서화)**: `LiveActivityIntent.perform()`이 앱이
///   완전히 종료된 상태에서도 (별도 익스텐션 타깃 없이) 메인 앱 번들
///   프로세스에서 실행되어 `UserDefaults.standard`를 공유한다는 전제로
///   구현했다. 시뮬레이터에서는 알림 자체를 사람이 탭할 수 없어 이 경로를
///   자동 검증할 수 없다 — PR의 실기기 체크리스트 참고.
enum AlarmKitBridge {
  static let channelName = "after30/alarmkit"

  // `AlarmKitWorker`(iOS 26 전용 actor) 안에 있으면 이 값을 읽는
  // `peek`/`ackCompletion`(iOS 버전 가드가 없는 코드)에서 "iOS 26
  // 이상에서만 쓸 수 있다"는 컴파일 에러가 난다 — 문자열 상수일 뿐
  // iOS 26 API가 아니므로 여기 최상위로 옮겼다.
  private static let pendingCompletionsKey = "alarmkit_pending_completions_v1"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { call, result in
      handle(call: call, result: result)
    }
  }

  private static func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "authorizationStatus":
      Task { @MainActor in
        result(await authorizationStatusString())
      }

    case "requestAuthorization":
      Task { @MainActor in
        result(await requestAuthorizationString())
      }

    case "schedule":
      guard let args = call.arguments as? [String: Any] else {
        result(false)
        return
      }
      Task { @MainActor in
        result(await scheduleAlarm(args: args))
      }

    case "cancel":
      guard let args = call.arguments as? [String: Any],
        let scheduleId = args["scheduleId"] as? String
      else {
        result(false)
        return
      }
      Task { @MainActor in
        result(await cancelAlarm(scheduleId: scheduleId))
      }

    case "cancelAll":
      Task { @MainActor in
        result(await cancelAllAlarms())
      }

    case "list":
      Task { @MainActor in
        result(await listAlarms())
      }

    case "alertingAlarm":
      Task { @MainActor in
        result(await alertingAlarm())
      }

    case "peekCompletions":
      result(peekPendingCompletions())

    case "ackCompletion":
      guard let args = call.arguments as? [String: Any], let id = args["id"] as? String else {
        result(false)
        return
      }
      result(ackPendingCompletion(id: id))

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - 권한(액터 상태를 건드리지 않으므로 직접 호출)

  private static func authorizationStatusString() async -> String {
    guard #available(iOS 26.0, *) else { return "notSupported" }
    return mapAuthorizationState(AlarmManager.shared.authorizationState)
  }

  private static func requestAuthorizationString() async -> String {
    guard #available(iOS 26.0, *) else { return "notSupported" }
    do {
      let state = try await AlarmManager.shared.requestAuthorization()
      return mapAuthorizationState(state)
    } catch {
      return "denied"
    }
  }

  @available(iOS 26.0, *)
  private static func mapAuthorizationState(_ state: AlarmManager.AuthorizationState) -> String {
    switch state {
    case .notDetermined: return "notDetermined"
    case .denied: return "denied"
    case .authorized: return "authorized"
    @unknown default: return "notDetermined"
    }
  }

  // MARK: - 스케줄링(AlarmKitWorker 액터로 위임 — 직렬화)

  private static func scheduleAlarm(args: [String: Any]) async -> Bool {
    guard #available(iOS 26.0, *) else { return false }
    return await AlarmKitWorker.shared.schedule(args: args)
  }

  private static func cancelAlarm(scheduleId: String) async -> Bool {
    guard #available(iOS 26.0, *) else { return false }
    return await AlarmKitWorker.shared.cancel(scheduleId: scheduleId)
  }

  private static func cancelAllAlarms() async -> Bool {
    guard #available(iOS 26.0, *) else { return false }
    return await AlarmKitWorker.shared.cancelAll()
  }

  private static func listAlarms() async -> [[String: Any]] {
    guard #available(iOS 26.0, *) else { return [] }
    return await AlarmKitWorker.shared.list()
  }

  private static func alertingAlarm() async -> [String: Any]? {
    guard #available(iOS 26.0, *) else { return nil }
    return await AlarmKitWorker.shared.alertingAlarm()
  }

  // MARK: - "복용 완료" 완료 기록(백그라운드 LiveActivityIntent → Dart 폴링)
  //
  // 리뷰 M8: 성공적으로 서버에 반영되기 전까지는 기록을 지우지 않는다(오프라인
  // 등으로 실패하면 다음 폴링 때 다시 시도할 수 있어야 한다) — 그래서
  // "전부 꺼내고 비우는" drain 대신 "읽기만 하는" peek + "성공한 것만 지우는"
  // ack로 나눴다. 각 기록에 실제 탭 시각(`timestampMs`)을 남겨, 자정을 넘겨
  // 처리되더라도 Dart 쪽이 올바른 날짜로 복용 완료를 기록할 수 있게 한다.

  fileprivate static func recordCompletion(scheduleId: String, medicineName: String, hour: Int, minute: Int) {
    var pending = loadPendingCompletions()
    pending.append(
      PendingCompletion(
        id: UUID().uuidString,
        scheduleId: scheduleId,
        medicineName: medicineName,
        hour: hour,
        minute: minute,
        timestampMs: Int64(Date().timeIntervalSince1970 * 1000)
      )
    )
    savePendingCompletions(pending)
  }

  private static func peekPendingCompletions() -> [[String: Any]] {
    loadPendingCompletions().map {
      [
        "id": $0.id,
        "scheduleId": $0.scheduleId,
        "medicineName": $0.medicineName,
        "hour": $0.hour,
        "minute": $0.minute,
        "timestampMs": $0.timestampMs,
      ]
    }
  }

  private static func ackPendingCompletion(id: String) -> Bool {
    var pending = loadPendingCompletions()
    let originalCount = pending.count
    pending.removeAll { $0.id == id }
    savePendingCompletions(pending)
    return pending.count < originalCount
  }

  private static func loadPendingCompletions() -> [PendingCompletion] {
    guard let data = UserDefaults.standard.data(forKey: pendingCompletionsKey) else {
      return []
    }
    return (try? JSONDecoder().decode([PendingCompletion].self, from: data)) ?? []
  }

  private static func savePendingCompletions(_ completions: [PendingCompletion]) {
    guard let data = try? JSONEncoder().encode(completions) else { return }
    UserDefaults.standard.set(data, forKey: pendingCompletionsKey)
  }
}

/// AlarmKit 등록/취소를 직렬화하는 액터(리뷰 M3). Dart 쪽 `MethodChannel`
/// 호출은 여러 개가 겹칠 수 있는데(예: 포그라운드 복귀 재계산과 새 알람
/// 등록), 이 워커를 거치지 않고 `loadRecords → schedule → saveRecords`를
/// 직접 실행하면 두 호출이 서로의 저장 결과를 덮어써 UUID가 중복
/// 생성되거나 기록이 누락될 수 있다. 액터는 한 번에 하나의 메서드만
/// 실행되도록 보장한다.
@available(iOS 26.0, *)
actor AlarmKitWorker {
  static let shared = AlarmKitWorker()
  static let recordsKey = "alarmkit_records_v1"

  private init() {}

  func schedule(args: [String: Any]) async -> Bool {
    guard
      let scheduleId = args["scheduleId"] as? String,
      let medicineName = args["medicineName"] as? String,
      let days = args["days"] as? [String],
      let timesArg = args["times"] as? [[String: Any]]
    else { return false }

    let weekdays = days.compactMap(Self.isoToWeekday)
    guard !weekdays.isEmpty, !timesArg.isEmpty else { return false }

    var records = loadRecords()

    // 더 이상 요청되지 않는 시간대(사용자가 시간을 삭제한 경우)는 취소한다.
    let requestedKeys = Set(
      timesArg.compactMap { entry -> String? in
        guard let h = entry["hour"] as? Int, let m = entry["minute"] as? Int else { return nil }
        return Self.recordKey(scheduleId: scheduleId, hour: h, minute: m)
      }
    )
    for (key, record) in records where record.scheduleId == scheduleId && !requestedKeys.contains(key) {
      if let uuid = UUID(uuidString: record.alarmUUID) {
        try? AlarmManager.shared.cancel(id: uuid)
      }
      records.removeValue(forKey: key)
    }

    for entry in timesArg {
      guard let hour = entry["hour"] as? Int, let minute = entry["minute"] as? Int else { continue }
      let key = Self.recordKey(scheduleId: scheduleId, hour: hour, minute: minute)

      // 이미 등록된 알람을 고치는 경우(m3): 같은 UUID로 바로
      // schedule()을 다시 호출하지 않고, 먼저 취소한 뒤 새로 등록한다.
      let existingUUID = records[key].flatMap { UUID(uuidString: $0.alarmUUID) }
      if let existingUUID {
        try? AlarmManager.shared.cancel(id: existingUUID)
      }
      let uuid = existingUUID ?? UUID()

      let metadata = MedicationAlarmMetadata(scheduleId: scheduleId, medicineName: medicineName)
      let stopButton = AlarmButton(text: "정지", textColor: .white, systemImageName: "stop.fill")
      let secondaryButton = AlarmButton(
        text: "복용 완료", textColor: .white, systemImageName: "checkmark.circle")
      let alert: AlarmPresentation.Alert
      if #available(iOS 26.1, *) {
        alert = AlarmPresentation.Alert(
          title: LocalizedStringResource(stringLiteral: "\(medicineName) 복용 시간입니다"),
          secondaryButton: secondaryButton,
          secondaryButtonBehavior: .custom
        )
      } else {
        alert = AlarmPresentation.Alert(
          title: LocalizedStringResource(stringLiteral: "\(medicineName) 복용 시간입니다"),
          stopButton: stopButton,
          secondaryButton: secondaryButton,
          secondaryButtonBehavior: .custom
        )
      }
      let attributes = AlarmAttributes<MedicationAlarmMetadata>(
        presentation: AlarmPresentation(alert: alert),
        metadata: metadata,
        tintColor: Color.blue
      )
      let secondaryIntent = MarkMedicationTakenIntent(
        scheduleId: scheduleId, medicineName: medicineName, hour: hour, minute: minute)
      let schedule = Alarm.Schedule.relative(
        .init(
          time: .init(hour: hour, minute: minute),
          repeats: .weekly(weekdays)
        )
      )
      let configuration = AlarmManager.AlarmConfiguration<MedicationAlarmMetadata>.alarm(
        schedule: schedule,
        attributes: attributes,
        secondaryIntent: secondaryIntent
      )

      do {
        let alarm = try await AlarmManager.shared.schedule(id: uuid, configuration: configuration)
        records[key] = AlarmRecord(
          scheduleId: scheduleId,
          medicineName: medicineName,
          days: days,
          hour: hour,
          minute: minute,
          alarmUUID: alarm.id.uuidString
        )
      } catch AlarmManager.AlarmError.maximumLimitReached {
        // m3: AlarmKit 자체 한도 초과 — 이 항목만 건너뛰고 나머지는
        // 계속 시도한다. Dart 쪽에 개별 실패를 알리는 채널은 아직 없어
        // 최소한 로그로 남긴다(실기기에서 발생 시 로컬 알림 fallback으로
        // 전환하는 방안을 후속 작업으로 검토).
        print("AlarmKit 최대 알람 개수 초과: \(key)")
        continue
      } catch {
        print("AlarmKit 스케줄링 실패: \(error)")
        saveRecords(records)
        return false
      }
    }

    saveRecords(records)
    return true
  }

  func cancel(scheduleId: String) -> Bool {
    var records = loadRecords()
    var didCancel = false
    for (key, record) in records where record.scheduleId == scheduleId {
      if let uuid = UUID(uuidString: record.alarmUUID) {
        try? AlarmManager.shared.cancel(id: uuid)
        didCancel = true
      }
      records.removeValue(forKey: key)
    }
    saveRecords(records)
    return didCancel
  }

  /// 우리 기록뿐 아니라 `AlarmManager.shared.alarms`에 실제로 남아 있는
  /// 알람을 전부 순회해 취소한다(리뷰 M3) — 기록이 드리프트해도(예: 과거
  /// 버그로 기록되지 않은 알람이 있어도) 실제 시스템 상태를 기준으로
  /// 정리한다.
  func cancelAll() -> Bool {
    if let systemAlarms = try? AlarmManager.shared.alarms {
      for alarm in systemAlarms {
        try? AlarmManager.shared.cancel(id: alarm.id)
      }
    }
    saveRecords([:])
    return true
  }

  func list() -> [[String: Any]] {
    loadRecords().values.map { record in
      [
        "scheduleId": record.scheduleId,
        "medicineName": record.medicineName,
        "days": record.days,
        "hour": record.hour,
        "minute": record.minute,
      ]
    }
  }

  /// 지금 울리고 있는(state == .alerting) AlarmKit 알람을 우리 기록과
  /// 대조해 반환한다. 알림 본문 탭(콜드 스타트 포함) 라우팅에 쓴다.
  func alertingAlarm() -> [String: Any]? {
    guard let alarms = try? AlarmManager.shared.alarms else { return nil }
    guard let alerting = alarms.first(where: { $0.state == .alerting }) else { return nil }
    let records = loadRecords()
    guard let record = records.values.first(where: { $0.alarmUUID == alerting.id.uuidString })
    else { return nil }
    return [
      "scheduleId": record.scheduleId,
      "medicineName": record.medicineName,
      "hour": record.hour,
      "minute": record.minute,
      "day": Self.koreanWeekday(for: Date()),
    ]
  }

  private func loadRecords() -> [String: AlarmRecord] {
    guard let data = UserDefaults.standard.data(forKey: Self.recordsKey) else { return [:] }
    return (try? JSONDecoder().decode([String: AlarmRecord].self, from: data)) ?? [:]
  }

  private func saveRecords(_ records: [String: AlarmRecord]) {
    guard let data = try? JSONEncoder().encode(records) else { return }
    UserDefaults.standard.set(data, forKey: Self.recordsKey)
  }

  private static func recordKey(scheduleId: String, hour: Int, minute: Int) -> String {
    "\(scheduleId)#\(hour):\(minute)"
  }

  private static func isoToWeekday(_ iso: String) -> Locale.Weekday? {
    switch iso.uppercased() {
    case "MON": return .monday
    case "TUE": return .tuesday
    case "WED": return .wednesday
    case "THU": return .thursday
    case "FRI": return .friday
    case "SAT": return .saturday
    case "SUN": return .sunday
    default: return nil
    }
  }

  fileprivate static func koreanWeekday(for date: Date) -> String {
    // Foundation Calendar.component(.weekday): 1=일 ... 7=토
    let weekday = Calendar.current.component(.weekday, from: date)
    let map = ["", "일", "월", "화", "수", "목", "금", "토"]
    return map[weekday]
  }
}

private struct AlarmRecord: Codable {
  var scheduleId: String
  var medicineName: String
  var days: [String]
  var hour: Int
  var minute: Int
  var alarmUUID: String
}

private struct PendingCompletion: Codable {
  var id: String
  var scheduleId: String
  var medicineName: String
  var hour: Int
  var minute: Int
  var timestampMs: Int64
}

/// AlarmKit 알람에 붙이는 메타데이터(약 이름 등). `Decodable, Encodable,
/// Hashable, Sendable`은 저장 프로퍼티가 모두 값 타입이라 자동 합성된다.
@available(iOS 26.0, *)
private struct MedicationAlarmMetadata: AlarmMetadata {
  let scheduleId: String
  let medicineName: String
}

/// "복용 완료" 보조 버튼용 앱 인텐트. `LiveActivityIntent`는 앱을
/// 포그라운드로 전환하지 않고 백그라운드에서 실행되도록 설계돼 있어
/// 기존 로컬 알림의 SilentAction(복용 완료) 동작과 일치한다.
///
/// 별도 App Extension 타깃 없이 메인 앱 타깃 안에 정의했다 — 스파이크
/// 결과 이 방식으로 컴파일/링크된다(PR 참고). 단, 앱이 완전히 종료된
/// 상태에서 이 `perform()`이 실제로 실행되는지는 시뮬레이터로 검증할
/// 방법이 없어 실기기 체크리스트 항목으로 남겨둔다.
@available(iOS 26.0, *)
struct MarkMedicationTakenIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "복용 완료"
  // m6: Shortcuts/Spotlight 등에 사용자가 직접 찾아 실행할 수 있는
  // 인텐트로 노출되지 않게 한다(알람 버튼 전용).
  static var isDiscoverable: Bool = false

  @Parameter(title: "scheduleId")
  var scheduleId: String

  @Parameter(title: "medicineName")
  var medicineName: String

  @Parameter(title: "hour")
  var hour: Int

  @Parameter(title: "minute")
  var minute: Int

  init() {
    self.scheduleId = ""
    self.medicineName = ""
    self.hour = 0
    self.minute = 0
  }

  init(scheduleId: String, medicineName: String, hour: Int, minute: Int) {
    self.scheduleId = scheduleId
    self.medicineName = medicineName
    self.hour = hour
    self.minute = minute
  }

  func perform() async throws -> some IntentResult {
    AlarmKitBridge.recordCompletion(
      scheduleId: scheduleId, medicineName: medicineName, hour: hour, minute: minute)
    return .result()
  }
}
