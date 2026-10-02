# 夸克网盘 Linux 版（AppImage）

非官方的夸克网盘 Windows 客户端 Linux 封装。单个文件、开箱即用，无需安装 Wine、无需配置任何环境。

> 夸克网盘官方仅提供 Windows / macOS / 移动端客户端，Linux 用户此前只能使用网页版。本项目将官方 Windows 客户端与精简的 Wine 运行时打包为一个 AppImage，让 Linux 桌面用户可以完整使用网盘客户端（同步盘、分享、在线预览等）。

## 📥 下载

前往 [Releases](../../releases) 页面下载 `QuarkNetdisk-x86_64.AppImage`，附有 `.sha256` 校验文件：

```bash
sha256sum -c QuarkNetdisk-x86_64.AppImage.sha256
```

## ✨ 特性

- **单文件**：应用 + Wine 运行时 + 中文字体 + 预配置环境，全部在一个 AppImage 里（约 728 MB）
- **零依赖**：内置 Kron4ek Wine（wow64 构建），**不需要**系统安装 Wine，也**不需要** 32 位库（multilib）
- **开箱即用**：内置 Noto Sans CJK 中文字体、预设 200% 界面缩放、已规避 Wine Mono/Gecko 安装弹窗与 GPU 黑屏问题，系统对话框（文件选择等）中文显示正常
- **可调缩放**：`--dpi` 参数任意调整界面缩放
- **互不干扰**：所有数据写入用户目录，删除数据目录即完全重置

## 🚀 运行方法

```bash
chmod +x QuarkNetdisk-x86_64.AppImage
./QuarkNetdisk-x86_64.AppImage
```

如果系统提示 FUSE 相关错误（部分发行版未预装 libfuse2），改用：

```bash
./QuarkNetdisk-x86_64.AppImage --appimage-extract-and-run
```

首次启动会初始化运行环境（约十几秒），之后进入扫码登录界面。

## 🔧 命令行选项

```bash
./QuarkNetdisk-x86_64.AppImage [选项] [透传给应用的参数]

  --dpi <N>    界面缩放百分比，取值 60–480，默认 200
               例：--dpi 150、--dpi=175
  --help       显示帮助
```

缩放值按百分比解释（100 = 标准大小），非法值自动回落到 200。高分辨率屏幕建议 150–250。

## 📂 数据位置

| 内容 | 路径 |
|---|---|
| 全部数据（登录态、配置、缓存） | `~/.local/share/quark-netdisk/` |
| 完全重置 | 删除 `~/.local/share/quark-netdisk/` 后重新启动 |

**下载路径**：应用里的 Windows 路径通过 `Z:` 盘映射到真实 Linux 文件系统（`Z:\` = `/`）。推荐在客户端设置里把下载目录改为：

```
Z:\home\<你的用户名>\下载
```

即可直接下载到系统的下载文件夹。

## ⚠️ 已知限制

- **GPU 加速已关闭**（`--disable-gpu`）：开启时黑屏，故默认使用软件渲染。界面流畅度足够日常使用，但视频播放性能有限
- **Widevine DRM**：在 Wine 下不可用，部分加密版权视频可能无法播放
- **客户端自动更新无效**：AppImage 为只读挂载，客户端内升级不会成功。夸克发新版本后可用 `build.sh` 重新打包
- **首次启动较慢**、每次启动有几秒"正在更新 Wine 配置"提示，属正常现象

## 🩺 常见问题

| 现象 | 处理 |
|---|---|
| 提示缺少 libfuse2 | 加 `--appimage-extract-and-run` 参数，或安装 fuse2 包 |
| 界面字太大/太小 | `--dpi` 调整，如 `--dpi 150` |
| 下载的文件找不到 | 检查客户端内设置的下载路径是否为 `Z:\home\...` 开头；注意 `Downloads` 与 `下载` 是两个不同目录 |
| 想在应用菜单里显示 | 手动创建 `.desktop` 文件，`Exec` 指向 AppImage 路径，`Icon` 任选 |

## 🔒 隐私与安全

- 客户端本体为**阿里夸克官方 Windows 安装目录的逐字节原样副本**，未修改任何程序文件、资源与配置
- 打包层（AppRun 脚本 + Wine + 字体）不含任何网络行为；登录凭据仅保存在本机数据目录中
- 本仓库不包含、不分发夸克网盘的任何文件；构建脚本需要你自行提供官方安装目录
- 本项目与阿里巴巴/夸克官方无任何关系

## 🛠️ 自行构建

在一台装有 Linux 的 x86_64 机器上（构建依赖见 `build.sh` 头部注释）：

```bash
git clone <本仓库>
cd quark-netdisk-appimage
./build.sh /path/to/夸克Windows安装目录 ./build-out
```

- `/path/to/夸克Windows安装目录`：在 Windows 上安装夸克网盘后整个安装目录的拷贝（其下含 `7.3.5.810/` 这类版本子目录）
- 脚本自动完成：组装应用目录 → 下载 Kron4ek Wine（wow64）→ 构建预配置 prefix（中文字体、DPI、字体替换表、屏蔽 Mono/Gecko）→ 生成图标 → 打包 AppImage 并输出 sha256
- 产物：`build-out/QuarkNetdisk-x86_64.AppImage`（+ `.sha256`）

产品目录结构：

```
QuarkNetdisk.AppDir/
├── AppRun                      # 启动脚本：初始化数据目录、写入 DPI、调用 Wine
├── runtime/
│   ├── app/                    # 夸克网盘 Windows 版（原样副本）
│   ├── wine/                   # Kron4ek Wine (Staging, wow64)
│   └── prefix-template/        # 预配置 Wine prefix
└── quark.desktop / icon.png
```

技术要点（踩坑记录）：

- 夸克客户端核心功能依赖 6 个 Windows 预编译原生模块（含闭源的 `@ali/xdrive`），**没有 Linux 版本**，因此原生 Electron 移植不可行，Wine 是唯一路径
- Wine 选型用 wow64 构建：32 位代码跑在 64 位进程里，产物不依赖目标机器的 multilib
- 客户端所有运行时数据都写入 Wine prefix 的 AppData，安装目录只追加日志，因此只读挂载可以正常工作
- 应用数据与程序分离：换机器/重装只需重拷 AppImage，登录态在 `~/.local/share/quark-netdisk`
- 系统对话框豆腐块：Wine GDI 走注册表的 `FontSubstitutes`/`FontLink`，与 Chromium 的字体回退无关，需单独配置

## 📋 版本信息

| 组件 | 版本 |
|---|---|
| 夸克网盘（Windows） | 7.3.5.810（应用 2.5.40，Electron 24.1.3 夸克 fork） |
| Wine | 11.18 Staging（Kron4ek wow64 构建） |
| 字体 | Noto Sans CJK SC |
| 打包格式 | AppImage Type 2 |

## 📄 免责声明

本项目仅为个人学习与技术研究所做的打包封装，不提供、不修改、不分发夸克网盘的任何代码。夸克网盘软件版权归阿里巴巴集团所有，请支持正版；使用本封装即表示你已同意夸克网盘的官方用户协议。如有侵权请联系删除，作者不对使用本封装产生的任何问题负责。
