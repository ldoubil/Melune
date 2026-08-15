import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:melune/app.dart';
import 'package:melune/src/rust/api/simple.dart';
import 'package:melune/src/rust/frb_generated.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  testWidgets('Can call rust function', (tester) async {
    await tester.pumpWidget(
      MeluneApp(appName: appName(), greet: greet),
    );
    await tester.pumpAndSettle();
    expect(find.text('Melune · 洛音'), findsWidgets);
    expect(find.text('新专'), findsOneWidget);
  });
}
