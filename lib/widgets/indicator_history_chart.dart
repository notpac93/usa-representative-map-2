import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

/// A dated observation; periods are YYYY or YYYY-MM. Missing periods remain
/// gaps, rather than being interpolated into an apparent observation.
class HistoryPoint {
  final String period;
  final double value;
  final double? marginOfError;
  const HistoryPoint(this.period, this.value, {this.marginOfError});
  bool followsGap(HistoryPoint previous) =>
      date.difference(previous.date).inDays > (period.length > 4 ? 45 : 400);
  DateTime get date => DateTime.utc(
    int.parse(period.substring(0, 4)),
    period.length > 4 ? int.parse(period.substring(5, 7)) : 1,
  );
}

class IndicatorHistoryChart extends StatefulWidget {
  final String title;
  final String unit;
  final String source;
  final String note;
  final List<HistoryPoint> points;
  final VoidCallback onSource;
  final bool survey;
  final bool population;
  const IndicatorHistoryChart({
    super.key,
    required this.title,
    required this.unit,
    required this.source,
    required this.note,
    required this.points,
    required this.onSource,
    this.survey = false,
    this.population = false,
  });
  @override
  State<IndicatorHistoryChart> createState() => _IndicatorHistoryChartState();
}

class _IndicatorHistoryChartState extends State<IndicatorHistoryChart> {
  String? _range;
  String? _selected;
  bool get monthly => widget.points.any((p) => p.period.length > 4);
  String label(String period) => period.length == 4
      ? period
      : DateFormat('MMM yyyy').format(HistoryPoint(period, 0).date);
  String format(double value, {bool compact = false}) {
    if (widget.unit == 'USD') {
      return compact
          ? NumberFormat.compactCurrency(
              symbol: '\$',
              decimalDigits: 1,
            ).format(value)
          : NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(value);
    }
    if (widget.unit == 'percent') return '${value.toStringAsFixed(1)}%';
    return compact
        ? NumberFormat.compact().format(value)
        : NumberFormat.decimalPattern().format(value);
  }

