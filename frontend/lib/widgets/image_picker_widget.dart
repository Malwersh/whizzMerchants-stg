import 'package:flutter/material.dart';
import '../core/theme/whizz_colors.dart';
import 'dart:io';

class ImagePickerWidget extends StatelessWidget {
  final File? selectedImage;
  final String? uploadedImageUrl;
  final bool isUploading;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;

  const ImagePickerWidget({
    super.key,
    required this.selectedImage,
    this.uploadedImageUrl,
    required this.isUploading,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Image (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        _buildImagePreview(context),
        const SizedBox(height: 12),
        _buildImageButtons(context),
      ],
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    return Center(
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: WhizzColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: WhizzColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (selectedImage != null)
                Image.file(
                  selectedImage!,
                  fit: BoxFit.cover,
                )
              else if (uploadedImageUrl != null)
                Image.network(
                  uploadedImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildPlaceholderIcon(),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                )
              else
                _buildPlaceholderIcon(),
              if (isUploading)
                Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Icon(
      Icons.image,
      size: 64,
      color: WhizzColors.onSurfaceVariant,
    );
  }

  Widget _buildImageButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: isUploading ? null : onPickImage,
          icon: const Icon(Icons.add_a_photo),
          label: const Text('Select Image'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Theme.of(context).primaryColor,
            backgroundColor: Colors.white,
            side: BorderSide(color: Theme.of(context).primaryColor),
          ),
        ),
        if (selectedImage != null || uploadedImageUrl != null) ...[
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: isUploading ? null : onRemoveImage,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove'),
            style: ElevatedButton.styleFrom(
              foregroundColor: WhizzColors.error,
              backgroundColor: WhizzColors.surface,
              side: BorderSide(color: WhizzColors.error),
            ),
          ),
        ],
      ],
    );
  }
}
