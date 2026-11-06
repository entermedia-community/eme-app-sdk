// Tutorials hosted by an EME Server: `entitytopic` → `entitytutorial`, taken
// inside a tutor chat channel.

class TutorialTopic {
  final String id;
  final String title;
  final String description;
  final int tutorialCount;

  const TutorialTopic({
    required this.id,
    required this.title,
    this.description = '',
    this.tutorialCount = 0,
  });

  factory TutorialTopic.fromJson(Map<String, dynamic> json) {
    return TutorialTopic(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      tutorialCount: (json['tutorials'] as num?)?.toInt() ?? 0,
    );
  }
}

class TutorialSummary {
  final String id;
  final String title;
  final String topicId;
  final int totalSections;
  final int completedSections;

  const TutorialSummary({
    required this.id,
    required this.title,
    this.topicId = '',
    this.totalSections = 0,
    this.completedSections = 0,
  });

  factory TutorialSummary.fromJson(Map<String, dynamic> json) {
    return TutorialSummary(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      topicId: (json['entitytopicid'] ?? '').toString(),
      totalSections: (json['totalsections'] as num?)?.toInt() ?? 0,
      completedSections: (json['completedsections'] as num?)?.toInt() ?? 0,
    );
  }
}

/// How sure the learner was; the wire value is the `answerconfidence` id.
enum TutorialConfidence {
  noidea,
  notsure,
  mostlysure,
  confident;

  static TutorialConfidence? tryParse(String? value) =>
      values.asNameMap()[value];
}

/// One multiple choice question. [options] is keyed by the wire key
/// (`option_a`…); empty options are dropped.
class TutorialQuestion {
  final String id;
  final String question;
  final Map<String, String> options;

  /// The wire value is a letter (`A`) or a key (`option_a`); see
  /// [isCorrectOption].
  final String correctOption;
  final String rationale;
  final String cognitiveLevel;

  const TutorialQuestion({
    required this.id,
    required this.question,
    required this.options,
    this.correctOption = '',
    this.rationale = '',
    this.cognitiveLevel = '',
  });

  factory TutorialQuestion.fromJson(Map<String, dynamic> json) {
    final options = <String, String>{};
    final rawOptions = json['options'];
    if (rawOptions is Map) {
      final keys = rawOptions.keys.map((k) => k.toString()).toList()..sort();
      for (final key in keys) {
        final text = rawOptions[key]?.toString().trim() ?? '';
        if (text.isNotEmpty) options[key] = text;
      }
    }
    return TutorialQuestion(
      id: (json['id'] ?? '').toString(),
      question: (json['question'] ?? '').toString(),
      options: options,
      correctOption: (json['correctoption'] ?? '').toString(),
      rationale: (json['rationale'] ?? '').toString(),
      cognitiveLevel:
          (json['mcqcognitivelevel'] ?? json['cognitivelevel'] ?? '')
              .toString(),
    );
  }

  /// `option_c` → `C`.
  static String letterOf(String key) => key.split('_').last.toUpperCase();

  bool isCorrectOption(String key) {
    final correct = correctOption.trim();
    if (correct.isEmpty) return false;
    return correct.toLowerCase() == key.toLowerCase() ||
        letterOf(correct) == letterOf(key);
  }
}

/// A tutor channel as `tutorsession.json` returns it.
class TutorialChannel {
  final String id;
  final String channelType;

  const TutorialChannel({required this.id, this.channelType = ''});

  factory TutorialChannel.fromJson(Map<String, dynamic> json) =>
      TutorialChannel(
        id: (json['id'] ?? '').toString(),
        channelType: (json['channeltype'] ?? '').toString(),
      );
}
