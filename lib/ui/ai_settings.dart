import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/ai_catalog.dart';
import '../core/ai_catalog_client.dart';
import '../core/ai_client.dart';
import '../core/ai_models.dart';
import '../core/ai_service.dart';
import 'ai_catalog_widgets.dart';
import 'common.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({
    super.key,
    required this.service,
    this.catalogClient,
    this.linkOpener = openAiOfficialLink,
  });
  final AiService service;
  final AiModelCatalogClient? catalogClient;
  final AiLinkOpener linkOpener;
  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final _scroll = ScrollController();
  final _endpoint = TextEditingController(),
      _model = TextEditingController(),
      _key = TextEditingController(),
      _catalogUrl = TextEditingController();
  late final AiModelCatalogClient _catalogClient =
      widget.catalogClient ?? DioAiModelCatalogClient();
  bool _loading = true,
      _working = false,
      _streaming = true,
      _hasKey = false,
      _refreshing = false;
  String _tokenField = 'max_tokens';
  String? _error, _savedCatalogUrl;
  AiProvider? _provider;
  AiCatalogResult? _catalog;
  int _generation = 0;
  CancelToken? _cancel;
  AiConfig get _draft => AiConfig(
    endpoint: _endpoint.text.trim(),
    model: _model.text.trim(),
    streaming: _streaming,
    tokenField: _tokenField,
  );
  bool get _dirty {
    final saved = widget.service.config;
    return saved == null ||
        _draft.endpoint != saved.endpoint ||
        _draft.model != saved.model ||
        _streaming != saved.streaming ||
        _tokenField != saved.tokenField ||
        _key.text.isNotEmpty ||
        _catalogUrl.text.trim() != (_savedCatalogUrl ?? '');
  }

  bool get _disabled => _loading || _working || widget.service.busy;
  List<AiCatalogModel> get _models =>
      _catalog?.models ?? _provider?.models ?? [];
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_changed);
    _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _showError(Object error) {
    if (!mounted) return;
    setState(() => _error = _errorText(error));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  String _errorText(Object error) => error is FormatException
      ? error.message
      : error is AiFailure
      ? error.message
      : 'AI 操作未完成，账本不受影响，请检查本机存储。';
  Future<void> _readCatalog() async {
    final endpoint = _endpoint.text.trim();
    final generation = _generation;
    final cached = await widget.service.storage.catalog(endpoint);
    if (mounted &&
        generation == _generation &&
        endpoint == _endpoint.text.trim()) {
      setState(() => _catalog = cached);
    }
  }

  Future<void> _load() async {
    try {
      await widget.service.initialize();
      final config = widget.service.config;
      if (!mounted) return;
      if (config != null) {
        _endpoint.text = config.endpoint;
        _model.text = config.model;
        _streaming = config.streaming;
        _tokenField = config.tokenField;
        _provider = providerForEndpoint(config.endpoint);
        _hasKey = await widget.service.storage.keyFor(config) != null;
        _savedCatalogUrl = await widget.service.storage.catalogAddress(
          config.endpoint,
        );
        if (_savedCatalogUrl?.isNotEmpty == true) _provider = null;
        _catalogUrl.text = _savedCatalogUrl ?? '';
        await _readCatalog();
      }
    } catch (error) {
      _error = _errorText(error);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _invalidate() {
    _generation++;
    _cancel?.cancel();
    _refreshing = false;
  }

  @override
  void dispose() {
    _invalidate();
    widget.service.removeListener(_changed);
    _endpoint.dispose();
    _model.dispose();
    _key.dispose();
    _catalogUrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_disabled || _refreshing) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _selectProvider(String? id) async {
    _invalidate();
    setState(() {
      _provider = aiProviders.where((p) => p.id == id).firstOrNull;
      _catalog = null;
      _key.clear();
      _hasKey = false;
      _error = null;
      _catalogUrl.clear();
      if (_provider != null) {
        _endpoint.text = _provider!.endpoint;
        _model.text = _provider!.models.first.id;
        _tokenField = _provider!.tokenField;
      }
    });
    await _endpointKey();
    try {
      await _readCatalog();
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    }
  }

  Future<void> _endpointKey() async {
    final address = _endpoint.text.trim();
    final generation = _generation;
    final key = await widget.service.storage.keyFor(_draft);
    if (mounted &&
        generation == _generation &&
        address == _endpoint.text.trim()) {
      setState(() => _hasKey = key != null);
    }
  }

  void _editedEndpoint(String _) {
    _invalidate();
    setState(() {
      _provider = providerForEndpoint(_endpoint.text.trim());
      _catalog = null;
      _key.clear();
      _hasKey = false;
      _catalogUrl.clear();
    });
    _endpointKey();
  }

  Future<void> _save() => _run(() async {
    final config = _draft;
    config.validate();
    final address = _provider == null ? _catalogUrl.text.trim() : '';
    if (address.isNotEmpty) validateCatalogUri(config.endpoint, address);
    final oldKey = await widget.service.storage.keyFor(config);
    final key = _key.text.trim().isEmpty ? oldKey : _key.text.trim();
    if (key == null) throw const FormatException('新服务地址需要重新填写密钥，不会沿用其他地址的密钥。');
    _invalidate();
    await widget.service.configure(config, key);
    await widget.service.storage.saveCatalogAddress(
      config.endpoint,
      address.isEmpty ? null : address,
    );
    _savedCatalogUrl = address.isEmpty ? null : address;
    _key.clear();
    _hasKey = true;
    await _readCatalog();
    if (mounted) message(context, 'AI 配置已保存，不会自动联网。');
  });
  Future<void> _test() => _run(() async {
    if (_dirty) throw const FormatException('表单有未保存修改，请先保存配置。');
    final config = widget.service.config;
    if (config == null) throw const FormatException('请先保存配置。');
    if (!await confirm(
          context,
          title: '测试连接？',
          body: '向 ${config.endpoint} 发送一条不含账本的短消息。可能产生 API 费用，不会自动重试。',
          action: '发送测试',
        ) ||
        !mounted) {
      return;
    }
    final result = await widget.service.testConnection();
    if (mounted) message(context, result);
  });
  Future<void> _refresh() async {
    if (_disabled || _refreshing) return;
    if (_dirty) {
      _showError(const FormatException('表单有未保存修改，请先保存配置后刷新。'));
      return;
    }
    final config = widget.service.config!;
    final generation = ++_generation;
    _cancel = CancelToken();
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final uri = catalogUri(config, customUrl: _savedCatalogUrl);
      final key = await widget.service.storage.keyFor(config);
      if (key == null) throw const FormatException('请先保存此地址的密钥。');
      final revision = widget.service.storage.catalogRevision;
      if (!await widget.service.storage.catalogConsented(uri)) {
        if (!mounted || generation != _generation) return;
        if (!await confirm(
              context,
              title: '查询模型列表？',
              body:
                  '接收地址：$uri\n只发送此地址绑定的认证信息，查询账号模型目录。不发送账本、统计或聊天，不进行聊天测试。服务商计费与权限以官方说明为准。',
              action: '确认查询',
            ) ||
            !mounted ||
            generation != _generation) {
          return;
        }
        await widget.service.storage.consentCatalog(uri);
      }
      if (generation != _generation || !mounted) return;
      final result = await _catalogClient.fetch(config, key, uri, _cancel!);
      if (generation != _generation || !mounted || _cancel!.isCancelled) return;
      if (!await widget.service.storage.saveCatalog(
        result,
        key,
        revision,
        isCurrent: () =>
            mounted && generation == _generation && !_cancel!.isCancelled,
      )) {
        return;
      }
      if (generation == _generation && mounted) {
        setState(() => _catalog = result);
      }
    } catch (e) {
      if (generation == _generation && mounted) _showError(e);
    } finally {
      if (generation == _generation && mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _chooseModel() async {
    final selected = await chooseAiModel(context, _models);
    if (selected == null || !mounted) return;
    _invalidate();
    setState(() {
      _model.text = selected.id;
      _tokenField =
          selected.tokenField ??
          (selected.brand != null ? _provider?.tokenField : null) ??
          _tokenField;
    });
  }

  @override
  Widget build(BuildContext context) {
    final frozen = _disabled;
    final actionDisabled = frozen || _refreshing;
    return Scaffold(
      appBar: AppBar(title: const Text('AI 服务')),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '可选联网分析 · 账本仍在本机\n选服务商 → 选模型 → 获取密钥 → 保存配置\n仅支持 OpenAI 兼容文本聊天，密钥由你提供。',
          ),
          const SizedBox(height: 18),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!, key: const ValueKey('ai-settings-error')),
            ),
          DropdownButtonFormField<String>(
            key: ValueKey('provider-${_provider?.id}'),
            icon: const Icon(LucideIcons.chevronDown, size: 20),
            initialValue:
                _provider?.id ?? (_endpoint.text.isEmpty ? null : 'custom'),
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '服务商',
              hintText: '请选择服务商',
            ),
            items: [
              ...aiProviders.map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Row(
                    children: [
                      AiBrandIcon(p.id),
                      const SizedBox(width: 12),
                      Expanded(child: Text(p.name)),
                    ],
                  ),
                ),
              ),
              const DropdownMenuItem(value: 'custom', child: Text('自定义')),
            ],
            onChanged: frozen ? null : _selectProvider,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _endpoint,
            enabled: !frozen,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: _editedEndpoint,
            decoration: const InputDecoration(
              labelText: '完整 HTTPS 聊天端点',
              hintText: 'https://你的服务地址/v1/chat/completions',
            ),
          ),
          if (_provider?.id == 'qwen')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '北京在线模型查询需要业务空间专属域名；普通聊天地址仍可保存使用。请先查看官方说明，再填写完整空间地址和此地址密钥。',
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _model,
            enabled: !frozen,
            autocorrect: false,
            onChanged: (_) {
              _invalidate();
              setState(() {});
            },
            decoration: const InputDecoration(
              labelText: '模型名称',
              hintText: '可手动填写精确模型 ID',
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: frozen || _models.isEmpty ? null : _chooseModel,
                icon: const Icon(LucideIcons.list, size: 20),
                label: const Text('选择模型'),
              ),
              TextButton.icon(
                onPressed: actionDisabled ? null : _refresh,
                icon: const Icon(LucideIcons.refreshCw, size: 20),
                label: Text(_provider?.id == 'zhipu' ? '在线刷新暂不支持' : '刷新模型列表'),
              ),
              if (_refreshing)
                TextButton(
                  onPressed: () => setState(() {
                    _invalidate();
                    _error = '已取消模型刷新，原列表已保留。';
                  }),
                  child: const Text('取消刷新'),
                ),
            ],
          ),
          if (_refreshing) const LinearProgressIndicator(),
          Text(
            _catalog == null
                ? '列表来源：内置目录（未在线刷新）'
                : '列表来源：${_catalog!.source}\n上次成功刷新：${_catalog!.refreshedAt.toLocal().toString().split('.').first}',
          ),
          if (_catalog != null &&
              !_catalog!.models.any((m) => m.id == _model.text.trim()))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('当前列表未包含此模型，请核对权限或选择其他模型'),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('模型目录不保证账号权限或实时可用性；不会自动换模型或重发聊天。'),
          ),
          if (_provider == null)
            TextField(
              controller: _catalogUrl,
              enabled: !frozen,
              autocorrect: false,
              onChanged: (_) {
                _invalidate();
                setState(() {});
              },
              decoration: const InputDecoration(
                labelText: '同源 HTTPS 模型列表地址（可选）',
                hintText: '不填写时不会猜测模型列表地址',
              ),
            ),
          if (_provider != null)
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => showAiOfficialLink(
                    context,
                    _provider!.keyUrl,
                    widget.linkOpener,
                  ),
                  child: const Text('获取 API 密钥'),
                ),
                TextButton(
                  onPressed: () => showAiOfficialLink(
                    context,
                    _provider!.docsUrl,
                    widget.linkOpener,
                  ),
                  child: const Text('查看模型说明'),
                ),
              ],
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _key,
            enabled: !frozen,
            obscureText: true,
            enableIMEPersonalizedLearning: false,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) {
              _invalidate();
              setState(() {});
            },
            decoration: InputDecoration(
              labelText: 'API 密钥',
              hintText: _hasKey ? '此地址已有密钥；留空保留，更换地址需重填' : '仅存储在本机系统安全存储中',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('逐步显示回复'),
            subtitle: const Text('关闭后等待完整回复；不自动切换模式重试'),
            value: _streaming,
            onChanged: frozen
                ? null
                : (v) {
                    _invalidate();
                    setState(() => _streaming = v);
                  },
          ),
          DropdownButtonFormField<String>(
            key: ValueKey(_tokenField),
            icon: const Icon(LucideIcons.chevronDown, size: 20),
            initialValue: _tokenField,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '输出限制参数 · 1536 tokens',
            ),
            items: [
              'max_tokens',
              'max_completion_tokens',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: frozen
                ? null
                : (v) {
                    _invalidate();
                    setState(() => _tokenField = v!);
                  },
          ),
          const SizedBox(height: 18),
          if (_dirty && !_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('有未保存修改，请先保存再刷新模型或测试连接。'),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: actionDisabled ? null : _save,
                child: const Text('保存配置'),
              ),
              OutlinedButton(
                onPressed: actionDisabled ? null : _test,
                child: const Text('测试已保存配置'),
              ),
              if (widget.service.busy)
                TextButton(
                  onPressed: widget.service.stop,
                  child: const Text('停止请求'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Panel(
            child: const Text(
              '只有主动操作才联网。首次查询确认接收地址；模型查询只发送认证，不发送账本或聊天。\n\n聊天可能计费，首次发送确认数据范围。API 密钥、加密模型缓存、报告和聊天均不进入账本备份。更换或删除密钥清除模型缓存，不迁移聊天。',
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: actionDisabled
                ? null
                : () => _run(() async {
                    if (!await confirm(
                          context,
                          title: '删除 API 密钥？',
                          body: '删除密钥及模型缓存，不删除账本或聊天历史。再次分析需要重新填写密钥。',
                        ) ||
                        !mounted) {
                      return;
                    }
                    _invalidate();
                    await widget.service.storage.deleteApiKey();
                    _hasKey = false;
                    _key.clear();
                    _catalog = null;
                    if (context.mounted) message(context, 'API 密钥和模型缓存已删除。');
                  }),
            child: const Text('删除 API 密钥'),
          ),
          TextButton(
            onPressed: actionDisabled
                ? null
                : () => _run(() async {
                    if (!await confirm(
                          context,
                          title: '清空全部 AI 记录？',
                          body: '删除本地报告、聊天、快照及模型缓存，不删除账本或 API 密钥，也不删除服务商副本。',
                          action: '清空记录',
                        ) ||
                        !mounted) {
                      return;
                    }
                    _invalidate();
                    await widget.service.clear();
                    _catalog = null;
                    if (context.mounted) message(context, '本地 AI 记录已清空。');
                  }),
            child: const Text('清空全部 AI 记录'),
          ),
        ],
      ),
    );
  }
}
