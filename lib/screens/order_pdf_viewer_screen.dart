import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/bill_models.dart';

class OrderPdfViewerScreen extends StatelessWidget {
  final ExecutiveOrderRecord order;

  const OrderPdfViewerScreen({
    super.key,
    required this.order,
  });

  Future<void> _launchGovInfoPdf(BuildContext context) async {
    if (order.pdfUrl.isEmpty) return;
    final uri = Uri.parse(order.pdfUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch official PDF URL')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening PDF: $e')),
        );
      }
    }
  }

  Future<Uint8List> _generateOrderPdf(PdfPageFormat format) async {
    final pdf = pw.Document();

    final title = order.title.trim();
    final orderNum = order.orderNumber.trim();
    final president = order.president.trim();
    final citation = order.citation.trim();
    final signDate = order.signingDate.trim();
    final pubDate = order.publicationDate.trim();
    final summary = (order.summary != null && order.summary!.trim().isNotEmpty)
        ? order.summary!.trim()
        : "Executive Order $orderNum directs federal departments and agencies regarding \"$title\" pursuant to presidential authority under Article II of the United States Constitution.";
    final disposition = order.dispositionNotes?.trim() ?? "";

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Government Publishing Office / Federal Register Masthead
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "FEDERAL REGISTER",
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.Text(
                    citation.isNotEmpty ? citation : "Presidential Documents",
                    style: pw.TextStyle(fontSize: 10, letterSpacing: 0.8),
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, height: 12),

              // Title 3 Masthead
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      "Title 3—THE PRESIDENT",
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      "Executive Order $orderNum",
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (signDate.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Signed: $signDate",
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
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.8, color: PdfColors.grey700),
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
              pw.SizedBox(height: 14),

              // Preamble
              pw.Text(
                "By the authority vested in me as President by the Constitution and the laws of the United States of America, it is hereby ordered as follows:",
                style: const pw.TextStyle(
                  fontSize: 10.5,
                  lineSpacing: 1.4,
                ),
              ),
              pw.SizedBox(height: 12),

              // Section 1: Purpose & Policy
              pw.Text(
                "Section 1. Policy and Purpose.",
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
              pw.SizedBox(height: 10),

              // Section 2: Implementation
              pw.Text(
                "Sec. 2. Directives and Agency Implementation.",
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                "The heads of all executive departments and agencies shall take all necessary actions within their lawful authority and consistent with applicable law to execute the provisions and policy directives set forth in this order.",
                style: const pw.TextStyle(
                  fontSize: 10,
                  lineSpacing: 1.45,
                ),
              ),
              pw.SizedBox(height: 10),

              // Legal Disposition if any
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
                        "Legal Disposition & Relationship to Prior Actions:",
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
                pw.SizedBox(height: 10),
              ],

              // Section 3: General Provisions
              pw.Text(
                "Sec. 3. General Provisions.",
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                "(a) Nothing in this order shall be construed to impair or otherwise affect the authority granted by law to an executive department or agency, or the head thereof, or the functions of the Director of the Office of Management and Budget relating to budgetary, administrative, or legislative proposals.\n"
                "(b) This order shall be implemented consistent with applicable law and subject to the availability of appropriations.",
                style: const pw.TextStyle(
                  fontSize: 9.5,
                  lineSpacing: 1.35,
                ),
              ),
              pw.Spacer(),

              // Presidential Signature Block
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
                      "THE WHITE HOUSE",
                      style: pw.TextStyle(
                        fontSize: 9,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (signDate.isNotEmpty)
                      pw.Text(
                        signDate,
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                  ],
                ),
              ),
              pw.Divider(thickness: 0.8, height: 16),

              // Official Document Filing Footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    citation.isNotEmpty ? "Citation: $citation" : "",
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    pubDate.isNotEmpty ? "Federal Register Publication: $pubDate" : "",
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    "National Archives & Records Administration",
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Executive Order ${order.orderNumber}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (order.citation.isNotEmpty)
              Text(
                order.citation,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        actions: [
          if (order.pdfUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download, size: 16),
                label: const Text("GovInfo PDF"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _launchGovInfoPdf(context),
              ),
            ),
        ],
      ),
      body: PdfPreview(
        build: (format) => _generateOrderPdf(format),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: "Executive_Order_${order.orderNumber}.pdf",
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        previewPageMargin: const EdgeInsets.all(16),
      ),
    );
  }
}
