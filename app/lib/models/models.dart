import 'package:flutter/material.dart';

import '../core/format.dart';

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String _string(Object? value) => value?.toString() ?? '';

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

/// How a call is shown in the UI, derived from direction + status.
enum CallDirection { incoming, outgoing, missed }

extension CallDirectionX on CallDirection {
  String get label => switch (this) {
    CallDirection.incoming => 'Incoming',
    CallDirection.outgoing => 'Outgoing',
    CallDirection.missed => 'Missed',
  };

  IconData get icon => switch (this) {
    CallDirection.incoming => Icons.call_received,
    CallDirection.outgoing => Icons.call_made,
    CallDirection.missed => Icons.call_missed,
  };
}

enum MessageStatus { queued, sent, delivered, failed, received }

extension MessageStatusX on MessageStatus {
  String get label => switch (this) {
    MessageStatus.queued => 'Queued',
    MessageStatus.sent => 'Sent',
    MessageStatus.delivered => 'Delivered',
    MessageStatus.failed => 'Not delivered',
    MessageStatus.received => 'Received',
  };

  static MessageStatus parse(Object? value) => switch (_string(value)) {
    'queued' => MessageStatus.queued,
    'delivered' => MessageStatus.delivered,
    'failed' => MessageStatus.failed,
    'received' => MessageStatus.received,
    _ => MessageStatus.sent,
  };
}

@immutable
class AppUser {
  const AppUser({required this.id, required this.name, required this.email});

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: _string(json['id']),
    name: _string(json['name']),
    email: _string(json['email']),
  );

  final String id;
  final String name;
  final String email;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};

  /// First name only, for the "Good Morning, Alex" greeting.
  String get firstName => name.trim().split(RegExp(r'\s+')).first;
}

/// The Twilio number the admin assigned to this account.
@immutable
class AssignedNumber {
  const AssignedNumber({
    required this.id,
    required this.phoneNumber,
    required this.friendlyName,
    required this.voice,
    required this.sms,
    required this.mms,
  });

  factory AssignedNumber.fromJson(Map<String, dynamic> json) {
    final capabilities = json['capabilities'];
    final map = capabilities is Map ? capabilities : const {};
    return AssignedNumber(
      id: _string(json['id']),
      phoneNumber: _string(json['phoneNumber']),
      friendlyName: _string(json['friendlyName']),
      voice: map['voice'] == true,
      sms: map['sms'] == true,
      mms: map['mms'] == true,
    );
  }

  final String id;
  final String phoneNumber;
  final String friendlyName;
  final bool voice;
  final bool sms;
  final bool mms;

  String get formatted => formatPhoneNumber(phoneNumber);

  Map<String, dynamic> toJson() => {
    'id': id,
    'phoneNumber': phoneNumber,
    'friendlyName': friendlyName,
    'capabilities': {'voice': voice, 'sms': sms, 'mms': mms},
  };
}

@immutable
class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.phone,
    this.role = '',
    this.numberLabel = 'Mobile',
  });

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    id: _string(json['id']),
    name: _string(json['name']),
    phone: _string(json['phone']),
    role: _string(json['role']),
    numberLabel: _string(json['label']).isEmpty
        ? 'Mobile'
        : _string(json['label']),
  );

  final String id;
  final String name;
  final String phone;
  final String role;
  final String numberLabel;

  String get formattedPhone => formatPhoneNumber(phone);
}

@immutable
class CallRecord {
  const CallRecord({
    required this.id,
    required this.from,
    required this.to,
    required this.contactName,
    required this.direction,
    required this.status,
    required this.durationSec,
    required this.startedAt,
  });

  factory CallRecord.fromJson(Map<String, dynamic> json) => CallRecord(
    id: _string(json['id']),
    from: _string(json['from']),
    to: _string(json['to']),
    contactName: _string(json['contactName']),
    direction: _string(json['direction']),
    status: _string(json['status']),
    durationSec: _int(json['durationSec']),
    startedAt: _parseDate(json['startedAt']),
  );

  final String id;
  final String from;
  final String to;
  final String contactName;
  final String direction;
  final String status;
  final int durationSec;
  final DateTime? startedAt;

  bool get isInbound => direction == 'inbound';

  /// The far end of the call — what the history list shows.
  String get peerNumber => isInbound ? from : to;

  String get displayName =>
      contactName.isNotEmpty ? contactName : formatPhoneNumber(peerNumber);

