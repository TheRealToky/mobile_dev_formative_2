import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_dev_formative_2/core/errors.dart';
import 'package:mobile_dev_formative_2/data/models/app_user.dart';
import 'package:mobile_dev_formative_2/data/models/incident.dart';
import 'package:mobile_dev_formative_2/data/models/report_draft.dart';
import 'package:mobile_dev_formative_2/data/repositories/incident_repository.dart';
import 'package:mobile_dev_formative_2/data/repositories/photo_repository.dart';
import 'package:mobile_dev_formative_2/data/services/photo_services.dart';
import 'package:mobile_dev_formative_2/providers/auth_providers.dart';
import 'package:mobile_dev_formative_2/providers/incident_providers.dart';
import 'package:mobile_dev_formative_2/providers/report_controller.dart';
import 'package:mobile_dev_formative_2/providers/retry_policy.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/builders.dart';

class MockIncidentRepository extends Mock implements IncidentRepository {}

class MockPhotoRepository extends Mock implements PhotoRepository {}

class MockImageCompressor extends Mock implements ImageCompressor {}

final _profile = AppUser(
  uid: 'uid1',
  displayName: 'Ada',
  email: 'ada@alustudent.com',
  role: UserRole.student,
  createdAt: DateTime(2026),
);

ReportDraft _draft({
  List<DraftPhoto> photos = const [],
  bool anonymous = false,
}) => ReportDraft(
  title: '  Leaking tap  ',
  description: 'The tap in the bathroom leaks all night.',
  category: IncidentCategory.water,
  building: 'Library',
  locationDetail: '2nd floor',
  isAnonymous: anonymous,
  photos: photos,
);

