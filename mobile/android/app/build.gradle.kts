plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePath = System.getenv("PLANIT_ANDROID_KEYSTORE_PATH")
val releaseKeystorePassword = System.getenv("PLANIT_ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = System.getenv("PLANIT_ANDROID_KEY_ALIAS")
val releaseKeyPassword = System.getenv("PLANIT_ANDROID_KEY_PASSWORD")
val releaseSigningValues =
    listOf(
        releaseKeystorePath,
        releaseKeystorePassword,
        releaseKeyAlias,
        releaseKeyPassword,
    )
val configuredReleaseSigningValues = releaseSigningValues.count { !it.isNullOrBlank() }
require(configuredReleaseSigningValues == 0 || configuredReleaseSigningValues == releaseSigningValues.size) {
    "Android release signing is partially configured. Set all PLANIT_ANDROID_* signing variables."
}

android {
    namespace = "com.abrghaze.planit"
    // flutter_secure_storage 11 requires compile SDK 37.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.abrghaze.planit"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (configuredReleaseSigningValues == releaseSigningValues.size) {
        signingConfigs {
            create("release") {
                storeFile = file(requireNotNull(releaseKeystorePath))
                storePassword = requireNotNull(releaseKeystorePassword)
                keyAlias = requireNotNull(releaseKeyAlias)
                keyPassword = requireNotNull(releaseKeyPassword)
            }
        }
        buildTypes {
            getByName("release") {
                signingConfig = signingConfigs.getByName("release")
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
