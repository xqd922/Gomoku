import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../services/rooms.dart';

class RoomEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<RoomSnapshot> createRoom(Session session, String commandId) =>
      Rooms.create(session, commandId);
  Future<RoomSnapshot> joinRoom(
    Session session,
    String code,
    String commandId,
  ) => Rooms.join(session, code, commandId);
  Future<RoomSnapshot?> activeRoom(Session session) => Rooms.active(session);
  Future<List<RoomSnapshot>> openRooms(Session session) =>
      Rooms.openList(session);
  Future<RoomSnapshot> snapshot(Session session, String roomId) =>
      Rooms.get(session, roomId);
  Future<RoomSnapshot> command(
    Session session,
    String roomId,
    RoomCommand command,
  ) => Rooms.command(session, roomId, command);
  Future<void> heartbeat(Session session, String roomId, String connectionId) =>
      Rooms.heartbeat(session, roomId, connectionId);
  Stream<RoomSnapshot> watch(
    Session session,
    String roomId,
    String connectionId,
  ) => Rooms.watch(session, roomId, connectionId);
}
