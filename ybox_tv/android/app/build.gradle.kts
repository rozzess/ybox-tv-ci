plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "tv.ybox.ybox_tv"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "tv.ybox.ybox_tv"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23 // Firebase Auth requires 23+
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        val tvBox = System.getenv("YBOX_TVBOX") == "1"
        // TV-box APK: hard-lock the window to landscape at the manifest
        // level (runtime TV detection can't be trusted — cheap boxes report
        // themselves as touch phones, which rendered the app as a portrait
        // phone-shaped window on the TV, splash included).
        manifestPlaceholders["screenOrientation"] =
            if (tvBox) "sensorLandscape" else "unspecified"
        if (tvBox) {
            // One APK that installs on both 32- and 64-bit ARM boxes but
            // skips the x86 libs (media_kit's FFmpeg is ~18 MB per ABI).
            // --target-platform can't do this — it only filters the Flutter
            // engine, not plugin .so files.
            ndk { abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a")) }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
