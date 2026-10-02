import '../database/database_helper.dart';
import '../models/receipt_voucher_model.dart';

class ReceiptVoucherRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int> createReceiptVoucher(ReceiptVoucher voucher) {
    return _databaseHelper.createReceiptVoucher(voucher);
  }

  Future<List<ReceiptVoucher>> getForCustomer(int customerId) async {
    final maps = await _databaseHelper.getReceiptVouchersForCustomer(
      customerId,
    );
    return maps.map(ReceiptVoucher.fromMap).toList();
  }
}
