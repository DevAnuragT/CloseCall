/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _ida;
import 'dart:typed_data' as _idt;
import 'package:closecall_client/src/protocol/auth/account_state.dart'
    as _iksdjlut;
import 'package:closecall_client/src/protocol/media/media_asset.dart'
    as _i7z5ta07;
import 'package:closecall_client/src/protocol/pairing/pairing_state.dart'
    as _i9hl8iq9;
import 'package:closecall_client/src/protocol/widget/widget_delivery_state.dart'
    as _ih73c9dn;
import 'package:closecall_client/src/protocol/widget/widget_schedule_entry.dart'
    as _ipgzv14b;
import 'package:closecall_client/src/protocol/widget/widget_send_receipt.dart'
    as _i6vqeh0y;
import 'package:closecall_client/src/protocol/widget/widget_timeline.dart'
    as _ic1bjjnb;
import 'package:http/http.dart' as _i85jenna;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _iacc;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _iaic;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'protocol.dart' as _il2as5qe;

/// {@category Endpoint}
class EndpointAccount extends _isc.EndpointRef {
  EndpointAccount(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'account';

  _ida.Future<_iksdjlut.AccountState> currentAccount() =>
      caller.callServerEndpoint<_iksdjlut.AccountState>(
        'account',
        'currentAccount',
        {},
      );
}

/// Development/test only. The callback also guards non-endpoint creation paths.
/// {@category Endpoint}
class EndpointAnonymousIdp extends _iaic.EndpointAnonymousIdpBase {
  EndpointAnonymousIdp(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'anonymousIdp';

  @override
  _ida.Future<_iacc.AuthSuccess> login({String? token}) =>
      caller.callServerEndpoint<_iacc.AuthSuccess>('anonymousIdp', 'login', {
        'token': token,
      });
}

/// {@category Endpoint}
class EndpointEmailIdp extends _iaic.EndpointEmailIdpBase {
  EndpointEmailIdp(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'emailIdp';

  /// Logs in the user and returns a new session.
  ///
  /// Throws an [EmailAccountLoginException] in case of errors, with reason:
  /// - [EmailAccountLoginExceptionReason.invalidCredentials] if the email or
  ///   password is incorrect.
  /// - [EmailAccountLoginExceptionReason.tooManyAttempts] if there have been
  ///   too many failed login attempts.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _ida.Future<_iacc.AuthSuccess> login({
    required String email,
    required String password,
  }) => caller.callServerEndpoint<_iacc.AuthSuccess>('emailIdp', 'login', {
    'email': email,
    'password': password,
  });

  /// Starts the registration for a new user account with an email-based login
  /// associated to it.
  ///
  /// Upon successful completion of this method, an email will have been
  /// sent to [email] with a verification link, which the user must open to
  /// complete the registration.
  ///
  /// Always returns a account request ID, which can be used to complete the
  /// registration. If the email is already registered, the returned ID will not
  /// be valid.
  @override
  _ida.Future<_isc.UuidValue> startRegistration({required String email}) =>
      caller.callServerEndpoint<_isc.UuidValue>(
        'emailIdp',
        'startRegistration',
        {'email': email},
      );

  /// Verifies an account request code and returns a token
  /// that can be used to complete the account creation.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the account request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the password
  ///   does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if no request exists
  ///   for the given [accountRequestId] or [verificationCode] is invalid.
  @override
  _ida.Future<String> verifyRegistrationCode({
    required _isc.UuidValue accountRequestId,
    required String verificationCode,
  }) =>
      caller.callServerEndpoint<String>('emailIdp', 'verifyRegistrationCode', {
        'accountRequestId': accountRequestId,
        'verificationCode': verificationCode,
      });

  /// Completes a new account registration, creating a new auth user with a
  /// profile and attaching the given email account to it.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the account request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the password
  ///   does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if the [registrationToken]
  ///   is invalid.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  ///
  /// Returns a session for the newly created user.
  @override
  _ida.Future<_iacc.AuthSuccess> finishRegistration({
    required String registrationToken,
    required String password,
  }) => caller.callServerEndpoint<_iacc.AuthSuccess>(
    'emailIdp',
    'finishRegistration',
    {'registrationToken': registrationToken, 'password': password},
  );

  /// Requests a password reset for [email].
  ///
  /// If the email address is registered, an email with reset instructions will
  /// be send out. If the email is unknown, this method will have no effect.
  ///
  /// Always returns a password reset request ID, which can be used to complete
  /// the reset. If the email is not registered, the returned ID will not be
  /// valid.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts trying to request a password reset.
  ///
  @override
  _ida.Future<_isc.UuidValue> startPasswordReset({required String email}) =>
      caller.callServerEndpoint<_isc.UuidValue>(
        'emailIdp',
        'startPasswordReset',
        {'email': email},
      );

