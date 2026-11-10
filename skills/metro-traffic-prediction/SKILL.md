---
name: metro-traffic-prediction
description: 城市轨道交通客流预测（MindSpore 全栈）的模型机制、文献超链接、数据口径与实测结论速查——LSTM/Seq2Seq/Transformer/Informer 单站点 + ST-GAT 多站点，Optuna 收敛口径调参。Use when 做地铁/交通客流预测、时间序列模型选型、GAT 时空预测，或需要引用相关文献。
---

# 城市轨道交通客流预测（MindSpore）· 机制与文献

## 数据与实验口径
- 数据：北京地铁 2016年3月 AFC 客流（17线276站，in/out_15min.csv，276×1800，15分钟粒度，5周25工作日）。
- 切分 70/15/15；逐站 MinMax 归一化；早停 patience 10~15；双报告（跑满最终值 / 早停最优值）。
- 收敛口径（最终结论用）：Optuna 100 epoch、lr∈[1e-5,1e-3]、RNN hidden∈[16,32,64,128,256]、Transformer/Informer d_model∈[16,32,64,128]。
- 匿名站点：CSV 行→站点映射是近似（按线路顺序），精确还原需论文原始「站编号→站名」表。

## 各模型机制
| 模型 | 机制 | 输出方式 |
|---|---|---|
| LSTM | 门控循环捕获时序依赖 | 末隐态→Dense 一次出 K 步 |
| Seq2Seq | Encoder(LSTM)+注意力+Decoder(LSTMCell) 自回归 | 逐步生成 K 步 |
| Transformer | 位置编码+多头自注意力+FFN | 末 token→Dense 出 K 步 |
| Informer | Encoder-Decoder 自注意力，生成式解码器(start-token+因果 mask) | 自回归出 K 步 |
| ST-GAT | GATConv 空间聚合(图注意力)+GRU 时序 | 时空特征→Dense 出 K 步 |

## 文献参考（超链接）
- GAT：Veličković 2018 https://arxiv.org/abs/1710.10903 · pyGAT https://github.com/Diego999/pyGAT
- Transformer：Vaswani 2017 https://arxiv.org/abs/1706.03762
- Informer：Zhou 2021 https://arxiv.org/abs/2012.07436
- LSTM：Hochreiter & Schmidhuber 1997 https://doi.org/10.1162/neco.1997.9.8.1735
- Seq2Seq：Sutskever 2014 https://arxiv.org/abs/1409.3215 · 注意力 Bahdanau 2015 https://arxiv.org/abs/1409.0473
- Optuna：Akiba 2019 https://arxiv.org/abs/1907.10902
- 交通时空：STGCN https://arxiv.org/abs/1709.04875 · ASTGCN https://doi.org/10.1609/aaai.v33i01.3301922 · DCRNN https://arxiv.org/abs/1707.01926 · LibCity https://github.com/LibCity/Bigscity-LibCity
- MindSpore：https://www.mindspore.cn/ · 官方 GAT 示例 https://gitee.com/mindspore/models/tree/master/official/gnn/gat
- 天气：Open-Meteo https://open-meteo.com/ · archive https://archive-api.open-meteo.com/

## 关键结论（实测）
1. 收敛口径下 LSTM 双口径第一（16步 101.22 / 72步 83.57 / 单步 69.76，val RMSE）；Seq2Seq/Transformer 差距缩小到 2~3 点。
2. 降 lr 区间到 [1e-5,1e-3] 救活了短预算下发散/崩溃的模型（Seq2Seq72 324→89、Informer16 398→157、Transformer72 241→115、Informer72 585→320）。
3. Informer 生成式解码器短序列长时误差累积，始终最差。
4. Transformer 需位置编码（漏了 RMSE 599→114）+ dropout≥0.2（否则 ep22 发散）。
5. ST-GAT 多站点（1号线23站）：v1 215 → v2 158.83（hidden64/4头/150ep，↓26%）。
6. 环境因素：该时段降水全 0、无法定假日，仅温度可用（Open-Meteo 已抓，待接入模型）。

## 实现坑
- MindSpore CPU 不支持 Einsum，GAT 邻居聚合用 transpose+reshape+batch matmul。
- Seq2Seq 多层时 h.squeeze(0) 会崩，改 h[-1]。
- 子进程写工作区会被 DSH 沙箱拦（.ckpt/.json 追加写），结果先写临时目录再拷回。

## 演示平台（ECharts GL 3D）实战要点
> 静态离线 demo（`work/web`）：ECharts 5.5.1 + echarts-gl 2.0.9 + MapLibre 3.6.2，全 vendored。
- **ECharts 6 与 echarts-gl 2.0.x 不兼容**，必须降到 5.5.1。
- `zlevel` 分层解决覆盖：经纬网放高 zlevel、点/标签再高一层；同一层内 `z` 排序不够（热力光斑的 shadowBlur 会压过细线）。
- **`markLine` 挂在空 series 上会退化成「贴网格边框的矩形」**——series 要给 2 个锚点数据才有坐标系范围；更稳的做法是直接用坐标轴 `splitLine` 画经纬网。
- 更新数据只 `setOption(..., false)` + **按 series `id` merge**，不要每次 `notMerge=true` 重建，否则相机/`dataZoom` 会被重置；拖动/缩放后不要重设 `viewControl`。
- 3D 俯视 = `viewControl alpha≈89.5, beta=180, projection:'orthographic'`（正 90° 会前后轴重叠）；用户拖拽后 ECharts 不回调状态，需自己监听 mousedown/mousemove 推断「已离开俯视」并复位按钮。
- 「分界」不要用占位柱（吃掉一格导致不连续）：用零宽度 `line3D` 线框 + 地面线；曲线两段（上下文→输入、历史→预测）要手动加「连接锚点」，否则分界处断一格、信息不连贯。
- 纵轴分两种策略：2D 曲线可随峰值自适应（niceCeil 分档）；3D 热力应**全局定标**（扫全部窗口取峰值），仿真中不变，否则比例尺一直变无法观察。
- 时间轴按数据真实结构：北京数据是 **72 步/天（05:00–22:45）**；补夜间 0 要扩成 **96 步/天**，且模型输入窗口必须 > 夜间步数（夜间 24 → 输入 36），否则清晨窗口全是 0、吃不到前一天尾部。
- **未运营时段预测为 0 靠「掩码解码」而非加权损失**：加权 MSE 只把夜间均值从 82 压到 69；把运营时刻表当硬约束乘到解码输出（`out * is_operating_mask`）后夜间均值/ RMSE 严格 0，整体 RMSE 还降 8.6%。
- WSL matplotlib 缺中文字体：拷 `C:\Windows\Fonts\simhei.ttf` 到 `/usr/share/fonts/truetype/custom/`，脚本里 `fm.fontManager.addfont(path)` + `rcParams['font.sans-serif']=['SimHei',...]`；只改 rcParams 不生效。
- ST 变体「Seq2Seq 最好」结论强度有限（共用超参、单次、无 STGCN/DCRNN 基线）；下「架构最优」结论需独立调参 + 3 种子 + 显著性检验。

