import java.io.FileInputStream
import java.util.*

plugins {
    id("com.android.application")
    kotlin("android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}
// Carga segura de key.properties
val keystoreProperties = Properties().apply {
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }else {
        logger.error("¡Archivo key.properties no encontrado!")
  }
}
android {
    namespace = "com.manlorstudios.juego_casillas_colores2"
    compileSdk = flutter.compileSdkVersion.toInt()

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    aaptOptions {
        noCompress("mp3")
    }

    kotlinOptions {
        jvmTarget = "21"
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a")
            isUniversalApk = true
        }
    }

    defaultConfig {
        applicationId = "com.manlorstudios.juego_casillas_colores2"
        minSdk = 23
        targetSdk = 34
        versionCode = 6
        versionName = "6.0.0"
        multiDexEnabled = true

        ndk {
            abiFilters.add("armeabi-v7a")
            abiFilters.add("arm64-v8a")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isDebuggable = false
            isMinifyEnabled = true
            ndk {
                debugSymbolLevel = "FULL"
                abiFilters.clear()
                abiFilters.add("x86_64")
                abiFilters.add("armeabi-v7a")
                abiFilters.add("arm64-v8a")
            }
        }

        debug {
            ndk {
                abiFilters.clear()
                abiFilters.add("x86_64")
                abiFilters.add("armeabi-v7a")
                abiFilters.add("arm64-v8a")
            }
        }
    }

    configurations.all {
        resolutionStrategy {
            force("com.google.android.gms:play-services-measurement:22.4.0")
            force("com.google.android.gms:play-services-measurement-base:22.4.0")
            force("com.google.android.gms:play-services-measurement-impl:22.4.0")
            force("com.google.android.gms:play-services-measurement-sdk-api:22.4.0")
            force("com.google.android.gms:play-services-measurement-sdk:22.4.0")
            force("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.22")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.android.gms:play-services-ads:22.6.0")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("com.google.gms:google-services:4.4.2")
    implementation("org.jetbrains.kotlin:kotlin-stdlib:2.1.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("com.google.android.gms:play-services-measurement-api:22.4.0")
    implementation("androidx.activity:activity-ktx:1.10.1")
}

repositories {
    google()
    mavenCentral()
}