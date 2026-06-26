// import 'network_discovery.dart';
//
// class ApiConfig {
//   static String? _baseUrl;
//
//   /// Initialize API base URL (CALL ON APP START)
//   static Future<void> init() async {
//     _baseUrl = await NetworkDiscovery.discoverServer();
//
//     if (_baseUrl == null) {
//       throw Exception(
//         "❌ Server not found on LAN. Check WiFi, firewall, or server running.",
//       );
//     }
//
//     print('🌐 API Base URL: $_baseUrl');
//   }
//
//   /// Safe getter
//   static String get baseUrl {
//     if (_baseUrl == null) {
//       throw Exception(
//         'ApiConfig not initialized. Call ApiConfig.init() in main()',
//       );
//     }
//     return _baseUrl!;
//   }
//
//   // ── AUTH ─────────────────────────────────────────────
//   static String get registerUrl => '$baseUrl/auth/register';
//   static String get loginUrl => '$baseUrl/auth/login';
//   static String get getMeUrl => '$baseUrl/auth/me';
//
//   // ── PRODUCTS ────────────────────────────────────────
//   static String get productsUrl => '$baseUrl/products';
//   static String productUrl(int id) => '$baseUrl/products/$id';
//   static String toggleProductStatusUrl(int id) =>
//       '$baseUrl/products/$id/toggle-status';
//   static String updateProductQuantityUrl(int id) =>
//       '$baseUrl/products/$id/quantity';
//   static String productByBarcodeUrl(String barcode) =>
//       '$baseUrl/products/barcode/$barcode';
//
//   // ── CUSTOMER PRICES ─────────────────────────────────
//   static String get customerPricesUrl => '$baseUrl/customer-prices';
//   static String customerPriceUrl(int id) =>
//       '$baseUrl/customer-prices/$id';
//   static String toggleCustomerPriceStatusUrl(int id) =>
//       '$baseUrl/customer-prices/$id/toggle-status';
//   static String get bulkCustomerPricesUrl =>
//       '$baseUrl/customer-prices/bulk';
//
//   // ── CUSTOMERS ───────────────────────────────────────
//   static String get customersUrl => '$baseUrl/customers';
//   static String customerUrl(int id) => '$baseUrl/customers/$id';
//   static String toggleCustomerStatusUrl(int id) =>
//       '$baseUrl/customers/$id/toggle-status';
//   static String customerBalanceUrl(int id) =>
//       '$baseUrl/customers/$id/balance';
//
//   // ── SUPPLIERS ───────────────────────────────────────
//   static String get suppliersUrl => '$baseUrl/suppliers';
//   static String supplierUrl(int id) => '$baseUrl/suppliers/$id';
//   static String supplierLedgerUrl(int id) =>
//       '$baseUrl/suppliers/$id/ledger';
//
//   // ── PURCHASE ORDERS ────────────────────────────────
//   static String get purchaseOrdersUrl => '$baseUrl/purchase-orders';
//   static String purchaseOrderUrl(int id) =>
//       '$baseUrl/purchase-orders/$id';
//   static String purchaseOrderReceiptsUrl(int id) =>
//       '$baseUrl/purchase-orders/$id/receipts';
//
//   // ── PURCHASE RECEIPTS ──────────────────────────────
//   static String get createReceiptUrl =>
//       '$baseUrl/purchase-orders/receipts';
//   static String receiptByIdUrl(int id) =>
//       '$baseUrl/purchase-orders/receipts/$id';
//   static String deleteReceiptUrl(int id) =>
//       '$baseUrl/purchase-orders/receipts/$id';
//
//   // ── SALES ───────────────────────────────────────────
//   static String get salesUrl => '$baseUrl/sales';
//   static String saleUrl(int id) => '$baseUrl/sales/$id';
//   static String get salesDailySummaryUrl =>
//       '$baseUrl/sales/summary/daily';
//   static String salePaymentUrl(int id) =>
//       '$baseUrl/sales/$id/payment';
//
//   // ── SALE RETURNS ────────────────────────────────────
//   static String get saleReturnsUrl => '$baseUrl/sales/returns';
//   static String saleReturnUrl(int id) =>
//       '$baseUrl/sales/returns/$id';
//   static String saleReturnsBySaleUrl(int id) =>
//       '$baseUrl/sales/$id/returns';
// }

