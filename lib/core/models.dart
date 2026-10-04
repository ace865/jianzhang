import 'dart:math';

enum EntryKind { expense, income }

enum Period { day, month, year }

const paymentMethods = ['未注明', '微信', '支付宝', '银行卡', '现金', '其他'];
const iconKeys = [
  'utensils',
  'train',
  'shopping',
  'home',
  'game',
  'medical',
  'book',
  'more',
  'briefcase',
  'gift',
  'coffee',
];
const maxCents = 99999999999;

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random.secure().nextInt(0x7fffffff).toRadixString(36)}';
String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String monthKey(DateTime date) => dayKey(date).substring(0, 7);
DateTime onlyDay(DateTime date) => DateTime(date.year, date.month, date.day);
bool validDay(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final parsed = DateTime.tryParse(value);
  return parsed != null &&
      parsed.year >= 1900 &&
      parsed.year <= 2100 &&
      dayKey(parsed) == value;
}

int? parseMoney(String value) {
  final text = value.trim();
  if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  final cents =
      int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return cents > 0 && cents <= maxCents ? cents : null;
}

String moneyInput(int cents) =>
    '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
String money(int cents, {bool symbol = true}) {
  final absolute = cents.abs();
  final integer = (absolute ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return '${cents < 0 ? '−' : ''}${symbol ? '¥' : ''}$integer.${(absolute % 100).toString().padLeft(2, '0')}';
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.kind,
    this.active = true,
    this.order = 0,
  });
  final String id, name, icon;
  final EntryKind kind;
  final bool active;
  final int order;
  factory Category.fromMap(Map<String, Object?> map) => Category(
    id: map['id'] as String,
    name: map['name'] as String,
    icon: map['icon'] as String,
    kind: EntryKind.values.byName(map['kind'] as String),
    active: map['active'] == 1,
    order: map['sort_order'] as int,
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'kind': kind.name,
    'active': active ? 1 : 0,
    'sort_order': order,
  };
  Category copyWith({String? name, String? icon, bool? active}) => Category(
    id: id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    kind: kind,
    active: active ?? this.active,
    order: order,
  );
}

const initialCategories = [
  Category(
    id: 'food',
    name: '餐饮',
    icon: 'utensils',
    kind: EntryKind.expense,
    order: 0,
  ),
  Category(
    id: 'transport',
    name: '交通',
    icon: 'train',
    kind: EntryKind.expense,
    order: 1,
  ),
  Category(
    id: 'shopping',
    name: '购物',
    icon: 'shopping',
    kind: EntryKind.expense,
    order: 2,
  ),
  Category(
    id: 'housing',
    name: '住房',
    icon: 'home',
    kind: EntryKind.expense,
    order: 3,
  ),
  Category(
    id: 'entertainment',
    name: '娱乐',
    icon: 'game',
    kind: EntryKind.expense,
    order: 4,
  ),
  Category(
    id: 'medical',
    name: '医疗',
    icon: 'medical',
    kind: EntryKind.expense,
    order: 5,
  ),
  Category(
    id: 'learning',
    name: '学习',
    icon: 'book',
    kind: EntryKind.expense,
    order: 6,
  ),
  Category(
    id: 'other-expense',
    name: '其他',
    icon: 'more',
    kind: EntryKind.expense,
    order: 7,
  ),
  Category(
    id: 'salary',
    name: '工资',
    icon: 'briefcase',
    kind: EntryKind.income,
    order: 0,
  ),
  Category(
    id: 'bonus',
    name: '奖金',
    icon: 'gift',
    kind: EntryKind.income,
    order: 1,
  ),
  Category(
    id: 'other-income',
    name: '其他收入',
    icon: 'more',
    kind: EntryKind.income,
    order: 2,
  ),
];

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.kind,
    required this.cents,
    required this.categoryId,
    required this.date,
    this.payment = '未注明',
    this.note = '',
    required this.createdAt,
  });
  final String id, categoryId, payment, note;
  final EntryKind kind;
  final int cents, createdAt;
  final DateTime date;
  factory LedgerEntry.fromMap(Map<String, Object?> map) => LedgerEntry(
    id: map['id'] as String,
    kind: EntryKind.values.byName(map['kind'] as String),
    cents: map['cents'] as int,
    categoryId: map['category_id'] as String,
    date: DateTime.parse(map['day'] as String),
    payment: map['payment'] as String,
    note: map['note'] as String,
    createdAt: map['created_at'] as int,
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'kind': kind.name,
    'cents': cents,
    'category_id': categoryId,
    'day': dayKey(date),
    'payment': payment,
    'note': note,
    'created_at': createdAt,
  };
}

class PeriodWindow {
  PeriodWindow(this.period, this.date);
  final Period period;
  final DateTime date;
  DateTime get start => switch (period) {
    Period.day => onlyDay(date),
    Period.month => DateTime(date.year, date.month),
    Period.year => DateTime(date.year),
  };
  DateTime get end => switch (period) {
    Period.day => DateTime(date.year, date.month, date.day + 1),
    Period.month => DateTime(date.year, date.month + 1),
    Period.year => DateTime(date.year + 1),
  };
  String get label => switch (period) {
    Period.day => '${date.year}年${date.month}月${date.day}日',
    Period.month => '${date.year}年${date.month}月',
    Period.year => '${date.year}年',
  };
  String get shortLabel => switch (period) {
    Period.day => '当日',
    Period.month => '当月',
    Period.year => '当年',
  };
  PeriodWindow shift(int amount) => PeriodWindow(period, switch (period) {
    Period.day => DateTime(date.year, date.month, date.day + amount),
    Period.month => DateTime(date.year, date.month + amount),
    Period.year => DateTime(date.year + amount),
  });
  bool get containsToday {
    final today = onlyDay(DateTime.now());
    return !today.isBefore(start) && today.isBefore(end);
  }

  String get caption => containsToday
      ? '截至${DateTime.now().month}月${DateTime.now().day}日'
      : '完整${switch (period) {
          Period.day => '当日',
          Period.month => '月份',
          Period.year => '年度',
        }}';
}

class EntryFilter {
  const EntryFilter({
    this.start,
    this.end,
    this.kind,
    this.categoryId,
    this.payment,
    this.search = '',
  });
  final DateTime? start, end;
  final EntryKind? kind;
  final String? categoryId, payment;
  final String search;
}

class Totals {
  const Totals({this.income = 0, this.expense = 0, this.count = 0});
  final int income, expense, count;
  int get balance => income - expense;
}

class CategoryTotal {
  const CategoryTotal(this.categoryId, this.cents, this.count);
  final String categoryId;
  final int cents, count;
}

class TrendPoint {
  const TrendPoint(this.label, this.income, this.expense);
  final String label;
  final int income, expense;
}

class BudgetStatus {
  const BudgetStatus(this.categoryId, this.limit, this.spent);
  final String categoryId;
  final int limit, spent;
  int get remaining => limit - spent;
  double get ratio => limit > 0 ? spent / limit : 0;
}
