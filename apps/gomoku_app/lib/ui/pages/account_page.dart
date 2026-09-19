import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api.dart';
import '../../design/tokens.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../state/online.dart';
import '../../state/settings.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

enum _AccountMode { login, register, reset }

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key, this.returnTo});
  final String? returnTo;
  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
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
    final colors = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final capabilities = ref.watch(serviceConfigProvider);
    final allowEmail = capabilities.asData?.value.authMode == 'email';
    final profile = auth.profile;
    final signedIn = profile != null && !profile.isGuest;
    final sync = ref.watch(syncProvider);
    final active = ref.watch(activeRoomProvider).asData?.value;
    final blocked = active != null;
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
    return PageFrame(
      maxWidth: AppLayout.reading,
      children: [
        PageHeading(title: s.t('accountTitle'), subtitle: s.t('accountBody')),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(AppShape.feature),
          ),
          child: Row(
            children: [
              const BrandMark(size: 44),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.nickname ?? s.t('guest'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.t(
                        signedIn
                            ? (sync.busy
                                  ? 'syncing'
                                  : sync.lastSuccess != null &&
                                        sync.error == null
                                  ? 'synced'
                                  : 'syncPending')
                            : allowEmail
                            ? 'guestNotice'
                            : 'privateAccountNotice',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: colors.onSecondaryContainer),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (blocked) ...[
          const SizedBox(height: 20),
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
        ],
        const SizedBox(height: 22),
        if (capabilities.hasError) ...[
          InlineNotice(
            message: s.t('connectionUnavailable'),
            action: TextButton(
              onPressed: () => ref.invalidate(serviceConfigProvider),
              child: Text(s.t('retry')),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (signedIn)
          Card(
            child: Padding(
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
                    controller: _nickname,
                    maxLength: 24,
                    enabled: !_busy && !blocked,
                    decoration: InputDecoration(labelText: s.t('nickname')),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy || blocked
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                try {
                                  await ref
                                      .read(authProvider.notifier)
                                      .rename(_nickname.text.trim());
                                } catch (error) {
                                  if (context.mounted) {
                                    showFailure(context, error);
                                  }
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
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Divider(),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _busy || blocked ? null : _logout,
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(s.t('logout')),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: Padding(
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
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: colors.primary),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_mode != _AccountMode.reset &&
                          !verify &&
                          allowEmail) ...[
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
                                    mode == _AccountMode.login
                                        ? 'login'
                                        : 'register',
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
                        enabled: !_busy && !verify && !blocked,
                        autofillHints: const [AutofillHints.email],
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: s.t('email'),
                          prefixIcon: const Icon(
                            Icons.alternate_email_rounded,
                          ),
                        ),
                        validator: (value) =>
                            value != null &&
                                RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                ).hasMatch(value.trim())
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
                          enabled: !_busy && !blocked,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: s.t('verificationCode'),
                            errorText: _errorField == 'code'
                                ? _serverError
                                : null,
                            prefixIcon: const Icon(
                              Icons.mark_email_read_outlined,
                            ),
                          ),
                          onChanged: (_) {
                            if (_errorField == 'code') {
                              setState(() => _errorField = null);
                            }
                          },
                          validator: (value) =>
                              value != null && value.trim().isNotEmpty
                              ? null
                              : s.t('codeError'),
                        ),
                      ],
                      if (_mode == _AccountMode.login || verify) ...[
                        const SizedBox(height: 18),
                        _passwordField(enabled: !_busy && !blocked),
                      ],
                      if (_mode == _AccountMode.register && verify) ...[
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _nickname,
                          enabled: !_busy && !blocked,
                          maxLength: 24,
                          autofillHints: const [AutofillHints.nickname],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: s.t('nickname'),
                            errorText: _errorField == 'nickname'
                                ? _serverError
                                : null,
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
                        InlineNotice(message: _serverError!, error: true),
                      ],
                      const SizedBox(height: 24),
                      _submitButton(
                        submitLabel,
                        enabled:
                            !_busy &&
                            !blocked &&
                            !auth.resolving &&
                            capabilities.asData != null,
                      ),
                      const SizedBox(height: 10),
                      if (_mode == _AccountMode.login && allowEmail)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _setMode(_AccountMode.reset),
                          child: Text(s.t('forgotPassword')),
                        )
                      else if (allowEmail)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _setMode(
                                  verify ? _mode : _AccountMode.login,
                                ),
                          child: Text(s.t(verify ? 'editEmail' : 'back')),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
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

  Widget _submitButton(String label, {required bool enabled}) =>
      FilledButton.icon(
        key: const ValueKey('account-submit'),
        onPressed: enabled ? _submit : null,
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
        label: Text(context.strings.t(label)),
      );
}
