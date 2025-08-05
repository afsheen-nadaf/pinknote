// Top-level build file for the Android part of your Flutter project.
// NOTE: This file uses Kotlin DSL (.kts)

plugins {
    // NOTE: The plugins block has a special scope and cannot access variables
    // from the main script body. The version is hardcoded here to resolve the error.
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("com.google.gms.google-services") version "4.3.15" apply false
}

// This block applies configurations to ALL modules in the project
// (the root, your :app, and all third-party plugins).
allprojects {
    // This ensures all modules can find dependencies from the same repositories.
    repositories {
        google()
        mavenCentral()
    }

    // ✅ THE MOST AGGRESSIVE FIX:
    // This code finds every single Kotlin compilation task in your entire project
    // and explicitly tells it to compile for Java 17. By putting this in `allprojects`,
    // we can finally override the bad settings from the stubborn `app_settings` plugin.
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = "17"
        }
    }
}

// Standard Flutter configuration to manage the build directory.
rootProject.buildDir = file("../build")
subprojects {
    project.buildDir = file("${rootProject.buildDir}/${project.name}")
}

// Standard Flutter configuration for the 'flutter clean' command.
tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}