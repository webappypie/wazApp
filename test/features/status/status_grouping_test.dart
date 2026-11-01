import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/features/library/domain/library_models.dart';
import 'package:wazapp/features/status/domain/status_grouping.dart';
import 'package:wazapp/features/status/domain/status_models.dart';

StatusItem _item(String name, DateTime t, {MediaKind kind = MediaKind.image}) => StatusItem(
  app: StatusApp.whatsapp,
  uri: 'content://x/$name',
  name: name,
  kind: kind,
  mimeType: 'image/jpeg',
  sizeBytes: 10,
  modified: t,
);

void main() {
  final now = DateTime(2026, 10, 25, 12);

  test('groups by day, newest day and newest item first, with Today/Yesterday labels', () {
    final groups = groupStatusesByDay([
      _item('old', DateTime(2026, 10, 20, 9)),
      _item('a', DateTime(2026, 10, 25, 8)),
      _item('b', DateTime(2026, 10, 25, 11)),
      _item('y', DateTime(2026, 10, 24, 23)),
    ], now);
    expect(groups.map((g) => g.label), ['Today', 'Yesterday', '20 Oct']);
    expect(groups.first.items.map((i) => i.name), ['b', 'a']);
  });

  test('a different year includes the year; kind filter keeps only that kind', () {
    final groups = groupStatusesByDay([
      _item('p', DateTime(2025, 12, 31, 8)),
      _item('v', DateTime(2025, 12, 31, 9), kind: MediaKind.video),
    ], now, kind: MediaKind.video);
    expect(groups, hasLength(1));
    expect(groups.single.label, '31 Dec 2025');
    expect(groups.single.items.single.name, 'v');
  });

  test('empty input gives no groups', () {
    expect(groupStatusesByDay(const [], now), isEmpty);
  });
}
