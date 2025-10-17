import 'package:flutter/material.dart';

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
              headingRowColor: MaterialStateProperty.all(
                isDarkMode ? const Color(0xFF3E3E3E) : Colors.grey[200],
              ),
              dataRowColor: MaterialStateProperty.all(
                isDarkMode ? const Color(0xFF2E2E2E) : Colors.white,
              ),
              columns: columns
                  .map((column) => DataColumn(
                        label: SelectableText(
                          column,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ))
                  .toList(),
              rows: tableData
                  .map((row) => DataRow(
                        cells: columns
                            .map((column) => DataCell(
                                  SelectableText(
                                    row[column]?.toString() ?? '',
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.black87,
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

class DocumentPreviewCard extends StatelessWidget {
  final String id;
  final String name;
  final String type;
  final String date;
  final String? previewUrl;
  final VoidCallback? onTap;

  const DocumentPreviewCard({
    super.key,
    required this.id,
    required this.name,
    required this.type,
    required this.date,
    this.previewUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isDarkMode ? const Color(0xFF2E2E2E) : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(type),
          child: Icon(
            _getTypeIcon(type),
            color: Colors.white,
          ),
        ),
        title: SelectableText(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              type,
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.grey[600],
                fontSize: 12,
              ),
            ),
            SelectableText(
              date,
              style: TextStyle(
                color: isDarkMode ? Colors.white60 : Colors.grey[500],
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
