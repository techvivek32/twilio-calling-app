import 'package:flutter/material.dart';

import '../screens/active_call_screen.dart';
import '../widgets/personal_number_prompt.dart';
import 'format.dart';
import 'session.dart';

/// Starts an outbound call and opens the in-call screen.
///
/// Every entry point — dialler, history, contacts, a conversation — goes
/// through here. Call history used to build [ActiveCallScreen] directly
/// without ever asking Twilio to dial, so the screen opened and sat at "Not
/// connected"; one shared path keeps that from happening again.
Future<void> startCall(
  BuildContext context, {
  required String number,
  String contactName = '',
  String? displayName,
  String? role,
  AppSession? session,
}) async {
  final active = session ?? AppSession.instance;

  // Click-to-call bridges to the user's own handset, so it must be known.
  if (!await ensurePersonalNumber(context, active)) return;
  if (!context.mounted) return;

  String? callSid;
  String? warning;

  try {
    callSid = await active.placeCall(to: number, contactName: contactName);
  } catch (error) {
    warning = error.toString();
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ActiveCallScreen(
        name: displayName?.isNotEmpty == true
            ? displayName!
            : (contactName.isNotEmpty ? contactName : formatPhoneNumber(number)),
        phone: formatPhoneNumber(number),
        rawNumber: number,
        contactName: contactName,
        role: role,
        callSid: callSid,
        warning: warning,
        session: session,
      ),
    ),
  );
}