  @override
  Widget build(BuildContext context) {
    final all = [...widget.points]
      ..sort((a, b) => a.period.compareTo(b.period));
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFF1F4F8) : const Color(0xFF15191E);
    final muted = dark ? const Color(0xFFAFBDCC) : const Color(0xFF626D79);
    final border = dark ? const Color(0xFF354252) : const Color(0xFFE9ECF0);
    final options = monthly
        ? ['12 months', 'All']
        : ['3 years', '5 years', 'All'];
    final range = _range ?? (monthly ? 'All' : '5 years');
    final cutoff = all.isEmpty || range == 'All'
        ? null
        : monthly
        ? DateTime.utc(all.last.date.year, all.last.date.month - 11)
        : DateTime.utc(all.last.date.year - (range == '3 years' ? 2 : 4));
    final points = all
        .where((p) => cutoff == null || !p.date.isBefore(cutoff))
        .toList();
    final selected =
        points.where((p) => p.period == _selected).firstOrNull ??
        points.lastOrNull;
    final change = points.length < 2
        ? 0.0
        : points.last.value - points.first.value;
    final color = widget.survey
        ? (dark ? const Color(0xFF73D5AC) : const Color(0xFF23845F))
        : change < 0
        ? (dark ? const Color(0xFFFF8599) : const Color(0xFFD13752))
        : (dark ? const Color(0xFF73D5AC) : const Color(0xFF23845F));
    final delta = widget.unit == 'percent'
        ? '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} percentage points'
        : points.length < 2 || points.first.value == 0
        ? 'Change unavailable'
        : '${change > 0 ? '+' : ''}${(change / points.first.value * 100).toStringAsFixed(2)}%';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.population && points.isNotEmpty
                ? 'Population · ${points.first.period}–${points.last.period}'
                : widget.title,
            style: TextStyle(
              color: ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(widget.source, style: TextStyle(color: muted, fontSize: 11)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 5,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text(option, style: const TextStyle(fontSize: 11)),
                  selected: range == option,
                  onSelected: (_) => setState(() {
                    _range = option;
                    _selected = null;
                  }),
                ),
            ],
          ),
          if (points.length < 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'At least two published observations are needed for a trend.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            )
          else ...[
            const SizedBox(height: 12),
            Text(
              '$delta · ${label(points.first.period)}–${label(points.last.period)}',
              style: TextStyle(
                color: widget.survey ? muted : color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) => MouseRegion(
                onHover: (event) => _inspect(
                  event.localPosition.dx,
                  constraints.maxWidth,
                  points,
                ),
                child: GestureDetector(
                  onTapDown: (event) => _inspect(
                    event.localPosition.dx,
                    constraints.maxWidth,
                    points,
                  ),
                  child: Semantics(
                    label:
                        '${widget.title}, ${widget.unit}, ${label(points.first.period)} to ${label(points.last.period)}. Exact observations available below.',
                    child: SizedBox(
                      height: 200,
                      child: CustomPaint(
                        painter: _HistoryPainter(
                          points,
                          color,
                          muted,
                          border,
                          selected!.period,
                          (v) => format(v, compact: true),
                          label,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('${widget.title}-${selected!.period}-$range'),
              initialValue: selected.period,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Inspect a reporting period',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: points
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.period,
                      child: Text(
                        label(p.period),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (period) => setState(() => _selected = period),
            ),
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(
                '${label(selected.period)}: ${format(selected.value)}${selected.marginOfError == null ? '' : ' ±${format(selected.marginOfError!)} (90% margin of error)'}',
                style: TextStyle(
                  color: ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '${widget.unit == 'USD'
                ? 'Dollars'
                : widget.unit == 'percent'
                ? 'Percent'
                : 'Residents'} · Vertical scale fits observed values; check the axis bounds. Missing periods have gaps.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            widget.note,
            style: TextStyle(color: muted, fontSize: 11, height: 1.5),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: widget.onSource,
              child: const Text(
                'Sources & reporting notes',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _inspect(double x, double width, List<HistoryPoint> points) {
    if (points.isEmpty || width <= 90) return;
    final fraction = ((x - 62) / (width - 80)).clamp(0.0, 1.0);
    final first = points.first.date.millisecondsSinceEpoch;
    final target =
        first + fraction * (points.last.date.millisecondsSinceEpoch - first);
    final nearest = points.reduce(
      (a, b) =>
          (a.date.millisecondsSinceEpoch - target).abs() <
              (b.date.millisecondsSinceEpoch - target).abs()
          ? a
          : b,
    );
    if (_selected != nearest.period) setState(() => _selected = nearest.period);
  }
}

class _HistoryPainter extends CustomPainter {
  final List<HistoryPoint> points;
  final Color color, textColor, gridColor;
  final String selected;
  final String Function(double) format;
  final String Function(String) label;
  _HistoryPainter(
    this.points,
    this.color,
    this.textColor,
    this.gridColor,
    this.selected,
    this.format,
    this.label,
  );
  @override
  void paint(Canvas canvas, Size size) {
    const left = 62.0, top = 12.0, bottom = 30.0;
    final width = math.max(1.0, size.width - left - 18),
        height = size.height - top - bottom;
    var low = points.map((p) => p.value).reduce(math.min),
        high = points.map((p) => p.value).reduce(math.max);
    final pad = high == low
        ? math.max(1.0, high.abs() * .02)
        : (high - low) * .12;
    low = math.max(0.0, low - pad);
    high += pad;
    final first = points.first.date.millisecondsSinceEpoch,
        span = points.last.date.millisecondsSinceEpoch - first;
    Offset pos(HistoryPoint p) => Offset(
      left +
          (p.date.millisecondsSinceEpoch - first) /
              (span == 0 ? 1 : span) *
              width,
      top + (high - p.value) / (high - low) * height,
    );
    void text(String value, Offset offset, {bool right = false}) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(color: textColor, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(right ? offset.dx - painter.width : offset.dx, offset.dy),
      );
    }

    for (final step in [0.0, .5, 1.0]) {
      final y = top + step * height;
      canvas.drawLine(
        Offset(left, y),
        Offset(left + width, y),
        Paint()
          ..color = gridColor
          ..strokeWidth = .7,
      );
      text(
        format(high - step * (high - low)),
        Offset(left - 7, y - 7),
        right: true,
      );
    }
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = pos(points[i]);
      if (i == 0 || points[i].followsGap(points[i - 1])) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawCircle(
        p,
        points[i].period == selected ? 4 : 2.5,
        Paint()..color = color,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );
    text(label(points.first.period), Offset(left, size.height - 20));
    text(
      label(points.last.period),
      Offset(left + width, size.height - 20),
      right: true,
    );
  }

  @override
  bool shouldRepaint(covariant _HistoryPainter oldDelegate) => true;
}
