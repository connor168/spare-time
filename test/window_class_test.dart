import 'package:flutter_test/flutter_test.dart';
import 'package:focus_flow/ui/window_class.dart';

void main() {
  group('windowClassFor', () {
    test('uses compact layout below 600dp', () {
      expect(windowClassFor(320), WindowClass.compact);
      expect(windowClassFor(599.9), WindowClass.compact);
      expect(windowClassFor(599.9).usesBottomNavigation, isTrue);
    });

    test('uses medium layout from 600dp through 840dp', () {
      expect(windowClassFor(600), WindowClass.medium);
      expect(windowClassFor(840), WindowClass.medium);
      expect(windowClassFor(840).supportsMultiplePanes, isTrue);
    });

    test('uses expanded layout above 840dp', () {
      expect(windowClassFor(840.1), WindowClass.expanded);
      expect(windowClassFor(1280).supportsThreePanes, isTrue);
    });
  });
}
