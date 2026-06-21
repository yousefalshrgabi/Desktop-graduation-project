void main() {
  String xml = '<w:r><w:t>{</w:t></w:r><w:r><w:t>{is</w:t></w:r><w:r><w:t>Hajj}}</w:t></w:r>';
  String key = '{{isHajj}}';
  final chars = key.split('').map((c) => RegExp.escape(c));
  final pattern = chars.join(r'(?:<[^>]+>)*');
  print('Pattern: \');
  final regex = RegExp(pattern);
  print('Result: \');
}
