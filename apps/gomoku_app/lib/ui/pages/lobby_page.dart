import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gomoku_client/gomoku_client.dart';

import '../../data/api.dart';
import '../../design/shape.dart';
import '../../design/tokens.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../state/online.dart';
import '../../state/settings.dart';
import '../widgets/common.dart';
import '../widgets/enter.dart';
import '../widgets/press.dart';

class LobbyPage extends ConsumerStatefulWidget {
  const LobbyPage({super.key, this.initialCode = ''});
  final String initialCode;
  @override
  ConsumerState<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends ConsumerState<LobbyPage> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(
    text: widget.initialCode.toUpperCase(),
  );
  late final _nickname = TextEditingController(
    text:
        ref.read(authProvider).profile?.nickname ??
        ref.read(preferencesProvider).getString('nickname') ??
        '',
  );
  late bool _joining = widget.initialCode.isNotEmpty;
  bool _busy = false;
  bool _initializedName = false;
  String? _error, _errorField;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedName) {
      _initializedName = true;
      if (_nickname.text.isEmpty) {
        final scope =
            ref.read(preferencesProvider).getString('guestScope') ?? 'guest';
        final suffix = scope.split(':').last.characters.take(4).toString();
        _nickname.text = context.strings.t('guestName', {'suffix': suffix});
      }
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorField = null;
    });
    try {
      final name = _nickname.text.trim();
      final profile = ref.read(authProvider).profile;
      if (profile != null && profile.nickname != name) {
        await ref.read(authProvider.notifier).rename(name);
      } else {
        await ref.read(preferencesProvider).setString('nickname', name);
      }
      final controller = ref.read(onlineProvider.notifier);
      final room = _joining
          ? await controller.join(_code.text)
          : await controller.create();
      if (mounted) context.pushReplacement('/room/${room.roomId}');
    } catch (error) {
      if (mounted) {
        setState(() {
          final code = errorCode(error);
          _error = context.strings.error(code);
          _errorField = code == 'invalid_nickname'
              ? 'nickname'
              : [
                  'invalid_room_code',
                  'room_not_found',
                  'room_expired',
                ].contains(code)
              ? 'code'
              : 'form';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinOpen(RoomSnapshot room) async {
    setState(() {
      _joining = true;
      _code.text = room.code;
    });
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      final profile = next.profile;
      if (profile != null && previous?.profile?.playerId != profile.playerId) {
        _nickname.text = profile.nickname;
      }
    });
    final s = context.strings;
    final colors = Theme.of(context).colorScheme;
    final openRooms = ref.watch(lobbyRoomsProvider).asData?.value;
    final active = ref.watch(activeRoomProvider).asData?.value;
    final health = ref.watch(backendHealthProvider);
    final capabilities = ref.watch(serviceConfigProvider);
    final config = capabilities.asData?.value;
    if (config == null) {
      return PageFrame(
        maxWidth: AppLayout.reading,
        children: [
          PageHeading(title: s.t('lobbyTitle'), subtitle: s.t('lobbyBody')),
          if (widget.initialCode.isNotEmpty)
            Text('${s.t('roomCode')}: ${_code.text}'),
          const SizedBox(height: 20),
          InlineNotice(
            message: s.t(
              capabilities.hasError ? 'connectionUnavailable' : 'connecting',
            ),
            action: TextButton(
              onPressed: () => ref.invalidate(serviceConfigProvider),
              child: Text(s.t('retry')),
            ),
          ),
        ],
      );
    }
    return PageFrame(
      maxWidth: AppLayout.reading,
      children: [
        PageHeading(title: s.t('lobbyTitle'), subtitle: s.t('lobbyBody')),
        if (active != null) ...[
          InlineNotice(
            message: s.error('active_room'),
            action: FilledButton.tonal(
              onPressed: () =>
                  context.pushReplacement('/room/${active.roomId}'),
              child: Text(s.t('returnRoom')),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (health.hasError || health.asData?.value == false) ...[
          InlineNotice(
            message: s.t('connectionUnavailable'),
            icon: Icons.wifi_off_rounded,
            action: TextButton(
              onPressed: () => ref.invalidate(backendHealthProvider),
              child: Text(s.t('retry')),
            ),
          ),
          const SizedBox(height: 20),
        ],
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(s.t('createRoom'))),
            ButtonSegment(value: true, label: Text(s.t('joinRoom'))),
          ],
          selected: {_joining},
          showSelectedIcon: false,
          onSelectionChanged: _busy
              ? null
              : (value) => setState(() {
                  _joining = value.single;
                  _error = null;
                  _errorField = null;
                }),
        ),
        const SizedBox(height: 20),
        if (openRooms != null && openRooms.isNotEmpty) ...[
          Text(
            s.t('openRoomsTitle'),
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: colors.primary),
          ),
          const SizedBox(height: 12),
          for (final (index, room) in openRooms.indexed)
            StaggeredEnter(
              delay: enterStagger(index),
              child: Pressable(
                onTap: _busy ? null : () => _joinOpen(room),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: Text(
                      s.t('openRoomsBody', {'name': room.hostName}),
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: _busy ? null : () => _joinOpen(room),
                      child: Text(s.t('join')),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
        ],
        Container(
          padding: const EdgeInsets.all(AppSpacing.section),
          decoration: ShapeDecoration(
            color: colors.secondaryContainer,
            shape: AppShapes.feature,
          ),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.t(_joining ? 'joinRoomBody' : 'createRoomBody'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const ValueKey('room-nickname'),
                  controller: _nickname,
                  maxLength: 24,
                  enabled: !_busy && active == null,
                  textInputAction: _joining
                      ? TextInputAction.next
                      : TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: s.t('nickname'),
                    counterText: '',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    errorText: _errorField == 'nickname' ? _error : null,
                  ),
                  onChanged: (_) {
                    if (_errorField == 'nickname') {
                      setState(() => _errorField = null);
                    }
                  },
                  validator: (value) =>
                      value != null &&
                          value.trim().isNotEmpty &&
                          value.trim().runes.length <= 24
                      ? null
                      : s.error('invalid_nickname'),
                  onFieldSubmitted: (_) {
                    if (!_joining) _start();
                  },
                ),
                if (_joining) ...[
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const ValueKey('join-room-code'),
                    controller: _code,
                    maxLength: 6,
                    enabled: !_busy && active == null,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: s.t('roomCode'),
                      counterText: '',
                      prefixIcon: const Icon(Icons.tag_rounded),
                      errorText: _errorField == 'code' ? _error : null,
                    ),
                    onChanged: (_) {
                      if (_errorField == 'code') {
                        setState(() => _errorField = null);
                      }
                    },
                    validator: (value) =>
                        RegExp(r'^[a-zA-Z0-9]{6}$')
                            .hasMatch(value?.trim() ?? '')
                        ? null
                        : s.error('invalid_room_code'),
                    onFieldSubmitted: (_) => _start(),
                  ),
                ],
                if (_errorField == 'form' && _error != null) ...[
                  const SizedBox(height: 18),
                  InlineNotice(message: _error!, error: true),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: ValueKey(_joining ? 'join-room' : 'create-room'),
                  onPressed: _busy || active != null ? null : _start,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _joining
                              ? Icons.arrow_forward_rounded
                              : Icons.add_rounded,
                        ),
                  label: Text(s.t(_joining ? 'join' : 'createRoom')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          s.t('guestNotice'),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
