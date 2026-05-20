// backend/src/controllers/supplierPaymentController.js
const { Op } = require('sequelize');
const { SupplierLedger, Supplier, Bank, BankTransaction, Cheque, sequelize } = require('../models');
const { recalculateBalances } = require('./supplierLedgerController');
const { createCashbookEntry } = require('./cashbookController');

// ═══════════════════════════════════════════════════════════════════════════
// ✅ CREATE SUPPLIER PAYMENT + AUTO BANK TRANSACTION
// ═══════════════════════════════════════════════════════════════════════════
exports.createSupplierPayment = async (req, res) => {
  const dbTransaction = await sequelize.transaction();
  
  try {
    const { supplierId } = req.params;
    const {
      amount,
      payment_method,
      bank_id,
      bank_name,
      cheque_number,
      cheque_id,  // Add this - cheque_id from frontend
      cheque_date,
      reference_number,
      description,
      transaction_date,
    } = req.body;

    // ── Validate required fields ──
    if (!amount || parseFloat(amount) <= 0) {
      await dbTransaction.rollback();
      return res.status(400).json({
        success: false,
        message: 'Valid amount is required'
      });
    }

    if (!payment_method) {
      await dbTransaction.rollback();
      return res.status(400).json({
        success: false,
        message: 'Payment method is required'
      });
    }

    // ── Get supplier ──
    const supplier = await Supplier.findByPk(supplierId, { transaction: dbTransaction });
    if (!supplier) {
      await dbTransaction.rollback();
      return res.status(404).json({
        success: false,
        message: 'Supplier not found'
      });
    }

    const paymentAmount = parseFloat(amount);

    // ═══════════════════════════════════════════════════════════════════════
    // STEP 1: Validate bank if bank/cheque payment
    // ═══════════════════════════════════════════════════════════════════════
    let selectedBank = null;
    if ((payment_method === 'bank' || payment_method === 'cheque') && bank_id) {
      selectedBank = await Bank.findByPk(bank_id, { transaction: dbTransaction });
      
      if (!selectedBank) {
        await dbTransaction.rollback();
        return res.status(404).json({
          success: false,
          message: 'Selected bank not found'
        });
      }

      // For bank payments, check balance immediately
      // For cheque payments, don't check balance yet (only when cleared)
      if (payment_method === 'bank') {
        const bankBalance = parseFloat(selectedBank.balance);
        if (bankBalance < paymentAmount) {
          await dbTransaction.rollback();
          return res.status(400).json({
            success: false,
            message: `Insufficient balance in ${selectedBank.name}. Available: Rs ${bankBalance.toFixed(2)}`
          });
        }
      }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STEP 2: Create supplier ledger entry (payment)
    // ═══════════════════════════════════════════════════════════════════════
    
    const methodLabels = {
      'cash': 'Cash Payment',
      'bank': 'Bank Transfer',
      'cheque': 'Cheque Payment',
      'slip': 'Pay Slip'
    };

    const methodLabel = methodLabels[payment_method] || payment_method;
    
    // Auto-generate description if not provided
    const autoDesc = [
      `${methodLabel} to ${supplier.name}`,
      bank_name ? `| Bank: ${bank_name}` : null,
      cheque_number ? `| Chq#: ${cheque_number}` : null,
      reference_number ? `| Ref: ${reference_number}` : null,
    ].filter(Boolean).join(' ');

    const finalDescription = description?.trim() || autoDesc;

    // Create ledger entry with temporary balance
    const ledgerEntry = await SupplierLedger.create({
      supplier_id: supplierId,
      reference_type: 'payment',
      reference_id: cheque_id || null,  // Link to cheque if exists
      reference_number: reference_number || cheque_number || null,
      debit: paymentAmount.toFixed(2),
      credit: '0.00',
      balance: '0.00', // temporary - will be recalculated
      description: finalDescription,
      transaction_date: transaction_date ? new Date(transaction_date) : new Date(),
      payment_method,
      bank_name: bank_name || null,
      bank_id: bank_id || null,  // Add bank_id
      cheque_number: cheque_number || null,
      cheque_date: cheque_date 
      ? new Date(cheque_date + 'T00:00:00.000Z') 
      : null,
      cheque_cleared: false,  // Add this flag
      cheque_cleared_date: null,  // Add this
      created_by: req.user?.id,
    }, { transaction: dbTransaction });


     // ═══════════════════════════════════════════════════════════════════════
    // STEP 3: Update cheque record with supplier_id and ledger_id
    // ═══════════════════════════════════════════════════════════════════════
    if (cheque_id && payment_method === 'cheque') {
      await Cheque.update(
        {
          supplier_id: supplierId,
          supplier_ledger_id: ledgerEntry.id,
          payee_payer_name: supplier.name,
          description: description || `Payment to supplier: ${supplier.name}`
        },
        { where: { id: cheque_id }, transaction: dbTransaction }
      );
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STEP 4: Recalculate supplier ledger balances
    // ═══════════════════════════════════════════════════════════════════════
    await recalculateBalances(supplierId, dbTransaction);

    // ═══════════════════════════════════════════════════════════════════════
    // STEP 5: Record bank transaction (if bank/cheque payment)
    // ═══════════════════════════════════════════════════════════════════════
     let bankTransaction = null;
    if (selectedBank && payment_method === 'bank') {
      // Update bank balance immediately for bank transfers
      const newBankBalance = parseFloat(selectedBank.balance) - paymentAmount;
      await selectedBank.update(
        { balance: newBankBalance.toFixed(2) },
        { transaction: dbTransaction }
      );

      // Create bank transaction record
      bankTransaction = await BankTransaction.create({
        bank_id: bank_id,
        transaction_type: 'out',
        amount: paymentAmount.toFixed(2),
        description: `Bank transfer to ${supplier.name}`,
        reference_number: reference_number || null,
        balance_after: newBankBalance.toFixed(2),
        created_by: req.user?.id,
        transaction_date: transaction_date ? new Date(transaction_date) : new Date()
      }, { transaction: dbTransaction });
    }

    if (payment_method === 'cash') {
      await createCashbookEntry({
        entry_date: transaction_date || new Date(),
        entry_type: 'cash_out',
        source_type: 'supplier_payment',
        reference_id: ledgerEntry.id,
        reference_number: reference_number || null,
        description: `Cash paid to ${supplier.name}`,
        amount: paymentAmount,
        created_by: req.user?.id,
        transaction: dbTransaction,
      });
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STEP 6: Reload and commit
    // ═══════════════════════════════════════════════════════════════════════
    await ledgerEntry.reload({ transaction: dbTransaction });
    await dbTransaction.commit();

    // ═══════════════════════════════════════════════════════════════════════
    // SUCCESS RESPONSE
    // ═══════════════════════════════════════════════════════════════════════
const responseData = {
      entry: ledgerEntry,
      ...(bankTransaction && { bankTransaction }),
      ...(cheque_id && { cheque_id })
    };

    return res.status(201).json({
      success: true,
      message: payment_method === 'cheque' 
        ? 'Cheque payment recorded. Bank balance will update when cheque clears.'
        : 'Payment recorded successfully' + (bankTransaction ? ' and bank transaction created' : ''),
      data: responseData
    });

  } catch (error) {
    await dbTransaction.rollback();
    console.error('Supplier payment error:', error);
    
    return res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};


// ═══════════════════════════════════════════════════════════════════════════
// ✅ GET SUPPLIER PAYMENTS
// ═══════════════════════════════════════════════════════════════════════════
exports.getSupplierPayments = async (req, res) => {
  try {
    const { supplierId } = req.params;
    const { payment_method, from, to, page = 1, limit = 50 } = req.query;

    const where = {
      supplier_id: supplierId,
      reference_type: 'payment',
    };

    if (payment_method && payment_method !== 'all') {
      where.payment_method = payment_method;
    }

    if (from || to) {
      where.transaction_date = {};
      if (from) where.transaction_date[Op.gte] = new Date(from);
      if (to) {
        const toDate = new Date(to);
        toDate.setHours(23, 59, 59, 999);
        where.transaction_date[Op.lte] = toDate;
      }
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);

    const { count, rows } = await SupplierLedger.findAndCountAll({
      where,
      order: [['transaction_date', 'DESC'], ['id', 'DESC']],
      limit: parseInt(limit),
      offset
    });

    const totalPaid = await SupplierLedger.sum('debit', { where }) || 0;

    return res.json({
      success: true,
      data: {
        payments: rows,
        totalPaid: parseFloat(totalPaid).toFixed(2),
        pagination: {
          total: count,
          page: parseInt(page),
          pages: Math.ceil(count / parseInt(limit)),
        },
      },
    });

  } catch (error) {
    console.error('Get payments error:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};


// ═══════════════════════════════════════════════════════════════════════════
// ✅ DELETE SUPPLIER PAYMENT + CREATE REVERSAL
// ═══════════════════════════════════════════════════════════════════════════
exports.deleteSupplierPayment = async (req, res) => {
  const dbTransaction = await sequelize.transaction();
  
  try {
    const { supplierId, paymentId } = req.params;

    // ── Get the payment entry ──
    const entry = await SupplierLedger.findOne({
      where: {
        id: paymentId,
        supplier_id: supplierId,
        reference_type: 'payment'
      },
      transaction: dbTransaction
    });

    if (!entry) {
      await dbTransaction.rollback();
      return res.status(404).json({
        success: false,
        message: 'Payment not found'
      });
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STEP 1: If bank payment exists, reverse bank transaction
    // ═══════════════════════════════════════════════════════════════════════
    if ((entry.payment_method === 'bank' || entry.payment_method === 'cheque') && entry.bank_name) {
      // Find bank by name (if no bank_id stored, use bank_name)
      // Ideally you should store bank_id in SupplierLedger
      // For now, we'll try to find it by name
      const bank = await Bank.findOne({
        where: { name: entry.bank_name },
        transaction: dbTransaction
      });

      if (bank) {
        const paymentAmount = parseFloat(entry.debit);
        const newBankBalance = parseFloat(bank.balance) + paymentAmount;

        // Reverse bank balance
        await bank.update(
          { balance: newBankBalance.toFixed(2) },
          { transaction: dbTransaction }
        );

        // Create reversal bank transaction
        await BankTransaction.create({
          bank_id: bank.id,
          transaction_type: 'in', // Reversal - money comes back
          amount: paymentAmount.toFixed(2),
          description: `Reversal of payment to ${entry.description}`,
          reference_number: entry.reference_number ? `REV-${entry.reference_number}` : null,
          balance_after: newBankBalance.toFixed(2),
          created_by: req.user?.id,
          transaction_date: new Date()
        }, { transaction: dbTransaction });
      }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STEP 2: Create reversal ledger entry
    // ═══════════════════════════════════════════════════════════════════════
    await SupplierLedger.create({
      supplier_id: supplierId,
      reference_type: 'reversal',
      reference_id: entry.id,
      reference_number: entry.reference_number ? `REV-${entry.reference_number}` : null,
      debit: '0.00',
      credit: parseFloat(entry.debit).toFixed(2),
      balance: '0.00', // temporary - will be recalculated
      description: `Reversal of payment: ${entry.description}`,
      transaction_date: new Date(),
      created_by: req.user?.id,
    }, { transaction: dbTransaction });

    // ═══════════════════════════════════════════════════════════════════════
    // STEP 3: Delete original payment entry
    // ═══════════════════════════════════════════════════════════════════════
    await entry.destroy({ transaction: dbTransaction });

    // ═══════════════════════════════════════════════════════════════════════
    // STEP 4: Recalculate all ledger balances
    // ═══════════════════════════════════════════════════════════════════════
    await recalculateBalances(supplierId, dbTransaction);

    await dbTransaction.commit();

    return res.json({
      success: true,
      message: 'Payment deleted, reversal entry created, and balances updated'
    });

  } catch (error) {
    await dbTransaction.rollback();
    console.error('Delete payment error:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};
