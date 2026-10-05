import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:xml/xml.dart';

import 'models.dart';

const importMaxBytes = 20 * 1024 * 1024;
const importMaxRows = 20000;
const wechatHeaders = [
  '交易时间',
  '交易类型',
  '交易对方',
  '商品',
  '收/支',
  '金额(元)',
  '支付方式',
  '当前状态',
  '交易单号',
  '商户单号',
  '备注',
];

enum ImportDisposition { ready, review, invalid, excluded, duplicate, conflict }

class WechatRow {
  WechatRow({
    required this.line,
    required this.cells,
    required this.date,
    required this.cents,
    required this.kind,
    required this.order,
    required this.disposition,
    required this.reason,
  });
  final int line;
  final List<String> cells;
  final DateTime? date;
  final int? cents;
  final EntryKind? kind;
  final String order;
  final ImportDisposition disposition;
  final String reason;
  late final String sourceKey = order.isEmpty
      ? ''
      : sha256.convert(utf8.encode('wechat:$order')).toString();
  late final String fingerprint = sha256
      .convert(
        utf8.encode(
          jsonEncode([
            date?.toIso8601String(),
            cents,
            kind?.name,
            cells[1],
            cells[2],
            cells[3],
          ]),
        ),
      )
      .toString();
  String get description => [
    cells[2],
    cells[3],
    cells[10],
  ].where((s) => s.isNotEmpty && s != '/').join(' · ');
}

class ImportItem {
  ImportItem(this.row, this.disposition, this.reason, this.categoryId)
    : kind = row.kind,
      selected =
          disposition == ImportDisposition.ready && categoryId.isNotEmpty;
  final WechatRow row;
  final ImportDisposition disposition;
  final String reason;
  EntryKind? kind;
  String categoryId;
  bool selected;
  bool confirmed = false;
  bool get needsCategory => !blocked && categoryId.isEmpty;
  bool get blocked => [
    ImportDisposition.invalid,
    ImportDisposition.excluded,
    ImportDisposition.duplicate,
    ImportDisposition.conflict,
  ].contains(disposition);
  bool get needsConfirmation => disposition == ImportDisposition.review;
}

class ImportResult {
  const ImportResult(this.inserted, this.duplicates, this.unselected);
  final int inserted, duplicates, unselected;
}

String? suggestImportCategory(
  WechatRow row,
  EntryKind kind,
  List<Category> categories,
) {
  final active = categories.where((c) => c.active && c.kind == kind).toList();
  if (active.isEmpty) return null;
  final text = '${row.cells[1]} ${row.cells[2]} ${row.cells[3]}';
  final rules = kind == EntryKind.income
      ? {'工资|薪资': 'salary', '奖金': 'bonus'}
      : {
          '餐|饭|食|面馆|奶茶|咖啡': 'food',
          '地铁|公交|打车|交通|车票': 'transport',
          '超市|购物|百货|服装': 'shopping',
          '房租|水费|电费|物业': 'housing',
          '医院|药房|诊所': 'medical',
          '书店|课程|学费': 'learning',
          '电影|游戏|娱乐': 'entertainment',
        };
  for (final rule in rules.entries) {
    if (RegExp(rule.key).hasMatch(text)) {
      for (final c in active) {
        if (c.id == rule.value) return c.id;
      }
    }
  }
  return active
      .firstWhere(
        (c) => c.id == 'other-${kind.name}',
        orElse: () => active.first,
      )
      .id;
}

/// Only decodes data; never executes formulas or follows external relationships.
Future<List<WechatRow>> parseWechatFile(
  Uint8List bytes,
  String extension,
) async {
  if (bytes.length > importMaxBytes) {
    throw const FormatException('文件超过 20 MB，请分段导出');
  }
  try {
    if (extension == 'xlsx') {
      return parseWechatTable(_xlsx(bytes), excelDates: true);
    }
    if (extension != 'csv') {
      throw const FormatException('请选择微信 CSV 或 .xlsx，压缩包和 PDF 暂不支持');
    }
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      text = await CharsetConverter.decode('GB18030', bytes);
    }
    if (text.contains('\uFFFD')) throw const FormatException('文件编码损坏，无法可靠读取');
    return parseWechatCsv(text);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('文件损坏、已加密或格式不支持，请重新导出未加密账单');
  }
}

List<WechatRow> parseWechatCsv(String text) => parseWechatTable(
  const CsvToListConverter(shouldParseNumbers: false, allowInvalid: false)
      .convert(
        text.replaceFirst('\uFEFF', ''),
        eol: text.contains('\r\n') ? '\r\n' : '\n',
      )
      .map((r) => r.map((v) => v.toString()).toList())
      .toList(),
);

