import 'package:flutter/material.dart';

enum ImageEditAction { camera, gallery, remove }

Future<ImageEditAction?> showImageEditActionSheet(
  BuildContext context, {
  required bool hasImage,
}) {
  return showModalBottomSheet<ImageEditAction>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(ctx, ImageEditAction.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageEditAction.gallery),
          ),
          if (hasImage)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove image'),
              onTap: () => Navigator.pop(ctx, ImageEditAction.remove),
            ),
        ],
      ),
    ),
  );
}