void main() {
  late MockIncidentRepository incidents;
  late MockPhotoRepository storage;
  late MockImageCompressor compressor;
  final bytes = Uint8List.fromList([1, 2, 3]);

  setUpAll(() {
    registerFallbackValue(buildIncident());
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    incidents = MockIncidentRepository();
    storage = MockPhotoRepository();
    compressor = MockImageCompressor();
    when(() => incidents.newIncidentId()).thenReturn('new-id');
    when(() => compressor.compressForUpload(any()))
        .thenAnswer((_) async => bytes);
    when(() => storage.deletePhoto(any())).thenAnswer((_) async {});
  });

  /// Upload stub: returns a URL per local path and reports progress.
  void stubUploads({Object? failOn}) {
    var n = 0;
    when(
      () => storage.uploadIncidentPhoto(
        incidentId: any(named: 'incidentId'),
        uploaderUid: any(named: 'uploaderUid'),
        jpegBytes: any(named: 'jpegBytes'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((inv) async {
      n++;
      if (failOn == n) throw const UserFacingException('Upload failed.');
      (inv.namedArguments[#onProgress] as void Function(double)?)?.call(1);
      return 'https://storage/photo$n.jpg';
    });
  }

  Future<ProviderContainer> makeContainer({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final container = ProviderContainer.test(
      retry: noAutomaticRetry,
      overrides: [
        incidentRepositoryProvider.overrideWithValue(incidents),
        photoRepositoryProvider.overrideWithValue(storage),
        imageCompressorProvider.overrideWithValue(compressor),
        reportWriteTimeoutProvider.overrideWithValue(timeout),
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(_profile),
        ),
      ],
    );
    container.listen(currentUserProfileProvider, (_, _) {});
    await container.read(currentUserProfileProvider.future);
    return container;
  }

  group('submit', () {
    test('compresses and uploads photos, then writes the document', () async {
      stubUploads();
      when(() => incidents.createIncident(any())).thenAnswer((_) async {});
      final c = await makeContainer();
      final progress = <num?>[];
      c.listen(reportControllerProvider, (_, s) => progress.add(s.progress));

      final result = await c
          .read(reportControllerProvider.notifier)
          .submit(
            _draft(photos: const [LocalPhoto('/a.jpg'), LocalPhoto('/b.jpg')]),
          );

      expect(result?.incidentId, 'new-id');
      expect(result?.queuedOffline, isFalse);
      verify(() => compressor.compressForUpload('/a.jpg')).called(1);
      verify(() => compressor.compressForUpload('/b.jpg')).called(1);

      final saved =
          verify(() => incidents.createIncident(captureAny())).captured.single
              as Incident;
      expect(saved.id, 'new-id');
      expect(saved.title, 'Leaking tap', reason: 'trimmed');
      expect(saved.photoUrls, [
        'https://storage/photo1.jpg',
        'https://storage/photo2.jpg',
      ]);
      expect(saved.reporterId, 'uid1');
      expect(saved.reporterName, 'Ada');
      expect(progress.whereType<num>(), contains(greaterThan(0)));
      expect(c.read(reportControllerProvider).hasError, isFalse);
      verifyNever(() => storage.deletePhoto(any()));
    });

    test('anonymous reports are saved without the name', () async {
      when(() => incidents.createIncident(any())).thenAnswer((_) async {});
      final c = await makeContainer();
      await c
          .read(reportControllerProvider.notifier)
          .submit(_draft(anonymous: true));
      final saved =
          verify(() => incidents.createIncident(captureAny())).captured.single
              as Incident;
      expect(saved.isAnonymous, isTrue);
      expect(saved.reporterName, isNull);
    });

    test('deletes uploaded photos when the document write fails', () async {
      stubUploads();
      when(() => incidents.createIncident(any()))
          .thenThrow(const UserFacingException('You do not have permission.'));
      final c = await makeContainer();

      final result = await c
          .read(reportControllerProvider.notifier)
          .submit(
            _draft(photos: const [LocalPhoto('/a.jpg'), LocalPhoto('/b.jpg')]),
          );

      expect(result, isNull);
      expect(
        c.read(reportControllerProvider).error,
        isA<UserFacingException>(),
      );
      verify(() => storage.deletePhoto('https://storage/photo1.jpg')).called(1);
      verify(() => storage.deletePhoto('https://storage/photo2.jpg')).called(1);
    });

    test('deletes earlier photos when a later upload fails', () async {
      stubUploads(failOn: 2);
      final c = await makeContainer();

      final result = await c
          .read(reportControllerProvider.notifier)
          .submit(
            _draft(photos: const [LocalPhoto('/a.jpg'), LocalPhoto('/b.jpg')]),
          );

      expect(result, isNull);
      verify(() => storage.deletePhoto('https://storage/photo1.jpg')).called(1);
      verifyNever(() => incidents.createIncident(any()));
    });

    test('a write the server never confirms is reported as queued, '
        'and photos are kept', () async {
      stubUploads();
      when(() => incidents.createIncident(any()))
          .thenAnswer((_) => Completer<void>().future);
      final c = await makeContainer(timeout: const Duration(milliseconds: 50));

      final result = await c
          .read(reportControllerProvider.notifier)
          .submit(_draft(photos: const [LocalPhoto('/a.jpg')]));

      expect(result?.queuedOffline, isTrue);
      verifyNever(() => storage.deletePhoto(any()));
    });
  });

  group('saveEdit', () {
    test('keeps remaining photos, uploads new ones, deletes removed ones '
        'after saving', () async {
      stubUploads();
      when(() => incidents.updateIncident(any())).thenAnswer((_) async {});
      final c = await makeContainer();
      final original = buildIncident(
        id: 'inc1',
        photoUrls: const ['https://old/keep.jpg', 'https://old/drop.jpg'],
      );

      final result = await c
          .read(reportControllerProvider.notifier)
          .saveEdit(
            original,
            _draft(
              photos: const [
                RemotePhoto('https://old/keep.jpg'),
                LocalPhoto('/new.jpg'),
              ],
            ),
          );

      expect(result?.incidentId, 'inc1');
      final saved =
          verify(() => incidents.updateIncident(captureAny())).captured.single
              as Incident;
      expect(saved.photoUrls, [
        'https://old/keep.jpg',
        'https://storage/photo1.jpg',
      ]);
      expect(saved.status, original.status);
      verify(() => storage.deletePhoto('https://old/drop.jpg')).called(1);
      verifyNever(() => storage.deletePhoto('https://old/keep.jpg'));
    });
  });

  group('delete', () {
    test('removes the document, then its photos', () async {
      when(() => incidents.deleteIncident('inc1')).thenAnswer((_) async {});
      final c = await makeContainer();

      final ok = await c
          .read(reportControllerProvider.notifier)
          .delete(buildIncident(photoUrls: const ['https://p/1.jpg']));

      expect(ok, isTrue);
      verifyInOrder([
        () => incidents.deleteIncident('inc1'),
        () => storage.deletePhoto('https://p/1.jpg'),
      ]);
    });

    test('reports failure without touching photos', () async {
      when(() => incidents.deleteIncident(any()))
          .thenThrow(const UserFacingException('You do not have permission.'));
      final c = await makeContainer();

      final ok = await c
          .read(reportControllerProvider.notifier)
          .delete(buildIncident(photoUrls: const ['https://p/1.jpg']));

      expect(ok, isFalse);
      verifyNever(() => storage.deletePhoto(any()));
    });
  });
}
