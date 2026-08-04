import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('AcademyPro')),
        ),
      ),
    );
    expect(find.text('AcademyPro'), findsOneWidget);
  });
}
