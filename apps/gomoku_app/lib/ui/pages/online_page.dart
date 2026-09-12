import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gomoku_client/gomoku_client.dart';
import 'package:gomoku_core/gomoku_core.dart';

import '../../data/api.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../state/online.dart';
import '../../state/settings.dart';
import '../widgets/board.dart';
import '../widgets/common.dart';
import 'local_page.dart';

class OnlinePage extends ConsumerStatefulWidget {
  const OnlinePage({super.key, required this.roomId});
  final String roomId;
  @override
  ConsumerState<OnlinePage> createState() => _OnlinePageState();
}

class _OnlinePageState extends ConsumerState<OnlinePage> {
  Object? _error;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      await ref.read(onlineProvider.notifier).load(widget.roomId);
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      _loading = false;
    }
  }

  Future<void> _send(RoomAction action) async {
    try {
      await ref.read(onlineProvider.notifier).send(action);
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _leave() async {
    final s = context.strings;
    final room = ref.read(onlineProvider).room;
    if (room != null &&
        (room.status == RoomStatus.playing ||
            room.status == RoomStatus.paused) &&
        !await confirmAction(
          context,
          s.t('leaveTitle'),
          s.t('leaveBody'),
          confirmLabel: s.t('leaveRoom'),
        )) {
      return;
    }
    try {
      await ref.read(onlineProvider.notifier).leave();
      if (mounted) context.go('/');
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _copy(String value) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.strings.t('copied'))));
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(onlineProvider);
    final room = online.room?.roomId == widget.roomId ? online.room : null;
    final s = context.strings;
    final colors = Theme.of(context).colorScheme;
    if (_error != null && room == null) {
      return PageFrame(
        children: [
          PageHeading(
            title: s.t('friendMatch'),
            subtitle: s.error(errorCode(_error!)),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(onPressed: _load, child: Text(s.t('retry'))),
              TextButton(
                onPressed: () => context.go('/lobby'),
                child: Text(s.t('back')),
              ),
            ],
          ),
        ],
      );
    }
    if (room == null) return const Center(child: CircularProgressIndicator());
    final game = GameState.fromJson(
      jsonDecode(room.gameJson) as Map<String, dynamic>,
    );
    final player = ref.watch(authProvider).profile?.playerId;
    final isHost = room.hostPlayerId == player;
    final myStone = room.blackPlayerId == player ? Stone.black : Stone.white;
    final myReady = isHost ? room.hostReady : room.guestReady;
    final playing = room.status == RoomStatus.playing;
    final waiting = room.status == RoomStatus.waiting;
    final closed = room.status == RoomStatus.closed;
    final finished = room.status == RoomStatus.finished;
    final canSend = online.connected && !online.busy && !closed;
    final myTurn = playing && game.turn == myStone;
    final label = closed
        ? s.t('closedRoom')
        : game.isOver
        ? resultLabel(game, s)
        : room.status == RoomStatus.paused
        ? s.t('paused')
        : waiting
        ? s.t('waitingSeat')
        : s.t(myTurn ? 'yourTurn' : 'theirTurn');
    final seats = Column(
      children: [
        _Seat(
          name: room.hostName,
          stone: room.blackPlayerId == room.hostPlayerId
              ? Stone.black
              : Stone.white,
          mine: isHost,
          online: room.hostConnected,
          ready: room.hostReady,
          waiting: waiting,
        ),
        const SizedBox(height: 14),
        _Seat(
          name: room.guestName ?? s.t('waitingSeat'),
          stone: room.blackPlayerId == room.hostPlayerId
              ? Stone.white
              : Stone.black,
          mine: !isHost,
          online: room.guestConnected,
          ready: room.guestReady,
          waiting: waiting,
        ),
      ],
    );
    final panel = Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(label, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 22),
            seats,
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(),
            ),
            if (waiting)
              FilledButton.icon(
                onPressed: canSend && !myReady
                    ? () => _send(RoomAction.ready)
                    : null,
                icon: Icon(
                  myReady ? Icons.check_rounded : Icons.sports_esports_outlined,
                ),
                label: Text(s.t(myReady ? 'isReady' : 'ready')),
              ),
            if (playing && room.undoRequestedBy != null) ...[
              Text(
                s.t(
                  room.undoRequestedBy == player
                      ? 'undoWaiting'
                      : 'undoIncoming',
                ),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (room.undoRequestedBy != player) ...[
                const SizedBox(height: 10),
                Text(
                  s.t('undoExplanation'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: canSend
                      ? () => _send(RoomAction.acceptUndo)
                      : null,
                  child: Text(s.t('accept')),
                ),
                TextButton(
                  onPressed: canSend
                      ? () => _send(RoomAction.rejectUndo)
                      : null,
                  child: Text(s.t('decline')),
                ),
              ],
              const SizedBox(height: 18),
            ],
            if (playing)
              OutlinedButton.icon(
                onPressed:
                    canSend &&
                        room.undoRequestedBy == null &&
                        game.moves.any((move) => move.stone == myStone)
                    ? () => _send(RoomAction.requestUndo)
                    : null,
                icon: const Icon(Icons.undo_rounded),
                label: Text(s.t('undoRequest')),
              ),
            if (playing || room.status == RoomStatus.paused) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: canSend
                    ? () async {
                        if (await confirmAction(
                          context,
                          s.t('resignTitle'),
                          s.t('resignBody'),
                          confirmLabel: s.t('resign'),
                        )) {
                          await _send(RoomAction.resign);
                        }
                      }
                    : null,
                icon: const Icon(Icons.flag_outlined),
                label: Text(s.t('resign')),
              ),
            ],
            if (finished) ...[
              FilledButton.icon(
                onPressed: canSend && !myReady
                    ? () => _send(RoomAction.rematch)
                    : null,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(s.t(myReady ? 'rematchWaiting' : 'rematch')),
              ),
              const SizedBox(height: 12),
            ],
            if (game.isOver)
              OutlinedButton.icon(
                onPressed: () => context.go('/history/${room.gameId}'),
                icon: const Icon(Icons.replay_rounded),
                label: Text(s.t('replay')),
              ),
            const SizedBox(height: 20),
            Text(
              s.t('moves', {'n': game.moves.length}),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: online.busy ? null : _leave,
              icon: Icon(closed ? Icons.home_outlined : Icons.logout_rounded),
              label: Text(s.t(closed ? 'returnHome' : 'leaveRoom')),
            ),
          ],
        ),
      ),
    );
    return PageFrame(
      maxWidth: 1080,
      children: [
        PageHeading(
          title: s.t('friendMatch'),
          subtitle: '${s.t('round', {'n': room.round})} · ${room.code}',
          action: StatusPill(
            label: online.connected ? s.t('online') : s.t('reconnecting'),
            icon: online.connected
                ? Icons.wifi_rounded
                : Icons.wifi_off_rounded,
          ),
        ),
        if (!online.connected && !closed) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(s.t('reconnecting')),
                  TextButton(
                    onPressed: () =>
                        ref.read(onlineProvider.notifier).reconnect(),
                    child: Text(s.t('reconnect')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (room.status == RoomStatus.paused &&
            room.resumeDeadline != null) ...[
          _DisconnectNotice(
            deadline: room.resumeDeadline!,
            serverTime: room.serverTime,
          ),
          const SizedBox(height: 18),
        ],
        if (waiting) ...[
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('waitingFriend'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 14),
                Text(s.t('waitingBody')),
                const SizedBox(height: 28),
                SelectableText(
                  room.code,
                  semanticsLabel:
                      '${s.t('roomCode')}: ${room.code.split('').join(' ')}',
                  style: Theme.of(context).textTheme.displaySmall
                      ?.copyWith(color: colors.primary, letterSpacing: 6),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _copy(room.code),
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(s.t('shareCode')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _copy('${Api.webUrl}/join/${room.code}'),
                      icon: const Icon(Icons.link_rounded),
                      label: Text(s.t('shareLink')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          panel,
        ] else
          GameLayout(
            board: GameBoard(
              game: game,
              settings: ref.watch(settingsProvider),
              enabled: canSend && myTurn && room.undoRequestedBy == null,
              onMove: (row, col) => ref
                  .read(onlineProvider.notifier)
                  .send(RoomAction.move, row: row, col: col),
            ),
            panel: panel,
          ),
      ],
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.name,
    required this.stone,
    required this.mine,
    required this.online,
    required this.ready,
    required this.waiting,
  });
  final String name;
  final Stone stone;
  final bool mine, online, ready, waiting;
  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        StoneDisc(stone: stone, size: 34),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name + (mine ? ' · ${s.t('you')}' : ''),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                s.t(online ? 'online' : 'offline') +
                    (waiting
                        ? ' · ${s.t(ready ? 'isReady' : 'notReady')}'
                        : ''),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (ready && waiting)
          Icon(Icons.check_circle_rounded, color: colors.primary, size: 20),
      ],
    );
  }
}

class _DisconnectNotice extends StatefulWidget {
  const _DisconnectNotice({required this.deadline, required this.serverTime});
  final DateTime deadline, serverTime;
  @override
  State<_DisconnectNotice> createState() => _DisconnectNoticeState();
}

class _DisconnectNoticeState extends State<_DisconnectNotice> {
  late DateTime _received = DateTime.now();
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(_DisconnectNotice old) {
    super.didUpdateWidget(old);
    if (old.serverTime != widget.serverTime) _received = DateTime.now();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = math.max(
      0,
      widget.deadline.difference(widget.serverTime).inSeconds -
          DateTime.now().difference(_received).inSeconds,
    );
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        context.strings.t('disconnectBody', {'seconds': seconds}),
        style: TextStyle(color: colors.onTertiaryContainer),
      ),
    );
  }
}
