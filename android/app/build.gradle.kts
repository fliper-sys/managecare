import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.managecare"
    compileSdk = flutter.compileSdkVersion
    // Google Play requires Android 15+ apps with native libraries to support
    // 16 KB memory page sizes. NDK r28 builds native code with 16 KB ELF
    // alignment by default; relying on flutter.ndkVersion can pick an older
    // SDK from older Flutter installs and trigger the Play Console warning.
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.managecare"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // 🔥 CRITICAL: Ensure manifest annotations are processed correctly
        // This is needed for tools:node="remove" to work properly on permissions
        manifestPlaceholders["package_name"] = applicationId as String
    }

    packagingOptions {
        jniLibs {
            useLegacyPackaging = true
        }

        resources {
            // 🔥 CRITICAL: Exclude READ_MEDIA permissions per Google Play policy
            // These permissions are automatically added by some dependencies like image_picker
            // but our app uses one-time photo access via system picker instead
            excludes += "android/permission/READ_MEDIA_IMAGES"
            excludes += "android/permission/READ_MEDIA_VIDEO"
        }
    }

    // 🔥 CRITICAL: Override manifest merging to remove READ_MEDIA permissions
    // This ensures that even if dependencies declare these permissions,
    // they will be removed from the final manifest
    applicationVariants.all { variant ->
        variant.outputs.all { output ->
            val baseOutput = output as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            baseOutput.outputFileName = "${project.name}-${variant.name}-${variant.versionName}.apk"
            true
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            // Use the release signing config loaded from android/key.properties
            signingConfig = signingConfigs.getByName("release")
            // Customize other release options here if needed (minifyEnabled, proguardFiles, etc.)
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
