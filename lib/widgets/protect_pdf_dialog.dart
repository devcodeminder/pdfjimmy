import 'package:flutter/material.dart';

/// Dialog for protecting PDF with password and custom filename
class ProtectPdfDialog extends StatefulWidget {
  final String currentFileName;
  final bool isAlreadyProtected;
  final Function(
    String newPassword,
    String? currentPassword,
    String newFileName,
  )
  onProtect;
  final Function(String currentPassword)? onRemove;
  final VoidCallback? onCancel;

  const ProtectPdfDialog({
    Key? key,
    required this.currentFileName,
    required this.onProtect,
    this.isAlreadyProtected = false,
    this.onRemove,
    this.onCancel,
  }) : super(key: key);

  @override
  State<ProtectPdfDialog> createState() => _ProtectPdfDialogState();
}

class _ProtectPdfDialogState extends State<ProtectPdfDialog> {
  // ... existing controllers ...
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    String defaultName = widget.currentFileName
        .replaceAll('.pdf', '')
        .replaceAll('_protected', '');
    _fileNameController.text = '${defaultName}_protected';
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  void _handleRemove() {
    setState(() {
      _errorMessage = null;
    });

    if (_currentPasswordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter current password to remove protection';
      });
      return;
    }

    if (widget.onRemove != null) {
      widget.onRemove!(_currentPasswordController.text);
    }
  }

  void _handleProtect() {
    // ... existing handleProtect ...
    setState(() {
      _errorMessage = null;
    });

    // Validate current password if PDF is already protected (Change Password)
    if (widget.isAlreadyProtected && _currentPasswordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter current password';
      });
      return;
    }

    // Validate new password
    if (_newPasswordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter new password';
      });
      return;
    }

    if (_newPasswordController.text.length < 4) {
      setState(() {
        _errorMessage = 'Password must be at least 4 characters';
      });
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    if (_fileNameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a file name';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String? currentPassword = widget.isAlreadyProtected
        ? _currentPasswordController.text
        : null;

    widget.onProtect(
      _newPasswordController.text,
      currentPassword,
      _fileNameController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... existing build ...
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        // ... decoration ...
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 800),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1E1E1E), const Color(0xFF2D2D2D)]
                : [Colors.white, const Color(0xFFF8F9FD)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6D00).withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6D00), Color(0xFFFF8F00)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isAlreadyProtected
                            ? Icons.lock_open
                            : Icons.shield_outlined,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.isAlreadyProtected
                          ? 'Manage Protection'
                          : 'Protect PDF',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.isAlreadyProtected
                          ? 'Change password or remove protection'
                          : 'Add password protection to your PDF',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ... existing fields ...
                    // Current file name display (same as before)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : const Color(0xFFFF6D00).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.picture_as_pdf,
                            color: Color(0xFFFF6D00),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.currentFileName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Current password
                    if (widget.isAlreadyProtected) ...[
                      Text(
                        'Current Password',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _currentPasswordController,
                        obscureText: _obscureCurrentPassword,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: 'Enter current password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureCurrentPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureCurrentPassword =
                                    !_obscureCurrentPassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // New Password Fields ...
                    Text(
                      'New Password',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ... (TextFields for new/confirm password - keeping existing structure via tool)
                    TextField(
                      controller: _newPasswordController,
                      obscureText: _obscureNewPassword,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'Enter new password',
                        prefixIcon: const Icon(Icons.vpn_key),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscureNewPassword = !_obscureNewPassword,
                          ),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Confirm Password',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'Re-enter new password',
                        prefixIcon: const Icon(Icons.check_circle_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // File name
                    Text(
                      'Save As',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _fileNameController,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'Enter file name',
                        prefixIcon: const Icon(Icons.drive_file_rename_outline),
                        suffixText: '.pdf',
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    // Error message ...
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Remove button if protected
                    if (widget.isAlreadyProtected && !_isLoading) ...[
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _handleRemove,
                          icon: const Icon(Icons.lock_open, color: Colors.red),
                          label: const Text(
                            'Remove Password Protection',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    if (widget.onCancel != null) {
                                      widget.onCancel!();
                                    } else {
                                      Navigator.of(context).pop(null);
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(
                                color: Colors.grey.withOpacity(0.3),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleProtect,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6D00),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        widget.isAlreadyProtected
                                            ? Icons.save
                                            : Icons.shield,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        widget.isAlreadyProtected
                                            ? 'Update Password'
                                            : 'Protect PDF',
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Show protect PDF dialog
Future<Map<String, dynamic>?> showProtectPdfDialog({
  required BuildContext context,
  required String currentFileName,
  bool isAlreadyProtected = false,
}) async {
  return await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return ProtectPdfDialog(
        currentFileName: currentFileName,
        isAlreadyProtected: isAlreadyProtected,
        onProtect: (newPassword, currentPassword, newFileName) {
          Navigator.of(context).pop({
            'action': 'protect',
            'newPassword': newPassword,
            'currentPassword': currentPassword,
            'newFileName': newFileName,
          });
        },
        onRemove: (currentPassword) {
          Navigator.of(
            context,
          ).pop({'action': 'remove', 'currentPassword': currentPassword});
        },
        onCancel: () {
          Navigator.of(context).pop(null);
        },
      );
    },
  );
}
