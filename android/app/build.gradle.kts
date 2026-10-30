import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropsFile = rootProject.file("signing/keystore.properties")
val signingProps = Properties()
if (signingPropsFile.exists()) {
    signingProps.load(FileInputStream(signingPropsFile))
}

android {
    namespace = "com.howtocook.how_to_cook"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.howtocook.how_to_cook"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (signingPropsFile.exists()) {
                keyAlias = signingProps["keyAlias"] as String
                keyPassword = signingProps["keyPassword"] as String
                storePassword = signingProps["storePassword"] as String
                storeFile = rootProject.file("signing/${signingProps["storeFile"]}")
            }
        }
    }

    buildTypes {
        release {
            // Stable sideload key (android/signing/) — never ephemeral CI debug.keystore.
            signingConfig = if (signingPropsFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
