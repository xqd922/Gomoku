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

import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'dart:async' as _i2;
import 'package:gomoku_client/src/protocol/player_profile.dart' as _i3;
import 'package:gomoku_client/src/protocol/sync_page.dart' as _i4;
import 'package:gomoku_client/src/protocol/room_snapshot.dart' as _i5;
import 'package:gomoku_client/src/protocol/room_command.dart' as _i6;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _i7;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _i8;
import 'protocol.dart' as _i9;

/// {@category Endpoint}
class EndpointProfile extends _i1.EndpointRef {
  EndpointProfile(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'profile';

  _i2.Future<_i3.PlayerProfile> me() =>
      caller.callServerEndpoint<_i3.PlayerProfile>(
        'profile',
        'me',
        {},
      );

  _i2.Future<_i3.PlayerProfile> rename(String nickname) =>
      caller.callServerEndpoint<_i3.PlayerProfile>(
        'profile',
        'rename',
        {'nickname': nickname},
      );

  _i2.Future<_i4.SyncPage> syncRecords(
    List<String> uploads,
    String cursor,
  ) => caller.callServerEndpoint<_i4.SyncPage>(
    'profile',
    'syncRecords',
    {
      'uploads': uploads,
      'cursor': cursor,
    },
  );
}

/// {@category Endpoint}
class EndpointRoom extends _i1.EndpointRef {
  EndpointRoom(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'room';

  _i2.Future<_i5.RoomSnapshot> createRoom(String commandId) =>
      caller.callServerEndpoint<_i5.RoomSnapshot>(
        'room',
        'createRoom',
        {'commandId': commandId},
      );

  _i2.Future<_i5.RoomSnapshot> joinRoom(
    String code,
    String commandId,
  ) => caller.callServerEndpoint<_i5.RoomSnapshot>(
    'room',
    'joinRoom',
    {
      'code': code,
      'commandId': commandId,
    },
  );

  _i2.Future<_i5.RoomSnapshot?> activeRoom() =>
      caller.callServerEndpoint<_i5.RoomSnapshot?>(
        'room',
        'activeRoom',
        {},
      );

  _i2.Future<_i5.RoomSnapshot> snapshot(String roomId) =>
      caller.callServerEndpoint<_i5.RoomSnapshot>(
        'room',
        'snapshot',
        {'roomId': roomId},
      );

  _i2.Future<_i5.RoomSnapshot> command(
    String roomId,
    _i6.RoomCommand command,
  ) => caller.callServerEndpoint<_i5.RoomSnapshot>(
    'room',
    'command',
    {
      'roomId': roomId,
      'command': command,
    },
  );

  _i2.Future<void> heartbeat(
    String roomId,
    String connectionId,
  ) => caller.callServerEndpoint<void>(
    'room',
    'heartbeat',
    {
      'roomId': roomId,
      'connectionId': connectionId,
    },
  );

  _i2.Stream<_i5.RoomSnapshot> watch(
    String roomId,
    String connectionId,
  ) =>
      caller.callStreamingServerEndpoint<
        _i2.Stream<_i5.RoomSnapshot>,
        _i5.RoomSnapshot
      >(
        'room',
        'watch',
        {
          'roomId': roomId,
          'connectionId': connectionId,
        },
        {},
      );
}

class Modules {
  Modules(Client client) {
    serverpod_auth_idp = _i7.Caller(client);
    serverpod_auth_core = _i8.Caller(client);
  }

  late final _i7.Caller serverpod_auth_idp;

  late final _i8.Caller serverpod_auth_core;
}

class Client extends _i1.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    @Deprecated(
      'Use authKeyProvider instead. This will be removed in future releases.',
    )
    super.authenticationKeyManager,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _i1.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_i1.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
  }) : super(
         host,
         _i9.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
       ) {
    profile = EndpointProfile(this);
    room = EndpointRoom(this);
    modules = Modules(this);
  }

  late final EndpointProfile profile;

  late final EndpointRoom room;

  late final Modules modules;

  @override
  Map<String, _i1.EndpointRef> get endpointRefLookup => {
    'profile': profile,
    'room': room,
  };

  @override
  Map<String, _i1.ModuleEndpointCaller> get moduleLookup => {
    'serverpod_auth_idp': modules.serverpod_auth_idp,
    'serverpod_auth_core': modules.serverpod_auth_core,
  };
}
