import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:provider/provider.dart';
import '../models/purchase.dart';
import '../utils/constants.dart';

class ReceiptDialog extends StatefulWidget {
  final Purchase purchase;

  const ReceiptDialog({super.key, required this.purchase});

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  PrinterBluetoothManager _printerManager = PrinterBluetoothManager();
  List<PrinterBluetooth> _printers = [];
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _scanPrinters();
  }

  Future<void> _scanPrinters() async {
    final printers = await _printerManager.scanResults.toList();
    setState(() {
      _printers = printers.cast<PrinterBluetooth>();
    });
  }

  Future<void> _printReceipt({PrinterBluetooth? printer}) async {
    setState(() => _isPrinting = true);

    final List<int> bytes = await _generateReceipt();

    if (printer != null) {
      await _printerManager.connect(printer);
      await _printerManager.writeBytes(bytes);
      await _printerManager.disconnect();
    } else {
      // Fallback to share/print dialog
      await _showPrintPreview(bytes);
    }

    setState(() => _isPrinting = false);
  }

  Future<List<int>> _generateReceipt() async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    // Header
    bytes += generator.text(
      'MARNIE STORE',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    bytes += generator.text(
      'Official Receipt',
      styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size1),
    );
    bytes += generator.text('-' * 32);
    
    // Customer & Date
    bytes += generator.text('Customer: ${widget.purchase.customerName}');
    bytes += generator.text('Date: ${_formatDate(widget.purchase.purchaseDate)}');
    bytes += generator.text('-' * 32);
    
    // Items
    bytes += generator.text('ITEM', styles: const PosStyles(bold: true));
    bytes += generator.text('Qty  Price     Total', styles: const PosStyles(bold: true));
    
    for (final item in widget.purchase.items) {
      bytes += generator.text(item.name);
      final line = '${item.quantity}   ₱${item.price.toStringAsFixed(2)}  ₱${item.subtotal.toStringAsFixed(2)}';
      bytes += generator.text(line);
    }
    
    bytes += generator.text('-' * 32);
    
    // Total
    bytes += generator.text(
      'TOTAL: ₱${widget.purchase.totalAmount.toStringAsFixed(2)}',
      styles: const PosStyles(bold: true, height: PosTextSize.size1),
    );
    bytes += generator.text('-' * 32);
    
    // Footer
    bytes += generator.text('Thank you!', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Status: ${widget.purchase.status.toUpperCase()}');
    bytes += generator.text('-' * 32);
    
    // Cut paper
    bytes += generator.cut();

    return bytes;
  }

  Future<void> _showPrintPreview(List<int> bytes) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Receipt Preview', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              String.fromCharCodes(bytes),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 44, color: AppColors.success),
            const SizedBox(height: 8),
            const Text(
              'Purchase Complete!',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Status: ${widget.purchase.status.toUpperCase()}',
              style: TextStyle(color: AppColors.warning, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            
            // Receipt preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Text('MARNIE STORE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  Center(child: Text('Official Receipt', style: TextStyle(fontSize: 12))),
                  Divider(),
                  Text('Customer: ${widget.purchase.customerName}'),
                  Text('Date: ${_formatDate(widget.purchase.purchaseDate)}'),
                  Divider(),
                  ...widget.purchase.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${item.name} × ${item.quantity}', style: TextStyle(fontSize: 12)),
                        Text('₱${item.subtotal.toStringAsFixed(2)}', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  )),
                  Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('₱${widget.purchase.totalAmount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Center(child: Text('Thank you!', style: TextStyle(fontSize: 10))),
                  Center(child: Text('Status: ${widget.purchase.status}', style: TextStyle(fontSize: 10))),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Bluetooth printers list
            if (_printers.isNotEmpty) ...[
              const Text('Select Bluetooth Printer:', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              ..._printers.map((printer) => ListTile(
                title: Text(printer.name ?? 'Unknown Printer', style: const TextStyle(color: Colors.white)),
                onTap: () => _printReceipt(printer: printer),
              )),
            ],
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isPrinting ? null : () => _printReceipt(printer: null),
                    icon: _isPrinting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.print, size: 16),
                    label: Text(_isPrinting ? 'Printing...' : 'Print Receipt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
            
            // Bluetooth permission note
            const SizedBox(height: 8),
            Text(
              'Make sure Bluetooth is enabled and printer is paired',
              style: TextStyle(color: AppColors.textMuted, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
