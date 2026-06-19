import 'dart:io';

void main() {
  var d = Directory('lib');
  for (var f in d.listSync(recursive: true)) {
    if (f is File && f.path.endsWith('.dart')) {
      var s = f.readAsStringSync();
      if (s.contains(r'\$')) {
        f.writeAsStringSync(s.replaceAll(r'\$', r'$'));
        print('Fixed \${f.path}');
      }
    }
  }
}
