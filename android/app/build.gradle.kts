import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // android.builtInKotlin=false in gradle.properties, so the Kotlin Android
    // plugin has to be applied here for the kotlin { } block below to resolve.
    // Its version is declared in android/settings.gradle.kts.
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Play Store upload key: android/key.properties (never committed), e.g.
//   storePassword=…
//   keyPassword=…
//   keyAlias=upload
//   storeFile=C:/keys/ieltsai-upload.jks
// Without it, release builds are signed with the debug key (fine for
// `flutter run --release`, refused by Google Play).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.nextedadvisors.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "30.0.16248370"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (scheduled reminders) needs Java 8+ APIs.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.nextedadvisors.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Content protection: screenshots, screen recording and casting are
        // blocked, and a debugger is refused. Debug builds turn it off below.
        //
        // `nextedSecure` in gradle.properties turns it off for release builds
        // too, which is what a demo needs - someone showing the app has to be
        // able to take a screenshot of it. A build for the store must have it
        // back on.
        manifestPlaceholders["secureMode"] =
            (project.findProperty("nextedSecure") as String? ?: "true")
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            // `flutter run`: screenshots allowed while developing.
            manifestPlaceholders["secureMode"] = "false"
        }
        release {
            // The upload key when android/key.properties exists, else the debug key.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
