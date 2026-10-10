import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/offline_finance/domain/local_report.dart';
import 'package:planit_mobile/features/offline_finance/domain/offline_finance.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

enum ReportSpan { day, week, month, year, custom }

DateTime calendarDay(DateTime d) => DateTime(d.year, d.month, d.day);
int calendarDistance(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

final class ReportPeriod {
  const ReportPeriod(this.span, this.start, this.end);
  final ReportSpan span;
  final DateTime start, end;
  factory ReportPeriod.at(ReportSpan span, DateTime date) {
    final d = calendarDay(date.toLocal());
    return switch (span) {
      ReportSpan.day => ReportPeriod(
        span,
        d,
        DateTime(d.year, d.month, d.day + 1),
      ),
      ReportSpan.week => ReportPeriod(
        span,
        DateTime(d.year, d.month, d.day - d.weekday + 1),
        DateTime(d.year, d.month, d.day - d.weekday + 8),
      ),
      ReportSpan.month => ReportPeriod(
        span,
        DateTime(d.year, d.month),
        DateTime(d.year, d.month + 1),
      ),
      ReportSpan.year => ReportPeriod(
        span,
        DateTime(d.year),
        DateTime(d.year + 1),
      ),
      ReportSpan.custom => ReportPeriod(
        span,
        d,
        DateTime(d.year, d.month, d.day + 1),
      ),
    };
  }
  ReportPeriod shift(int delta) {
    if (span == ReportSpan.month) {
      return ReportPeriod.at(span, DateTime(start.year, start.month + delta));
    }
    if (span == ReportSpan.year) {
      return ReportPeriod.at(span, DateTime(start.year + delta));
    }
    final days = calendarDistance(start, end) * delta;
    return ReportPeriod(
      span,
      DateTime(start.year, start.month, start.day + days),
      DateTime(end.year, end.month, end.day + days),
    );
  }

  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);
  bool partial(DateTime now) => !now.isBefore(start) && now.isBefore(end);
  DateTime comparisonCutoff(DateTime now) {
    final previous = shift(-1);
    if (!partial(now)) return previous.end;
    final local = now.toLocal();
    late DateTime aligned;
    if (span == ReportSpan.month) {
      final day = local.day.clamp(
        1,
        DateTime(previous.start.year, previous.start.month + 1, 0).day,
      );
      aligned = DateTime(
        previous.start.year,
        previous.start.month,
        day,
        local.hour,
        local.minute,
        local.second,
        local.millisecond,
        local.microsecond,
      );
    } else if (span == ReportSpan.year) {
      final year = previous.start.year;
      final day = local.day.clamp(1, DateTime(year, local.month + 1, 0).day);
      aligned = DateTime(
        year,
        local.month,
        day,
        local.hour,
        local.minute,
        local.second,
        local.millisecond,
        local.microsecond,
      );
    } else {
      aligned = DateTime(
        previous.start.year,
        previous.start.month,
        previous.start.day + calendarDistance(start, local),
        local.hour,
        local.minute,
        local.second,
        local.millisecond,
        local.microsecond,
      );
    }
    return aligned.isAfter(previous.end) ? previous.end : aligned;
  }
}

final class ReportBucket {
  const ReportBucket({
    required this.start,
    required this.end,
    required this.report,
  });
  final DateTime start, end;
  final LocalReport report;
}

final class PeriodReport {
  const PeriodReport({
    required this.period,
    required this.current,
    required this.previous,
    required this.buckets,
    required this.partial,
  });
  final ReportPeriod period;
  final LocalReport current, previous;
  final List<ReportBucket> buckets;
  final bool partial;
}

LocalReport reportRange(
  Iterable<LedgerTransaction> rows,
  String currency,
  DateTime start,
  DateTime end, {
  DateTime? cutoff,
}) {
  final sources = <LedgerTransaction>[],
      categories = <String, Money>{},
      omitted = <String>{};
  var gross = Money.zero(currency),
      refunds = Money.zero(currency),
      income = Money.zero(currency);
  var pending = 0;
  for (final row in rows) {
    final date = row.occurredAt.toLocal();
    if (date.isBefore(start) ||
        !date.isBefore(end) ||
        (cutoff != null && date.isAfter(cutoff))) {
      continue;
    }
    if (row.amount.currency != currency) {
      if (countsInLocalReports(row)) omitted.add(row.amount.currency);
      continue;
    }
    if (row.hasPendingWork &&
        (countsInLocalReports(row) || row.pendingAction == 'REVERSE')) {
      pending++;
    }
    if (!countsInLocalReports(row) ||
        !(row.type.isIncome ||
            row.type.isSpending ||
            row.type == TransactionType.refund)) {
      continue;
    }
    sources.add(row);
    if (row.type.isIncome) {
      income += row.amount;
    } else {
      final isRefund = row.type == TransactionType.refund;
      if (isRefund) {
        refunds += row.amount;
      } else {
        gross += row.amount;
      }
      final signed = isRefund ? -row.amount : row.amount;
      categories.update(
        row.categoryId ?? '',
        (v) => v + signed,
        ifAbsent: () => signed,
      );
    }
  }
  sources.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return LocalReport(
    currency: currency,
    grossSpending: gross,
    refunds: refunds,
    income: income,
    categories: categories,
    sources: sources,
    pendingCount: pending,
    omittedCurrencies: omitted,
    dailySpending: const {},
  );
}

PeriodReport buildPeriodReport({
  required Iterable<LedgerTransaction> transactions,
  required String currency,
  required ReportPeriod period,
  required DateTime now,
}) {
  if (!period.start.isBefore(period.end) ||
      calendarDistance(period.start, period.end) > 3660) {
    throw const FormatException('Choose a date range of up to ten years.');
  }
  final rows = transactions.toList();
  final previous = period.shift(-1);
  final report = reportRange(
    rows,
    currency,
    period.start,
    period.end,
    cutoff: now,
  );
  final buckets = <ReportBucket>[];
  var start = period.start;
  while (start.isBefore(period.end)) {
    var end = period.span == ReportSpan.day
        ? DateTime(start.year, start.month, start.day, start.hour + 1)
        : period.span == ReportSpan.year ||
              calendarDistance(period.start, period.end) > 62
        ? DateTime(start.year, start.month + 1)
        : DateTime(start.year, start.month, start.day + 1);
    if (!end.isAfter(start)) end = start.add(const Duration(hours: 1));
    if (end.isAfter(period.end)) end = period.end;
    buckets.add(
      ReportBucket(
        start: start,
        end: end,
        report: reportRange(rows, currency, start, end, cutoff: now),
      ),
    );
    start = end;
  }
  return PeriodReport(
    period: period,
    current: report,
    previous: reportRange(
      rows,
      currency,
      previous.start,
      previous.end,
      cutoff: period.comparisonCutoff(now),
    ),
    buckets: buckets,
    partial: period.partial(now),
  );
}
