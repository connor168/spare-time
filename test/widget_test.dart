import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focus_flow/main.dart';

void main() {
  testWidgets('FocusFlow boots to the today view', (WidgetTester tester) async {
    await tester.pumpWidget(const FocusFlowApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
