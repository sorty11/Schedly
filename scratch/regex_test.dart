void main() {
  final dateRegex = RegExp(r'^[A-Z][a-z]{2}\s\d{1,2},\s\d{4}$');
  print('Regex match Jan 5, 2026: ${dateRegex.hasMatch('Jan 5, 2026')}');
  print('Regex match Jan  5,  2026: ${dateRegex.hasMatch('Jan  5,  2026')}');
}
