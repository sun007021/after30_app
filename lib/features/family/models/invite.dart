enum InviteStatus { SENT, ACCEPTED, DECLINED, EXPIRED }

enum InviteChannel { PUSH, INSTALL_LINK }

class Invite {
  final String id;
  final String phone;
  final String inviterId;
  final DateTime createdAt;
  final InviteStatus status;
  final InviteChannel channel;
  final String idempotencyKey;

  Invite({
    required this.id,
    required this.phone,
    required this.inviterId,
    required this.createdAt,
    required this.status,
    required this.channel,
    required this.idempotencyKey,
  });

  factory Invite.fromJson(Map<String, dynamic> json) {
    return Invite(
      id: json['id'],
      phone: json['phone'],
      inviterId: json['inviterId'],
      createdAt: DateTime.parse(json['createdAt']),
      status: InviteStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
      ),
      channel: InviteChannel.values.firstWhere(
        (e) => e.toString().split('.').last == json['channel'],
      ),
      idempotencyKey: json['idempotencyKey'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'inviterId': inviterId,
      'createdAt': createdAt.toIso8601String(),
      'status': status.toString().split('.').last,
      'channel': channel.toString().split('.').last,
      'idempotencyKey': idempotencyKey,
    };
  }

  Invite copyWith({
    String? id,
    String? phone,
    String? inviterId,
    DateTime? createdAt,
    InviteStatus? status,
    InviteChannel? channel,
    String? idempotencyKey,
  }) {
    return Invite(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      inviterId: inviterId ?? this.inviterId,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      channel: channel ?? this.channel,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }
}

class InviteResult {
  final String type; // 'REGISTERED_USER' or 'NOT_REGISTERED'
  final Invite? invite;
  final String message;

  InviteResult({required this.type, this.invite, required this.message});
}

enum InviteErrorType {
  INVALID_PHONE,
  DUPLICATE_INVITE,
  ALREADY_FAMILY,
  SELF_INVITE,
  RATE_LIMITED,
}

class InviteError {
  final InviteErrorType type;
  final String message;

  InviteError({required this.type, required this.message});
}

