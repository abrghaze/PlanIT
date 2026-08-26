import 'package:planit_mobile/features/financial_operations/domain/financial_operation.dart';

final class FinancialOperationState {
  const FinancialOperationState({
    required this.busy,
    this.transferPreview,
    this.reconciliationPreview,
    this.reallocationPreview,
    this.errorMessage,
    this.noticeMessage,
  });

  const FinancialOperationState.idle()
    : busy = false,
      transferPreview = null,
      reconciliationPreview = null,
      reallocationPreview = null,
      errorMessage = null,
      noticeMessage = null;

  final bool busy;
  final TransferPreview? transferPreview;
  final ReconciliationPreview? reconciliationPreview;
  final ReallocationPreview? reallocationPreview;
  final String? errorMessage;
  final String? noticeMessage;

  FinancialOperationState copyWith({
    bool? busy,
    TransferPreview? transferPreview,
    ReconciliationPreview? reconciliationPreview,
    ReallocationPreview? reallocationPreview,
    bool clearPreviews = false,
    String? errorMessage,
    bool clearError = false,
    String? noticeMessage,
    bool clearNotice = false,
  }) {
    return FinancialOperationState(
      busy: busy ?? this.busy,
      transferPreview:
          transferPreview ?? (clearPreviews ? null : this.transferPreview),
      reconciliationPreview:
          reconciliationPreview ??
          (clearPreviews ? null : this.reconciliationPreview),
      reallocationPreview:
          reallocationPreview ??
          (clearPreviews ? null : this.reallocationPreview),
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      noticeMessage: clearNotice ? null : noticeMessage ?? this.noticeMessage,
    );
  }
}
