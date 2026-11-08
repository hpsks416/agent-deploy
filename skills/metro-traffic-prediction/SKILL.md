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
