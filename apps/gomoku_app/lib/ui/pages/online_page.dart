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
import '../../design/tokens.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../state/online.dart';
import '../../state/settings.dart';
import '../shell.dart';
import '../widgets/board.dart';
import '../widgets/common.dart';
import '../widgets/game_layout.dart';
import 'settings_page.dart';

class OnlinePage extends ConsumerStatefulWidget {
  const OnlinePage({super.key, required this.roomId});
  final String roomId;
  @override
  ConsumerState<OnlinePage> createState() => _OnlinePageState();
}

class _OnlinePageState extends ConsumerState<OnlinePage> {
  final _boardKey = GlobalKey(debugLabel: 'online-board');
  final _interaction = BoardInteractionController();
  Object? _error;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _interaction.dispose();
    super.dispose();
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

  Widget _roomInfo(RoomSnapshot room) {
    final s = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.t('roomDetails'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        SelectableText(
          room.code,
          semanticsLabel:
              '${s.t('roomCode')}: ${room.code.split('').join(' ')}',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(letterSpacing: 3),
        ),
        const SizedBox(height: 8),
        Text(s.t('round', {'n': room.round})),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            IconButton.filledTonal(
              tooltip: s.t('shareCode'),
              onPressed: () => _copy(room.code),
              icon: const Icon(Icons.copy_rounded),
            ),
            IconButton.filledTonal(
              tooltip: s.t('shareLink'),
              onPressed: () => _copy('${Api.webUrl}/join/${room.code}'),
              icon: const Icon(Icons.link_rounded),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(onlineProvider);
    final room = online.room?.roomId == widget.roomId ? online.room : null;
    final s = context.strings;
    final colors = Theme.of(context).colorScheme;
    if (room == null) {
      final auth = ref.watch(authProvider);
      final needsLogin =
          !auth.resolving && !auth.hasSession && auth.profile == null;
      final error =
          _error ?? (needsLogin ? const ApiFailure('login_required') : null);
      return SectionScaffold(
        title: s.t('friendMatch'),
        compact: true,
        child: error == null
            ? const Center(child: CircularProgressIndicator())
            : PageFrame(
                children: [
                  InlineNotice(
                    message: s.error(errorCode(error)),
                    error: true,
                    action: TextButton(
                      onPressed: _load,
                      child: Text(s.t('retry')),
                    ),
                  ),
                  if (needsLogin)
                    FilledButton.icon(
                      onPressed: () => context.go('/account?returnTo=%2Flobby'),
                      icon: const Icon(Icons.login_rounded),
                      label: Text(s.t('login')),
                    ),
                  TextButton(
                    onPressed: () => context.go('/lobby'),
                    child: Text(s.t('joinRoom')),
                  ),
                ],
              ),
      );
    }
    final game = GameState.fromJson(
      jsonDecode(room.gameJson) as Map<String, dynamic>,
    );
    final player = ref.watch(authProvider).profile?.playerId;
    final isHost = room.hostPlayerId == player;
    final hostBlack = room.blackPlayerId == room.hostPlayerId;
    final myStone = room.blackPlayerId == player ? Stone.black : Stone.white;
    final myReady = isHost ? room.hostReady : room.guestReady;
    final waiting = room.status == RoomStatus.waiting;
    final playing = room.status == RoomStatus.playing;
    final closed = room.status == RoomStatus.closed;
    final finished = room.status == RoomStatus.finished;
    final canSend = online.connected && !online.busy && !closed;
    final myTurn = playing && game.turn == myStone;
    final label = closed
        ? s.t('closedRoom')
        : game.isOver
        ? s.t('finished')
        : room.status == RoomStatus.paused
        ? s.t('paused')
        : waiting
        ? s.t('waitingSeat')
        : s.t(myTurn ? 'yourTurn' : 'theirTurn');
    final reconnecting = !online.connected && !closed
        ? InlineNotice(
            message: s.t('reconnecting'),
            icon: Icons.wifi_off_rounded,
            action: TextButton(
              onPressed: () => ref.read(onlineProvider.notifier).reconnect(),
              child: Text(s.t('reconnect')),
            ),
          )
        : null;

    final menu = PopupMenuButton<String>(
      tooltip: s.t('gameOptions'),
      onSelected: (action) async {
        switch (action) {
          case 'settings':
            await showGameSettings(context);
          case 'room':
            await showModalBottomSheet<void>(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              constraints: const BoxConstraints(maxWidth: AppLayout.reading),
              builder: (context) => SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _roomInfo(room),
                ),
              ),
            );
          case 'resign':
            if (await confirmAction(
              context,
              s.t('resignTitle'),
              s.t('resignBody'),
              confirmLabel: s.t('resign'),
            )) {
              await _send(RoomAction.resign);
            }
          case 'leave':
            await _leave();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'room', child: Text(s.t('roomDetails'))),
        PopupMenuItem(value: 'settings', child: Text(s.t('gameSettings'))),
        if (playing || room.status == RoomStatus.paused)
          PopupMenuItem(
            value: 'resign',
            enabled: canSend,
            child: Text(s.t('resign')),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'leave',
          enabled: !online.busy,
          child: Text(s.t(closed ? 'returnHome' : 'leaveRoom')),
        ),
      ],
    );

    if (waiting) {
      return SectionScaffold(
        title: s.t('friendMatch'),
        actions: [menu],
        child: PageFrame(
          maxWidth: AppLayout.reading,
          children: [
            PageHeading(
              title: s.t('inviteTitle'),
              subtitle: s.t('waitingBody'),
            ),
            if (reconnecting != null) ...[
              reconnecting,
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(AppSpacing.section),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(AppShape.feature),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('roomCode'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    room.code,
                    semanticsLabel:
                        '${s.t('roomCode')}: ${room.code.split('').join(' ')}',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _copy(room.code),
                        icon: const Icon(Icons.copy_rounded),
                        label: Text(s.t('shareCode')),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _copy('${Api.webUrl}/join/${room.code}'),
                        icon: const Icon(Icons.link_rounded),
                        label: Text(s.t('shareLink')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SettingsGroup(
              title: s.t('readyCaption'),
              children: [
                _ReadySeat(
                  name: room.hostName,
                  stone: hostBlack ? Stone.black : Stone.white,
                  mine: isHost,
                  online: room.hostConnected,
                  ready: room.hostReady,
                ),
                _ReadySeat(
                  name: room.guestName ?? s.t('waitingSeat'),
                  stone: hostBlack ? Stone.white : Stone.black,
                  mine: !isHost,
                  online: room.guestConnected,
                  ready: room.guestReady,
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('ready-room'),
              onPressed: canSend && !myReady
                  ? () => _send(RoomAction.ready)
                  : null,
              icon: Icon(
                myReady ? Icons.check_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(s.t(myReady ? 'isReady' : 'ready')),
            ),
          ],
        ),
      );
    }

    if (closed && !game.isOver) {
      return SectionScaffold(
        title: s.t('friendMatch'),
        child: PageFrame(
          children: [
            InlineNotice(message: s.t('closedRoom')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/'),
              child: Text(s.t('returnHome')),
            ),
          ],
        ),
      );
    }

    final status = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerStrip(
          blackName: hostBlack ? room.hostName : room.guestName ?? s.t('white'),
          whiteName: hostBlack ? room.guestName ?? s.t('white') : room.hostName,
          blackOnline: hostBlack ? room.hostConnected : room.guestConnected,
          whiteOnline: hostBlack ? room.guestConnected : room.hostConnected,
          label: label,
          moves: game.moves.length,
          activeStone: playing ? game.turn : null,
        ),
        if (reconnecting != null) ...[const SizedBox(height: 12), reconnecting],
        if (room.status == RoomStatus.paused &&
            room.resumeDeadline != null) ...[
          const SizedBox(height: 12),
          _DisconnectNotice(
            deadline: room.resumeDeadline!,
            serverTime: room.serverTime,
          ),
        ],
        if (playing && room.undoRequestedBy != null) ...[
          const SizedBox(height: 12),
          InlineNotice(
            icon: Icons.undo_rounded,
            message: s.t(
              room.undoRequestedBy == player ? 'undoWaiting' : 'undoIncoming',
            ),
            action: room.undoRequestedBy == player
                ? null
                : Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: canSend
                            ? () => _send(RoomAction.rejectUndo)
                            : null,
                        child: Text(s.t('decline')),
                      ),
                      FilledButton.tonal(
                        onPressed: canSend
                            ? () => _send(RoomAction.acceptUndo)
                            : null,
                        child: Text(s.t('accept')),
                      ),
                    ],
                  ),
          ),
        ],
      ],
    );

    return GameScaffold(
      title: s.t('friendMatch'),
      actions: [menu],
      board: GameBoard(
        key: _boardKey,
        game: game,
        settings: ref.watch(settingsProvider),
        interaction: _interaction,
        showControls: false,
        enabled: canSend && myTurn && room.undoRequestedBy == null,
        onMove: (row, col) => ref
            .read(onlineProvider.notifier)
            .send(RoomAction.move, row: row, col: col),
      ),
      status: status,
      controls: game.isOver
          ? ResultMoment(
              key: ValueKey(room.gameId),
              gameId: room.gameId,
              label: resultLabel(game, s),
              child: EndGameActions(
                primaryLabel: s.t(
                  closed
                      ? 'returnHome'
                      : myReady
                      ? 'rematchWaiting'
                      : 'rematch',
                ),
                onPrimary: closed
                    ? () => context.go('/')
                    : finished && canSend && !myReady
                    ? () => _send(RoomAction.rematch)
                    : null,
                onReplay: () => context.push('/history/${room.gameId}'),
              ),
            )
          : MoveControls(
              interaction: _interaction,
              message: !canSend || !myTurn ? label : null,
              undo: IconButton.filledTonal(
                tooltip: s.t('undoRequest'),
                onPressed:
                    playing &&
                        canSend &&
                        room.undoRequestedBy == null &&
                        game.moves.any((move) => move.stone == myStone)
                    ? () => _send(RoomAction.requestUndo)
                    : null,
                icon: const Icon(Icons.undo_rounded),
              ),
            ),
      details: _roomInfo(room),
    );
  }
}

class _ReadySeat extends StatelessWidget {
  const _ReadySeat({
    required this.name,
    required this.stone,
    required this.mine,
    required this.online,
    required this.ready,
  });
  final String name;
  final Stone stone;
  final bool mine, online, ready;
  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return ListTile(
      leading: StoneDisc(stone: stone, size: 32),
      title: Text(name + (mine ? ' · ${s.t('you')}' : '')),
      subtitle: Text(
        '${s.t(online ? 'online' : 'offline')} · ${s.t(ready ? 'isReady' : 'notReady')}',
      ),
      trailing: ready
          ? Icon(
              Icons.check_circle_rounded,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
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
  DateTime _received = DateTime.now();
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
    return InlineNotice(
      icon: Icons.hourglass_top_rounded,
      message: context.strings.t('disconnectBody', {'seconds': seconds}),
    );
  }
}
