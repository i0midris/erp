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

  // Cache suppliers for offline use
  Future<void> cacheSuppliers(List<dynamic> suppliers) async {
    final db = await dbProvider.database;

    // Check if table exists before clearing
    final tableExists = await dbProvider.tableExists('cached_suppliers');
    if (tableExists) {
      await db.delete('cached_suppliers'); // Clear existing cache
    }

    for (final supplier in suppliers) {
      final supplierMap =
          supplier is Map<String, dynamic> ? supplier : supplier.toJson();
      await db.insert('cached_suppliers', {
        'id': supplierMap['id'],
        'name': supplierMap['name'] ?? supplierMap['text'] ?? '',
        'business_name': supplierMap['business_name'] ?? '',
        'mobile': supplierMap['mobile'] ?? '',
        'address_line_1': supplierMap['address_line_1'] ?? '',
        'city': supplierMap['city'] ?? '',
        'state': supplierMap['state'] ?? '',
        'country': supplierMap['country'] ?? '',
        'zip_code': supplierMap['zip_code'] ?? '',
        'contact_id': supplierMap['contact_id'] ?? '',
        'pay_term_type': supplierMap['pay_term_type'] ?? '',
        'pay_term_number': supplierMap['pay_term_number'] ?? 0,
        'balance': supplierMap['balance'] ?? 0.0,
        'last_sync': DateTime.now().toIso8601String(),
      });
    }
  }

  // Cache products for offline use
  Future<void> cacheProducts(List<dynamic> products) async {
    final db = await dbProvider.database;

    // Check if table exists before clearing
    final tableExists = await dbProvider.tableExists('cached_products');
    if (tableExists) {
      await db.delete('cached_products'); // Clear existing cache
    }

    for (final product in products) {
      final productMap =
          product is Map<String, dynamic> ? product : product.toJson();
      await db.insert('cached_products', {
        'product_id': productMap['product_id'],
        'product_name': productMap['product_name'] ?? '',
        'product_type': productMap['product_type'] ?? '',
        'variation_id': productMap['variation_id'],
        'variation_name': productMap['variation_name'] ?? '',
        'sub_sku': productMap['sub_sku'] ?? '',
        'default_purchase_price': productMap['default_purchase_price'] ?? 0.0,
        'last_sync': DateTime.now().toIso8601String(),
      });
    }
  }

  // Cache locations for offline use
  Future<void> cacheLocations(List<dynamic> locations) async {
    final db = await dbProvider.database;

    // Check if table exists before clearing
    final tableExists = await dbProvider.tableExists('cached_locations');
    if (tableExists) {
      await db.delete('cached_locations'); // Clear existing cache
    }

    for (final location in locations) {
      final locationMap =
          location is Map<String, dynamic> ? location : location.toJson();
      await db.insert('cached_locations', {
        'id': locationMap['id'],
        'name': locationMap['name'] ?? '',
        'location_id': locationMap['location_id'] ?? locationMap['id'],
        'address': locationMap['address'] ?? '',
        'city': locationMap['city'] ?? '',
        'state': locationMap['state'] ?? '',
        'country': locationMap['country'] ?? '',
        'zip_code': locationMap['zip_code'] ?? '',
        'last_sync': DateTime.now().toIso8601String(),
      });
    }
  }

  // Get cached suppliers
  Future<List<Map<String, dynamic>>> getCachedSuppliers(
      {String? searchTerm}) async {
    final db = await dbProvider.database;
    String where = '1=1';
    List<String> whereArgs = [];

    if (searchTerm != null && searchTerm.isNotEmpty) {
      where +=
          ' AND (name LIKE ? OR business_name LIKE ? OR contact_id LIKE ?)';
      whereArgs.addAll(['%$searchTerm%', '%$searchTerm%', '%$searchTerm%']);
    }

    final response = await db.query(
      'cached_suppliers',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );

    return response;
  }

  // Get cached products
  Future<List<Map<String, dynamic>>> getCachedProducts(
      {String? searchTerm}) async {
    final db = await dbProvider.database;
    String where = '1=1';
    List<String> whereArgs = [];

    if (searchTerm != null && searchTerm.isNotEmpty) {
      where += ' AND (product_name LIKE ? OR sub_sku LIKE ?)';
      whereArgs.addAll(['%$searchTerm%', '%$searchTerm%']);
    }

    final response = await db.query(
      'cached_products',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'product_name ASC',
    );

    return response;
  }

  // Get cached locations
  Future<List<Map<String, dynamic>>> getCachedLocations() async {
    final db = await dbProvider.database;
    final response = await db.query(
      'cached_locations',
      orderBy: 'name ASC',
    );

    return response;
  }

  // Get cached suppliers count
  Future<int> getCachedSuppliersCount() async {
    final db = await dbProvider.database;
    final response =
        await db.rawQuery('SELECT COUNT(*) as count FROM cached_suppliers');
    return response[0]['count'] as int;
  }

  // Get cached products count
  Future<int> getCachedProductsCount() async {
    final db = await dbProvider.database;
    final response =
        await db.rawQuery('SELECT COUNT(*) as count FROM cached_products');
    return response[0]['count'] as int;
  }

  // Get cached locations count
  Future<int> getCachedLocationsCount() async {
    final db = await dbProvider.database;
    final response =
        await db.rawQuery('SELECT COUNT(*) as count FROM cached_locations');
    return response[0]['count'] as int;
  }

  // Clear all purchase cache
  Future<void> clearPurchaseCache() async {
    final db = await dbProvider.database;
    await db.delete('cached_suppliers');
    await db.delete('cached_products');
    await db.delete('cached_locations');
  }
}
