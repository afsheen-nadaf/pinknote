pluginManagement {
    plugins {
        id("org.jetbrains.kotlin.jvm") version "2.1.0"
    }
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.3" apply false
    id("com.google.gms.google-services") version("4.3.15") apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
gradle.beforeProject {
    if (project.name == ".gradle" || project.projectDir.name == ".gradle") {
        throw GradleException("'.gradle' directory is not a valid module and must be ignored.")
    }
}