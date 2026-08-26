import 'package:planit_mobile/features/financial_operations/domain/financial_operation.dart';

abstract interface class FinancialOperationsRemoteDataSource {
  Future<TransferPreview> previewTransfer({
    required String accessToken,
    required TransferPreviewRequest request,
  });

  Future<ReconciliationPreview> previewReconciliation({
    required String accessToken,
    required ReconciliationPreviewRequest request,
  });

  Future<ReallocationPreview> previewReallocation({
    required String accessToken,
    required ReallocationPreviewRequest request,
  });
}
