import 'package:flutter/material.dart';
import 'package:another_iptv_player/services/parental_control_service.dart';
import 'package:another_iptv_player/widgets/pin_dialog.dart';

/// Settings screen for managing parental controls:
/// PIN setup/change/remove, keyword filtering, toggle lock.
class ParentalControlsScreen extends StatefulWidget {
  const ParentalControlsScreen({super.key});

  @override
  State<ParentalControlsScreen> createState() => _ParentalControlsScreenState();
}

class _ParentalControlsScreenState extends State<ParentalControlsScreen> {
  final ParentalControlService _service = ParentalControlService();
  bool _hasPin = false;
  bool _isEnabled = false;
  List<String> _keywords = [];
  bool _isLoading = true;
  final TextEditingController _keywordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final hasPin = await _service.hasPin();
    final isEnabled = await _service.isEnabled;
    final keywords = await _service.getKeywords();
    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _isEnabled = isEnabled;
        _keywords = keywords;
        _isLoading = false;
      });
    }
  }

  Future<void> _setupPin() async {
    String? firstPin;

    // Step 1: Enter new PIN
    final entered = await PinDialog.show(
      context,
      title: 'Create PIN',
      subtitle: 'Enter a 4-digit PIN',
      onSubmit: (pin) async {
        firstPin = pin;
        return true;
      },
    );

    if (entered != true || firstPin == null || !mounted) return;

    // Step 2: Confirm PIN
    final confirmed = await PinDialog.show(
      context,
      title: 'Confirm PIN',
      subtitle: 'Re-enter the same PIN',
      onSubmit: (pin) async {
        return pin == firstPin;
      },
    );

    if (confirmed == true && firstPin != null) {
      await _service.setupPin(firstPin!);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN set successfully')),
        );
      }
    }
  }

  Future<void> _changePin() async {
    // Verify current PIN first
    final verified = await PinDialog.show(
      context,
      title: 'Enter Current PIN',
      onSubmit: (pin) => _service.verifyPin(pin),
    );

    if (verified != true || !mounted) return;

    // Now setup new PIN
    await _setupPin();
  }

  Future<void> _removePin() async {
    final verified = await PinDialog.show(
      context,
      title: 'Enter PIN',
      subtitle: 'Verify PIN to remove it',
      onSubmit: (pin) => _service.verifyPin(pin),
    );

    if (verified == true) {
      await _service.removePin();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN removed')),
        );
      }
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    if (value && !_hasPin) {
      await _setupPin();
      return;
    }
    await _service.setEnabled(value);
    await _load();
  }

  Future<void> _addKeyword() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) return;
    await _service.addKeyword(keyword);
    _keywordController.clear();
    await _load();
  }

  Future<void> _removeKeyword(String keyword) async {
    await _service.removeKeyword(keyword);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parental Controls',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Lock icon header
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  child: Icon(Icons.lock_rounded,
                      size: 32, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Restrict content visibility using a PIN and keyword filters',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // Enable/Disable toggle
              _buildCard(
                theme,
                child: SwitchListTile(
                  title: const Text('Enable Parental Controls'),
                  subtitle: Text(_hasPin
                      ? 'PIN is set'
                      : 'Set a PIN to enable'),
                  value: _isEnabled,
                  onChanged: _toggleEnabled,
                  secondary: Icon(Icons.shield_rounded,
                      color: _isEnabled ? theme.colorScheme.primary : null),
                ),
              ),
              const SizedBox(height: 16),

              // PIN management
              _buildCard(
                theme,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.pin_rounded),
                      title: const Text('PIN Code'),
                      subtitle: Text(_hasPin ? '••••' : 'Not set'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_hasPin)
                            TextButton(
                              onPressed: _changePin,
                              child: const Text('Change'),
                            ),
                          if (_hasPin)
                            TextButton(
                              onPressed: _removePin,
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red),
                              child: const Text('Remove'),
                            ),
                          if (!_hasPin)
                            ElevatedButton(
                              onPressed: _setupPin,
                              child: const Text('Set PIN'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Keyword filtering
              Text('Content Filter Keywords',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Categories or content matching these keywords will be hidden when parental controls are active.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),

              // Add keyword input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keywordController,
                      decoration: InputDecoration(
                        hintText: 'e.g. adult, xxx, 18+',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      onSubmitted: (_) => _addKeyword(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _addKeyword,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Keyword list
              if (_keywords.isEmpty)
                _buildCard(
                  theme,
                  child: const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('No keywords added'),
                    subtitle: Text(
                        'Add keywords above to filter adult content'),
                  ),
                )
              else
                _buildCard(
                  theme,
                  child: Column(
                    children: _keywords.map((kw) {
                      return ListTile(
                        leading: const Icon(Icons.filter_alt_rounded,
                            size: 20),
                        title: Text(kw),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () => _removeKeyword(kw),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(ThemeData theme, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
