import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';

enum DeskSound {
  flip,
  shuffle,
  pinIn,
  pinOut,
  attach,
  peel,
  shred,
  crumple,
  writing,
  save,
  complete,
}

class DeskAudio {
  final _players = [AudioPlayer(), AudioPlayer()];
  final _busy = <int>{};
  final _last = <DeskSound, DateTime>{};
  final _cache = AudioCache(prefix: 'assets/sounds/');
  Preferences preferences = const Preferences();
  bool _ready = false;
  String? error;
  Future<void> initialize() async {
    try {
      final context = AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
      );
      for (var i = 0; i < _players.length; i++) {
        final index = i;
        await _players[i].setAudioContext(context);
        await _players[i].setReleaseMode(ReleaseMode.stop);
        _players[i].onPlayerComplete.listen((_) {
          _busy.remove(index);
        });
      }
      await _cache.loadAll(['flip.wav', 'writing.wav', 'save.wav']);
      _ready = true;
    } catch (e) {
      error = 'Sound assets could not be loaded: $e';
    }
  }

  Future<void> play(DeskSound sound) async {
    if (!_ready ||
        !preferences.sound ||
        preferences.volume <= 0 ||
        (sound == DeskSound.writing && !preferences.writingSound)) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_last[sound] ?? DateTime(2000)).inMilliseconds <
        (sound == DeskSound.writing ? 180 : 100)) {
      return;
    }
    _last[sound] = now;
    final slot = [0, 1].where((i) => !_busy.contains(i)).firstOrNull;
    if (slot == null) return;
    _busy.add(slot);
    try {
      if (Platform.isAndroid &&
          !(await const MethodChannel('atelier/device')
                  .invokeMethod<bool>('soundAllowed') ??
              false)) {
        _busy.remove(slot);
        return;
      }
      final uri = await _cache.load('${sound.name}.wav');
      await _players[slot].play(
        DeviceFileSource(uri.toFilePath()),
        volume: preferences.volume * (sound == DeskSound.writing ? .28 : 1),
      );
    } catch (_) {
      _busy.remove(slot);
    }
  }

  Future<void> stop() async {
    for (final p in _players) {
      await p.stop();
    }
    _busy.clear();
  }

  Future<void> dispose() async {
    for (final p in _players) {
      await p.dispose();
    }
  }
}
