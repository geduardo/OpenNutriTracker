import 'package:opennutritracker/core/presentation/widgets/app_text.dart';
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
            title: const AppText('Take photo'),
            onTap: () => Navigator.pop(ctx, ImageEditAction.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const AppText('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageEditAction.gallery),
          ),
          if (hasImage)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const AppText('Remove image'),
              onTap: () => Navigator.pop(ctx, ImageEditAction.remove),
            ),
        ],
      ),
    ),
  );
}
