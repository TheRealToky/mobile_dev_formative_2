/// App-wide constants. Values that also appear in `firestore.rules` are
/// marked; change them in both places.
library;

/// Email domains allowed to register and use the app.
///
/// Mirrored in `firestore.rules` (`verified()`).
/// The domain only grants access; the role always comes from
/// `users/{uid}.role`.
const List<String> allowedEmailDomains = [
  'alustudent.com',
  'alueducation.com',
  'alueducation.si.com',
];

/// Domains whose new accounts start with the `staff` role (everything else
/// in [allowedEmailDomains], i.e. `alustudent.com`, starts as `student`).
///
/// Only the starting role: after sign-up `users/{uid}.role` is the source of
/// truth, so changing it in the Firestore console switches the screens the
/// user gets (handy for testing). Mirrored in `firestore.rules`
/// (`roleForEmail()`).
const List<String> staffEmailDomains = [
  'alueducation.com',
  'alueducation.si.com',
];

/// Campus buildings offered in the report form.
///
/// These are plausible placeholders for the ALU Kigali campus, not an
/// official list. Edit freely; "Other" should stay last.
const List<String> campusBuildings = [
  'Main building',
  'Learning commons',
  'Library',
  'Cafeteria',
  'Residence hall A',
  'Residence hall B',
  'Sports ground',
  'Parking and gate',
  'Other',
];

/// Field limits. Mirrored in `firestore.rules` (`validIncident()`).
abstract final class Limits {
  static const titleMin = 5;
  static const titleMax = 80;
  static const descriptionMin = 10;
  static const descriptionMax = 1000;
  static const locationDetailMax = 120;
  static const statusNoteMax = 500;
  static const displayNameMin = 2;
  static const displayNameMax = 50;
  static const passwordMin = 8;

  /// Photos per incident. Mirrored in `firestore.rules`.
  static const maxPhotos = 3;

  /// Max size of one compressed photo in bytes (700 KB). Photos are stored
  /// as Firestore documents, which are capped at 1 MiB including field
  /// names, so this leaves headroom. Mirrored in `firestore.rules`.
  static const maxPhotoBytes = 700 * 1024;
}

/// Firestore collection names.
abstract final class Paths {
  static const users = 'users';
  static const incidents = 'incidents';
  static const statusHistory = 'statusHistory';

  /// Subcollection of an incident holding its photos as Bytes fields.
  static const photos = 'photos';
}
