import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../utils/timezone_utils.dart';

class AITableWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final String title;

  const AITableWidget({
    super.key,
    required this.data,
    this.title = 'Data Table',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Convert data to table format
    List<Map<String, dynamic>> tableData = [];

    if (data['rows'] != null && data['columns'] != null) {
      // Structured table data
      final columns = List<String>.from(data['columns']);
      final rows = List<List<dynamic>>.from(data['rows']);

      for (var row in rows) {
        final rowData = <String, dynamic>{};
        for (int i = 0; i < columns.length && i < row.length; i++) {
          rowData[columns[i]] = row[i];
        }
        tableData.add(rowData);
      }
    } else {
      // Simple key-value pairs
      data.forEach((key, value) {
        tableData.add({'Key': key.toString(), 'Value': value.toString()});
      });
    }

    if (tableData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2E2E2E) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('No data available'),
      );
    }

    final columns = tableData.first.keys.toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2E2E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.white12 : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              horizontalMargin: 12,
              headingRowHeight: 38,
              dataRowMinHeight: 34,
              dataRowMaxHeight: 56,
              headingRowColor: WidgetStateProperty.all(
                isDarkMode ? const Color(0xFF3E3E3E) : Colors.grey[200],
              ),
              dataRowColor: WidgetStateProperty.all(
                isDarkMode ? const Color(0xFF2E2E2E) : Colors.white,
              ),
              columns: columns
                  .map((column) => DataColumn(
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                          column,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          ),
                        ),
                      ))
                  .toList(),
              rows: tableData
                  .map((row) => DataRow(
                        cells: columns
                            .map((column) => DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 180),
                                    child: Text(
                                    row[column]?.toString() ?? '',
                                    softWrap: true,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final Color color;
  final bool isDarkMode;

  LineChartPainter({
    required this.data,
    required this.labels,
    required this.color,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Calculate points
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    final stepX = size.width / (data.length - 1);
    final stepY = range > 0 ? (size.height - 40) / range : 0;

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - 20 - ((data[i] - minValue) * stepY);
      points.add(Offset(x, y));
    }

    // Draw line
    if (points.length > 1) {
      final path = Path();
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    // Draw dots
    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }

    // Draw labels
    final textStyle = TextStyle(
      fontSize: 10,
      color: isDarkMode ? Colors.white70 : Colors.grey[600],
    );

    for (int i = 0; i < labels.length && i < points.length; i++) {
      final textPainter = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final x = points[i].dx - textPainter.width / 2;
      final y = size.height - 5;

      textPainter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AIChartWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final String chartType;
  final String title;

  const AIChartWidget({
    super.key,
    required this.data,
    this.chartType = 'bar',
    this.title = 'Chart',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    Widget chart;

    switch (chartType.toLowerCase()) {
      case 'pie':
        chart = _buildPieChart(isDarkMode);
        break;
      case 'line':
        chart = _buildLineChart(isDarkMode);
        break;
      default:
        chart = _buildBarChart(isDarkMode);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2E2E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.white12 : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: chart,
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(bool isDarkMode) {
    // Extract data for bar chart
    final chartData = _extractChartData();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Simple bar chart representation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(
              chartData['values'].length,
              (index) {
                final value = chartData['values'][index].toDouble();
                final maxValue = chartData['maxY'].toDouble();
                final height = (value / maxValue) * 120;

                return Column(
                  children: [
                    SelectableText(
                      value.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 30,
                      height: height,
                      decoration: BoxDecoration(
                        color: Colors.deepPurpleAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 40,
                      child: SelectableText(
                        chartData['labels'][index],
                        style: TextStyle(
                          fontSize: 10,
                          color: isDarkMode ? Colors.white70 : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(bool isDarkMode) {
    final chartData = _extractChartData();
    final colors = [
      Colors.deepPurpleAccent,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.pink,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Simple pie chart representation with legend
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              chartData['labels'].length,
              (index) {
                final color = colors[index % colors.length];
                final label = chartData['labels'][index];
                final value = chartData['values'][index];

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SelectableText(
                      '$label: $value',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(bool isDarkMode) {
    final chartData = _extractChartData();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Simple line chart representation
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: LineChartPainter(
                data: chartData['values'].map((v) => v.toDouble()).toList(),
                labels: chartData['labels'],
                color: Colors.deepPurpleAccent,
                isDarkMode: isDarkMode,
              ),
              size: const Size(double.infinity, 120),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _extractChartData() {
    // Try to extract data from various formats
    List<String> labels = [];
    List<num> values = [];
    double maxY = 100;

    if (data['labels'] != null && data['values'] != null) {
      labels = List<String>.from(data['labels']);
      values = List<num>.from(data['values']);
    } else if (data['data'] != null) {
      final dataList = List<Map<String, dynamic>>.from(data['data']);
      labels = dataList.map((item) => item['label']?.toString() ?? '').toList();
      values = dataList.map((item) => (item['value'] as num? ?? 0)).toList();
    } else {
      // Convert key-value pairs to chart data
      data.forEach((key, value) {
        labels.add(key.toString());
        if (value is num) {
          values.add(value);
        } else {
          values.add(0);
        }
      });
    }

    if (values.isNotEmpty) {
      maxY = values.reduce((a, b) => a > b ? a : b).toDouble() * 1.1;
    }

    return {
      'labels': labels,
      'values': values,
      'maxY': maxY,
    };
  }
}

class AIMessageStructuredWidget extends StatelessWidget {
  const AIMessageStructuredWidget({
    super.key,
    required this.text,
    this.sections,
    this.blocks,
    this.structuredData,
    this.responseType,
    this.safety,
  });

  final String text;
  final List<Map<String, dynamic>>? sections;
  final List<Map<String, dynamic>>? blocks;
  final Map<String, dynamic>? structuredData;
  final String? responseType;
  final Map<String, dynamic>? safety;

  @override
  Widget build(BuildContext context) {
    final responseBlocks = blocks ?? const <Map<String, dynamic>>[];
    if (responseBlocks.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: responseBlocks
            .map((block) => _buildResponseBlock(context, block))
            .toList(growable: false),
      );
    }
    final normalizedSections = _normalizedSections();
    final hasSafetySection = normalizedSections.any(
      (section) => (section['key']?.toString().toLowerCase() ?? '') == 'safety',
    );
    final shouldRenderFallbackStructured = structuredData != null &&
        normalizedSections.every(
          (section) =>
              (section['type']?.toString().toLowerCase() ?? '') != 'table',
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (normalizedSections.isEmpty)
          _markdown(context, text)
        else
          ...normalizedSections
              .map((section) => _buildSectionCard(context, section)),
        if (shouldRenderFallbackStructured) ...[
          const SizedBox(height: 8),
          _buildStructuredWidget(
            context,
            title: 'Structured Data',
            type: responseType?.toLowerCase() ?? 'table',
            data: structuredData,
          ),
        ],
        if (!hasSafetySection &&
            safety != null &&
            safety!['warnings'] is List &&
            (safety!['warnings'] as List).isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildSectionCard(
            context,
            {
              'key': 'safety',
              'title': 'Safety',
              'warnings': safety!['warnings'],
            },
          ),
        ],
      ],
    );
  }

  Widget _buildResponseBlock(BuildContext context, Map<String, dynamic> block) {
    final type = (block['type'] ?? '').toString().toLowerCase();
    final title = (block['title'] ?? '').toString().trim();
    if (type == 'documentsources') {
      // Source cards are rendered by ChatScreen, where each button can make a
      // fresh authenticated preview request. A signed URL is never stored in a
      // block or opened directly from Markdown.
      return const SizedBox.shrink();
    }
    if (type == 'labresults') {
      final items = block['items'] is List ? List<dynamic>.from(block['items']) : const <dynamic>[];
      return _LabResultsBlock(title: title, items: items);
    }
    if (type == 'insightlist') {
      final items = block['items'] is List ? List<dynamic>.from(block['items']) : const <dynamic>[];
      return _sectionSurface(
        context,
        title: title,
        child: _buildBullets(
          context,
          items.map((item) {
            if (item is Map) {
              final mapped = item.map((key, value) => MapEntry(key.toString(), value));
              final heading = mapped['title']?.toString().trim() ?? '';
              final description = (mapped['description'] ?? mapped['text'] ?? '').toString().trim();
              return heading.isEmpty ? description : '$heading: $description';
            }
            return item.toString();
          }).where((item) => item.isNotEmpty).toList(growable: false),
        ),
      );
    }
    if (type == 'table') {
      final data = block['data'] is Map
          ? (block['data'] as Map).map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      return AITableWidget(data: data, title: title);
    }
    if (type == 'disclaimer') {
      return _sectionSurface(
        context,
        title: title.isEmpty ? 'Important' : title,
        tone: _SectionTone.caution,
        child: _markdown(context, (block['text'] ?? '').toString()),
      );
    }
    if (type == 'heading') {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Text((block['text'] ?? title).toString(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );
    }
    final markdown = (block['markdown'] ?? block['text'] ?? '').toString();
    return _sectionSurface(
      context,
      title: title,
      child: _markdown(context, markdown),
    );
  }

  Widget _sectionSurface(
    BuildContext context, {
    required String title,
    required Widget child,
    _SectionTone tone = _SectionTone.standard,
  }) {
    final theme = Theme.of(context);
    final background = tone == _SectionTone.caution
        ? Colors.orange.withValues(alpha: theme.brightness == Brightness.dark ? .16 : .10)
        : Colors.transparent;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
          ],
          child,
        ],
      ),
    );
  }

  Widget _markdown(BuildContext context, String source) {
    // The server already emits Markdown fallback. Remove any HTML tags before
    // rendering and do not attach a link handler, so AI output cannot open an
    // arbitrary route in the client.
    final sanitized = source.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    if (sanitized.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return MarkdownBody(
      data: sanitized,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyMedium?.copyWith(height: 1.38),
        h1: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        h2: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        h3: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        tableBorder: TableBorder.all(color: theme.dividerColor),
        tableCellsPadding: const EdgeInsets.all(7),
      ),
    );
  }

  List<Map<String, dynamic>> _normalizedSections() {
    final rawSections = sections ?? const <Map<String, dynamic>>[];
    if (rawSections.isNotEmpty) {
      return rawSections
          .map((entry) => Map<String, dynamic>.from(entry))
          .where((entry) {
        final hasContent =
            (entry['content']?.toString().trim().isNotEmpty ?? false) ||
                (entry['data'] != null) ||
                (entry['warnings'] is List &&
                    (entry['warnings'] as List).isNotEmpty) ||
                (entry['items'] is List && (entry['items'] as List).isNotEmpty);
        return hasContent;
      }).toList(growable: false);
    }

    return _deriveSectionsFromText(text);
  }

  List<Map<String, dynamic>> _deriveSectionsFromText(String value) {
    final lines = value.split(RegExp(r'\r?\n'));
    final headingRegex =
        RegExp(r'^(#{1,3}\s*)?([A-Za-z][A-Za-z0-9 /&()_-]{2,48})(:)?$');
    final knownHeadings = <String>{
      'summary',
      'clinical summary',
      'key points',
      'key findings',
      'important details',
      'structured data',
      'table',
      'what this means',
      'clinical relevance',
      'what to do next',
      'next steps',
      'follow-up considerations',
      'missing / unclear information',
      'pertinent history',
      'safety',
      'urgent warning signs',
      'get urgent help now if',
    };

    final blocks = <Map<String, dynamic>>[];
    var currentTitle = 'Summary';
    final currentLines = <String>[];

    void flushCurrent() {
      final content = currentLines.join('\n').trim();
      if (content.isNotEmpty) {
        blocks.add({
          'key':
              currentTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
          'title': currentTitle,
          'content': content,
        });
      }
      currentLines.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      final headingMatch = headingRegex.firstMatch(line.trim());
      if (headingMatch != null) {
        final heading = (headingMatch.group(2) ?? '').trim();
        if (knownHeadings.contains(heading.toLowerCase())) {
          flushCurrent();
          currentTitle = heading;
          continue;
        }
      }
      currentLines.add(line);
    }
    flushCurrent();

    if (blocks.isEmpty && value.trim().isNotEmpty) {
      blocks.add({
        'key': 'summary',
        'title': 'Summary',
        'content': value.trim(),
      });
    }

    return blocks;
  }

  Widget _buildSectionCard(BuildContext context, Map<String, dynamic> section) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final title = (section['title'] ?? '').toString().trim();
    final key = (section['key'] ?? '').toString().trim().toLowerCase();
    final type = (section['type'] ?? '').toString().trim().toLowerCase();
    final warnings = section['warnings'] is List
        ? List<dynamic>.from(section['warnings'])
        : const <dynamic>[];
    final items = section['items'] is List
        ? List<dynamic>.from(section['items'])
        : const <dynamic>[];
    final content = (section['content'] ?? '').toString().trim();
    final data = section['data'];
    final isSafety = key == 'safety';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSafety
            ? Colors.orange.withValues(alpha: isDarkMode ? 0.16 : 0.12)
            : (isDarkMode ? const Color(0xFF2E2E2E) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSafety
              ? Colors.orange.withValues(alpha: 0.35)
              : (isDarkMode ? Colors.white12 : Colors.grey[300]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (warnings.isNotEmpty)
            _buildBullets(
              context,
              warnings.map((entry) => entry.toString()).toList(growable: false),
            )
          else if (items.isNotEmpty)
            _buildBullets(
              context,
              items.map((entry) => entry.toString()).toList(growable: false),
            )
          else if (type == 'table' || type == 'chart')
            _buildStructuredWidget(
              context,
              title: '',
              type: type,
              data: data,
            )
          else if (data is Map<String, dynamic>)
            _buildStructuredWidget(
              context,
              title: '',
              type: type.isNotEmpty ? type : 'table',
              data: data,
            )
          else if (content.isNotEmpty)
            _buildContentBody(context, content),
        ],
      ),
    );
  }

  Widget _buildStructuredWidget(
    BuildContext context, {
    required String title,
    required String type,
    required Map<String, dynamic>? data,
  }) {
    if (data == null) {
      return const SizedBox.shrink();
    }
    if (type == 'chart') {
      return AIChartWidget(
        data: data,
        title: title.isEmpty ? 'Chart' : title,
      );
    }
    return AITableWidget(
      data: data,
      title: title,
    );
  }

  Widget _buildContentBody(BuildContext context, String content) {
    final tableData = _tryParsePipeTable(content);
    if (tableData != null) {
      return AITableWidget(data: tableData, title: '');
    }

    final bullets = content
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) =>
            line.startsWith('- ') ||
            line.startsWith('* ') ||
            line.startsWith('• '))
        .map((line) => line.substring(2).trim())
        .toList(growable: false);

    if (bullets.length >= 2) {
      return _buildBullets(context, bullets);
    }

    return _markdown(context, content);
  }

  Widget _buildBullets(BuildContext context, List<String> bullets) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: bullets.map((line) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.circle,
                  size: 6,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  line,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }

  Map<String, dynamic>? _tryParsePipeTable(String content) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.contains('|'))
        .toList(growable: false);
    if (lines.length < 2) return null;

    List<String> parseRow(String line) {
      return line
          .split('|')
          .map((cell) => cell.trim())
          .where((cell) => cell.isNotEmpty)
          .toList(growable: false);
    }

    final columns = parseRow(lines.first);
    if (columns.length < 2) return null;

    var bodyStart = 1;
    if (lines.length > 1 &&
        (RegExp(r'^-+\s*\|').hasMatch(lines[1]) ||
            RegExp(r'\|\s*-+').hasMatch(lines[1]))) {
      bodyStart = 2;
    }
    if (bodyStart >= lines.length) return null;

    final rows = lines
        .skip(bodyStart)
        .map(parseRow)
        .where((row) => row.isNotEmpty)
        .map((row) {
      final normalized = row.take(columns.length).toList(growable: true);
      while (normalized.length < columns.length) {
        normalized.add('—');
      }
      return normalized;
    }).toList(growable: false);
    if (rows.isEmpty) return null;

    return {
      'columns': columns,
      'rows': rows,
    };
  }
}

enum _SectionTone { standard, caution }

class _LabResultsBlock extends StatelessWidget {
  const _LabResultsBlock({required this.title, required this.items});

  final String title;
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
          ],
          ...items.whereType<Map>().map((entry) {
            final item = entry.map(
                (key, value) => MapEntry(key.toString(), value));
            final status = (item['status'] ?? '').toString().toLowerCase();
            final statusColor = status.contains('below') ||
                    status.contains('above') ||
                    status.contains('attention')
                ? Colors.amber.shade800
                : status.contains('critical') || status.contains('urgent')
                    ? theme.colorScheme.error
                    : Colors.green.shade700;
            final statusText = switch (status) {
              'below_reference' => 'Below the displayed reference range',
              'above_reference' => 'Above the displayed reference range',
              'within_reference' => 'Within the displayed reference range',
              _ => (item['statusLabel'] ?? '').toString(),
            };
            final value = [item['value'], item['unit']]
                .where((part) =>
                    part != null && part.toString().trim().isNotEmpty)
                .join(' ');
            final reference = item['referenceRange']?.toString().trim() ?? '';
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((item['name'] ?? 'Result').toString(),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (value.isNotEmpty)
                    Text(value, style: theme.textTheme.bodyLarge),
                  if (reference.isNotEmpty)
                    Text('Reference: $reference',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  if (statusText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(statusText,
                          style: theme.textTheme.labelMedium?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class DocumentPreviewCard extends StatelessWidget {
  final String id;
  final String name;
  final String type;
  final String date;
  final bool previewAvailable;
  final VoidCallback? onPreview;
  final VoidCallback? onTap;

  const DocumentPreviewCard({
    super.key,
    required this.id,
    required this.name,
    required this.type,
    required this.date,
    this.previewAvailable = false,
    this.onPreview,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isDarkMode ? const Color(0xFF2E2E2E) : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(type),
          child: Icon(
            _getTypeIcon(type),
            color: Colors.white,
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              type,
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.grey[600],
                fontSize: 12,
              ),
            ),
            Text(
              formatDateForContext(context, date,
                  pattern: 'd MMM yyyy', fallback: ''),
              style: TextStyle(
                color: isDarkMode ? Colors.white60 : Colors.grey[500],
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (previewAvailable)
              IconButton(
                icon: const Icon(Icons.visibility, size: 18),
                color: isDarkMode ? Colors.white70 : Colors.black54,
                tooltip: 'Preview',
                onPressed: onPreview,
              ),
            IconButton(
              icon: const Icon(Icons.analytics_outlined, size: 18),
              color: isDarkMode ? Colors.white70 : Colors.black54,
              tooltip: 'Analyze',
              onPressed: onTap,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'report':
        return Colors.blue;
      case 'prescription':
        return Colors.green;
      case 'bill':
        return Colors.orange;
      case 'insurance':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'report':
        return Icons.description;
      case 'prescription':
        return Icons.medication;
      case 'bill':
        return Icons.receipt;
      case 'insurance':
        return Icons.security;
      default:
        return Icons.insert_drive_file;
    }
  }
}
