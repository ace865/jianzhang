import 'ai_models.dart';

class AiCatalogModel {
  const AiCatalogModel(
    this.id, {
    this.name,
    this.brand,
    this.textChat,
    this.tokenField,
  });
  final String id;
  final String? name, brand, tokenField;

  /// Null means the API supplied no conclusive capability information.
  final bool? textChat;
  String get label => name ?? id;
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'brand': brand,
    'textChat': textChat,
    'tokenField': tokenField,
  };
  factory AiCatalogModel.fromMap(Map map) => AiCatalogModel(
    map['id'] as String,
    name: map['name'] as String?,
    brand: map['brand'] as String?,
    textChat: map['textChat'] as bool?,
    tokenField: map['tokenField'] as String?,
  );
}

class AiProvider {
  const AiProvider(
    this.id,
    this.name,
    this.endpoint,
    this.models,
    this.keyUrl,
    this.docsUrl, {
    this.modelsUrl,
    this.tokenField = 'max_tokens',
  });
  final String id, name, endpoint, keyUrl, docsUrl, tokenField;
  final String? modelsUrl;
  final List<AiCatalogModel> models;
}

const aiProviders = <AiProvider>[
  AiProvider(
    'deepseek',
    'DeepSeek',
    'https://api.deepseek.com/chat/completions',
    [
      AiCatalogModel(
        'deepseek-flash',
        name: 'DeepSeek Flash',
        brand: 'deepseek',
        textChat: true,
      ),
      AiCatalogModel(
        'deepseek-v4-pro',
        name: 'DeepSeek V4 Pro',
        brand: 'deepseek',
        textChat: true,
      ),
    ],
    'https://platform.deepseek.com/api_keys',
    'https://api-docs.deepseek.com/quick_start/pricing-details-cny/',
    modelsUrl: 'https://api.deepseek.com/models',
  ),
  AiProvider(
    'qwen',
    '通义千问 · 百炼',
    'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
    [
      AiCatalogModel(
        'qwen3.8-flash',
        name: '千问 Flash',
        brand: 'qwen',
        textChat: true,
      ),
      AiCatalogModel(
        'qwen3.7-plus',
        name: '千问 Plus',
        brand: 'qwen',
        textChat: true,
      ),
    ],
    'https://help.aliyun.com/zh/model-studio/get-api-key',
    'https://help.aliyun.com/zh/model-studio/models',
  ),
  AiProvider(
    'kimi',
    'Kimi',
    'https://api.moonshot.cn/v1/chat/completions',
    [
      AiCatalogModel(
        'kimi-k2.6',
        name: 'Kimi K2.6',
        brand: 'kimi',
        textChat: true,
      ),
      AiCatalogModel('kimi-k3', name: 'Kimi K3', brand: 'kimi', textChat: true),
    ],
    'https://platform.kimi.com/console/api-keys',
    'https://platform.kimi.com/docs/api/chat',
    modelsUrl: 'https://api.moonshot.cn/v1/models',
    tokenField: 'max_completion_tokens',
  ),
  AiProvider(
    'zhipu',
    '智谱 · GLM',
    'https://open.bigmodel.cn/api/paas/v4/chat/completions',
    [
      AiCatalogModel(
        'glm-4.7-flash',
        name: 'GLM 4.7 Flash',
        brand: 'zhipu',
        textChat: true,
      ),
      AiCatalogModel(
        'glm-4-flash-250414',
        name: 'GLM 4 Flash',
        brand: 'zhipu',
        textChat: true,
      ),
    ],
    'https://open.bigmodel.cn/usercenter/proj-mgmt/apikeys',
    'https://docs.bigmodel.cn/cn/guide/start/model-overview',
  ),
  AiProvider(
    'siliconcloud',
    '硅基流动',
    'https://api.siliconflow.cn/v1/chat/completions',
    [
      AiCatalogModel(
        'deepseek-ai/DeepSeek-V4-Flash',
        name: 'DeepSeek V4 Flash · 硅基流动',
        brand: 'deepseek',
        textChat: true,
      ),
      AiCatalogModel(
        'moonshotai/Kimi-K2.7-Code',
        name: 'Kimi K2.7 Code · 硅基流动',
        brand: 'kimi',
        textChat: true,
      ),
    ],
    'https://cloud.siliconflow.cn/account/ak',
    'https://docs.siliconflow.cn/docs/api/chat-completions-post',
    modelsUrl: 'https://api.siliconflow.cn/v1/models',
  ),
  AiProvider(
    'openai',
    'OpenAI',
    'https://api.openai.com/v1/chat/completions',
    [
      AiCatalogModel(
        'gpt-4.1-mini',
        name: 'GPT-4.1 Mini',
        brand: 'openai',
        textChat: true,
      ),
      AiCatalogModel(
        'gpt-4.1',
        name: 'GPT-4.1',
        brand: 'openai',
        textChat: true,
      ),
    ],
    'https://platform.openai.com/api-keys',
    'https://developers.openai.com/api/docs/models',
    modelsUrl: 'https://api.openai.com/v1/models',
    tokenField: 'max_completion_tokens',
  ),
  AiProvider(
    'gemini',
    'Gemini',
    'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    [
      AiCatalogModel(
        'gemini-3.8-flash',
        name: 'Gemini Flash',
        brand: 'gemini',
        textChat: true,
      ),
    ],
    'https://aistudio.google.com/apikey',
    'https://ai.google.dev/gemini-api/docs/openai',
    modelsUrl: 'https://generativelanguage.googleapis.com/v1beta/openai/models',
  ),
];

