/// The outcome of a [saveTextFile] call, used so the UI can report honestly
/// instead of always claiming success.
enum FileSaveOutcome {
  /// The backup was delivered — shared/saved on native, or a browser download
  /// was triggered on web.
  completed,

  /// The user dismissed the native share sheet without saving or sharing.
  dismissed,
}
