import 'package:flutter/widgets.dart';

void main() {
  final m = Matrix4.translationValues(0.0, 1.0, 0.0)
    ..multiply(Matrix4.diagonal3Values(2.0, 2.0, 1.0));
  print(m);
}
