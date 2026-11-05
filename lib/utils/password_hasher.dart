import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PasswordHasher {
  static const _algorithm = 'pbkdf2-sha256';
  static const _iterations = 210000;
  static const _saltLength = 16;

  static Future<String> hash(String password) async {
    final salt = List<int>.generate(
      _saltLength,
      (_) => Random.secure().nextInt(256),
      growable: false,
    );
    final digest = await Isolate.run(
      () => _deriveKey(utf8.encode(password), salt, _iterations),
    );
    return '$_algorithm\$$_iterations\$${_encodeHex(salt)}\$${_encodeHex(digest)}';
  }

  static Future<bool> verify(String password, String storedValue) async {
    if (!storedValue.startsWith('$_algorithm\$')) {
      return _constantTimeEquals(
        utf8.encode(password),
        utf8.encode(storedValue),
      );
    }

    final parts = storedValue.split(r'$');
    if (parts.length != 4 || parts[0] != _algorithm) return false;
    final iterations = int.tryParse(parts[1]);
    final salt = _decodeHex(parts[2]);
    final expected = _decodeHex(parts[3]);
    if (iterations == null ||
        iterations < 100000 ||
        iterations > 1000000 ||
        salt == null ||
        salt.length != _saltLength ||
        expected == null ||
        expected.length != 32) {
      return false;
    }

    final actual = await Isolate.run(
      () => _deriveKey(utf8.encode(password), salt, iterations),
    );
    return _constantTimeEquals(actual, expected);
  }

  static List<int> _deriveKey(
    List<int> password,
    List<int> salt,
    int iterations,
  ) {
    final hmac = Hmac(sha256, password);
    var value = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = List<int>.from(value);

    for (var iteration = 1; iteration < iterations; iteration++) {
      value = hmac.convert(value).bytes;
      for (var index = 0; index < result.length; index++) {
        result[index] ^= value[index];
      }
    }

    return result;
  }

  static String _encodeHex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  static List<int>? _decodeHex(String value) {
    if (value.length.isOdd || !RegExp(r'^[0-9a-f]+$').hasMatch(value)) {
      return null;
    }
    return [
      for (var index = 0; index < value.length; index += 2)
        int.parse(value.substring(index, index + 2), radix: 16),
    ];
  }

  static bool _constantTimeEquals(List<int> left, List<int> right) {
    var difference = left.length ^ right.length;
    final length = max(left.length, right.length);
    for (var index = 0; index < length; index++) {
      final leftByte = index < left.length ? left[index] : 0;
      final rightByte = index < right.length ? right[index] : 0;
      difference |= leftByte ^ rightByte;
    }
    return difference == 0;
  }
}
