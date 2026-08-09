import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_flow/main.dart';

void main() {
  for (final width in [599.0, 600.0, 840.0, 841.0]) {
    testWidgets('renders without overflow at ${width.toInt()}dp',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const FocusFlowApp());

      expect(tester.takeException(), isNull);
      if (width < 600) {
        expect(find.byType(NavigationBar), findsOneWidget);
      } else {
        expect(find.byType(NavigationRail), findsOneWidget);
      }
    });
  }

  testWidgets('compact windows use bottom navigation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const FocusFlowApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('tablet windows use navigation rail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const FocusFlowApp());

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('a task can be marked complete', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const FocusFlowApp());
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox).first);
    expect(checkbox.value, isTrue);
  });

  testWidgets('knowledge base search filters notes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const FocusFlowApp());
    await tester.tap(find.text('知识库'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Agent');
    await tester.pump();

    expect(find.text('阅读记录：Agent 工作流'), findsOneWidget);
    expect(find.text('把复杂问题拆成可验证的假设'), findsNothing);
  });

  testWidgets('a knowledge note can be created', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const FocusFlowApp());
    await tester.tap(find.text('知识库'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新建笔记'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('note-title-field')), '新的心得');
    await tester.enterText(
        find.byKey(const Key('note-body-field')), '这是今天记录的内容。');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('新的心得'), findsOneWidget);
  });
}
