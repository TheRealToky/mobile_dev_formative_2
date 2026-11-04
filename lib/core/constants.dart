/// App-wide constants. Values that also appear in `firestore.rules` and
/// `storage.rules` are marked; change them in both places.
library;

/// Email domains allowed to register and use the app.
///
/// Mirrored in `firestore.rules` and `storage.rules` (`allowedEmail()`).
/// The domain only grants access; the role always comes from
/// `users/{uid}.role`.
const List<String> allowedEmailDomains = ['alustudent.com', 'alueducation.com'];

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

  /// Max upload size in bytes (5 MB). Mirrored in `storage.rules`.
  static const maxPhotoBytes = 5 * 1024 * 1024;
}

/// Firestore collection and Storage folder names.
abstract final class Paths {
  static const users = 'users';
  static const incidents = 'incidents';
  static const statusHistory = 'statusHistory';
  static const incidentPhotos = 'incident_photos';
}
