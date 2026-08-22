import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Keep local builds usable before Firebase creates the real JSON configuration.
// Once android/app/google-services.json exists, this generates the native
// Firebase resources consumed by Firebase.initializeApp().
if (rootProject.file("app/google-services.json").isFile) {
    apply(plugin = "com.google.gms.google-services")
}

val signingProperties = Properties().also { properties ->
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use(properties::load)
}

android {
    namespace = "com.focusflow.planner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Release lint is run separately in CI. Older third-party Flutter plugins
    // request legacy desugaring artifacts while generating their lint models;
    // that should not block packaging a verified application binary.
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.focusflow.planner"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = signingProperties.getProperty("storeFile")
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // build_release.ps1 refuses production builds without key.properties.
            // Keep debug builds usable in development environments without a private keystore.
            signingConfig = if (signingProperties.getProperty("storeFile") == null) signingConfigs.getByName("debug") else signingConfigs.getByName("release")
            // Huawei's optional analytics classes are not packaged unless its
            // service configuration is enabled. Avoid R8 treating those
            // optional references as hard release dependencies.
            isMinifyEnabled = false
            isShrinkResources = false
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
    val localWechatAar = rootProject.file(
        "../.tools/local-maven/com/tencent/mm/opensdk/wechat-sdk-android-without-mta/6.8.0/" +
            "wechat-sdk-android-without-mta-6.8.0.aar",
    )
    if (localWechatAar.isFile) {
        implementation(files(localWechatAar))
    } else {
        implementation("com.tencent.mm.opensdk:wechat-sdk-android-without-mta:6.8.0")
    }
}