String _label(String value) => value
    .replaceAll(RegExp(r'[\s\uFEFF]'), '')
    .replaceAll('（', '(')
    .replaceAll('）', ')');

List<WechatRow> parseWechatTable(
  List<List<String>> table, {
  bool excelDates = false,
  bool date1904 = false,
}) {
  int header = -1;
  List<int> columns = [];
  for (var i = 0; i < table.length; i++) {
    final labels = table[i].map(_label).toList();
    if (wechatHeaders.every(labels.contains)) {
      if (wechatHeaders.any((h) => labels.where((l) => l == h).length != 1)) {
        throw const FormatException('账单存在重复列名');
      }
      header = i;
      columns = wechatHeaders.map(labels.indexOf).toList();
      break;
    }
  }
  if (header < 0) throw const FormatException('未识别微信账单表头，请使用个人对账文件');
  final result = <WechatRow>[];
  for (var i = header + 1; i < table.length; i++) {
    final source = table[i];
    if (source.every((s) => s.trim().isEmpty)) continue;
    final first = source.first.trim();
    if (RegExp(r'^[-—=]{3,}|^(共\d+笔|收入：|支出：|中性交易：|注：|说明：)').hasMatch(first)) {
      continue;
    }
    if (result.length >= importMaxRows) {
      throw const FormatException('明细超过 20,000 条，请分段导出');
    }
    final cells = columns
        .map((j) => j < source.length ? source[j].trim() : '')
        .toList();
    final date = _date(cells[0], excelDates, date1904);
    final cents = parseMoney(cells[5].replaceFirst(RegExp(r'^[¥￥]'), ''));
    final kind = switch (cells[4]) {
      '支出' => EntryKind.expense,
      '收入' => EntryKind.income,
      _ => null,
    };
    var order = cells[8].replaceFirst(RegExp(r"^[`']"), '').trim();
    if (order == '/') order = '';
    var disposition = ImportDisposition.ready;
    var reason = '';
    if (date == null ||
        cents == null ||
        cells.any((s) => s.startsWith('\u0000')) ||
        RegExp(r'^\d+(?:[.]\d+)?[eE][+-]?\d+$').hasMatch(order) ||
        order.length > 128 ||
        cells[1].isEmpty ||
        cells[7].isEmpty ||
        cells[2].isEmpty ||
        cells[3].isEmpty ||
        !['支出', '收入', '/', '不计收支', '不计入收支'].contains(cells[4])) {
      disposition = ImportDisposition.invalid;
      reason = '日期、金额、单号或必需字段无效，不能入账';
    } else if (RegExp('失败|关闭|撤销').hasMatch(cells[7])) {
      disposition = ImportDisposition.excluded;
      reason = '失败、关闭或撤销交易不入账';
    } else if (kind == null ||
        order.isEmpty ||
        RegExp('退款|转账|充值|提现|存入零钱|还款|理财').hasMatch('${cells[1]} ${cells[7]}') ||
        !['支付成功', '收款成功', '交易成功'].contains(cells[7])) {
      disposition = ImportDisposition.review;
      reason = '特殊交易、未知状态或缺少单号，请确认收支含义';
    }
    result.add(
      WechatRow(
        line: i + 1,
        cells: cells,
        date: date,
        cents: cents,
        kind: kind,
        order: order,
        disposition: disposition,
        reason: reason,
      ),
    );
  }
  if (result.isEmpty) throw const FormatException('账单没有可预览的明细');
  return result;
}

DateTime? _date(String value, bool serial, bool date1904) {
  if (serial && RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) {
    final n = double.tryParse(value);
    if (n == null ||
        !n.isFinite ||
        n < 0 ||
        n > 74000 ||
        (!date1904 && n.floor() == 60)) {
      return null;
    }
    final base = date1904
        ? DateTime.utc(1904)
        : n < 60
        ? DateTime.utc(1899, 12, 31)
        : DateTime.utc(1899, 12, 30);
    final fields = base.add(Duration(seconds: (n * 86400).round()));
    final date = DateTime(
      fields.year,
      fields.month,
      fields.day,
      fields.hour,
      fields.minute,
      fields.second,
    );
    return validDay(dayKey(date)) ? date : null;
  }
  final m = RegExp(
    r'^(\d{4})[-/](\d{2})[-/](\d{2})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?$',
  ).firstMatch(value);
  if (m == null) return null;
  final day = '${m[1]}-${m[2]}-${m[3]}';
  final h = int.parse(m[4] ?? '0'),
      min = int.parse(m[5] ?? '0'),
      sec = int.parse(m[6] ?? '0');
  if (!validDay(day) || h > 23 || min > 59 || sec > 59) return null;
  return DateTime(
    int.parse(m[1]!),
    int.parse(m[2]!),
    int.parse(m[3]!),
    h,
    min,
    sec,
  );
}

