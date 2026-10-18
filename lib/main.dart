import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/services/storage_service.dart';
import 'features/alarm/services/alarm_service.dart';
import 'features/history/data/local_database.dart';
import 'features/tracking/services/tracking_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter uncaught error: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Platform uncaught error: $error\n$stack');
    return true;
  };

  try {
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
  } catch (_) {}

  try {
    await Hive.initFlutter();
    await StorageService().init();
    await TripHistoryRepository.openBox();
    await SavedDestinationsRepository.openBox();
  } catch (e) {
    debugPrint('Storage initialization warning: $e');
  }

  try {
    TrackingService.init();
    FlutterForegroundTask.initCommunicationPort();
  } catch (e) {
    debugPrint('Foreground service initialization warning: $e');
  }

  try {
    await AlarmService.init();
  } catch (e) {
    debugPrint('AlarmService initialization warning: $e');
  }

  runApp(const ProviderScope(child: WakeUpBuddyApp()));
}
