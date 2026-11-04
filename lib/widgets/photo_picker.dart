import 'dart:io';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/constants.dart';
import '../data/models/report_draft.dart';

/// Up to [max] photo thumbnails with a remove button each, plus an add tile
/// that asks for camera or gallery.
///
/// Stateless: the list lives in the form; this widget reports [onAdd] and
/// [onRemove]. Not previewable in the web-based widget previewer because it
/// shows local files with `dart:io`.
class PhotoPicker extends StatelessWidget {
  const PhotoPicker({
    super.key,
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    this.max = Limits.maxPhotos,
    this.enabled = true,
  });

  final List<DraftPhoto> photos;
  final void Function({required bool fromCamera}) onAdd;
  final ValueChanged<int> onRemove;
  final int max;
  final bool enabled;

  static const _tile = 96.0;

  Future<void> _chooseSource(BuildContext context) async {
    final fromCamera = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (fromCamera != null) onAdd(fromCamera: fromCamera);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canAdd = enabled && photos.length < max;

    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        for (var i = 0; i < photos.length; i++)
          _Thumbnail(
            photo: photos[i],
            size: _tile,
            index: i,
            onRemove: enabled ? () => onRemove(i) : null,
          ),
        if (canAdd)
          Semantics(
            button: true,
            label: 'Add photo, ${photos.length} of $max added',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => _chooseSource(context),
              borderRadius: BorderRadius.circular(Radii.card),
              child: Container(
                width: _tile,
                height: _tile,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.card),
                  border: Border.all(color: scheme.outline),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: scheme.primary),
                    const SizedBox(height: Gap.xs),
                    Text(
                      '${photos.length}/$max',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.photo,
    required this.size,
    required this.index,
    this.onRemove,
  });

  final DraftPhoto photo;
  final double size;
  final int index;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final image = switch (photo) {
      LocalPhoto(:final path) => Image.file(
        File(path),
        fit: BoxFit.cover,
        cacheWidth: 300,
      ),
      RemotePhoto(:final url) => Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: 300,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      ),
    };

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.card),
          child: SizedBox.square(dimension: size, child: image),
        ),
        if (onRemove != null)
          Positioned(
            top: 0,
            right: 0,
            child: IconButton.filledTonal(
              tooltip: 'Remove photo ${index + 1}',
              iconSize: 18,
              icon: const Icon(Icons.close),
              onPressed: onRemove,
            ),
          ),
      ],
    );
  }
}
