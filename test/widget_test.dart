import 'package:flutter_test/flutter_test.dart';
import 'package:nexted_ielts_app/app/routes.dart';

void main() {
  test('screen catalog covers all 76 canvas screens (75 + D11, D12 − H9 YouTube, removed) with unique routes', () {
    expect(ScreenCatalog.all.length, 76);
    final routes = ScreenCatalog.all.map((s) => s.route).toSet();
    expect(routes.length, 76);
  });
}
