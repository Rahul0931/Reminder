import 'package:flutter_test/flutter_test.dart';
import 'package:sticky_memo/quick_parse.dart';

void main() {
  test('reads a time from a quick note', () {
    final p = parseQuick('call mom tomorrow 6pm');
    expect(p.title, 'Call mom');
    expect(p.when, isNotNull);
    expect(p.when!.hour, 18);
  });

  test('keeps plain notes as notes', () {
    final p = parseQuick('buy a new notebook');
    expect(p.title, 'Buy a new notebook');
    expect(p.when, isNull);
  });

  test('understands "in 2 hours"', () {
    final p = parseQuick('drink water in 2 hours');
    expect(p.title, 'Drink water');
    final diff = p.when!.difference(DateTime.now()).inMinutes;
    expect(diff, inInclusiveRange(118, 121));
  });
}
