import 'package:flutter/material.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/services/player_state.dart';
import 'package:another_iptv_player/services/event_bus.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;

class LowLatencyButton extends StatefulWidget {
  const LowLatencyButton({super.key});

  @override
  State<LowLatencyButton> createState() => _LowLatencyButtonState();
}

class _LowLatencyButtonState extends State<LowLatencyButton> {
  bool _lowLatency = false;

  @override
  void initState() {
    super.initState();
    UserPreferences.getLowLatencyMode().then((v) {
      if (mounted) setState(() => _lowLatency = v);
    });
  }

  Future<void> _toggle() async {
    final newVal = !_lowLatency;
    await UserPreferences.setLowLatencyMode(newVal);
    if (mounted) setState(() => _lowLatency = newVal);

    // Notify PlayerWidget to apply properties
    EventBus().emit('low_latency_changed', newVal);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          newVal ? '⚡ Low Latency ON' : '🔄 Normal Mode',
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: newVal ? Colors.orange.shade800 : Colors.grey.shade800,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _lowLatency ? 'Low Latency: ON' : 'Low Latency: OFF',
      child: GestureDetector(
        onTap: _toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _lowLatency
                ? Colors.orange.withOpacity(0.85)
                : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _lowLatency ? Colors.orange : Colors.white38,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bolt_rounded,
                color: _lowLatency ? Colors.white : Colors.white70,
                size: 15,
              ),
              const SizedBox(width: 3),
              Text(
                'Low Latency',
                style: TextStyle(
                  color: _lowLatency ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