class ApiConfig {
  /// 🌐 VPS / Production Base URL (NO DISCOVERY)
  static const String baseUrl = 'http://72.60.40.108:3000/api';

  // ── AUTH ─────────────────────────────────────────────
  static String get registerUrl => '$baseUrl/auth/register';
  static String get loginUrl => '$baseUrl/auth/login';
  static String get getMeUrl => '$baseUrl/auth/me';

  // ── PRODUCTS ────────────────────────────────────────
  static String get productsUrl => '$baseUrl/products';
  static String productUrl(int id) => '$baseUrl/products/$id';
  static String toggleProductStatusUrl(int id) =>
      '$baseUrl/products/$id/toggle-status';
  static String updateProductQuantityUrl(int id) =>
      '$baseUrl/products/$id/quantity';
  static String productByBarcodeUrl(String barcode) =>
      '$baseUrl/products/barcode/$barcode';

  // ── CUSTOMER PRICES ─────────────────────────────────
  static String get customerPricesUrl => '$baseUrl/customer-prices';
  static String customerPriceUrl(int id) =>
      '$baseUrl/customer-prices/$id';
  static String toggleCustomerPriceStatusUrl(int id) =>
      '$baseUrl/customer-prices/$id/toggle-status';
  static String get bulkCustomerPricesUrl =>
      '$baseUrl/customer-prices/bulk';

  // ── CUSTOMERS ───────────────────────────────────────
  static String get customersUrl => '$baseUrl/customers';
  static String customerUrl(int id) => '$baseUrl/customers/$id';
  static String toggleCustomerStatusUrl(int id) =>
      '$baseUrl/customers/$id/toggle-status';
  static String customerBalanceUrl(int id) =>
      '$baseUrl/customers/$id/balance';

  // ── SUPPLIERS ───────────────────────────────────────
  static String get suppliersUrl => '$baseUrl/suppliers';
  static String supplierUrl(int id) => '$baseUrl/suppliers/$id';
  static String supplierLedgerUrl(int id) =>
      '$baseUrl/suppliers/$id/ledger';

  // ── PURCHASE ORDERS ────────────────────────────────
  static String get purchaseOrdersUrl => '$baseUrl/purchase-orders';
  static String purchaseOrderUrl(int id) =>
      '$baseUrl/purchase-orders/$id';
  static String purchaseOrderReceiptsUrl(int id) =>
      '$baseUrl/purchase-orders/$id/receipts';

  // ── PURCHASE RECEIPTS ──────────────────────────────
  static String get createReceiptUrl =>
      '$baseUrl/purchase-orders/receipts';
  static String receiptByIdUrl(int id) =>
      '$baseUrl/purchase-orders/receipts/$id';
  static String deleteReceiptUrl(int id) =>
      '$baseUrl/purchase-orders/receipts/$id';

  // ── SALES ───────────────────────────────────────────
  static String get salesUrl => '$baseUrl/sales';
  static String saleUrl(int id) => '$baseUrl/sales/$id';
  static String get salesDailySummaryUrl =>
      '$baseUrl/sales/summary/daily';
  static String salePaymentUrl(int id) =>
      '$baseUrl/sales/$id/payment';

  // ── SALE RETURNS ────────────────────────────────────
  static String get saleReturnsUrl => '$baseUrl/sales/returns';
  static String saleReturnUrl(int id) =>
      '$baseUrl/sales/returns/$id';
  static String saleReturnsBySaleUrl(int id) =>
      '$baseUrl/sales/$id/returns';
}