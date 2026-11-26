import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Read-only rendering of one field value, one widget per server render type in
/// `components/xml/typesreadonly`. Values arrive as the server serialises them:
/// strings, numbers, `{id, name}` maps, language maps and lists of those.
///
/// The render type is [rendertype] when set, otherwise [datatype], as on the server.
class FieldValueView extends StatelessWidget {
  const FieldValueView({
    super.key,
    required this.fieldId,
    required this.value,
    this.datatype = 'text',
    this.rendertype,
    this.lang = 'en',
    this.maxChips = 4,
    this.maxLines = 2,
    this.assetBuilder,
  });

  final String fieldId;
  final Object? value;
  final String datatype;
  final String? rendertype;
  final String lang;

  /// Chips shown before collapsing the rest into "+n".
  final int maxChips;
  final int maxLines;

  /// Renders an asset preview for an asset id (needs the app's signed image headers).
  /// Without it an asset shows as an icon and its id.
  final Widget Function(BuildContext context, String assetId)? assetBuilder;

  static const _chipTypes = {
    'list',
    'multi',
    'multiselect',
    'libraries',
    'teammembers',
    'tageditor',
    'entity',
    'entitysingle',
    'entitychildren',
    'entitycategories',
    'entitycategorieslist',
    'faceprofilegroup',
    'faceprofiles',
    'faceprofilesforasset',
    'radioselect',
    'autocomplete',
    'autocompletefulltext',
    'user',
    'userdefault',
    'category',
  };

