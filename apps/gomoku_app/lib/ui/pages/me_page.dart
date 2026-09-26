import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api.dart';
import '../../design/shape.dart';
import '../../design/tokens.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../state/online.dart';
import '../../state/settings.dart';
import '../kit/card.dart';
import '../kit/scaffold.dart';
import '../widgets/common.dart';
import 'settings_page.dart';

enum _AccountMode { login, register, reset }

/// The me tab: profile header, account, and every preference as FlClash-style
/// sections under a floating toolbar.
class MePage extends ConsumerWidget {
  const MePage({super.key, this.returnTo});
  final String? returnTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final auth = ref.watch(authProvider);
    final sync = ref.watch(syncProvider);
    final profile = auth.profile;
    final signedIn = profile != null && !profile.isGuest;
    final active = ref.watch(activeRoomProvider).asData?.value;
    final capabilities = ref.watch(serviceConfigProvider);
    final allowEmail = capabilities.asData?.value.authMode == 'email';
    final status = signedIn
        ? (sync.busy
              ? 'syncing'
              : sync.lastSuccess != null && sync.error == null
              ? 'synced'
              : 'syncPending')
        : 'guestLocal';
    return KitScaffold(
      title: s.t('tabMe'),
      child: KitPageBody(
        maxWidth: AppLayout.reading,
        scrollKey: const PageStorageKey('me-scroll'),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.section),
            decoration: ShapeDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              shape: AppShapes.feature,
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: signedIn
                        ? Theme.of(context).colorScheme.tertiaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: signedIn
                        ? null
                        : Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                  ),
                  child: ExcludeSemantics(
                    child: !signedIn || profile.nickname.isEmpty
                        ? Icon(
                            Icons.person_outline_rounded,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          )
                        : Text(
                            profile.nickname.characters.first.toUpperCase(),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onTertiaryContainer,
                                ),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.content),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.nickname ?? s.t('guest'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.tight),
                      Text(
                        s.t(
                          signedIn
                              ? status
                              : allowEmail
                              ? 'guestNotice'
                              : 'privateAccountNotice',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (active != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.t('accountActiveRoom')),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () =>
                          context.pushReplacement('/room/${active.roomId}'),
                      child: Text(s.t('continueGame')),
                    ),
                  ],
                ),
              ),
            ),
          if (capabilities.hasError)
            KitNotice(
              message: s.t('connectionUnavailable'),
              action: TextButton(
                onPressed: () => ref.invalidate(serviceConfigProvider),
                child: Text(s.t('retry')),
              ),
            ),
          signedIn
              ? _AccountCard(blocked: active != null)
              : _AuthCard(returnTo: returnTo, blocked: active != null),
          const _PaletteCard(),
          const _AppearanceGroup(),
          const PlayingPreferences(),
          const _AccessibilityGroup(),
          Text(
            s.t('aboutBody'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends ConsumerStatefulWidget {
  const _AccountCard({required this.blocked});
  final bool blocked;
  @override
  ConsumerState<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<_AccountCard> {
  late final TextEditingController _nickname;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController(
      text: ref.read(authProvider).profile?.nickname ?? '',
    );
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final s = context.strings;
    if (!await confirmAction(
      context,
      s.t('logoutTitle'),
      s.t('logoutBody'),
      confirmLabel: s.t('logout'),
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(syncProvider.notifier).sync();
      await ref.read(authProvider.notifier).logout();
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final sync = ref.watch(syncProvider);
    return KitCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.t('accountDetails'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('account-nickname'),
            controller: _nickname,
            maxLength: 24,
            enabled: !_busy && !widget.blocked,
            decoration: InputDecoration(labelText: s.t('nickname')),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: _busy || widget.blocked
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await ref
                              .read(authProvider.notifier)
                              .rename(_nickname.text.trim());
                        } catch (error) {
                          if (context.mounted) showFailure(context, error);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                icon: const Icon(Icons.check_rounded),
                label: Text(s.t('save')),
              ),
              FilledButton.icon(
                onPressed: sync.busy
                    ? null
                    : () => ref.read(syncProvider.notifier).sync(),
                icon: const Icon(Icons.sync_rounded),
                label: Text(s.t(sync.busy ? 'syncing' : 'sync')),
              ),
            ],
          ),
          if (sync.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                s.error(sync.error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Divider(),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy || widget.blocked ? null : _logout,
              icon: const Icon(Icons.logout_rounded),
              label: Text(s.t('logout')),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthCard extends ConsumerStatefulWidget {
  const _AuthCard({required this.returnTo, required this.blocked});
  final String? returnTo;
  final bool blocked;
  @override
  ConsumerState<_AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends ConsumerState<_AuthCard> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  late final TextEditingController _nickname;
  _AccountMode _mode = _AccountMode.login;
  String? _requestId;
  bool _busy = false;
  bool _obscure = true;
  String? _serverError, _errorField;

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController(
      text:
          ref.read(authProvider).profile?.nickname ??
          ref.read(preferencesProvider).getString('nickname') ??
          '',
    );
  }

  @override
  void dispose() {
    for (final controller in [_email, _password, _code, _nickname]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setMode(_AccountMode mode) {
    setState(() {
      _mode = mode;
      _requestId = null;
      _code.clear();
      _password.clear();
      _serverError = null;
      _errorField = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _serverError = null;
      _errorField = null;
    });
    final auth = ref.read(authProvider.notifier);
    try {
      switch (_mode) {
        case _AccountMode.login:
          await auth.login(_email.text.trim(), _password.text);
          if (!mounted) return;
          _nickname.text = ref.read(authProvider).profile!.nickname;
          TextInput.finishAutofillContext();
          final target = widget.returnTo;
          if (mounted &&
              target != null &&
              (target == '/lobby' ||
                  RegExp(r'^/join/[A-Za-z0-9]{6}$').hasMatch(target))) {
            context.go(target);
          }
        case _AccountMode.register:
          if (_requestId == null) {
            final request = await auth.startRegistration(_email.text.trim());
            if (mounted) setState(() => _requestId = request);
          } else {
            await auth.finishRegistration(
              _requestId!,
              _code.text.trim(),
              _password.text,
              _nickname.text.trim(),
            );
            TextInput.finishAutofillContext();
          }
        case _AccountMode.reset:
          if (_requestId == null) {
            final request = await auth.startReset(_email.text.trim());
            if (mounted) setState(() => _requestId = request);
          } else {
            await auth.finishReset(
              _requestId!,
              _code.text.trim(),
              _password.text,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.strings.t('resetDone'))),
              );
              _setMode(_AccountMode.login);
            }
          }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          final code = errorCode(error);
          _serverError = context.strings.error(code);
          _errorField = code == 'invalid_credentials'
              ? 'password'
              : code == 'invalid_verification'
              ? 'code'
              : code == 'invalid_nickname'
              ? 'nickname'
              : 'form';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final colors = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final capabilities = ref.watch(serviceConfigProvider);
    final allowEmail = capabilities.asData?.value.authMode == 'email';
    final verify = _requestId != null;
    final modeTitle = switch (_mode) {
      _AccountMode.login => 'login',
      _AccountMode.register => 'register',
      _AccountMode.reset => 'resetPassword',
    };
    final submitLabel = _mode == _AccountMode.login
        ? 'login'
        : !verify
        ? 'sendCode'
        : _mode == _AccountMode.register
        ? 'completeRegistration'
        : 'resetPassword';
    return KitCard(
      padding: const EdgeInsets.all(20),
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.t(modeTitle),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (_mode != _AccountMode.login) ...[
                Text(
                  s.t(verify ? 'verifyStep' : 'emailStep'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_mode != _AccountMode.reset && !verify && allowEmail) ...[
                SegmentedButton<_AccountMode>(
                  showSelectedIcon: false,
                  segments: [
                    for (final mode in [
                      _AccountMode.login,
                      _AccountMode.register,
                    ])
                      ButtonSegment(
                        value: mode,
                        label: Text(
                          s.t(
                            mode == _AccountMode.login ? 'login' : 'register',
                          ),
                        ),
                      ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: _busy
                      ? null
                      : (value) => _setMode(value.single),
                ),
                const SizedBox(height: 22),
              ],
              TextFormField(
                key: const ValueKey('account-email'),
                controller: _email,
                enabled: !_busy && !verify && !widget.blocked,
                autofillHints: const [AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: s.t('email'),
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                ),
                validator: (value) =>
                    value != null &&
                        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(
                          value.trim(),
                        )
                    ? null
                    : s.t('emailError'),
              ),
              if (verify) ...[
                const SizedBox(height: 18),
                Text(
                  s.t('verificationBody'),
                  style: TextStyle(color: colors.primary),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const ValueKey('verification-code'),
                  controller: _code,
                  enabled: !_busy && !widget.blocked,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: s.t('verificationCode'),
                    errorText: _errorField == 'code' ? _serverError : null,
                    prefixIcon: const Icon(Icons.mark_email_read_outlined),
                  ),
                  onChanged: (_) {
                    if (_errorField == 'code') {
                      setState(() => _errorField = null);
                    }
                  },
                  validator: (value) => value != null && value.trim().isNotEmpty
                      ? null
                      : s.t('codeError'),
                ),
              ],
              if (_mode == _AccountMode.login || verify) ...[
                const SizedBox(height: 18),
                _passwordField(enabled: !_busy && !widget.blocked),
              ],
              if (_mode == _AccountMode.register && verify) ...[
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nickname,
                  enabled: !_busy && !widget.blocked,
                  maxLength: 24,
                  autofillHints: const [AutofillHints.nickname],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: s.t('nickname'),
                    errorText: _errorField == 'nickname' ? _serverError : null,
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
                ),
              ],
              if (_serverError != null && _errorField == 'form') ...[
                const SizedBox(height: 18),
                KitNotice(message: _serverError!, error: true),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('account-submit'),
                onPressed:
                    !_busy &&
                        !widget.blocked &&
                        !auth.resolving &&
                        capabilities.asData != null
                    ? _submit
                    : null,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _mode == _AccountMode.login
                            ? Icons.login_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                label: Text(s.t(submitLabel)),
              ),
              const SizedBox(height: 10),
              if (_mode == _AccountMode.login && allowEmail)
                TextButton(
                  onPressed: _busy ? null : () => _setMode(_AccountMode.reset),
                  child: Text(s.t('forgotPassword')),
                )
              else if (allowEmail)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _setMode(verify ? _mode : _AccountMode.login),
                  child: Text(s.t(verify ? 'editEmail' : 'back')),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordField({required bool enabled}) {
    final s = context.strings;
    return TextFormField(
      key: const ValueKey('account-password'),
      controller: _password,
      enabled: enabled,
      obscureText: _obscure,
      autofillHints: [
        _mode == _AccountMode.login
            ? AutofillHints.password
            : AutofillHints.newPassword,
      ],
      keyboardType: null,
      textInputAction: _mode == _AccountMode.register
          ? TextInputAction.next
          : TextInputAction.done,
      onFieldSubmitted: (_) {
        if (_mode != _AccountMode.register) _submit();
      },
      decoration: InputDecoration(
        labelText: s.t('password'),
        errorText: _errorField == 'password' ? _serverError : null,
        helperText: _mode == _AccountMode.login ? null : s.t('passwordHint'),
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: s.t(_obscure ? 'showPassword' : 'hidePassword'),
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      onChanged: (_) {
        if (_errorField == 'password') {
          setState(() => _errorField = null);
        }
      },
      validator: (value) =>
          value != null && value.length >= (_mode == _AccountMode.login ? 1 : 8)
          ? null
          : s.t(_mode == _AccountMode.login ? 'passwordError' : 'passwordHint'),
    );
  }
}

class _PaletteCard extends ConsumerWidget {
  const _PaletteCard();

  Future<void> _update(
    BuildContext context,
    WidgetRef ref,
    AppSettings value,
  ) async {
    try {
      await ref.read(settingsProvider.notifier).update(value);
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final dynamicSupported = DesignCapabilities.supportsDynamicColor(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.section),
      decoration: ShapeDecoration(
        color: colors.tertiaryContainer,
        shape: AppShapes.feature,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('colorPreview'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: colors.onTertiaryContainer,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            s.t('preferencesCaption'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.onTertiaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (key, seed) in [
                ('iris', 0xff7560c7),
                ('sage', 0xff526e57),
                ('peach', 0xffa45439),
                ('ocean', 0xff376a91),
              ])
                Tooltip(
                  excludeFromSemantics: true,
                  message: s.t(key),
                  child: Semantics(
                    button: true,
                    selected:
                        !(settings.dynamicColor && dynamicSupported) &&
                        settings.seed == seed,
                    label: s.t(key),
                    child: InkResponse(
                      onTap: () => _update(
                        context,
                        ref,
                        settings.copyWith(seed: seed, dynamicColor: false),
                      ),
                      radius: 30,
                      child: AnimatedContainer(
                        duration: AppMotion.duration(
                          context,
                          AppMotion.feedback,
                        ),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Color(seed),
                          borderRadius: BorderRadius.circular(AppShape.card),
                        ),
                        child:
                            settings.seed == seed &&
                                !(settings.dynamicColor && dynamicSupported)
                            ? Center(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.surface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: SizedBox.square(
                                    dimension: 28,
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (settings.dynamicColor && dynamicSupported) ...[
            const SizedBox(height: AppSpacing.content),
            Text(s.t('colorFromSystem')),
          ],
        ],
      ),
    );
  }
}

class _AppearanceGroup extends ConsumerWidget {
  const _AppearanceGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final settings = ref.watch(settingsProvider);
    final dynamicSupported = DesignCapabilities.supportsDynamicColor(context);
    Future<void> update(AppSettings value) async {
      try {
        await ref.read(settingsProvider.notifier).update(value);
      } catch (error) {
        if (context.mounted) showFailure(context, error);
      }
    }

    return KitSection(
      title: s.t('appearanceSection'),
      children: [
        KitListTile(
          icon: Icons.contrast_rounded,
          title: s.t('theme'),
          subtitle: s.t(settings.theme.name),
          onTap: () async {
            final value = await showChoice<ThemeMode>(
              context,
              title: s.t('theme'),
              value: settings.theme,
              choices: [
                for (final mode in ThemeMode.values) (mode, s.t(mode.name)),
              ],
            );
            if (value != null && context.mounted) {
              await update(ref.read(settingsProvider).copyWith(theme: value));
            }
          },
        ),
        if (dynamicSupported)
          KitListTile.toggle(
            icon: Icons.palette_outlined,
            title: s.t('dynamicColor'),
            subtitle: s.t('dynamicColorBody'),
            value: settings.dynamicColor,
            onValueChanged: (value) =>
                update(settings.copyWith(dynamicColor: value)),
          ),
      ],
    );
  }
}

class _AccessibilityGroup extends ConsumerWidget {
  const _AccessibilityGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final settings = ref.watch(settingsProvider);
    Future<void> update(AppSettings value) async {
      try {
        await ref.read(settingsProvider.notifier).update(value);
      } catch (error) {
        if (context.mounted) showFailure(context, error);
      }
    }

    return KitSection(
      title: s.t('accessibilitySection'),
      children: [
        KitListTile(
          icon: Icons.language_rounded,
          title: s.t('language'),
          subtitle: s.t(settings.language),
          onTap: () async {
            final value = await showChoice<String>(
              context,
              title: s.t('language'),
              value: settings.language,
              choices: [
                for (final language in ['system', 'zh', 'en'])
                  (language, s.t(language)),
              ],
            );
            if (value != null && context.mounted) {
              await update(
                ref.read(settingsProvider).copyWith(language: value),
              );
            }
          },
        ),
        KitListTile.toggle(
          icon: Icons.animation_rounded,
          title: s.t('reduceMotion'),
          subtitle: s.t('reduceMotionBody'),
          value: settings.reduceMotion,
          onValueChanged: (value) =>
              update(settings.copyWith(reduceMotion: value)),
        ),
      ],
    );
  }
}
