import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Renders a locally picked image or falls back to a network URL.
///
/// Local previews use bytes instead of `Image.file`, which keeps the widget
/// compatible with Flutter Web.
class AdaptiveImagePreview extends StatefulWidget {
  const AdaptiveImagePreview({
    super.key,
    this.pickedImage,
    this.imageUrl = '',
    required this.placeholder,
    this.loadingPlaceholder,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final XFile? pickedImage;
  final String imageUrl;
  final Widget placeholder;
  final Widget? loadingPlaceholder;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  State<AdaptiveImagePreview> createState() => _AdaptiveImagePreviewState();
}

class _AdaptiveImagePreviewState extends State<AdaptiveImagePreview> {
  Uint8List? _bytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPickedImage();
  }

  @override
  void didUpdateWidget(covariant AdaptiveImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickedImage != widget.pickedImage ||
        oldWidget.pickedImage?.path != widget.pickedImage?.path) {
      _loadPickedImage();
    }
  }

  Future<void> _loadPickedImage() async {
    final pickedImage = widget.pickedImage;
    if (pickedImage == null) {
      if (_bytes != null || _isLoading) {
        setState(() {
          _bytes = null;
          _isLoading = false;
        });
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final bytes = await pickedImage.readAsBytes();
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bytes = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localBytes = _bytes;
    if (widget.pickedImage != null) {
      if (_isLoading && localBytes == null) {
        return widget.loadingPlaceholder ??
            const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }

      if (localBytes != null && localBytes.isNotEmpty) {
        return Image.memory(
          localBytes,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => widget.placeholder,
        );
      }
    }

    if (widget.imageUrl.trim().isNotEmpty) {
      return Image.network(
        widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => widget.placeholder,
      );
    }

    return widget.placeholder;
  }
}
