import 'package:flutter/material.dart';
import 'package:pdfjimmy/models/signature_placement_model.dart';
import 'package:pdfjimmy/models/signature_data.dart';

/// Widget for displaying and manipulating a placed signature
class PlacedSignatureWidget extends StatefulWidget {
  final SignaturePlacement placement;
  final SignatureData signatureData;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(SignaturePlacement) onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onConfirm;
  final double scrollOffset;

  const PlacedSignatureWidget({
    Key? key,
    required this.placement,
    required this.signatureData,
    required this.isSelected,
    required this.onTap,
    required this.onUpdate,
    required this.onDelete,
    required this.onConfirm,
    this.scrollOffset = 0.0,
  }) : super(key: key);

  @override
  State<PlacedSignatureWidget> createState() => _PlacedSignatureWidgetState();
}

class _PlacedSignatureWidgetState extends State<PlacedSignatureWidget> {
  late Offset _position;
  late double _scale;
  late double _rotation;

  @override
  void initState() {
    super.initState();
    _position = widget.placement.position;
    _scale = widget.placement.scale;
    _rotation = widget.placement.rotation;
  }

  @override
  Widget build(BuildContext context) {
    // Only add hit-test padding when selected (to support floating buttons).
    // When unselected, we want precise tapping on the signature itself.
    final double hitTestPadding = widget.isSelected ? 60.0 : 0.0;

    // Helper to adjust control positions based on padding
    double adjust(double val) => val + hitTestPadding;

    // Calculate screen position: Document Position - Scroll Offset
    final double renderTop = _position.dy - widget.scrollOffset;

    return Positioned(
      // Shift the whole widget so the "Image" stays securely in place
      left: _position.dx - hitTestPadding,
      top: renderTop - hitTestPadding,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanUpdate: widget.isSelected ? _onPanUpdate : null,
        child: Transform.rotate(
          angle: _rotation,
          child: Transform.scale(
            scale: _scale,
            // The Container here is transparent, just holding the Stack
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. The Signature Image (Centered via Padding)
                // We wrap the image in padding so the Stack expands to include this 'safe area'
                Padding(
                  padding: EdgeInsets.all(hitTestPadding),
                  child: Container(
                    decoration: BoxDecoration(
                      border: widget.isSelected
                          ? Border.all(color: Colors.orange, width: 2)
                          : null,
                    ),
                    child: Image.memory(
                      widget.signatureData.imageData,
                      width: 150,
                      height: 75,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // 2. Control handles (only when selected)
                if (widget.isSelected) ...[
                  // Cancel / Delete (Top Left Corner)
                  Positioned(
                    top: adjust(-25),
                    left: adjust(-25),
                    child: GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  // Confirm / Done (Bottom Center)
                  Positioned(
                    bottom: adjust(
                      -60,
                    ), // Effectively 0 relative to stack bottom if padding is 60
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: widget.onConfirm,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Resize handles (Corners)
                  // Bottom Right
                  Positioned(
                    bottom: adjust(-10),
                    right: adjust(-10),
                    child: GestureDetector(
                      onPanUpdate: _onResizeUpdate,
                      child: _buildHandle(Icons.zoom_out_map, Colors.blue),
                    ),
                  ),
                  // Top Right
                  Positioned(
                    top: adjust(-10),
                    right: adjust(-10),
                    child: GestureDetector(
                      onPanUpdate: _onResizeUpdate,
                      child: _buildHandle(Icons.zoom_out_map, Colors.blue),
                    ),
                  ),
                  // Bottom Left
                  Positioned(
                    bottom: adjust(-10),
                    left: adjust(-10),
                    child: GestureDetector(
                      onPanUpdate: _onResizeUpdate,
                      child: _buildHandle(Icons.zoom_out_map, Colors.blue),
                    ),
                  ),

                  // Rotate handle (Top Center)
                  Positioned(
                    top: adjust(-30),
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onPanUpdate: _onRotateUpdate,
                        child: _buildHandle(Icons.rotate_right, Colors.green),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _position += details.delta;
    });
    _updatePlacement();
  }

  void _onResizeUpdate(DragUpdateDetails details) {
    setState(() {
      // Simple scaling based on drag distance
      final delta = details.delta.dx + details.delta.dy;
      _scale = (_scale + delta * 0.01).clamp(0.3, 3.0);
    });
    _updatePlacement();
  }

  void _onRotateUpdate(DragUpdateDetails details) {
    setState(() {
      // Rotate based on drag
      _rotation += details.delta.dx * 0.01;
    });
    _updatePlacement();
  }

  void _updatePlacement() {
    widget.onUpdate(
      widget.placement.copyWith(
        position: _position,
        scale: _scale,
        rotation: _rotation,
      ),
    );
  }
}

/// Overlay for managing signature placements on a PDF page
class SignatureOverlay extends StatelessWidget {
  final int pageNumber;
  final List<SignaturePlacement> placements;
  final Map<String, SignatureData> signaturesMap;
  final int? selectedPlacementId;
  final Function(int) onSignatureSelected;
  final Function(SignaturePlacement) onPlacementUpdate;
  final Function(int) onPlacementDelete;
  final VoidCallback? onConfirmSelection;
  final double scrollOffset;

  const SignatureOverlay({
    Key? key,
    required this.pageNumber,
    required this.placements,
    required this.signaturesMap,
    this.selectedPlacementId,
    required this.onSignatureSelected,
    required this.onPlacementUpdate,
    required this.onPlacementDelete,
    this.onConfirmSelection,
    this.scrollOffset = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final pagePlacements = placements
        .where((p) => p.pageNumber == pageNumber)
        .toList();

    return Stack(
      children: pagePlacements.map((placement) {
        final signatureData = signaturesMap[placement.signatureId];
        if (signatureData == null) return const SizedBox.shrink();

        return PlacedSignatureWidget(
          placement: placement,
          signatureData: signatureData,
          scrollOffset: scrollOffset, // Pass scroll offset
          isSelected: selectedPlacementId == placement.id,
          onTap: () {
            if (placement.id != null) {
              onSignatureSelected(placement.id!);
            }
          },
          onUpdate: onPlacementUpdate,
          onConfirm: () {
            if (onConfirmSelection != null) onConfirmSelection!();
          },
          onDelete: () {
            if (placement.id != null) {
              onPlacementDelete(placement.id!);
            }
          },
        );
      }).toList(),
    );
  }
}