  bool get isKnownContact => contactName.isNotEmpty;

  CallDirection get displayDirection {
    if (status == 'missed' || status == 'no-answer') {
      return CallDirection.missed;
    }
    return isInbound ? CallDirection.incoming : CallDirection.outgoing;
  }

  String get timeLabel => formatTimestamp(startedAt);

  String get durationLabel => formatDuration(durationSec);

  bool get connected => displayDirection != CallDirection.missed;
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.fromMe,
    required this.status,
    required this.sentAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: _string(json['id']),
    body: _string(json['body']),
    fromMe: json['fromMe'] == true,
    status: MessageStatusX.parse(json['status']),
    sentAt: _parseDate(json['sentAt']),
  );

  final String id;
  final String body;
  final bool fromMe;
  final MessageStatus status;
  final DateTime? sentAt;

  String get timeLabel => formatTimestamp(sentAt);

  bool get failed => status == MessageStatus.failed;
}

@immutable
class Conversation {
  const Conversation({
    required this.peer,
    required this.contactName,
    required this.messages,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    return Conversation(
      peer: _string(json['peer']),
      contactName: _string(json['contactName']),
      messages: rawMessages is List
          ? rawMessages
                .whereType<Map<String, dynamic>>()
                .map(ChatMessage.fromJson)
                .toList()
          : const [],
    );
  }

  final String peer;
  final String contactName;
  final List<ChatMessage> messages;

  String get displayName =>
      contactName.isNotEmpty ? contactName : formatPhoneNumber(peer);

  String get formattedPeer => formatPhoneNumber(peer);

  ChatMessage? get last => messages.isEmpty ? null : messages.last;

  Conversation withMessages(List<ChatMessage> updated) => Conversation(
    peer: peer,
    contactName: contactName,
    messages: updated,
  );
}

@immutable
class ActivityItem {
  const ActivityItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.isAlert,
    required this.at,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
    kind: _string(json['kind']),
    title: _string(json['title']),
    subtitle: _string(json['subtitle']),
    isAlert: json['isAlert'] == true,
    at: _parseDate(json['at']),
  );

  final String kind;
  final String title;
  final String subtitle;
  final bool isAlert;
  final DateTime? at;

  bool get isCall => kind == 'call';

  IconData get icon {
    if (isAlert) return Icons.call_missed;
    return isCall ? Icons.call_received : Icons.chat_bubble_outline;
  }

  String get timeLabel => formatTimestamp(at);
}

/// Everything the home dashboard needs, from `GET /api/mobile/me`.
@immutable
class HomeSummary {
  const HomeSummary({
    required this.user,
    required this.number,
    required this.twilioConfigured,
    required this.callsToday,
    required this.missedToday,
    required this.incomingToday,
    required this.unreadMessages,
    required this.latestSender,
    required this.latestBody,
    required this.activity,
  });

  factory HomeSummary.fromJson(Map<String, dynamic> json) {
    final today = json['today'] is Map ? json['today'] as Map : const {};
    final messages = json['messages'] is Map
        ? json['messages'] as Map
        : const {};
    final latest = messages['latest'];
    final activity = json['activity'];

    return HomeSummary(
      user: AppUser.fromJson(
        json['user'] is Map<String, dynamic>
            ? json['user'] as Map<String, dynamic>
            : const {},
      ),
      number: json['number'] is Map<String, dynamic>
          ? AssignedNumber.fromJson(json['number'] as Map<String, dynamic>)
          : null,
      twilioConfigured: json['twilioConfigured'] == true,
      callsToday: _int(today['calls']),
      missedToday: _int(today['missed']),
      incomingToday: _int(today['incoming']),
      unreadMessages: _int(messages['unread']),
      latestSender: latest is Map ? _string(latest['from']) : '',
      latestBody: latest is Map ? _string(latest['body']) : '',
      activity: activity is List
          ? activity
                .whereType<Map<String, dynamic>>()
                .map(ActivityItem.fromJson)
                .toList()
          : const [],
    );
  }

  final AppUser user;
  final AssignedNumber? number;
  final bool twilioConfigured;
  final int callsToday;
  final int missedToday;
  final int incomingToday;
  final int unreadMessages;
  final String latestSender;
  final String latestBody;
  final List<ActivityItem> activity;

  bool get hasLatestMessage => latestSender.isNotEmpty;
}
