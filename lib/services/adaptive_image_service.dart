import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'platform_capabilities.dart';

/// Opens the most natural image-picking flow for the current platform.
abstract final class AdaptiveImageService {
  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> pickForUser(
    BuildContext context, {
    String sheetTitle = 'Select image',
    String galleryLabel = 'Choose from gallery',
    String cameraLabel = 'Take a photo',
    int imageQuality = 80,
  }) async {
    if (!PlatformCapabilities.supportsCameraCapture) {
      return _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: imageQuality,
      );
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sheetTitle,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(galleryLabel),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(cameraLabel),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return null;
    return pickDirect(source, imageQuality: imageQuality);
  }

  static Future<XFile?> pickDirect(
    ImageSource source, {
    int imageQuality = 80,
  }) {
    final effectiveSource = source == ImageSource.camera &&
            !PlatformCapabilities.supportsCameraCapture
        ? ImageSource.gallery
        : source;

    return _picker.pickImage(
      source: effectiveSource,
      imageQuality: imageQuality,
    );
  }
}
