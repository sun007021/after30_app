class MemberMedicationSummary {
  final int userId;
  final String? userName;
  final int totalScheduled;
  final int takenCount;
  final int pendingCount;
  final int missedCount;
  final int cancelledCount;
  final double complianceRate;

  MemberMedicationSummary({
    required this.userId,
    this.userName,
    required this.totalScheduled,
    required this.takenCount,
    required this.pendingCount,
    required this.missedCount,
    this.cancelledCount = 0,
    required this.complianceRate,
  });

  factory MemberMedicationSummary.fromJson(Map<String, dynamic> json) {
    return MemberMedicationSummary(
      userId: json['user_id'] as int,
      userName: json['user_name'] as String?,
      totalScheduled: json['total_scheduled'] as int,
      takenCount: json['taken_count'] as int,
      pendingCount: json['pending_count'] as int,
      missedCount: json['missed_count'] as int,
      cancelledCount: (json['cancelled_count'] as num?)?.toInt() ?? 0,
      complianceRate: (json['compliance_rate'] as num).toDouble(),
    );
  }

  /// 게이지용 진행률 (0.0 ~ 1.0) — 당일 복용 완료 / 예정
  double get progress =>
      totalScheduled > 0 ? (takenCount / totalScheduled).clamp(0.0, 1.0) : 0.0;
}

class FamilyDashboard {
  final int groupId;
  final String groupName;
  final DateTime date;
  final List<MemberMedicationSummary> membersSummary;

  FamilyDashboard({
    required this.groupId,
    required this.groupName,
    required this.date,
    required this.membersSummary,
  });

  factory FamilyDashboard.fromJson(Map<String, dynamic> json) {
    final members = (json['members_summary'] as List? ?? const [])
        .map(
          (item) => MemberMedicationSummary.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    return FamilyDashboard(
      groupId: json['group_id'] as int,
      groupName: json['group_name'] as String,
      date: DateTime.parse(json['date'] as String),
      membersSummary: members,
    );
  }

  MemberMedicationSummary? summaryFor(int userId) {
    for (final summary in membersSummary) {
      if (summary.userId == userId) return summary;
    }
    return null;
  }
}

/// 홈 화면용 — 모든 그룹의 가족 멤버 복약 현황 (`GET /families/dashboard`)
class HomeDashboard {
  final DateTime date;
  final List<MemberMedicationSummary> membersSummary;

  HomeDashboard({
    required this.date,
    required this.membersSummary,
  });

  factory HomeDashboard.fromJson(Map<String, dynamic> json) {
    final members = (json['members_summary'] as List? ?? const [])
        .map(
          (item) => MemberMedicationSummary.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    return HomeDashboard(
      date: DateTime.parse(json['date'] as String),
      membersSummary: members,
    );
  }
}
