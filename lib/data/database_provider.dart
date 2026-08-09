import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

Future<AppDatabase> openAppDatabase() async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File(path.join(directory.path, 'focus_flow.sqlite'));
  return AppDatabase(NativeDatabase.createInBackground(file));
}
