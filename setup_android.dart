// Adds what Sticky Memo needs to the Android project that `flutter create` makes:
// notification permissions, the alarm receivers, the app name, and Java desugaring.
// Run once:  dart run tool/setup_android.dart
import 'dart:io';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    stderr.writeln('android/ folder not found. First run:\n'
        '  flutter create --platforms=android --org com.stickymemo --project-name sticky_memo .');
    exit(1);
  }

  var m = manifest.readAsStringSync();
  if (!m.contains('POST_NOTIFICATIONS')) {
    m = m.replaceFirst('<application', '''<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32"/>

    <application''');
  }
  // Lets a reminder open the half-screen alert, even over the lock screen.
  if (!m.contains('USE_FULL_SCREEN_INTENT')) {
    m = m.replaceFirst('<application',
        '<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>\n\n    <application');
  }
  if (!m.contains('showWhenLocked')) {
    m = m.replaceFirst('android:name=".MainActivity"',
        'android:name=".MainActivity"\n            android:showWhenLocked="true"\n            android:turnScreenOn="true"');
  }
  m = m.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="Sticky Memo"');
  if (!m.contains('ScheduledNotificationReceiver')) {
    m = m.replaceFirst('</application>', '''    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    </application>''');
  }
  manifest.writeAsStringSync(m);

  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');
  if (kts.existsSync()) {
    var g = kts.readAsStringSync();
    if (!g.contains('isCoreLibraryDesugaringEnabled')) {
      g = g.replaceFirst('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true');
      g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")\n}\n';
      kts.writeAsStringSync(g);
    }
  } else if (groovy.existsSync()) {
    var g = groovy.readAsStringSync();
    if (!g.contains('coreLibraryDesugaringEnabled')) {
      g = g.replaceFirst('compileOptions {', 'compileOptions {\n        coreLibraryDesugaringEnabled true');
      g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'\n}\n";
      groovy.writeAsStringSync(g);
    }
  } else {
    stderr.writeln('Could not find android/app/build.gradle(.kts).');
    exit(1);
  }

  stdout.writeln('Android project is ready for Sticky Memo.');
}
