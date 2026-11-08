---
name: mindspore-gpu-wsl
description: 在 Windows + NVIDIA 笔记本（含 RTX 30/40 系、sm_89）上把 MindSpore 跑上 GPU：不走自编译，用官方预编译包 + WSL2 + CUDA 11.8（靠 compute_86 PTX 被驱动 JIT）。含一键脚本、GRAPH/PYNATIVE 陷阱、DSH 沙箱下 wsl 提权等实战坑。Use when 要在 Windows 上配 MindSpore GPU、遇到 "no kernel image available"、sm_89/Ada 不支持、ResetResource dynamic shape、WSL2 CUDA 环境搭建、或评估「要不要自编译 MindSpore GPU」。
---

# MindSpore GPU on Windows（WSL2 + 预编译包，不自编译）

## 核心结论（先记这条，能省 2–4 小时）

**官方预编译 GPU wheel 能在 RTX 40 系（sm_89）上跑，不需要自编译。**

- 官方只声明支持 CUDA 10.1/11.1/11.6，但 wheel 里编了 **compute_86 PTX**（见 `cmake/gpu_env_setup.cmake` 的 `common` 架构列表）；
- 驱动（≥ 520，如 551.95）会把 compute_86 PTX **JIT 编译**成 sm_89 的 SASS，于是能用；
- 代价：首次 kernel 启动有 1–1.5s JIT 冷启动，之后正常；
- 前提：**CUDA toolkit 用 11.8**（nvcc 11.6 编不了 sm_89，但运行时用 11.8 的 11.x 运行库即可跑 11.6 构建的 wheel）。

**判定路径**：先花 1 小时搭环境试预编译包 → 失败再考虑源码编译（`build.sh -G` 只接受 `common|auto|ptx`，手动 sm_89 会被拒，只能靠 `auto` 探测）。

## 何时用

- Windows 上要 MindSpore GPU（官方 Windows 只有 CPU）；想省掉双系统/虚拟机。
- 出现 `CUDA error: no kernel image is available for execution on the device`（旧包缺 arch / 用错 CUDA）。
- 评估「是否必须自编译 MindSpore GPU」时。
- 见到 `ResetResource] kernel must override ... when dynamic shape`、`Error Number: 719 unspecified launch failure`。

## 4 步流程（完整脚本见 References）

```powershell
# ① 管理员装 WSL2 + Ubuntu-20.04（需一次重启）
powershell -ExecutionPolicy Bypass -File <工作区>\env\01-install-wsl-elevated.ps1
# 重启后写 C:\Users\<user>\.wslconfig：memory=20GB / processors=24 / swap=8GB，然后 wsl --shutdown

# ②③ WSL 内：CUDA 11.8 + cuDNN 8.9.7 + 官方预编译 wheel
wsl -d Ubuntu-20.04 -u root -- bash <工作区>/env/10-wsl-stage1.sh
wsl -d Ubuntu-20.04 -u root -- bash <工作区>/env/20-try-prebuilt.sh
wsl -d Ubuntu-20.04 -u root -- bash <工作区>/env/21-stage2b.sh

# ④ 跑项目脚本（自动改 device_target + 路径）
wsl -d Ubuntu-20.04 -u root -- bash -c "export RUN_MODE=GRAPH; python3 <工作区>/env/40-run-gpu.py <项目脚本>.py [参数]"
```

关键版本组合（实测可用）：
| 组件 | 版本 |
|---|---|
| WSL | WSL2（Ubuntu 20.04，kernel 6.18.x） |
| CUDA | 11.8.89（`developer.download.nvidia.cn/compute/cuda/repos/wsl-ubuntu/x86_64/`，`cuda-toolkit-11-8`，**只装 toolkit 不装驱动**） |
| cuDNN | 8.9.7 cuda11（`.../cudnn/redist/cudnn/linux-x86_64/` 免登录 tar.xz） |
| Python | 3.8（focal 自带，够 MindSpore 2.2 用） |
| MindSpore | 官方 wheel：`ms-release.obs.cn-north-4.myhuaweicloud.com/<ver>/MindSpore/unified/x86_64/mindspore-<ver>-cp38-cp38-linux_x86_64.whl` |

## 坑集（每条都踩过）

