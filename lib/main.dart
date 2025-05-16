import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'managers/sound_manager.dart';
import 'app_widget.dart'; // Nuevo archivo

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp();
  await MobileAds.instance.initialize();
  await SoundManager.init();

  runApp(
    EasyLocalization(
      supportedLocales: [
        Locale('en'), // Inglés
        Locale('es'), // Español
        Locale('fr'), // Francés
        Locale('ru'), // Ruso
        Locale('zh'), // Chino
      ],
      path: 'assets/translations', // Ruta a tus archivos JSON
      fallbackLocale: Locale('en'),
      child: ColorSortApp(), // Widget principal de la aplicación
    ),
  );
}