import 'package:flutter_test/flutter_test.dart';

import 'package:notevault/main.dart';

void main() {
  testWidgets('App renders NoteVault shell', (WidgetTester tester) async {
    await tester.pumpWidget(const NoteVaultApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Vault'), findsAtLeastNWidgets(1));
    expect(find.text('Notes'), findsAtLeastNWidgets(1));
  });
}