  /// Verifies a password reset code and returns a finishPasswordResetToken
  /// that can be used to finish the password reset.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.expired] if the password reset
  ///   request has already expired.
  /// - [EmailAccountPasswordResetExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts trying to verify the password reset.
  /// - [EmailAccountPasswordResetExceptionReason.invalid] if no request exists
  ///   for the given [passwordResetRequestId] or [verificationCode] is invalid.
  ///
  /// If multiple steps are required to complete the password reset, this endpoint
  /// should be overridden to return credentials for the next step instead
  /// of the credentials for setting the password.
  @override
  _ida.Future<String> verifyPasswordResetCode({
    required _isc.UuidValue passwordResetRequestId,
    required String verificationCode,
  }) =>
      caller.callServerEndpoint<String>('emailIdp', 'verifyPasswordResetCode', {
        'passwordResetRequestId': passwordResetRequestId,
        'verificationCode': verificationCode,
      });

  /// Completes a password reset request by setting a new password.
  ///
  /// The [verificationCode] returned from [verifyPasswordResetCode] is used to
  /// validate the password reset request.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.expired] if the password reset
  ///   request has already expired.
  /// - [EmailAccountPasswordResetExceptionReason.policyViolation] if the new
  ///   password does not comply with the password policy.
  /// - [EmailAccountPasswordResetExceptionReason.invalid] if no request exists
  ///   for the given [passwordResetRequestId] or [verificationCode] is invalid.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _ida.Future<void> finishPasswordReset({
    required String finishPasswordResetToken,
    required String newPassword,
  }) => caller.callServerEndpoint<void>('emailIdp', 'finishPasswordReset', {
    'finishPasswordResetToken': finishPasswordResetToken,
    'newPassword': newPassword,
  });

  @override
  _ida.Future<bool> hasAccount() =>
      caller.callServerEndpoint<bool>('emailIdp', 'hasAccount', {});
}

/// Enables the standard Serverpod JWT refresh flow.
/// {@category Endpoint}
class EndpointJwtRefresh extends _iacc.EndpointRefreshJwtTokens {
  EndpointJwtRefresh(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'jwtRefresh';

  /// Creates a new token pair for the given [refreshToken].
  ///
  /// If [refreshToken] is omitted, cookie-mode web clients fall back to the
  /// configured HttpOnly refresh cookie. When neither source is present this
  /// throws [RefreshTokenNotFoundException], the same public "no usable refresh
  /// credential" exception used for unknown refresh tokens.
  ///
  /// Can throw the following exceptions:
  /// -[RefreshTokenMalformedException]: refresh token is malformed and could
  ///   not be parsed. Not expected to happen for tokens issued by the server.
  /// -[RefreshTokenNotFoundException]: refresh token is unknown to the server.
  ///   Either the token was deleted or generated by a different server.
  /// -[RefreshTokenExpiredException]: refresh token has expired. Will happen
  ///   only if it has not been used within configured `refreshTokenLifetime`.
  /// -[RefreshTokenInvalidSecretException]: refresh token is incorrect, meaning
  ///   it does not refer to the current secret refresh token. This indicates
  ///   either a malfunctioning client or a malicious attempt by someone who has
  ///   obtained the refresh token. In this case the underlying refresh token
  ///   will be deleted, and access to it will expire fully when the last access
  ///   token is elapsed.
  ///
  /// This endpoint is unauthenticated, meaning the client won't include any
  /// authentication information with the call.
  @override
  _ida.Future<_iacc.AuthSuccess> refreshAccessToken({String? refreshToken}) =>
      caller.callServerEndpoint<_iacc.AuthSuccess>(
        'jwtRefresh',
        'refreshAccessToken',
        {'refreshToken': refreshToken},
        authenticated: false,
      );
}

/// {@category Endpoint}
class EndpointMedia extends _isc.EndpointRef {
  EndpointMedia(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'media';

  _ida.Future<_i7z5ta07.MediaAsset> uploadPhoto(
    _idt.ByteData pngBytes,
    String requestId,
  ) => caller.callServerEndpoint<_i7z5ta07.MediaAsset>('media', 'uploadPhoto', {
    'pngBytes': pngBytes,
    'requestId': requestId,
  });

  _ida.Future<List<_i7z5ta07.MediaAsset>> listAssets() =>
      caller.callServerEndpoint<List<_i7z5ta07.MediaAsset>>(
        'media',
        'listAssets',
        {},
      );

  _ida.Future<_idt.ByteData> downloadPhoto(String assetId) =>
      caller.callServerEndpoint<_idt.ByteData>('media', 'downloadPhoto', {
        'assetId': assetId,
      });
}

/// Identity comes exclusively from authenticated JWT sessions, never arguments.
/// {@category Endpoint}
class EndpointPairing extends _isc.EndpointRef {
  EndpointPairing(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'pairing';

  _ida.Future<_i9hl8iq9.PairingState> createCouple() =>
      caller.callServerEndpoint<_i9hl8iq9.PairingState>(
        'pairing',
        'createCouple',
        {},
      );

  _ida.Future<_i9hl8iq9.PairingState> joinByCode(String code) =>
      caller.callServerEndpoint<_i9hl8iq9.PairingState>(
        'pairing',
        'joinByCode',
        {'code': code},
      );

  _ida.Future<_i9hl8iq9.PairingState?> currentCouple() =>
      caller.callServerEndpoint<_i9hl8iq9.PairingState?>(
        'pairing',
        'currentCouple',
        {},
      );
}

/// {@category Endpoint}
class EndpointWidgetSchedule extends _isc.EndpointRef {
  EndpointWidgetSchedule(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'widgetSchedule';

  _ida.Future<_ic1bjjnb.WidgetTimeline> currentTimeline() =>
      caller.callServerEndpoint<_ic1bjjnb.WidgetTimeline>(
        'widgetSchedule',
        'currentTimeline',
        {},
      );

  _ida.Future<_ic1bjjnb.WidgetTimeline> partnerTimeline() =>
      caller.callServerEndpoint<_ic1bjjnb.WidgetTimeline>(
        'widgetSchedule',
        'partnerTimeline',
        {},
      );

  /// Reads the signed-in recipient's committed state, including opt-out state.
  _ida.Future<_ih73c9dn.WidgetDeliveryState> getDeliveryState() =>
      caller.callServerEndpoint<_ih73c9dn.WidgetDeliveryState>(
        'widgetSchedule',
        'getDeliveryState',
        {},
      );

  /// Only the recipient may change their own couple-scoped consent.
  _ida.Future<_ih73c9dn.WidgetDeliveryState> setDeliveryConsent(bool enabled) =>
      caller.callServerEndpoint<_ih73c9dn.WidgetDeliveryState>(
        'widgetSchedule',
        'setDeliveryConsent',
        {'enabled': enabled},
      );

  /// Sends an already uploaded, sender-owned asset. Retry with the same UUID.
  _ida.Future<_i6vqeh0y.WidgetSendReceipt> sendAsset(
    String assetId,
    String requestId,
  ) => caller.callServerEndpoint<_i6vqeh0y.WidgetSendReceipt>(
    'widgetSchedule',
    'sendAsset',
    {'assetId': assetId, 'requestId': requestId},
  );

  _ida.Future<_ipgzv14b.WidgetScheduleEntry> createSchedule(
    String assetId,
    DateTime activeFrom,
    DateTime activeUntil,
    String requestId,
  ) => caller.callServerEndpoint<_ipgzv14b.WidgetScheduleEntry>(
    'widgetSchedule',
    'createSchedule',
    {
      'assetId': assetId,
      'activeFrom': activeFrom,
      'activeUntil': activeUntil,
      'requestId': requestId,
    },
  );

  _ida.Future<_ic1bjjnb.WidgetTimeline> setFallback(String assetId) =>
      caller.callServerEndpoint<_ic1bjjnb.WidgetTimeline>(
        'widgetSchedule',
        'setFallback',
        {'assetId': assetId},
      );

  _ida.Future<void> cancelSchedule(String scheduleId) =>
      caller.callServerEndpoint<void>('widgetSchedule', 'cancelSchedule', {
        'scheduleId': scheduleId,
      });

  /// Local notifications reduce latency, precise timers handle boundaries, and
  /// one-second DB reconciliation covers missed events/restarts/other pods.
  /// Every snapshot rechecks the CURRENT user's complete membership.
  _ida.Stream<_ic1bjjnb.WidgetTimeline> watchTimeline() =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_ic1bjjnb.WidgetTimeline>,
        _ic1bjjnb.WidgetTimeline
      >('widgetSchedule', 'watchTimeline', {}, {});
}

class Modules {
  Modules(Client client) {
    serverpod_auth_core = _iacc.Caller(client);
    serverpod_auth_idp = _iaic.Caller(client);
  }

