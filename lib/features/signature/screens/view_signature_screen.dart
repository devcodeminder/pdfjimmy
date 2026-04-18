import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'signature_editor_screen.dart';

class ViewSignatureScreen extends StatelessWidget {
  final String signatureId;
  final String signatureName;
  final Uint8List imageData;
  final double rotation;
  final DateTime createdAt;

  const ViewSignatureScreen({
    super.key,
    required this.signatureId,
    required this.signatureName,
    required this.imageData,
    required this.rotation,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(signatureName),
        backgroundColor: Colors.blue[700],
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: Column(
          children: [
            // Signature preview area
            Expanded(
              child: Center(
                child: Container(
                  margin: EdgeInsets.all(24),
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Transform.rotate(
                    angle: rotation * 3.14159 / 180,
                    child: Image.memory(imageData, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),

            // Signature info
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey.shade600),
                      SizedBox(width: 8),
                      Text(
                        'Signature Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildInfoRow(Icons.label_outline, 'Name', signatureName),
                  SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.rotate_right,
                    'Rotation',
                    '${rotation.toInt()}°',
                  ),
                  SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Created',
                    _formatDate(createdAt),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to signature editor
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SignatureEditorScreen(
                imageData: imageData,
                signatureName: signatureName,
                currentRotation: rotation,
              ),
            ),
          );

          // Return the result back to the previous screen
          if (result != null && context.mounted) {
            Navigator.pop(context, {
              'signatureId': signatureId,
              'result': result,
            });
          }
        },
        icon: Icon(Icons.edit),
        label: Text('Edit'),
        backgroundColor: Colors.blue,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
