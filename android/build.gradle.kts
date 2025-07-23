// Top-level build file for the Android part of your Flutter project.

val kotlinVersion = "2.1.0" // ✅ camelCase for Kotlin DSL

plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("com.google.gms.google-services") version "4.3.15" apply false
}


// Configure repositories used by all sub-projects (your app + plugins)
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Redirect build outputs to the main /build folder
rootProject.buildDir = file("../build")
subprojects {
    project.buildDir = file("${rootProject.buildDir}/${project.name}")
    project.evaluationDependsOn(":app")
}

// Register 'clean' task for `flutter clean`
tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}