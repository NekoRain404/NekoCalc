# NekoCalc Architecture

NekoCalc 使用 Feature-first + Clean Architecture 简化版。

## 分层

- `features/`: UI 层。页面、组件、动画、输入交互只放这里。
- `application/`: Application 层。Controller、页面状态协调、UseCase 编排。
- `domain/`: Domain 层。实体、数学模型、工程计算逻辑、工具目录。
- `data/`: Data 层。SQLite、本地文件、Repository、导入导出、设置持久化。
- `core/`: Core 层。表达式解析器、单位换算、格式化、通用扩展。
- `shared/`: 跨 feature 的展示组件，只放无业务含义的 UI 组件。

## 依赖方向

UI -> Application -> Domain

Data 由 Application 或 UI 注入，不让 Domain 依赖 SQLite、Flutter 页面或平台实现。业务层优先依赖 Repository，`AppDatabase` 只作为 SQL 与迁移边界。

## 新增工具的路径

1. 在 `domain/usecases/tool_catalog.dart` 增加 `ToolDefinition`。
2. 在 `domain/usecases/calculate_tool.dart` 增加对应 `ToolKind` 的计算分支。
3. 文本型工具在 `domain/usecases/tool_capabilities.dart` 登记，并走 `TextToolDetailScreen`。
4. 如需持久化，走 `data/local/app_database.dart`，不要在页面直接写 SQL。
5. 页面和 Controller 不直接写 SQL；历史、笔记、设置、工具使用和备份恢复分别通过 `data/repositories/` 下的 Repository 访问。

## 约束

- 页面不直接写工程公式。
- 数据库表结构集中在 `AppDatabase`。
- SQLite 查询、迁移、索引和事务集中在 `AppDatabase`；业务命名和组合操作放在 Repository。
- 通用 UI 放 `shared/presentation`，带业务语义的组件留在各自 feature。
- 单个文件过大时优先按职责拆，不按“工具类大全”堆放。
- Domain 不依赖 Flutter UI 类型；图标、颜色等视觉映射放在 feature 的 presentation 层。
- 当前 Flutter Android 入口是 `android/`，根级旧 `app/` 原生模块暂不作为应用入口。
- 工具页统一通过 `tool_navigation.dart` 打开详情页，不在各个列表页面分散判断工具类型。
