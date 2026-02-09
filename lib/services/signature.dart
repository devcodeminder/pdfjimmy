import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:crop_your_image/crop_your_image.dart';
import '../screens/view_signature_screen.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

class SignatureData {
  final String id;
  final Uint8List imageData;
  final String name;
  final DateTime createdAt;
  final double rotation;

  SignatureData({
    required this.id,
    required this.imageData,
    required this.name,
    required this.createdAt,
    this.rotation = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'imageData': base64Encode(imageData),
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'rotation': rotation,
  };

  factory SignatureData.fromJson(Map<String, dynamic> json) => SignatureData(
    id: json['id'],
    imageData: base64Decode(json['imageData']),
    name: json['name'],
    createdAt: DateTime.parse(json['createdAt']),
    rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
  );
}

class SignaturePosition {
  double x;
  double y;
  double scale;
  int pageNumber;
  String signatureId; // Link to specific signature

  SignaturePosition({
    this.x = 100,
    this.y = 100,
    this.scale = 1.0,
    this.pageNumber = 1,
    required this.signatureId,
  });

  SignaturePosition copyWith({
    double? x,
    double? y,
    double? scale,
    int? pageNumber,
    String? signatureId,
  }) {
    return SignaturePosition(
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      pageNumber: pageNumber ?? this.pageNumber,
      signatureId: signatureId ?? this.signatureId,
    );
  }
}

class SignatureProvider extends ChangeNotifier {
  // Private variables
  File? _pdfFile;
  List<SignatureData> _signatures = [];
  SignatureData? _selectedSignature;
  List<SignaturePosition> _signaturePositions = [];
  SignaturePosition? _currentSignaturePosition;
  List<SignaturePosition> _previousPositions = [];
  bool _isLoading = false;
  bool _isDragging = false;
  int _currentPageNumber = 1;
  int _totalPages = 0;
  bool _showSignatureOverlay = false;

  // Animation controllers
  AnimationController? _fadeController;
  AnimationController? _scaleController;
  Animation<double>? _fadeAnimation;
  Animation<double>? _scaleAnimation;

  // PDF viewer controller
  PdfViewerController? _pdfViewerController;

  final ImagePicker _picker = ImagePicker();

  // Getters
  File? get pdfFile => _pdfFile;
  List<SignatureData> get signatures => _signatures;
  SignatureData? get selectedSignature => _selectedSignature;
  List<SignaturePosition> get signaturePositions => _signaturePositions;
  SignaturePosition? get currentSignaturePosition => _currentSignaturePosition;
  List<SignaturePosition> get previousPositions => _previousPositions;
  bool get isLoading => _isLoading;
  bool get isDragging => _isDragging;
  int get currentPageNumber => _currentPageNumber;
  int get totalPages => _totalPages;
  bool get showSignatureOverlay => _showSignatureOverlay;
  PdfViewerController? get pdfViewerController => _pdfViewerController;
  Animation<double>? get fadeAnimation => _fadeAnimation;
  Animation<double>? get scaleAnimation => _scaleAnimation;

  void initProvider(TickerProvider vsync) {
    _initAnimations(vsync);
    _initPdfController();
    loadStoredSignatures();
  }

  void _initAnimations(TickerProvider vsync) {
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: vsync,
    );

