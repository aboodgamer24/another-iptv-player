import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:another_iptv_player/services/sync_service.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/utils/app_transitions.dart';
import 'package:another_iptv_player/screens/post_login_choice_screen.dart';
import 'package:another_iptv_player/screens/playlist_screen.dart';

enum TvFlow { none, login, signup, guest }

class TvWelcomeScreen extends StatefulWidget {
  const TvWelcomeScreen({super.key});

  @override
  State<TvWelcomeScreen> createState() => _TvWelcomeScreenState();
}

class _TvWelcomeScreenState extends State<TvWelcomeScreen> with TickerProviderStateMixin {
  TvFlow _currentFlow = TvFlow.none;
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Controllers
  final Map<String, TextEditingController> _controllers = {
    'serverUrl': TextEditingController(text: 'http://'),
    'email': TextEditingController(),
    'password': TextEditingController(),
    'displayName': TextEditingController(),
  };

  // Focus Nodes
  final FocusNode _loginBtnNode = FocusNode();
  final FocusNode _signupBtnNode = FocusNode();
  final FocusNode _guestBtnNode = FocusNode();
  final Map<String, FocusNode> _fieldNodes = {
    'serverUrl': FocusNode(),
    'email': FocusNode(),
    'password': FocusNode(),
    'displayName': FocusNode(),
    'submit': FocusNode(),
    'next': FocusNode(),
  };

