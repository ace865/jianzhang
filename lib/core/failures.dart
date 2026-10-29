/// Stable validation identifiers. Legacy messages remain available to older
/// callers; presentation translates them without exposing unknown exceptions.
enum LedgerError {
  invalidEntry,
  categoryMismatch,
  disabledCategory,
  invalidBudget,
  invalidNote,
}

/// A presentation-layer validation with a stable resource identifier.
class LocalizedFailure extends FormatException {
  const LocalizedFailure(this.code, super.message);
  final String code;
}

class LedgerFailure extends FormatException {
  const LedgerFailure.invalidEntry()
    : code = LedgerError.invalidEntry,
      super('请检查金额、日期或备注');
  const LedgerFailure.categoryMismatch()
    : code = LedgerError.categoryMismatch,
      super('分类与收支类型不匹配');
  const LedgerFailure.disabledCategory()
    : code = LedgerError.disabledCategory,
      super('此分类已停用，请选择其他分类');
  const LedgerFailure.invalidBudget()
    : code = LedgerError.invalidBudget,
      super('预算金额无效');
  const LedgerFailure.invalidNote()
    : code = LedgerError.invalidNote,
      super('小记内容无效');
  final LedgerError code;
}
