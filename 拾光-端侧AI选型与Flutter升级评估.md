# 拾光 · 端侧 AI 选型与 Flutter 升级评估

> **性质**：2026-10-27 基于本项目实机环境实测（非网络资料转述）。标注「实测」的条目均在本机 `F:\daima\ai-album` 与 `F:\flutter` 上验证过；标注「推断」的条目未经实跑，需在真机/真升级中确认。
> **结论先行**：端侧 AI 能实现，但**当前工具链下只有一条路能走通**；「升级 Flutter 换更好的插件」不是免费选项，它是一笔需要用 15 个插件去偿还的迁移债。

---

## 一、当前基线（实测）

| 项目 | 实测值 | 说明 |
|---|---|---|
| Flutter | **3.22.3** (stable, 2024-07-16) | `F:\flutter\bin\cache\flutter.version.json` |
| Dart | **3.4.4** | 同上 |
| AGP | **8.4.0** | `android/settings.gradle` |
| Gradle | **8.6** | `gradle/wrapper/gradle-wrapper.properties` |
| Kotlin | **1.9.20** | `android/settings.gradle` |
| compileSdk / minSdk | 36 / 26 | `android/app/build.gradle` |
| ndkVersion | **26.1.10909125（已声明，未安装）** | `Android/sdk/ndk`、`sdk/cmake`、`cmdline-tools` 三者均不存在 |
| 直接依赖 | 15 个（含 2 个 webview、2 个 mlkit 系） | `flutter pub outdated` 实测 |
| release 构建 | `minifyEnabled true` + `shrinkResources true` | 对 ProGuard 规则敏感 |

**关键含义**：`minSdk 26` 只说明「能装」，NDK 未安装说明**当前任何涉及 native 编译的方案都尚未具备执行条件**——这是 Phase 0 的第 0 步，不是第 3 步。

---

## 二、三条路线的真实门槛

| 路线 | 版本门槛（实测） | 是否需自编译 | 与当前项目的冲突 |
|---|---|---|---|
| **A. `llama_cpp_dart` 0.2.2** | env `sdk >=3.2.0 <4.0.0` ✅ 与 Dart 3.4.4 兼容 | **需要**：README 明确要求事先编译出 llama.cpp 共享库，插件不含预编译产物 | 无版本冲突；代价是自建 NDK 交叉编译链 + 按 ABI 打包 `.so` + 自己维护 `DynamicLibrary.open` 路径 |
| **B. `llama_flutter_android` 0.2.6** | 要求 Flutter **≥3.24**；插件自身 `AGP 8.9.1 + Kotlin 2.1.0`；CMake 3.22.1；NDK r27+ | 不需要手工编译：插件内置 llama.cpp 全量源码，gradle 走 `externalNativeBuild` 自动编 | 三条硬冲突：①Flutter 3.22.3 < 3.24；②AGP 8.9 需 Gradle ≥8.11（现 8.6）；③Kotlin 1.9.20 → 2.1.0 |
| **C. `llamadart` 0.16.4** | 要求 Dart **^3.10.7**（2026-10-26 发版，生态最活跃） | 走 Dart native assets（`hooks` + `code_assets`），构建期生成 | 需 Flutter 升到 3.38 量级，比 B 更远，直接排除 |

**B 的额外事实（实测其 `android/build.gradle.kts`）**：
- `abiFilters = ["arm64-v8a"]` —— **只编 arm64**，32 位与纯 v7a 设备直接不支持；
- 带 `-Wl,-z,max-page-size=16384`（Android 15 的 16KB 页要求）与 `GGML_DOTPROD`/`NEON` 优化；
- 提供 `detectGpu()` 返回 Vulkan 支持与建议卸载层数，工程完成度高于 A；
- `minSdk 26`（注释说明为 SharedMemory 支持）。