  // Animation Controllers
  late AnimationController _panelController;
  late AnimationController _buttonsController;
  late AnimationController _shakeController;

  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _buttonsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Initial focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_loginBtnNode);
    });
  }

  @override
  void dispose() {
    _panelController.dispose();
    _buttonsController.dispose();
    _shakeController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _loginBtnNode.dispose();
    _signupBtnNode.dispose();
    _guestBtnNode.dispose();
    for (var node in _fieldNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _selectFlow(TvFlow flow) {
    setState(() {
      _currentFlow = flow;
      _currentStep = 0;
      _errorMessage = null;
    });
    _buttonsController.reverse();
    _panelController.forward();
    
    // Auto-focus first field
    _focusFirstFieldOfFlow(flow);
  }

  void _focusFirstFieldOfFlow(TvFlow flow) {
    Timer(const Duration(milliseconds: 350), () {
      if (flow == TvFlow.guest) {
        FocusScope.of(context).requestFocus(_fieldNodes['submit']);
      } else {
        FocusScope.of(context).requestFocus(_fieldNodes['serverUrl']);
      }
    });
  }

  void _goBack() {
    if (_currentStep > 0) {
      _clearStepsFrom(_currentStep);
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
      _focusFieldForStep(_currentStep);
    } else {
      _clearAllSteps();
      setState(() {
        _currentFlow = TvFlow.none;
      });
      _panelController.reverse();
      _buttonsController.forward();
      FocusScope.of(context).requestFocus(_loginBtnNode);
    }
  }

  void _clearStepsFrom(int stepIndex) {
    final steps = _getStepsForFlow(_currentFlow);
    for (int i = stepIndex; i < steps.length; i++) {
      if (steps[i].key != 'serverUrl' || _currentFlow == TvFlow.none) {
        // Keep serverUrl unless resetting everything
        _controllers[steps[i].key]?.clear();
        if (steps[i].key == 'serverUrl') {
          _controllers['serverUrl']?.text = 'http://';
        }
      }
    }
  }

  void _clearAllSteps() {
    _controllers['email']?.clear();
    _controllers['password']?.clear();
    _controllers['displayName']?.clear();
    // Keep serverUrl for convenience unless user really wants a full reset
  }

  void _focusFieldForStep(int step) {
    final flowSteps = _getStepsForFlow(_currentFlow);
    if (step < flowSteps.length) {
      final fieldKey = flowSteps[step].key;
      FocusScope.of(context).requestFocus(_fieldNodes[fieldKey]);
    }
  }

  List<_StepData> _getStepsForFlow(TvFlow flow) {
    if (flow == TvFlow.login) {
      return [
        _StepData(
          key: 'serverUrl',
          label: 'Server URL',
          hint: 'http://your-server:7000',
          icon: Icons.dns_rounded,
          keyboardType: TextInputType.url,
          validator: (v) => v.isEmpty || (!v.startsWith('http://') && !v.startsWith('https://'))
              ? 'Enter a valid URL starting with http://'
              : null,
        ),
        _StepData(
          key: 'email',
          label: 'Email',
          hint: 'you@example.com',
          icon: Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: (v) => !v.contains('@') ? 'Enter a valid email' : null,
        ),
        _StepData(
          key: 'password',
          label: 'Password',
          icon: Icons.lock_rounded,
          isPassword: true,
          validator: (v) => v.isEmpty ? 'Password is required' : null,
          submitLabel: 'Sign In',
        ),
      ];
    } else if (flow == TvFlow.signup) {
      return [
        _StepData(
          key: 'serverUrl',
          label: 'Server URL',
          hint: 'http://your-server:7000',
          icon: Icons.dns_rounded,
          keyboardType: TextInputType.url,
          validator: (v) => v.isEmpty || (!v.startsWith('http://') && !v.startsWith('https://'))
              ? 'Enter a valid URL starting with http://'
              : null,
        ),
        _StepData(
          key: 'displayName',
          label: 'Display Name',
          hint: 'Your name',
          icon: Icons.person_rounded,
          validator: (v) => v.isEmpty ? 'Name is required' : null,
        ),
        _StepData(
          key: 'email',
          label: 'Email',
          hint: 'you@example.com',
          icon: Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: (v) => !v.contains('@') ? 'Enter a valid email' : null,
        ),
        _StepData(
          key: 'password',
          label: 'Password',
          hint: 'Min. 6 characters',
          icon: Icons.lock_rounded,
          isPassword: true,
          validator: (v) => v.length < 6 ? 'Min. 6 characters' : null,
          submitLabel: 'Create Account',
        ),
      ];
    }
    return [];
  }

  Future<void> _advanceOrSubmit() async {
    final steps = _getStepsForFlow(_currentFlow);
    final currentStepData = steps[_currentStep];
    final value = _controllers[currentStepData.key]!.text.trim();

    final error = currentStepData.validator?.call(value);
    if (error != null) {
      setState(() => _errorMessage = error);
      _shakeController.forward(from: 0);
      return;
    }

    setState(() => _errorMessage = null);

    if (_currentStep < steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      _focusFieldForStep(_currentStep);
    } else {
      _executeSubmit();
    }
  }

  Future<void> _executeSubmit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final serverUrl = _controllers['serverUrl']!.text.trim();
      final email = _controllers['email']!.text.trim();
      final password = _controllers['password']!.text;
      final displayName = _controllers['displayName']!.text.trim();

      if (_currentFlow == TvFlow.login) {
        await SyncService.instance.login(serverUrl, email, password);
      } else {
        await SyncService.instance.register(serverUrl, email, password, displayName);
      }

      await UserPreferences.setHasSeenWelcome(true);
      if (!mounted) return;
      Navigator.pushReplacement(context, fadeRoute(builder: (c) => const PostLoginChoiceScreen()));
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
      _shakeController.forward(from: 0);
    }
  }

  Future<void> _continueAsGuest() async {
    await UserPreferences.setHasSeenWelcome(true);
    if (!mounted) return;
    Navigator.pushReplacement(context, fadeRoute(builder: (c) => const PlaylistScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.escape): const _BackIntent(),
          LogicalKeySet(LogicalKeyboardKey.backspace): const _BackIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _BackIntent: CallbackAction<_BackIntent>(onInvoke: (_) => _goBack()),
          },
          child: Stack(
            children: [
              // Logo Block
              AnimatedBuilder(
                animation: _panelController,
                builder: (context, child) {
                  final slideValue = Curves.easeOutCubic.transform(_panelController.value);
                  return Positioned(
                    left: 0,
                    right: (MediaQuery.of(context).size.width / 2) * slideValue,
                    top: 0,
                    bottom: 0,
                    child: Center(child: child),
                  );
                },
                child: _LogoBlock(),
              ),

              // Choice Buttons
              Positioned(
                left: 0,
                right: 0,
                bottom: 100,
                child: FadeTransition(
                  opacity: _buttonsController,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: _buttonsController, curve: Curves.easeOutCubic)),
                    child: _currentFlow == TvFlow.none ? _buildChoiceButtons() : const SizedBox.shrink(),
                  ),
                ),
              ),

              // Right Panel
              AnimatedBuilder(
                animation: _panelController,
                builder: (context, child) {
                  final slideValue = Curves.easeOutCubic.transform(_panelController.value);
                  return Positioned(
                    right: (1.0 - slideValue) * 80 - (1.0 - slideValue) * MediaQuery.of(context).size.width / 2,
                    top: 0,
                    bottom: 0,
                    width: MediaQuery.of(context).size.width / 2,
                    child: Opacity(
                      opacity: _panelController.value,
                      child: child,
                    ),
                  );
                },
                child: _buildRightPanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MenuButton(
          label: 'Login',
          icon: Icons.key_rounded,
          focusNode: _loginBtnNode,
          onPressed: () => _selectFlow(TvFlow.login),
        ),
        const SizedBox(width: 24),
        _MenuButton(
          label: 'Sign Up',
          icon: Icons.auto_awesome_rounded,
          focusNode: _signupBtnNode,
          onPressed: () => _selectFlow(TvFlow.signup),
        ),
        const SizedBox(width: 24),
        _MenuButton(
          label: 'Continue as Guest',
          icon: Icons.person_outline_rounded,
          focusNode: _guestBtnNode,
          onPressed: () => _selectFlow(TvFlow.guest),
        ),
      ],
    );
  }

  Widget _buildRightPanel() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button
          Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.select) {
                _goBack();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextButton.icon(
              onPressed: _goBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back', style: TextStyle(fontSize: 16)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 32),

          Expanded(
            child: _currentFlow == TvFlow.guest ? _buildGuestFlow() : _buildStepFlow(),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestFlow() {
    return Center(
      child: Card(
        color: Colors.white.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_outline_rounded, size: 80, color: Theme.of(context).primaryColor),
              const SizedBox(height: 24),
              const Text(
                'Continue as Guest',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                'You can sign in anytime from Settings → Account',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.amber),
                    SizedBox(width: 8),
                    Text(
                      'Your data won\'t be backed up',
                      style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  focusNode: _fieldNodes['submit'],
                  onPressed: _continueAsGuest,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Continue →', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepFlow() {
    final steps = _getStepsForFlow(_currentFlow);
    if (steps.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            if (i <= _currentStep)
              _TvFieldStep(
                step: steps[i],
                isActive: i == _currentStep,
                isLocked: i < _currentStep,
                controller: _controllers[steps[i].key]!,
                focusNode: _fieldNodes[steps[i].key]!,
                btnFocusNode: i == steps.length - 1 ? _fieldNodes['submit'] : _fieldNodes['next'],
                isSubmitting: _isLoading,
                errorMessage: i == _currentStep ? _errorMessage : null,
                shakeAnimation: _shakeController,
                isPasswordVisible: _isPasswordVisible,
                onTogglePassword: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                onNext: _advanceOrSubmit,
                onEdit: () {
                  _clearStepsFrom(i + 1);
                  setState(() {
                    _currentStep = i;
                    _errorMessage = null;
                  });
                  _focusFieldForStep(i);
                },
              ),
            if (i < _currentStep) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _StepData {
  final String key;
  final String label;
  final String? hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool isPassword;
  final String? Function(String)? validator;
  final String? submitLabel;

  _StepData({
    required this.key,
    required this.label,
    this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.validator,
    this.submitLabel,
  });
}

class _LogoBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Image.asset(
            'assets/logo.png',
            errorBuilder: (c, e, s) => Icon(Icons.live_tv_rounded, size: 64, color: Theme.of(context).primaryColor),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'C4-TV',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your IPTV, Synced Everywhere',
          style: TextStyle(fontSize: 18, color: Colors.white38, letterSpacing: 1.2),
        ),
      ],
    );
  }
}

class _MenuButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final FocusNode focusNode;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.focusNode,
    required this.onPressed,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final color = _isFocused ? Theme.of(context).primaryColor : Colors.white10;
    final textColor = _isFocused ? Colors.white : Colors.white60;

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.select) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isFocused
                ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: textColor, size: 24),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvFieldStep extends StatelessWidget {
  final _StepData step;
  final bool isActive;
  final bool isLocked;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? btnFocusNode;
  final bool isSubmitting;
  final String? errorMessage;
  final AnimationController shakeAnimation;
  final bool isPasswordVisible;
  final VoidCallback onTogglePassword;
  final VoidCallback onNext;
  final VoidCallback onEdit;

  const _TvFieldStep({
    required this.step,
    required this.isActive,
    required this.isLocked,
    required this.controller,
    required this.focusNode,
    this.btnFocusNode,
    required this.isSubmitting,
    this.errorMessage,
    required this.shakeAnimation,
    required this.isPasswordVisible,
    required this.onTogglePassword,
    required this.onNext,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (isLocked) {
      return _buildLockedChip(context);
    }

    if (!isActive) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Column(
        key: ValueKey(step.key),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.label,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: shakeAnimation,
            builder: (context, child) {
              final shake = TweenSequence<double>([
                TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
                TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
                TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
                TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
              ]).animate(shakeAnimation).value;
              return Transform.translate(offset: Offset(shake, 0), child: child);
            },
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: step.isPassword && !isPasswordVisible,
              keyboardType: step.keyboardType,
              style: const TextStyle(fontSize: 18, color: Colors.white),
              decoration: InputDecoration(
                hintText: step.hint,
                prefixIcon: Icon(step.icon, color: Colors.white54),
                suffixIcon: step.isPassword
                    ? IconButton(
                        icon: Icon(isPasswordVisible ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                        onPressed: onTogglePassword,
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              ),
              onSubmitted: (_) => onNext(),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              focusNode: btnFocusNode,
              onPressed: isSubmitting ? null : onNext,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: isSubmitting
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3))
                  : Text(
                      step.submitLabel ?? 'Next →',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedChip(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.select) {
          onEdit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final bool isFocused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onEdit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isFocused ? Theme.of(context).primaryColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFocused ? Theme.of(context).primaryColor : Colors.white10,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(step.icon, size: 18, color: Colors.white54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step.isPassword ? '••••••••' : controller.text,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Edit', style: TextStyle(color: Colors.white38, fontSize: 13)),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit_rounded, size: 14, color: Colors.white38),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BackIntent extends Intent {
  const _BackIntent();
}
