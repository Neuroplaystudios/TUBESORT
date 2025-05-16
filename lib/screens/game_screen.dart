import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:easy_localization/easy_localization.dart';

// Modelos
import '../models/game_theme.dart';
import '../models/power_up.dart'; // Contiene PowerUpType y PowerUp
import '../models/level_stats.dart';
import '../models/game_mode.dart';

// Managers y Utils
import '../managers/sound_manager.dart';
// import '../utils/firebase_utils.dart'; // guardarProgresoFirebase() se llama desde HomeScreen al volver

// Constantes y Widgets
import '../constants/ad_units.dart';
import '../constants/app_styles.dart'; // Para appBarTextStyle
import '../widgets/glass_button.dart';


class GameScreen extends StatefulWidget {
  final int level;
  final GameTheme theme;
  final GameMode gameMode;

  const GameScreen({
    Key? key,
    required this.level,
    required this.theme,
    required this.gameMode,
  }) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final List<IconData> _availableIcons = [
    Icons.favorite, Icons.eco, Icons.water_drop, Icons.wb_sunny, Icons.auto_awesome,
    Icons.star, Icons.anchor, Icons.rocket, Icons.cloud, Icons.ac_unit,
    Icons.airplanemode_active, Icons.android, Icons.audiotrack, Icons.beach_access, Icons.cake,
  ];
  late Map<Color, IconData> _colorIcons;
  final Random _random = Random();

  late int _currentLevel;
  Timer? _gameTimer;
  RewardedAd? _rewardedAd;
  late List<List<Color>> tubes;
  int? selectedTube;
  int _moves = 0;
  late Duration _timeLeft;
  bool _isWildcardActive = false; // No se usa, considera eliminar
  bool _isFreezeActive = false; // No se usa, considera eliminar
  List<int> _frozenTubes = []; // No se usa, considera eliminar
  int? _hintTubeFrom;
  int? _hintTubeTo;
  bool _showTutorial = false;
  late AnimationController _winAnimationController;
  late Animation<double> _winAnimation;
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  late ConfettiController _confettiController;
  final List<Map<String, dynamic>> _moveHistory = [];

  int _hintUses = 5;
  int _rewindUses = 0;
  int _addTubeUses = 0;

