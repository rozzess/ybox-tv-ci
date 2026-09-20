import 'dart:io';

Future<String> readFileAsString(String path) => File(path).readAsString();
