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

import 'package:serverpod/serverpod.dart' as _i1;

import '../endpoints/profile_endpoint.dart' as _i2;
import '../endpoints/room_endpoint.dart' as _i3;

import 'package:gomoku_server/src/generated/room_command.dart' as _i4;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _i5;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _i6;

class Endpoints extends _i1.EndpointDispatch {
  @override
  void initializeEndpoints(_i1.Server server) {
    var endpoints = <String, _i1.Endpoint>{
      'profile': _i2.ProfileEndpoint()
        ..initialize(
          server,
          'profile',
          null,
        ),
      'room': _i3.RoomEndpoint()
        ..initialize(
          server,
          'room',
          null,
        ),
    };
    connectors['profile'] = _i1.EndpointConnector(
      name: 'profile',
      endpoint: endpoints['profile']!,
      methodConnectors: {
        'me': _i1.MethodConnector(
          name: 'me',
          params: {},
          call: (
            _i1.Session session,
            Map<String, dynamic> params,
          ) async => (endpoints['profile'] as _i2.ProfileEndpoint).me(session),
        ),
        'rename': _i1.MethodConnector(
          name: 'rename',
          params: {
            'nickname': _i1.ParameterDescription(
              name: 'nickname',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['profile'] as _i2.ProfileEndpoint).rename(
                session,
                params['nickname'],
              ),
        ),
        'syncRecords': _i1.MethodConnector(
          name: 'syncRecords',
          params: {
            'uploads': _i1.ParameterDescription(
              name: 'uploads',
              type: _i1.getType<List<String>>(),
              nullable: false,
            ),
            'cursor': _i1.ParameterDescription(
              name: 'cursor',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['profile'] as _i2.ProfileEndpoint).syncRecords(
                    session,
                    params['uploads'],
                    params['cursor'],
                  ),
        ),
      },
    );
    connectors['room'] = _i1.EndpointConnector(
      name: 'room',
      endpoint: endpoints['room']!,
      methodConnectors: {
        'createRoom': _i1.MethodConnector(
          name: 'createRoom',
          params: {
            'commandId': _i1.ParameterDescription(
              name: 'commandId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['room'] as _i3.RoomEndpoint).createRoom(
                session,
                params['commandId'],
              ),
        ),
        'joinRoom': _i1.MethodConnector(
          name: 'joinRoom',
          params: {
            'code': _i1.ParameterDescription(
              name: 'code',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'commandId': _i1.ParameterDescription(
              name: 'commandId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['room'] as _i3.RoomEndpoint).joinRoom(
                session,
                params['code'],
                params['commandId'],
              ),
        ),
        'activeRoom': _i1.MethodConnector(
          name: 'activeRoom',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['room'] as _i3.RoomEndpoint).activeRoom(session),
        ),
        'snapshot': _i1.MethodConnector(
          name: 'snapshot',
          params: {
            'roomId': _i1.ParameterDescription(
              name: 'roomId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['room'] as _i3.RoomEndpoint).snapshot(
                session,
                params['roomId'],
              ),
        ),
        'command': _i1.MethodConnector(
          name: 'command',
          params: {
            'roomId': _i1.ParameterDescription(
              name: 'roomId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'command': _i1.ParameterDescription(
              name: 'command',
              type: _i1.getType<_i4.RoomCommand>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['room'] as _i3.RoomEndpoint).command(
                session,
                params['roomId'],
                params['command'],
              ),
        ),
        'heartbeat': _i1.MethodConnector(
          name: 'heartbeat',
          params: {
            'roomId': _i1.ParameterDescription(
              name: 'roomId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'connectionId': _i1.ParameterDescription(
              name: 'connectionId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['room'] as _i3.RoomEndpoint).heartbeat(
                session,
                params['roomId'],
                params['connectionId'],
              ),
        ),
        'watch': _i1.MethodStreamConnector(
          name: 'watch',
          params: {
            'roomId': _i1.ParameterDescription(
              name: 'roomId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'connectionId': _i1.ParameterDescription(
              name: 'connectionId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          streamParams: {},
          returnType: _i1.MethodStreamReturnType.streamType,
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['room'] as _i3.RoomEndpoint).watch(
                session,
                params['roomId'],
                params['connectionId'],
              ),
        ),
      },
    );
    modules['serverpod_auth_idp'] = _i5.Endpoints()
      ..initializeEndpoints(server);
    modules['serverpod_auth_core'] = _i6.Endpoints()
      ..initializeEndpoints(server);
  }
}
