plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
    // [FIX-CRASHREPORT-01] راجع DECISIONS.md — يرفع تلقائياً ملف mapping.txt
    // الخاص بـProGuard/R8 مع كل بناء إصدار (isMinifyEnabled=true بـ
    // app/build.gradle.kts أصلاً)، حتى تظهر تتبعات الأعطال بأسماء حقيقية على
    // Firebase Console بدل رموز مبهمة. نسخة الإضافة مطابقة لما هو مُختبَر
    // فعلياً بمستودع FlutterFire الرسمي مع firebase_crashlytics 5.3.0
    // (نفس الإصدار المضاف بـpubspec.yaml).
    id("com.google.firebase.crashlytics") version "2.8.1" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}