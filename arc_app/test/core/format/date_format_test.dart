import 'package:arc_app/core/format/date_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 9, 18); // a Friday

  test('shortDate formats as dd/mm/yyyy', () {
    expect(shortDate(date), '18/09/2026');
    expect(shortDate(DateTime(2026, 1, 5)), '05/01/2026');
  });

  test('monthAbbr returns the Spanish three-letter month', () {
    expect(monthAbbr(date), 'sep');
    expect(monthAbbr(DateTime(2026, 1, 1)), 'ene');
  });

  test('weekdayName returns the Spanish weekday', () {
    expect(weekdayName(date), 'viernes');
    expect(weekdayName(DateTime(2026, 9, 20)), 'domingo');
  });
}
