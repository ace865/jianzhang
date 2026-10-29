import '../l10n/system_messages.dart';
import '../l10n/localization.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/ai_catalog.dart';
import '../core/ai_catalog_client.dart';
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
  Object? _error;
  String? _savedCatalogUrl;
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
    setState(() => _error = error);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

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
      // Configuration recovery must not depend on decrypting chat history.
      final config = await widget.service.loadConfiguration();
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
      if (mounted) _error = error;
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
    final generation = _generation;
    await _endpointKey();
    try {
      await _readCatalog();
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e);
      }
    }
  }

  Future<void> _endpointKey() async {
    final address = _endpoint.text.trim();
    final generation = _generation;
    try {
      final key = await widget.service.storage.keyFor(_draft);
      if (mounted &&
          generation == _generation &&
          address == _endpoint.text.trim()) {
        setState(() => _hasKey = key != null);
      }
    } catch (error) {
      if (mounted &&
          generation == _generation &&
          address == _endpoint.text.trim()) {
        setState(() => _error = error);
      }
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
    if (!mounted) return;
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
    if (mounted) {
      message(
        context,
        tr(context).aiConfigurationSavedNoAutomaticNetworkRequest,
      );
    }
  });
  Future<void> _test() => _run(() async {
    if (_dirty) {
      throw LocalizedFailure(
        'youHaveUnsavedChangesSaveTheConfiguration',
        tr(context).youHaveUnsavedChangesSaveTheConfiguration,
      );
    }
    final config = widget.service.config;
    if (config == null) {
      throw LocalizedFailure(
        'saveTheConfigurationFirst',
        tr(context).saveTheConfigurationFirst,
      );
    }
    if (!await confirm(
          context,
          title: tr(context).testConnection,
          body: tr(context)
              .sendAShortMessageWithoutLedgerData((config.endpoint).toString()),
          action: tr(context).sendTest,
        ) ||
        !mounted) {
      return;
    }
    final result = await widget.service.testConnection(
      language: LanguageSettings.instance.tag,
    );
    if (mounted) message(context, systemMessage(context, result) ?? result);
  });
  Future<void> _refresh() async {
    if (_disabled || _refreshing) return;
    if (_dirty) {
      _showError(
        LocalizedFailure(
          'youHaveUnsavedChangesSaveBeforeRefreshing',
          tr(context).youHaveUnsavedChangesSaveBeforeRefreshing,
        ),
      );
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
      if (!mounted) return;
      if (key == null) {
        throw LocalizedFailure(
          'saveTheKeyForThisAddressFirst',
          tr(context).saveTheKeyForThisAddressFirst,
        );
      }
      final revision = widget.service.storage.catalogRevision;
      if (!await widget.service.storage.catalogConsented(uri)) {
        if (!mounted || generation != _generation) return;
        if (!await confirm(
              context,
              title: tr(context).queryModelList,
              body: tr(context)
                  .recipientPOnlyAuthenticationBoundToThis((uri).toString()),
              action: tr(context).confirmQuery,
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
      appBar: AppBar(title: Text(tr(context).aiService)),
      body: ListView(
        controller: _scroll,
        padding: EdgeInsets.all(20),
        children: [
          Text(tr(context).optionalOnlineAnalysisYourLedgerStaysLocal),
          SizedBox(height: 18),
          if (_loading) LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                errorText(context, _error!),
                key: ValueKey('ai-settings-error'),
              ),
            ),
          DropdownButtonFormField<String>(
            key: ValueKey('provider-${_provider?.id}'),
            icon: Icon(LucideIcons.chevronDown, size: 20),
            initialValue:
                _provider?.id ?? (_endpoint.text.isEmpty ? null : 'custom'),
            isExpanded: true,
            decoration: InputDecoration(
              labelText: tr(context).provider,
              hintText: tr(context).chooseAProvider,
            ),
            items: [
              ...aiProviders.map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Row(
                    children: [
                      AiBrandIcon(p.id),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(systemMessage(context, p.name) ?? p.name),
                      ),
                    ],
                  ),
                ),
              ),
              DropdownMenuItem(
                value: 'custom',
                child: Text(tr(context).custom),
              ),
            ],
            onChanged: frozen ? null : _selectProvider,
          ),
          SizedBox(height: 14),
          TextField(
            controller: _endpoint,
            enabled: !frozen,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: _editedEndpoint,
            decoration: InputDecoration(
              labelText: tr(context).fullHttpsChatEndpoint,
              hintText: tr(context).httpsYourServiceVChatCompletions,
            ),
          ),
          if (_provider?.id == 'qwen')
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                tr(context).beijingModelQueriesRequireAWorkspaceSpecific,
              ),
            ),
          SizedBox(height: 14),
          TextField(
            controller: _model,
            enabled: !frozen,
            autocorrect: false,
            onChanged: (_) {
              _invalidate();
              setState(() {});
            },
            decoration: InputDecoration(
              labelText: tr(context).modelName,
              hintText: tr(context).youCanEnterAnExactModelId,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: frozen || _models.isEmpty ? null : _chooseModel,
                icon: Icon(LucideIcons.list, size: 20),
                label: Text(tr(context).chooseModel),
              ),
              TextButton.icon(
                onPressed: actionDisabled ? null : _refresh,
                icon: Icon(LucideIcons.refreshCw, size: 20),
                label: Text(
                  _provider?.id == 'zhipu'
                      ? tr(context).onlineRefreshIsNotSupportedYet
                      : tr(context).refreshModelList,
                ),
              ),
              if (_refreshing)
                TextButton(
                  onPressed: () => setState(() {
                    _invalidate();
                    _error = const LocalizedFailure(
                      'modelRefreshCancelledThePreviousListIs',
                      '',
                    );
                  }),
                  child: Text(tr(context).cancelRefresh),
                ),
            ],
          ),
          if (_refreshing) LinearProgressIndicator(),
          Text(
            _catalog == null
                ? tr(context).sourceBuiltInCatalogNotRefreshedOnline
                : tr(context).sourcePLastSuccessfulRefreshP(
                    (_catalog!.source).toString(),
                    (_catalog!.refreshedAt
                            .toLocal()
                            .toString()
                            .split('.')
                            .first)
                        .toString(),
                  ),
          ),
          if (_catalog != null &&
              !_catalog!.models.any((m) => m.id == _model.text.trim()))
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(tr(context).thisModelIsNotInTheCurrent),
            ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(tr(context).theCatalogDoesNotGuaranteeAccessOr),
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
              decoration: InputDecoration(
                labelText: tr(context).sameOriginHttpsModelListAddressOptional,
                hintText: tr(context).leaveBlankToAvoidGuessingAModel,
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
                  child: Text(tr(context).getApiKey),
                ),
                TextButton(
                  onPressed: () => showAiOfficialLink(
                    context,
                    _provider!.docsUrl,
                    widget.linkOpener,
                  ),
                  child: Text(tr(context).viewModelDocumentation),
                ),
              ],
            ),
          SizedBox(height: 14),
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
              labelText: tr(context).apiKey,
              hintText: _hasKey
                  ? tr(context).keySavedForThisAddressLeaveBlank
                  : tr(context).storedOnlyInThisDeviceSSecure,
            ),
          ),
          SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr(context).streamReplies),
            subtitle: Text(tr(context).turnOffToWaitForCompleteReplies),
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
            icon: Icon(LucideIcons.chevronDown, size: 20),
            initialValue: _tokenField,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: tr(context).outputLimitParameterTokens,
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
          SizedBox(height: 18),
          if (_dirty && !_loading)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                tr(context).saveChangesBeforeRefreshingModelsOrTesting,
              ),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: actionDisabled ? null : _save,
                child: Text(tr(context).saveConfiguration),
              ),
              OutlinedButton(
                onPressed: actionDisabled ? null : _test,
                child: Text(tr(context).testSavedConfiguration),
              ),
              if (widget.service.busy)
                TextButton(
                  onPressed: widget.service.stop,
                  child: Text(tr(context).stopRequest),
                ),
            ],
          ),
          SizedBox(height: 24),
          Panel(
            child: Text(tr(context).networkAccessOccursOnlyAfterAnExplicit),
          ),
          SizedBox(height: 12),
          TextButton(
            onPressed: actionDisabled
                ? null
                : () => _run(() async {
                    if (!await confirm(
                          context,
                          title: tr(context).deleteApiKey,
                          body: tr(context).deletesTheKeyAndModelCacheNot,
                        ) ||
                        !mounted) {
                      return;
                    }
                    _invalidate();
                    await widget.service.storage.deleteApiKey();
                    _hasKey = false;
                    _key.clear();
                    _catalog = null;
                    if (context.mounted) {
                      message(context, tr(context).apiKeyAndModelCacheDeleted);
                    }
                  }),
            child: Text(tr(context).deleteApiKey115),
          ),
          TextButton(
            onPressed: actionDisabled
                ? null
                : () => _run(() async {
                    if (!await confirm(
                          context,
                          title: tr(context).clearAllAiRecords,
                          body: tr(context)
                              .deletesLocalReportsChatsSnapshotsAndModel,
                          action: tr(context).clearRecords,
                        ) ||
                        !mounted) {
                      return;
                    }
                    _invalidate();
                    await widget.service.clear();
                    _catalog = null;
                    if (context.mounted) {
                      message(context, tr(context).localAiRecordsCleared);
                    }
                  }),
            child: Text(tr(context).clearAllAiRecords120),
          ),
        ],
      ),
    );
  }
}