    _scaleController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: vsync,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController!, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController!, curve: Curves.elasticOut),
    );

    _fadeController!.forward();
  }

  void _initPdfController() {
    _pdfViewerController = PdfViewerController();
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    _scaleController?.dispose();
    super.dispose();
  }

  // Pick PDF file
  Future<void> pickPDF() async {
    try {
      _isLoading = true;
      notifyListeners();

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        _pdfFile = File(result.files.single.path!);
        _showSignatureOverlay = false;
        _scaleController?.forward();

        // Reset positions for new PDF
        _signaturePositions.clear();
        _currentSignaturePosition = null;
      }
    } catch (e) {
      print('Error picking PDF: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add signature from camera or gallery
  Future<void> addSignature({required ImageSource source}) async {
    try {
      _isLoading = true;
      notifyListeners();

      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final imageBytes = await image.readAsBytes();

      // Process image to make background fully transparent
      await processSignature(imageBytes);
    } catch (e) {
      print('Error adding signature: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Process and store signature with transparent background
  Future<void> processSignature(Uint8List imageBytes) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Create fully transparent background signature
      final processedBytes = await _createTransparentSignature(imageBytes);

      // Create signature data
      final signature = SignatureData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        imageData: processedBytes,
        name: 'Signature ${_signatures.length + 1}',
        createdAt: DateTime.now(),
      );

      _signatures.add(signature);
      await _saveSignatures();
    } catch (e) {
      print('Error processing signature: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create signature with fully transparent background
  Future<Uint8List> _createTransparentSignature(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Could not decode image');

      // Create new image with transparent background
      final newImage = img.Image(width: image.width, height: image.height);

      // Fill with fully transparent pixels
      img.fill(newImage, color: img.ColorRgba8(0, 0, 0, 0));

      // Process each pixel to create transparent background
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final int r = pixel.r.toInt();
          final int g = pixel.g.toInt();
          final int b = pixel.b.toInt();

          // Calculate brightness to determine if pixel should be transparent
          final double brightness = (r * 0.299 + g * 0.587 + b * 0.114);

          // More aggressive white/light background removal
          if (brightness > 200) {
            // Make light pixels transparent
            continue; // Skip setting pixel (remains transparent)
          } else if (brightness > 150) {
            // Semi-transparent for medium brightness
            final int alpha = (255 - (brightness - 150) * 2.55).round().clamp(
              0,
              255,
            );
            newImage.setPixel(x, y, img.ColorRgba8(r, g, b, alpha));
          } else {
            // Keep dark pixels (signature content) fully opaque
            newImage.setPixel(x, y, img.ColorRgba8(r, g, b, 255));
          }
        }
      }

      return Uint8List.fromList(img.encodePng(newImage));
    } catch (e) {
      print('Error creating transparent signature: $e');
      return imageBytes; // Return original if processing fails
    }
  }

  // Save signatures to local storage
  Future<void> _saveSignatures() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/signatures.json');

      final signaturesJson = _signatures.map((s) => s.toJson()).toList();
      await file.writeAsString(json.encode(signaturesJson));
    } catch (e) {
      print('Error saving signatures: $e');
    }
  }

  // Load stored signatures
  Future<void> loadStoredSignatures() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/signatures.json');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonString);

        _signatures = jsonList
            .map((json) => SignatureData.fromJson(json))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error loading signatures: $e');
    }
  }

  // Select signature for positioning
  void selectSignature(SignatureData signature) {
    _selectedSignature = signature;
    _showSignatureOverlay = true;
    _currentSignaturePosition = SignaturePosition(
      pageNumber: _currentPageNumber,
      signatureId: signature.id,
    );
    _previousPositions.clear();
    notifyListeners();
  }

  // Update signature position
  void updateSignaturePosition(double dx, double dy) {
    if (_selectedSignature == null || _currentSignaturePosition == null) return;

    // Store previous position for undo
    if (!_isDragging) {
      _previousPositions.add(_currentSignaturePosition!.copyWith());
    }

    _currentSignaturePosition!.x = dx;
    _currentSignaturePosition!.y = dy;
    notifyListeners();
  }

  // Undo last position change
  void undoPosition() {
    if (_previousPositions.isNotEmpty) {
      _currentSignaturePosition = _previousPositions.removeLast();
      notifyListeners();
    }
  }

  // Reset signature position
  void resetPosition() {
    if (_selectedSignature != null) {
      _currentSignaturePosition = SignaturePosition(
        pageNumber: _currentPageNumber,
        signatureId: _selectedSignature!.id,
      );
      _previousPositions.clear();
      notifyListeners();
    }
  }

  // Scale signature
  void scaleSignature(double scale) {
    if (_currentSignaturePosition != null) {
      _currentSignaturePosition!.scale = scale.clamp(0.1, 3.0);
      notifyListeners();
    }
  }

  // Place signature on current position
  void placeSignature() {
    if (_selectedSignature == null || _currentSignaturePosition == null) return;

    _signaturePositions.add(
      SignaturePosition(
        x: _currentSignaturePosition!.x,
        y: _currentSignaturePosition!.y,
        scale: _currentSignaturePosition!.scale,
        pageNumber: _currentPageNumber,
        signatureId: _selectedSignature!.id,
      ),
    );

    _showSignatureOverlay = false;
    _currentSignaturePosition = null;
    notifyListeners();
  }

  // Remove last placed signature
  void removeLastSignature() {
    if (_signaturePositions.isNotEmpty) {
      _signaturePositions.removeLast();
      notifyListeners();
    }
  }

  // Clear all placed signatures
  void clearAllSignatures() {
    _signaturePositions.clear();
    _showSignatureOverlay = false;
    notifyListeners();
  }

  // Save final PDF with signatures and custom filename
  Future<void> saveFinalPDF(String filename) async {
    if (_pdfFile == null || _signaturePositions.isEmpty) {
      return;
    }

    try {
      await Permission.storage.request();
      _isLoading = true;
      notifyListeners();

      // Load the original PDF
      final bytes = await _pdfFile!.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      // Add signatures to respective pages
      for (final signaturePos in _signaturePositions) {
        if (signaturePos.pageNumber <= document.pages.count) {
          // Find the signature data
          final signatureData = _signatures.firstWhere(
            (sig) => sig.id == signaturePos.signatureId,
            orElse: () => _signatures.first, // Fallback to first signature
          );

          final page = document.pages[signaturePos.pageNumber - 1];
          final graphics = page.graphics;

          // Create bitmap from signature
          final signatureImage = PdfBitmap(signatureData.imageData);

          // Calculate size based on scale
          final width = 120 * signaturePos.scale;
          final height = 60 * signaturePos.scale;

          // Draw signature on page with transparency support
          graphics.drawImage(
            signatureImage,
            Rect.fromLTWH(signaturePos.x, signaturePos.y, width, height),
          );
        }
      }

      // Save to device with custom filename
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      // Ensure filename ends with .pdf
      final pdfFilename = filename.endsWith('.pdf')
          ? filename
          : '$filename.pdf';
      final outputFile = File('${directory.path}/$pdfFilename');

      final savedBytes = await document.save();
      await outputFile.writeAsBytes(savedBytes);

      document.dispose();

      // Show success message
      print('PDF saved successfully to: ${outputFile.path}');
    } catch (e) {
      print('Error saving PDF: $e');
      throw e; // Re-throw to handle in UI
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete signature
  void deleteSignature(SignatureData signature) {
    _signatures.remove(signature);
    if (_selectedSignature?.id == signature.id) {
      _selectedSignature = null;
      _showSignatureOverlay = false;
    }
    // Also remove any placed signatures with this ID
    _signaturePositions.removeWhere((pos) => pos.signatureId == signature.id);
    _saveSignatures();
    notifyListeners();
  }

  // Update signature (for editing)
  void updateSignature(
    String signatureId, {
    Uint8List? imageData,
    double? rotation,
  }) {
    final index = _signatures.indexWhere((s) => s.id == signatureId);
    if (index != -1) {
      final oldSignature = _signatures[index];
      _signatures[index] = SignatureData(
        id: oldSignature.id,
        name: oldSignature.name,
        imageData: imageData ?? oldSignature.imageData,
        createdAt: oldSignature.createdAt,
        rotation: rotation ?? oldSignature.rotation,
      );
      _saveSignatures();
      notifyListeners();
    }
  }

  // Update current page number
  void updatePageNumber(int pageNumber) {
    _currentPageNumber = pageNumber;
    notifyListeners();
  }

  // Update total pages
  void updateTotalPages(int total) {
    _totalPages = total;
    notifyListeners();
  }

  void setDragging(bool dragging) {
    _isDragging = dragging;
    notifyListeners();
  }

  void setShowSignatureOverlay(bool show) {
    _showSignatureOverlay = show;
    if (!show) {
      _currentSignaturePosition = null;
    }
    notifyListeners();
  }
}

class SignatureApp extends StatefulWidget {
  @override
  _SignatureAppState createState() => _SignatureAppState();
}

class _SignatureAppState extends State<SignatureApp>
    with TickerProviderStateMixin {
  late SignatureProvider _signatureProvider;

  @override
  void initState() {
    super.initState();
    _signatureProvider = SignatureProvider();
    _signatureProvider.initProvider(this);
  }

  @override
  void dispose() {
    _signatureProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _signatureProvider,
      child: Scaffold(
        appBar: AppBar(
          title: Text('PDF Signature App'),
          backgroundColor: Colors.blue[700],
          elevation: 0,
          actions: [
            Consumer<SignatureProvider>(
              builder: (context, provider, child) {
                return provider.pdfFile != null
                    ? IconButton(
                        onPressed: () => _showPDFActions(provider),
                        icon: Icon(Icons.more_vert),
                      )
                    : SizedBox.shrink();
              },
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue[700]!, Colors.blue[50]!],
            ),
          ),
          child: Consumer<SignatureProvider>(
            builder: (context, provider, child) {
              return provider.isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Processing...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    )
                  : provider.pdfFile == null
                  ? _buildWelcomeScreen(provider)
                  : _buildPDFView(provider);
            },
          ),
        ),
        floatingActionButton: Consumer<SignatureProvider>(
          builder: (context, provider, child) {
            return provider.pdfFile != null
                ? FloatingActionButton.extended(
                    onPressed: provider.showSignatureOverlay
                        ? provider.placeSignature
                        : () => _showAddSignatureDialog(provider),
                    icon: Icon(
                      provider.showSignatureOverlay ? Icons.check : Icons.add,
                    ),
                    label: Text(
                      provider.showSignatureOverlay ? 'Place' : 'Add Signature',
                    ),
                    backgroundColor: provider.showSignatureOverlay
                        ? Colors.green
                        : Colors.blue,
                  )
                : SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildWelcomeScreen(SignatureProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf, size: 100, color: Colors.white),
          SizedBox(height: 24),
          Text(
            'PDF Signature App',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Pick a PDF and add your signature',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: provider.pickPDF,
            icon: Icon(Icons.upload_file),
            label: Text('Pick PDF File'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showAddSignatureDialog(provider),
            icon: Icon(Icons.add),
            label: Text('Manage Signatures'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
          SizedBox(height: 20),
          provider.signatures.isNotEmpty
              ? Container(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.signatures.length,
                    itemBuilder: (context, index) {
                      final signature = provider.signatures[index];
                      return Container(
                        margin: EdgeInsets.only(right: 12),
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors
                                .white, // White background to show transparency
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Image.memory(
                            signature.imageData,
                            width: 80,
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  ),
                )
              : SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildPDFView(SignatureProvider provider) {
    return Column(
      children: [
        // Page info
        Container(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Page ${provider.currentPageNumber} of ${provider.totalPages}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Signatures: ${provider.signaturePositions.length}',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),

        // PDF viewer with signature overlay
        Expanded(
          child: Stack(
            children: [
              // PDF viewer
              Container(
                margin: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SfPdfViewer.file(
                    provider.pdfFile!,
                    controller: provider.pdfViewerController,
                    onPageChanged: (PdfPageChangedDetails details) {
                      provider.updatePageNumber(details.newPageNumber);
                    },
                    onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                      provider.updateTotalPages(details.document.pages.count);
                    },
                  ),
                ),
              ),

              // Signature overlay for positioning
              provider.showSignatureOverlay &&
                      provider.selectedSignature != null &&
                      provider.currentSignaturePosition != null
                  ? Positioned(
                      left: provider.currentSignaturePosition!.x + 16,
                      top: provider.currentSignaturePosition!.y + 16,
                      child: GestureDetector(
                        onPanStart: (_) => provider.setDragging(true),
                        onPanEnd: (_) => provider.setDragging(false),
                        onPanUpdate: (details) {
                          provider.updateSignaturePosition(
                            provider.currentSignaturePosition!.x +
                                details.delta.dx,
                            provider.currentSignaturePosition!.y +
                                details.delta.dy,
                          );
                        },
                        child: Transform.scale(
                          scale: provider.currentSignaturePosition!.scale,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red, width: 2),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                            child: Image.memory(
                              provider.selectedSignature!.imageData,
                              width: 150,
                              height: 75,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    )
                  : SizedBox.shrink(),
            ],
          ),
        ),

        // Control panel
        _buildControlPanel(provider),
      ],
    );
  }

  Widget _buildControlPanel(SignatureProvider provider) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Signature selection
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...provider.signatures.map(
                  (signature) => GestureDetector(
                    onTap: () async {
                      // Open View Signature screen
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ViewSignatureScreen(
                            signatureId: signature.id,
                            signatureName: signature.name,
                            imageData: signature.imageData,
                            rotation: signature.rotation,
                            createdAt: signature.createdAt,
                          ),
                        ),
                      );

                      // If signature was edited, update it
                      if (result != null && result is Map<String, dynamic>) {
                        final signatureId = result['signatureId'] as String;
                        final editResult =
                            result['result'] as Map<String, dynamic>;
                        provider.updateSignature(
                          signatureId,
                          imageData: editResult['imageData'] as Uint8List?,
                          rotation: editResult['rotation'] as double?,
                        );
                      }
                    },
                    onLongPress: () {
                      // Select signature on long press
                      provider.selectSignature(signature);
                    },
                    child: Container(
                      margin: EdgeInsets.only(right: 12),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: provider.selectedSignature?.id == signature.id
                              ? Colors.blue
                              : Colors.grey,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: Column(
                        children: [
                          Transform.rotate(
                            angle: signature.rotation * 3.14159 / 180,
                            child: Image.memory(
                              signature.imageData,
                              width: 80,
                              height: 40,
                              fit: BoxFit.contain,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(signature.name, style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Scale slider (only when positioning)
          provider.showSignatureOverlay &&
                  provider.currentSignaturePosition != null
              ? Column(
                  children: [
                    Text(
                      'Scale: ${provider.currentSignaturePosition!.scale.toStringAsFixed(1)}',
                    ),
                    Slider(
                      value: provider.currentSignaturePosition!.scale,
                      onChanged: provider.scaleSignature,
                      min: 0.1,
                      max: 3.0,
                      divisions: 29,
                    ),
                    SizedBox(height: 16),
                  ],
                )
              : SizedBox.shrink(),

          // Action buttons
          provider.showSignatureOverlay
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: provider.previousPositions.isNotEmpty
                          ? provider.undoPosition
                          : null,
                      icon: Icon(Icons.undo),
                      label: Text('Undo'),
                    ),
                    ElevatedButton.icon(
                      onPressed: provider.resetPosition,
                      icon: Icon(Icons.refresh),
                      label: Text('Reset'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => provider.setShowSignatureOverlay(false),
                      icon: Icon(Icons.close),
                      label: Text('Cancel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: provider.signaturePositions.isNotEmpty
                          ? provider.removeLastSignature
                          : null,
                      icon: Icon(Icons.remove),
                      label: Text('Remove'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: provider.signaturePositions.isNotEmpty
                          ? () => _showSaveDialog(provider)
                          : null,
                      icon: Icon(Icons.save),
                      label: Text('Save PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  void _showSaveDialog(SignatureProvider provider) {
    final TextEditingController filenameController = TextEditingController();
    filenameController.text =
        'signed_document_${DateTime.now().millisecondsSinceEpoch}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Save PDF'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter filename for the signed PDF:'),
            SizedBox(height: 16),
            TextField(
              controller: filenameController,
              decoration: InputDecoration(
                labelText: 'Filename',
                suffixText: '.pdf',
                border: OutlineInputBorder(),
                hintText: 'Enter filename without extension',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final filename = filenameController.text.trim();
              if (filename.isNotEmpty) {
                Navigator.pop(context);
                try {
                  await provider.saveFinalPDF(filename);
                  _showSuccessDialog('PDF saved successfully!');
                } catch (e) {
                  _showErrorDialog('Failed to save PDF: $e');
                }
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Success'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAddSignatureDialog(SignatureProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Signature Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                provider.addSignature(source: ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                provider.addSignature(source: ImageSource.gallery);
              },
            ),
            if (provider.signatures.isNotEmpty) Divider(),
            if (provider.signatures.isNotEmpty)
              ListTile(
                leading: Icon(Icons.list),
                title: Text('Manage Signatures'),
                onTap: () {
                  Navigator.pop(context);
                  _showSignatureManager(provider);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showSignatureManager(SignatureProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage Signatures'),
        content: Container(
          width: double.maxFinite,
          child: provider.signatures.isEmpty
              ? Text('No signatures available')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: provider.signatures.length,
                  itemBuilder: (context, index) {
                    final signature = provider.signatures[index];
                    return ListTile(
                      leading: Container(
                        width: 50,
                        height: 25,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Image.memory(
                          signature.imageData,
                          width: 50,
                          height: 25,
                          fit: BoxFit.contain,
                        ),
                      ),
                      title: Text(signature.name),
                      subtitle: Text(
                        signature.createdAt.toString().split('.')[0],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _showDeleteConfirmDialog(provider, signature),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(
    SignatureProvider provider,
    SignatureData signature,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Signature'),
        content: Text('Are you sure you want to delete "${signature.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              provider.deleteSignature(signature);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showPDFActions(SignatureProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('PDF Actions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.clear_all),
              title: Text('Clear All Signatures'),
              onTap: () {
                Navigator.pop(context);
                _showClearAllConfirmDialog(provider);
              },
            ),
            ListTile(
              leading: Icon(Icons.refresh),
              title: Text('Load New PDF'),
              onTap: () {
                Navigator.pop(context);
                provider.pickPDF();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearAllConfirmDialog(SignatureProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All Signatures'),
        content: Text(
          'Are you sure you want to remove all placed signatures from the PDF?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              provider.clearAllSignatures();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class CropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final Function(Uint8List) onCropped;

  const CropScreen({
    Key? key,
    required this.imageBytes,
    required this.onCropped,
  }) : super(key: key);

  @override
  _CropScreenState createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final _cropController = CropController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Crop Signature'),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            onPressed: () {
              _cropController.crop();
            },
            icon: Icon(Icons.check),
            tooltip: 'Crop and Save',
          ),
        ],
      ),
      body: Container(
        color: Colors.black,
        child: Crop(
          image: widget.imageBytes,
          controller: _cropController,
          onCropped: (croppedData) {
            widget.onCropped(croppedData);
            Navigator.pop(context);
          },
          withCircleUi: false,
          baseColor: Colors.blue.withValues(alpha: 0.8),
          maskColor: Colors.white.withValues(alpha: 0.3),
          radius: 20,
          onStatusChanged: (status) {
            // Handle crop status changes if needed
          },
          willUpdateScale: (newScale) {
            // Handle scale updates if needed
            return newScale < 5;
          },
          cornerDotBuilder: (size, edgeAlignment) =>
              const DotControl(color: Colors.blue),
          clipBehavior: Clip.none,
          interactive: true,
          fixCropRect: false,
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        color: Colors.blue[700],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Adjust the crop area to include only your signature',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Tap the check mark when ready',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class DotControl extends StatelessWidget {
  const DotControl({Key? key, this.color = Colors.white, this.padding = 8})
    : super(key: key);

  final Color color;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blue, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}
