import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/language.dart';
import '../core/models.dart';
import 'generated/app_localizations.dart';
export '../core/language.dart';
export 'generated/app_localizations.dart';

AppLocalizations tr(BuildContext context) =>
    AppLocalizations.of(context) ??
    lookupAppLocalizations(LanguageSettings.instance.locale);

String categoryLabel(BuildContext context, Category category) {
  return categoryDisplayName(tr(context), category);
}

String categoryDisplayName(AppLocalizations l, Category category) {
  final defaults = initialCategories.where(
    (c) => c.id == category.id && c.name == category.name,
  );
  if (defaults.isEmpty) return category.name;
  return switch (category.id) {
    'food' => l.food,
    'transport' => l.transport,
    'shopping' => l.shopping,
    'housing' => l.housing,
    'entertainment' => l.entertainment,
    'medical' => l.medical,
    'learning' => l.learning,
    'salary' => l.salary,
    'bonus' => l.bonus,
    'gift' => l.gift,
    'investment' => l.investment,
    'other-income' => l.otherIncome,
    _ => l.other,
  };
}

EntryFilter localizedSearchFilter(
  EntryFilter filter,
  List<Category> categories,
  AppLocalizations l,
) {
  final query = filter.search.trim().toLowerCase();
  final ids = query.isEmpty
      ? <String>[]
      : categories
            .where((category) {
              final displayed = categoryDisplayName(l, category);
              // Custom and renamed categories already use the database's original-name
              // search. Only built-in translated names need extra ID matches.
              return displayed != category.name &&
                  displayed.toLowerCase().contains(query);
            })
            .map((c) => c.id)
            .toList();
  return EntryFilter(
    start: filter.start,
    end: filter.end,
    kind: filter.kind,
    categoryId: filter.categoryId,
    payment: filter.payment,
    search: filter.search,
    searchCategoryIds: ids,
  );
}

String paymentLabel(BuildContext context, String value) => switch (value) {
  '未注明' => tr(context).unspecified,
  '微信' => tr(context).wechat,
  '支付宝' => tr(context).alipay,
  '银行卡' => tr(context).bankCard,
  '现金' => tr(context).cash,
  '其他' => tr(context).other,
  _ => value,
};

String dateLabel(
  BuildContext context,
  DateTime date, {
  bool month = false,
  bool year = false,
}) =>
    (year
            ? DateFormat.y(formattingLocale(context))
            : month
            ? DateFormat.yMMM(formattingLocale(context))
            : DateFormat.yMMMd(formattingLocale(context)))
        .format(date);

String periodLabel(BuildContext context, PeriodWindow window) =>
    (switch (window.period) {
      Period.day => DateFormat.yMMMd(formattingLocale(context)),
      Period.month => DateFormat.yMMM(formattingLocale(context)),
      Period.year => DateFormat.y(formattingLocale(context)),
    }).format(window.date);
String shortPeriodLabel(BuildContext context, PeriodWindow window) =>
    switch (window.period) {
      Period.day => tr(context).thisDay,
      Period.month => tr(context).thisMonth,
      Period.year => tr(context).thisYear,
    };

String formattingLocale(BuildContext context) {
  final name = tr(context).localeName;
  if (name.startsWith('zh')) {
    return name.contains('Hant') ? 'zh_TW' : 'zh_CN';
  }
  return name;
}

String trendLabel(BuildContext context, String label) {
  final month = RegExp(r'^(\d+)月$').firstMatch(label);
  if (month != null) {
    return DateFormat.MMM(formattingLocale(context))
        .format(DateTime(2000, int.parse(month.group(1)!)));
  }
  final day = RegExp(r'^(\d+)日$').firstMatch(label);
  return day != null && formattingLocale(context) == 'en'
      ? day.group(1)!
      : label;
}
