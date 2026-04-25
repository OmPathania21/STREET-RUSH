import 'package:flame_audio/flame_audio.dart';

class GameAudioManager {
  static const String _bgmTrack = 'bgm_loop.mp3';
  static const String _coinSfx = 'coin_pickup.wav';
  static const String _crashSfx = 'crash.wav';

  bool _initialized = false;
  bool _bgmStarted = false;
  bool _bgmPaused = false;

  late final AudioPool _coinPool;
  late final AudioPool _crashPool;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      await FlameAudio.bgm.initialize();
      await Future.wait([
        FlameAudio.audioCache.load(_bgmTrack),
        FlameAudio.audioCache.load(_coinSfx),
        FlameAudio.audioCache.load(_crashSfx),
      ]);

      _coinPool = await FlameAudio.createPool(_coinSfx, maxPlayers: 4);
      _crashPool = await FlameAudio.createPool(_crashSfx, maxPlayers: 1);
      _initialized = true;
    } catch (e) {
      print('AudioManager initialization failed: $e');
      _initialized = true;
    }
  }

  Future<void> startOrResumeBgm() async {
    if (!_initialized) {
      await initialize();
    }

    if (!_bgmStarted) {
      await FlameAudio.bgm.play(_bgmTrack, volume: 0.42);
      _bgmStarted = true;
      _bgmPaused = false;
      return;
    }

    if (_bgmPaused) {
      FlameAudio.bgm.resume();
      _bgmPaused = false;
    }
  }

  void pauseBgm() {
    if (!_bgmStarted || _bgmPaused) {
      return;
    }
    FlameAudio.bgm.pause();
    _bgmPaused = true;
  }

  Future<void> playCoinPickup() async {
    if (!_initialized) {
      return;
    }
    await _coinPool.start(volume: 0.75);
  }

  Future<void> playCrash() async {
    if (!_initialized) {
      return;
    }
    await _crashPool.start(volume: 0.95);
  }

  void stopAll() {
    if (!_initialized) {
      return;
    }
    FlameAudio.bgm.stop();
    _bgmStarted = false;
    _bgmPaused = false;
  }
}