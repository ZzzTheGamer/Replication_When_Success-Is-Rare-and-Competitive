# Formula 1：成功与失败经验的复现及扩展

本项目使用 R 独立重建 Lapré and Cravey（2022）的累计经验变量，复现 Table 1 及 Table 2 的模型（1）、（2）、（4），并将模型（4）扩展至 1950–2025 和 2018–2025 两个样本。已发表结果与 R 估计并列展示。变量定义、构造依据及模型公式见 `CODEBOOK.md`。

## 运行环境与数据

分析已在 R 4.4.3 下验证。依赖包由 `setup.R` 安装，软件包版本记录在 `results/sessionInfo.txt`。全部数据处理、估计、表格和图形均由 R 完成。

作者原始数据需从原始复现材料取得，并将以下三个文件放入 `data/raw/authors/`：

- `F1DataMainVariables.xlsx`：逐场事件标记、比赛信息和车手资料。
- `F1StataData.dta`：用于核验独立重建的变量。
- `F1VariableDictionary.xlsx`：作者变量字典。

原始数据位于其他目录时，可通过环境变量 `F1_AUTHOR_DIR` 指定目录。公开来源的 API JSON 和比赛报告 HTML 缓存已包含在项目中，支持离线复现。

## 完整复现

在 RStudio 打开 `f1_replication.Rproj`，执行：

```r
source("setup.R")
Sys.setenv(F1_OFFLINE = "1")
source("run_submission.R")
```

命令行运行：

```sh
Rscript setup.R
F1_OFFLINE=1 Rscript run_submission.R
```

`setup.R` 首次安装依赖时需要联网；完整分析使用缓存时不需要联网。`run_submission.R` 按顺序执行数据重建、历史核验、扩展样本构造、模型估计及结果输出。人工编码表修改后，使用同一入口重新运行，以更新受影响的后续累计经验和估计。

## 文件结构

```text
f1_replication/
├── README.md
├── CODEBOOK.md
├── setup.R
├── run_submission.R
├── f1_replication.Rproj
├── R/
│   ├── 00_config.R
│   ├── 01_rebuild_original.R
│   ├── 02_download_jolpica.R
│   ├── 03_download_wikipedia.R
│   ├── 04_models.R
│   ├── 05_link_and_validate_status.R
│   ├── 06_build_extension.R
│   ├── 07_extension_models.R
│   ├── 08_tables_and_figures.R
│   ├── 10_paper_style_tables.R
│   ├── functions.R
│   ├── model_helpers.R
│   └── paper_style_helpers.R
├── data/
│   ├── manual/
│   ├── raw/
│   │   ├── authors/
│   │   ├── jolpica/
│   │   └── wikipedia/
│   └── processed/
└── results/
    ├── paper_style/
    ├── tables/
    ├── figures/
    ├── checks/
    ├── models/
    └── sessionInfo.txt
```

`data/raw/authors/` 由原始复现材料提供；`data/processed/` 和 `results/models/` 在运行时生成。

| 脚本 | 功能 |
|---|---|
| `00_config.R` | 检查依赖、配置路径及缓存选项。 |
| `01_rebuild_original.R` | 从 Excel 事件标记重建累计经验，与 Stata 数据逐项核对。 |
| `02_download_jolpica.R` | 读取或下载赛程及逐场结果。 |
| `03_download_wikipedia.R` | 读取或下载比赛报告，提取补充比赛信息。 |
| `04_models.R` | 估计历史样本的模型（1）、（2）、（4）。 |
| `05_link_and_validate_status.R` | 连接历史身份与比赛结果，评估 status 分类与作者编码的一致率。 |
| `06_build_extension.R` | 应用人工编码，构造扩展样本并延续历史累计经验。 |
| `07_extension_models.R` | 估计扩展模型（4）、时期差异检验及敏感性分析。 |
| `08_tables_and_figures.R` | 输出数值表、核验结果、图形、软件版本及输入哈希。 |
| `10_paper_style_tables.R` | 重新估计五个模型并生成与原文布局对应的比较表。 |
| `functions.R` | 数据构造、读取、核验及通用输出函数。 |
| `model_helpers.R` | 模型估计、聚类标准误及随机截距核验。 |
| `paper_style_helpers.R` | 比较表的 PDF、HTML、PNG 和 CSV 排版输出。 |

## 人工输入

| 文件（`data/manual/`） | 内容 |
|---|---|
| `status_mapping.csv` | API status 到完赛、车辆失败、驾驶失败及非出发等类别的对应规则。 |
| `dnf_overrides.csv` | 原因未明确的退赛记录、补充分类和来源。 |
| `dsq_sensitivity.csv` | 取消资格事件的原因审阅与敏感性分类。 |
| `race_coding.csv` | 天气、赛道类别、证据及来源。 |
| `original_team_dummies.csv` | 原文 20 个车队指示变量的名称与适用年份。 |
| `modern_team_mapping.csv` | 新时期车队身份及其与原文指示变量的对应。 |
| `published_table1.csv` | 原文 Table 1 的统计量与显示精度。 |
| `published_table2.csv` | 原文模型（1）、（2）、（4）的系数及标准误基准。 |

## 结果文件

- `results/paper_style/paper_style_comparison_tables.pdf`：Table 1、Table 2 及模型（4）扩展比较表；同目录 `index.html` 为 HTML 版。
- `results/paper_style/refitted_coefficients.csv`：五个模型的完整系数、聚类标准误、检验及置信区间。
- `results/paper_style/refitted_model_metadata.csv`：模型公式、样本数、比赛数及拟合统计量。
- `results/figures/figure1_failure_rates.png`：1950–2025 年车辆失败与驾驶失败比例。
- `results/figures/figure2_car_failure_coefficients.png`：三个时期样本的车辆失败经验系数及 95% 置信区间。
- `results/tables/`：失败率、系数差异检验、敏感性估计及发表值比较。
- `results/checks/`：累计变量、控制变量、分类一致率、样本覆盖和估计核验。

`results/checks/input_sha256_manifest.csv` 记录人工输入、API 缓存及作者关键文件的 SHA-256，以识别分析所用的数据快照。
