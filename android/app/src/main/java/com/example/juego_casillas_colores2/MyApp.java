package com.manlorstudios.juego_casillas_colores2;  // ¡Debe coincidir exactamente!

import com.google.android.gms.ads.MobileAds;
import androidx.multidex.MultiDexApplication;
public class  MyApp extends MultiDexApplication {
    @Override
    public void onCreate() {
        super.onCreate();
        MobileAds.initialize(this, initializationStatus -> {});
        //MobileAds.initialize(this); // Inicializa AdMob
    }
}
