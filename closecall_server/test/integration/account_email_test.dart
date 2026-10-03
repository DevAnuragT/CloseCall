import 'dart:convert';
import 'dart:math';

import 'package:closecall_server/src/auth/authentication.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/anonymous.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

String ephemeralSecret() => base64UrlEncode(
  List<int>.generate(32, (_) => Random.secure().nextInt(256)),
);

void main() {
  withServerpod(
    'Recoverable email identity and account isolation',
    (builder, endpoints) {
      final registrationCodes = <UuidValue, String>{};
      final resetCodes = <UuidValue, String>{};
      TestSessionBuilder asUser(String id) => builder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(id, {}),
      );

      setUp(() {
        registrationCodes.clear();
        resetCodes.clear();
        builder.build().serverpod.initializeAuthServices(
          tokenManagerBuilders: [JwtConfigFromPasswords()],
          identityProviderBuilders: [
            AnonymousIdpConfig(
              onBeforeAnonymousAccountCreated:
                  (session, {token, required transaction}) {
                    requireDevelopmentAuthentication(session.serverpod.runMode);
                  },
            ),
            // Test-only callback capture. Never call the default code logger.
            EmailIdpConfigFromPasswords(
              sendRegistrationVerificationCode:
                  (
                    session, {
                    required email,
                    required accountRequestId,
                    required verificationCode,
                    required transaction,
                  }) {
                    registrationCodes[accountRequestId] = verificationCode;
                  },
              sendPasswordResetVerificationCode:
                  (
                    session, {
                    required email,
                    required passwordResetRequestId,
                    required verificationCode,
                    required transaction,
                  }) {
                    resetCodes[passwordResetRequestId] = verificationCode;
                  },
            ),
          ],
        );
      });

      Future<AuthSuccess> register(String email, String password) async {
        final request = await endpoints.emailIdp.startRegistration(
          builder,
          email: email,
        );
        final token = await endpoints.emailIdp.verifyRegistrationCode(
          builder,
          accountRequestId: request,
          verificationCode: registrationCodes.remove(request)!,
        );
        return endpoints.emailIdp.finishRegistration(
          builder,
          registrationToken: token,
          password: password,
        );
      }

      test('current account rejects unauthenticated callers', () async {
        await expectLater(
          endpoints.account.currentAccount(builder),
          throwsA(isA<ServerpodUnauthenticatedException>()),
        );
      });

      test(
        'email registration, fresh-session login and reset preserve identity and pairing',
        () async {
          final email = 'recovery-${Uuid().v4()}@example.com';
          final oldPassword = ephemeralSecret();
          final newPassword = ephemeralSecret();
          final registered = await register(email, oldPassword);
          final id = registered.authUserId.toString();
          final account = await endpoints.account.currentAccount(asUser(id));
          expect(account.userId, id);
          expect(account.isGuest, isFalse);
          expect(account.email, email);
          final couple = await endpoints.pairing.createCouple(asUser(id));
          final login = await endpoints.emailIdp.login(
            builder,
            email: email,
            password: oldPassword,
          );
          expect(login.authUserId, registered.authUserId);
          final session = builder.build();
          final auth = await session.serverpod.authenticationHandler!(
            session,
            login.token,
          );
          expect(auth?.userIdentifier == id, isTrue);
          final reset = await endpoints.emailIdp.startPasswordReset(
            builder,
            email: email,
          );
          final resetToken = await endpoints.emailIdp.verifyPasswordResetCode(
            builder,
            passwordResetRequestId: reset,
            verificationCode: resetCodes.remove(reset)!,
          );
          await endpoints.emailIdp.finishPasswordReset(
            builder,
            finishPasswordResetToken: resetToken,
            newPassword: newPassword,
          );
          await expectLater(
            endpoints.emailIdp.login(
              builder,
              email: email,
              password: oldPassword,
            ),
            throwsA(isA<EmailAccountLoginException>()),
          );
          final recovered = await endpoints.emailIdp.login(
            builder,
            email: email,
            password: newPassword,
          );
          expect(recovered.authUserId, registered.authUserId);
          expect(
            (await endpoints.pairing.currentCouple(
              asUser(recovered.authUserId.toString()),
            ))!.coupleId,
            couple.coupleId,
          );
          final refreshed = await endpoints.account.currentAccount(asUser(id));
          expect(refreshed.email, email);
          expect(refreshed.isGuest, isFalse);
        },
      );

      test(
        'guest and two recoverable accounts expose only their own IDP records',
        () async {
          final guest = await endpoints.anonymousIdp.login(builder);
          final guestState = await endpoints.account.currentAccount(
            asUser(guest.authUserId.toString()),
          );
          expect(guestState.userId, guest.authUserId.toString());
          expect(guestState.isGuest, isTrue);
          expect(guestState.email, isNull);
          final firstEmail = 'first-${Uuid().v4()}@example.com';
          final secondEmail = 'second-${Uuid().v4()}@example.com';
          final first = await register(firstEmail, ephemeralSecret());
          final second = await register(secondEmail, ephemeralSecret());
          expect(first.authUserId == second.authUserId, isFalse);
          expect(
            (await endpoints.account.currentAccount(
              asUser(first.authUserId.toString()),
            )).email,
            firstEmail,
          );
          expect(
            (await endpoints.account.currentAccount(
              asUser(second.authUserId.toString()),
            )).email,
            secondEmail,
          );
          expect(
            (await endpoints.account.currentAccount(
              asUser(guest.authUserId.toString()),
            )).email,
            isNull,
          );
        },
      );

      test(
        'invalid registration code and unknown reset never produce an account',
        () async {
          final email = 'unknown-${Uuid().v4()}@example.com';
          final request = await endpoints.emailIdp.startRegistration(
            builder,
            email: email,
          );
          await expectLater(
            endpoints.emailIdp.verifyRegistrationCode(
              builder,
              accountRequestId: request,
              verificationCode: ephemeralSecret(),
            ),
            throwsA(isA<EmailAccountRequestException>()),
          );
          final reset = await endpoints.emailIdp.startPasswordReset(
            builder,
            email: email,
          );
          expect(resetCodes.containsKey(reset), isFalse);
          await expectLater(
            endpoints.emailIdp.verifyPasswordResetCode(
              builder,
              passwordResetRequestId: reset,
              verificationCode: ephemeralSecret(),
            ),
            throwsA(isA<EmailAccountPasswordResetException>()),
          );
          expect(
            await EmailAccount.db.count(
              builder.build(),
              where: (t) => t.email.equals(email),
            ),
            0,
          );
        },
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
    ephemeralDatabase: true,
    testServerOutputMode: TestServerOutputMode.silent,
  );
}
