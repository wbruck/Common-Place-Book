import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_service.dart';

/// Which credential flow the [LoginScreen] is currently presenting.
enum AuthMode {
  /// Signing an existing account in.
  signIn,

  /// Creating a new account.
  signUp,
}

/// Email + password sign-up / sign-in screen (US-005).
///
/// Reachable from Settings via the `/login` named route; logged-out users are
/// never forced here (the app stays fully usable without an account). The
/// screen validates input client-side and surfaces backend [AuthFailure]s as
/// readable messages rather than raw exceptions.
///
/// [authService] is injectable so widget tests can supply a fake without
/// touching the network or `Supabase.initialize`. When omitted it is read from
/// the app-level [RepositoryProvider] (the single instance shared with
/// Settings), which was built after `main()` initialized Supabase.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, AuthService? authService})
      : _injectedAuthService = authService;

  final AuthService? _injectedAuthService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final AuthService _authService;

  AuthMode _mode = AuthMode.signIn;
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  /// Set after a sign-up that created an account but withheld a session pending
  /// email confirmation. Drives a persistent inline banner (not a transient
  /// SnackBar) so the user understands sign-up succeeded and what to do next.
  bool _confirmationPending = false;

  /// Minimum password length enforced client-side before hitting the backend.
  static const int _minPasswordLength = 6;

  bool get _isSignIn => _mode == AuthMode.signIn;

  @override
  void initState() {
    super.initState();
    _authService =
        widget._injectedAuthService ?? context.read<AuthService>();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Please enter your email.';
    }
    // Pragmatic email check: a single @ with non-empty local and domain parts
    // and a dot in the domain. Server-side validation remains authoritative.
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Please enter your password.';
    }
    if (password.length < _minPasswordLength) {
      return 'Password must be at least $_minPasswordLength characters.';
    }
    return null;
  }

  void _toggleMode() {
    setState(() {
      _mode = _isSignIn ? AuthMode.signUp : AuthMode.signIn;
      // Leaving the screen state the user explicitly changed; clear the
      // confirmation banner only when they head back into sign-up.
      if (!_isSignIn) {
        _confirmationPending = false;
      }
    });
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    // Capture which flow we ran before awaiting, so a mode toggle mid-request
    // can't misroute the result.
    final wasSignIn = _isSignIn;

    setState(() {
      _isSubmitting = true;
      _confirmationPending = false;
    });

    if (wasSignIn) {
      final result =
          await _authService.signInWithEmail(email: email, password: password);
      if (!mounted) {
        return;
      }
      setState(() => _isSubmitting = false);
      result.fold(
        onSuccess: (_) {
          // A successful sign-in always carries an active session.
          _showMessage('Signed in successfully.');
          _leaveOnSignedIn();
        },
        onFailure: (failure) => _showMessage(failure.message, isError: true),
      );
      return;
    }

    final result =
        await _authService.signUpWithEmail(email: email, password: password);
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);
    result.fold(
      onSuccess: (signUp) {
        if (signUp.isSignedIn) {
          // Confirmation disabled: an active session exists, navigate away.
          _showMessage('Account created. You are signed in.');
          _leaveOnSignedIn();
          return;
        }
        // Confirmation pending: the account exists but no session yet. Stay on
        // the screen, switch to sign-in mode, and show a persistent banner so
        // it never looks like sign-up silently failed.
        setState(() {
          _mode = AuthMode.signIn;
          _confirmationPending = true;
          _passwordController.clear();
        });
      },
      onFailure: (failure) => _showMessage(failure.message, isError: true),
    );
  }

  /// Pops back to the caller (Settings) or, failing that, routes home. Used
  /// only when an active session exists.
  void _leaveOnSignedIn() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _sendPasswordReset() async {
    // Only the email field is required for a reset; validate it in isolation.
    final emailError = _validateEmail(_emailController.text);
    if (emailError != null) {
      _showMessage(
        'Enter your email above first, then tap "Forgot password?".',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final result =
        await _authService.sendPasswordResetEmail(_emailController.text.trim());

    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    result.fold(
      onSuccess: (_) => _showMessage(
        'If that email has an account, a reset link is on its way.',
      ),
      onFailure: (failure) => _showMessage(failure.message, isError: true),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? theme.colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignIn ? 'Sign in' : 'Create account'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.cloud_sync_outlined,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sync across your devices',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to back up your entries and keep every device '
                      'up to date. You can keep using the app without an '
                      'account.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_confirmationPending) ...[
                      const SizedBox(height: 24),
                      _ConfirmationPendingBanner(),
                    ],
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'you@example.com',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_isSubmitting,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _isSubmitting ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: _isSubmitting
                              ? null
                              : () => setState(
                                    () =>
                                        _obscurePassword = !_obscurePassword,
                                  ),
                        ),
                      ),
                      validator: _validatePassword,
                    ),
                    if (_isSignIn) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isSubmitting ? null : _sendPasswordReset,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isSignIn ? 'Sign in' : 'Create account'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isSubmitting ? null : _toggleMode,
                      child: Text(
                        _isSignIn
                            ? "Don't have an account? Create one"
                            : 'Already have an account? Sign in',
                      ),
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
}

/// Persistent inline banner shown after a sign-up that requires email
/// confirmation before a session is issued (the Supabase default).
///
/// Unlike a transient SnackBar this stays on screen, so the user clearly
/// understands the account was created and that the next step is to confirm
/// their email and then sign in.
class _ConfirmationPendingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.mark_email_unread_outlined,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Check your email to confirm',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your account was created. Open the confirmation link we '
                  'sent, then sign in below.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
