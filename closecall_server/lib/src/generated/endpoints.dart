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
import 'dart:typed_data' as _idt;
import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _iacs;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _iais;
import '../auth/account_endpoint.dart' as _ii6ycf6v;
import '../auth/anonymous_idp_endpoint.dart' as _in0zita6;
import '../auth/email_idp_endpoint.dart' as _iuc1hd5t;
import '../auth/jwt_refresh_endpoint.dart' as _inwq3ztq;
import '../media/media_endpoint.dart' as _i9ppd1x8;
import '../pairing/pairing_endpoint.dart' as _iku2870h;

class Endpoints extends _is.EndpointDispatch {
  @override
  void initializeEndpoints(_is.Server server) {
    var endpoints = <String, _is.Endpoint>{
      'account': _ii6ycf6v.AccountEndpoint()
        ..initialize(server, 'account', null),
      'anonymousIdp': _in0zita6.AnonymousIdpEndpoint()
        ..initialize(server, 'anonymousIdp', null),
      'emailIdp': _iuc1hd5t.EmailIdpEndpoint()
        ..initialize(server, 'emailIdp', null),
      'jwtRefresh': _inwq3ztq.JwtRefreshEndpoint()
        ..initialize(server, 'jwtRefresh', null),
      'media': _i9ppd1x8.MediaEndpoint()..initialize(server, 'media', null),
      'pairing': _iku2870h.PairingEndpoint()
        ..initialize(server, 'pairing', null),
    };
    connectors['account'] = _is.EndpointConnector(
      name: 'account',
      endpoint: endpoints['account']!,
      methodConnectors: {
        'currentAccount': _is.MethodConnector(
          name: 'currentAccount',
          params: {},
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['account'] as _ii6ycf6v.AccountEndpoint)
                  .currentAccount(session),
        ),
      },
    );
    connectors['anonymousIdp'] = _is.EndpointConnector(
      name: 'anonymousIdp',
      endpoint: endpoints['anonymousIdp']!,
      methodConnectors: {
        'login': _is.MethodConnector(
          name: 'login',
          params: {
            'token': _is.ParameterDescription(
              name: 'token',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['anonymousIdp'] as _in0zita6.AnonymousIdpEndpoint)
                  .login(session, token: params['token']),
        ),
      },
    );
    connectors['emailIdp'] = _is.EndpointConnector(
      name: 'emailIdp',
      endpoint: endpoints['emailIdp']!,
      methodConnectors: {
        'login': _is.MethodConnector(
          name: 'login',
          params: {
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'password': _is.ParameterDescription(
              name: 'password',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint).login(
                session,
                email: params['email'],
                password: params['password'],
              ),
        ),
        'startRegistration': _is.MethodConnector(
          name: 'startRegistration',
          params: {
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .startRegistration(session, email: params['email']),
        ),
        'verifyRegistrationCode': _is.MethodConnector(
          name: 'verifyRegistrationCode',
          params: {
            'accountRequestId': _is.ParameterDescription(
              name: 'accountRequestId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'verificationCode': _is.ParameterDescription(
              name: 'verificationCode',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .verifyRegistrationCode(
                    session,
                    accountRequestId: params['accountRequestId'],
                    verificationCode: params['verificationCode'],
                  ),
        ),
        'finishRegistration': _is.MethodConnector(
          name: 'finishRegistration',
          params: {
            'registrationToken': _is.ParameterDescription(
              name: 'registrationToken',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'password': _is.ParameterDescription(
              name: 'password',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .finishRegistration(
                    session,
                    registrationToken: params['registrationToken'],
                    password: params['password'],
                  ),
        ),
        'startPasswordReset': _is.MethodConnector(
          name: 'startPasswordReset',
          params: {
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .startPasswordReset(session, email: params['email']),
        ),
        'verifyPasswordResetCode': _is.MethodConnector(
          name: 'verifyPasswordResetCode',
          params: {
            'passwordResetRequestId': _is.ParameterDescription(
              name: 'passwordResetRequestId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'verificationCode': _is.ParameterDescription(
              name: 'verificationCode',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .verifyPasswordResetCode(
                    session,
                    passwordResetRequestId: params['passwordResetRequestId'],
                    verificationCode: params['verificationCode'],
                  ),
        ),
        'finishPasswordReset': _is.MethodConnector(
          name: 'finishPasswordReset',
          params: {
            'finishPasswordResetToken': _is.ParameterDescription(
              name: 'finishPasswordResetToken',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'newPassword': _is.ParameterDescription(
              name: 'newPassword',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .finishPasswordReset(
                    session,
                    finishPasswordResetToken:
                        params['finishPasswordResetToken'],
                    newPassword: params['newPassword'],
                  ),
        ),
        'hasAccount': _is.MethodConnector(
          name: 'hasAccount',
          params: {},
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint).hasAccount(
                session,
              ),
        ),
      },
    );
    connectors['jwtRefresh'] = _is.EndpointConnector(
      name: 'jwtRefresh',
      endpoint: endpoints['jwtRefresh']!,
      methodConnectors: {
        'refreshAccessToken': _is.MethodConnector(
          name: 'refreshAccessToken',
          params: {
            'refreshToken': _is.ParameterDescription(
              name: 'refreshToken',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['jwtRefresh'] as _inwq3ztq.JwtRefreshEndpoint)
                  .refreshAccessToken(
                    session,
                    refreshToken: params['refreshToken'],
                  ),
        ),
      },
    );
    connectors['media'] = _is.EndpointConnector(
      name: 'media',
      endpoint: endpoints['media']!,
      methodConnectors: {
        'uploadPhoto': _is.MethodConnector(
          name: 'uploadPhoto',
          params: {
            'pngBytes': _is.ParameterDescription(
              name: 'pngBytes',
              type: _is.getType<_idt.ByteData>(),
              nullable: false,
            ),
            'requestId': _is.ParameterDescription(
              name: 'requestId',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['media'] as _i9ppd1x8.MediaEndpoint).uploadPhoto(
                session,
                params['pngBytes'],
                params['requestId'],
              ),
        ),
        'listAssets': _is.MethodConnector(
          name: 'listAssets',
          params: {},
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['media'] as _i9ppd1x8.MediaEndpoint).listAssets(
                session,
              ),
        ),
        'downloadPhoto': _is.MethodConnector(
          name: 'downloadPhoto',
          params: {
            'assetId': _is.ParameterDescription(
              name: 'assetId',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['media'] as _i9ppd1x8.MediaEndpoint).downloadPhoto(
                session,
                params['assetId'],
              ),
        ),
      },
    );
    connectors['pairing'] = _is.EndpointConnector(
      name: 'pairing',
      endpoint: endpoints['pairing']!,
      methodConnectors: {
        'createCouple': _is.MethodConnector(
          name: 'createCouple',
          params: {},
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['pairing'] as _iku2870h.PairingEndpoint).createCouple(
                session,
              ),
        ),
        'joinByCode': _is.MethodConnector(
          name: 'joinByCode',
          params: {
            'code': _is.ParameterDescription(
              name: 'code',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['pairing'] as _iku2870h.PairingEndpoint).joinByCode(
                session,
                params['code'],
              ),
        ),
        'currentCouple': _is.MethodConnector(
          name: 'currentCouple',
          params: {},
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['pairing'] as _iku2870h.PairingEndpoint).currentCouple(
                session,
              ),
        ),
      },
    );
    modules['serverpod_auth_core'] = _iacs.Endpoints()
      ..initializeEndpoints(server);
    modules['serverpod_auth_idp'] = _iais.Endpoints()
      ..initializeEndpoints(server);
  }
}
