const sequelize = require('../config/db');

const User = require('./User');

const initCategory = require('./Category');
const initSubcategory = require('./Subcategory');
const initUnit = require('./Unit');
const initSupplier = require('./supplier');
const initCustomer = require('./customer');
const initProduct = require('./Product');
const initCustomerPrice = require('./CustomerPrice');
const initProductImage = require('./ProductImage');
const initPurchaseOrder = require('./PurchaseOrder');
const initPurchaseOrderItem = require('./PurchaseOrderItem');
const initPurchaseReceipt = require('./PurchaseReceipt');
const initPurchaseReceiptItem = require('./PurchaseReceiptItem');
const initSupplierLedger = require('./SupplierLedger');
const initSale = require('./Sale');
const initSaleItem = require('./SaleItem');
const initCustomerLedger = require('./CustomerLedger');
const initBank = require('./Bank');
const initBankTransaction = require('./BankTransaction');
const initBankTransfer = require('./BankTransfer');
const initCheque = require('./Cheque');
const initCashbook = require('./Cashbook');          // ADD

const Category = initCategory(sequelize);
const Subcategory = initSubcategory(sequelize);
const Unit = initUnit(sequelize);
const Supplier = initSupplier(sequelize);
const Customer = initCustomer(sequelize);
const Product = initProduct(sequelize);
const CustomerPrice = initCustomerPrice(sequelize);
const ProductImage = initProductImage(sequelize);
const PurchaseOrder = initPurchaseOrder(sequelize);
const PurchaseOrderItem = initPurchaseOrderItem(sequelize);
const PurchaseReceipt = initPurchaseReceipt(sequelize);
const PurchaseReceiptItem = initPurchaseReceiptItem(sequelize);
const SupplierLedger = initSupplierLedger(sequelize);
const Sale = initSale(sequelize);
const SaleItem = initSaleItem(sequelize);
const CustomerLedger = initCustomerLedger(sequelize);
const Bank = initBank(sequelize);
const BankTransaction = initBankTransaction(sequelize);
const BankTransfer = initBankTransfer(sequelize);
const Cheque = initCheque(sequelize);
const Cashbook = initCashbook(sequelize);            // ADD

// ── Associations (unchanged) ─────────────────────────────────────────────────

Category.hasMany(Subcategory, { foreignKey: 'category_id', as: 'subcategories' });
Subcategory.belongsTo(Category, { foreignKey: 'category_id', as: 'category' });

Product.belongsTo(Supplier, { foreignKey: 'supplier_id', as: 'supplier' });
Product.belongsTo(Category, { foreignKey: 'category_id', as: 'category' });
Product.belongsTo(Subcategory, { foreignKey: 'subcategory_id', as: 'subcategory' });
Product.belongsTo(Unit, { foreignKey: 'unit_id', as: 'unit' });
Product.hasMany(CustomerPrice, { foreignKey: 'product_id', as: 'customerPrices' });
Product.hasMany(ProductImage, { foreignKey: 'product_id', as: 'images', onDelete: 'CASCADE' });

ProductImage.belongsTo(Product, { foreignKey: 'product_id', as: 'product' });

CustomerPrice.belongsTo(Product, { foreignKey: 'product_id', as: 'product' });
CustomerPrice.belongsTo(Customer, { foreignKey: 'customer_id', as: 'customer' });

Customer.hasMany(CustomerPrice, { foreignKey: 'customer_id', as: 'prices' });
Customer.hasMany(CustomerLedger, { foreignKey: 'customer_id', as: 'ledgerEntries', onDelete: 'CASCADE' });
Customer.hasMany(Sale, { foreignKey: 'customer_id', as: 'sales' });

CustomerLedger.belongsTo(Customer, { foreignKey: 'customer_id', as: 'customer' });

Supplier.hasMany(Product, { foreignKey: 'supplier_id', as: 'products' });
Supplier.hasMany(SupplierLedger, { foreignKey: 'supplier_id', as: 'ledgerEntries' });

SupplierLedger.belongsTo(Supplier, { foreignKey: 'supplier_id', as: 'supplier' });

Unit.hasMany(Product, { foreignKey: 'unit_id', as: 'products' });

