/// A bookish animal avatar shipped with the app, as an alternative to picking a
/// photo from the gallery. The SVG carries its own palette and outline ring, so
/// it renders the same in light and dark themes.
class PresetAvatar {
  /// Stable identifier. Persisted (prefixed) in settings, so never rename one
  /// without migrating stored values.
  final String id;
  final String name;

  const PresetAvatar(this.id, this.name);

  String get asset => 'assets/avatars/$id.svg';
}

const List<PresetAvatar> presetAvatars = [
  PresetAvatar('owl', 'Owl'),
  PresetAvatar('cat', 'Cat'),
  PresetAvatar('fox', 'Fox'),
  PresetAvatar('crow', 'Crow'),
  PresetAvatar('turtle', 'Turtle'),
];
