// Define la versión de Kotlin al inicio del archivo
val kotlinVersion by extra("1.9.22")

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.3.2")
        //classpath(kotlin("gradle-plugin", kotlinVersion)) // Usa la variable definida
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.22")
        classpath("com.google.gms:google-services:4.4.2")
    }
}

plugins {
    id("com.android.application") version "8.7.3" apply false
    kotlin("android") version "2.1.0" apply false // Versión explícita
    id("com.google.gms.google-services") version "4.4.2" apply false
    id("dev.flutter.flutter-gradle-plugin") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }

    // Configuración de Kotlin para todos los subproyectos
    //tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach(){

        kotlinOptions {
            jvmTarget = "21"
            apiVersion = "1.9"
        }
    }
}

// Configuración de directorios (mantener igual)
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}