// lib/config/api_config.dart

class ApiConfig {

  static const String baseUrl = 'http://localhost:3000/api';

  // ── Auth ─────────────────────────────────────────────────────────
  static const String registerUrl = '$baseUrl/auth/register';
  static const String loginUrl    = '$baseUrl/auth/login';
  static const String getMeUrl    = '$baseUrl/auth/me';

  // ── Products ─────────────────────────────────────────────────────
  static const String productsUrl = '$baseUrl/products';
  static String productUrl(int id)               => '$baseUrl/products/$id';
  static String toggleProductStatusUrl(int id)   => '$baseUrl/products/$id/toggle-status';
  static String updateProductQuantityUrl(int id) => '$baseUrl/products/$id/quantity';
  static String productByBarcodeUrl(String barcode) => '$baseUrl/products/barcode/$barcode';

  // ── Customer Prices ──────────────────────────────────────────────
  static const String customerPricesUrl    = '$baseUrl/customer-prices';
  static String customerPriceUrl(int id)   => '$baseUrl/customer-prices/$id';
  static String toggleCustomerPriceStatusUrl(int id) =>
      '$baseUrl/customer-prices/$id/toggle-status';
  static const String bulkCustomerPricesUrl = '$baseUrl/customer-prices/bulk';

  // ── Customers ────────────────────────────────────────────────────
  static const String customersUrl              = '$baseUrl/customers';
  static String customerUrl(int id)             => '$baseUrl/customers/$id';
  static String toggleCustomerStatusUrl(int id) => '$baseUrl/customers/$id/toggle-status';
  static String customerBalanceUrl(int id)      => '$baseUrl/customers/$id/balance';

  // ── Suppliers ────────────────────────────────────────────────────
  static const String suppliersUrl = '$baseUrl/suppliers';
  static String supplierUrl(int id)              => '$baseUrl/suppliers/$id';
  static String supplierLedgerUrl(int id)        => '$baseUrl/suppliers/$id/ledger';

  // ── Purchase Orders ──────────────────────────────────────────────
  static const String purchaseOrdersUrl = '$baseUrl/purchase-orders';
  static String purchaseOrderUrl(int id)         => '$baseUrl/purchase-orders/$id';
  static String purchaseOrderReceiptsUrl(int id) => '$baseUrl/purchase-orders/$id/receipts';

  // ── Purchase Receipts ────────────────────────────────────────────
  static const String createReceiptUrl           = '$baseUrl/purchase-orders/receipts';
  static String receiptByIdUrl(int id)           => '$baseUrl/purchase-orders/receipts/$id';
  static String deleteReceiptUrl(int id)         => '$baseUrl/purchase-orders/receipts/$id';

  // ── Sales ────────────────────────────────────────────────────────
  static const String salesUrl                   = '$baseUrl/sales';
  static String saleUrl(int id)                  => '$baseUrl/sales/$id';
  static const String salesDailySummaryUrl       = '$baseUrl/sales/summary/daily';
  static String salePaymentUrl(int id)           => '$baseUrl/sales/$id/payment';
}