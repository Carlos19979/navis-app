import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/utils/byte_utils.dart';

void main() {
  test('formats storage sizes at the precision that means something', () {
    expect(ByteUtils.format(512), '512 B');
    expect(ByteUtils.format(2048), '2 KB');
    expect(ByteUtils.format(1024 * 1024), '1.0 MB');
    expect(ByteUtils.format(6 * 1024 * 1024), '6.0 MB');
    expect(ByteUtils.format(42 * 1024 * 1024), '42 MB');
    expect(ByteUtils.format(3 * 1024 * 1024 * 1024), '3.0 GB');
  });
}
