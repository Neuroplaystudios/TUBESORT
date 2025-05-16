import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  static final AudioPlayer _soundPlayer = AudioPlayer();
  static final AudioPlayer _musicPlayer = AudioPlayer(playerId: 'music_player');

  static bool _soundsEnabled = true;
  static bool _musicEnabled = true;
  static bool _isMusicPlaying = false;

  static bool isMusicEnabled() => _musicEnabled;
  static bool isSoundsEnabled() => _soundsEnabled;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _soundsEnabled = prefs.getBool('soundsEnabled') ?? true;
    _musicEnabled = prefs.getBool('musicEnabled') ?? true;

    await _soundPlayer.setVolume(1.0);
    await _soundPlayer.setReleaseMode(ReleaseMode.release);
    await _musicPlayer.setVolume(0.3);
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);

    if (_musicEnabled && _soundsEnabled) {
      await playMusic();
    }
  }

  static Future<void> toggleSounds(bool enabled) async {
    _soundsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundsEnabled', enabled);

    debugPrint('Sonidos ${enabled ? "activados" : "desactivados"}');

    if (!enabled) {
      await stopMusic();
      await _soundPlayer.stop();
    } else {
      // If sounds are re-enabled, check if music should also play
      if (_musicEnabled) {
        await playMusic();
      }
    }
  }

  static Future<void> toggleMusic(bool enabled) async {
    _musicEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('musicEnabled', enabled);

    debugPrint('toggleMusic -> enabled: $_musicEnabled');

    if (!_soundsEnabled || !_musicEnabled) {
      debugPrint("Deteniendo la música (desactivado o sin sonidos)");
      await stopMusic();
    } else {
      await playMusic();
    }
  }

  static Future<void> playSound(String sound) async {
    if (!_soundsEnabled) return;

    try {
      await _soundPlayer.play(AssetSource('sounds/$sound.mp3'));
    } catch (e) {
      debugPrint('Error al reproducir sonido $sound: $e');
    }
  }

  static Future<void> playMusic() async {
    if (!_musicEnabled || !_soundsEnabled) {
      debugPrint('playMusic cancelado: música o sonidos desactivados');
      return;
    }

    if (_isMusicPlaying) {
      debugPrint('Música ya está sonando, no se vuelve a reproducir.');
      return;
    }

    try {
      debugPrint('Iniciando reproducción de música...');
      await _musicPlayer.play(AssetSource('sounds/background_music.mp3'));
      _isMusicPlaying = true;
    } catch (e) {
      debugPrint('Error reproduciendo música: $e');
    }
  }

  static Future<void> stopMusic() async {
    try {
      debugPrint('>> Llamando _musicPlayer.stop()');
      await _musicPlayer.stop();
      _isMusicPlaying = false;
      debugPrint('>> Música detenida correctamente');
    } catch (e) {
      debugPrint('Error deteniendo música: $e');
    }
  }

  static Future<void> dispose() async {
    await _soundPlayer.dispose();
    await _musicPlayer.dispose();
  }
}