  String get _type =>
      (rendertype == null || rendertype!.isEmpty) ? datatype : rendertype!;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null || (v is String && v.isEmpty) || (v is List && v.isEmpty)) {
      return const SizedBox.shrink();
    }
    final t = _type;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    switch (t) {
      case 'password':
        return Text('Not shown', style: TextStyle(color: muted));
      case 'boolean':
        return _text(context, '$v' == 'true' ? 'Yes' : 'No');
      case 'color':
        return _color(context, '$v');
      case 'date':
      case 'datesearch':
        return _text(context, _date(v, false), nowrap: true);
      case 'datetime':
      case 'time':
        return _text(context, _date(v, true), nowrap: true);
      case 'monthday':
      case 'autoincrement':
      case 'sessionestimate':
        return _text(context, '$v');
      case 'filesize':
        return _text(context, formatFieldBytes(v), nowrap: true);
      case 'percentage':
        return _text(context, _percent(v), nowrap: true);
      case 'secondstotime':
        return _text(context, _hours(v));
      case 'timelength':
        return _text(context, _minutesSeconds(v));
      case 'url':
        return _link(context, '$v', Icons.open_in_new);
      case 'documentpage':
        return _asset(context, v);
      case 'file':
      case 'attachment':
        return _link(context, _plain(v), Icons.attach_file);
      case 'asset':
      case 'primarymedia':
        return _asset(context, v);
      case 'number':
        final s = _plain(v);
        return _text(
          context,
          (fieldId == 'width' || fieldId == 'height') ? '${s}px' : s,
          nowrap: true,
        );
      case 'long':
      case 'float':
      case 'double':
      case 'integer':
      case 'currency':
      case 'object':
        return v is List
            ? _chips(context, v)
            : _text(context, _plain(v), nowrap: true);
      case 'json':
      case 'nested':
      case 'objectarray':
        return _structured(context, v);
      case 'map':
        return _map(context, v);
      case 'kwmap':
        return _kwmap(context, v);
      case 'markdown':
        return _text(context, _stripMarkdown(_plain(v)));
      case 'html':
      case 'largehtml':
        return _text(context, _stripHtml(_plain(v)));
      case 'multilanguage':
        return _text(context, _plain(v));
      case 'timecodetable':
        return _chips(
          context,
          v is List ? [for (final e in v) e is Map ? e['cliplabel'] : e] : [v],
        );
      case 'drupalmediausage':
        return _chips(
          context,
          v is List ? [for (final e in v) e is Map ? e['page'] : e] : [v],
        );
      case 'producttable':
        return _text(context, _plain(v));
    }
    if (_chipTypes.contains(t) || v is List) {
      if (t == 'category' ||
          t == 'entitycategories' ||
          t == 'entitycategorieslist') {
        return _chips(
          context,
          v is List ? v : [v],
          icon: Icons.folder_outlined,
        );
      }
      if (t == 'user' || t == 'userdefault' || t == 'teammembers') {
        return _chips(context, v is List ? v : [v], icon: Icons.person_outline);
      }
      if (v is! List &&
          !const {
            'multi',
            'multiselect',
            'libraries',
            'tageditor',
            'entity',
            'entitychildren',
            'faceprofiles',
            'faceprofilesforasset',
            'faceprofilegroup',
          }.contains(t)) {
        return _text(context, _plain(v));
      }
      return _chips(context, v is List ? v : [v]);
    }
    // text, textarea, htmlescaped, highlight, matched and anything unknown.
    return _text(context, _plain(v));
  }

  // ---- helpers -----------------------------------------------------------

  /// A single value as text: `{id,name}`, language maps and scalars.
  String _plain(Object? v) {
    if (v == null) return '';
    if (v is List) return v.map(_plain).where((s) => s.isNotEmpty).join(', ');
    if (v is Map) {
      final isLang =
          v.isNotEmpty &&
          !v.containsKey('id') &&
          v.keys.every((k) => k is String && k.length <= 5) &&
          v.values.every((x) => x is String);
      if (isLang) return '${v[lang] ?? v['en'] ?? v.values.first}';
      final name = v['name'];
      if (name != null) return _plain(name);
      return '${v['id'] ?? ''}';
    }
    return '$v';
  }

  Widget _text(BuildContext context, String s, {bool nowrap = false}) => Text(
    s,
    maxLines: nowrap ? 1 : maxLines,
    softWrap: !nowrap,
    overflow: TextOverflow.ellipsis,
  );

  Widget _chips(BuildContext context, List<Object?> values, {IconData? icon}) {
    final scheme = Theme.of(context).colorScheme;
    final labels = [
      for (final e in values)
        if (_plain(e).isNotEmpty) _plain(e),
    ];
    if (labels.isEmpty) return const SizedBox.shrink();
    Widget chip(String s, {Color? color}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? scheme.secondary).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              s,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final l in labels.take(maxChips)) chip(l),
        if (labels.length > maxChips)
          chip('+${labels.length - maxChips}', color: scheme.onSurfaceVariant),
      ],
    );
  }

  Widget _color(BuildContext context, String s) {
    final c = _parseColor(s);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(child: _text(context, s, nowrap: true)),
      ],
    );
  }

  Widget _link(BuildContext context, String s, IconData icon) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          s,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    ],
  );

  Widget _asset(BuildContext context, Object? v) {
    final id = v is Map ? '${v['id'] ?? ''}' : _plain(v);
    if (id.isEmpty) return const SizedBox.shrink();
    final b = assetBuilder;
    if (b != null) {
      return SizedBox(width: 56, height: 40, child: b(context, id));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.image_outlined, size: 14),
        const SizedBox(width: 4),
        Flexible(
          child: _text(context, v is Map ? _plain(v) : id, nowrap: true),
        ),
      ],
    );
  }

  /// Nested rows, object arrays and raw JSON: a count, or the compact JSON.
  Widget _structured(BuildContext context, Object? v) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (v is List) {
      return Text(
        '${v.length} ${v.length == 1 ? 'row' : 'rows'}',
        style: TextStyle(color: muted),
      );
    }
    if (v is Map) {
      return Text(
        jsonEncode(v),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      );
    }
    return _text(context, '$v');
  }

  Widget _map(BuildContext context, Object? v) {
    if (v is Map) {
      final lat = v['latitude'] ?? v['lat'];
      final lng = v['longitude'] ?? v['lng'] ?? v['lon'];
      if (lat != null && lng != null) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.place_outlined, size: 14),
            const SizedBox(width: 4),
            Flexible(child: _text(context, '$lat, $lng', nowrap: true)),
          ],
        );
      }
    }
    return _text(context, _plain(v), nowrap: true);
  }

  Widget _kwmap(BuildContext context, Object? v) {
    if (v is! Map) return _text(context, _plain(v));
    return _chips(context, [
      for (final e in v.entries)
        if ('${e.value}'.isNotEmpty) '${e.key}: ${e.value}',
    ]);
  }

  String _date(Object? v, bool withTime) {
    final s = '$v';
    final d = DateTime.tryParse(s)?.toLocal();
    if (d == null) return s;
    return withTime
        ? DateFormat.yMMMd().add_jm().format(d)
        : DateFormat.yMMMd().format(d);
  }

  String _percent(Object? v) {
    final n = num.tryParse('$v');
    if (n == null) return '$v';
    // The server stores fractions (0.25) for percentages.
    final p = n <= 1 && n >= -1 ? n * 100 : n;
    return '${NumberFormat('#,##0.##').format(p)}%';
  }

  String _hours(Object? v) {
    final n = num.tryParse('$v');
    if (n == null) return '$v';
    return '${NumberFormat('#,##0.##').format(n / 3600)} hours';
  }

  String _minutesSeconds(Object? v) {
    final n = num.tryParse('$v');
    if (n == null) return '$v';
    final total = n.round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int x) => x.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }

  static String _stripHtml(String s) => s
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _stripMarkdown(String s) => s
      .replaceAll(RegExp(r'[#*_`>]+'), '')
      .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1] ?? '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static Color? _parseColor(String s) {
    var h = s.trim();
    if (!h.startsWith('#')) return null;
    h = h.substring(1);
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
    if (h.length == 6) h = 'ff$h';
    final n = int.tryParse(h, radix: 16);
    return n == null || h.length != 8 ? null : Color(n);
  }
}

/// 1536 -> "1.5 KB".
String formatFieldBytes(Object? v) {
  final n = num.tryParse('${v ?? ''}');
  if (n == null) return '';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = n.toDouble();
  var i = 0;
  while (size >= 1024 && i < units.length - 1) {
    size /= 1024;
    i++;
  }
  return i == 0
      ? '${size.round()} B'
      : '${size.toStringAsFixed(1)} ${units[i]}';
}
