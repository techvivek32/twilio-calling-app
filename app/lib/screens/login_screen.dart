import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../core/theme.dart';
import 'shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.session});

  final AppSession? session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final TextEditingController _serverController = TextEditingController(
    text: _session.serverUrl,
  );

  AppSession get _session => widget.session ?? AppSession.instance;

  bool _obscure = true;
  bool _remember = true;
  bool _busy = false;
  bool _testing = false;
  String? _error;
  String? _serverOk;
  String? _serverError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _session.signIn(
        email: _emailController.text,
        password: _passwordController.text,
        serverUrl: _serverController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ShellScreen()),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.xl,
                vertical: AppSpace.xxl,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.business_center_outlined,
                          size: 38,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    Text(
                      'Vision Connect',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    const Text(
                      'Sign in to continue to your workspace.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xxl),

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpace.md),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(
                            AppSpace.radiusField,
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.4,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg),
                    ],

                    const _FieldLabel('Email or Username'),
                    const SizedBox(height: AppSpace.sm),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        hintText: 'Enter your email',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Email or username is required'
                          : null,
                    ),
                    const SizedBox(height: AppSpace.lg),
                    const _FieldLabel('Password'),
                    const SizedBox(height: AppSpace.sm),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      enabled: !_busy,
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Password is required'
                          : null,
                    ),
                    const SizedBox(height: AppSpace.md),
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _remember,
                            onChanged: (v) =>
                                setState(() => _remember = v ?? false),
                          ),
                        ),
                        const SizedBox(width: AppSpace.md),
                        const Expanded(
                          child: Text(
                            'Remember Me',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Flexible(
                          child: TextButton(
                            onPressed: _busy ? null : _showPasswordHelp,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Forgot Password?',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.xl),
                    FilledButton(
                      onPressed: _busy ? null : _login,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Login'),
                                SizedBox(width: AppSpace.sm),
                                Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    const Divider(),
                    const SizedBox(height: AppSpace.md),

                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(
                        bottom: AppSpace.md,
                      ),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: const Text(
                        'Server address',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      subtitle: Text(
                        _session.serverUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      children: [
                        TextFormField(
                          controller: _serverController,
                          enabled: !_busy,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            hintText: 'http://10.0.2.2:3000',
                            prefixIcon: Icon(Icons.dns_outlined),
                          ),
                        ),
                        const SizedBox(height: AppSpace.sm),
                        const Text(
                          'Where the admin panel is running. Use 10.0.2.2 on '
                          'an Android emulator, or the computer’s LAN IP on a '
                          'real device.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpace.md),
                        OutlinedButton.icon(
                          onPressed: _busy || _testing ? null : _testConnection,
                          icon: _testing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : const Icon(Icons.wifi_tethering, size: 20),
                          label: Text(
                            _testing ? 'Testing…' : 'Test connection',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                        if (_serverOk != null) ...[
                          const SizedBox(height: AppSpace.sm),
                          _ServerNote(
                            message: _serverOk!,
                            icon: Icons.check_circle_outline,
                            color: AppColors.success,
                          ),
                        ],
                        if (_serverError != null) ...[
                          const SizedBox(height: AppSpace.sm),
                          _ServerNote(
                            message: _serverError!,
                            icon: Icons.error_outline,
                            color: AppColors.danger,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Verifies the typed address before the user tries to sign in, so a wrong
  /// host is obvious here rather than looking like bad credentials.
  Future<void> _testConnection() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _testing = true;
      _serverOk = null;
      _serverError = null;
    });

    final address = _serverController.text.trim();
    try {
      await _session.api.ping(candidate: address.isEmpty ? null : address);
      if (!mounted) return;
      setState(() {
        _serverOk = 'Connected to ${address.isEmpty ? _session.serverUrl : address}.';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _serverError = error.message);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _showPasswordHelp() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Ask your administrator to reset your password in the admin panel.',
          ),
        ),
      );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// Result line under the "Test connection" button.
class _ServerNote extends StatelessWidget {
  const _ServerNote({
    required this.message,
    required this.icon,
    required this.color,
  });

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            message,
            style: TextStyle(fontSize: 13, height: 1.4, color: color),
          ),
        ),
      ],
    );
  }
}
