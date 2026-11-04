import 'package:cloud_firestore/cloud_firestore.dart';

/// Converts a Firestore date field to [DateTime].
///
/// Server timestamps are `null` in the local snapshot until the server
/// confirms the write, so `null` maps to [fallback] (default: now) instead of
/// throwing. Accepts [Timestamp] (SDK) and [DateTime] (tests).
DateTime dateFromFirestore(Object? value, {DateTime? fallback}) =>
    switch (value) {
      Timestamp t => t.toDate(),
      DateTime d => d,
      _ => fallback ?? DateTime.now(),
    };

/// Reads a string field, returning [orElse] when missing or the wrong type.
String stringFrom(Object? value, {String orElse = ''}) =>
    value is String ? value : orElse;
