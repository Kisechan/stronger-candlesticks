import 'package:app/src/app.dart';
import 'package:app/src/repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots into home page', (tester) async {
    await tester.pumpWidget(
      KlineTrainingApp(
        repository: MemoryBundleRepository(seedDemoOnLoad: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('训练'), findsWidgets);
    expect(find.text('离线 K 线推演'), findsOneWidget);
  });
}
