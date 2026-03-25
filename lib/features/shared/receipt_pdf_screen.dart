import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:waste_bridge/core/ui/user_safe_error.dart';
import 'package:waste_bridge/providers/app_providers.dart';
import 'package:waste_bridge/services/api_endpoints.dart';

/// In-app PDF viewer for `GET /receipts/{id}/pdf` (authenticated bytes).
class ReceiptPdfScreen extends ConsumerStatefulWidget {
  const ReceiptPdfScreen({super.key, required this.receiptId});

  final String receiptId;

  @override
  ConsumerState<ReceiptPdfScreen> createState() => _ReceiptPdfScreenState();
}

class _ReceiptPdfScreenState extends ConsumerState<ReceiptPdfScreen> {
  PdfControllerPinch? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final dio = ref.read(apiClientProvider).dio;
      final response = await dio.get<List<int>>(
        ApiEndpoints.receiptPdf(widget.receiptId),
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'application/pdf'},
        ),
      );
      final raw = response.data;
      if (raw == null || raw.isEmpty) {
        throw StateError('Empty PDF');
      }
      final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
      if (!mounted) return;
      setState(() {
        _controller = PdfControllerPinch(
          document: PdfDocument.openData(bytes),
        );
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final err = _error;
    final c = _controller;
    return Scaffold(
      appBar: AppBar(title: Text('Receipt ${widget.receiptId}')),
      body: err != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  userVisibleError(err, fallback: 'Could not load PDF.'),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : c == null
              ? const Center(child: CircularProgressIndicator())
              : PdfViewPinch(controller: c),
    );
  }
}
