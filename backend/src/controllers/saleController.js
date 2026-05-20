const { Op, fn, col } = require('sequelize');
const sequelize = require('../config/db');
// const { Sale, SaleItem, Customer, Product, Unit, Category, CustomerLedger } = require('../models');
const { Sale, SaleItem, Customer, Product, Unit, Category, CustomerLedger, Bank, BankTransaction, Cheque } = require('../models');
const { createCashbookEntry } = require('./cashbookController');

// ─────────────────────────────────────────────
//  HELPER: generate invoice number
// ─────────────────────────────────────────────
async function generateInvoiceNumber(type) {
  const prefix = type === 'invoice' ? 'INV' : 'POS';
  const today = new Date();
  const datePart = `${today.getFullYear()}${String(today.getMonth() + 1).padStart(2, '0')}${String(today.getDate()).padStart(2, '0')}`;

  const last = await Sale.findOne({
    where: { invoice_number: { [Op.like]: `${prefix}-${datePart}-%` } },
    order: [['id', 'DESC']],
  });

  let seq = 1;
  if (last) {
    const parts = last.invoice_number.split('-');
    seq = parseInt(parts[parts.length - 1]) + 1;
  }

  return `${prefix}-${datePart}-${String(seq).padStart(4, '0')}`;
}

async function getCustomerBalance(customerId, transaction) {
  const lastEntry = await CustomerLedger.findOne({
    where: { customer_id: customerId },
    order: [['id', 'DESC']],
    transaction,
  });
  return lastEntry ? parseFloat(lastEntry.balance) : 0;
}

async function createLedgerEntry({
  customerId, date, transactionType, referenceId,
  referenceNumber, description, debit = 0, credit = 0, transaction,
  paymentMethod, bankName, bankId, chequeNumber, chequeDate,  // ADD THESE
}) {
  const currentBalance = await getCustomerBalance(customerId, transaction);
  const newBalance = currentBalance + credit - debit;

  return await CustomerLedger.create({
    customer_id: customerId,
    date: date || new Date(),
    transaction_type: transactionType,
    reference_id: referenceId,
    reference_number: referenceNumber,
    description,
    debit,
    credit,
    balance: newBalance,
    payment_method: paymentMethod || null,      // ADD
    bank_name: bankName || null,                // ADD
    bank_id: bankId || null,                    // ADD
    cheque_number: chequeNumber || null,         // ADD
    cheque_date: chequeDate || null,            // ADD
  }, { transaction });
}

function parseLengthFields(item) {
  let selectedLengths = null;
  let lengthQuantities = null;
  let selectedLengthsDisplay = null;
  let totalPieces = null;

  if (!Array.isArray(item.selected_lengths) || item.selected_lengths.length === 0) {
    return { selectedLengths, lengthQuantities, selectedLengthsDisplay, totalPieces };
  }

  selectedLengths = item.selected_lengths.map(String);

  if (item.length_quantities && typeof item.length_quantities === 'object') {
    lengthQuantities = {};
    let pieces = 0;

    for (const len of selectedLengths) {
      const rawQty = item.length_quantities[len];
      const parsedQty = rawQty != null ? (parseFloat(rawQty) || 1) : 1;
      lengthQuantities[len] = parsedQty;
      pieces += parsedQty;
    }

    totalPieces = Math.round(pieces);
    selectedLengthsDisplay = selectedLengths
      .map(len => `${len} (${Math.round(lengthQuantities[len])})`)
      .join(', ');

  } else {
    lengthQuantities = {};
    selectedLengths.forEach(len => { lengthQuantities[len] = 1; });
    totalPieces = selectedLengths.length;
    selectedLengthsDisplay = selectedLengths.map(len => `${len} (1)`).join(', ');
  }

  return { selectedLengths, lengthQuantities, selectedLengthsDisplay, totalPieces };
}

