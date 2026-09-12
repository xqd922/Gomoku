import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../state/online.dart';
import '../../state/settings.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

class LobbyPage extends ConsumerStatefulWidget {
  const LobbyPage({super.key, this.initialCode = ''});
  final String initialCode;
  @override
  ConsumerState<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends ConsumerState<LobbyPage> {
  late final _code = TextEditingController(text: widget.initialCode);
  late final _nickname = TextEditingController(
    text:
        ref.read(preferencesProvider).getString('nickname') ??
        '棋友 ${ref.read(preferencesProvider).getString('guestScope')!.substring(6, 10)}',
  );
  bool _busy = false;
  @override
  void dispose() {
    _code.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _start(bool join) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final name = _nickname.text.trim();
      if (name.isEmpty || name.runes.length > 24) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.error('invalid_nickname'))),
        );
        return;
      }
      final profile = ref.read(authProvider).profile;
      if (profile != null && profile.nickname != name) {
        await ref.read(authProvider.notifier).rename(name);
      } else {
        await ref.read(preferencesProvider).setString('nickname', name);
      }
      final controller = ref.read(onlineProvider.notifier);
      final room = join
          ? await controller.join(_code.text)
          : await controller.create();
      if (mounted) context.go('/room/${room.roomId}');
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final colors = Theme.of(context).colorScheme;
    final active = ref.watch(activeRoomProvider).asData?.value;
    return PageFrame(
      maxWidth: 860,
      children: [
        PageHeading(title: s.t('lobbyTitle'), subtitle: s.t('lobbyBody')),
        if (active != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('unfinished'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(onlineProvider.notifier).enter(active);
                      context.go('/room/${active.roomId}');
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(s.t('continueGame')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
        ],
        Container(
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(32),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BrandMark(size: 42),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      s.t('createRoom'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nickname,
                maxLength: 24,
                enabled: !_busy && active == null,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: s.t('nickname'),
                  counterText: '',
                  prefixIcon: const Icon(Icons.face_rounded),
                  fillColor: colors.surface,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('create-room'),
                  onPressed: _busy || active != null
                      ? null
                      : () => _start(false),
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: Text(s.t('createRoom')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('joinRoom'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 18),
                TextField(
                  key: const ValueKey('join-room-code'),
                  controller: _code,
                  maxLength: 6,
                  enabled: !_busy && active == null,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: s.t('roomCode'),
                    counterText: '',
                    prefixIcon: const Icon(Icons.tag_rounded),
                    fillColor: colors.surface,
                  ),
                  onSubmitted: (_) => _start(true),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy || active != null
                        ? null
                        : () => _start(true),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(s.t('join')),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          s.t('guestNotice'),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
