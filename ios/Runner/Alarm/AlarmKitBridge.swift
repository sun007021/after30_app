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
/// - **실기기 검증 필요(문서화)**: `LiveActivityIntent.perform()`이 앱이
///   완전히 종료된 상태에서도 (별도 익스텐션 타깃 없이) 메인 앱 번들
///   프로세스에서 실행되어 `UserDefaults.standard`를 공유한다는 전제로
///   구현했다. 시뮬레이터에서는 알림 자체를 사람이 탭할 수 없어 이 경로를
///   자동 검증할 수 없다 — PR의 실기기 체크리스트 참고.
enum AlarmKitBridge {
  static let channelName = "after30/alarmkit"

  private static let recordsKey = "alarmkit_records_v1"
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
      result(authorizationStatusString())

    case "requestAuthorization":
      Task {
        result(await requestAuthorizationString())
      }

    case "schedule":
      guard let args = call.arguments as? [String: Any] else {
        result(false)
        return
      }
      Task {
        result(await scheduleAlarm(args: args))
      }

    case "cancel":
      guard let args = call.arguments as? [String: Any],
        let scheduleId = args["scheduleId"] as? String
      else {
        result(false)
        return
      }
      result(cancelAlarm(scheduleId: scheduleId))

    case "cancelAll":
      result(cancelAllAlarms())

    case "list":
      result(listAlarms())

    case "alertingAlarm":
      result(alertingAlarm())

    case "drainCompletions":
      result(drainPendingCompletions())

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - 권한

  private static func authorizationStatusString() -> String {
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

  // MARK: - 스케줄링

  private static func scheduleAlarm(args: [String: Any]) async -> Bool {
    guard #available(iOS 26.0, *) else { return false }
    guard
      let scheduleId = args["scheduleId"] as? String,
      let medicineName = args["medicineName"] as? String,
      let days = args["days"] as? [String],
      let timesArg = args["times"] as? [[String: Any]]
    else { return false }

    let weekdays = days.compactMap(isoToWeekday)
    guard !weekdays.isEmpty, !timesArg.isEmpty else { return false }

    var records = loadRecords()

    // 더 이상 요청되지 않는 시간대(사용자가 시간을 삭제한 경우)는 취소한다.
    let requestedKeys = Set(
      timesArg.compactMap { entry -> String? in
        guard let h = entry["hour"] as? Int, let m = entry["minute"] as? Int else { return nil }
        return recordKey(scheduleId: scheduleId, hour: h, minute: m)
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
      let key = recordKey(scheduleId: scheduleId, hour: hour, minute: minute)
      let uuid = records[key].flatMap { UUID(uuidString: $0.alarmUUID) } ?? UUID()

      let metadata = MedicationAlarmMetadata(scheduleId: scheduleId, medicineName: medicineName)
      let stopButton = AlarmButton(text: "정지", textColor: .white, systemImageName: "stop.fill")
      let secondaryButton = AlarmButton(
        text: "복용 완료", textColor: .white, systemImageName: "checkmark.circle")
      let alert = AlarmPresentation.Alert(
        title: LocalizedStringResource(stringLiteral: "\(medicineName) 복용 시간입니다"),
        stopButton: stopButton,
        secondaryButton: secondaryButton,
        secondaryButtonBehavior: .custom
      )
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
      } catch {
        print("AlarmKit 스케줄링 실패: \(error)")
        saveRecords(records)
        return false
      }
    }

    saveRecords(records)
    return true
  }

  private static func cancelAlarm(scheduleId: String) -> Bool {
    guard #available(iOS 26.0, *) else { return false }
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

  private static func cancelAllAlarms() -> Bool {
    guard #available(iOS 26.0, *) else { return false }
    let records = loadRecords()
    for record in records.values {
      if let uuid = UUID(uuidString: record.alarmUUID) {
        try? AlarmManager.shared.cancel(id: uuid)
      }
    }
    saveRecords([:])
    return true
  }

  private static func listAlarms() -> [[String: Any]] {
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
  private static func alertingAlarm() -> [String: Any]? {
    guard #available(iOS 26.0, *) else { return nil }
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
      "day": koreanWeekday(for: Date()),
    ]
  }

  // MARK: - "복용 완료" 완료 기록(백그라운드 LiveActivityIntent → Dart 폴링)

  fileprivate static func recordCompletion(scheduleId: String, medicineName: String, hour: Int, minute: Int) {
    var pending = loadPendingCompletions()
    pending.append(
      PendingCompletion(
        scheduleId: scheduleId,
        medicineName: medicineName,
        day: koreanWeekday(for: Date()),
        hour: hour,
        minute: minute
      )
    )
    savePendingCompletions(pending)
  }

  private static func drainPendingCompletions() -> [[String: Any]] {
    let pending = loadPendingCompletions()
    savePendingCompletions([])
    return pending.map {
      [
        "scheduleId": $0.scheduleId,
        "medicineName": $0.medicineName,
        "day": $0.day,
        "hour": $0.hour,
        "minute": $0.minute,
      ]
    }
  }

  // MARK: - 영속화

  private static func recordKey(scheduleId: String, hour: Int, minute: Int) -> String {
    "\(scheduleId)#\(hour):\(minute)"
  }

  private static func loadRecords() -> [String: AlarmRecord] {
    guard let data = UserDefaults.standard.data(forKey: recordsKey) else { return [:] }
    return (try? JSONDecoder().decode([String: AlarmRecord].self, from: data)) ?? [:]
  }

  private static func saveRecords(_ records: [String: AlarmRecord]) {
    guard let data = try? JSONEncoder().encode(records) else { return }
    UserDefaults.standard.set(data, forKey: recordsKey)
  }

  private static func loadPendingCompletions() -> [PendingCompletion] {
    guard let data = UserDefaults.standard.data(forKey: pendingCompletionsKey) else { return [] }
    return (try? JSONDecoder().decode([PendingCompletion].self, from: data)) ?? []
  }

  private static func savePendingCompletions(_ completions: [PendingCompletion]) {
    guard let data = try? JSONEncoder().encode(completions) else { return }
    UserDefaults.standard.set(data, forKey: pendingCompletionsKey)
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

  private static func koreanWeekday(for date: Date) -> String {
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
  var scheduleId: String
  var medicineName: String
  var day: String
  var hour: Int
  var minute: Int
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
