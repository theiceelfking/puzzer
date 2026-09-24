import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:puzzer/main.dart';

void main() {
  testWidgets('Home screen shows title and action buttons', (WidgetTester tester) async {
    await tester.pumpWidget(const PuzzerApp());

    expect(find.text('Puzzer'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Tạo phòng mới'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Tham gia phòng có sẵn'), findsOneWidget);
  });
}
