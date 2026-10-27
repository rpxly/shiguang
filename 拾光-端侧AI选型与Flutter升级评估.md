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
| 1 | `git clone https://github.com/ggml-org/llama.cpp`（可改用国内镜像） | 仓库较大 | **必须固定到 4ffc47cb2001e7d523f9ff525335bbe34b1a2858**（见下方「硬约束」） |
| 2 | CMake 交叉编译 arm64-v8a，产出 `libllama.so` | 视机器 5–20 分钟 | 需 `-DGGML_OPENMP=OFF`（Android NDK 无 OpenMP）等常见开关 |
| 3 | `.so` 放入 `android/app/src/main/jniLibs/arm64-v8a/` | — | 同时在 `build.gradle` 的 `abiFilters` 里只保留 arm64，避免其他 ABI 装机即崩 |
| 4 | `pubspec.yaml` 加 `llama_cpp_dart: 0.2.2`（锁版本），`flutter pub get` | 1 分钟 | 还需两条 `dependency_overrides`，见下方「硬约束」 |
| 5 | 实现 `lib/services/llama_cpp_backend.dart` | — | 已实现，见文件内注释（libraryPath / formatter / promptId 三个坑） |
| 6 | 模型：`qwen3-1.7b-instruct-q4_k_m.gguf`（约 1.1GB） | 下载 | huggingface.co 实测不可达；modelscope.cn / hf-mirror.com 实测可用 |

### 两条硬约束（2026-10-27 真机实测踩出来的）

**① `.so` 的 llama.cpp 版本必须与 Dart 绑定一致。**

`llama_cpp_dart 0.2.2` 的 FFI 结构体是按 llama.cpp `4ffc47cb2001e7d523f9ff525335bbe34b1a2858`（GGML 0.9.4，约 b6xxx 期间）生成的。用更新的 b11919 编出来的 `.so`，`llama_model_default_params()` 等按值返回的结构体尺寸不一致，Dart 侧缓冲区写穿，真机表现为**一加载模型就 SIGSEGV**：

```
F libc : Fatal signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0x104
#00 pc ... libllama.so (llama_model_loader::llama_model_loader(...)+380)
#02 pc ... libllama.so (llama_model_load_from_file+200)
```

→ 结论：`git checkout` 到该 commit 再编，不要用 master/最新 release。包里 `src/llama.cpp` 是空子模块，拿不到源码，必须自己 clone。

**② Flutter 3.22.3 需要两条依赖覆盖。**

`llama_cpp_dart 0.2.2 → typed_isolate 6.0.0` 要 `meta ^1.15.0`（Flutter 钉死 1.12.0）；`llama_cpp_dart` 又要 `ffi ^2.1.4`（需 Dart ≥3.7，本项目 3.4.4）。两者都只需改 pubspec 约束，无 API 差异：

```yaml
dependency_overrides:
  meta: 1.15.0   # 纯注解包，无原生代码
  ffi: 2.1.3     # 2.1.4 相对 2.1.3 零 API 变化，只因 tall style 格式化抬了 SDK 门槛
```

**③ 三个 API 细节（README 有过时之处，已按源码核实）。**

- `Llama.libraryPath` 在 Android 上默认是 `libmtmd.so`（多模态库），纯文本链路必须显式改 `libllama.so`；
- 0.2.2 的 `LlamaLoad` **没有** `format` 参数，formatter 是 `LlamaParent` 第二个位置参数；提示词已是 ChatML 成品时不传 formatter；
- `sendPrompt()` 返回的是 **promptId** 不是正文；正文要从 `parent.stream` 收，`await parent.waitForCompletion(promptId)` 收尾。


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

初版写这一节时项目**确实没有 git 仓库**；POC 期间已 `git init` 并提交基线，前置条件已满足。真正升级前还要补两步：

```bash
git tag pre-flutter-upgrade          # 可回滚锚点
git stash list                       # 确认没有未提交改动被卷进去
```

