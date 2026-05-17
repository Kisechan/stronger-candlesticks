import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FileDownloader().start(autoCleanDatabase: true);
  runApp(KlineTrainingApp(repository: LocalBundleRepository()));
}
