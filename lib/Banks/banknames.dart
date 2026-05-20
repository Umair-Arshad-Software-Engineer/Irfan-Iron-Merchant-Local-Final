class Bank {
  final String name;
  final String iconPath;

  Bank({required this.name, required this.iconPath});
}
class BankTransfer {
  final String fromBankId;
  final String fromBankName;
  final String toBankId;
  final String toBankName;
  final double amount;
  final String description;
  final DateTime timestamp;

  BankTransfer({
    required this.fromBankId,
    required this.fromBankName,
    required this.toBankId,
    required this.toBankName,
    required this.amount,
    required this.description,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'fromBankId': fromBankId,
      'fromBankName': fromBankName,
      'toBankId': toBankId,
      'toBankName': toBankName,
      'amount': amount,
      'description': description,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}
final List<Bank> pakistaniBanks = [
  Bank(name: 'Allied Bank', iconPath: 'asset/bank_icons/allied_bank.png'),
  Bank(name: 'Habib Bank Limited (HBL)', iconPath: 'asset/bank_icons/hbl.png'),
  Bank(name: 'United Bank Limited (UBL)', iconPath: 'asset/bank_icons/ubl.png'),
  Bank(name: 'MCB Bank', iconPath: 'asset/bank_icons/mcb.png'),
  Bank(name: 'Bank Alfalah', iconPath: 'asset/bank_icons/bank_alfalah.png'),
  Bank(name: 'Meezan Bank', iconPath: 'asset/bank_icons/meezan_bank.png'),
  Bank(name: 'National Bank of Pakistan (NBP)', iconPath: 'asset/bank_icons/nbp.png'),
  Bank(name: 'Askari Bank', iconPath: 'asset/bank_icons/askari_bank.png'),
  Bank(name: 'Faysal Bank', iconPath: 'asset/bank_icons/faysal_bank.png'),
  Bank(name: 'Standard Chartered Bank', iconPath: 'asset/bank_icons/standard_chartered.png'),
  Bank(name: 'Bank Of Punjab', iconPath: 'asset/bank_icons/bop.png'),
  Bank(name: 'Bank Al-Habib Limited (BAHL)', iconPath: 'asset/bank_icons/bahl.png'),
  Bank(name: 'JazzCash', iconPath: 'asset/bank_icons/jazzcash.png'),
  Bank(name: 'EasyPaisa', iconPath: 'asset/bank_icons/easypaisa.png'),
  Bank(name: 'NayaPay', iconPath: 'asset/bank_icons/nayapay.jpeg'),
  Bank(name: 'SadaPay', iconPath: 'asset/bank_icons/sadapay.jpeg'),
  Bank(name: 'Khaibar Bank', iconPath: 'asset/bank_icons/khaibar.jpg'),
  Bank(name: 'JS Bank', iconPath: 'asset/bank_icons/js.png'),
  Bank(name: 'Habib MetroPolitan', iconPath: 'asset/bank_icons/hbmp.png'),
  Bank(name: 'Silk Bank', iconPath: 'asset/bank_icons/silk.jpeg'),
  Bank(name: 'Soneri Bank', iconPath: 'asset/bank_icons/soneri.jpg'),
  Bank(name: 'Bank Islami', iconPath: 'asset/bank_icons/bank_islamic.jpg'),
  Bank(name: 'Al Barka', iconPath: 'asset/bank_icons/al_barka.png'),
  Bank(name: 'Dubai Islamic', iconPath: 'asset/bank_icons/dubai_islamic.jpg'),
];
