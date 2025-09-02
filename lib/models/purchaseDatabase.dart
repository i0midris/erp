import 'database.dart';

class PurchaseDatabase {
  late DbProvider dbProvider;

  PurchaseDatabase() {
    dbProvider = new DbProvider();
  }

  // Store purchase line
  Future<int> storePurchaseLine(value) async {
    final db = await dbProvider.database;
    var response = db.insert('purchase_lines', value);
    return response;
  }

  // Get purchase lines by purchase_id
  Future<List> getPurchaseLines(purchaseId) async {
    final db = await dbProvider.database;
    var response = await db.query('purchase_lines',
        columns: [
          'product_id',
          'variation_id',
          'quantity',
          'unit_price',
          'line_discount_amount',
          'line_discount_type',
          'item_tax_id',
          'item_tax',
          'sub_unit_id',
          'lot_number',
          'mfg_date',
          'exp_date',
          'purchase_order_line_id',
          'purchase_requisition_line_id'
        ],
        where: "purchase_id = ?",
        whereArgs: [purchaseId]);
    return response;
  }

  // Update purchase line
  Future<int> updatePurchaseLine(purchaseLineId, value) async {
    final db = await dbProvider.database;
    var response = await db.update('purchase_lines', value,
        where: 'id = ?', whereArgs: [purchaseLineId]);
    return response;
  }

  // Delete purchase line
  Future<int> deletePurchaseLine(int purchaseLineId) async {
    final db = await dbProvider.database;
    var response = await db
        .delete('purchase_lines', where: 'id = ?', whereArgs: [purchaseLineId]);
    return response;
  }

  // Delete purchase lines by purchase_id
  Future<int> deletePurchaseLinesByPurchaseId(purchaseId) async {
    final db = await dbProvider.database;
    var response = await db.delete('purchase_lines',
        where: 'purchase_id = ?', whereArgs: [purchaseId]);
    return response;
  }

  // Store purchase
  Future<int> storePurchase(Map<String, dynamic> value) async {
    final db = await dbProvider.database;
    var response = await db.insert('purchase', value);
    return response;
  }

  // Get purchases
  Future<List> getPurchases({bool? all}) async {
    final db = await dbProvider.database;
    var response = await db.query('purchase', orderBy: 'id DESC');
    return response;
  }

  // Get purchase by id
  Future<List> getPurchaseById(purchaseId) async {
    final db = await dbProvider.database;
    var response =
        await db.query('purchase', where: 'id = ?', whereArgs: [purchaseId]);
    return response;
  }

  // Get purchase by transaction_id
  Future<List> getPurchaseByTransactionId(transactionId) async {
    final db = await dbProvider.database;
    var response = await db.query('purchase',
        where: 'transaction_id = ?', whereArgs: [transactionId]);
    return response;
  }

  // Get transaction ids of synced purchases
  Future<List> getTransactionIds() async {
    final db = await dbProvider.database;
    var response = await db.query('purchase',
        columns: ['transaction_id'],
        where: 'transaction_id != ?',
        whereArgs: ['null']);
    var ids = [];
    response.forEach((element) {
      ids.add(element['transaction_id']);
    });
    return ids;
  }

  // Get not synced purchases
  Future<List> getNotSyncedPurchases() async {
    final db = await dbProvider.database;
    var response = await db.query('purchase', where: 'is_synced = 0');
    return response;
  }

  // Update purchase
  Future<int> updatePurchase(purchaseId, value) async {
    final db = await dbProvider.database;
    var response = await db
        .update('purchase', value, where: 'id = ?', whereArgs: [purchaseId]);
    return response;
  }

  // Delete purchase
  Future<int> deletePurchase(int purchaseId) async {
    final db = await dbProvider.database;
    await db.delete('purchase_lines',
        where: 'purchase_id = ?', whereArgs: [purchaseId]);
    await db.delete('purchase_payments',
        where: 'purchase_id = ?', whereArgs: [purchaseId]);
    var response =
        await db.delete('purchase', where: 'id = ?', whereArgs: [purchaseId]);
    return response;
  }

  // Store purchase payment
  Future<int> storePurchasePayment(value) async {
    final db = await dbProvider.database;
    var response = db.insert('purchase_payments', value);
    return response;
  }

  // Get purchase payments
  Future<List> getPurchasePayments(purchaseId) async {
    final db = await dbProvider.database;
    var response = await db.query('purchase_payments',
        where: 'purchase_id = ?', whereArgs: [purchaseId]);
    return response;
  }

  // Delete purchase payment
  Future<int> deletePurchasePayment(int paymentId) async {
    final db = await dbProvider.database;
    var response = await db
        .delete('purchase_payments', where: 'id = ?', whereArgs: [paymentId]);
    return response;
  }

  // Delete purchase payments by purchase_id
  Future<int> deletePurchasePaymentsByPurchaseId(purchaseId) async {
    final db = await dbProvider.database;
    var response = await db.delete('purchase_payments',
        where: 'purchase_id = ?', whereArgs: [purchaseId]);
    return response;
  }

  // Empty purchase tables
  deletePurchaseTables() async {
    final db = await dbProvider.database;
    await db.delete('purchase');
    await db.delete('purchase_lines');
    await db.delete('purchase_payments');
  }

  // Count purchase lines
  Future<String> countPurchaseLines({purchaseId}) async {
    String where = '1=1';
    if (purchaseId != null) {
      where = 'purchase_id = $purchaseId';
    }

    final db = await dbProvider.database;
    var response = await db
        .rawQuery('SELECT COUNT(*) AS counts FROM purchase_lines WHERE $where');
    return response[0]['counts'].toString();
  }
}
