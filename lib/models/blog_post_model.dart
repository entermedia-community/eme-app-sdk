class BlogPostModel {
  final String id;
  final String title;
  final String author;
  final String date;
  final String readTime;
  final String excerpt;
  final String tag;
  final int likes;
  final String? content;

  const BlogPostModel({
    required this.id,
    required this.title,
    required this.author,
    required this.date,
    required this.readTime,
    required this.excerpt,
    required this.tag,
    required this.likes,
    this.content,
  });

  factory BlogPostModel.fromJson(Map<String, dynamic> json) {
    return BlogPostModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      date: json['date'] as String? ?? '',
      readTime: json['readTime'] as String? ?? '',
      excerpt: json['excerpt'] as String? ?? '',
      tag: json['tag'] as String? ?? 'General',
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      content: json['content'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'date': date,
      'readTime': readTime,
      'excerpt': excerpt,
      'tag': tag,
      'likes': likes,
      if (content != null) 'content': content,
    };
  }

  BlogPostModel copyWith({
    String? id,
    String? title,
    String? author,
    String? date,
    String? readTime,
    String? excerpt,
    String? tag,
    int? likes,
    String? content,
  }) {
    return BlogPostModel(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      date: date ?? this.date,
      readTime: readTime ?? this.readTime,
      excerpt: excerpt ?? this.excerpt,
      tag: tag ?? this.tag,
      likes: likes ?? this.likes,
      content: content ?? this.content,
    );
  }
}
