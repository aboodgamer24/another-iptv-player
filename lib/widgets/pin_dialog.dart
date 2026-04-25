import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A reusable 4-digit PIN entry dialog.
///
/// Returns `true` if 4 digits were entered & submitted (caller verifies),
/// or `null` if cancelled.
class PinDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Future<bool> Function(String pin) onSubmit;

  const PinDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.onSubmit,
  });

  /// Show the dialog and return whether the PIN was accepted.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Future<bool> Function(String pin) onSubmit,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          PinDialog(title: title, subtitle: subtitle, onSubmit: onSubmit),
    );
  }

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog>
    with SingleTickerProviderStateMixin {
  final List<String> _digits = [];
  bool _isLoading = false;
  bool _hasError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _addDigit(String digit) {
    if (_digits.length >= 4 || _isLoading) return;
    setState(() {
      _digits.add(digit);
      _hasError = false;
    });

    if (_digits.length == 4) {
      _submit();
    }
  }

  void _removeDigit() {
    if (_digits.isEmpty || _isLoading) return;
    setState(() {
      _digits.removeLast();
      _hasError = false;
    });
  }

  Future<void> _submit() async {
    if (_digits.length != 4) return;

    setState(() => _isLoading = true);

    final pin = _digits.join();
    final accepted = await widget.onSubmit(pin);

    if (!mounted) return;

    if (accepted) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _hasError = true;
        _isLoading = false;
        _digits.clear();
      });
      _shakeController.forward(from: 0);
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.lock_rounded,
                size: 28,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              widget.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 28),

            // Dot indicators with shake animation
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    _shakeAnimation.value *
                        (_shakeController.value < 0.5 ? 1 : -1),
                    0,
                  ),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _digits.length;
                  return Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hasError
                          ? Colors.red
                          : (filled
                                ? theme.colorScheme.primary
                                : Colors.transparent),
                      border: Border.all(
                        color: _hasError
                            ? Colors.red
                            : theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),

            if (_hasError) ...[
              const SizedBox(height: 12),
              Text(
                'Incorrect PIN',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
              ),
            ],
            const SizedBox(height: 28),

            // Keypad
            _buildKeypad(theme, isDark),

            const SizedBox(height: 16),

            // Cancel button
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => Navigator.of(context).pop(null),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad(ThemeData theme, bool isDark) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            if (key.isEmpty) {
              return const SizedBox(width: 72, height: 56);
            }

            final isBackspace = key == '⌫';

            return Padding(
              padding: const EdgeInsets.all(4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isLoading
                      ? null
                      : () {
                          if (isBackspace) {
                            _removeDigit();
                          } else {
                            _addDigit(key);
                          }
                        },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 64,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2C2C)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: isBackspace
                        ? Icon(
                            Icons.backspace_outlined,
                            size: 22,
                            color: theme.colorScheme.onSurface,
                          )
                        : Text(
                            key,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
