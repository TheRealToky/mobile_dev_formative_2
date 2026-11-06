import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/data/repositories/photo_repository.dart';
import 'package:mobile_dev_formative_2/providers/report_controller.dart';
import 'package:mobile_dev_formative_2/widgets/incident_photo.dart';

/// A valid 1x1 PNG, so `Image.memory` can decode it in widget tests.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  late FakeFirebaseFirestore db;
  late FirestorePhotoRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestorePhotoRepository(db);
  });

  group('FirestorePhotoRepository', () {
    test('stores the bytes under the incident and returns its path', () async {
      final progress = <double>[];
      final ref = await repo.uploadIncidentPhoto(
        incidentId: 'inc1',
        uploaderUid: 'student1',
        jpegBytes: _png,
        onProgress: progress.add,
      );

      expect(ref, startsWith('incidents/inc1/photos/'));
      expect(progress.last, 1);
      final data = (await db.doc(ref).get()).data()!;
      expect(data[PhotoFields.ownerUid], 'student1');
      expect(data[PhotoFields.contentType], 'image/jpeg');
      expect((data[PhotoFields.data] as Blob).bytes, _png);
    });

    test('loads what it stored, and null once deleted', () async {
      final ref = await repo.uploadIncidentPhoto(
        incidentId: 'inc1',
        uploaderUid: 'student1',
        jpegBytes: _png,
      );
      expect(await repo.loadPhoto(ref), _png);

      await repo.deletePhoto(ref);
      expect(await repo.loadPhoto(ref), isNull);
    });

    test('ignores legacy Storage URLs and missing photos on delete', () async {
      await repo.deletePhoto('https://firebasestorage.googleapis.com/x.jpg');
      await repo.deletePhoto(photoRefFor('inc1', 'missing'));
    });
  });

  test('isNetworkUrl tells legacy URLs from photo references', () {
    expect(isNetworkUrl('https://example.com/a.jpg'), isTrue);
    expect(isNetworkUrl(photoRefFor('inc1', 'p1')), isFalse);
  });

  testWidgets('IncidentPhoto shows a stored photo from Firestore', (
    tester,
  ) async {
    final ref = await repo.uploadIncidentPhoto(
      incidentId: 'inc1',
      uploaderUid: 'student1',
      jpegBytes: _png,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [photoRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(home: IncidentPhoto(photoRef: ref)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
  });

  testWidgets('IncidentPhoto shows a placeholder for a missing photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [photoRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: IncidentPhoto(photoRef: photoRefFor('inc1', 'gone')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });
}
