import 'package:flutter_test/flutter_test.dart';
import 'package:how_to_cook/main.dart';

void main() {
  testWidgets('App starts and shows title', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await tester.pumpWidget(const HowToCookApp());
    await tester.pump(); // first frame
    expect(find.text('程序员做饭指南'), findsOneWidget);
  });
}
