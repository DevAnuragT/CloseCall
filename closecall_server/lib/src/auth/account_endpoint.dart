import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/providers/anonymous.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

import '../generated/protocol.dart';

class AccountEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<AccountState> currentAccount(Session session) async {
    final identity = session.authenticated!.userIdentifier;
    final id = UuidValue.fromString(identity);
    final emailAccount = await EmailAccount.db.findFirstRow(
      session,
      where: (t) => t.authUserId.equals(id),
    );
    final anonymousAccount = await AnonymousAccount.db.findFirstRow(
      session,
      where: (t) => t.authUserId.equals(id),
    );
    return AccountState(
      userId: identity,
      isGuest: emailAccount == null && anonymousAccount != null,
      email: emailAccount?.email,
    );
  }
}