List<List<String>> _xlsx(Uint8List bytes) {
  final zip = ZipDecoder().decodeBytes(bytes);
  if (zip.length > 1000 ||
      zip.fold<int>(0, (s, f) => s + f.size) > 100 * 1024 * 1024 ||
      zip.any((f) => f.size > 64 * 1024 * 1024)) {
    throw const FormatException('表格解压内容过大，请分段导出');
  }
  XmlDocument? xml(String name) {
    final file = zip.findFile(name);
    if (file == null) return null;
    final contents = file.readBytes()!;
    if (contents.length != file.size || getCrc32(contents) != file.crc32) {
      throw const FormatException('表格内容校验失败，请重新导出');
    }
    final text = utf8.decode(contents);
    if (text.contains('<!DOCTYPE') || text.contains('<!ENTITY')) {
      throw const FormatException('不支持的 XML 内容');
    }
    return XmlDocument.parse(text);
  }

  final workbook = xml('xl/workbook.xml');
  if (workbook == null) throw const FormatException('不是有效的 .xlsx 文件');
  final date1904 = workbook
      .findAllElements('workbookPr')
      .any((e) => ['1', 'true'].contains(e.getAttribute('date1904')));
  final shared =
      xml('xl/sharedStrings.xml')
          ?.findAllElements('si')
          .map((e) => e.findAllElements('t').map((t) => t.innerText).join())
          .toList() ??
      <String>[];
  List<List<String>>? found;
  for (final file in zip.where(
    (f) => RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(f.name),
  )) {
    final sheet = xml(file.name)!;
    final rows = <List<String>>[];
    for (final row in sheet.findAllElements('row')) {
      final originalLine = int.tryParse(row.getAttribute('r') ?? '');
      if (originalLine == null ||
          originalLine <= rows.length ||
          originalLine > importMaxRows + 1000) {
        throw const FormatException('表格行号无效或过大，请分段导出');
      }
      while (rows.length < originalLine - 1) {
        rows.add([]);
      }
      if (rows.length > importMaxRows + 1000) {
        throw const FormatException('表格行数过大，请分段导出');
      }
      final cells = <String>[];
      for (final cell in row.findElements('c')) {
        final address = cell.getAttribute('r') ?? '';
        final letters = RegExp(r'^[A-Z]+').stringMatch(address);
        if (letters == null) throw const FormatException('单元格地址无效');
        var col = 0;
        for (final n in letters.codeUnits) {
          col = col * 26 + n - 64;
        }
        if (col > 64) throw const FormatException('表格列数过大');
        while (cells.length < col) {
          cells.add('');
        }
        final value = cell.getElement('v')?.innerText ?? '';
        var text = value;
        final type = cell.getAttribute('t');
        if (cell.getElement('f') != null) {
          text = '\u0000公式不支持';
        } else if (type == 's') {
          text = shared[int.parse(value)];
        } else if (type == 'inlineStr') {
          text = cell.findAllElements('t').map((e) => e.innerText).join();
        }
        // Numeric long identifiers cannot be recovered after Excel rounding.
        else if ((type == null || type == 'n') &&
            RegExp(r'^\d{16,}|[eE]').hasMatch(value)) {
          text = '\u0000长数字不可靠';
        }
        cells[col - 1] = text;
      }
      rows.add(cells);
    }
    if (!rows.any((r) => r.map(_label).contains('交易时间'))) continue;
    if (found != null) throw const FormatException('包含多个账单工作表，请分别导出');
    if (date1904) {
      final header = rows.firstWhere((r) => r.map(_label).contains('交易时间'));
      final dateColumn = header.map(_label).toList().indexOf('交易时间');
      for (final row in rows) {
        if (row.length > dateColumn &&
            RegExp(r'^\d+(\.\d+)?$').hasMatch(row[dateColumn])) {
          row[dateColumn] = (double.parse(row[dateColumn]) + 1462).toString();
        }
      }
    }
    found = rows;
  }
  return found ?? (throw const FormatException('未找到微信明细工作表'));
}
