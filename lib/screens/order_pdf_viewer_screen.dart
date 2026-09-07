import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/bill_models.dart';

/// Screen that renders an authentic Presidential Executive Order document
/// directly inside the application, with native zoom, print, and PDF download.
class OrderPdfViewerScreen extends StatefulWidget {
  final ExecutiveOrderRecord order;

  const OrderPdfViewerScreen({
    super.key,
    required this.order,
  });

  @override
  State<OrderPdfViewerScreen> createState() => _OrderPdfViewerScreenState();
}

class _OrderPdfViewerScreenState extends State<OrderPdfViewerScreen> {
  final TransformationController _transformController = TransformationController();
  double _currentScale = 1.0;
  bool _isGeneratingPdf = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      _currentScale = (_currentScale + 0.2).clamp(0.6, 2.5);
      _transformController.value = Matrix4.identity()..scale(_currentScale);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentScale = (_currentScale - 0.2).clamp(0.6, 2.5);
      _transformController.value = Matrix4.identity()..scale(_currentScale);
    });
  }

  void _resetZoom() {
    setState(() {
      _currentScale = 1.0;
      _transformController.value = Matrix4.identity();
    });
  }

  Future<void> _launchGovInfoPdf() async {
    if (widget.order.pdfUrl.isEmpty) return;
    final uri = Uri.parse(widget.order.pdfUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch official PDF URL')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening PDF: $e')),
        );
      }
    }
  }

  Future<Uint8List> _generateOrderPdfBytes(PdfPageFormat format) async {
    final pdf = pw.Document();

    final title = widget.order.title.trim();
    final orderNum = widget.order.orderNumber.trim();
    final president = widget.order.president.trim();
    final citation = widget.order.citation.trim();
    final signDate = widget.order.signingDate.trim();
    final pubDate = widget.order.publicationDate.trim();
    final summary = (widget.order.summary != null && widget.order.summary!.trim().isNotEmpty)
        ? widget.order.summary!.trim()
        : 'Executive Order $orderNum directs federal departments and agencies regarding "$title" pursuant to presidential authority under Article II of the United States Constitution.';
    final disposition = widget.order.dispositionNotes?.trim() ?? '';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(40),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'FEDERAL REGISTER',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.Text(
                    citation.isNotEmpty ? citation : 'Presidential Documents',
                    style: const pw.TextStyle(fontSize: 10, letterSpacing: 0.8),
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, height: 12),
              pw.SizedBox(height: 8),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 0.8, height: 14),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    citation.isNotEmpty ? 'Citation: $citation' : '',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    pubDate.isNotEmpty ? 'Publication: $pubDate' : '',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'National Archives & Records Administration',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Title 3 Masthead
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'Title 3—THE PRESIDENT',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Executive Order $orderNum',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (signDate.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Signed: $signDate',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Order Title Box
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 1.0, color: PdfColors.black),
              ),
              child: pw.Text(
                title,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  lineSpacing: 2,
                ),
              ),
            ),
            pw.SizedBox(height: 16),

            // Preamble
            pw.Text(
              'By the authority vested in me as President by the Constitution and the laws of the United States of America, it is hereby ordered as follows:',
              style: const pw.TextStyle(
                fontSize: 10.5,
                lineSpacing: 1.4,
              ),
            ),
            pw.SizedBox(height: 14),

            // Section 1: Policy & Purpose
            pw.Text(
              'Section 1. Policy and Purpose.',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              summary,
              style: const pw.TextStyle(
                fontSize: 10,
                lineSpacing: 1.45,
              ),
            ),
            pw.SizedBox(height: 12),

            // Section 2: Implementation Directives
            pw.Text(
              'Sec. 2. Directives and Agency Implementation.',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'The heads of all executive departments and agencies shall take all necessary actions within their lawful authority and consistent with applicable law to execute the provisions and policy directives set forth in this order.',
              style: const pw.TextStyle(
                fontSize: 10,
                lineSpacing: 1.45,
              ),
            ),
            pw.SizedBox(height: 12),

            // Disposition Notes
            if (disposition.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(width: 0.5, color: PdfColors.grey400),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Legal Disposition & Relationship to Prior Actions:',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      disposition.replaceAll('\r', '').replaceAll('\n', '; '),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
            ],

            // Section 3: General Provisions
            pw.Text(
              'Sec. 3. General Provisions.',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '(a) Nothing in this order shall be construed to impair or otherwise affect the authority granted by law to an executive department or agency, or the head thereof, or the functions of the Director of the Office of Management and Budget relating to budgetary, administrative, or legislative proposals.\n'
              '(b) This order shall be implemented consistent with applicable law and subject to the availability of appropriations.\n'
              '(c) This order is not intended to, and does not, create any right or benefit, substantive or procedural, enforceable at law or in equity by any party against the United States, its departments, agencies, or entities, its officers, employees, or agents, or any other person.',
              style: const pw.TextStyle(
                fontSize: 9.5,
                lineSpacing: 1.35,
              ),
            ),
            pw.SizedBox(height: 24),

            // Signature Block
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    president.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'THE WHITE HOUSE,',
                    style: const pw.TextStyle(fontSize: 9, letterSpacing: 0.8),
                  ),
                  if (signDate.isNotEmpty)
                    pw.Text(
                      signDate,
                      style: const pw.TextStyle(fontSize: 8.5),
                    ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _downloadPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final bytes = await _generateOrderPdfBytes(PdfPageFormat.letter);
      final filename = 'Executive_Order_${widget.order.orderNumber}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading $filename...'),
            backgroundColor: const Color(0xFF1E3A8A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _printDocument() async {
    try {
      await Printing.layoutPdf(
        name: 'Executive_Order_${widget.order.orderNumber}',
        onLayout: (format) => _generateOrderPdfBytes(format),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eo = widget.order;
    final orderNum = eo.orderNumber.trim();
    final title = eo.title.trim();
    final citation = eo.citation.trim();
    final signDate = eo.signingDate.trim();
    final pubDate = eo.publicationDate.trim();
    final president = eo.president.trim();
    final summary = (eo.summary != null && eo.summary!.trim().isNotEmpty)
        ? eo.summary!.trim()
        : 'Executive Order $orderNum directs federal departments and agencies regarding "$title" pursuant to presidential authority under Article II of the United States Constitution.';
    final disposition = eo.dispositionNotes?.trim() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 2,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Executive Order $orderNum",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (citation.isNotEmpty)
              Text(
                citation,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          // Zoom Controls
          IconButton(
            tooltip: "Zoom Out",
            icon: const Icon(Icons.zoom_out, size: 20),
            onPressed: _zoomOut,
          ),
          Center(
            child: Text(
              "${(_currentScale * 100).toInt()}%",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
          ),
          IconButton(
            tooltip: "Zoom In",
            icon: const Icon(Icons.zoom_in, size: 20),
            onPressed: _zoomIn,
          ),
          IconButton(
            tooltip: "Reset Zoom",
            icon: const Icon(Icons.fit_screen, size: 20),
            onPressed: _resetZoom,
          ),
          const SizedBox(width: 6),

          // Download PDF Action Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton.icon(
              icon: _isGeneratingPdf
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download, size: 16),
              label: const Text("Download PDF"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: _isGeneratingPdf ? null : _downloadPdf,
            ),
          ),
          const SizedBox(width: 8),

          // Print Action Button
          IconButton(
            tooltip: "Print Order",
            icon: const Icon(Icons.print, size: 20),
            onPressed: _printDocument,
          ),

          // GovInfo Link
          if (eo.pdfUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 12),
              child: Tooltip(
                message: "Open original GPO GovInfo PDF",
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text("GovInfo PDF"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF93C5FD),
                    side: const BorderSide(color: Color(0xFF3B82F6)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  onPressed: _launchGovInfoPdf,
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.5,
          maxScale: 2.8,
          boundaryMargin: const EdgeInsets.all(80),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 820),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 28,
                      spreadRadius: 4,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Official Federal Register Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          "FEDERAL REGISTER",
                          style: TextStyle(
                            fontFamily: "Georgia",
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          citation.isNotEmpty ? citation : "Presidential Documents",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const Divider(thickness: 2.0, color: Color(0xFF0F172A), height: 16),
                    const SizedBox(height: 12),

                    // Title 3 Masthead
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            "Title 3—THE PRESIDENT",
                            style: TextStyle(
                              fontFamily: "Georgia",
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Executive Order $orderNum",
                            style: const TextStyle(
                              fontFamily: "Georgia",
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (signDate.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Signed: $signDate",
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Boxed Title
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                      decoration: BoxDecoration(
                        border: Border.all(width: 1.5, color: const Color(0xFF0F172A)),
                        color: const Color(0xFFF8FAFC),
                      ),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: "Georgia",
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Preamble
                    const Text(
                      "By the authority vested in me as President by the Constitution and the laws of the United States of America, it is hereby ordered as follows:",
                      style: TextStyle(
                        fontFamily: "Georgia",
                        fontSize: 13.5,
                        height: 1.6,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 1: Policy and Purpose
                    const Text(
                      "Section 1. Policy and Purpose.",
                      style: TextStyle(
                        fontFamily: "Georgia",
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      summary,
                      style: const TextStyle(
                        fontFamily: "Georgia",
                        fontSize: 13,
                        height: 1.65,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 2: Directives & Agency Implementation
                    const Text(
                      "Sec. 2. Directives and Agency Implementation.",
                      style: TextStyle(
                        fontFamily: "Georgia",
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "The heads of all executive departments and agencies shall take all necessary actions within their lawful authority and consistent with applicable law to execute the provisions and policy directives set forth in this order.",
                      style: TextStyle(
                        fontFamily: "Georgia",
                        fontSize: 13,
                        height: 1.65,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Disposition Notes
                    if (disposition.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
                                SizedBox(width: 6),
                                Text(
                                  "Legal Disposition & Relationship to Prior Actions:",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              disposition,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF78350F),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Section 3: General Provisions
                    const Text(
                      "Sec. 3. General Provisions.",
                      style: TextStyle(
                        fontFamily: "Georgia",
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "(a) Nothing in this order shall be construed to impair or otherwise affect the authority granted by law to an executive department or agency, or the head thereof, or the functions of the Director of the Office of Management and Budget relating to budgetary, administrative, or legislative proposals.\n\n"
                      "(b) This order shall be implemented consistent with applicable law and subject to the availability of appropriations.\n\n"
                      "(c) This order is not intended to, and does not, create any right or benefit, substantive or procedural, enforceable at law or in equity by any party against the United States, its departments, agencies, or entities, its officers, employees, or agents, or any other person.",
                      style: TextStyle(
                        fontFamily: "Georgia",
                        fontSize: 12.5,
                        height: 1.55,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Presidential Signature Block
                    Align(
                      alignment: Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            president.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: "Georgia",
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            "THE WHITE HOUSE,",
                            style: TextStyle(
                              fontFamily: "Georgia",
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                              color: Color(0xFF475569),
                            ),
                          ),
                          if (signDate.isNotEmpty)
                            Text(
                              signDate,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(thickness: 1.0, color: Color(0xFFCBD5E1)),
                    const SizedBox(height: 8),

                    // Archival Footer
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (citation.isNotEmpty)
                            Text(
                              "FR Citation: $citation",
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                          if (pubDate.isNotEmpty)
                            Text(
                              "Publication: $pubDate",
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                          const Text(
                            "National Archives & Records Administration",
                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
