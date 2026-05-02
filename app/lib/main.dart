import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(KlineTrainingApp(repository: LocalBundleRepository()));
}
