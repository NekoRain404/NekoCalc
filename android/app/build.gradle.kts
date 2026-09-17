import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.nekorain.nekocalc"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.nekorain.nekocalc"
        // 中文：写死 24，因为 libqalculate AAR 的 minSdk 就是 24。跟随
        //       flutter.minSdkVersion 只是碰巧相等，一次 Flutter 升级就可能让清单合并失败。
        // English: Pinned to 24 because the libqalculate AAR declares minSdk 24. Following
        //          flutter.minSdkVersion only matches by coincidence today, and a Flutter
        //          upgrade could break the manifest merge.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // 中文：正式发布时读取本机私有签名配置；仓库只保留 example，避免泄露密钥。
            // English: Read private signing config only on release machines; the repo keeps only the example file.
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // 中文：没有正式 keystore 时回退 debug 签名，保证开发机仍可构建体验包。
            // English: Fall back to debug signing without a release keystore so local test builds keep working.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 中文：libqalculate v5.12.0（GPL-2.0-or-later，与本项目 GPL-3.0 兼容），
    //       预编译版只有 arm64-v8a。name 是文件名去掉 .aar 后缀，flatDir 按此匹配；
    //       这里必须显式写 group（空串），Kotlin DSL 没有给 group 默认值，
    //       而 Groovy 的 implementation(name:…, ext:…) 写法在 Kotlin DSL 里根本不编译。
    // English: libqalculate v5.12.0 (GPL-2.0-or-later, GPL-3.0 compatible), prebuilt for
    //          arm64-v8a only. `name` is the file's basename without the extension — that is
    //          what flatDir matches on. `group` must be passed explicitly (empty) because the
    //          Kotlin DSL overload gives it no default; the Groovy spelling
    //          implementation(name:…, ext:…) does not compile in a .kts build script.
    implementation(group = "", name = "libqalculate-5.12.0", ext = "aar")
}