function normalizePaymentMethod(method) {
  const map = {
    'bank': 'bank',
    'bank_transfer': 'bank_transfer',
    'cheque': 'cheque',
    'slip': 'slip',
    'cash': 'cash',
    'card': 'card',
    'credit': 'credit',
  };
  return map[method] || 'cash';
}

exports.getAllSales = async (req, res) => {
  try {
    const {
      page = 1, limit = 20, search, sale_type, sale_category, payment_status,
      payment_method, customer_id, date_from, date_to,
      sort_by = 'created_at', sort_order = 'DESC',
    } = req.query;

    const pageNum = parseInt(page);
    const limitNum = parseInt(limit);
    const offset = (pageNum - 1) * limitNum;
    const whereClause = {};

    let includeCustomer = false;
    if (search) includeCustomer = true;
    if (sale_type) whereClause.sale_type = sale_type;
    if (sale_category) whereClause.sale_category = sale_category;
    if (payment_status) whereClause.payment_status = payment_status;
    if (payment_method) whereClause.payment_method = payment_method;
    if (customer_id) { whereClause.customer_id = customer_id; includeCustomer = true; }
    if (date_from || date_to) {
      whereClause.sale_date = {};
      if (date_from) whereClause.sale_date[Op.gte] = date_from;
      if (date_to) whereClause.sale_date[Op.lte] = date_to;
    }

    const include = [
      {
        model: Customer, as: 'customer',
        attributes: ['id', 'name', 'contact', 'customer_type'],
        required: includeCustomer ? true : false,
        ...(search ? { where: { name: { [Op.like]: `%${search}%` } } } : {})
      },
      {
        model: SaleItem, as: 'items',
        attributes: [
          'id', 'product_name', 'quantity', 'unit_price', 'total_price',
          'selected_lengths', 'length_quantities', 'selected_lengths_display',
          'total_pieces', 'weight', 'used_customer_price'
        ],
        include: [
          { model: Product, as: 'product', attributes: ['id', 'item_name', 'barcode'], required: false },
        ],
      },
    ];

    const mainWhereClause = { ...whereClause };
    if (search && !includeCustomer) {
      mainWhereClause.invoice_number = { [Op.like]: `%${search}%` };
    }

    const { count, rows: sales } = await Sale.findAndCountAll({
      where: mainWhereClause, include,
      order: [[sort_by, sort_order]],
      limit: limitNum, offset, distinct: true, subQuery: false,
    });

    let summaryQuery = {
      where: { ...whereClause },
      attributes: [
        [fn('SUM', col('Sale.grand_total')), 'total_revenue'],
        [fn('SUM', col('Sale.discount_amount')), 'total_discount'],
        [fn('COUNT', col('Sale.id')), 'total_transactions'],
      ],
      raw: true,
    };

    if (search) {
      summaryQuery.include = [
        { model: Customer, as: 'customer', required: true, where: { name: { [Op.like]: `%${search}%` } }, attributes: [] }
      ];
      summaryQuery.where = {
        ...whereClause,
        [Op.or]: [
          { invoice_number: { [Op.like]: `%${search}%` } },
          { '$customer.name$': { [Op.like]: `%${search}%` } }
        ]
      };
    }

    const totals = await Sale.findOne(summaryQuery);

    res.json({
      success: true, data: sales,
      pagination: { total: count, page: pageNum, limit: limitNum, pages: Math.ceil(count / limitNum) },
      summary: {
        total_revenue: parseFloat(totals?.total_revenue) || 0,
        total_discount: parseFloat(totals?.total_discount) || 0,
        total_transactions: parseInt(totals?.total_transactions) || 0,
      },
    });
  } catch (error) {
    console.error('Get all sales error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.getSaleById = async (req, res) => {
  try {
    const { id } = req.params;

    const sale = await Sale.findByPk(id, {
      include: [
        { model: Customer, as: 'customer', attributes: ['id', 'name', 'contact', 'address', 'email', 'customer_type'] },
        {
          model: SaleItem, as: 'items',
          include: [
            {
              model: Product, as: 'product',
              attributes: ['id', 'item_name', 'barcode', 'sale_price', 'cost_price',
                           'length_combinations', 'has_multiple_lengths'],
              include: [{ model: Unit, as: 'unit', attributes: ['id', 'name', 'symbol'] }],
            },
          ],
        },
      ],
    });

    if (!sale) return res.status(404).json({ success: false, message: 'Sale not found' });

    res.json({ success: true, data: sale });
  } catch (error) {
    console.error('Get sale by id error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.createSale = async (req, res) => {
  const t = await sequelize.transaction();
  try {
    const {
      sale_type = 'pos',
      sale_category = 'filled',
      customer_id,
      sale_date,
      due_date,
      items,
      discount_type = 'fixed',
      discount_value = 0,
      payment_method: rawPaymentMethod = 'cash',
      payment_status,
      amount_paid = 0,
      notes,
      credit_details,
      reference,
    } = req.body;

    const payment_method = normalizePaymentMethod(rawPaymentMethod);
    const isSarya = sale_category === 'sarya';

    console.log('Creating sale:', { sale_type, sale_category, isSarya, itemsCount: items?.length });

    if (!items || !Array.isArray(items) || items.length === 0) {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'Sale must have at least one item' });
    }

    if (sale_type === 'invoice' && !customer_id) {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'Invoice requires a customer' });
    }

    if (customer_id) {
      const customer = await Customer.findByPk(customer_id, { transaction: t });
      if (!customer) {
        await t.rollback();
        return res.status(404).json({ success: false, message: 'Customer not found' });
      }
    }

    let subtotal = 0;
    const itemSnapshots = [];

    for (const item of items) {
      if (!item.product_id) {
        await t.rollback();
        return res.status(400).json({ success: false, message: 'Each item must have a product_id' });
      }

      const product = await Product.findByPk(item.product_id, { transaction: t });
      if (!product) {
        await t.rollback();
        return res.status(404).json({ success: false, message: `Product id ${item.product_id} not found` });
      }

      let quantity = 0;
      let weight = null;
      let totalPrice = 0;
      const unitPrice = parseFloat(item.unit_price ?? product.sale_price);

      if (isSarya) {
        // SARYA mode: weight is required, quantity is ALWAYS 0
        weight = item.weight != null ? parseFloat(item.weight) : null;
        if (!weight || weight <= 0) {
          await t.rollback();
          return res.status(400).json({
            success: false,
            message: `SARYA mode requires a valid weight > 0 for each item (product_id: ${item.product_id})`,
          });
        }
        quantity = 0; // ✅ CRITICAL: Set quantity to 0 for weight-based items
        totalPrice = weight * unitPrice;
        console.log(`SARYA item: product=${product.item_name}, weight=${weight}kg, price=${unitPrice}/kg, total=${totalPrice}, quantity=0`);
      } else {
        // FILLED mode: quantity is required
        quantity = item.quantity ? parseInt(item.quantity) : 0;
        if (!quantity || quantity < 1) {
          await t.rollback();
          return res.status(400).json({
            success: false,
            message: `Each item must have quantity >= 1 (product_id: ${item.product_id})`,
          });
        }
        totalPrice = unitPrice * quantity;
        
        // Stock check only for FILLED mode
        if (product.available_qty < quantity) {
          await t.rollback();
          return res.status(400).json({
            success: false,
            message: `Insufficient stock for "${product.item_name}". Available: ${product.available_qty}`,
          });
        }
        
        console.log(`FILLED item: product=${product.item_name}, quantity=${quantity}, price=${unitPrice}, total=${totalPrice}`);
      }

      subtotal += totalPrice;

      const { selectedLengths, lengthQuantities, selectedLengthsDisplay, totalPieces } = parseLengthFields(item);

      itemSnapshots.push({
        product_id: product.id,
        product_name: product.item_name,
        barcode: product.barcode,
        unit_price: unitPrice,
        quantity: quantity, // Will be 0 for SARYA, >0 for FILLED
        total_price: totalPrice,
        selected_lengths: selectedLengths,
        length_quantities: lengthQuantities,
        selected_lengths_display: selectedLengthsDisplay,
        total_pieces: totalPieces,
        weight: weight,
        used_customer_price: item.used_customer_price === true,
        _available_qty: product.available_qty,
        _isSarya: isSarya,
      });
    }

    let discountAmount = 0;
    const discountVal = parseFloat(discount_value) || 0;

    if (discount_type === 'percent') {
      discountAmount = subtotal * (discountVal / 100);
    } else {
      discountAmount = discountVal;
    }
    discountAmount = Math.min(discountAmount, subtotal);
    const grandTotal = subtotal - discountAmount;

    const isCredit = payment_method === 'credit';
    const paid = isCredit ? 0 : (parseFloat(amount_paid) || (sale_type === 'pos' ? grandTotal : 0));
    const changeAmount = Math.max(paid - grandTotal, 0);

    let resolvedPaymentStatus = payment_status;
    if (!resolvedPaymentStatus) {
      if (isCredit) {
        resolvedPaymentStatus = 'unpaid';
      } else if (sale_type === 'pos') {
        resolvedPaymentStatus = 'paid';
      } else {
        resolvedPaymentStatus = paid >= grandTotal ? 'paid' : paid > 0 ? 'partial' : 'unpaid';
      }
    }

    const invoiceNumber = await generateInvoiceNumber(sale_type);

    let finalNotes = notes || '';
    if (isCredit && credit_details) {
      const creditNotes = [];
      if (credit_details.notes) creditNotes.push(`Credit Note: ${credit_details.notes}`);
      if (credit_details.due_date) {
        const dueDate = new Date(credit_details.due_date);
        creditNotes.push(`Due Date: ${dueDate.toISOString().split('T')[0]}`);
      }
      if (creditNotes.length > 0) {
        finalNotes = finalNotes ? `${finalNotes}\n${creditNotes.join('\n')}` : creditNotes.join('\n');
      }
    }

    const sale = await Sale.create(
      {
        invoice_number: invoiceNumber,
        sale_type,
        sale_category,
        customer_id: customer_id || null,
        sale_date: sale_date || new Date(),
        due_date: isCredit && credit_details?.due_date ? credit_details.due_date : due_date || null,
        subtotal,
        discount_type,
        discount_value: discountVal,
        discount_amount: discountAmount,
        tax_amount: 0,
        grand_total: grandTotal,
        amount_paid: paid,
        change_amount: changeAmount,
        payment_method,
        payment_status: resolvedPaymentStatus,
        notes: finalNotes || null,
        reference: reference || null,
      },
      { transaction: t }
    );

    const saleItems = itemSnapshots.map(({ _available_qty, _isSarya, ...snap }) => ({
      ...snap,
      sale_id: sale.id,
    }));
    await SaleItem.bulkCreate(saleItems, { transaction: t });

    // Deduct stock only for FILLED mode (quantity > 0)
    for (const snap of itemSnapshots) {
      if (!snap._isSarya && snap.quantity > 0) {
        await Product.decrement(
          { physical_qty: snap.quantity, available_qty: snap.quantity },
          { where: { id: snap.product_id }, transaction: t }
        );
      }
    }

    if (customer_id) {
      const saleAmount = isCredit ? grandTotal : (grandTotal - paid);

      if (saleAmount > 0) {
        await createLedgerEntry({
          customerId: customer_id,
          date: sale_date || new Date(),
          transactionType: 'sale',
          referenceId: sale.id,
          referenceNumber: invoiceNumber,
          description: `Sale ${invoiceNumber} - ${sale_type === 'invoice' ? 'Invoice' : 'POS'}${isCredit ? ' (Credit)' : ''}${isSarya ? ' [SARYA]' : ''}`,
          debit: 0,
          credit: saleAmount,
          transaction: t,
        });
      }

      if (paid > 0) {
        await createLedgerEntry({
          customerId: customer_id,
          date: sale_date || new Date(),
          transactionType: 'payment',
          referenceId: sale.id,
          referenceNumber: invoiceNumber,
          description: `Payment received for ${invoiceNumber} (${payment_method})`,
          debit: paid,
          credit: 0,
          transaction: t,
        });
      }

      const finalBalance = await getCustomerBalance(customer_id, t);
      await Customer.update({ balance: finalBalance }, { where: { id: customer_id }, transaction: t });
    }

    await t.commit();

    const created = await Sale.findByPk(sale.id, {
      include: [
        { model: Customer, as: 'customer', attributes: ['id', 'name', 'contact', 'balance'] },
        {
          model: SaleItem, as: 'items',
          include: [
            {
              model: Product, as: 'product',
              attributes: ['id', 'item_name', 'barcode'],
              include: [{ model: Unit, as: 'unit', attributes: ['id', 'name', 'symbol'] }],
            },
          ],
        },
      ],
    });

    console.log('Sale created successfully:', { 
      invoiceNumber, 
      itemsCount: saleItems.length,
      saryaItems: saleItems.filter(i => i.weight > 0 && i.quantity === 0).length,
      filledItems: saleItems.filter(i => i.quantity > 0).length
    });

    const message = isCredit
      ? `${sale_type === 'invoice' ? 'Credit invoice' : 'Credit sale'} created successfully`
      : `${sale_type === 'invoice' ? 'Invoice' : 'Sale'} created successfully`;

    res.status(201).json({ success: true, message, data: created });
  } catch (error) {
    await t.rollback();
    console.error('Create sale error:', error);

    if (error.name === 'SequelizeValidationError') {
      return res.status(400).json({
        success: false,
        message: 'Validation error',
        errors: error.errors.map((e) => e.message),
      });
    }

    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.updateSale = async (req, res) => {
  try {
    const { id } = req.params;
    const { due_date, payment_status, payment_method: rawPaymentMethod, amount_paid, notes, reference } = req.body;

    const sale = await Sale.findByPk(id);
    if (!sale) return res.status(404).json({ success: false, message: 'Sale not found' });

    if (sale.payment_status === 'paid' && payment_status && payment_status !== 'paid') {
      return res.status(400).json({ success: false, message: 'Cannot change status of a fully paid sale' });
    }

    const payment_method = rawPaymentMethod ? normalizePaymentMethod(rawPaymentMethod) : undefined;

    await sale.update({
      due_date: due_date !== undefined ? due_date : sale.due_date,
      payment_status: payment_status || sale.payment_status,
      payment_method: payment_method || sale.payment_method,
      amount_paid: amount_paid !== undefined ? parseFloat(amount_paid) : sale.amount_paid,
      notes: notes !== undefined ? notes : sale.notes,
      reference: reference !== undefined ? reference : sale.reference,
    });

    const updated = await Sale.findByPk(id, {
      include: [
        { model: Customer, as: 'customer', attributes: ['id', 'name', 'contact'] },
        {
          model: SaleItem, as: 'items',
          include: [{ model: Product, as: 'product', attributes: ['id', 'item_name', 'barcode'] }],
        },
      ],
    });

    res.json({ success: true, message: 'Sale updated successfully', data: updated });
  } catch (error) {
    console.error('Update sale error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.deleteSale = async (req, res) => {
  const t = await sequelize.transaction();
  try {
    const { id } = req.params;

    const sale = await Sale.findByPk(id, { include: [{ model: SaleItem, as: 'items' }] });
    if (!sale) {
      await t.rollback();
      return res.status(404).json({ success: false, message: 'Sale not found' });
    }

    const isSarya = sale.sale_category === 'sarya';
    if (!isSarya) {
      for (const item of sale.items) {
        await Product.increment(
          { physical_qty: item.quantity, available_qty: item.quantity },
          { where: { id: item.product_id }, transaction: t }
        );
      }
    }

    if (sale.customer_id) {
      const unpaidAmount = parseFloat(sale.grand_total) - parseFloat(sale.amount_paid);
      const paidAmount = parseFloat(sale.amount_paid);

      if (unpaidAmount > 0) {
        await createLedgerEntry({
          customerId: sale.customer_id,
          date: new Date(),
          transactionType: 'adjustment',
          referenceId: sale.id,
          referenceNumber: sale.invoice_number,
          description: `VOID: Reverse sale credit for ${sale.invoice_number}`,
          debit: unpaidAmount,
          credit: 0,
          transaction: t,
        });
      }

      if (paidAmount > 0) {
        await createLedgerEntry({
          customerId: sale.customer_id,
          date: new Date(),
          transactionType: 'adjustment',
          referenceId: sale.id,
          referenceNumber: sale.invoice_number,
          description: `VOID: Reverse payment debit for ${sale.invoice_number}`,
          debit: 0,
          credit: paidAmount,
          transaction: t,
        });
      }

      const finalBalance = await getCustomerBalance(sale.customer_id, t);
      await Customer.update({ balance: finalBalance }, { where: { id: sale.customer_id }, transaction: t });
    }

    await SaleItem.destroy({ where: { sale_id: id }, transaction: t });
    await sale.destroy({ transaction: t });
    await t.commit();

    res.json({ success: true, message: 'Sale voided, stock restored, and ledger reversed successfully' });
  } catch (error) {
    await t.rollback();
    console.error('Delete sale error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.getDailySummary = async (req, res) => {
  try {
    const { date } = req.query;
    const targetDate = date || new Date().toISOString().split('T')[0];

    const sales = await Sale.findAll({
      where: { sale_date: targetDate, payment_status: { [Op.ne]: 'draft' } },
      attributes: [
        'sale_type', 'sale_category', 'payment_method', 'payment_status',
        [fn('COUNT', col('id')), 'count'],
        [fn('SUM', col('grand_total')), 'total'],
        [fn('SUM', col('discount_amount')), 'discount'],
      ],
      group: ['sale_type', 'sale_category', 'payment_method', 'payment_status'],
      raw: true,
    });

    const overall = await Sale.findOne({
      where: { sale_date: targetDate, payment_status: { [Op.ne]: 'draft' } },
      attributes: [
        [fn('COUNT', col('id')), 'total_transactions'],
        [fn('SUM', col('grand_total')), 'total_revenue'],
        [fn('SUM', col('discount_amount')), 'total_discount'],
        [fn('SUM', col('amount_paid')), 'total_collected'],
      ],
      raw: true,
    });

    const creditSalesTotal = await Sale.sum('grand_total', {
      where: { sale_date: targetDate, payment_method: 'credit', payment_status: { [Op.ne]: 'draft' } },
    });

    res.json({
      success: true,
      data: {
        date: targetDate,
        breakdown: sales,
        summary: {
          total_transactions: parseInt(overall.total_transactions) || 0,
          total_revenue: parseFloat(overall.total_revenue) || 0,
          total_discount: parseFloat(overall.total_discount) || 0,
          total_collected: parseFloat(overall.total_collected) || 0,
          total_credit: parseFloat(creditSalesTotal) || 0,
        },
      },
    });
  } catch (error) {
    console.error('Daily summary error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};


exports.recordPayment = async (req, res) => {
  const t = await sequelize.transaction();
  try {
    const { id } = req.params;
    const { 
      amount, 
      payment_method: rawPaymentMethod, 
      payment_date, 
      notes, 
      cheque_number, 
      bank_name,
      bank_id,        // Add bank_id
      cheque_date,
      cheque_id       // For linking
    } = req.body;

    if (!amount || parseFloat(amount) <= 0) {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'Valid amount is required' });
    }

    const payment_method = normalizePaymentMethod(rawPaymentMethod);
    const paymentAmount = parseFloat(amount);

    const sale = await Sale.findByPk(id, {
      include: [{ model: Customer, as: 'customer' }],
      transaction: t
    });

    if (!sale) { 
      await t.rollback(); 
      return res.status(404).json({ success: false, message: 'Sale not found' }); 
    }
    if (sale.payment_status === 'paid') { 
      await t.rollback(); 
      return res.status(400).json({ success: false, message: 'Sale is already fully paid' }); 
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STEP 1: Validate bank for bank/cheque payments
    // ═══════════════════════════════════════════════════════════════════════
    let selectedBank = null;
    if ((payment_method === 'bank' || payment_method === 'cheque') && bank_id) {
      selectedBank = await Bank.findByPk(bank_id, { transaction: t });
      
      if (!selectedBank) {
        await t.rollback();
        return res.status(404).json({
          success: false,
          message: 'Selected bank not found'
        });
      }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STEP 2: Create Cheque Record (if payment method is cheque)
    // ═══════════════════════════════════════════════════════════════════════
    let chequeId = null;
    if (payment_method === 'cheque') {
      if (!cheque_number) {
        await t.rollback();
        return res.status(400).json({
          success: false,
          message: 'Cheque number is required for cheque payment'
        });
      }

      // Create cheque record (RECEIVED from customer)
      const cheque = await Cheque.create({
        bank_id: bank_id,
        cheque_number: cheque_number,
        cheque_type: 'received', // We receive cheque FROM customer
        amount: paymentAmount,
        payee_payer_name: sale.customer?.name || 'Customer',
        description: notes || `Payment received from customer for ${sale.invoice_number}`,
        issue_date: payment_date ? new Date(payment_date) : new Date(),
        due_date: cheque_date ? new Date(cheque_date) : null,
        status: 'pending',
        created_by: req.user?.id,
      }, { transaction: t });

      chequeId = cheque.id;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STEP 3: Record Bank Transaction (if bank payment - money comes IN)
    // ═══════════════════════════════════════════════════════════════════════
    let bankTransaction = null;
    if (selectedBank && payment_method === 'bank') {
      // For bank transfers FROM customer, money comes IN to our account
      const currentBalance = parseFloat(selectedBank.balance);
      const newBalance = currentBalance + paymentAmount;  // ✅ INCREASE balance

      // Update bank balance
      await selectedBank.update(
        { balance: newBalance.toFixed(2) },
        { transaction: t }
      );

      // Create bank transaction record (type 'in' for incoming money)
      bankTransaction = await BankTransaction.create({
        bank_id: bank_id,
        transaction_type: 'in',  // ✅ 'in' for customer payments
        amount: paymentAmount.toFixed(2),
        description: notes || `Payment received from ${sale.customer?.name || 'Customer'} for ${sale.invoice_number}`,
        reference_number: sale.invoice_number,
        balance_after: newBalance.toFixed(2),
        created_by: req.user?.id,
        transaction_date: payment_date ? new Date(payment_date) : new Date()
      }, { transaction: t });
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STEP 4: Update sale payment info
    // ═══════════════════════════════════════════════════════════════════════
    const newPaid = parseFloat(sale.amount_paid) + paymentAmount;
    const newStatus = newPaid >= parseFloat(sale.grand_total) ? 'paid' : 'partial';

    let paymentNotes = notes || '';
    if (payment_method === 'cheque' && cheque_number) {
      const chequeInfo = `Payment via Cheque #${cheque_number}, Bank: ${selectedBank?.name || bank_name || 'N/A'}, Date: ${cheque_date ? new Date(cheque_date).toISOString().split('T')[0] : 'N/A'}`;
      paymentNotes = paymentNotes ? `${paymentNotes}\n${chequeInfo}` : chequeInfo;
    }
    if (payment_method === 'bank' && selectedBank) {
      const bankInfo = `Payment via Bank Transfer to ${selectedBank.name}`;
      paymentNotes = paymentNotes ? `${paymentNotes}\n${bankInfo}` : bankInfo;
    }

    await sale.update({
      amount_paid: newPaid,
      payment_status: newStatus,
      payment_method: payment_method || sale.payment_method,
      notes: paymentNotes ? (sale.notes ? `${sale.notes}\n${paymentNotes}` : paymentNotes) : sale.notes,
    }, { transaction: t });

    // ═══════════════════════════════════════════════════════════════════════
    // STEP 5: Update cheque with sale_id reference
    // ═══════════════════════════════════════════════════════════════════════
    if (chequeId) {
      await Cheque.update(
        {
          sale_id: sale.id,
          customer_id: sale.customer_id,
        },
        { where: { id: chequeId }, transaction: t }
      );
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STEP 6: Create customer ledger entry
    // ═══════════════════════════════════════════════════════════════════════
    if (sale.customer_id) {
      await createLedgerEntry({
        customerId: sale.customer_id,
        date: payment_date || new Date(),
        transactionType: 'payment',
        referenceId: sale.id,
        referenceNumber: sale.invoice_number,
        description: paymentNotes || `Payment received for ${sale.invoice_number} (${payment_method})`,
        debit: paymentAmount,
        credit: 0,
        transaction: t,
        paymentMethod: payment_method,           // ADD
        bankName: selectedBank?.name || bank_name || null,  // ADD
        bankId: bank_id || null,                 // ADD
        chequeNumber: cheque_number || null,      // ADD
        chequeDate: cheque_date ? new Date(cheque_date) : null,  // ADD
      });

      const finalBalance = await getCustomerBalance(sale.customer_id, t);
      await Customer.update({ balance: finalBalance }, { where: { id: sale.customer_id }, transaction: t });
    }

    if (payment_method === 'cash' && sale.customer_id) {
      await createCashbookEntry({
        entry_date: payment_date || new Date(),
        entry_type: 'cash_in',
        source_type: 'customer_payment',
        reference_id: sale.id,
        reference_number: sale.invoice_number,
        description: `Cash payment for invoice ${sale.invoice_number} - ${sale.customer?.name || 'Customer'}`,
        amount: paymentAmount,
        created_by: req.user?.id,
        transaction: t,
      });
    }

    await t.commit();

    const updated = await Sale.findByPk(id, {
      include: [{ model: Customer, as: 'customer', attributes: ['id', 'name', 'balance'] }],
    });

    // Build appropriate success message
    let successMessage = 'Payment recorded successfully';
    if (payment_method === 'cheque' && cheque_number) {
      successMessage = `Cheque #${cheque_number} recorded. Status: Pending (awaiting clearing)`;
    } else if (payment_method === 'bank' && selectedBank) {
      successMessage = `Bank transfer recorded. ${selectedBank.name} balance increased by Rs ${paymentAmount.toFixed(2)}`;
    }

    res.json({ 
      success: true, 
      message: successMessage,
      data: {
        sale: updated,
        cheque_id: chequeId,
        bank_transaction: bankTransaction
      }
    });
  } catch (error) {
    await t.rollback();
    console.error('Record payment error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.getCreditSalesSummary = async (req, res) => {
  try {
    const { customer_id } = req.query;
    const whereClause = { payment_method: 'credit', payment_status: { [Op.ne]: 'paid' } };
    if (customer_id) whereClause.customer_id = customer_id;

    const creditSales = await Sale.findAll({
      where: whereClause,
      include: [{ model: Customer, as: 'customer', attributes: ['id', 'name', 'contact'] }],
      order: [['due_date', 'ASC']],
    });

    const totalOutstanding = creditSales.reduce((sum, sale) => sum + (sale.grand_total - sale.amount_paid), 0);
    const overdueSales = creditSales.filter(sale =>
      sale.due_date && new Date(sale.due_date) < new Date() && sale.payment_status !== 'paid'
    );

    res.json({
      success: true,
      data: {
        credit_sales: creditSales,
        summary: {
          total_outstanding: totalOutstanding,
          total_credit_sales: creditSales.length,
          overdue_count: overdueSales.length,
          overdue_amount: overdueSales.reduce((sum, sale) => sum + (sale.grand_total - sale.amount_paid), 0),
        },
      },
    });
  } catch (error) {
    console.error('Get credit sales summary error:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};