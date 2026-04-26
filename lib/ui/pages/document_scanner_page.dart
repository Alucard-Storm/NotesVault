import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors/error_handler.dart';

/// Result from document scanning
class DocumentScanResult {
  DocumentScanResult({
    required this.imagePath,
    this.extractedText = '',
  });

  final String imagePath;
  final String extractedText;
}

/// Page for scanning documents using camera
class DocumentScannerPage extends StatefulWidget {
  const DocumentScannerPage({super.key});

  @override
  State<DocumentScannerPage> createState() => _DocumentScannerPageState();
}

class _DocumentScannerPageState extends State<DocumentScannerPage> {
  final _imagePicker = ImagePicker();
  XFile? _scannedImage;
  final _textController = TextEditingController();
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isProcessing = false;

  bool get _isOcrSupported {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> _processSelectedImage(XFile image) async {
    setState(() {
      _isProcessing = true;
      _scannedImage = image;
    });

    String extractedText = '';
    if (_isOcrSupported) {
      extractedText = await _extractTextFromImage(image.path);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _textController.text = extractedText.trim();
      _isProcessing = false;
    });

    if (!_isOcrSupported) {
      ErrorHandler.showErrorSnackBar(
        context,
        'OCR is currently supported on Android and iOS only. You can still enter text manually.',
      );
      return;
    }

    if (extractedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text detected. You can edit text manually.')),
      );
    }
  }

  Future<String> _extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          'Text recognition failed: $e',
        );
      }
      return '';
    }
  }

  Future<void> _captureImage() async {
    try {
      setState(() => _isProcessing = true);
      
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (!mounted) return;

      if (image == null) {
        setState(() => _isProcessing = false);
        return;
      }

      await _processSelectedImage(image);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ErrorHandler.showErrorSnackBar(
        context,
        'Failed to capture image: $e',
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      setState(() => _isProcessing = true);
      
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (!mounted) return;

      if (image == null) {
        setState(() => _isProcessing = false);
        return;
      }

      await _processSelectedImage(image);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ErrorHandler.showErrorSnackBar(
        context,
        'Failed to pick image: $e',
      );
    }
  }

  void _createNoteFromScan() {
    if (_scannedImage == null) {
      ErrorHandler.showErrorSnackBar(
        context,
        'Please capture or select an image first',
      );
      return;
    }

    final result = DocumentScanResult(
      imagePath: _scannedImage!.path,
      extractedText: _textController.text,
    );

    Navigator.pop(context, result);
  }

  void _clear() {
    setState(() {
      _scannedImage = null;
      _textController.clear();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Document'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image preview
                    if (_scannedImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_scannedImage!.path),
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.document_scanner_outlined,
                              size: 48,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No image selected',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Action buttons
                    FilledButton.icon(
                      onPressed: _captureImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickImageFromGallery,
                      icon: const Icon(Icons.image),
                      label: const Text('Pick from Gallery'),
                    ),
                    const SizedBox(height: 24),
                    if (_scannedImage != null) ...[
                      const Text(
                        'Extracted Text (Edit if needed):',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // OCR output can be edited manually
                      TextField(
                        controller: _textController,
                        minLines: 6,
                        maxLines: 12,
                        decoration: InputDecoration(
                          hintText: 'Enter or paste extracted text here...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _createNoteFromScan,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Create Note'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _clear,
                        child: const Text('Clear & Try Again'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
