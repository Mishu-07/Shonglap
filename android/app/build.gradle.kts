// android/app/build.gradle.kts

import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

fun readProperties(file: java.io.File): Properties {
    val properties = Properties()
    if (file.exists()) {
        properties.load(file.inputStream())
    }
    return properties
}

val localProperties = readProperties(rootProject.file("local.properties"))
val flutterRoot = localProperties.getProperty("flutter.sdk") ?: throw GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")

val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.example.first_app"
    compileSdk = flutter.compileSdkVersion// Or use flutter.compileSdkVersion if defined elsewhere
    ndkVersion = "27.0.12077973" // Or use flutter.ndkVersion

    compileOptions {
        // **FIX**: Added core library desugaring for notifications package.
        isCoreLibraryDesugaringEnabled = true
        // **FIX**: Reverted to Java 1.8 for better compatibility.
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        // Using your custom Application ID
        applicationId = "com.cse21.kothopokothon"
        minSdk = 23
        targetSdk = 33 // Or use flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
        // **FIX**: Corrected the property name for multiDex.
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    // **FIX**: Corrected the type to be a String.
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.8.20") // Use a specific version
    // **FIX**: Re-added the desugaring library dependency.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
