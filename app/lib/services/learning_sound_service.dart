import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Short locally synthesized feedback tones; no network or external sound files.
class LearningSoundService {
  LearningSoundService._() {
    _ready = _loadSetting();
  }

  static final LearningSoundService instance = LearningSoundService._();
  static const String _settingKey = 'linguapro_learning_sounds_enabled_v1';
  static const int _sampleRate = 22050;

  final AudioPlayer _player = AudioPlayer();
  late final Future<void> _ready;
  bool _enabled = true;

  bool get enabled => _enabled;

  Future<void> _loadSetting() async {
    final preferences = await SharedPreferences.getInstance();
    _enabled = preferences.getBool(_settingKey) ?? true;
  }

  Future<void> load() => _ready;

  Future<void> setEnabled(bool value) async {
    await _ready;
    _enabled = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_settingKey, value);
    if (!value) await _player.stop();
  }

  Future<void> correct() => _play(<(double, int)>[
        (659.25, 105),
        (0, 35),
        (880.0, 175),
      ]);

  Future<void> incorrect() => _play(<(double, int)>[
        (310.0, 145),
        (0, 25),
        (220.0, 190),
      ]);

  Future<void> tap() => _play(<(double, int)>[(520.0, 45)]);

  Future<void> complete() => _play(<(double, int)>[
        (523.25, 100),
        (659.25, 100),
        (783.99, 100),
        (1046.5, 240),
      ]);

  Future<void> _play(List<(double, int)> tones) async {
    await _ready;
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(BytesSource(_wav(tones)), volume: 0.55);
    } catch (_) {
      // Sound is an enhancement: playback failures must never interrupt a lesson.
    }
  }

  Uint8List _wav(List<(double, int)> tones) {
    final sampleCount = tones.fold<int>(
      0,
      (sum, tone) => sum + (_sampleRate * tone.$2 ~/ 1000),
    );
    final bytes = Uint8List(44 + sampleCount * 2);
    final header = ByteData.sublistView(bytes);
    void writeText(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes[offset + i] = value.codeUnitAt(i);
      }
    }

    writeText(0, 'RIFF');
    header.setUint32(4, 36 + sampleCount * 2, Endian.little);
    writeText(8, 'WAVE');
    writeText(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(28, _sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    writeText(36, 'data');
    header.setUint32(40, sampleCount * 2, Endian.little);

    var sampleOffset = 0;
    for (final tone in tones) {
      final frequency = tone.$1;
      final count = _sampleRate * tone.$2 ~/ 1000;
      for (var i = 0; i < count; i++) {
        var sample = 0.0;
        if (frequency > 0) {
          final attack = math.min(1.0, i / (_sampleRate * 0.008));
          final release = math.min(1.0, (count - i) / (_sampleRate * 0.025));
          final envelope = math.min(attack, release);
          sample = math.sin(2 * math.pi * frequency * i / _sampleRate) *
              envelope *
              0.22;
        }
        header.setInt16(44 + sampleOffset * 2, (sample * 32767).round(),
            Endian.little);
        sampleOffset++;
      }
    }
    return bytes;
  }
}
