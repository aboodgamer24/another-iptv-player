import 'package:flutter/material.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/services/player_state.dart';
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
    setState(() => _lowLatency = newVal);

    final native = PlayerState.activePlayer?.platform;
    if (native is NativePlayer) {
      try {
        if (newVal) {
          await native.setProperty('cache', 'no');
          await native.setProperty('demuxer-max-bytes', '2MiB');
          await native.setProperty('demuxer-max-back-bytes', '1MiB');
          await native.setProperty('cache-secs', '0');
          await native.setProperty('demuxer-readahead-secs', '0.5');
          await native.setProperty('video-sync', 'audio');
        } else {
          await native.setProperty('cache', 'yes');
          await native.setProperty('demuxer-max-bytes', '50MiB');
          await native.setProperty('demuxer-max-back-bytes', '10MiB');
          await native.setProperty('cache-secs', '5');
          await native.setProperty('demuxer-readahead-secs', '3.0');
        }
      } catch (_) {}
    }

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
