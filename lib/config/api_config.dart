// 后端 API 配置
//
// 集中管理后端服务器地址，方便切换开发/生产环境。

/// 后端服务器基础 URL
///
/// 通过 `--dart-define=API_BASE_URL=https://xxx` 注入。
/// 未指定时默认使用本地开发地址。
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);
