import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Google Home APIs SDK is distributed as AAR files (not on Maven). When they
// are dropped in app/libs/homeapis the real Google Home controller is
// compiled; otherwise a stub reports "sdkMissing". See libs/homeapis/README.md.
val homeApisDir = file("libs/homeapis")
val homeApisPresent =
    homeApisDir.isDirectory && (homeApisDir.listFiles()?.any { it.name.endsWith(".aar") } ?: false)
logger.lifecycle("SleepStop: Home APIs SDK ${if (homeApisPresent) "present" else "absent"} (libs/homeapis)")

android {
    namespace = "com.sleepstop.sleep_stop"
    compileSdk = maxOf(35, flutter.compileSdkVersion)
    ndkVersion = flutter.ndkVersion

    sourceSets {
        getByName("main") {
            kotlin.srcDir(if (homeApisPresent) "src/homeapis/kotlin" else "src/homeapis-stub/kotlin")
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
        if (homeApisPresent) {
            // Home APIs 1.11 ships Kotlin 2.4 metadata; the project is on 2.2.
            freeCompilerArgs += "-Xskip-metadata-version-check"
        }
    }

    defaultConfig {
        applicationId = "com.sleepstop.sleep_stop"
        minSdk = 26
        // Google Play requires API 36 (Android 16) for new apps since 31 Aug 2026.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Ship native symbol tables to Play Console (crash symbolication) as a
            // separate bundle entry instead of keeping unstripped .so files in the APKs.
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    if (homeApisPresent) {
        implementation(fileTree(mapOf("dir" to "libs/homeapis", "include" to listOf("*.aar"))))
        // Required by the Home APIs SDK (explicit import mandated since 1.11).
        implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
        implementation("com.google.android.gms:play-services-base:18.7.2")
        implementation("androidx.activity:activity-ktx:1.10.1")
    }
}

flutter {
    source = "../.."
}
