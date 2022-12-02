// @dart=2.9
import 'dart:io';

import "package:ente_auth/app/view/app.dart";
import 'package:ente_auth/core/configuration.dart';
import 'package:ente_auth/core/constants.dart';
import 'package:ente_auth/core/logging/super_logging.dart';
import 'package:ente_auth/core/network.dart';
import 'package:ente_auth/ente_theme_data.dart';
import 'package:ente_auth/services/authenticator_service.dart';
import 'package:ente_auth/services/billing_service.dart';
import 'package:ente_auth/services/notification_service.dart';
import 'package:ente_auth/services/preference_service.dart';
import 'package:ente_auth/services/update_service.dart';
import 'package:ente_auth/services/user_remote_flag_service.dart';
import 'package:ente_auth/services/user_service.dart';
import 'package:ente_auth/store/code_store.dart';
import 'package:ente_auth/ui/tools/app_lock.dart';
import 'package:ente_auth/ui/tools/lock_screen.dart';
import 'package:ente_auth/utils/crypto_util.dart';
import "package:flutter/material.dart";
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_size/window_size.dart';

final _logger = Logger("main");

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle("ente Auth");
    setWindowMinSize(const Size(375, 750));
    setWindowMaxSize(const Size(375, 750));
  }
  await _runInForeground();
}

Future<void> _runInForeground() async {
  return await _runWithLogs(() async {
    _logger.info("Starting app in foreground");
    await _init(false, via: 'mainMethod');
    UpdateService.instance.showUpdateNotification();
    runApp(
      AppLock(
        builder: (args) => const App(),
        lockScreen: const LockScreen(),
        enabled: Configuration.instance.shouldShowLockScreen(),
        lightTheme: lightThemeData,
        darkTheme: darkThemeData,
      ),
    );
  });
}

Future _runWithLogs(Function() function, {String prefix = ""}) async {
  await SuperLogging.main(
    LogConfig(
      body: function,
      logDirPath: (await getApplicationSupportDirectory()).path + "/logs",
      maxLogFiles: 5,
      sentryDsn: sentryDSN,
      enableInDebugMode: true,
      prefix: prefix,
    ),
  );
}

Future<void> _init(bool bool, {String via}) async {
  await CryptoUtil.init();
  await PreferenceService.instance.init();
  await CodeStore.instance.init();
  await Configuration.instance.init();
  await Network.instance.init();
  await UserService.instance.init();
  await UserRemoteFlagService.instance.init();
  await AuthenticatorService.instance.init();
  await BillingService.instance.init();
  await NotificationService.instance.init();
  await UpdateService.instance.init();
}
