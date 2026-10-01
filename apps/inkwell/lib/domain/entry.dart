import 'package:paper/paper.dart';

/// How the day felt. Five levels, because three is not enough to see a trend
/// and seven is more precision than anyone can report honestly.
enum Mood {
  awful(-2),
  low(-1),
  neutral(0),
  good(1),
  great(2);

  const Mood(this.score);

  /// Used for averages and for the trend chart's y-value.
  final int score;

  static Mood? byName(String? name) {
    if (name == null) return null;
    for (final mood in Mood.values) {
      if (mood.name == name) return mood;
    }
    return null;
  }
}

/// One journal entry.
///
/// The body is plain text. There is no rich-text model on purpose: a
/// proprietary document format is the thing most likely to make these entries
/// unreadable in ten years, and plain text exports, greps and diffs.
class Entry {
  const Entry({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.title,
    required this.body,
    this.mood,
    this.tags = const <String>[],
  });

  factory Entry.fromJson(Map<String, Object?> json) {
    final created = DateTime.parse(json['createdAt']! as String).toLocal();
    final rawTags = json['tags'];
    return Entry(
      id: json['id']! as String,
      createdAt: created,
      updatedAt: json['updatedAt'] is String
          ? DateTime.parse(json['updatedAt']! as String).toLocal()
          : created,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      mood: Mood.byName(json['mood'] as String?),
      tags: rawTags is List
          ? <String>[
              for (final tag in rawTags)
                if (tag is String && tag.trim().isNotEmpty) tag.trim(),
            ]
          : const <String>[],
    );
  }

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String title;
  final String body;
  final Mood? mood;
  final List<String> tags;

  Day get day => Day.fromDateTime(createdAt);

  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;

  /// First line of the body, for the list row.
  String get preview {
    final text = body.trim();
    if (text.isEmpty) return '';
    final firstBreak = text.indexOf('\n');
    final line = firstBreak == -1 ? text : text.substring(0, firstBreak);
    return line.length <= 140 ? line : '${line.substring(0, 139)}…';
  }

  /// A heading for the row when the user left the title blank.
  String titleOr(String fallback) =>
      title.trim().isEmpty ? fallback : title.trim();

  int get wordCount {
    final words = body.trim().split(RegExp(r'\s+'));
    return words.length == 1 && words.first.isEmpty ? 0 : words.length;
  }

  /// True when [query] appears in the title, body or tags.
  ///
  /// Case-insensitive and substring-based rather than token-based, because
  /// Korean does not separate words with spaces and a tokeniser tuned for
  /// English would simply fail to match.
  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    if (title.toLowerCase().contains(needle)) return true;
    if (body.toLowerCase().contains(needle)) return true;
    return tags.any((tag) => tag.toLowerCase().contains(needle));
  }

  Entry copyWith({
    String? title,
    String? body,
    Mood? mood,
    bool clearMood = false,
    List<String>? tags,
    required DateTime updatedAt,
  }) => Entry(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    title: title ?? this.title,
    body: body ?? this.body,
    mood: clearMood ? null : (mood ?? this.mood),
    tags: tags ?? this.tags,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'title': title,
    'body': body,
    if (mood != null) 'mood': mood!.name,
    if (tags.isNotEmpty) 'tags': tags,
  };

  @override
  bool operator ==(Object other) => other is Entry && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Entry($id, ${day.toString()}, "${titleOr('untitled')}")';
}