**16KB 页对齐是一项未来风险（推断，需验证）**：当前 `targetSdk = flutter.targetSdkVersion`（Flutter 3.22 → 34），一旦升到 35+，Google Play 要求所有 `.so` 按 16KB 对齐。若走 A 路线自编译，必须自己加 `-Wl,-z,max-page-size=16384`，否则将来上架被拒。校验命令：`llvm-readelf -l libllama.so | grep LOAD`，`Align` 应为 `0x4000`。

---

## 三、A 路线的 POC 执行清单（不升级 Flutter 的唯一路径）

| 步骤 | 内容 | 耗时性质 | 说明 |
|---|---|---|---|
| 0 | 安装 Android cmdline-tools → `sdkmanager "ndk;26.1.10909125" "cmake;3.22.1"` | 下载约 1.5–2GB | 当前 SDK 里连 `cmdline-tools` 都没有，需先装 |
| 1 | `git clone https://github.com/ggml-org/llama.cpp`（可改用国内镜像） | 仓库较大 | 建议固定 tag，避免上游 API 变动 |
| 2 | CMake 交叉编译 arm64-v8a，产出 `libllama.so` | 视机器 5–20 分钟 | 需 `-DGGML_OPENMP=OFF`（Android NDK 无 OpenMP）等常见开关 |
| 3 | `.so` 放入 `android/app/src/main/jniLibs/arm64-v8a/` | — | 同时在 `build.gradle` 的 `abiFilters` 里只保留 arm64，避免其他 ABI 装机即崩 |
| 4 | `pubspec.yaml` 加 `llama_cpp_dart: ^0.2.2`，`flutter pub get` | 1 分钟 | 已核实与 Dart 3.4.4 兼容 |
| 5 | 实现 `lib/services/llama_cpp_backend.dart`（约 30 行） | — | 代码骨架已就绪，见下节 |
| 6 | 模型：`qwen3-1.7b-instruct-q4_k_m.gguf`（约 1.1GB） | 下载 | huggingface.co 实测不可达；modelscope.cn / hf-mirror.com 实测可用 |

**已就绪的部分（本次已落地）**：`lib/services/on_device_ai_service.dart` 里已有 `LlamaBackend` 抽象、提示词构造、设备闸门（读 `/proc/meminfo` 判内存、判 ABI）、流式事件协议、以及**永不空手而归的兜底链路**。第 5 步只需实现 `LlamaBackend` 三个方法并注入，`kOnDeviceLlmWired` 改 `true` 即接通。

---

## 四、若选 B 路线：升级 Flutter 的实际工作量

**必须先承认**：我没有在这台机器上执行升级，以下是基于版本约束与依赖清单的**风险清单**，不是已验证的结论。

### 4.1 需要改的文件与顺序

1. `android/gradle/wrapper/gradle-wrapper.properties`：8.6 → 8.11+
2. `android/settings.gradle`：AGP 8.4.0 → 8.9.x；Kotlin 1.9.20 → 2.1.0
3. `F:\flutter`：`flutter upgrade` 到 3.24+（Dart 随之为 3.5+）
4. `pubspec.yaml`：`sdk: ">=3.3.0 <4.0.0"` 需上调；`flutter_lints 3.0.2` → 4.0.0+ 才会与新版 lint 集对齐

### 4.2 逐依赖影响面（`flutter pub outdated` 实测数据）

