# foresight-zhtw

[English](README.md) · **繁體中文**

讓 macOS 上的 Google AI Edge Foresight 支援繁體中文（台灣）、日文以及中英混合轉寫，無需修改應用本身。
另外可選：讓 Foresight 的聊天改用更大的本地模型（Qwen3.8-27B），代替自帶的 Gemma 4 E2B。

本專案 fork 自 [michaelpersonal/foresight-zh](https://github.com/michaelpersonal/foresight-zh)。
SenseVoice 輸出的是簡體中文，這個 fork 用 [OpenCC](https://github.com/BYVoid/OpenCC) 把每句中文
轉成繁體（`s2twp`：台灣字形加台灣用語，例如 軟體、伺服器），並要求摘要用繁體中文或日文輸出。

非官方專案，與 Google 無關。倉庫中不包含任何 Google 程式碼或模型權重。

## 使用方法

- 開啟 **`~/Applications/Foresight 中文.app`**（或執行 `~/tools/foresight-zh/launch.sh`）。
  如果 Foresight 已在執行，它會先退出，再帶著 shim 重新啟動。
- 用其他方式啟動 Foresight（Dock、Spotlight、登入項、點選通知）不會載入 shim：應用照常可用，
  但只能轉寫英文。下面的可選守護程式可以自動解決這個問題。
- 文字按句出現：每次停頓後顯示一段，而不是逐詞顯示。
- 日誌：`~/Library/Logs/foresight-zh/shim.log`。如需同時記錄每條轉寫結果（除錯用）：
  `FORESIGHT_ZH_TRACE=1 ~/tools/foresight-zh/launch.sh`。

- 本地 Qwen 服務執行時，聊天走 Qwen；沒執行時走 Foresight 自帶的 Gemma（見下文"聊天改用本地模型"）。

## 安裝步驟

shim 和啟動指令碼預設本倉庫位於 `~/tools/foresight-zh`。

1. 安裝 Foresight 並開啟一次。
2. 下載轉寫引擎（約 270MB）：[sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) C 庫、
   SenseVoice-Small（int8）和 Silero VAD，存放在 `~/local-llm/models/special/foresight-zh/`：

   ```bash
   ./setup-sensevoice.sh
   ```

3. 編譯 OpenCC（arm64），用於簡轉繁，需要 `cmake`。不使用 Homebrew 的 opencc：在 Rosetta 下
   它是 x86_64，無法載入 Foresight。

   ```bash
   ./setup-opencc.sh
   ```

   預設轉換為 `s2twp`。要改的話，把其他 OpenCC 設定名（`s2tw` 只轉字形、`s2hk` 等）或 `off`
   寫進 `~/tools/foresight-zh/opencc`。SenseVoice 標為日文、韓文或英文的句子不會被轉換。

   SenseVoice 預設逐句自動判斷語言，短句偶爾會判錯（國語句子偶爾變成日文）。啟動時固定語言：
   `launch.sh zh` 或 `launch.sh ja`（也可以 `en`、`ko`、`yue`）。預設值可以寫進
   `~/tools/foresight-zh/language`；兩者都沒有就是 `auto`。

4. 構建 shim：

   ```bash
   shim/build.sh
   ```

5. 可選：生成 Dock / Spotlight 啟動器：

   ```bash
   osacompile -o ~/Applications/"Foresight 中文.app" -e 'do shell script "$HOME/tools/foresight-zh/launch.sh zh"'
   osacompile -o ~/Applications/"Foresight 日本語.app" -e 'do shell script "$HOME/tools/foresight-zh/launch.sh ja"'
   ```

6. 可選：安裝自動重啟守護程式。這個 LaunchAgent 每 5 秒檢查一次，如果 Foresight 沒有載入 shim，
   就通過 `launch.sh` 重新啟動它。Dock 直接啟動、通知、登入項、更新等情況都能覆蓋。重啟發生在
   普通啟動後幾秒內，所以這幾秒內不要開始錄音。5 分鐘內最多重啟 3 次。

   ```bash
   ./install-watcher.sh              # 安裝並啟動
   ./install-watcher.sh --uninstall  # 解除安裝
   touch ~/Library/Logs/foresight-zh/watcher.paused   # 暫停（刪除該檔案即恢復）
   ```

   日誌：`~/Library/Logs/foresight-zh/watcher.log`。

## 工作原理

Foresight 的即時轉寫由 Google 閉源的 ODML 轉寫庫完成。Dart 介面層通過匯出的 C API 呼叫它
（`OdmlCreateInferenceEngine`、`OdmlCreateSpeechPipelineFromProto`、
`OdmlSpeechProcessorTranscribe`、`OdmlSpeechProcessorFinishStream` 等）。它自帶的模型
（`models/3`）只支援英文。

`shim/libforesight_zh.dylib` 通過 `DYLD_INSERT_LIBRARIES` 注入。應用的 entitlements 允許這樣做
（`allow-dyld-environment-variables`、`disable-library-validation`），因此 Google 的程式碼簽名和
鑰匙串訪問都不受影響。在轉寫方面，shim 做三件事：

1. **替換語音識別。** 攔截 `dlsym`（Dart FFI 用它查詢 C API），接管
   `OdmlSpeechProcessorTranscribe` 和 `OdmlSpeechProcessorFinishStream`。Foresight 傳入的音訊
   （48kHz 浮點，麥克風和系統聲音各一路）先重取樣到 16kHz，再用 Silero VAD 按停頓切分成句，
   每句在 CPU 上用 SenseVoice-Small 轉寫（通常 15–85 毫秒）。結果按 Foresight 自己的格式返回
   （`text`、`is_final`、以微秒計的起止時間）。Foresight 自帶的英文引擎仍會載入，但不再執行。
   見 `shim/sensevoice_engine.c`。SenseVoice 標為中文的每一句接著用 OpenCC 轉成繁體
   （和 sherpa-onnx 一樣用 `dlopen` 載入；缺少時轉寫維持簡體）。
2. **去掉 ASCII 過濾。** Dart 層會用正則 `[^\x20-\x7E\n\r]` 刪掉轉寫文本中所有非可列印 ASCII
   字元，中文因此被全部刪除。shim 在記憶體中（寫時複製頁面，磁碟上的程式不變）把這個正則常量
   改成 `[\x00-\x08\x7F]+`。

3. **為 Foresight 的詞數統計給中文加空格。** Foresight 按空格分隔的"詞"來衡量轉寫長度：
   聊天檢索用的即時轉寫片段、以及會議摘要按鈕，都要達到一定詞數才會出現。沒有空格的中文
   因此看起來幾乎是空的：沒有摘要按鈕，聊天裡也沒有會議內容。shim 在每個中日韓字元的邊界
   插入一個極細空格（U+200A，幾乎看不見），聊天轉接層在把文字交給模型前再去掉。

如果 SenseVoice 檔案缺失或載入失敗，shim 會退回 Foresight 自帶的引擎（英文）。

### 備選引擎：Gemma 4 E2B

在 SenseVoice 之前，shim 讓 Foresight 自己的轉寫流程執行一個由 Gemma 4 E2B（Foresight 自己
下載的模型）重新打包的模型：重定向模型路徑，並把轉寫選項改成批處理加轉寫提示詞。這個方案可用，
但需要一份 3.4GB 的 Gemma 副本，記憶體佔用也更大。啟用方法：

```bash
uv venv ~/local-llm/venvs/litert --python 3.12
uv pip install -p ~/local-llm/venvs/litert/bin/python litert-lm-api litert-lm
model-build/build.sh                       # 把 models/15 重新打包成 ASR 模型
echo gemma > ~/tools/foresight-zh/engine   # 切換引擎；刪除這個檔案即恢復預設
```

`model-build/build.sh` 會去掉視覺部分、drafter，以及音訊部分的"僅限 CPU"標記（Foresight 在
GPU 上執行語音模型），並換上僅用於轉寫的模板。`make_override.py` 生成 Gemma 模式下替換的
選項檔案 `pipeline_override.pb`。

## 聊天改用本地模型

Foresight 的聊天（詢問筆記和日曆）在本機執行 Gemma 4 E2B。shim 可以把它轉到本地的
OpenAI 相容服務。預設目標是 `~/local-llm` 裡的 Qwen3.8-27B Splash 服務：

```bash
~/local-llm/runtime/bin/splash-serve start qwen38-27b-splash
echo 'http://127.0.0.1:8000/v1 incoai/Qwen3.8-27B-Splash {"reasoning_effort":"none","temperature":0.7,"top_p":0.8,"top_k":20}' > ~/tools/foresight-zh/chat
```

`chat` 檔案只有一行：`<base_url> [模型] [{額外請求欄位}]`，或者 `off`。沒有這個檔案時預設
使用 `http://127.0.0.1:8096/v1 qwen3.8-27b-mtp`（llama.cpp）。修改後需要重啟 Foresight。

- shim 不會自己啟動模型服務：`~/local-llm` 同一時間只執行一個模型服務，啟動一個會停掉其他的。
  服務沒執行、或者埠上是別的模型時，聊天用 Gemma。每 5 秒重新檢查一次。
- Foresight 自己的取樣引數（temperature 0.4、top_k 40，為 Gemma 調的）不會轉發。llama.cpp
  服務端會自動使用 Qwen 的非思考模式引數；Splash 服務端沒有預設值，所以上面的 `chat` 行自己
  帶上：關閉思考，temperature 0.7、top_p 0.8、top_k 20。Qwen 推薦的第四個引數
  `presence_penalty` 會被 Splash 拒絕。
- 每次回覆最多 2048 個 token，因為 llama.cpp 在取消後仍會繼續生成。
- 用 Foresight 的實際問題測試（M5 Max）：Splash 上的 Qwen3.8-27B 約每秒 212 字元，llama.cpp
  約 91。Qwen3.8-Flash-Next（MTPLX）速度相近，但有一題忽略了檢索到的筆記，轉而呼叫日曆工具。

- 會議摘要也走同一個轉接層。Foresight 的摘要提示詞是英文的，所以轉寫以中日文為主時，轉接層會
  要求模型用繁體中文（台灣）輸出，轉寫含假名時則要求日文，並保留模板標題（`# Overview`、
  `# Details`）。這只對走本地服務的聊天生效，內建的 Gemma 路徑不變。
- 限制：會議進行中，Foresight 用你的問題去檢索轉寫片段，所以請用會議的語言提問（英文問題匹配
  不到中文片段）。加空格功能之前錄的會議，轉寫沒有空格，仍然沒有摘要按鈕。

原理：Foresight 的聊天通過 LiteRT-LM 的對話 C API 傳遞 JSON 訊息
（`litert_lm_create_conversation_v2`、`litert_lm_conversation_send_message_stream` 等）。shim
用同樣的 `dlsym` 攔截接管這些函式，把對話（系統提示詞、筆記上下文、歷史、`search_calendar`
工具）轉換成 OpenAI 聊天請求，按 Foresight 的格式流式返回回覆，並把工具呼叫轉換成 Foresight
的工具呼叫訊息。引擎的其他用途（摘要、音訊、圖片）仍由 Gemma 處理。`FORESIGHT_ZH_TRACE=1`
會記錄所有 `dlsym` 查詢和其餘的 `litert_lm_*` 呼叫，並把 JSON 引數和轉接層發出的請求儲存到
`~/Library/Logs/foresight-zh/lm/`。
`shim/test/chat_harness.c` 可以把儲存的對話重新跑一遍。

## Foresight 更新之後

shim 在動手前會先檢查，跳過的步驟會寫進日誌：

- **找不到過濾正則：** 跳過補丁，中文可能又會被刪掉。找到新的過濾字串，更新
  `shim/foresight_zh.c` 中的 `patch_ascii_filter`。
- **聊天 C API 有變化：** 檢視 `shim.log` 中的 `chat:` 行，把 `chat` 設為 `off`，再用
  `FORESIGHT_ZH_TRACE=1` 重新跟蹤。
- **語音 C API 有變化：** 接管邏輯依賴當前的引數佈局和結果結構。檢視 `shim.log`。不載入 shim
  時應用不受影響。

## 檔案說明

- `shim/foresight_zh.c`：dlsym 攔截、ODML 鉤子、過濾器補丁、引擎選擇
- `shim/sensevoice_engine.c`：基於 sherpa-onnx 的 VAD + SenseVoice 引擎（通過 `dlopen` 載入）
- `shim/chat_bridge.c`：把聊天轉到本地 OpenAI 相容服務（libcurl）
- `shim/cJSON.c`、`shim/cJSON.h`：[cJSON](https://github.com/DaveGamble/cJSON) v1.7.18（MIT）
- `shim/test/chat_harness.c`：把儲存的 Foresight 對話送進聊天轉接層測試
- `shim/sherpa-onnx-c-api.h`：sherpa-onnx C API 標頭檔案（v1.13.8，Apache-2.0，Xiaomi Corporation）
- `shim/test/sv_harness.c`：把 48kHz float32 原始錄音送進引擎做測試
- `shim/test/tw_harness.c`：檢查簡轉繁
  （`clang -o /tmp/tw shim/test/tw_harness.c shim/sensevoice_engine.c && /tmp/tw`）
- `setup-sensevoice.sh`：下載引擎；`setup-opencc.sh`：編譯 OpenCC；`shim/build.sh`：構建 shim
- `launch.sh`：啟動指令碼；`~/Applications/Foresight 中文.app` 是它的封裝
- `watcher.sh`、`install-watcher.sh`：自動重啟的 LaunchAgent（通過
  `~/Library/Logs/foresight-zh/shim.pid` 判斷 shim 是否已載入）
- `model-build/`、`make_override.py`、`pipeline_override.pb`：Gemma 備選方案