1. **GRU + PYNATIVE（默认异步）+ GPU 必崩**（约 300–2600 步随机）：`ResetResource` 刷 ERROR → `Launch kernel failed`/`CUDA 719`。
   已定位根因：PYNATIVE 异步派发路径下，`LaunchKernelsDynamic` 对每个 kernel 每步调 `Resize()`；而 `rl/gru_grad_data|gru_grad_weight` 这两个旧式 kernel 未实现 `ResetResource`、每次 Resize 都销毁重建整套 cuDNN 描述符 → 最终某个输出设备地址变空，**报错却落在无关的 `Slice` 上**。
   **两个修复（都实测）**：
   - **首选 `GRAPH_MODE`**（GRU 实测 3.0 ms/step，完全不触发；注意 GRAPH 下 `value_and_grad` 不能传 lambda）；
   - **必须 PYNATIVE 时加 `pynative_synchronize=True`**（关异步队列；最小复现 20000 步 + 项目模型 100 epoch 均零报错，代价约 1.6× 慢）。
   - 判断有没有踩坑：日志里 `ResetResource` 行数必须为 0；LSTM 在 PYNATIVE 下不受影响。
2. **版本告警可忽略**：`MindSpore version X and cuda version 11.8.x does not match ... officially`，功能正常。
3. **WSL 默认只给一半内存**（32G → 15G）→ 必须写 `.wslconfig`；否则训练/编译 OOM。
4. **数据别从 `/mnt/<盘>` 直读**（DrvFs 慢）→ 先 `cp` 进 WSL 家目录。
5. **DSH/沙箱内 `wsl` 命令报 `Wsl/E_ACCESSDENIED`**：沙箱禁止命名管道 → agent 内必须用 `danger-full-access` 提权执行；用户终端不受影响。
6. **Windows PowerShell 5.1 读 UTF-8 无 BOM 的 `.ps1` 会按 GBK 解析**→ 中文字符串报「字符串缺少终止符」。脚本要么存成 **纯 ASCII**，要么带 BOM。
7. **PowerShell 里写 bash heredoc 会吃掉 `$VAR` 和反引号**（`$CUDA_HOME` 变空、`PATH` 被 Windows 路径替换）→ 把 shell 脚本**写成文件**（用 write 工具），再 `bash <文件>`，不要内联拼接。
8. 下载源：NVIDIA 会 302 到 `developer.download.nvidia.cn`；`ms-release.obs...` 对**不存在的 key 返回 403**（不是 404），别把它当权限问题。
9. 官方**没有** CUDA 11.8/12.x 的 GPU wheel/镜像；`≥2.5 稳定版` 不再单发 GPU 包（Linux 包是 Ascend+CPU unified）。

## 验收清单（缺一不可）

```bash
nvidia-smi                                   # WSL 内能看到显卡
nvcc -V                                      # release 11.8
nvcc -arch=sm_89 hello.cu && ./hello         # devices=1, cc=8.9
python3 -c "import mindspore as ms; ms.set_context(device_target='GPU'); ms.run_check()"   # OK
# 再跑：matmul / Dense / LSTM / Conv2d / 一步训练反向
```

## 性能参考（RTX 4080 Laptop，项目真实数据 LSTM 多步16）

| 配置 | ms/step | 相对 CPU |
|---|---|---|
| CPU PYNATIVE | 52.3 | 1.0× |
| GPU PYNATIVE | 10.0 | 5.2× |
| GPU GRAPH | 6.6 | 7.9× |

## References

- 本机完整落地案例与脚本：`G:\CodexDS\DSH\MAIN\MINDSPORE\work\结论-MindSporeGPU环境-可用.md`、`work\env\`
- 官方源码安装（依赖矩阵）：https://github.com/mindspore-ai/docs/blob/master/install/mindspore_gpu_install_source_en.md
- 架构选择源码：https://gitee.com/mindspore/mindspore/blob/master/cmake/gpu_env_setup.cmake
- build.sh 选项（`-G`/`-V`）：https://gitee.com/mindspore/mindspore/blob/r2.2/scripts/build/usage.sh
- CUDA 11.8 Release Notes（sm_89 支持）：https://docs.nvidia.com/cuda/archive/11.8.0/cuda-toolkit-release-notes/index.html
- 官方 issue 通道：https://atomgit.com/mindspore/mindspore/issues （2025-12 起从 Gitee 迁至 AtomGit，Gitee 为镜像）
