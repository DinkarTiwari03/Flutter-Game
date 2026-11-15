/// Top-level areas of the game UI, shown in the bottom bar (phone) or the
/// navigation rail (desktop).
enum GameSection {
  build('Build', 'Place houses, shops, factories and services.'),
  roads('Roads', 'Lay roads to connect your districts.'),
  economy('Economy', 'Taxes, income and budget.'),
  missions('Missions', 'Goals and rewards.'),
  statistics('Statistics', 'City-wide numbers and trends.');

  const GameSection(this.label, this.summary);

  final String label;
  final String summary;
}
