import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Simple text editor for rich text notes
/// Uses flutter_quill for formatting support
class RichTextEditor extends StatefulWidget {
  const RichTextEditor({
    super.key,
    required this.initialContent,
    required this.onChanged,
  });

  final String initialContent; // Plain text or formatted content
  final ValueChanged<String> onChanged;

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late QuillController _controller;

  @override
  void initState() {
    super.initState();

    final doc = _documentFromContent(widget.initialContent);

    _controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    _controller.document.changes.listen((_) {
      widget.onChanged(jsonEncode(_controller.document.toDelta().toJson()));
    });
  }

  Document _documentFromContent(String content) {
    if (content.trim().isEmpty) {
      return Document();
    }

    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return Document.fromJson(decoded.cast<Map<String, dynamic>>());
      }
    } catch (_) {
      // Fall back to plain text for legacy notes.
    }

    return Document()..insert(0, content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Simple toolbar with basic formatting
        Container(
          color: Colors.grey.shade100,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ToolbarButton(
                  icon: Icons.format_bold,
                  onTap: () {
                    _controller.formatSelection(Attribute.bold);
                  },
                ),
                _ToolbarButton(
                  icon: Icons.format_italic,
                  onTap: () {
                    _controller.formatSelection(Attribute.italic);
                  },
                ),
                _ToolbarButton(
                  icon: Icons.format_underlined,
                  onTap: () {
                    _controller.formatSelection(Attribute.underline);
                  },
                ),
                const VerticalDivider(),
                _ToolbarButton(
                  icon: Icons.format_list_bulleted,
                  onTap: () {
                    _controller.formatSelection(Attribute.ul);
                  },
                ),
                _ToolbarButton(
                  icon: Icons.format_list_numbered,
                  onTap: () {
                    _controller.formatSelection(Attribute.ol);
                  },
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // Editor
        Expanded(
          child: QuillEditor.basic(
          controller: _controller,
          ),
        ),
      ],
    );
  }
}

/// Simple toolbar button
class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Icon(icon, size: 20),
      ),
    );
  }
}

/// Widget for displaying rich text notes (read-only)
class RichTextViewer extends StatefulWidget {
  const RichTextViewer({
    super.key,
    required this.content,
  });

  final String content;

  @override
  State<RichTextViewer> createState() => _RichTextViewerState();
}

class _RichTextViewerState extends State<RichTextViewer> {
  late QuillController _controller;

  @override
  void initState() {
    super.initState();

    final doc = _documentFromContent(widget.content);

    _controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  Document _documentFromContent(String content) {
    if (content.trim().isEmpty) {
      return Document();
    }

    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return Document.fromJson(decoded.cast<Map<String, dynamic>>());
      }
    } catch (_) {
      // Fall back to plain text for legacy notes.
    }

    return Document()..insert(0, content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
     return AbsorbPointer(
      child: IgnorePointer(
        child: QuillEditor.basic(
          controller: _controller,
        ),
      ),
     );
  }
}
