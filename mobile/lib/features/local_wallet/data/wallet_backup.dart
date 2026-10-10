import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:planit_mobile/features/local_wallet/domain/wallet.dart';

final class WalletBackup {
  static const iterations = 210000;
  static const maximumBytes = 20 * 1024 * 1024;
  static final _aad = utf8.encode('PlanIT local wallet encrypted backup v1');
  static void _password(String password) {
    if (password.length < 12 || password.length > 256) {
      throw const FormatException(
        'Use a backup passphrase of 12–256 characters.',
      );
    }
  }

  static Future<List<int>> encrypt(Wallet wallet, String password) async {
    _password(password);
    final json = wallet.toJson();
    return Isolate.run(() async {
      final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
      final key = await Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
      final box = await AesGcm.with256bits().encrypt(
        utf8.encode(jsonEncode(json)),
        secretKey: key,
        aad: _aad,
      );
      return utf8.encode(
        jsonEncode({
          'format': 'planit-encrypted-wallet',
          'version': 1,
          'iterations': iterations,
          'salt': base64Encode(salt),
          'nonce': base64Encode(box.nonce),
          'mac': base64Encode(box.mac.bytes),
          'ciphertext': base64Encode(box.cipherText),
        }),
      );
    });
  }

  static Future<Wallet> decrypt(List<int> bytes, String password) async {
    _password(password);
    if (bytes.length > maximumBytes) {
      throw const FormatException('Backup file is too large.');
    }
    final json = await Isolate.run(() async {
      final j = walletMap(jsonDecode(utf8.decode(bytes)));
      if (j['format'] != 'planit-encrypted-wallet' ||
          j['version'] != 1 ||
          j['iterations'] != iterations) {
        throw const FormatException('Unsupported encrypted PlanIT backup.');
      }
      List<int> field(String key, int? size) {
        final value = base64Decode(walletText(j[key], max: maximumBytes));
        if (size != null && value.length != size) {
          throw const FormatException('Damaged backup.');
        }
        return value;
      }

      final salt = field('salt', 16),
          nonce = field('nonce', 12),
          mac = field('mac', 16);
      final key = await Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
      final plaintext = await AesGcm.with256bits().decrypt(
        SecretBox(field('ciphertext', null), nonce: nonce, mac: Mac(mac)),
        secretKey: key,
        aad: _aad,
      );
      return walletMap(jsonDecode(utf8.decode(plaintext)));
    });
    return Wallet.fromJson(json);
  }
}
