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
        "grove: no android/key.properties, so a release build is signed " +
            "with the debug key and cannot be uploaded to Play."
    )
}

android {
    namespace = "com.tyttest.grove"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs this: it uses java.time to work
        // out when a scheduled notification fires, and desugaring is what
        // puts java.time on the Android versions below 26 that this app still
        // supports. Without it the build fails outright at
        // checkReleaseAarMetadata rather than at runtime, which is the right
        // place for it to fail.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.tyttest.grove"
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

dependencies {
    // The version flutter_local_notifications names. The plugin's own example
    // also adds androidx.window 1.0.0 against an old report of desugaring
    // crashing on Android 12L; that is not copied here, because Flutter's
    // embedding already brings androidx.window-java 1.2.0 in.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