PurchaseOrder.belongsTo(Supplier, { foreignKey: 'supplier_id', as: 'supplier' });
PurchaseOrder.belongsTo(User, { foreignKey: 'created_by', as: 'creator' });
PurchaseOrder.hasMany(PurchaseOrderItem, { foreignKey: 'purchase_order_id', as: 'items', onDelete: 'CASCADE' });
PurchaseOrder.hasMany(PurchaseReceipt, { foreignKey: 'purchase_order_id', as: 'receipts' });

PurchaseOrderItem.belongsTo(PurchaseOrder, { foreignKey: 'purchase_order_id', as: 'purchaseOrder' });
PurchaseOrderItem.belongsTo(Product, { foreignKey: 'product_id', as: 'product' });
PurchaseOrderItem.hasMany(PurchaseReceiptItem, { foreignKey: 'purchase_order_item_id', as: 'receiptItems' });

PurchaseReceipt.belongsTo(PurchaseOrder, { foreignKey: 'purchase_order_id', as: 'purchaseOrder' });
PurchaseReceipt.belongsTo(User, { foreignKey: 'created_by', as: 'creator' });
PurchaseReceipt.hasMany(PurchaseReceiptItem, { foreignKey: 'purchase_receipt_id', as: 'items', onDelete: 'CASCADE' });

PurchaseReceiptItem.belongsTo(PurchaseReceipt, { foreignKey: 'purchase_receipt_id', as: 'purchaseReceipt' });
PurchaseReceiptItem.belongsTo(PurchaseOrderItem, { foreignKey: 'purchase_order_item_id', as: 'purchaseOrderItem' });
PurchaseReceiptItem.belongsTo(Product, { foreignKey: 'product_id', as: 'product' });

Sale.belongsTo(Customer, { foreignKey: 'customer_id', as: 'customer' });
Sale.hasMany(SaleItem, { foreignKey: 'sale_id', as: 'items', onDelete: 'CASCADE' });

SaleItem.belongsTo(Sale, { foreignKey: 'sale_id', as: 'sale' });
SaleItem.belongsTo(Product, { foreignKey: 'product_id', as: 'product' });

Bank.hasMany(BankTransaction, { foreignKey: 'bank_id', as: 'transactions', onDelete: 'CASCADE' });
Bank.hasMany(Cheque, { foreignKey: 'bank_id', as: 'cheques', onDelete: 'CASCADE' });

BankTransaction.belongsTo(Bank, { foreignKey: 'bank_id', as: 'bank' });
BankTransaction.belongsTo(User, { foreignKey: 'created_by', as: 'creator' });

BankTransfer.belongsTo(Bank, { foreignKey: 'from_bank_id', as: 'fromBank' });
BankTransfer.belongsTo(Bank, { foreignKey: 'to_bank_id', as: 'toBank' });
BankTransfer.belongsTo(User, { foreignKey: 'created_by', as: 'creator' });
BankTransfer.belongsTo(BankTransaction, { foreignKey: 'debit_transaction_id', as: 'debitTransaction' });
BankTransfer.belongsTo(BankTransaction, { foreignKey: 'credit_transaction_id', as: 'creditTransaction' });

Cheque.belongsTo(Bank, { foreignKey: 'bank_id', as: 'bank' });
Cheque.belongsTo(User, { foreignKey: 'created_by', as: 'creator' });
Cheque.belongsTo(BankTransaction, { foreignKey: 'bank_transaction_id', as: 'clearedTransaction' });

// Cashbook has no FK associations — standalone table
// (reference_id is a logical pointer, not a DB foreign key)

module.exports = {
  User,
  Category,
  Subcategory,
  Unit,
  Supplier,
  Customer,
  Product,
  CustomerPrice,
  ProductImage,
  PurchaseOrder,
  PurchaseOrderItem,
  PurchaseReceipt,
  PurchaseReceiptItem,
  SupplierLedger,
  Sale,
  SaleItem,
  CustomerLedger,
  Bank,
  BankTransaction,
  BankTransfer,
  Cheque,
  Cashbook,                                          // ADD
  sequelize,
};