import 'package:flutter_test/flutter_test.dart';
import 'package:notevault/models/checklist_item.dart';

void main() {
  group('ChecklistItem', () {
    test('creates with expected values', () {
      const item = ChecklistItem(
        id: 'item-1',
        text: 'Buy milk',
        isChecked: true,
        order: 2,
      );

      expect(item.id, 'item-1');
      expect(item.text, 'Buy milk');
      expect(item.isChecked, isTrue);
      expect(item.order, 2);
    });

    test('copyWith updates selected fields only', () {
      const item = ChecklistItem(
        id: 'item-1',
        text: 'Buy milk',
        isChecked: false,
        order: 0,
      );

      final updated = item.copyWith(text: 'Buy oat milk', isChecked: true);

      expect(updated.id, item.id);
      expect(updated.text, 'Buy oat milk');
      expect(updated.isChecked, isTrue);
      expect(updated.order, item.order);
    });

    test('serializes to and from json', () {
      const item = ChecklistItem(
        id: 'item-1',
        text: 'Buy milk',
        isChecked: true,
        order: 1,
      );

      final restored = ChecklistItem.fromJson(item.toJson());

      expect(restored.id, item.id);
      expect(restored.text, item.text);
      expect(restored.isChecked, item.isChecked);
      expect(restored.order, item.order);
    });
  });
}