import 'package:flutter/widgets.dart';

import 'localization.dart';

/// Localizes known legacy system messages at the presentation boundary.
/// Unknown failures are handled by the caller; never expose raw exceptions.
String? systemMessage(BuildContext context, String message) {
  if (message.length > 8192) return null;
  final l = tr(context);
  switch (message) {
    case "账本暂时无法打开。请检查设备可用空间后重试，原有账本不会被清空。":
      return l.cannotOpenTheLedgerCheckAvailableStorage;
    case "简账":
      return l.message;
    case "重试":
      return l.retry;
    case "记一笔":
      return l.addEntry;
    case "总览":
      return l.overview;
    case "账单":
      return l.entries;
    case "分析":
      return l.analysis;
    case "设置":
      return l.settings;
    case "AI 操作未完成。账本不受影响，请检查设备存储或重试。":
      return l.aiOperationFailedYourLedgerIsUnaffected;
    case "无法核对最新账本，请重试。":
      return l.cannotCheckTheLatestLedgerPleaseRetry;
    case "确认接收地址与数据范围":
      return l.confirmRecipientAndDataScope;
    case "确认本次发送":
      return l.confirmThisRequest;
    case "追问只携带原报告和最近六轮完整问答，较早聊天保留本机但不再发送。":
      return l.followUpsIncludeTheOriginalReportAnd;
    case "查看实际发送内容":
      return l.viewExactRequestContent;
    case "取消":
      return l.cancel;
    case "确认并发送":
      return l.confirmAndSend;
    case "该期间没有已记录数据，或属于未来期间，未发送请求。":
      return l.noRecordedDataForThisPeriodOr;
    case "请分析这份收支汇总：主要分类、与上期变化、月度预算（如有）及可执行建议。不要编造缺失数据。":
      return l.analyzeThisIncomeAndExpenseSummaryMain;
    case "AI 分析":
      return l.aiAnalysis;
    case "历史":
      return l.history;
    case "AI 服务":
      return l.aiService;
    case "本地事实 · AI 不负责计算":
      return l.localFactsAiDoesNotCalculateTotals;
    case "上期为零，不计算增长百分比。":
      return l.thePreviousPeriodIsZeroNoGrowth;
    case "查看统计汇总":
      return l.viewStatisticalSummary;
    case "仅代表已记录账目，不包含未来账单。AI 建议可能有误，不会修改账本。":
      return l.onlyRecordedEntriesAreIncludedExcludingFuture;
    case "账本已更新，本对话仍基于旧数据；可重新分析。":
      return l.yourLedgerHasChangedThisConversationStill;
    case "服务或模型已改变。旧对话只供查看，不会转发，请生成新报告。":
      return l.theServiceOrModelHasChangedOld;
    case "生成分析":
      return l.generateAnalysis;
    case "重新分析 · 新对话":
      return l.analyzeAgainNewConversation;
    case "配置 AI 服务":
      return l.configureAiService;
    case "停止生成":
      return l.stopGenerating;
    case "没有可分析的已记录数据，或所选期间在未来。不会请求 API。":
      return l.noRecordedDataToAnalyzeOrThe;
    case "仅重试本地保存":
      return l.retryLocalSaveOnly;
    case "回复已复制，请妥善保存。":
      return l.replyCopiedKeepItSomewhereSafe;
    case "复制失败，请长按回复手动复制。":
      return l.copyFailedLongPressTheReplyTo;
    case "复制回复":
      return l.copyReply;
    case "正在等待回复…":
      return l.waitingForAReply;
    case "生成中…":
      return l.generating;
    case "已完成":
      return l.complete;
    case "未完成":
      return l.incomplete;
    case "已停止":
      return l.stopped;
    case "继续追问":
      return l.askAFollowUp;
    case "聊天内容会发送，请勿输入敏感信息":
      return l.messagesWillBeSentDoNotEnter;
    case "预览并发送":
      return l.previewAndSend;
    case "AI 历史":
      return l.aiHistory;
    case "还没有 AI 记录":
      return l.noAiRecordsYet;
    case "生成报告后，会加密保存在本机。":
      return l.generatedReportsAreEncryptedAndSavedOn;
    case "报告已完成":
      return l.reportComplete;
    case "报告未完成":
      return l.reportIncomplete;
    case "删除对话":
      return l.deleteConversation;
    case "删除这段对话？":
      return l.deleteThisConversation;
    case "同时删除本地报告、聊天和关联汇总。不会删除账本或服务商副本。":
      return l.deletesTheLocalReportChatAndAssociated;
    case "删除":
      return l.delete;
    case "选择模型":
      return l.chooseModel;
    case "搜索模型名称或 ID":
      return l.searchModelNameOrId;
    case "没有匹配模型，仍可在设置页手动填写。":
      return l.noMatchingModelYouCanStillEnter;
    case "目录注明文本能力 · 实际兼容性需测试":
      return l.listedAsTextCapableCompatibilityNeedsTesting;
    case "兼容性未验证":
      return l.compatibilityUnverified;
    case "无法打开系统浏览器":
      return l.cannotOpenTheSystemBrowser;
    case "关闭":
      return l.close;
    case "复制链接":
      return l.copyLink;
    case "AI 操作未完成，账本不受影响，请检查本机存储。":
      return l.aiOperationFailedYourLedgerIsUnaffected67;
    case "新服务地址需要重新填写密钥，不会沿用其他地址的密钥。":
      return l.aNewServiceAddressNeedsItsOwn;
    case "AI 配置已保存，不会自动联网。":
      return l.aiConfigurationSavedNoAutomaticNetworkRequest;
    case "表单有未保存修改，请先保存配置。":
      return l.youHaveUnsavedChangesSaveTheConfiguration;
    case "请先保存配置。":
      return l.saveTheConfigurationFirst;
    case "测试连接？":
      return l.testConnection;
    case "发送测试":
      return l.sendTest;
    case "表单有未保存修改，请先保存配置后刷新。":
      return l.youHaveUnsavedChangesSaveBeforeRefreshing;
    case "请先保存此地址的密钥。":
      return l.saveTheKeyForThisAddressFirst;
    case "查询模型列表？":
      return l.queryModelList;
    case "确认查询":
      return l.confirmQuery;
    case "可选联网分析 · 账本仍在本机\n选服务商 → 选模型 → 获取密钥 → 保存配置\n仅支持 OpenAI 兼容文本聊天，密钥由你提供。":
      return l.optionalOnlineAnalysisYourLedgerStaysLocal;
    case "服务商":
      return l.provider;
    case "请选择服务商":
      return l.chooseAProvider;
    case "自定义":
      return l.custom;
    case "完整 HTTPS 聊天端点":
      return l.fullHttpsChatEndpoint;
    case "https://你的服务地址/v1/chat/completions":
      return l.httpsYourServiceVChatCompletions;
    case "北京在线模型查询需要业务空间专属域名；普通聊天地址仍可保存使用。请先查看官方说明，再填写完整空间地址和此地址密钥。":
      return l.beijingModelQueriesRequireAWorkspaceSpecific;
    case "模型名称":
      return l.modelName;
    case "可手动填写精确模型 ID":
      return l.youCanEnterAnExactModelId;
    case "在线刷新暂不支持":
      return l.onlineRefreshIsNotSupportedYet;
    case "刷新模型列表":
      return l.refreshModelList;
    case "已取消模型刷新，原列表已保留。":
      return l.modelRefreshCancelledThePreviousListIs;
    case "取消刷新":
      return l.cancelRefresh;
    case "列表来源：内置目录（未在线刷新）":
      return l.sourceBuiltInCatalogNotRefreshedOnline;
    case "当前列表未包含此模型，请核对权限或选择其他模型":
      return l.thisModelIsNotInTheCurrent;
    case "模型目录不保证账号权限或实时可用性；不会自动换模型或重发聊天。":
      return l.theCatalogDoesNotGuaranteeAccessOr;
    case "同源 HTTPS 模型列表地址（可选）":
      return l.sameOriginHttpsModelListAddressOptional;
    case "不填写时不会猜测模型列表地址":
      return l.leaveBlankToAvoidGuessingAModel;
    case "获取 API 密钥":
      return l.getApiKey;
    case "查看模型说明":
      return l.viewModelDocumentation;
    case "API 密钥":
      return l.apiKey;
    case "此地址已有密钥；留空保留，更换地址需重填":
      return l.keySavedForThisAddressLeaveBlank;
    case "仅存储在本机系统安全存储中":
      return l.storedOnlyInThisDeviceSSecure;
    case "逐步显示回复":
      return l.streamReplies;
    case "关闭后等待完整回复；不自动切换模式重试":
      return l.turnOffToWaitForCompleteReplies;
    case "输出限制参数 · 1536 tokens":
      return l.outputLimitParameterTokens;
    case "有未保存修改，请先保存再刷新模型或测试连接。":
      return l.saveChangesBeforeRefreshingModelsOrTesting;
    case "保存配置":
      return l.saveConfiguration;
    case "测试已保存配置":
      return l.testSavedConfiguration;
    case "停止请求":
      return l.stopRequest;
    case "只有主动操作才联网。首次查询确认接收地址；模型查询只发送认证，不发送账本或聊天。\n\n聊天可能计费，首次发送确认数据范围。API 密钥、加密模型缓存、报告和聊天均不进入账本备份。更换或删除密钥清除模型缓存，不迁移聊天。":
      return l.networkAccessOccursOnlyAfterAnExplicit;
    case "删除 API 密钥？":
      return l.deleteApiKey;
    case "删除密钥及模型缓存，不删除账本或聊天历史。再次分析需要重新填写密钥。":
      return l.deletesTheKeyAndModelCacheNot;
    case "API 密钥和模型缓存已删除。":
      return l.apiKeyAndModelCacheDeleted;
    case "删除 API 密钥":
      return l.deleteApiKey115;
    case "清空全部 AI 记录？":
      return l.clearAllAiRecords;
    case "删除本地报告、聊天、快照及模型缓存，不删除账本或 API 密钥，也不删除服务商副本。":
      return l.deletesLocalReportsChatsSnapshotsAndModel;
    case "清空记录":
      return l.clearRecords;
    case "本地 AI 记录已清空。":
      return l.localAiRecordsCleared;
    case "清空全部 AI 记录":
      return l.clearAllAiRecords120;
    case "收支分析":
      return l.incomeAndExpenseAnalysis;
    case "支出":
      return l.expenses;
    case "收入":
      return l.income;
    case "查看 / 生成分析":
      return l.viewGenerateAnalysis;
    case "分类占比":
      return l.categoryBreakdown;
    case "年度收支对比":
      return l.annualIncomeAndExpenses;
    case "月度支出趋势":
      return l.monthlyExpenseTrend;
    case "月度收入趋势":
      return l.monthlyIncomeTrend;
    case "● 收入":
      return l.income131;
    case "● 支出":
      return l.expenses132;
    case "趋势会出现在这里":
      return l.trendsWillAppearHere;
    case "记录收支后，即可看到花费的变化。":
      return l.recordIncomeAndExpensesToSeeHow;
    case "每月收入与支出对比图":
      return l.monthlyIncomeAndExpenseComparisonChart;
    case "还没有分类数据":
      return l.noCategoryDataYet;
    case "记录一笔收支，看看钱花在哪里。":
      return l.addAnEntryToSeeWhereYour;
    case "总收入":
      return l.totalIncome;
    case "总支出":
      return l.totalExpenses;
    case "操作未完成，请重试。原有数据仍保留。":
      return l.operationFailedPleaseRetryYourExistingData;
    case "确认":
      return l.confirm;
    case "还没有记录":
      return l.noEntriesYet;
    case "记下第一笔，让每一笔花费都有迹可循。":
      return l.startWithOneEntryAndKeepTrack;
    case "暂时无法读取数据":
      return l.cannotReadDataRightNow;
    case "请重试，账本文件不会被清空。":
      return l.pleaseRetryYourLedgerFileWillNot;
    case "上一期":
      return l.previousPeriod;
    case "年份":
      return l.year;
    case "日期":
      return l.date;
    case "下一期":
      return l.nextPeriod;
    case "日":
      return l.day;
    case "月":
      return l.month;
    case "年":
      return l.year156;
    case "已超支":
      return l.overBudget;
    case "剩余":
      return l.remaining;
    case "已达到预算，请留意后续支出":
      return l.budgetReachedWatchUpcomingExpenses;
    case "预算已使用 80% 以上":
      return l.overOfBudgetUsed;
    case "未注明":
      return l.unspecified;
    case "请输入大于 0、最多两位小数的金额":
      return l.enterAnAmountGreaterThanZeroWith;
    case "请先在设置中添加或启用分类":
      return l.addOrEnableACategoryInSettings;
    case "已记下这一笔":
      return l.entrySaved;
    case "账单已更新":
      return l.entryUpdated;
    case "删除这笔账单？":
      return l.deleteThisEntry;
    case "账单已删除":
      return l.entryDeleted;
    case "编辑账单":
      return l.editEntry;
    case "删除账单":
      return l.deleteEntry;
    case "还没有可用分类":
      return l.noAvailableCategories;
    case "请到设置中的分类管理添加或启用分类。":
      return l.addOrEnableCategoriesInSettingsCategories;
    case "支付方式":
      return l.paymentMethod;
    case "备注（可选）":
      return l.noteOptional;
    case "保存账单":
      return l.saveEntry;
    case "保存修改":
      return l.saveChanges;
    case "全部日期":
      return l.allDates;
    case "筛选账单日期":
      return l.filterEntryDates;
    case "应用":
      return l.apply;
    case "导出筛选账单":
      return l.exportFilteredEntries;
    case "账单已导出":
      return l.entriesExported;
    case "选择日期范围":
      return l.chooseDateRange;
    case "上个月":
      return l.previousMonth;
    case "下个月":
      return l.nextMonth;
    case "列表":
      return l.list;
    case "日历":
      return l.calendar;
    case "搜索备注或分类":
      return l.searchNotesOrCategories;
    case "清除搜索":
      return l.clearSearch;
    case "全部类型":
      return l.allTypes;
    case "全部分类":
      return l.allCategories;
    case "（已停用）":
      return l.disabled;
    case "全部支付方式":
      return l.allPaymentMethods;
    case "读取账单失败":
      return l.failedToReadEntries;
    case "没有符合条件的账单":
      return l.noMatchingEntries;
    case "试着调整筛选条件，或返回总览记一笔。":
      return l.adjustTheFiltersOrReturnToOverview;
    case "正在加载…":
      return l.loading;
    case "一":
      return l.mon;
    case "二":
      return l.tue;
    case "三":
      return l.wed;
    case "四":
      return l.thu;
    case "五":
      return l.fri;
    case "六":
      return l.sat;
    case "点击日期查看账单，或写一段当天的小记。\n金额遵循当前筛选条件。":
      return l.tapADateToViewEntriesOr;
    case "为这一天记账":
      return l.addAnEntryForThisDay;
    case "这一天还没有符合条件的账单":
      return l.noMatchingEntriesForThisDay;
    case "可以补记账单，也可以留下小记。":
      return l.addAnEntryOrLeaveADaily;
    case "每日小记":
      return l.dailyNote;
    case "今天有哪些值得记下的事情？":
      return l.whatWouldYouLikeToRememberAbout;
    case "小记已保存":
      return l.dailyNoteSaved;
    case "保存中…":
      return l.saving;
    case "保存小记":
      return l.saveDailyNote;
    case "切换到浅色主题":
      return l.switchToLightTheme;
    case "切换到深色主题":
      return l.switchToDarkTheme;
    case "结余":
      return l.balance;
    case "月度预算":
      return l.monthlyBudget;
    case "设置预算，让花费更有分寸":
      return l.setABudgetToPlanYourSpending;
    case "年度收支":
      return l.annualIncomeAndExpenses227;
    case "支出趋势":
      return l.expenseTrend;
    case "最近账单":
      return l.recentEntries;
    case "记下第一笔":
      return l.addYourFirstEntry;
    case "完整备份已保存":
      return l.fullBackupSaved;
    case "恢复这份备份？":
      return l.restoreThisBackup;
    case "先备份现有账本":
      return l.backUpCurrentLedgerFirst;
    case "替换并恢复":
      return l.replaceAndRestore;
    case "现有账本已备份":
      return l.currentLedgerBackedUp;
    case "现在用选中的备份替换当前账本？":
      return l.replaceTheCurrentLedgerWithTheSelected;
    case "账本已恢复":
      return l.ledgerRestored;
    case "属于你的，安静的收支手账。":
      return l.yourQuietPersonalIncomeAndExpenseJournal;
    case "深色主题":
      return l.darkTheme;
    case "C · 深色暖灰":
      return l.cWarmDarkGray;
    case "A · 暖白陶土":
      return l.aWarmWhiteAndTerracotta;
    case "流畅优先":
      return l.reduceMotion;
    case "减少页面和图表动画":
      return l.reducePageAndChartAnimations;
    case "分类管理":
      return l.categories;
    case "自定义分类名称、图标和启用状态":
      return l.customizeNamesIconsAndEnabledStatus;
    case "设置总预算和分类预算":
      return l.setOverallAndCategoryBudgets;
    case "可选联网分析 · 配置接口与管理本地聊天":
      return l.optionalOnlineAnalysisConfigureServiceAndLocal;
    case "导入微信账单":
      return l.importWechatStatements;
    case "CSV / .xlsx · 预览、去重与分类确认":
      return l.csvXlsxPreviewDeduplicationAndCategoryReview;
    case "完整备份":
      return l.fullBackup;
    case "包含全部账单、预算、小记及设置":
      return l.includesAllEntriesBudgetsDailyNotesAnd;
    case "恢复备份":
      return l.restoreBackup;
    case "使用简账 JSON 备份文件替换账本":
      return l.replaceTheLedgerUsingAJsonBackup;
    case "导出全部账单":
      return l.exportAllEntries;
    case "CSV 文件；筛选导出请前往账单页":
      return l.csvFileExportFilteredEntriesFromThe;
    case "全部账单已导出":
      return l.allEntriesExported;
    case "数据与隐私":
      return l.dataAndPrivacy;
    case "账本保存在这台设备上，无需账号，离线可用。只有你主动使用 AI 时，统计汇总和必要聊天上下文才发送到你配置的服务地址；不上传单笔账单、备注或小记。\n\n请定期保存账本备份。卸载应用或清除数据会删除本机账本及 AI 历史；AI 记录和密钥不包含在账本备份中。CSV 文件不用于恢复。账本备份未加密，请保存在信任的位置。":
      return l.yourLedgerStaysOnThisDeviceWorks;
    case "开源许可":
      return l.openSourceLicenses;
    case "月度总预算":
      return l.monthlyOverallBudget;
    case "复制上月预算？":
      return l.copyLastMonthSBudgets;
    case "只补充本月尚未设置的预算，不覆盖已有额度。":
      return l.onlyAddsBudgetsNotYetSetThis;
    case "复制":
      return l.copy;
    case "上月没有可复制的预算，或本月已全部设置":
      return l.noBudgetsToCopyOrAllBudgets;
    case "复制上月预算":
      return l.copyLastMonthSBudgets269;
    case "总支出预算":
      return l.overallExpenseBudget;
    case "分类预算":
      return l.categoryBudgets;
    case "总预算和分类预算分别统计，分类额度之和不必等于总预算。":
      return l.overallAndCategoryBudgetsAreTrackedSeparately;
    case "未设置 · 点击添加":
      return l.notSetTapToAdd;
    case "请输入预算金额":
      return l.enterBudgetAmount;
    case "移除预算":
      return l.removeBudget;
    case "请输入有效金额，最多两位小数":
      return l.enterAValidAmountWithUpTo;
    case "保存":
      return l.save;
    case "添加分类":
      return l.addCategory;
    case "点击修改名称或图标":
      return l.tapToChangeNameOrIcon;
    case "已停用 · 历史记录保留":
      return l.disabledHistoryPreserved;
    case "编辑分类":
      return l.editCategory;
    case "分类名称":
      return l.categoryName;
    case "请输入分类名称":
      return l.enterACategoryName;
    case "文件读取失败，请重新导出":
      return l.failedToReadTheFileExportIt;
    case "文件超过 20 MB，请分段导出":
      return l.fileExceedsMbExportItInSmaller;
    case "读取失败，请检查文件并重试":
      return l.failedToReadCheckTheFileAnd;
    case "确认这笔交易的含义":
      return l.confirmWhatThisTransactionMeans;
    case "调整分类":
      return l.adjustCategory;
    case "分类建议仅供参考，可以手动调整。":
      return l.categorySuggestionsAreForReferenceAndCan;
    case "作为":
      return l.importAs;
    case "分类":
      return l.category;
    case "没有可用分类，请先在分类管理中启用或添加分类。":
      return l.noCategoriesAvailableAddOrEnableA;
    case "确认并选入":
      return l.confirmAndSelect;
    case "批量设置已选账单分类":
      return l.setCategoryForSelectedEntries;
    case "将新增选中的账单，不覆盖已有记录。建议先在设置中保存完整备份。":
      return l.addsSelectedEntriesWithoutOverwritingExistingRecords;
    case "确认导入":
      return l.confirmImport;
    case "导入失败，原账本未更改。请重新选择文件预览，检查分类及待确认账单。":
      return l.importFailedYourOriginalLedgerIsUnchanged;
    case "缺少分类":
      return l.missingCategory;
    case "可导入":
      return l.readyToImport;
    case "已确认":
      return l.confirmed;
    case "待确认":
      return l.needsConfirmation;
    case "异常":
      return l.invalid;
    case "不入账":
      return l.excluded;
    case "重复":
      return l.duplicate;
    case "冲突":
      return l.conflict;
    case "返回":
      return l.back;
    case "本机解析 CSV / .xlsx，不上传账单。退款、转账等需单独确认。文件上限 20 MB / 20,000 条。":
      return l.csvXlsxIsParsedOnThisDevice;
    case "正在提交，请稍候…":
      return l.submittingPleaseWait;
    case "正在读取与解析…":
      return l.readingAndParsing;
    case "取消解析":
      return l.cancelParsing;
    case "选择微信账单文件":
      return l.chooseWechatStatementFile;
    case "重新选择文件":
      return l.chooseAnotherFile;
    case "选择可导入账单":
      return l.selectImportableEntries;
    case "全部取消":
      return l.deselectAll;
    case "批量分类":
      return l.bulkCategory;
    case "无效日期":
      return l.invalidDate;
    case "无效金额":
      return l.invalidAmount;
    case "缺少可用分类，请在分类管理中启用或添加分类后重新预览。":
      return l.noAvailableCategoryAddOrEnableOne;
    case "未设置分类":
      return l.categoryNotSet;
    case "通义千问 · 百炼":
      return l.systemQwenBailian0;
    case "千问 Flash":
      return l.systemQwenFlash1;
    case "千问 Plus":
      return l.systemQwenPlus2;
    case "智谱 · GLM":
      return l.systemZhipuGlm3;
    case "DeepSeek V4 Flash · 硅基流动":
      return l.systemDeepseekVFlashSiliconflow4;
    case "Kimi K2.7 Code · 硅基流动":
      return l.systemKimiKCodeSiliconflow5;
    case "请填写不含用户名、片段或空格的完整 HTTPS 模型列表地址。":
      return l.systemEnterAFullHttpsModelListAddress6;
    case "模型列表地址必须与聊天端点同源，不会跨域发送密钥。":
      return l.systemTheModelListAddressMustShareThe7;
    case "智谱暂不支持在线获取模型列表，请使用内置列表或查看官方模型说明。":
      return l.systemZhipuOnlineModelQueriesAreNotSupported8;
    case "北京地域查询需要业务空间专属域名。请根据官方说明，将完整聊天端点填写为 https://业务空间ID.cn-beijing.maas.aliyuncs.com/compatible-mode/v1/chat/completions，重新填写此地址的密钥并保存。不会猜测空间或跨地域发送密钥。":
      return l.systemBeijingQueriesRequireAWorkspaceSpecificDomain9;
    case "自定义服务需要先填写同源 HTTPS 模型列表地址并保存，不会猜测地址。":
      return l.systemForACustomServiceEnterAndSave10;
    case "请先保存有效密钥。":
      return l.systemSaveAValidKeyFirst11;
    case "模型刷新超时，原列表和刷新时间已保留。":
      return l.systemModelRefreshTimedOutThePreviousList12;
    case "模型查询证书验证失败，未绕过证书校验。":
      return l.systemModelQueryCertificateVerificationFailedCertificateChecks13;
    case "模型刷新网络失败，原列表已保留，请检查网络。":
      return l.systemModelRefreshNetworkErrorThePreviousList14;
    case "模型列表格式错误，原列表已保留。":
      return l.systemInvalidModelListFormatThePreviousList15;
    case "模型查询鉴权失败，请核对密钥和账号权限。":
      return l.systemModelQueryAuthenticationFailedCheckYourKey16;
    case "接口不支持此模型列表地址，请使用手动输入或查看官方说明。":
      return l.systemThisModelListUrlIsUnsupportedEnter17;
    case "模型查询被限流或额度不足，不会自动重试。":
      return l.systemModelQueryRateLimitOrInsufficientQuota18;
    case "模型查询拒绝重定向，不会转发密钥。":
      return l.systemModelQueryRedirectRefusedTheKeyWas19;
    case "模型列表为空，原列表已保留。":
      return l.systemEmptyModelListThePreviousListIs21;
    case "模型列表超过 2 MB，列表不完整，未替换缓存。":
      return l.systemModelListExceedsMbAndIsIncomplete22;
    case "千问模型分页格式错误，未替换缓存。":
      return l.systemInvalidQwenPaginationFormatCacheNotReplaced23;
    case "模型分页总数异常或超过 2,000 条，列表不完整，未替换缓存。":
      return l.systemInvalidPaginationTotalOrOverModelsIncomplete24;
    case "模型列表分页未完成，未替换缓存。":
      return l.systemModelPaginationIsIncompleteCacheNotReplaced25;
    case "模型列表超过 2,000 条，未替换缓存。":
      return l.systemModelListExceedsItemsCacheNotReplaced26;
    case "模型目录项损坏，原列表已保留。":
      return l.systemCorruptModelCatalogEntryThePreviousList27;
    case "模型 ID 无效，原列表已保留。":
      return l.systemInvalidModelIdThePreviousListIs28;
    case "未返回可选择的文本模型，原列表已保留。":
      return l.systemNoSelectableTextModelReturnedThePrevious29;
    case "模型分页未完成，未替换缓存。":
      return l.systemModelPaginationIsIncompleteCacheNotReplaced30;
    case "模型列表超过 20 页，列表不完整，未替换缓存。":
      return l.systemModelListExceedsPagesAndIsIncomplete31;
    case "密钥无效或没有模型权限，请检查配置。":
      return l.systemInvalidKeyOrNoModelAccessCheck32;
    case "额度不足或请求被限流，请到服务商检查后手动重试。":
      return l.systemInsufficientQuotaOrRateLimitedCheckWith33;
    case "网络连接失败，请检查网络后手动重试。":
      return l.systemNetworkConnectionFailedCheckYourConnectionAnd34;
    case "请求超时，未自动重发；服务商可能已处理并计费。":
      return l.systemRequestTimedOutAndWasNotResent35;
    case "安全证书验证失败，不会跳过验证。":
      return l.systemCertificateVerificationFailedVerificationWillNotBe36;
    case "接口或回复格式不兼容，请检查端点、模型、输出限制参数或切换完整回复模式。":
      return l.systemIncompatibleApiOrReplyFormatCheckEndpoint37;
    case "请求已停止；不能保证服务商停止处理或免收费用。":
      return l.systemRequestStoppedProviderProcessingOrChargesMay38;
    case "上下文超过 96 KiB。":
      return l.systemContextExceedsKib39;
    case "请填写完整 HTTPS 聊天端点，不含用户名、查询参数或片段。":
      return l.systemEnterAFullHttpsChatEndpointWithout40;
    case "请填写模型名称并选择输出限制参数。":
      return l.systemEnterAModelNameAndChooseThe41;
    case "请输入问题，最多 2000 字。":
      return l.systemEnterAQuestionOfUpToCharacters42;
    case "本次上下文超过 96 KiB，请开启新对话或缩小分析范围。":
      return l.systemContextExceedsKibStartANewConversation43;
    case "请先停止当前请求。":
      return l.systemStopTheCurrentRequestFirst44;
    case "当前请求尚未结束。":
      return l.systemARequestIsStillRunning45;
    case "本地记录尚未保存，请先仅重试保存或复制回复，不会自动重发请求。":
      return l.systemLocalRecordsAreNotSavedRetryLocal46;
    case "服务或模型已改变，请生成新报告，不会转发旧对话。":
      return l.systemServiceOrModelChangedGenerateANew47;
    case "所选期间没有已记录数据，或属于未来期间。":
      return l.systemNoRecordedDataInThisPeriodOr48;
    case "请先配置此服务地址的 API 密钥。":
      return l.systemConfigureAnApiKeyForThisService49;
    case "请先确认数据发送范围和服务地址。":
      return l.systemConfirmTheDataScopeAndServiceAddress50;
    case "回复达到输出限制，内容未完整；不会作为追问上下文。":
      return l.systemOutputLimitReachedThisIncompleteReplyWill51;
    case "操作未完成，未自动重发。账本不受影响。":
      return l.systemOperationIncompleteNoAutomaticResendYourLedger52;
    case "回复已完成，但本地保存失败。服务商可能已计费，关闭应用前结果尚未持久化；请仅重试保存或复制回复。":
      return l.systemReplyCompletedButLocalSavingFailedThe53;
    case "本地记录保存失败，关闭应用前记录尚未持久化；请仅重试保存或复制回复，不会重发网络请求。":
      return l.systemLocalSavingFailedRecordsAreNotDurable54;
    case "请等待当前操作结束。":
      return l.systemWaitForTheCurrentOperationToFinish55;
    case "请等待当前请求结束。":
      return l.systemWaitForTheCurrentRequestToFinish56;
    case "请先保存接口配置。":
      return l.systemSaveTheServiceConfigurationFirst57;
    case "这是接口连接测试，不含账本。请只回复：连接成功。":
      return l.systemThisIsAConnectionTestWithNo58;
    case "请先保存 API 密钥。":
      return l.systemSaveAnApiKeyFirst59;
    case "，接口未返回用量":
      return l.systemApiUsageWasNotReported61;
    case "请先停止请求。":
      return l.systemStopTheRequestFirst63;
    case "AI 配置无法读取，请重新设置；账本不受影响。":
      return l.systemAiConfigurationCouldNotBeReadConfigure67;
    case "请填写有效密钥。":
      return l.systemEnterAValidKey68;
    case "模型缓存密钥不可用。":
      return l.systemModelCacheEncryptionKeyUnavailable69;
    case "模型缓存无效。":
      return l.systemInvalidModelCache70;
    case "本地模型缓存无法读取，原文件保留；可手动刷新，账本和聊天不受影响。":
      return l.systemCannotReadTheLocalModelCacheOriginal71;
    case "AI 记录加密密钥不可用。记录未删除，可清空 AI 记录后重新开始。":
      return l.systemAiEncryptionKeyUnavailableRecordsAreNot72;
    case "上次请求被中断，未自动重发。":
      return l.systemThePreviousRequestWasInterruptedAndWas73;
    case "AI 记录损坏或无法解密，原文件保留。可清空 AI 记录；账本不受影响。":
      return l.systemAiRecordsAreCorruptOrCannotBe74;
    case "无效 AI 记录编号。":
      return l.systemInvalidAiRecordId75;
    case "正在执行其他数据操作":
      return l.systemAnotherDataOperationIsRunning76;
    case "保存完整备份":
      return l.systemSaveFullBackup77;
    case "备份文件超过 50 MB，暂不支持恢复":
      return l.systemBackupExceedsMbAndCannotBeRestored79;
    case "账本来自较新的应用版本。请保留现有数据并安装支持该账本的新版；不要卸载或清除数据。":
      return l.systemThisLedgerRequiresANewerAppKeep81;
    case "交易单号重复，跳过":
      return l.systemDuplicateTransactionNumberSkipped84;
    case "与已有账单疑似重复，请确认是否仍要导入":
      return l.systemPossiblyDuplicatesAnExistingEntryConfirmWhether85;
    case "导入条数超限":
      return l.systemTooManyEntriesToImport86;
    case "预览已变化或存在未确认账单，请重新预览；原账本未更改":
      return l.systemPreviewChangedOrEntriesNeedConfirmationPreview87;
    case "请填写有效的分类名称和图标":
      return l.systemEnterAValidCategoryNameAndIcon88;
    case "已有分类不能更改收支类型":
      return l.systemCannotChangeAnExistingCategorySIncome89;
    case "请检查金额、日期或备注":
      return l.systemCheckTheAmountDateOrNote90;
    case "分类与收支类型不匹配":
      return l.systemCategoryDoesNotMatchIncomeExpenseType91;
    case "此分类已停用，请选择其他分类":
      return l.systemCategoryDisabledChooseAnotherOne92;
    case "预算金额无效":
      return l.systemInvalidBudgetAmount93;
    case "预算仅支持支出分类":
      return l.systemBudgetsSupportExpenseCategoriesOnly94;
    case "小记内容无效":
      return l.systemInvalidDailyNote95;
    case "这不是有效的简账备份文件":
      return l.systemNotAValidBackupFile96;
    case "备份内容不完整或格式错误，原账本未更改":
      return l.systemIncompleteOrInvalidBackupOriginalLedgerUnchanged97;
    case "不支持此备份格式或版本":
      return l.systemUnsupportedBackupFormatOrVersion98;
    case "请选择微信 CSV 或 .xlsx，压缩包和 PDF 暂不支持":
      return l.systemChooseWechatCsvOrXlsxArchivesAnd109;
    case "文件编码损坏，无法可靠读取":
      return l.systemFileEncodingIsCorruptAndCannotBe110;
    case "文件损坏、已加密或格式不支持，请重新导出未加密账单":
      return l.systemFileIsCorruptEncryptedOrUnsupportedExport111;
    case "账单存在重复列名":
      return l.systemStatementContainsDuplicateColumnNames112;
    case "未识别微信账单表头，请使用个人对账文件":
      return l.systemWechatStatementHeaderNotRecognizedUseA113;
    case "明细超过 20,000 条，请分段导出":
      return l.systemMoreThanEntriesExportInSmallerParts115;
    case "日期、金额、单号或必需字段无效，不能入账":
      return l.systemInvalidDateAmountTransactionNumberOrRequired116;
    case "失败、关闭或撤销交易不入账":
      return l.systemFailedClosedOrCancelledTransactionsAreExcluded118;
    case "特殊交易、未知状态或缺少单号，请确认收支含义":
      return l.systemSpecialTransactionUnknownStatusOrMissingNumber120;
    case "账单没有可预览的明细":
      return l.systemNoEntriesAvailableToPreview121;
    case "表格解压内容过大，请分段导出":
      return l.systemUncompressedSpreadsheetIsTooLargeExportIn122;
    case "表格内容校验失败，请重新导出":
      return l.systemSpreadsheetValidationFailedExportItAgain123;
    case "不支持的 XML 内容":
      return l.systemUnsupportedXmlContent124;
    case "不是有效的 .xlsx 文件":
      return l.systemNotAValidXlsxFile125;
    case "表格行号无效或过大，请分段导出":
      return l.systemInvalidOrExcessiveRowIndexExportIn126;
    case "表格行数过大，请分段导出":
      return l.systemTooManySpreadsheetRowsExportInSmaller127;
    case "单元格地址无效":
      return l.systemInvalidCellAddress128;
    case "表格列数过大":
      return l.systemTooManySpreadsheetColumns129;
    case "包含多个账单工作表，请分别导出":
      return l.systemMultipleStatementWorksheetsFoundExportThemSeparately132;
    case "未找到微信明细工作表":
      return l.systemWechatDetailWorksheetNotFound133;
  }
  final m0 = RegExp(
    "^接收地址：([\\s\\S]*?)\\\n模型：([\\s\\S]*?)\\\n\\\n仅含统计汇总、分类名称和本对话必要上下文，不含账单明细。可能产生\\ API\\ 费用，删除本地记录不删除服务商副本。\$",
  ).firstMatch(message);
  if (m0 != null) {
    return l.recipientPModelPOnlyStatisticalSummaries(
      systemMessage(context, m0.group(1)!) ?? m0.group(1)!,
      systemMessage(context, m0.group(2)!) ?? m0.group(2)!,
    );
  }
  final m1 = RegExp(
    "^收入\\ ([\\s\\S]*?)\\\n支出\\ ([\\s\\S]*?)\\\n结余\\ ([\\s\\S]*?)\$",
  ).firstMatch(message);
  if (m1 != null) {
    return l.incomePExpensesPBalanceP(
      systemMessage(context, m1.group(1)!) ?? m1.group(1)!,
      systemMessage(context, m1.group(2)!) ?? m1.group(2)!,
      systemMessage(context, m1.group(3)!) ?? m1.group(3)!,
    );
  }
  final m2 = RegExp(
    "^统计范围：([\\s\\S]*?)\\ 至\\ ([\\s\\S]*?)（不含末日）\\\n比较范围：([\\s\\S]*?)\\ 至\\ ([\\s\\S]*?)（不含末日）\\\n生成依据时间：([\\s\\S]*?)\$",
  ).firstMatch(message);
  if (m2 != null) {
    return l.periodPToPEndExcludedComparison(
      systemMessage(context, m2.group(1)!) ?? m2.group(1)!,
      systemMessage(context, m2.group(2)!) ?? m2.group(2)!,
      systemMessage(context, m2.group(3)!) ?? m2.group(3)!,
      systemMessage(context, m2.group(4)!) ?? m2.group(4)!,
      systemMessage(context, m2.group(5)!) ?? m2.group(5)!,
    );
  }
  final m3 = RegExp("^较上期变化：([\\s\\S]*?)%（本地计算）\$").firstMatch(message);
  if (m3 != null) {
    return l.changeFromPreviousPeriodPCalculatedLocally(
      systemMessage(context, m3.group(1)!) ?? m3.group(1)!,
    );
  }
  final m4 = RegExp("^接口返回用量：([\\s\\S]*?)\\ tokens\$").firstMatch(message);
  if (m4 != null) {
    return l.reportedUsagePTokens(
      systemMessage(context, m4.group(1)!) ?? m4.group(1)!,
    );
  }
  final m5 = RegExp("^可以复制链接后手动打开：\\\n([\\s\\S]*?)\$").firstMatch(message);
  if (m5 != null) {
    return l.copyThisLinkAndOpenItManually(
      systemMessage(context, m5.group(1)!) ?? m5.group(1)!,
    );
  }
  final m6 = RegExp(
    "^向\\ ([\\s\\S]*?)\\ 发送一条不含账本的短消息。可能产生\\ API\\ 费用，不会自动重试。\$",
  ).firstMatch(message);
  if (m6 != null) {
    return l.sendAShortMessageWithoutLedgerData(
      systemMessage(context, m6.group(1)!) ?? m6.group(1)!,
    );
  }
  final m7 = RegExp(
    "^接收地址：([\\s\\S]*?)\\\n只发送此地址绑定的认证信息，查询账号模型目录。不发送账本、统计或聊天，不进行聊天测试。服务商计费与权限以官方说明为准。\$",
  ).firstMatch(message);
  if (m7 != null) {
    return l.recipientPOnlyAuthenticationBoundToThis(
      systemMessage(context, m7.group(1)!) ?? m7.group(1)!,
    );
  }
  final m8 = RegExp("^列表来源：([\\s\\S]*?)\\\n上次成功刷新：([\\s\\S]*?)\$")
      .firstMatch(message);
  if (m8 != null) {
    return l.sourcePLastSuccessfulRefreshP(
      systemMessage(context, m8.group(1)!) ?? m8.group(1)!,
      systemMessage(context, m8.group(2)!) ?? m8.group(2)!,
    );
  }
  final m9 = RegExp("^([\\s\\S]*?)\\ ·\\ ([\\s\\S]*?)解读；只发送汇总，可查看发送内容\$")
      .firstMatch(message);
  if (m9 != null) {
    return l.pPAnalysisSummariesOnlyWithA(
      systemMessage(context, m9.group(1)!) ?? m9.group(1)!,
      systemMessage(context, m9.group(2)!) ?? m9.group(2)!,
    );
  }
  final m10 = RegExp(r'^(\d+) 笔$').firstMatch(message);
  if (m10 != null) {
    return l.pEntries(int.parse(m10.group(1)!));
  }
  final m11 = RegExp("^([\\s\\S]*?)万\$").firstMatch(message);
  if (m11 != null) {
    return l.p(systemMessage(context, m11.group(1)!) ?? m11.group(1)!);
  }
  final m12 = RegExp("^([\\s\\S]*?)趋势图\$").firstMatch(message);
  if (m12 != null) {
    return l.pTrendChart(
      systemMessage(context, m12.group(1)!) ?? m12.group(1)!,
    );
  }
  final m13 = RegExp("^查看([\\s\\S]*?)\$").firstMatch(message);
  if (m13 != null) {
    return l.viewP(systemMessage(context, m13.group(1)!) ?? m13.group(1)!);
  }
  final m14 = RegExp("^选择([\\s\\S]*?)\$").firstMatch(message);
  if (m14 != null) {
    return l.chooseP(systemMessage(context, m14.group(1)!) ?? m14.group(1)!);
  }
  final m15 = RegExp("^已用\\ ([\\s\\S]*?)\\ ·\\ 预算\\ ([\\s\\S]*?)\$")
      .firstMatch(message);
  if (m15 != null) {
    return l.usedPBudgetP(
      systemMessage(context, m15.group(1)!) ?? m15.group(1)!,
      systemMessage(context, m15.group(2)!) ?? m15.group(2)!,
    );
  }
  final m16 = RegExp("^([\\s\\S]*?)\\ ·\\ ([\\s\\S]*?)\\\n删除后，相关统计和预算会同步更新。\$")
      .firstMatch(message);
  if (m16 != null) {
    return l.pPRelatedStatisticsAndBudgetsWill(
      systemMessage(context, m16.group(1)!) ?? m16.group(1)!,
      systemMessage(context, m16.group(2)!) ?? m16.group(2)!,
    );
  }
  final m17 = RegExp("^金额\\ ([\\s\\S]*?)\\ 元\$").firstMatch(message);
  if (m17 != null) {
    return l.amountPCny(systemMessage(context, m17.group(1)!) ?? m17.group(1)!);
  }
  final m18 = RegExp("^([\\s\\S]*?)分类\$").firstMatch(message);
  if (m18 != null) {
    return l.pCategory(systemMessage(context, m18.group(1)!) ?? m18.group(1)!);
  }
  final m19 = RegExp("^([\\s\\S]*?)年([\\s\\S]*?)月\$").firstMatch(message);
  if (m19 != null) {
    return l.pP(
      systemMessage(context, m19.group(1)!) ?? m19.group(1)!,
      systemMessage(context, m19.group(2)!) ?? m19.group(2)!,
    );
  }
  final m20 = RegExp("^([\\s\\S]*?)年([\\s\\S]*?)月([\\s\\S]*?)日\$")
      .firstMatch(message);
  if (m20 != null) {
    return l.pPP(
      systemMessage(context, m20.group(1)!) ?? m20.group(1)!,
      systemMessage(context, m20.group(2)!) ?? m20.group(2)!,
      systemMessage(context, m20.group(3)!) ?? m20.group(3)!,
    );
  }
  final m21 = RegExp("^收入\\ ([\\s\\S]*?)\$").firstMatch(message);
  if (m21 != null) {
    return l.incomeP(systemMessage(context, m21.group(1)!) ?? m21.group(1)!);
  }
  final m22 = RegExp("^支出\\ ([\\s\\S]*?)\$").firstMatch(message);
  if (m22 != null) {
    return l.expensesP(systemMessage(context, m22.group(1)!) ?? m22.group(1)!);
  }
  final m23 = RegExp("^收入\\ ([\\s\\S]*?)\\ ·\\ 支出\\ ([\\s\\S]*?)\$")
      .firstMatch(message);
  if (m23 != null) {
    return l.incomePExpensesP(
      systemMessage(context, m23.group(1)!) ?? m23.group(1)!,
      systemMessage(context, m23.group(2)!) ?? m23.group(2)!,
    );
  }
  final m24 = RegExp("^加载更多（([\\s\\S]*?)/([\\s\\S]*?)）\$").firstMatch(message);
  if (m24 != null) {
    return l.loadMorePP(
      systemMessage(context, m24.group(1)!) ?? m24.group(1)!,
      systemMessage(context, m24.group(2)!) ?? m24.group(2)!,
    );
  }
  final m25 = RegExp("^([\\s\\S]*?)支出\$").firstMatch(message);
  if (m25 != null) {
    return l.pExpenses(systemMessage(context, m25.group(1)!) ?? m25.group(1)!);
  }
  final m26 = RegExp(
    "^文件包含\\ ([\\s\\S]*?)\\ 笔账单。\\\n\\\n恢复会替换当前账本中的全部账单、分类、预算、小记和设置，不会合并。建议先保存现有账本的备份。\$",
  ).firstMatch(message);
  if (m26 != null) {
    return l.thisFileContainsPEntriesRestoringReplaces(
      systemMessage(context, m26.group(1)!) ?? m26.group(1)!,
    );
  }
  final m27 = RegExp("^简账\\ ([\\s\\S]*?)\\ ·\\ 个人离线账本\$").firstMatch(message);
  if (m27 != null) {
    return l.pPersonalOfflineLedger(
      systemMessage(context, m27.group(1)!) ?? m27.group(1)!,
    );
  }
  final m28 = RegExp("^([\\s\\S]*?)预算\$").firstMatch(message);
  if (m28 != null) {
    return l.pBudget(systemMessage(context, m28.group(1)!) ?? m28.group(1)!);
  }
  final m29 = RegExp("^已复制\\ ([\\s\\S]*?)\\ 项预算\$").firstMatch(message);
  if (m29 != null) {
    return l.copiedPBudgets(
      systemMessage(context, m29.group(1)!) ?? m29.group(1)!,
    );
  }
  final m30 = RegExp("^添加([\\s\\S]*?)分类\$").firstMatch(message);
  if (m30 != null) {
    return l.addPCategory(
      systemMessage(context, m30.group(1)!) ?? m30.group(1)!,
    );
  }
  final m31 = RegExp("^([\\s\\S]*?)\\\n退款不会自动抵扣原消费。作为收入或支出导入将影响统计，请确认。\$")
      .firstMatch(message);
  if (m31 != null) {
    return l.pRefundsDoNotAutomaticallyOffsetThe(
      systemMessage(context, m31.group(1)!) ?? m31.group(1)!,
    );
  }
  final m32 = RegExp("^导入\\ ([\\s\\S]*?)\\ 笔微信账单？\$").firstMatch(message);
  if (m32 != null) {
    return l.importPWechatEntries(
      systemMessage(context, m32.group(1)!) ?? m32.group(1)!,
    );
  }
  final m33 = RegExp(
    "^导入完成：成功\\ ([\\s\\S]*?)\\ 笔，重复跳过\\ ([\\s\\S]*?)\\ 笔，未选入\\ ([\\s\\S]*?)\\ 笔。\$",
  ).firstMatch(message);
  if (m33 != null) {
    return l.importCompletePAddedPDuplicatesSkipped(
      systemMessage(context, m33.group(1)!) ?? m33.group(1)!,
      systemMessage(context, m33.group(2)!) ?? m33.group(2)!,
      systemMessage(context, m33.group(3)!) ?? m33.group(3)!,
    );
  }
  final m34 = RegExp(
    "^共\\ ([\\s\\S]*?)\\ 笔\\ ·\\ 可导入\\ ([\\s\\S]*?)\\ ·\\ 重复\\ ([\\s\\S]*?)\\\n待确认\\ ([\\s\\S]*?)\\ ·\\ 异常/冲突\\ ([\\s\\S]*?)\\ ·\\ 不入账\\ ([\\s\\S]*?)\$",
  ).firstMatch(message);
  if (m34 != null) {
    return l.totalPReadyPDuplicatesPReview(
      systemMessage(context, m34.group(1)!) ?? m34.group(1)!,
      systemMessage(context, m34.group(2)!) ?? m34.group(2)!,
      systemMessage(context, m34.group(3)!) ?? m34.group(3)!,
      systemMessage(context, m34.group(4)!) ?? m34.group(4)!,
      systemMessage(context, m34.group(5)!) ?? m34.group(5)!,
      systemMessage(context, m34.group(6)!) ?? m34.group(6)!,
    );
  }
  final m35 = RegExp(
    "^缺少分类\\ ([\\s\\S]*?)\\ 笔\\ ·\\ 已选\\ ([\\s\\S]*?)\\ 笔\\ ·\\ 收入\\ ([\\s\\S]*?)\\ ·\\ 支出\\ ([\\s\\S]*?)\$",
  ).firstMatch(message);
  if (m35 != null) {
    return l.missingCategoryPSelectedPIncomeP(
      systemMessage(context, m35.group(1)!) ?? m35.group(1)!,
      systemMessage(context, m35.group(2)!) ?? m35.group(2)!,
      systemMessage(context, m35.group(3)!) ?? m35.group(3)!,
      systemMessage(context, m35.group(4)!) ?? m35.group(4)!,
    );
  }
  final m36 = RegExp(
    "^原文件第\\ ([\\s\\S]*?)\\ 行\\ ·\\ ([\\s\\S]*?)\\ ·\\ ([\\s\\S]*?)\$",
  ).firstMatch(message);
  if (m36 != null) {
    return l.sourceRowPPP(
      systemMessage(context, m36.group(1)!) ?? m36.group(1)!,
      systemMessage(context, m36.group(2)!) ?? m36.group(2)!,
      systemMessage(context, m36.group(3)!) ?? m36.group(3)!,
    );
  }
  final m37 = RegExp("^([\\s\\S]*?)\\ ·\\ ([\\s\\S]*?)\\ ·\\ 调整\$")
      .firstMatch(message);
  if (m37 != null) {
    return l.pPAdjust(
      systemMessage(context, m37.group(1)!) ?? m37.group(1)!,
      systemMessage(context, m37.group(2)!) ?? m37.group(2)!,
    );
  }
  final m38 = RegExp("^导入\\ ([\\s\\S]*?)\\ 笔\$").firstMatch(message);
  if (m38 != null) {
    return l.importPEntries(
      systemMessage(context, m38.group(1)!) ?? m38.group(1)!,
    );
  }
  final m39 = RegExp("^模型查询失败（HTTP\\ ([\\s\\S]*?)），原列表已保留。\$")
      .firstMatch(message);
  if (m39 != null) {
    return l.systemModelQueryFailedHttpPThePrevious20(
      systemMessage(context, m39.group(1)!) ?? m39.group(1)!,
    );
  }
  final m40 = RegExp("^连接成功([\\s\\S]*?)。\$").firstMatch(message);
  if (m40 != null) {
    return l.systemConnectedP60(
      systemMessage(context, m40.group(1)!) ?? m40.group(1)!,
    );
  }
  final m41 = RegExp("^，用量\\ ([\\s\\S]*?)\\ tokens\$").firstMatch(message);
  if (m41 != null) {
    return l.systemUsagePTokens62(
      systemMessage(context, m41.group(1)!) ?? m41.group(1)!,
    );
  }
  final m42 = RegExp("^([\\s\\S]*?)\\ ·\\ ([\\s\\S]*?)分析\$")
      .firstMatch(message);
  if (m42 != null) {
    return l.systemPPAnalysis64(
      systemMessage(context, m42.group(1)!) ?? m42.group(1)!,
      systemMessage(context, m42.group(2)!) ?? m42.group(2)!,
    );
  }
  final m43 = RegExp("^同一单号内容或状态冲突（([\\s\\S]*?)），请核对原账单；不会覆盖旧账。([\\s\\S]*?)\$")
      .firstMatch(message);
  if (m43 != null) {
    return l.systemOrderContentOrStatusConflictPReview82(
      systemMessage(context, m43.group(1)!) ?? m43.group(1)!,
      systemMessage(context, m43.group(2)!) ?? m43.group(2)!,
    );
  }
  final m44 = RegExp("^旧导入未记录交易状态，本次为([\\s\\S]*?)，请核对原账单；不会覆盖旧账。([\\s\\S]*?)\$")
      .firstMatch(message);
  if (m44 != null) {
    return l.systemTheOldImportDidNotRecordStatus83(
      systemMessage(context, m44.group(1)!) ?? m44.group(1)!,
      systemMessage(context, m44.group(2)!) ?? m44.group(2)!,
    );
  }
  final m45 = RegExp("^截至([\\s\\S]*?)月([\\s\\S]*?)日\$").firstMatch(message);
  if (m45 != null) {
    return l.systemAsOfPP100(
      systemMessage(context, m45.group(1)!) ?? m45.group(1)!,
      systemMessage(context, m45.group(2)!) ?? m45.group(2)!,
    );
  }
  final m46 = RegExp("^完整([\\s\\S]*?)\$").firstMatch(message);
  if (m46 != null) {
    return l.systemFullP101(
      systemMessage(context, m46.group(1)!) ?? m46.group(1)!,
    );
  }
  return null;
}
