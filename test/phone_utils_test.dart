import 'package:famplan/core/utils/phone_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePhone', () {
    test('accepts local 0 format', () {
      expect(normalizePhone('08012345678'), '+2348012345678');
      expect(normalizePhone('080 1234 5678'), '+2348012345678');
    });

    test('accepts +234 format', () {
      expect(normalizePhone('+2348012345678'), '+2348012345678');
      expect(normalizePhone('+234 801 234 5678'), '+2348012345678');
    });

    test('accepts 234 without plus', () {
      expect(normalizePhone('2348012345678'), '+2348012345678');
    });

    test('rejects invalid numbers', () {
      expect(normalizePhone('8012345678'), isNull);
      expect(normalizePhone('+448012345678'), isNull);
      expect(normalizePhone('080123'), isNull);
    });
  });

  group('phoneToAuthEmail', () {
    test('maps normalized phone to auth email', () {
      expect(
        phoneToAuthEmail('+2348012345678'),
        '2348012345678@famplan.auth',
      );
    });
  });
}