import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:opennutritracker/core/utils/food_image_storage.dart';
import 'package:opennutritracker/core/utils/locator.dart';

/// Displays an image from either a local file path or a network URL.
/// Falls back to [placeholder] when [imageUrl] is null.
class FoodImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const FoodImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _fallback(context);
    }

    if (FoodImageStorage.isLocalPath(imageUrl)) {
      final file = File(imageUrl!);
      if (!file.existsSync()) {
        debugPrint('FoodImage: file not found: $imageUrl');
        return errorWidget ?? _fallback(context);
      }
      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stack) {
          debugPrint('FoodImage: render error for $imageUrl: $error');
          return errorWidget ?? _fallback(context);
        },
      );
    }

    return CachedNetworkImage(
      cacheManager: locator<CacheManager>(),
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? _fallback(context),
      errorWidget: (context, url, error) =>
          errorWidget ?? _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    return placeholder ??
        SizedBox(
          width: width,
          height: height,
          child: Center(
            child: Icon(Icons.restaurant_outlined,
                color: Theme.of(context).colorScheme.secondary),
          ),
        );
  }
}
