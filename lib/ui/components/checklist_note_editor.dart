import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/checklist_item.dart';

/// Widget for editing checklist items
class ChecklistNoteEditor extends StatefulWidget {
  const ChecklistNoteEditor({
    super.key,
    required this.items,
    required this.onChanged,
  });

  final List<ChecklistItem> items;
  final ValueChanged<List<ChecklistItem>> onChanged;

  @override
  State<ChecklistNoteEditor> createState() => _ChecklistNoteEditorState();
}

class _ChecklistNoteEditorState extends State<ChecklistNoteEditor> {
  late List<ChecklistItem> _items;
  late Map<String, TextEditingController> _controllers;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _items = [...widget.items];
    _controllers = {};
    for (final item in _items) {
      _controllers[item.id] = TextEditingController(text: item.text);
    }
  }

  void _toggleItem(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(isChecked: !_items[index].isChecked);
      widget.onChanged(_items);
      setState(() {});
    }
  }

  void _deleteItem(String id) {
    _items.removeWhere((item) => item.id == id);
    _controllers[id]?.dispose();
    _controllers.remove(id);
    widget.onChanged(_items);
    setState(() {});
  }

  void _addItem() {
    final newItem = ChecklistItem(
      id: _uuid.v4(),
      text: '',
      isChecked: false,
      order: _items.length,
    );
    _items.add(newItem);
    _controllers[newItem.id] = TextEditingController();
    widget.onChanged(_items);
    setState(() {});
  }

  void _updateItem(String id, String newText) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(text: newText);
      widget.onChanged(_items);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.checklist_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No items yet',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final controller = _controllers[item.id]!;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Checkbox(
                            value: item.isChecked,
                            onChanged: (_) => _toggleItem(item.id),
                          ),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                hintText: 'Item ${index + 1}',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                              ),
                              style: TextStyle(
                                decoration: item.isChecked
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                              onChanged: (value) => _updateItem(item.id, value),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _deleteItem(item.id),
                            tooltip: 'Delete item',
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget for displaying checklist items (read-only)
class ChecklistNoteViewer extends StatelessWidget {
  const ChecklistNoteViewer({
    super.key,
    required this.items,
  });

  final List<ChecklistItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No items',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: item.isChecked,
                onChanged: null, // Read-only
              ),
              Expanded(
                child: Text(
                  item.text,
                  style: TextStyle(
                    decoration: item.isChecked
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
