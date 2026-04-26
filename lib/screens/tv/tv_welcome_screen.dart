import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../repositories/user_preferences.dart';
import '../../services/sync_service.dart';
import '../playlist_screen.dart';
import '../post_login_choice_screen.dart';
import '../../utils/app_transitions.dart';

enum TvAuthMode { none, login, signup, guest }
enum TvLoginStep { serverUrl, email, password, done }
enum TvSignupStep { serverUrl, displayName, email, password, done }
enum TvGuestStep { displayName, done }

class TvWelcomeScreen extends StatefulWidget {
  const TvWelcomeScreen({super.key});

  @override
  State<TvWelcomeScreen> createState() => _TvWelcomeScreenState();
}

class _TvWelcomeScreenState extends State<TvWelcomeScreen> {
  TvAuthMode _mode = TvAuthMode.none;
  int _stepIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  final _serverUrlController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  final _serverUrlFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _displayNameFocus = FocusNode();
  final _nextFocus = FocusNode();

  @override
  void dispose() {
    _serverUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _serverUrlFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _displayNameFocus.dispose();
    _nextFocus.dispose();
    super.dispose();
  }

  void _onBack() {
    if (_stepIndex > 0) {
      setState(() => _stepIndex--);
    } else {
      setState(() {
        _mode = TvAuthMode.none;
        _stepIndex = 0;
        _errorMessage = null;
      });
    }
  }

  Future<void> _onNext() async {
    setState(() => _errorMessage = null);
    
    // Validation
    final currentStep = _getCurrentStep();
    if (currentStep == 'serverUrl') {
      final v = _serverUrlController.text.trim();
      if (v.isEmpty) { setState(() => _errorMessage = 'Server URL is required'); return; }
      if (!v.startsWith('http')) { setState(() => _errorMessage = 'Must start with http:// or https://'); return; }
    } else if (currentStep == 'email') {
      if (_emailController.text.trim().isEmpty) { setState(() => _errorMessage = 'Username/Email is required'); return; }
    } else if (currentStep == 'password') {
      if (_passwordController.text.isEmpty) { setState(() => _errorMessage = 'Password is required'); return; }
    }

    // Advance or Submit
    if (_isLastStep()) {
      await _submit();
    } else {
      setState(() => _stepIndex++);
      _requestFocusForStep();
    }
  }

