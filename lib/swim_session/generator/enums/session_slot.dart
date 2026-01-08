// swim_session.dart (or common enums file)
enum SessionSlot {
  morning,
  afternoon,
  undefined,
}
// session_slot_extensions.dart
extension SessionSlotX on SessionSlot {
  String get short {
    switch (this) {
      case SessionSlot.morning:
        return 'AM';
      case SessionSlot.afternoon:
        return 'PM';
      case SessionSlot.undefined:
        return '';
    }
  }

  String get description {
    switch (this) {
      case SessionSlot.morning:
        return 'Morning';
      case SessionSlot.afternoon:
        return 'Evening';
      case SessionSlot.undefined:
        return '';
    }
  }
}