  @override
  void initState() {
    super.initState();
    _assignRandomIcons();
    _currentLevel = widget.level;
    _loadRewardedAd();
    _loadBannerAd();
    tubes = _generateLevelTubes(_currentLevel); // Usar _currentLevel
    _confettiController = ConfettiController(duration: Duration(seconds: 3));
    _timeLeft = Duration(minutes: 2) + Duration(seconds: _currentLevel * 5); // Usar _currentLevel
    // SoundManager.init() ya se llama en main.dart

    if (widget.gameMode == GameMode.timed) {
      _startTimer();
    }

    _winAnimationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _winAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _winAnimationController, curve: Curves.elasticOut),
    );

    _loadInterstitialAd();
    _loadPreferencesAndPowerUps();
  }

  void _assignRandomIcons() {
    _colorIcons = {};
    final List<IconData> localAvailableIcons = List.from(_availableIcons);
    localAvailableIcons.shuffle(_random);

    int iconIndex = 0;
    for (final color in widget.theme.colorPalette) {
      if (iconIndex < localAvailableIcons.length) {
        _colorIcons[color] = localAvailableIcons[iconIndex++];
      } else {
        // Si te quedas sin iconos únicos, puedes repetir o usar uno por defecto
        _colorIcons[color] = Icons.circle;
      }
    }
  }

  Future<void> _loadPreferencesAndPowerUps() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showTutorial = prefs.getBool('showTutorial') ?? true;
        _hintUses = prefs.getInt('hintUses') ?? 5;
        _rewindUses = prefs.getInt('rewindUses') ?? 0;
        _addTubeUses = prefs.getInt('addTubeUses') ?? 0;
      });
    }
  }

  Future<void> _savePowerUpUses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('hintUses', _hintUses);
    await prefs.setInt('rewindUses', _rewindUses);
    await prefs.setInt('addTubeUses', _addTubeUses);
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId, // Usar constante
      request: AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _loadRewardedAd();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _loadRewardedAd();
              }
          );
        },
        onAdFailedToLoad: (error) {
          print('Failed to load rewarded ad: $error');
          _rewardedAd = null; // Asegurarse que es null si falla
        },
      ),
    );
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: bannerGameScreenAdUnitId, // Usar constante
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (mounted) {
            setState(() { _isBannerAdLoaded = true; });
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          print('Failed to load a banner ad (GameScreen): ${error.message}');
        },
      ),
    )..load();
  }

  void _showRewardedAd(PowerUpType powerUpType) {
    if (_rewardedAd == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('videoNotReady'))));
      _loadRewardedAd(); // Intentar recargar
      return;
    }

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        setState(() {
          switch (powerUpType) {
            case PowerUpType.hint: _hintUses += 5; break;
            case PowerUpType.rewind: _rewindUses += 1; break;
            case PowerUpType.addTube: _addTubeUses += 1; break;
          }
          _savePowerUpUses();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('usesAdded', args: ['1'])))); // Asumiendo que 'usesAdded' es como "+{count} uso(s) añadidos!"
      },
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _rewardedAd?.dispose();
    _confettiController.dispose();
    _gameTimer?.cancel();
    _winAnimationController.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId, // Usar constante
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              _loadInterstitialAd(); // Recargar para el próximo uso
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              ad.dispose();
              _loadInterstitialAd(); // Recargar
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('InterstitialAd failed to load: $error');
          _interstitialAd = null;
          _isAdLoaded = false;
        },
      ),
    );
  }

  List<List<Color>> _generateLevelTubes(int level) {
    _assignRandomIcons(); // Asegúrate de que los íconos se reasignan para cada nivel
    final random = Random();
    final colorsCount = min(widget.theme.colorPalette.length, min(8, 3 + (level ~/ 3))); // No más colores que los disponibles en el tema
    final tubesCount = colorsCount + 1; // Un tubo vacío extra

    final List<Color> availableColors = List<Color>.from(widget.theme.colorPalette);
    availableColors.shuffle(random);
    final List<Color> levelColors = availableColors.sublist(0, colorsCount);

    final List<Color> allBalls = [];
    for (var color in levelColors) {
      for (int i = 0; i < 3; i++) { // 3 bolas por color
        allBalls.add(color);
      }
    }
    allBalls.shuffle(random);
    List<List<Color>> newTubes = List.generate(tubesCount, (_) => []);

    int currentTubeIndex = 0;
    for (Color ball in allBalls) {
      // Distribuir para que no todos los tubos se llenen completamente al inicio si es posible
      // Esto es un intento simple, puede requerir una lógica más compleja para una "buena" distribución inicial.
      if (newTubes[currentTubeIndex].length < 3) { // Llenar hasta 3, el 4to espacio es para movimiento
        newTubes[currentTubeIndex].add(ball);
      } else {
        // Buscar otro tubo que no esté lleno (esto es simplista, idealmente no llenas todos los tubos menos el vacío)
        bool placed = false;
        for(int i=0; i< tubesCount -1; ++i) { // No intentes colocar en el tubo vacío designado
          if(newTubes[i].length < 3) {
            newTubes[i].add(ball);
            placed = true;
            break;
          }
        }
        if (!placed) { // Si todos los tubos (excepto el vacío) están llenos con 3, coloca en el actual
          if (newTubes[currentTubeIndex].length < 4) { // Asegurar que no exceda la capacidad total
            newTubes[currentTubeIndex].add(ball);
          }
        }
      }
      currentTubeIndex = (currentTubeIndex + 1) % (tubesCount - 1); // Rota entre los tubos que no son el vacío
    }
    // Podrías querer una lógica para asegurar que el nivel sea soluble y no demasiado fácil/difícil.
    return newTubes;
  }


  void _startTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_timeLeft.inSeconds == 0) {
        timer.cancel();
        _showTimeUpDialog();
      } else {
        setState(() {
          _timeLeft = _timeLeft - Duration(seconds: 1);
        });
      }
    });
  }

  void _selectTube(int index) {
    // if (_frozenTubes.contains(index)) return; // Lógica de congelar no implementada

    if (selectedTube == null) {
      if (tubes[index].isNotEmpty) {
        setState(() { selectedTube = index; });
        SoundManager.playSound('select');
      }
    } else {
      if (selectedTube == index) {
        setState(() { selectedTube = null; });
      } else {
        _moveColor(selectedTube!, index);
      }
    }
  }

  void _moveColor(int from, int to) {
    if (from == to || tubes[from].isEmpty) { // No permitir mover de/a tubos congelados si se implementa
      setState(() => selectedTube = null);
      return;
    }

    final fromTube = tubes[from];
    final toTube = tubes[to];
    final colorToMove = fromTube.last;

    if (toTube.length >= 3) { // Capacidad máxima del tubo es 4
      setState(() => selectedTube = null);
      SoundManager.playSound('error');
      return;
    }

    if (toTube.isEmpty || toTube.last == colorToMove) {
      setState(() {
        toTube.add(fromTube.removeLast());
        selectedTube = null;
        _moves++;
        _moveHistory.add({'from': from, 'to': to, 'color': colorToMove});

        if (_checkLevelComplete()) {
          _winLevel();
        } else {
          SoundManager.playSound('move');
        }
      });
    } else {
      SoundManager.playSound('error');
      setState(() => selectedTube = null);
    }
  }

  void _showHint() {
    if (_hintUses <= 0) {
      _showRefillDialog(PowerUpType.hint);
      SoundManager.playSound('error');
      return;
    }

    // Lógica simple para encontrar un movimiento posible
    for (int from = 0; from < tubes.length; from++) {
      if (tubes[from].isEmpty) continue;
      final color = tubes[from].last;
      for (int to = 0; to < tubes.length; to++) {
        if (from == to) continue;
        if (tubes[to].isEmpty || (tubes[to].last == color && tubes[to].length < 4)) {
          // Movimiento válido encontrado
          setState(() {
            _hintUses--;
            _savePowerUpUses();
            _hintTubeFrom = from;
            _hintTubeTo = to;
          });
          Future.delayed(Duration(seconds: 1), () {
            if (mounted) {
              setState(() { _hintTubeFrom = null; _hintTubeTo = null; });
            }
          });
          SoundManager.playSound('hint');
          return;
        }
      }
    }
    // No se encontró movimiento (o solo quedan movimientos que no completan un tubo)
    SoundManager.playSound('error'); // O un sonido diferente para "no hay pistas obvias"
  }

  void _useRewindPower() {
    if (_rewindUses <= 0) {
      _showRefillDialog(PowerUpType.rewind);
      SoundManager.playSound('error');
      return;
    }
    if (_moveHistory.isEmpty) {
      SoundManager.playSound('error');
      return;
    }

    setState(() {
      _rewindUses--;
      _savePowerUpUses();
      final lastMove = _moveHistory.removeLast();
      // Revertir el movimiento: mover la bola de 'to' a 'from'
      if (lastMove.containsKey('from') && lastMove.containsKey('to') && lastMove.containsKey('color')) {
        final colorToMoveBack = tubes[lastMove['to']].removeLast();
        tubes[lastMove['from']].add(colorToMoveBack);
        _moves--; // Decrementar contador de movimientos si se desea
      }
      SoundManager.playSound('undo');
    });
  }

  void _useAddTubePower() {
    if (_addTubeUses <= 0) {
      _showRefillDialog(PowerUpType.addTube);
      SoundManager.playSound('error');
      return;
    }
    if (tubes.length >= 20) { // Límite máximo de tubos
      SoundManager.playSound('error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('maxTubesReached'))));
      return;
    }

    setState(() {
      _addTubeUses--;
      _savePowerUpUses();
      tubes.add([]);
      SoundManager.playSound('powerup');
    });
  }

  Future<void> _showRefillDialog(PowerUpType powerUpType) async {
    String powerUpName = "";
    IconData powerUpIcon = Icons.error;
    Color powerUpColor = Colors.red;

    switch (powerUpType) {
      case PowerUpType.addTube:
        powerUpName = tr('powerUpAddTube'); powerUpIcon = Icons.add_circle_outline; powerUpColor = widget.theme.colorPalette[2]; break;
      case PowerUpType.rewind:
        powerUpName = tr('powerUpUndo'); powerUpIcon = Icons.replay; powerUpColor = widget.theme.colorPalette[5]; break;
      case PowerUpType.hint:
        powerUpName = tr('powerUpHint'); powerUpIcon = Icons.lightbulb_outline; powerUpColor = widget.theme.colorPalette[4]; break;
    }

    bool? watchAd = await showDialog<bool>(
      context: context, barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(25),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [widget.theme.colorPalette[0].withOpacity(0.9), widget.theme.colorPalette[2].withOpacity(0.9)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.theme.textColor.withOpacity(0.2), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(powerUpIcon, size: 60, color: powerUpColor),
              SizedBox(height: 20),
              Text(tr('recharge', namedArgs: {'powerUpName': powerUpName}), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: widget.theme.textColor), textAlign: TextAlign.center),
              SizedBox(height: 5),
              Text(tr('getOneMore'), style: TextStyle(fontSize: 16, color: widget.theme.textColor.withOpacity(0.9)), textAlign: TextAlign.center),
              SizedBox(height: 15),
              GlassButton( // Usando el GlassButton reutilizable
                text: tr('watchVideo'),
                onPressed: () => Navigator.pop(context, true),
                textColor: widget.theme.textColor,
                gradientColors: [powerUpColor, powerUpColor.withOpacity(0.7)], // Ejemplo de gradiente para el botón
                borderColor: widget.theme.textColor,
                iconColor: widget.theme.textColor, // O un color específico si lo deseas
              ),
            ],
          ),
        ),
      ),
    );
    if (watchAd == true && mounted) {
      _showRewardedAd(powerUpType);
    }
  }

  bool _checkLevelComplete() {

    for (var tube in tubes) {
      if (tube.isNotEmpty && (tube.length != 3 || !tube.every((c) => c == tube.first))) { // Chequea si está lleno (3) y homogéneo
        return false;
      }
    }
    return true;
  }

  Future<void> _winLevel() async {
    _gameTimer?.cancel();
    _winAnimationController.forward();
    SoundManager.playSound('win');
    _confettiController.play();

    var coinsEarned = 10 + _currentLevel * 2;
    if (widget.gameMode == GameMode.timed) {
      coinsEarned += (_timeLeft.inSeconds ~/ 5);
    }

    await Future.delayed(Duration(milliseconds: 300));

    bool? wantContinue = await showDialog<bool>(
      context: context, barrierDismissible: false,
      builder: (context) => _buildWinDialog(coinsEarned),
      useRootNavigator: true,
    );

    if (wantContinue == true) {
      await _saveLevelProgress(coinsEarned);
      if (_isAdLoaded && _interstitialAd != null && _currentLevel % 3 == 0) {
        _interstitialAd!.show();
      } else { // Si no se muestra el anuncio, ir al siguiente nivel directamente
        _goToNextLevel();
      }
      // _goToNextLevel se llamará en onAdDismissedFullScreenContent si se muestra un anuncio
      if (_interstitialAd?.fullScreenContentCallback != null && _isAdLoaded && _currentLevel % 3 == 0) {
        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (InterstitialAd ad) {
            ad.dispose();
            _loadInterstitialAd(); // Recargar
            _goToNextLevel();     // Ir al siguiente nivel DESPUÉS de cerrar el anuncio
          },
          onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
            ad.dispose();
            _loadInterstitialAd(); // Recargar
            _goToNextLevel();     // Ir al siguiente nivel si el anuncio falla
          },
        );
      } else if (!(_isAdLoaded && _currentLevel % 3 == 0)) { // Si no hay anuncio que mostrar o no toca
        _goToNextLevel();
      }
    } else {
      // El usuario eligió no continuar (por ejemplo, si hubiera un botón "Menú Principal")
      // Por ahora, el diálogo de ganar solo tiene "Continuar", así que esto no se alcanza.
      // Si quieres salir, usa Navigator.pop(context); desde el diálogo.
    }
  }


  Future<void> _saveLevelProgress(int coinsEarned) async {
    final prefs = await SharedPreferences.getInstance();
    final nextLevel = _currentLevel + 1;

    await prefs.setInt('level', nextLevel);
    await prefs.setInt('coins', (prefs.getInt('coins') ?? 0) + coinsEarned);

    final stats = LevelStats(
      level: _currentLevel, moves: _moves,
      time: widget.gameMode == GameMode.timed ? (Duration(minutes: 2) + Duration(seconds: widget.level * 5) - _timeLeft) : Duration.zero,
      date: DateTime.now(),
    );
    final statsJson = prefs.getStringList('level_stats') ?? [];
    statsJson.add(jsonEncode({'level': stats.level, 'moves': stats.moves, 'time': stats.time.inSeconds, 'date': stats.date.toIso8601String()}));
    await prefs.setStringList('level_stats', statsJson);
  }

  void _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showTutorial', false);
    if (mounted) {
      setState(() { _showTutorial = false; });
    }
  }

  String _getModeName(GameMode mode) {
    switch (mode) {
      case GameMode.classic: return 'modeClassic'.tr();
      case GameMode.timed: return 'modeTimed'.tr();
      case GameMode.oneTap: return 'modeOneTap'.tr();
      case GameMode.daily: return 'modeDaily'.tr();
    }
  }

  void _showTimeUpDialog() {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [widget.theme.colorPalette[0].withOpacity(0.9), widget.theme.colorPalette[2].withOpacity(0.9)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.theme.textColor.withOpacity(0.2), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_off, size: 60, color: widget.theme.textColor),
                SizedBox(height: 20),
                Text(tr('timeUpTitle'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: widget.theme.textColor)),
                SizedBox(height: 15),
                Text(tr('timeUpMessage'), style: TextStyle(fontSize: 18, color: widget.theme.textColor.withOpacity(0.9)), textAlign: TextAlign.center),
                SizedBox(height: 25),
                GlassButton(
                  text: tr('retry_button'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (mounted) {
                      setState(() {
                        tubes = _generateLevelTubes(_currentLevel);
                        _moves = 0;
                        _moveHistory.clear();
                        if (widget.gameMode == GameMode.timed) {
                          _timeLeft = Duration(minutes: 2) + Duration(seconds: _currentLevel * 5);
                          _startTimer();
                        }
                      });
                    }
                  },
                  textColor: widget.theme.textColor,
                  gradientColors: [widget.theme.colorPalette[1], widget.theme.colorPalette[3]],
                  borderColor: widget.theme.textColor,
                ),
                SizedBox(height: 10),
                GlassButton(
                  text: tr('exit_button'),
                  onPressed: () {
                    _gameTimer?.cancel();
                    Navigator.of(context).pop(); // Cierra el diálogo
                    Navigator.of(context).pop(); // Vuelve a HomeScreen
                  },
                  textColor: widget.theme.textColor,
                  gradientColors: [widget.theme.colorPalette[0], widget.theme.colorPalette[2]],
                  borderColor: widget.theme.textColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _goToNextLevel() {
    if (!mounted) return;
    // No es necesario setState aquí para _currentLevel, ya que estamos reemplazando la pantalla
    final nextLevelValue = _currentLevel + 1;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GameScreen(
          key: ValueKey('level-$nextLevelValue'), // Nueva key para forzar reconstrucción
          level: nextLevelValue,
          theme: widget.theme,
          gameMode: widget.gameMode,
        ),
      ),
    );
  }

  Widget _buildWinDialog(int coinsEarned) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _winAnimation,
        child: Container(
          padding: EdgeInsets.all(25),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [widget.theme.colorPalette[0].withOpacity(0.9), widget.theme.colorPalette[2].withOpacity(0.9)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.theme.textColor.withOpacity(0.2), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.celebration, size: 60, color: Colors.yellow),
              SizedBox(height: 20),
              Text(tr('levelCompleted'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: widget.theme.textColor)),
              SizedBox(height: 15),
              Text('${tr('moves')}: $_moves', style: TextStyle(fontSize: 18, color: widget.theme.textColor.withOpacity(0.9))),
              if (widget.gameMode == GameMode.timed) ...[
                SizedBox(height: 5),
                Text('${tr('timeRemaining')} ${_timeLeft.inMinutes}:${(_timeLeft.inSeconds % 60).toString().padLeft(2, '0')}', style: TextStyle(fontSize: 18, color: widget.theme.textColor.withOpacity(0.9))),
              ],
              SizedBox(height: 10),
              Text('${tr('score')}: $coinsEarned', style: TextStyle(fontSize: 18, color: Colors.yellow, fontWeight: FontWeight.bold)), // Usar 'score' si existe
              SizedBox(height: 25),
              GlassButton(
                text: tr('Continuar'), // Usar 'continue_button'
                onPressed: () {
                  _winAnimationController.reset();
                  Navigator.of(context).pop(true); // Indica que se quiere continuar
                },
                textColor: widget.theme.textColor,
                gradientColors: [widget.theme.colorPalette[1], widget.theme.colorPalette[4]],
                borderColor: widget.theme.textColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRealisticTube(List<Color> tube, int index, {required bool isPortrait}) {
    bool isSelected = selectedTube == index;
    // bool isTubeEmpty = tube.isEmpty; // No se usa directamente
    // bool isFrozen = _frozenTubes.contains(index); // Lógica no implementada
    bool isHintFrom = _hintTubeFrom == index;
    bool isHintTo = _hintTubeTo == index;

    // Dimensiones y factores como estaban en el código que proporcionaste originalmente
    double tubeWidthFactor = isPortrait ? 9.5 : 12.5;// / ANTES: 6.5 : 9.5. AJUSTA ESTOS VALORES DE ANCHURA DE LOS TUBOS
    double tubeWidth = MediaQuery.of(context).size.width / tubeWidthFactor;
    double tubeTotalHeight = 140.0;

    double tubeBodyHeight = 125.0;
    double tubeBodyBottomOffset = 4.0;

    double ballHeight = 32.0;
    double ballMarginBottomOriginal = 1.0; // En el original era 'bottom: 1'
    double ballWidth = tubeWidth - 8.0; // modificar la anchura del cubo

    double tubeMouthHeight = 8.0;
    double tubeBaseRenderHeight = 12.0;
    double ballContainerBottomPadding = 12.0;


    return GestureDetector(
      onTap: () => _selectTube(index),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        width: tubeWidth,
        height: tubeTotalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Base del tubo
            Positioned(
              bottom: 0,
              child: Container(
                width: tubeWidth, height: tubeBaseRenderHeight,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(50), // Como en el original
                  boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.2), blurRadius: 8, spreadRadius: 1)],
                ),
              ),
            ),
            // Cuerpo del tubo
            Positioned(
              bottom: tubeBodyBottomOffset, // 4
              child: Container(
                width: tubeWidth, height: tubeBodyHeight, // 135
                decoration: BoxDecoration(
                  color: widget.theme.tubeColor.withOpacity(0.05 /*isFrozen ? 0.3 : 0.05*/),
                  border: Border.all(
                    color: isSelected ? Colors.amber.shade400.withOpacity(0.8)
                        : (isHintFrom || isHintTo) ? Colors.green.withOpacity(0.8)
                    // : isFrozen ? Colors.blue.withOpacity(0.8)
                        : widget.theme.tubeColor,
                    width: isSelected ? 2.5 : (isHintFrom || isHintTo) ? 2.0 : 1.0, /*isFrozen ? 1.5 : 1.0*/
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(12)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: Offset(0, 4)),
                    if (isSelected) BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 12, spreadRadius: 1),
                    if (isHintFrom || isHintTo) BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 12, spreadRadius: 1),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(12)),
                  child: Stack( // Aquí iban los efectos de luz originales
                    children: [
                      // Los efectos de luz que tenías en el original, si los quieres de vuelta
                      // Ejemplo:
                      // Positioned(
                      //   top: 12, left: 8,
                      //   child: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15))),
                      // ),
                      // Positioned(
                      //   top: 25, right: 4,
                      //   child: Container(width: 8, height: 30, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.transparent], begin: Alignment.centerRight, end: Alignment.centerLeft))),
                      // ),
                    ],
                  ),
                ),
              ),
            ),
            // Bolas de colores
            if (tube.isNotEmpty)
              Positioned(
                bottom: ballContainerBottomPadding, // 12
                child: Column(
                  // Este Column se llena de abajo hacia arriba visualmente debido al .reversed
                  children: [
                    SizedBox(height: 8), // Este SizedBox estaba en tu código original
                    ...tube.asMap().entries.map((entry) { // Mapeamos la lista original
                      int i_original_index = entry.key; // Índice en la lista 'tube' (0 es la de abajo)
                      Color color = entry.value;

                      // isTop DETERMINA QUÉ BOLA SE CONSIDERA "SUPERIOR" PARA LA ANIMACIÓN Y SELECCIÓN.
                      // Debe corresponder a la última bola en la lista lógica 'tube'.
                      bool isTop = i_original_index == tube.length - 1;
                      bool isSelectedBlock = isSelected && isTop; // La bola seleccionada es la superior del tubo seleccionado

                      // Fórmula de elevación original
                      double elevationOffset = 0.0;
                      if (isSelectedBlock) {
                        // Esta es la fórmula que tenías y que funcionaba con tu lógica original
                        //elevationOffset = -(110 - (tube.length * 32) + 12).toDouble();
                        elevationOffset = -(130.0 - (tube.length * 32.0) + 12.0);
                        //formula:
                        //altura total del tubo : 140
                        //altura ocupada por cubos: tube.lenght*32
                        //margen inferior 12
                        //esto coloca el cubo justo en la boca del tubo
                        // Si la bola se eleva demasiado o muy poco, este "12.0" es el ajuste fino.
                        // Otra forma de calcularlo era:
                        // elevationOffset = -(tubeTotalHeight - (tube.length * ballHeight + (tube.length -1) * ballMarginBottomOriginal) - ballContainerBottomPadding - tubeMouthHeight + (ballHeight/2) );
                        // Pero usemos la que proporcionaste que funcionaba.
                      }


                      return AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        margin: EdgeInsets.only(bottom: ballMarginBottomOriginal), // Original: bottom: 1
                        width: ballWidth, // Original: tubeWidth - 8
                        height: ballHeight, // Original: 32
                        decoration: BoxDecoration( // Decoración original de las bolas
                          color: color,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(isTop ? 6 : 0), // Si es la superior lógica (isTop), se redondea arriba
                            bottom: Radius.circular(4),
                          ),
                          boxShadow: [
                            BoxShadow(color: color.withOpacity(0.7), blurRadius: 6, spreadRadius: 1, offset: Offset(0, 2)),
                            BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 4, spreadRadius: 0, offset: Offset(0, -1)),
                            if (isTop && isSelected) BoxShadow(color: Colors.white.withOpacity(0.8), blurRadius: 8, spreadRadius: 1),
                          ],
                          gradient: LinearGradient(
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [color.withOpacity(0.95), HSLColor.fromColor(color).withLightness(max(0, HSLColor.fromColor(color).lightness - 0.1)).toColor().withOpacity(0.8)],
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
                        ),
                        child: Center(
                          child: Icon(
                            _colorIcons[color] ?? Icons.circle,
                            size: 20, color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        transform: Matrix4.identity()..translate(0.0, elevationOffset),
                      );
                    }).toList().reversed, // <<-- AQUÍ ESTÁ EL .reversed QUE TENÍAS ORIGINALMENTE
                  ],
                ),
              ),
            // Boca del tubo
            Positioned(
              top: 13, // Ajustado para estar realmente en la parte superior del widget del tubo (era 4)
              child: Container(
                width: tubeWidth,
                height: tubeMouthHeight, // 12
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
                ),
              ),
            ),
            // if (isFrozen) // Indicador de congelado
            //   Positioned( top: 4, right: 4, child: Icon( Icons.ac_unit, color: Colors.blue, size: 16)),
          ],
        ),
      ),
    );
  }


  Widget _buildTutorialOverlay() {
    return GestureDetector(
      onTap: _completeTutorial,
      child: Container(
        color: Colors.black.withOpacity(0.7), padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tr('tutorialWelcome', args: ['TubeSort!']), style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center), // Asegurar que 'tutorialWelcome' acepte un argumento
            SizedBox(height: 30),
            _buildTutorialStep(icon: Icons.swap_vert, title: tr('tutorialMoveTitle'), description: tr('tutorialMoveDesc')),
            SizedBox(height: 20),
            _buildTutorialStep(icon: Icons.undo, title: tr('tutorialUndoTitle'), description: tr('tutorialUndoDesc')),
            SizedBox(height: 20),
            _buildTutorialStep(icon: Icons.lightbulb_outline, title: tr('tutorialTipTitle'), description: tr('tutorialTipDesc')),
            SizedBox(height: 30),
            GlassButton(
              text: tr('understood'),
              onPressed: _completeTutorial,
              textColor: widget.theme.textColor,
              gradientColors: [widget.theme.colorPalette[2], widget.theme.colorPalette[5]],
              borderColor: widget.theme.textColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialStep({required IconData icon, required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.yellow, size: 30),
        SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text(description, style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _build3DPowerUpButton({ required IconData icon, required Color color, required int count, required VoidCallback onPressed, required String tooltip }) {
    return Tooltip(
      message: tr(tooltip, namedArgs: {'count': count.toString()}), // Asumiendo que el tooltip usa el contador
      child: Container(
        //padding: EdgeInsets.only(top:0), // Eliminado o ajustado si es necesario
        margin: EdgeInsets.symmetric(horizontal: 2, vertical: 4), // Ajustar margen para que quepan
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container( // Botón base
              width: 40, height: 40, // Tamaño fijo para consistencia
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.9), color.withOpacity(0.7)],
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, spreadRadius: 1, offset: Offset(2, 2)),
                  BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 3, spreadRadius: 1, offset: Offset(-1, -1)),
                ],
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
              ),
              child: IconButton(
                padding: EdgeInsets.zero, // Quitar padding del IconButton
                icon: Icon(icon, size: 20), // Tamaño del ícono
                color: Colors.white,
                onPressed: onPressed,
              ),
            ),
            if (count > 0) // Contador
              Positioned(
                right: 0, top: 0,
                child: Container(
                  padding: EdgeInsets.all(count > 9 ? 3 : 4), // Ajustar padding para números de dos dígitos
                  decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 0.5)),
                  constraints: BoxConstraints(minWidth: 16, minHeight: 16), // Tamaño mínimo del círculo
                  child: Text(
                    '$count',
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  // NUEVO METODO PARA CONSTRUIR LA FILA DE ESTADÍSTICAS
  PreferredSizeWidget _buildStatsRow(BuildContext context) {
    // Usamos PreferredSize para darle una altura definida a esta sección del AppBar
    // Ajusta la altura (ej. 24.0 o 30.0) según el tamaño de tu texto y el espaciado deseado
    double statsRowHeight = 28.0;

    return PreferredSize(
      preferredSize: Size.fromHeight(statsRowHeight),
      child: Container(
        // Opcional: Añadir un color de fondo sutil o decoración si es necesario
        // para que las estadísticas se destaquen del fondo de la pantalla.
        // color: widget.theme.backgroundColor.withOpacity(0.1), // Ejemplo
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0), // Espaciado interno
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribuye el espacio
          children: <Widget>[
            Text(
              '${tr('level')}: $_currentLevel',
              style: TextStyle(color: widget.theme.textColor, fontSize: 14), // Ajusta tamaño si es necesario
            ),
            Text(
              '${tr('moves')}: $_moves',
              style: TextStyle(color: widget.theme.textColor, fontSize: 14),
            ),
            if (widget.gameMode == GameMode.timed)
              Text(
                '${tr('time')}: ${_timeLeft.inMinutes}:${(_timeLeft.inSeconds % 60).toString().padLeft(2, '0')}',
                style: TextStyle(color: widget.theme.textColor, fontSize: 14),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
        builder: (context, orientation) {
          final bool isPortrait = orientation == Orientation.portrait;
          double appBarTitleActionsHeight = 48.0; // Tu toolbarHeight original
          double statsRowHeight = 28.0; // La misma altura definida en _buildStatsRow

          return Scaffold(
            backgroundColor: widget.theme.backgroundColor,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: Text(_getModeName(widget.gameMode), style: appBarTextStyle.copyWith(fontSize: 20, color: widget.theme.textColor)), // Usar appBarTextStyle
              centerTitle: true,
              backgroundColor: Colors.transparent, elevation: 0, toolbarHeight: 38,
              leading: IconButton( // Botón de regreso
                icon: Icon(Icons.arrow_back, color: widget.theme.textColor),
                onPressed: () => Navigator.of(context).pop(),
              ),
              //flexibleSpace: Container(
                //decoration: BoxDecoration(
                  //gradient: LinearGradient(
                    //colors: [widget.theme.colorPalette[0].withOpacity(0.9), widget.theme.colorPalette[2].withOpacity(0.9)],
                    //begin: Alignment.topCenter, end: Alignment.bottomCenter,
                 // ),
                //),
              //),
              actions: [
                if (widget.gameMode != GameMode.oneTap)
                  _build3DPowerUpButton(icon: Icons.add_circle_outline, color: widget.theme.colorPalette[4], count: _addTubeUses, onPressed: _useAddTubePower, tooltip: 'tooltipAddTube'),
                _build3DPowerUpButton(icon: Icons.replay, color: widget.theme.colorPalette[2], count: _rewindUses, onPressed: _useRewindPower, tooltip: 'tooltipRewind'),
                _build3DPowerUpButton(icon: Icons.lightbulb_outline, color: widget.theme.colorPalette[5], count: _hintUses, onPressed: _showHint, tooltip: 'tooltipHint'),
                SizedBox(width: 8), // Espacio al final
              ],
              bottom: _buildStatsRow(context), // <--- ESTADÍSTICAS EN EL BOTTOM DEL APPBAR
            ),
            body: Stack(
              children: [
                //if (widget.theme.backgroundImage.isNotEmpty)
                 // Positioned.fill(child: Image.asset('assets/images/wood_texture.jpg', fit: BoxFit.cover, )),
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/wood_texture.png', // <--- PON TU RUTA EXACTA AQUÍ
                    fit: BoxFit.cover,
                    errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                      //print("Error al cargar la imagen de fondo: $exception");
                      print("ERROR AL CARGAR LA IMAGEN DE FONDO (GameScreen): $exception");
                      //return Text('Error al cargar imagen', style: TextStyle(color: Colors.red)); // Muestra un error en la UI
                      return Container(
                          color: Colors.red.withOpacity(0.3), // Un color para indicar visualmente el error
                      child: Center(
                      child: Text(
                      'Error cargando fondo',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      ),
                      );
                    },
                  ),
                ),
                //Column(
                  //children: [
                    // if (widget.gameMode == GameMode.timed)
                    //   Padding(
                    //     padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    //     child: LinearProgressIndicator(
                    //       value: (_timeLeft.inSeconds / (Duration(minutes: 2) + Duration(seconds: _currentLevel * 5)).inSeconds).clamp(0.0, 1.0),
                    //       backgroundColor: Colors.grey.withOpacity(0.3),
                    //       valueColor: AlwaysStoppedAnimation<Color>(_timeLeft.inSeconds < 30 ? Colors.red : Colors.green),
                    //     ),
                    //   ),
                    Padding(
                      //padding: EdgeInsets.symmetric(horizontal: 20, vertical: 60),//modificar la posicion de label level y movimiento
                        padding: EdgeInsets.only(
                          top: appBarTitleActionsHeight + statsRowHeight + MediaQuery.of(context).padding.top,
                        ),
                        child: Column(
                        children: [
                        // La barra de progreso del modo cronometrado
                        if (widget.gameMode == GameMode.timed)
                        Padding(
                        padding: EdgeInsets.only(top: 4.0, left: 20, right: 20, bottom: 8.0), // Ajusta padding
                        child: LinearProgressIndicator(
                        value: (_timeLeft.inSeconds / (Duration(minutes: 2) + Duration(seconds: widget.level * 5)).inSeconds).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(_timeLeft.inSeconds < 30 ? Colors.red : Colors.green),
                        ),
                        ),


                    Expanded(
                      child: GridView.builder(
                        //padding: EdgeInsets.all(8.0),
                        //padding: EdgeInsets.only(top: kToolbarHeight + MediaQuery.of(context).padding.top),
                        padding: EdgeInsets.only(top: 0.0, left: 16.0, right: 16.0, bottom: 16.0),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isPortrait ? 5 : 8,
                          childAspectRatio: isPortrait ? ( (MediaQuery.of(context).size.width / 5) / 180 ) : ( (MediaQuery.of(context).size.width / 8) / 150 ), // Ajustar aspect ratio
                          mainAxisSpacing: 2, crossAxisSpacing: 2, // Reducir espaciado
                        ),
                        itemCount: tubes.length,
                        itemBuilder: (context, index) {
                          return _buildRealisticTube(tubes[index], index, isPortrait: isPortrait);
                        },
                      ),
                    ),
                    // Los mensajes de Wildcard/Freeze se eliminan ya que la lógica no está implementada
                    if (_isBannerAdLoaded && _bannerAd != null)
                      Container(
                        height: _bannerAd!.size.height.toDouble(), width: double.infinity,
                        child: AdWidget(ad: _bannerAd!), alignment: Alignment.center,
                      ),
                  ],
                ),
                      ),
                if (_showTutorial) _buildTutorialOverlay(),
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive, shouldLoop: false,
                    colors: widget.theme.colorPalette,
                  ),
                ),
              ],
            ),
          );
        }
    );
  }
}

