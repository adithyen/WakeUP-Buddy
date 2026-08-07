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

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  await Hive.initFlutter();
  await StorageService().init();

  // Open history / saved-destinations boxes
  await TripHistoryRepository.openBox();
  await SavedDestinationsRepository.openBox();

  TrackingService.init();
  FlutterForegroundTask.initCommunicationPort();

  // Initialize alarm package — registers broadcast receiver and ring stream.
  await AlarmService.init();

  runApp(const ProviderScope(child: WakeUpBuddyApp()));
}
