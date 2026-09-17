allprojects {
    repositories {
        google()
        mavenCentral()
        // 中文：本地预编译的 libqalculate AAR。它没有传递依赖，所以 flatDir 足够
        //       （flatDir 不解析 POM）。
        // English: The locally vendored libqalculate AAR. It declares no transitive
        //          dependencies, so flatDir is sufficient (flatDir does not resolve POMs).
        flatDir { dirs("${rootProject.projectDir}/app/libs") }
    }
}

val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