  void _requestFocusForStep() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final step = _getCurrentStep();
      if (step == 'serverUrl') _serverUrlFocus.requestFocus();
      else if (step == 'email') _emailFocus.requestFocus();
      else if (step == 'password') _passwordFocus.requestFocus();
      else if (step == 'displayName') _displayNameFocus.requestFocus();
    });
  }

  String _getCurrentStep() {
    if (_mode == TvAuthMode.login) return TvLoginStep.values[_stepIndex].name;
    if (_mode == TvAuthMode.signup) return TvSignupStep.values[_stepIndex].name;
    if (_mode == TvAuthMode.guest) return TvGuestStep.values[_stepIndex].name;
    return '';
  }

  bool _isLastStep() {
    if (_mode == TvAuthMode.login) return _stepIndex == TvLoginStep.values.length - 2;
    if (_mode == TvAuthMode.signup) return _stepIndex == TvSignupStep.values.length - 2;
    if (_mode == TvAuthMode.guest) return _stepIndex == TvGuestStep.values.length - 2;
    return false;
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      if (_mode == TvAuthMode.guest) {
        await UserPreferences.setHasSeenWelcome(true);
        if (mounted) Navigator.pushReplacement(context, slideRoute(builder: (_) => const PlaylistScreen()));
        return;
      }

      final url = _serverUrlController.text.trim();
      final email = _emailController.text.trim();
      final pass = _passwordController.text;

      if (_mode == TvAuthMode.login) {
        await SyncService.instance.login(url, email, pass);
      } else {
        await SyncService.instance.register(url, email, pass, _displayNameController.text.trim());
      }

      await UserPreferences.setHasSeenWelcome(true);
      if (mounted) Navigator.pushReplacement(context, fadeRoute(builder: (_) => const PostLoginChoiceScreen()));
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().contains('401') ? 'Invalid credentials' : 'Connection failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Subtle radial gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                // Logo + Name
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/logo.png', width: 48, height: 48, errorBuilder: (_, __, ___) => const Icon(Icons.live_tv_rounded, color: Colors.white, size: 40)),
                    const SizedBox(width: 16),
                    const Text('C4-TV', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ],
                ),
                
                Expanded(
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, anim) {
                        final isEntering = child.key == ValueKey(_mode.index + _stepIndex);
                        final offset = isEntering ? const Offset(0.1, 0) : const Offset(-0.1, 0);
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: offset, end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeInOut)),
                            child: child,
                          ),
                        );
                      },
                      child: _mode == TvAuthMode.none ? _buildModeSelection() : _buildStepView(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelection() {
    return Column(
      key: const ValueKey('modes'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _TvLargeButton(
          icon: Icons.key_rounded,
          label: 'Login',
          autofocus: true,
          onTap: () => setState(() { _mode = TvAuthMode.login; _stepIndex = 0; _requestFocusForStep(); }),
        ),
        const SizedBox(height: 16),
        _TvLargeButton(
          icon: Icons.edit_note_rounded,
          label: 'Sign Up',
          onTap: () => setState(() { _mode = TvAuthMode.signup; _stepIndex = 0; _requestFocusForStep(); }),
        ),
        const SizedBox(height: 16),
        _TvLargeButton(
          icon: Icons.person_outline_rounded,
          label: 'Guest',
          onTap: () => setState(() { _mode = TvAuthMode.guest; _stepIndex = 0; _requestFocusForStep(); }),
        ),
      ],
    );
  }

  Widget _buildStepView() {
    final step = _getCurrentStep();
    String title = '';
    Widget field = const SizedBox.shrink();

    if (step == 'serverUrl') {
      title = 'Enter your server URL';
      field = _buildField(controller: _serverUrlController, focusNode: _serverUrlFocus, label: 'Server URL', hint: 'http://your-server:port', keyboardType: TextInputType.url);
    } else if (step == 'email') {
      title = 'Enter your username or email';
      field = _buildField(controller: _emailController, focusNode: _emailFocus, label: 'Username / Email', keyboardType: TextInputType.emailAddress);
    } else if (step == 'password') {
      title = 'Enter your password';
      field = _buildField(controller: _passwordController, focusNode: _passwordFocus, label: 'Password', obscure: _obscurePassword, suffix: IconButton(
        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      ));
    } else if (step == 'displayName') {
      title = _mode == TvAuthMode.guest ? 'Enter your name (optional)' : 'Enter your display name';
      field = _buildField(controller: _displayNameController, focusNode: _displayNameFocus, label: 'Display Name', hint: _mode == TvAuthMode.guest ? 'Leave blank to skip' : null);
    }

    return Container(
      key: ValueKey(_mode.index + _stepIndex),
      width: 480,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 18)),
          const SizedBox(height: 24),
          field,
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
          ],
          const SizedBox(height: 32),
          _TvLargeButton(
            focusNode: _nextFocus,
            label: _isLastStep() ? (_mode == TvAuthMode.guest ? 'Start' : 'Connect') : 'Next',
            isLoading: _isLoading,
            onTap: _onNext,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _onBack,
            child: const Text('Back', style: TextStyle(color: Colors.white38, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    String? hint,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _nextFocus.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.select) {
          // If virtual keyboard is open, this might not fire correctly on all TVs
          // But for remote OK, we move focus to Next button
          _nextFocus.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 16),
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 16),
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 3)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}

class _TvLargeButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool isLoading;

  const _TvLargeButton({
    this.icon,
    required this.label,
    required this.onTap,
    this.autofocus = false,
    this.focusNode,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Focus(
      autofocus: autofocus,
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter  ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA) {
          onTap();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp && focusNode != null) {
          // In step view, up goes back to field
          FocusScope.of(context).previousFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (ctx) {
        final hasFocus = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 320,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: hasFocus ? Colors.white.withValues(alpha: 0.15) : Colors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: hasFocus ? primary : Colors.transparent, width: 3),
              boxShadow: hasFocus ? [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 20)] : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                else ...[
                  if (icon != null) ...[Icon(icon, color: Colors.white, size: 24), const SizedBox(width: 12)],
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }
}
