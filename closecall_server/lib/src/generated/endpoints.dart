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
import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _iacs;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _iais;
import '../auth/anonymous_idp_endpoint.dart' as _in0zita6;
import '../auth/jwt_refresh_endpoint.dart' as _inwq3ztq;
import '../pairing/pairing_endpoint.dart' as _iku2870h;

class Endpoints extends _is.EndpointDispatch {
  @override
  void initializeEndpoints(_is.Server server) {
    var endpoints = <String, _is.Endpoint>{
      'anonymousIdp': _in0zita6.AnonymousIdpEndpoint()
        ..initialize(server, 'anonymousIdp', null),
      'jwtRefresh': _inwq3ztq.JwtRefreshEndpoint()
        ..initialize(server, 'jwtRefresh', null),
      'pairing': _iku2870h.PairingEndpoint()
        ..initialize(server, 'pairing', null),
    };
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
