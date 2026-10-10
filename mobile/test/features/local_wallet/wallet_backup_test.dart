import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/local_wallet/data/wallet_backup.dart';
import 'package:planit_mobile/features/local_wallet/domain/wallet.dart';
import 'wallet_store_test.dart' show cash, expense;

void main() {
  test(
    'encrypted backup round trips all records and rejects wrong passwords/tampering',
    () async {
      final w = Wallet.empty().copyWith(
        accounts: [cash()],
        entries: [expense('private', '10.1234')],
        budgets: [
          WalletBudget(
            id: 'budget',
            categoryId: 'food',
            month: '2026-10',
            limit: Money.parse('50', 'MAD'),
          ),
        ],
        goals: [
          WalletGoal(
            id: 'goal',
            name: 'Emergency',
            target: Money.parse('1000', 'MAD'),
            saved: Money.parse('12', 'MAD'),
            accountId: 'cash',
          ),
        ],
      );
      const pass = 'a long private backup passphrase';
      final bytes = await WalletBackup.encrypt(w, pass);
      expect(utf8.decode(bytes), isNot(contains('10.1234')));
      final restored = await WalletBackup.decrypt(bytes, pass);
      expect(restored.toJson(), w.toJson());
      await expectLater(
        WalletBackup.decrypt(bytes, 'wrong but long password'),
        throwsA(anything),
      );
      final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final cipher = base64Decode(envelope['ciphertext'] as String);
      cipher[0] ^= 1;
      envelope['ciphertext'] = base64Encode(cipher);
      await expectLater(
        WalletBackup.decrypt(utf8.encode(jsonEncode(envelope)), pass),
        throwsA(anything),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
  test(
    'malformed, oversized and unsupported backups fail before any wallet mutation',
    () async {
      await expectLater(
        WalletBackup.decrypt(utf8.encode('{}'), 'long enough passphrase'),
        throwsFormatException,
      );
      await expectLater(
        WalletBackup.encrypt(Wallet.empty(), 'short'),
        throwsFormatException,
      );
      await expectLater(
        WalletBackup.decrypt(
          List.filled(WalletBackup.maximumBytes + 1, 0),
          'long enough passphrase',
        ),
        throwsFormatException,
      );
      final j = Wallet.empty().toJson();
      j['version'] = 999;
      expect(() => Wallet.fromJson(j), throwsFormatException);
    },
  );
}
