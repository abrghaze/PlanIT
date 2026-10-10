import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/offline_finance/domain/report_period.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';
import 'local_report_test.dart' show entry;

void main() {
  test(
    'UTC records use device dates and DST day buckets reconcile without gaps',
    () {
      final instant = DateTime.utc(2026, 10, 5, 23, 30);
      final local = instant.toLocal();
      final period = ReportPeriod.at(ReportSpan.day, local);
      final result = buildPeriodReport(
        currency: 'MAD',
        period: period,
        now: period.end,
        transactions: [entry('utc', '7', at: instant)],
      );
      expect(result.current.sources.single.id, 'utc');
      for (final date in [
        DateTime(2026, 3, 8),
        DateTime(2026, 11, 1),
        DateTime(2026, 3, 29),
        DateTime(2026, 10, 25),
        DateTime(2026, 2, 15),
        DateTime(2026, 3, 22),
      ]) {
        final p = ReportPeriod.at(ReportSpan.day, date);
        final rows = <LedgerTransaction>[];
        var cursor = p.start.toUtc();
        while (cursor.isBefore(p.end)) {
          rows.add(entry('hour-${rows.length}', '1', at: cursor));
          cursor = cursor.add(const Duration(hours: 1));
        }
        final r = buildPeriodReport(
          transactions: rows,
          currency: 'MAD',
          period: p,
          now: p.end,
        );
        expect(
          r.current.grossSpending,
          Money.parse(rows.length.toString(), 'MAD'),
        );
        expect(
          r.buckets.fold(
            Money.zero('MAD'),
            (s, b) => s + b.report.grossSpending,
          ),
          r.current.grossSpending,
        );
        expect(r.buckets.expand((b) => b.report.sources).length, rows.length);
      }
    },
  );
  test(
    'day, Monday week, leap month, year and custom bounds are calendar based',
    () {
      final d = DateTime(2024, 2, 29, 23);
      expect(ReportPeriod.at(ReportSpan.day, d).end, DateTime(2024, 3));
      final week = ReportPeriod.at(ReportSpan.week, d);
      expect(week.start, DateTime(2024, 2, 26));
      expect(week.end, DateTime(2024, 3, 4));
      expect(ReportPeriod.at(ReportSpan.month, d).start, DateTime(2024, 2));
      expect(ReportPeriod.at(ReportSpan.month, d).end, DateTime(2024, 3));
      expect(ReportPeriod.at(ReportSpan.year, d).end, DateTime(2025));
      final custom = ReportPeriod(
        ReportSpan.custom,
        DateTime(2024, 2, 28),
        DateTime(2024, 3, 2),
      );
      expect(custom.shift(-1).start, DateTime(2024, 2, 25));
      expect(custom.shift(-1).end, custom.start);
    },
  );
  test(
    'partial periods align previous calendar dates including short/leap months',
    () {
      final now = DateTime(2024, 3, 31, 12, 15);
      final month = ReportPeriod.at(ReportSpan.month, now);
      expect(month.comparisonCutoff(now), DateTime(2024, 2, 29, 12, 15));
      final year = ReportPeriod.at(ReportSpan.year, DateTime(2024, 2, 29));
      expect(
        year.comparisonCutoff(DateTime(2024, 2, 29, 16)),
        DateTime(2023, 2, 28, 16),
      );
      final week = ReportPeriod.at(ReportSpan.week, DateTime(2026, 10, 10, 14));
      expect(
        week.comparisonCutoff(DateTime(2026, 10, 10, 14)),
        DateTime(2026, 10, 3, 14),
      );
    },
  );
  test(
    'current partial month compares matching elapsed dates rather than full preceding month',
    () {
      final now = DateTime(2026, 10, 10, 12);
      final result = buildPeriodReport(
        currency: 'MAD',
        period: ReportPeriod.at(ReportSpan.month, now),
        now: now,
        transactions: [
          entry('this', '20'),
          entry('previous-before', '10', month: 9),
          entry('previous-after', '800', month: 9, day: 20),
          entry('future', '500', day: 20),
        ],
      );
      expect(result.current.netSpending, Money.parse('20', 'MAD'));
      expect(result.previous.netSpending, Money.parse('10', 'MAD'));
      expect(result.partial, isTrue);
    },
  );
  test(
    'every span reconciles chart buckets categories sources and summary exactly',
    () {
      final rows = [
        entry('expense', '100.0001'),
        entry('uncategorized', '5.0002', category: null),
        entry('income', '400.0003', type: TransactionType.income),
        entry('refund', '150.0004', type: TransactionType.refund),
        entry('fee', '2', type: TransactionType.transferFee),
        entry('transfer', '10000', type: TransactionType.transferOut),
        entry('draft', '900', status: TransactionStatus.draft),
        entry('reverse', '100', pending: 'REVERSE'),
        entry('void', '100', status: TransactionStatus.voided),
        entry(
          'pending',
          '10',
          pending: 'POST',
          status: TransactionStatus.draft,
        ),
        entry('eur', '500', currency: 'EUR'),
      ];
      for (final span in ReportSpan.values) {
        final p = span == ReportSpan.custom
            ? ReportPeriod(span, DateTime(2026, 10, 3), DateTime(2026, 10, 7))
            : ReportPeriod.at(span, DateTime(2026, 10, 5));
        final r = buildPeriodReport(
          transactions: rows,
          currency: 'MAD',
          period: p,
          now: DateTime(2026, 11),
        );
        expect(r.current.grossSpending, Money.parse('117.0003', 'MAD'));
        expect(r.current.netSpending, Money.parse('-33.0001', 'MAD'));
        expect(r.current.remainingIncome, Money.parse('433.0004', 'MAD'));
        expect(
          r.current.categories.values.fold(Money.zero('MAD'), (s, v) => s + v),
          r.current.netSpending,
        );
        expect(
          r.buckets.fold(Money.zero('MAD'), (s, b) => s + b.report.income),
          r.current.income,
        );
        expect(
          r.buckets.fold(Money.zero('MAD'), (s, b) => s + b.report.netSpending),
          r.current.netSpending,
        );
        expect(
          r.buckets.expand((b) => b.report.sources).map((t) => t.id).toSet(),
          r.current.sources.map((t) => t.id).toSet(),
        );
        expect(r.current.omittedCurrencies, {'EUR'});
      }
    },
  );
  test('end boundary is exclusive and timestamp uses local calendar', () {
    final p = ReportPeriod.at(ReportSpan.day, DateTime(2026, 10, 5));
    final r = buildPeriodReport(
      currency: 'MAD',
      period: p,
      now: DateTime(2026, 11),
      transactions: [
        entry('before', '1', day: 4),
        entry('inside', '2'),
        entry('end', '4', day: 6),
      ],
    );
    expect(r.current.sources.map((t) => t.id), ['inside']);
    expect(calendarDistance(DateTime(2026, 3, 29), DateTime(2026, 3, 30)), 1);
    expect(p.contains(DateTime(2026, 10, 5).toUtc()), isTrue);
  });
}
