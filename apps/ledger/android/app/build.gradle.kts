import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload keys live in android/key.properties, which is not in the repository.
// See android/README.md for what belongs in it.
val keystore = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

// The Flutter template signs release builds with the debug key so that
// `flutter run --release` works out of the box. That is worth keeping, but
// not worth keeping quiet about: a debug-signed bundle passes every step up
// to the Play Console, which is where it is rejected.
val hasUploadKey = keystore.getProperty("storeFile") != null
if (!hasUploadKey) {
    logger.lifecycle(
        "ledger: no android/key.properties, so a release build is signed " +
            "with the debug key and cannot be uploaded to Play."
    )
}

android {
    namespace = "com.tyttest.ledger"
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
        applicationId = "com.tyttest.ledger"
        // Pinned rather than inherited from the Flutter tool: these decide
        // which phones can install the app and how the system treats it, and
        // they should change because someone decided to, not because the
        // Flutter version on the build machine moved.
        //
        // 24 is Android 7.0, which is also as far back as the icon goes:
        // adaptive icons start at 26, so 24 and 25 get the flat bitmap and
        // anything older would get nothing worth shipping.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                storeFile = rootProject.file(keystore.getProperty("storeFile"))
                storePassword = keystore.getProperty("storePassword")
                keyAlias = keystore.getProperty("keyAlias")
                keyPassword = keystore.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                signingConfigs.findByName("release")
                    ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
