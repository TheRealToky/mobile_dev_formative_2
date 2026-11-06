import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/photo_repository.dart';
import '../providers/report_controller.dart';

/// JPEG bytes of one photo, by reference. Kept for a few minutes after the
/// last widget showing it goes away, so going back and forth between the
/// feed and a report does not download the same photo again.
final photoBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, photoRef) async {
      final bytes = await ref
          .watch(photoRepositoryProvider)
          .loadPhoto(photoRef);
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 5), link.close);
      ref.onDispose(timer.cancel);
      return bytes;
    });

/// Shows an incident photo from its reference: a Firestore photo document
/// (current) or an `https://` URL (reports made while photos were in Cloud
/// Storage). Shows a spinner while loading and an icon if it is missing.
class IncidentPhoto extends ConsumerWidget {
  const IncidentPhoto({
    super.key,
    required this.photoRef,
    this.fit = BoxFit.cover,
    this.cacheWidth,
  });

  final String photoRef;
  final BoxFit fit;

  /// Decode width in physical pixels, to save memory for thumbnails.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget placeholder(Widget child) => ColoredBox(
      color: muted,
      child: Center(child: child),
    );
    final broken = placeholder(const Icon(Icons.broken_image_outlined));

    if (isNetworkUrl(photoRef)) {
      return Image.network(
        photoRef,
        fit: fit,
        cacheWidth: cacheWidth,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : placeholder(const CircularProgressIndicator()),
        errorBuilder: (_, _, _) => broken,
      );
    }

    return switch (ref.watch(photoBytesProvider(photoRef))) {
      AsyncData(value: final bytes?) => Image.memory(
        bytes,
        fit: fit,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => broken,
      ),
      AsyncLoading() => placeholder(const CircularProgressIndicator()),
      _ => broken,
    };
  }
}
