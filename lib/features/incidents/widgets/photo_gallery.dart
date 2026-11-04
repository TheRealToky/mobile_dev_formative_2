import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Horizontally swipeable photo strip; tapping a photo opens it full screen.
class PhotoGallery extends StatelessWidget {
  const PhotoGallery({super.key, required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
        itemBuilder: (context, i) => Semantics(
          button: true,
          label: 'Photo ${i + 1} of ${urls.length}, open full screen',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => FullScreenPhotos(urls: urls, initialIndex: i),
              ),
            ),
            child: Hero(
              tag: urls[i],
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.card),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: _NetworkPhoto(url: urls[i], fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen, swipeable, pinch-to-zoom photo viewer.
class FullScreenPhotos extends StatelessWidget {
  const FullScreenPhotos({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${urls.length} photo${urls.length == 1 ? '' : 's'}'),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: urls.length,
        itemBuilder: (context, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: Hero(
              tag: urls[i],
              child: _NetworkPhoto(url: urls[i], fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

class _NetworkPhoto extends StatelessWidget {
  const _NetworkPhoto({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : ColoredBox(
              color: muted,
              child: const Center(child: CircularProgressIndicator()),
            ),
      errorBuilder: (_, _, _) => ColoredBox(
        color: muted,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}