bool isQwenWorkspace(Uri uri) =>
    uri.scheme == 'https' &&
    uri.port == 443 &&
    RegExp(
      r'^[a-zA-Z0-9-]+\.(cn-beijing|ap-northeast-1|eu-central-1|us-east-1)\.maas\.aliyuncs\.com$',
    ).hasMatch(uri.host);

AiProvider? providerForEndpoint(String endpoint) {
  for (final provider in aiProviders) {
    if (provider.endpoint == endpoint) return provider;
  }
  final uri = Uri.tryParse(endpoint);
  if (uri != null &&
      isQwenWorkspace(uri) &&
      uri.path == '/compatible-mode/v1/chat/completions' &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      uri.userInfo.isEmpty) {
    return aiProviders[1];
  }
  return null;
}

Uri validateCatalogUri(String endpoint, String address) {
  final chat = Uri.tryParse(endpoint), uri = Uri.tryParse(address);
  if (uri == null ||
      chat == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.path.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      RegExp(r'\s').hasMatch(address) ||
      uri.toString().length > 2048) {
    throw const FormatException('请填写不含用户名、片段或空格的完整 HTTPS 模型列表地址。');
  }
  if (chat.scheme != uri.scheme ||
      chat.host != uri.host ||
      chat.port != uri.port) {
    throw const FormatException('模型列表地址必须与聊天端点同源，不会跨域发送密钥。');
  }
  return uri;
}

Uri catalogUri(AiConfig config, {String? customUrl}) {
  config.validate();
  final provider = providerForEndpoint(config.endpoint);
  if (provider?.id == 'zhipu') {
    throw const FormatException('智谱暂不支持在线获取模型列表，请使用内置列表或查看官方模型说明。');
  }
  if (provider?.id == 'qwen') {
    final chat = Uri.parse(config.endpoint);
    if (!isQwenWorkspace(chat)) {
      throw const FormatException(
        '北京地域查询需要业务空间专属域名。请根据官方说明，将完整聊天端点填写为 https://业务空间ID.cn-beijing.maas.aliyuncs.com/compatible-mode/v1/chat/completions，重新填写此地址的密钥并保存。不会猜测空间或跨地域发送密钥。',
      );
    }
    return validateCatalogUri(
      config.endpoint,
      chat.replace(path: '/api/v1/models').toString(),
    );
  }
  final address = provider?.modelsUrl ?? customUrl;
  if (address == null || address.trim().isEmpty) {
    throw const FormatException('自定义服务需要先填写同源 HTTPS 模型列表地址并保存，不会猜测地址。');
  }
  return validateCatalogUri(config.endpoint, address.trim());
}

class AiCatalogResult {
  const AiCatalogResult({
    required this.endpoint,
    required this.source,
    required this.refreshedAt,
    required this.models,
  });
  final String endpoint, source;
  final DateTime refreshedAt;
  final List<AiCatalogModel> models;
  Map<String, dynamic> toMap() => {
    'endpoint': endpoint,
    'source': source,
    'refreshedAt': refreshedAt.toIso8601String(),
    'models': models.map((m) => m.toMap()).toList(),
  };
  factory AiCatalogResult.fromMap(Map map) => AiCatalogResult(
    endpoint: map['endpoint'] as String,
    source: map['source'] as String,
    refreshedAt: DateTime.parse(map['refreshedAt'] as String),
    models: (map['models'] as List)
        .map((m) => AiCatalogModel.fromMap(m as Map))
        .toList(),
  );
}
