import '../models/note.dart';

class SemanticSearchService {
  const SemanticSearchService();

  List<SemanticMatch> rankNotes({
    required String query,
    required List<Note> notes,
    required String Function(Note note) plainText,
  }) {
    final normalizedQuery = _tokens(query);
    if (normalizedQuery.isEmpty) {
      return notes
          .map((note) => SemanticMatch(note: note, score: 0, matchedTerms: const []))
          .toList();
    }

    final matches = <SemanticMatch>[];
    for (final note in notes) {
      final contentTokens = {
        ..._tokens(note.title),
        ..._tokens(plainText(note)),
        ...note.tags.expand(_tokens),
      };
      final overlap = normalizedQuery.where(contentTokens.contains).toList();
      if (overlap.isEmpty) {
        continue;
      }
      final score = overlap.length / normalizedQuery.length;
      matches.add(SemanticMatch(note: note, score: score, matchedTerms: overlap));
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches;
  }

  Set<String> _tokens(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length > 2)
        .toSet();
  }
}

class SemanticMatch {
  const SemanticMatch({
    required this.note,
    required this.score,
    required this.matchedTerms,
  });

  final Note note;
  final double score;
  final List<String> matchedTerms;
}
