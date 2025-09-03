import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_final/config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DbProvider {
  DbProvider();

  DbProvider._createInstance();

  static final DbProvider db = DbProvider._createInstance();
  static Database? _database;

  //query to create system table(location,brand,category,taxRate)
  String createSystemTable =
      "CREATE TABLE system (id INTEGER PRIMARY KEY AUTOINCREMENT, keyId INTEGER DEFAULT null,"
      " key TEXT, value TEXT)";

  //query to create contact table
  String createContactTable =
      "CREATE TABLE contact (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, city TEXT, state TEXT,"
      " country TEXT, address_line_1 TEXT, address_line_2 TEXT, zip_code TEXT, mobile TEXT)";

  //query to create variation Table
  String createVariationTable =
      "CREATE TABLE variations (id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER,"
      " variation_id INTEGER, product_name TEXT, product_variation_name TEXT, variation_name TEXT,"
      " display_name TEXT, sku TEXT, sub_sku TEXT, type TEXT, enable_stock INTEGER,"
      " brand_id INTEGER, unit_id INTEGER, category_id INTEGER, sub_category_id INTEGER,"
      " tax_id INTEGER, default_sell_price REAL, sell_price_inc_tax REAL, product_image_url TEXT,"
      " selling_price_group BLOB DEFAULT null, product_description TEXT)";

  //query to create variation by location table
  String createVariationByLocationTable =
      "CREATE TABLE variations_location_details (id INTEGER PRIMARY KEY AUTOINCREMENT,"
      " product_id INTEGER, variation_id INTEGER, location_id INTEGER, qty_available REAL)";

  //query to create product available in location table
  String createProductAvailableInLocationTable =
      "CREATE TABLE product_locations (id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER,"
      " location_id INTEGER)";

  //query to create sale table in database
  String createSellTable =
      "CREATE TABLE sell (id INTEGER PRIMARY KEY AUTOINCREMENT, transaction_date TEXT, invoice_no TEXT,"
      " contact_id INTEGER, location_id INTEGER, status TEXT, tax_rate_id INTEGER, discount_amount REAL,"
      " discount_type TEXT, sale_note TEXT, staff_note TEXT, shipping_details TEXT, is_quotation INTEGER DEFAULT 0,"
      " shipping_charges REAL DEFAULT 0.00,invoice_amount REAL, change_return REAL DEFAULT 0.00, pending_amount REAL DEFAULT 0.00,"
      " is_synced INTEGER, transaction_id INTEGER DEFAULT null, invoice_url TEXT DEFAULT null)";

//query to create sale line table in database
  String createSellLineTable =
      "CREATE TABLE sell_lines (id INTEGER PRIMARY KEY AUTOINCREMENT, sell_id INTEGER,"
      " product_id INTEGER,variation_id INTEGER, quantity REAL, unit_price REAL,"
      " tax_rate_id INTEGER, discount_amount REAL, discount_type TEXT, note TEXT,"
      " is_completed INTEGER)";

  //query to create payment line table in database
  String createSellPaymentsTable =
      "CREATE TABLE sell_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, sell_id INTEGER,"
      " payment_id INTEGER DEFAULT null, method TEXT, amount REAL, note TEXT,"
      " account_id INTEGER DEFAULT null, is_return INTEGER DEFAULT 0)";

  //query to create purchase table in database
  String createPurchaseTable =
      "CREATE TABLE purchase (id INTEGER PRIMARY KEY AUTOINCREMENT, transaction_date TEXT, ref_no TEXT,"
      " contact_id INTEGER, location_id INTEGER, status TEXT, tax_id INTEGER, discount_amount REAL,"
      " discount_type TEXT, additional_notes TEXT, shipping_details TEXT, shipping_charges REAL DEFAULT 0.00,"
      " total_before_tax REAL, tax_amount REAL, final_total REAL,"
      " is_synced INTEGER, transaction_id INTEGER DEFAULT null)";

  //query to create purchase line table in database
  String createPurchaseLineTable =
      "CREATE TABLE purchase_lines (id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER,"
      " product_id INTEGER, variation_id INTEGER, quantity REAL, unit_price REAL,"
      " line_discount_amount REAL, line_discount_type TEXT, item_tax_id INTEGER,"
      " item_tax REAL, sub_unit_id INTEGER, lot_number TEXT, mfg_date TEXT, exp_date TEXT,"
      " purchase_order_line_id INTEGER, purchase_requisition_line_id INTEGER)";

  //query to create purchase payment line table in database
  String createPurchasePaymentsTable =
      "CREATE TABLE purchase_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER,"
      " payment_id INTEGER DEFAULT null, method TEXT, amount REAL, note TEXT,"
      " account_id INTEGER DEFAULT null, paid_on TEXT)";

  //query to create cached suppliers table
  String createCachedSuppliersTable =
      "CREATE TABLE IF NOT EXISTS cached_suppliers (id INTEGER PRIMARY KEY, name TEXT, business_name TEXT,"
      " mobile TEXT, address_line_1 TEXT, city TEXT, state TEXT, country TEXT,"
      " zip_code TEXT, contact_id TEXT, pay_term_type TEXT, pay_term_number INTEGER,"
      " balance REAL, last_sync TEXT)";

  //query to create cached products table
  String createCachedProductsTable =
      "CREATE TABLE IF NOT EXISTS cached_products (id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER,"
      " product_name TEXT, product_type TEXT, variation_id INTEGER, variation_name TEXT,"
      " sub_sku TEXT, default_purchase_price REAL, last_sync TEXT)";

  //query to create cached locations table
  String createCachedLocationsTable =
      "CREATE TABLE IF NOT EXISTS cached_locations (id INTEGER PRIMARY KEY, name TEXT, location_id INTEGER,"
      " address TEXT, city TEXT, state TEXT, country TEXT, zip_code TEXT, last_sync TEXT)";

  // Utility method to check if table exists
  Future<bool> tableExists(String tableName) async {
    final db = await database;
    var result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'");
    return result.isNotEmpty;
  }

  // Utility method to drop table if exists (for testing/debugging)
  Future<void> dropTableIfExists(String tableName) async {
    final db = await database;
    await db.execute("DROP TABLE IF EXISTS $tableName");
  }

  //get database of type Future<database>
  Future<Database> get database async {
    // if database doesn't exists, create one
    if (_database == null) {
      _database = await initializeDatabase(Config.userId);
    }
    // if database exists, return database
    return _database!;
  }

  int currVersion = 9;

  //create tables during the creation of the database itself.
  Future<Database> initializeDatabase(loginUserId) async {
    Directory posDirectory = await getApplicationDocumentsDirectory();
    String path = join(posDirectory.path + 'PosDemo$loginUserId.db');
    if (Platform.isWindows || Platform.isLinux) {
      return await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
            version: currVersion,
            onCreate: (db, version) async {
              await db.execute(createSystemTable);
              await db.execute(createContactTable);
              await db.execute(createVariationTable);
              await db.execute(createVariationByLocationTable);
              await db.execute(createProductAvailableInLocationTable);
              await db.execute(createSellTable);
              await db.execute(createSellLineTable);
              await db.execute(createSellPaymentsTable);
              await db.execute(createPurchaseTable);
              await db.execute(createPurchaseLineTable);
              await db.execute(createPurchasePaymentsTable);
              await db.execute(createCachedSuppliersTable);
              await db.execute(createCachedProductsTable);
              await db.execute(createCachedLocationsTable);
            },
            onUpgrade: (db, oldVersion, newVersion) async {
              if (oldVersion < 2) {
                await db.execute(
                    "ALTER TABLE sell_lines RENAME TO prev_sell_line;");
                await db.execute(createSellLineTable);
                await db.execute(
                    "INSERT INTO sell_lines SELECT * FROM prev_sell_line;");
              }

              if (oldVersion < 3) {
                await db.execute(
                    "ALTER TABLE variations RENAME  TO prev_variations;");
                await db.execute(createVariationTable);
                await db.execute(
                    "INSERT INTO variations SELECT * FROM prev_variations;");
              }

              if (oldVersion < 4) {
                await db.execute(createContactTable);
              }

              if (oldVersion < 5) {
                await db.execute(
                    "ALTER TABLE sell ADD COLUMN invoice_url TEXT DEFAULT null;");
              }

              if (oldVersion < 6) {
                await db.execute(
                    "ALTER TABLE sell_payments ADD COLUMN account_id INTEGER DEFAULT null;");
              }

              if (oldVersion < 7) {
                await db.execute(createPurchaseTable);
                await db.execute(createPurchaseLineTable);
                await db.execute(createPurchasePaymentsTable);
              }

              if (oldVersion < 8) {
                await db.execute(createCachedSuppliersTable);
                await db.execute(createCachedProductsTable);
                await db.execute(createCachedLocationsTable);
              }

              if (oldVersion < 9) {
                // Add shipping_details column to purchase table
                await db.execute(
                    "ALTER TABLE purchase ADD COLUMN shipping_details TEXT");
              }

              db.setVersion(currVersion);
            },
          ));
    }
    return await openDatabase(
      path,
      version: currVersion,
      onCreate: (Database db, int version) async {
        await db.execute(createSystemTable);
        await db.execute(createContactTable);
        await db.execute(createVariationTable);
        await db.execute(createVariationByLocationTable);
        await db.execute(createProductAvailableInLocationTable);
        await db.execute(createSellTable);
        await db.execute(createSellLineTable);
        await db.execute(createSellPaymentsTable);
        await db.execute(createPurchaseTable);
        await db.execute(createPurchaseLineTable);
        await db.execute(createPurchasePaymentsTable);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE sell_lines RENAME TO prev_sell_line;");
          await db.execute(createSellLineTable);
          await db
              .execute("INSERT INTO sell_lines SELECT * FROM prev_sell_line;");
        }

        if (oldVersion < 3) {
          await db
              .execute("ALTER TABLE variations RENAME  TO prev_variations;");
          await db.execute(createVariationTable);
          await db
              .execute("INSERT INTO variations SELECT * FROM prev_variations;");
        }

        if (oldVersion < 4) {
          await db.execute(createContactTable);
        }

        if (oldVersion < 5) {
          await db.execute(
              "ALTER TABLE sell ADD COLUMN invoice_url TEXT DEFAULT null;");
        }

        if (oldVersion < 6) {
          await db.execute(
              "ALTER TABLE sell_payments ADD COLUMN account_id INTEGER DEFAULT null;");
        }

        if (oldVersion < 7) {
          await db.execute(createPurchaseTable);
          await db.execute(createPurchaseLineTable);
          await db.execute(createPurchasePaymentsTable);
        }

        if (oldVersion < 9) {
          // Add shipping_details column to purchase table
          await db
              .execute("ALTER TABLE purchase ADD COLUMN shipping_details TEXT");
        }

        db.setVersion(currVersion);
      },
    );
  }
}