| 包 | 当前 | 可解析上限 | 最新 | 升级风险评估 |
|---|---|---|---|---|
| `google_mlkit_image_labeling` | 0.14.1（**精确锁版本**） | 0.14.1 | 0.16.1 | **高**：pubspec 里写的是精确版本号（无 `^`），跨 2 个小版本通常伴随 ML Kit 原生 SDK 升级，需重测场景识别准确率与 APK 体积 |
| `photo_manager` | 3.10.0 | 3.12.0 | 3.12.0 | 中：全项目相册读写的根基，升级后必须重跑扫描/缩略图/权限三条链路 |
| `health` | 12.2.1 | 13.1.3 | 13.3.2 | 中高：12→13 是**大版本**，Health Connect 权限模型常有破坏性变更；`StepsService` 需重测 |
| `share_plus` | 10.1.4 | 12.0.2 | 13.3.1 | 中：10→12 跨大版本，`Share.shareXFiles` 的 API 面在 11+ 有调整；导出分享是核心链路 |
| `webview_flutter` / `_android` | 4.8.0 / 3.16.8 | 4.8.0 / 3.16.8 | 4.14.1 | 中：项目用 webview 加载外部内容，4.8→4.14 需重测加载与 JS 交互 |
| `image_picker` | 1.1.2 | 1.1.2 | 1.2.4 | 低 |
| `path_provider` | 2.1.5 | 2.1.5 | 2.1.6 | 低 |
| `build_runner` | 2.4.11 | 2.4.11 | 2.17.1 | 低但需注意：`build_resolvers` / `build_runner_core` 已被官方标记 **discontinued**，升级会牵动 Hive 代码生成链路（`*.g.dart`） |
| `flutter_lints` | 3.0.2 | 4.0.0 | 6.0.0 | 低代码风险、高噪音：lint 规则变多会让 `flutter analyze` 从 50 条 info 涨到数百条，需一次性清理否则 CI 无法卡门 |

### 4.3 时间与风险判断（推断）

- 单纯「能编译通过」：约 1 天；
- 「15 个插件逐项回归 + 真机验证」：**3–5 人日**，其中 `health`、`photo_manager`、`share_plus` 是三个最可能出问题的点；
- 真正的风险不是升级失败，而是**升级后被夹在中间**：新旧 API 都改了一半，release 包体积/启动时间无人复测。

### 4.4 回滚方案（必须提前准备）

本项目**没有 git 仓库**（实测 `git status` 报 `not a git repository`）。在执行任何升级前，第一件事是：

```bash
git init && git add -A && git commit -m "chore: 升级前基线快照"
```

没有这一步，任何升级都不可回滚——这比选 A 还是选 B 更紧急。

---

## 五、决策建议

| 阶段 | 动作 | 门槛 |
|---|---|---|
| **现在** | 规则版月度摘要（已落地）先上线，验证「叙事是否真是流失原因」 | 无需任何新依赖 |
| **Phase 0** | A 路线 POC：装 NDK → 编 `libllama.so` → 接 `LlamaBackend` → 三台真机（2/4/8GB RAM）测 tok/s 与峰值内存 | 只动新增文件，不动现有链路 |
| **Phase 0.5** | 用「端侧 AI 诊断」页复制提示词到桌面版 llama.cpp，先判 1.7B 中文质量够不够 | 零成本，可在 Phase 0 之前做 |
| **Phase 1** | 数据达标（中端机 60 字 < 15s、无 OOM）后，再决定是否投入模型下载与管理 | 需要留存/生成率数据支撑 |
| **Phase 2（可选）** | 若 Phase 1 证明端侧价值足够，再评估 B 路线（升级 Flutter 换来「零手工编译 + Vulkan 加速」） | 先补 git 基线，再排 3–5 人日 |

**不推荐**：为了「插件省事」先升级 Flutter。B 路线省下的是编译脚本，付出的是 15 个插件的回归风险 + 一次性 3–5 人日，而它带来的唯一确定收益（Vulkan 加速）在 1.7B + 60 字的场景下几乎感知不到。

---

## 六、验收标准（Phase 0 结束时必须拿出这些数）

1. 三台真机的 **tok/s**（prompt 处理 / 生成分开记）与**峰值 RSS**；
2. **首次生成总耗时**（含模型加载）分位值；
3. 100 次生成的**空文本 / 截断 / 重复循环**发生率；
4. 与规则版的人评对比（哪一版更愿意「导出分享」，至少 10 人）；
5. 模型目录占用与卸载后残留。
