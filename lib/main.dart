import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/database/database.dart';
import 'core/database/database_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the database
  final database = AppDatabase();
  DatabaseProvider.initialize(database);

  runApp(const CommonPlaceBookApp());
}
