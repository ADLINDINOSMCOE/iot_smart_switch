import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/models/switch_model.dart';
import 'package:iot_smart_switch/theme/app_theme.dart';
import 'package:iot_smart_switch/widgets/switch_tile.dart';

void main() {
  Widget createTestableWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }

  group('SwitchTile Widget Tests', () {
    testWidgets('Displays switch name, room, deviceId and state correctly',
        (WidgetTester tester) async {
      const testSwitch = SwitchModel(
        id: 'switch_1',
        name: 'Balcony Light',
        room: 'Balcony',
        isOn: false,
        deviceId: 'esp32_001',
      );

      await tester.pumpWidget(
        createTestableWidget(
          const SwitchTile(switchModel: testSwitch),
        ),
      );

      expect(find.text('Balcony Light'), findsOneWidget);
      expect(find.text('(switch_1)'), findsOneWidget);
      expect(find.text('Balcony'), findsOneWidget);
      expect(find.text('esp32_001'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);
    });

    testWidgets('Triggers onToggle callback when switch toggled',
        (WidgetTester tester) async {
      bool toggledValue = false;
      const testSwitch = SwitchModel(
        id: 'switch_1',
        name: 'Balcony Light',
        room: 'Balcony',
        isOn: false,
        deviceId: 'esp32_001',
      );

      await tester.pumpWidget(
        createTestableWidget(
          SwitchTile(
            switchModel: testSwitch,
            onToggle: (val) => toggledValue = val,
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(toggledValue, isTrue);
    });
  });
}
