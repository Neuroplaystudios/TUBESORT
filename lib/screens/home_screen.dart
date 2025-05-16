import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:confetti/confetti.dart';
import 'package:easy_localization/easy_localization.dart';

// Tus widgets y páginas (asegúrate que las rutas sean correctas)
import '../widgets/jumping_title.dart';
import 'ranking_page.dart'; // Asumiendo que es RankingPage()
import 'game_screen.dart';
import '../widgets/glass_button.dart'; // Importa el GlassButton

// Modelos
import '../models/game_theme.dart';
import '../models/game_mode.dart';

// Managers y Utils
import '../managers/sound_manager.dart';
import '../utils/firebase_utils.dart';
import '../utils/language_utils.dart'; // Para getFlagForLanguage

// Constantes
import '../constants/ad_units.dart';


class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showButtons = false; // No parece usarse, considera eliminarla
  int _level = 1;
  int _coins = 0; // No parece usarse directamente en HomeScreen, ¿quizás para mostrar?
  GameMode _selectedMode = GameMode.classic;
  late GameTheme _currentTheme; // Se inicializará en initState
  bool _isMusicOn = true; // Controla el estado visual del botón, no la lógica directa
  bool _isSoundOn = true; // Controla el estado visual del botón, no la lógica directa
  late ConfettiController _confettiController;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  TextEditingController _nameController = TextEditingController(text: 'Jugador123');
  String _selectedLanguage = 'Español'; // Valor inicial

  static final List<GameTheme> _themes = [
    GameTheme(
      name: 'Clásico',
      backgroundColor: Color(0xFF1A1A2E).withOpacity(0.8),
      tubeColor: Colors.white.withOpacity(0.3),
      textColor: Colors.white,
      colorPalette: [
        Colors.red.shade400, Colors.green.shade400, Colors.blue.shade400,
        Colors.orange.shade400, Colors.purple.shade400, Colors.yellow.shade400,
        Colors.teal.shade400, Colors.pink.shade400, Colors.cyan.shade400,
      ],
    ),
    GameTheme(
      name: 'Neón',
      backgroundColor: Color(0xFF0F0F1A),
      tubeColor: Colors.white.withOpacity(0.1),
      textColor: Colors.white,
      colorPalette: [
        Colors.redAccent.shade400, Colors.greenAccent.shade400, Colors.blueAccent.shade400,
        Colors.orangeAccent.shade400, Colors.purpleAccent.shade400, Colors.yellowAccent.shade400,
        Colors.tealAccent.shade400, Colors.pinkAccent.shade400, Colors.cyanAccent.shade400,
      ],
    ),
    GameTheme(
      name: 'Acuarela',
      backgroundColor: Color(0xFFF5F5F5),
      tubeColor: Colors.black.withOpacity(0.1),
      textColor: Colors.black87,
      colorPalette: [
        Color(0xFFFF6B6B), Color(0xFF4ECDC4), Color(0xFF45B7D1),
        Color(0xFFFFA07A), Color(0xFFA18CD1), Color(0xFFFFD166),
        Color(0xFF06D6A0), Color(0xFFFF9FF3), Color(0xFF48D1CC),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentTheme = _themes[0]; // Inicializa el tema actual
    _loadData();
    // SoundManager.init() ya se llama en main.dart, no es necesario aquí
    _confettiController = ConfettiController(duration: Duration(seconds: 3));
    _loadSettingsAndSoundState();
    _loadBannerAd();
  }

  Future<void> _loadSettingsAndSoundState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('playerName') ?? 'Jugador123';
      _selectedLanguage = prefs.getString('language') ?? 'Español'; // O el idioma por defecto de EasyLocalization
      // Actualiza el estado visual de los botones de sonido/música
      _isSoundOn = SoundManager.isSoundsEnabled();
      _isMusicOn = SoundManager.isMusicEnabled(); // Asumiendo que tienes una forma de saber esto también
      // o simplemente _isSoundOn controla ambos visualmente.
      // Para simplificar, _isSoundOn puede controlar el icono de volumen general.
    });
    // No necesitas llamar a _initSoundAndMusic() si SoundManager.init() ya se hizo en main.dart
    // y SoundManager maneja su propio estado interno basado en SharedPreferences.
  }


  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: bannerHomeScreenAdUnitId, // Usar constante
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
          print('Failed to load a banner ad (HomeScreen): ${error.message}');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _confettiController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _level = prefs.getInt('level') ?? 1;
        _coins = prefs.getInt('coins') ?? 0;
        // El estado de sonido/música se carga en _loadSettingsAndSoundState
        // y es manejado por SoundManager
      });
    }
  }

  // _addCoins no se usa en HomeScreen, si es necesario en GameScreen, debe estar allí.

  void _showSettings(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    // Asegurarse que _nameController.text esté actualizado antes de mostrar el diálogo
    _nameController.text = prefs.getString('playerName') ?? 'Jugador123';
    // _selectedLanguage ya debería estar actualizado por _loadSettingsAndSoundState

    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Usar un StatefulWidget para el contenido del diálogo si el Dropdown necesita actualizar su propio estado visualmente
        // dentro del diálogo ANTES de guardar en SharedPreferences. Por ahora, asumimos que setState del HomeScreen es suficiente.
        return StatefulBuilder( // Para que el Dropdown se actualice dentro del diálogo
            builder: (BuildContext context, StateSetter setDialogState) {
              return Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _currentTheme.colorPalette[0].withOpacity(0.9),
                        _currentTheme.colorPalette[2].withOpacity(0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _currentTheme.textColor.withOpacity(0.2), width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tr('settings_title'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _currentTheme.textColor)),
                      SizedBox(height: 20),
                      TextField(
                        controller: _nameController,
                        maxLength: 10,
                        decoration: InputDecoration(
                          labelText: tr('name_label'),
                          counterStyle: TextStyle(color: _currentTheme.textColor),
                          labelStyle: TextStyle(color: _currentTheme.textColor),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _currentTheme.textColor)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _currentTheme.textColor)),
                        ),
                        style: TextStyle(color: _currentTheme.textColor),
                        onChanged: (value) async {
                          final prefsOnChanged = await SharedPreferences.getInstance();
                          prefsOnChanged.setString('playerName', value.isNotEmpty ? value : 'Usuario');
                        },
                      ),
                      SizedBox(height: 15),
                      DropdownButton<String>(
                        value: _selectedLanguage,
                        dropdownColor: _currentTheme.backgroundColor,
                        iconEnabledColor: _currentTheme.textColor,
                        style: TextStyle(color: _currentTheme.textColor),
                        items: ['Español', 'English', 'Русский', 'Français', '中文'].map((String lang) {
                          return DropdownMenuItem<String>(value: lang, child: Text(lang));
                        }).toList(),
                        onChanged: (String? newLang) async {
                          if (newLang != null) {
                            setDialogState(() { // Actualiza el estado del diálogo
                              _selectedLanguage = newLang;
                            });
                            setState(() { // Actualiza el estado de HomeScreen para la bandera
                              _selectedLanguage = newLang;
                            });
                            final prefsOnChanged = await SharedPreferences.getInstance();
                            prefsOnChanged.setString('language', newLang);
                            Locale newLocale;
                            switch (newLang) {
                              case 'English': newLocale = Locale('en'); break;
                              case 'Español': newLocale = Locale('es'); break;
                              case 'Русский': newLocale = Locale('ru'); break;
                              case '中文': newLocale = Locale('zh'); break;
                              case 'Français': newLocale = Locale('fr'); break; // Añadido Francés
                              default: newLocale = Locale('en');
                            }
                            context.setLocale(newLocale);
                          }
                        },
                      ),
                      SizedBox(height: 20),
                      GlassButton(
                        text: tr('close_button'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icons.close,
                        textColor: _currentTheme.textColor,
                        gradientColors: [_currentTheme.colorPalette[2], _currentTheme.colorPalette[5]],
                        borderColor: _currentTheme.textColor,
                      ),
                    ],
                  ),
                ),
              );
            }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentTheme.backgroundColor,
      body: Stack(
        children: [
          if (_currentTheme.backgroundImage.isNotEmpty)
            Positioned.fill(
              child: Image.asset(
                _currentTheme.backgroundImage,
                fit: BoxFit.cover,
                opacity: AlwaysStoppedAnimation(0.1),
              ),
            ),
          Positioned(
            top: 40, left: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.settings, color: _currentTheme.textColor, size: 30),
                  onPressed: () => _showSettings(context),
                ),
                SizedBox(height: 6),
                Text(getFlagForLanguage(_selectedLanguage), style: TextStyle(fontSize: 24)),
              ],
            ),
          ),
          Positioned(
            top: 40, right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: AnimatedSwitcher(
                    duration: Duration(milliseconds: 300),
                    child: Icon(
                      _isSoundOn ? Icons.volume_up : Icons.volume_off, // Controlado por _isSoundOn
                      key: ValueKey<bool>(_isSoundOn),
                      color: _currentTheme.textColor,
                      size: 30,
                    ),
                  ),
                  onPressed: () async {
                    bool newSoundState = !_isSoundOn;
                    await SoundManager.toggleSounds(newSoundState);
                    // Sincronizar con el estado de la música si la lógica es combinada
                    // await SoundManager.toggleMusic(newSoundState);
                    setState(() {
                      _isSoundOn = newSoundState;
                      _isMusicOn = newSoundState; // Si un botón controla ambos
                    });
                  },
                ),
                SizedBox(height: 6),
                IconButton(
                  icon: Icon(Icons.emoji_events, color: Colors.amber, size: 30),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RankingPage()));
                  },
                ),
              ],
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                JumpingTitle(),
                SizedBox(height: 400),
                GlassButton(
                  text: tr('level_label', namedArgs: {'number': _level.toString()}),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GameScreen(
                          level: _level,
                          theme: _currentTheme,
                          gameMode: _selectedMode,
                        ),
                      ),
                    );
                    await _loadData(); // Recargar nivel y datos
                    await guardarProgresoFirebase();
                  },
                  icon: Icons.play_arrow,
                  textColor: _currentTheme.textColor,
                  gradientColors: [_currentTheme.colorPalette[2], _currentTheme.colorPalette[5]],
                  borderColor: _currentTheme.textColor,
                ),
                SizedBox(height: 100),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: _currentTheme.colorPalette,
            ),
          ),
          if (_isBannerAdLoaded && _bannerAd != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: _bannerAd!.size.height.toDouble(),
                width: double.infinity,
                child: AdWidget(ad: _bannerAd!),
                alignment: Alignment.center,
              ),
            ),
        ],
      ),
    );
  }
}