  late final _iacc.Caller serverpod_auth_core;

  late final _iaic.Caller serverpod_auth_idp;
}

class Client extends _isc.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(_isc.MethodCallContext, Object, StackTrace)? onFailedCall,
    Function(_isc.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
    _i85jenna.Client? httpClientOverride,
  }) : super(
         host,
         _il2as5qe.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
         httpClientOverride: httpClientOverride,
       ) {
    account = EndpointAccount(this);
    anonymousIdp = EndpointAnonymousIdp(this);
    emailIdp = EndpointEmailIdp(this);
    jwtRefresh = EndpointJwtRefresh(this);
    media = EndpointMedia(this);
    pairing = EndpointPairing(this);
    widgetSchedule = EndpointWidgetSchedule(this);
    modules = Modules(this);
  }

  late final EndpointAccount account;

  late final EndpointAnonymousIdp anonymousIdp;

  late final EndpointEmailIdp emailIdp;

  late final EndpointJwtRefresh jwtRefresh;

  late final EndpointMedia media;

  late final EndpointPairing pairing;

  late final EndpointWidgetSchedule widgetSchedule;

  late final Modules modules;

  @override
  Map<String, _isc.EndpointRef> get endpointRefLookup => {
    'account': account,
    'anonymousIdp': anonymousIdp,
    'emailIdp': emailIdp,
    'jwtRefresh': jwtRefresh,
    'media': media,
    'pairing': pairing,
    'widgetSchedule': widgetSchedule,
  };

  @override
  Map<String, _isc.ModuleEndpointCaller> get moduleLookup => {
    'serverpod_auth_core': modules.serverpod_auth_core,
    'serverpod_auth_idp': modules.serverpod_auth_idp,
  };
}
