class AiStudyService {
  const AiStudyService();

  String summarize(String content) {
    final sentences = content
        .replaceAll('\n', ' ')
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    return sentences.take(3).join(' ');
  }

  List<String> generateExamQuestions(String content) {
    final keyPhrases = content
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((word) => word.length > 5)
        .take(5)
        .toList();
    if (keyPhrases.isEmpty) {
      return const ['What are the most important concepts in this note?'];
    }
    return keyPhrases
        .map((phrase) => 'Explain $phrase and provide one practical example.')
        .toList();
  }

  List<String> flashcards(String content) {
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(8)
        .toList();
    return lines
        .map((line) => 'Q: What does this mean?\nA: $line')
        .toList();
  }
}
