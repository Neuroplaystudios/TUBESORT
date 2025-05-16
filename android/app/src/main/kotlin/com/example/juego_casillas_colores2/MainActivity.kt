package com.manlorstudios.juego_casillas_colores2

import io.flutter.embedding.android.FlutterActivity

import com.google.android.gms.ads.MobileAds


class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)

        // Inicializar MobileAds aquí
        MobileAds.initialize(this) { initializationStatus ->
            // Aquí puedes manejar el estado de la inicialización si es necesario
        }
    }
}
