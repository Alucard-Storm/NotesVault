import 'package:flutter/material.dart';

import '../../controllers/notes_controller.dart';

class StudyDashboardPage extends StatelessWidget {
  const StudyDashboardPage({super.key, required this.controller});

  final NotesController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final notes = controller.activeNotes;
        final staleNotes = notes.where((n) => DateTime.now().difference(n.updatedAt).inDays >= 7).toList();
        final tagCounts = <String, int>{};
        for (final note in notes) {
          for (final tag in note.tags) {
            tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
          }
        }
        final topTags = tagCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Scaffold(
          appBar: AppBar(title: const Text('Study Dashboard')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MetricCard(title: 'Revision reminders', value: '${staleNotes.length} notes need review'),
              const SizedBox(height: 12),
              _MetricCard(title: 'Active notes', value: '${notes.length} this semester'),
              const SizedBox(height: 12),
              _MetricCard(title: 'Top topics', value: topTags.take(3).map((e) => '${e.key} (${e.value})').join(', ').ifEmpty('No tags yet')),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(value),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