回滚动作：`F:\flutter` 用 `git -C F:/flutter checkout 3.22.3`（SDK 目录本身是 git 克隆）、
`android/` 三处版本号反向改回、`flutter pub get` 重解析 —— 所以**升级动过的每个文件都要在同一次 commit 里**，否则回滚会留下一半新一半旧的状态。

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

---

## 七、Phase 0 真机实测记录

### 7.1 三档矩阵（截至 2026-10-27）

| 档位 | 设备 / 系统 | 总内存 | 首 token | 生成速度 | 峰值 PSS | 60 字总耗时 | 状态 |
|---|---|---|---|---|---|---|---|
| 低（3.7GB） | iPlay80Mini / Android 16 / arm64-v8a / 800×1340 | 3743MB | **26.1–26.7s** | ≈1.7 tok/s | **1.59GB** | **38.5s**（44 字） | ✅ 实测完成 |
| 中（4GB） | 待补 | — | — | — | — | — | ⬜ 待设备 |
| 高（8GB） | 待补 | — | — | — | — | — | ⬜ 待设备 |

**低档明细（两次 isolate 模式实测）**

| 指标 | 第 1 次 | 第 2 次 |
|---|---|---|
| 首 token 延迟 | 26.1s | 26.7s |
| 输出字数 | 44 字 | 71 字 |
| 总耗时 | 38.5s | 41.7s |
| 峰值 PSS | 1 597 836 KB（≈1.59GB） | 同量级 |
| 生成后回落 | 360–370MB | 同量级 |
| UI 表现 | 不卡、不崩（推理在子 isolate） | 同 |

内存构成：模型 mmap **1050MB** + CPU compute buffer **≈150MB** + 应用基线 ≈200MB。
设备仅 3.74GB，**低于 `kMinTotalRamMb = 4096` 的正式闸门**，本次是用诊断页的
「低配实测（绕过内存闸门）」开关强行放行的 —— 也就是说：**能跑通，但出厂默认不会在这类机型上跑**，
这条闸门保留是正确的（3.7GB 机型上 1.59GB 常驻已接近 LMK 红线）。

**结论（对 Phase 1 门槛）**：60 字 < 15s 的中端机目标，按 1.7 tok/s 折算，
需要 ≥8 tok/s 才有余量——低配档**不达标**，符合预期（低配走规则版）。
中/高档数据补齐后才能判定 Phase 1 是否可投。

### 7.2 质量观察（1.7B 的已知短板，需靠兜底而非靠调参解决）

同一份事实，两次生成内容差异明显，且都会**在事实之外加形容词**：

- 事实：36 张 / 4 天 / 有夜间
- 输出：`10 月共拍摄 36 张照片，分布在 4 天内。夜间的拍摄记录了城市的光影变化，白天的景色则捕捉了自然与人文的交融。这月的拍摄充满平静与真实。`

数字与天数**忠实**，但「城市的光影变化」「自然与人文的交融」是模型自行脑补的画面描述。
上一轮「天气晴朗」则来自 `magazine_meta` 的 weather 字段（属事实，非编造）。

→ 处置：**不追求消除脑补**，而是守住两条线：①事实行 <4 时不交给模型（已有闸门）；
②叙事只作为封面文案，导出/分享前的数字口径一律走规则版事实。这两条已写入 #11/#12。

### 7.3 复现步骤（换机器补齐矩阵时照做）

```bash
# 1. 模型放应用内部目录（不能放 /storage/emulated/0，FUSE 会卡死）
adb push F:/path/qwen3-1.7b-instruct-q4_k_m.gguf /sdcard/
adb shell run-as com.example.shiguang cp /sdcard/qwen3-1.7b-instruct-q4_k_m.gguf files/

# 2. 装机
flutter build apk --debug --target-platform android-arm64 && flutter install

# 3. 打开「端侧 AI 诊断」→ 开「低配实测（绕过内存闸门）」→ 生成本月摘要
#    logcat 过滤 tag "flutter" 看 [AI] 首 token / 生成结束打点

# 4. 采内存
adb shell dumpsys meminfo com.example.shiguang | grep -i "TOTAL PSS"
```
