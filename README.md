# Tang Primer 20K Z80 + PSG Sound System

Tang Primer 20K Dock 上に、Z80 互換CPU、ROM、RAM、AY-3-8910/YM2149互換PSG×2を構成し、Z80プログラムからI/Oポート経由で演奏する小型SoCプロジェクトです。

2基のPSGが生成した合計6チャンネルをFPGA内部でミックスし、16-bit PCMへ変換して、Dock搭載のPT8211ステレオDACから出力します。

> [!IMPORTANT]
> RTL実装、実アセンブル、シミュレーション、Gowinでのbitstream生成、GW2A-18へのSRAM転送、PT8211からの実機発音まで確認済みです。HDMI画面とUSB UVC列挙・映像は実機確認中です。

## 現在の実装状況

- TV80 Z80互換CPUを3.375 MHzで動作
- 8 KiB boot ROM + 56 KiB RAMを合計32個のBSRAMで構成
- Z80 I/Oポート`A0h`/`A1h`と`A2h`/`A3h`からJT49 PSG×2を独立制御
- PSG出力を16-bitモノラルPCMへ変換し左右へ複製
- 27 MHzからfractional dividerで48 kHz相当のPT8211信号を生成
- `z80asm`でROMブートローダとRAM用PSGプログラムを実アセンブル
- ROMでRAMテスト後、`JP 2000h`によりRAM上のプログラムを実行
- RAMプログラムにC→G→Am→Em→F→C→F→Gのカノン進行を実装
- PSG1で3和音、PSG2で`+2`デチューンの8ステップリード、三角形ハードウェアエンベロープ、キック／スネア／ハイハット風ノイズを演奏
- Icarus Verilogで両PSGへの書き込み、デチューン、エンベロープ再トリガー、ノイズ、PT8211 BCKを確認済み
- HDMI VGA互換640×480p60画面にZ80のPC/AF/BC/DE/HL/SP/RとPSG1/PSG2の各R0〜RFを16進表示
- DockのS2/S3で0〜100%の音量を10%刻みで調整（起動時10%）
- USB3317 ULPI経由のUVC 1.1 WebCamとして同じ画面をYUY2 640×480p30で送信
- Gowin EDA V1.9.11.03 Educationでbitstream生成済み
- GW2A(R)-18(C)を検出し、bitstreamをSRAMへ転送済み
- LED1/0交互点滅とPT8211の実機発音を確認済み

未確認項目はHDMI画面の実機表示と、PC上でのUSB UVC列挙・映像表示です。

## 目標

- Tang Primer 20KのFPGA上でZ80互換CPUを動作させる
- Z80からアクセスできるROMとRAMをBlock SRAMで構成する
- Z80の`OUT`/`IN`命令でPSGレジスタを操作する
- 3矩形波、ノイズ、エンベロープを利用できるようにする
- Dock搭載PT8211 DACとオーディオアンプから音を出す
- 起動ROMからRAM上のアセンブル済みプログラムを実行して3音を演奏する
- シミュレーション、合成、書き込み、実機発音を別々に検証する

## 対象ハードウェア

- Sipeed Tang Primer 20K Core Board
- GW2A-LV18PG256C8/I7 FPGA
- Tang Primer 20K Dock
- Dock搭載PT8211ステレオDAC
- Dockの3.5 mmオーディオ出力、または接続されたスピーカー
- 27 MHzオンボードクロック

DockなしでCore Board単体を使う場合は、PT8211または互換DAC、ローパスフィルタ、アンプを外付けし、ピン制約を変更する必要があります。

## システム構成

```text
                         27 MHz
                            |
                  +---------v---------+
                  | clock / reset     |
                  | clk_sys = 27 MHz  |
                  | Z80 clock divider |
                  | PSG clock enable  |
                  | 48 kHz sample CE  |
                  +----+-----------+--+
                       |           |
              3.375 MHz clock     |
                       |           |
                +------v------+    |
                | Z80 core    |    |
                | T80/TV80    |    |
                +------+------+    |
                       | address/data/control
             +---------+----------+
             |                    |
      +------v------+      +------v-------+
      | memory bus  |      | I/O decoder  |
      +------+------+      +------+-------+
             |                    |
       +-----+-----+        +-----v------+
       |           |        | PSG core   |
    +--v--+     +--v--+     | YM2149/AY  |
    | ROM |     | RAM |     +-----+------+
    +-----+     +-----+           | 3 channels
                                  v
                           +------+-------+
                           | mixer / gain |
                           | 16-bit PCM   |
                           +------+-------+
                                  | 48 kHz PCM
                           +------v-------+
                           | PT8211       |
                           | serializer   |
                           +------+-------+
                                  | BCK/WS/DIN
                           +------v-------+
                           | Dock PT8211  |
                           | DAC + AMP    |
                           +--------------+
```

## クロック設計

メモリ、I/O、PSG、PT8211送信器は27 MHzで動作します。TV80のラッパーはclock enable入力を持たないため、3-bitカウンタで生成した3.375 MHzクロックを与え、SDCで27 MHzからのdivide-by-8 generated clockとして制約しています。PSG内部には27 MHzから生成したclock enableを与えます。

| 用途 | 周波数 | 生成方法 |
| --- | ---: | --- |
| システムクロック | 27 MHz | `clk`入力を直接使用 |
| Z80 | 3.375 MHz | 27 MHzを8分周した派生クロック |
| PSG基準 | 1.6875 MHz | 27 MHzを16分周したclock enable |
| PCMサンプル更新 | 48 kHz | PT8211の32-bitフレーム境界 |
| PT8211 BCK | 1.536 MHz | PLLまたは位相アキュムレータで生成 |

Z80クロックはレジスタ出力から生成し、Gowinのグローバルクロック資源へ配置されています。今後PLLや専用CLKDIVへ変更する場合も、`clk_cpu`のgenerated clock制約を維持します。

48 kHz × 32 bit = 1.536 MHzのBCKで、左右それぞれ16 bitを送信します。PSGはモノラルなので、同じサンプルを左右へ送ります。

## Z80コア

Z80互換コアには[TV80](https://github.com/hutch31/tv80)の`tv80n`を採用しています。MITライセンスの固定コミットを`third_party/tv80` submoduleとして組み込み、Gowin EDAで合成できることを確認済みです。出典と固定コミットは`THIRD_PARTY.md`に記録しています。

必要なCPU信号は次のとおりです。

| 信号 | 方向 | 用途 |
| --- | --- | --- |
| `A[15:0]` | CPU出力 | メモリ／I/Oアドレス |
| `DI[7:0]` | CPU入力 | 読み出しデータ |
| `DO[7:0]` | CPU出力 | 書き込みデータ |
| `MREQ_n` | CPU出力 | メモリアクセス |
| `IORQ_n` | CPU出力 | I/Oアクセス |
| `RD_n` | CPU出力 | 読み出し |
| `WR_n` | CPU出力 | 書き込み |
| `WAIT_n` | CPU入力 | ウェイト要求。初期実装では常時High |
| `INT_n` | CPU入力 | 割り込み。初期実装では常時High |
| `NMI_n` | CPU入力 | NMI。初期実装では常時High |
| `RESET_n` | CPU入力 | 同期化したリセット |

初期版ではWAIT、割り込み、バスリクエストを使いません。まず命令フェッチ、RAM読み書き、I/O書き込みの最小経路を動作させます。

## メモリマップ

Z80の64 KiBアドレス空間を次のように割り当てます。

| アドレス | サイズ | 種別 | 内容 |
| --- | ---: | --- | --- |
| `0000h–1FFFh` | 8 KiB | ROM | RAMテストと`JP 2000h`を行うブートローダ |
| `2000h–FFFFh` | 56 KiB | RAM | アセンブル済みPSGプログラム、スタック、ワーク領域 |

ROMとRAMはGW2AのBlock SRAMから推論します。外部DDR3は初期版では使いません。8 KiB ROMと56 KiB RAMの合計64 KiBは約512 Kbitです。

### メモリバス条件

```text
rom_cs = !MREQ_n && A[15:13] == 3'b000
ram_cs = !MREQ_n && A[15:13] != 3'b000
mem_rd = !MREQ_n && !RD_n
mem_wr = !MREQ_n && !WR_n
```

- ROMへの書き込みは無視する
- RAMは同期読み出しBlock SRAMとして構成する
- CPUコアの読み出しタイミングと1サイクル遅延が合わない場合だけ`WAIT_n`を追加する
- ROMの初期値はアセンブル済みHEXファイルをGowin BSRAMへ読み込む
- 未選択時のCPU入力データは`FFh`とする

## I/Oポートマップ

Z80のI/O空間は下位8 bitをデコードします。

| ポート | R/W | 内容 |
| --- | --- | --- |
| `A0h` | W | PSGレジスタ番号を選択（0～15） |
| `A1h` | W | 選択中のPSGレジスタへデータを書き込み |
| `A1h` | R | 選択中のPSGレジスタを読み出し |
| `A2h` | W | PSG2レジスタ番号を選択（0～15） |
| `A3h` | W | PSG2の選択中レジスタへデータを書き込み |
| `A3h` | R | PSG2の選択中レジスタを読み出し |
| `B0h` | W | デバッグLED5〜0出力（bit 5〜0、1で点灯） |
| `C0h`〜`CBh` | W | HDMI用Z80スナップショット（PC、AF、BC、DE、HL、SP） |
| その他 | - | 予約。読み出し値は`FFh` |

診断ファームウェアは、`20h`（Boot ROM開始）、`10h`（RAM試験成功）、
`08h`（RAMアプリ開始）、`04h`（PSG初期化完了）の順に表示し、
メインループでは`02h`と`01h`を交互に出力してLED1/LED0を点滅させます。
RAM試験に失敗した場合はLED0が点灯したままになります。

I/Oライトパルスは、次の条件を27 MHzクロックへ同期させて1回だけ生成します。Z80の1回のバスサイクル中に同じPSGレジスタへ複数回書き込まないよう、前サイクルの状態を使って立ち上がりを検出します。

```text
io_write = !IORQ_n && !WR_n
io_read  = !IORQ_n && !RD_n
```

## PSG

PSGにはAY-3-8910/YM2149互換の[JT49](https://github.com/jotego/jt49)を2基採用しています。それぞれに独立したアドレスラッチとデータポートを割り当てます。

### PSGレジスタ

| Reg | 内容 |
| ---: | --- |
| 0, 1 | Tone A period |
| 2, 3 | Tone B period |
| 4, 5 | Tone C period |
| 6 | Noise period |
| 7 | Mixer enable |
| 8 | Channel A volume / envelope enable |
| 9 | Channel B volume / envelope enable |
| 10 | Channel C volume / envelope enable |
| 11, 12 | Envelope period |
| 13 | Envelope shape |
| 14, 15 | GPIO。初期版では未使用 |

### Z80からの書き込み例

```asm
PSG_ADDR equ 0A0h
PSG_DATA equ 0A1h

; Register 0 = Tone A fine period
ld a, 0
out (PSG_ADDR), a
ld a, 0ACh
out (PSG_DATA), a

; Register 1 = Tone A coarse period
ld a, 1
out (PSG_ADDR), a
xor a
out (PSG_DATA), a

; Register 7 = enable Tone A, disable noise on all channels
ld a, 7
out (PSG_ADDR), a
ld a, 03Eh
out (PSG_DATA), a

; Register 8 = Channel A volume 15
ld a, 8
out (PSG_ADDR), a
ld a, 0Fh
out (PSG_DATA), a
```

RAM上のプログラムはPSG1でC→G→Am→Em→F→C→F→Gのカノン進行を3和音で演奏します。PSG2のTone A/Bは8ステップのリードを周期`+2`で重ねてデチューンし、Volume register 8/9のエンベロープビットを使います。各音でEnvelope shape register 13に`0Eh`を書き、上下反復する三角形エンベロープを再トリガーします。発振波形自体はPSGの矩形波です。PSG2のChannel Cはノイズ専用で、Noise periodと音量を変えてキック、スネア、クローズド／オープンハイハット風の8ステップリズムを重ねます。

## 音声データパス

2基のJT49が生成する各10-bit出力を11-bitで加算し、16-bit unipolar PCMへスケーリングします。起動時の10%では合算後を3/2倍し、2基が同時に最大出力でもPCMピークは3069です。S2/S3で0〜100%を10%刻みに変更でき、最大時も16-bit範囲内に収めます。

```text
PSG1 tone A/B/C ----------+
                          +--> 11-bit sum --> x3/2 --> 16-bit PCM --> L/R
PSG2 melody A/B + noise C-+                 S2/S3 volume 0..100%
```

初期版の方針：

- 中間加算器にはガードビットを持たせる
- 6チャンネル同時発音でもオーバーフローさせない
- 無音時をPCMの`0000h`とする
- 同一モノラルサンプルを左右チャンネルへ送る
- `PA_EN`はリセット中Low、DACへ無音フレームを数回送った後にHighとする
- 電源投入時のポップノイズを減らすため、振幅を短時間でランプアップする

PSGの非線形音量特性を再現する場合は、将来15/16段の振幅LUTを追加します。初期版ではコアの出力形式を確認し、単純な安全スケーリングから開始します。

## PT8211 DACインターフェース

Tang Primer 20K DockのPT8211へ次の3信号を出力します。

| 信号 | FPGAピン | 内容 |
| --- | --- | --- |
| `HP_DIN` | `P15` | 16-bitシリアル音声データ |
| `HP_WS` | `P16` | 左右チャンネル選択 |
| `HP_BCK` | `N15` | 1.536 MHz bit clock |
| `PA_EN` | `R16` | オーディオアンプ有効化 |

PT8211は一般的なI2Sとはデータ位置やWSタイミングが異なるため、汎用I2S送信器をそのまま使わず、PT8211用シリアライザを使用します。DINはBCKのサンプリングエッジに対して十分なセットアップ時間を確保します。

## HDMIデバッグ表示

27 MHz入力からPLLで126 MHzを生成し、5分周した25.2 MHzを使って
VGA互換640×480p60のデバッグ画面を出力します。左ペインにZ80、中央にPSG1、右ペインにPSG2を配置します。Z80欄は`PC`、`AF`、`BC`、`DE`、`HL`、`SP`、`R`と音量、下段は`RAM:2000`として`2000h`〜`200Fh`の16バイト、PSG欄はそれぞれ`R0:xx`〜`RF:xx`を縦16行で表示します。

RAM表示範囲は本体RAMと同じHEXで初期化した16-byte診断ミラーで、Z80が`2000h`〜`200Fh`へ書く場合も本体と同時更新します。RAM全体へ第2読み出しポートを追加せず、Gowin BSRAMの対応モードを維持します。

AF/BC/DE/HL/SPはRAM上の演奏プログラムがI/Oポート`C0h`〜`CBh`へ周期的に書く一貫したスナップショットです。PCはTV80のM1命令フェッチアドレスをハードウェアで追跡するため、実行位置に応じて変化します。Rは各M1サイクルで下位7bitを加算しbit 7を保持するZ80互換リフレッシュカウンタです。

USB UVC出力は現在PSG1のレジスタ画面のみを使い、非圧縮YUY2 640×480p30として送出します。

TMDSエンコードとGW2A OSER10シリアライザにはMITライセンスの
[osafune/hdmi_tx](https://github.com/osafune/hdmi_tx)を使用します。

| 信号 | FPGAピンペア | 内容 |
| --- | --- | --- |
| `O_tmds_clk_p` | `G16,H15` | TMDS clock |
| `O_tmds_data_p[0]` | `H14,H16` | TMDS data 0 |
| `O_tmds_data_p[1]` | `J15,K16` | TMDS data 1 |
| `O_tmds_data_p[2]` | `K14,K15` | TMDS data 2 |

## USB HOST/OTG端子のWebCam出力

Dock上で「USB HOST」と表記されるUSB3317接続端子を、PC接続時にはUSB 2.0
High-Speed UVC Deviceとして使用します。USB機能スライドスイッチをDevice/OTG側へ
設定してからPCへ接続してください。JTAG/UART用Type-C端子とは別の端子です。

- UVC version: 1.1
- Format: YUY2、640×480、16 bit/pixel
- Frame interval: 333,333×100 ns（約30 fps）
- Transfer: High-Speed Bulk IN、Endpoint `81h`、最大512 byte
- Payload: 各USBパケットの先頭に2-byte UVCヘッダ、FID/EOF付き
- USB PHY: Dock搭載USB3317、60 MHz ULPI

`rtl/generated/usb_uvc_core.v`はLUNA 0.2.3から生成した固定Verilogです。通常の
GowinビルドではPython依存関係は不要です。コアを再生成する場合だけ、Python仮想環境で
次を実行します。

```sh
python3 -m pip install -r tools/requirements-uvc.txt
make uvc-core
```

UVCパケット生成の単体テストは次のとおりです。

```sh
make sim-uvc
```

テストは1フレームについて、1205パケット、614,400映像byte、合計616,810 byte、
YUY2先頭画素、EOFヘッダを確認します。

| ULPI信号 | FPGAピン |
| --- | --- |
| `ulpi_clk` | `T15` |
| `ulpi_dir` / `ulpi_nxt` / `ulpi_stp` | `K12` / `K13` / `K11` |
| `ulpi_rst` | `F10` |
| `ulpi_data[7:0]` | `R12,P13,R13,T14,H13,J12,H12,G11` |

USB診断中は起動後のLED5/4/3をULPI状態表示にも使います。LED5は60 MHz
ULPIクロック検出、LED4はDIRを一度でも検出、LED3はNXTを一度でも検出すると点灯を保持します。
LED1/0の交互点滅は従来どおりZ80 RAMプログラムの動作表示です。

## その他のピン割り当て

| 信号 | FPGAピン | 備考 |
| --- | --- | --- |
| `clk` | `H11` | 27 MHz |
| `rst_n` | `T10` | DockのS0スイッチ、Active-Lowリセット入力 |
| `vol_down_n` | `T2` | DockのS2、音量を10%下げる、Active-Low |
| `vol_up_n` | `D7` | DockのS3、音量を10%上げる、Active-Low |
| `led[5:0]` | `L16,L14,N14,N16,A13,C13` | DockのLED5〜0、Active-lowデバッグLED |

S0を押している間はZ80、RAM制御、PSG、PT8211送信器をリセットし、離してから1024システムクロック待ってZ80を`0000h`から再起動します。S2/S3は20 msデバウンス後、押下1回につき音量を1段階変更し、離すまで再入力しません。

## リセットシーケンス

1. 外部`rst_n`を27 MHzドメインへ2段同期する
2. PLLを使用する場合はlockを待つ
3. 1024システムクロック以上、内部リセットを保持する
4. ROM、RAM、PSG、PT8211シリアライザをリセット解除する
5. Z80のリセットを解除し、`0000h`から命令フェッチを開始する
6. PT8211へ無音を送り、最後に`PA_EN`をHighにする

非同期入力によるリセットアサートは許可しても、解除は必ずシステムクロックへ同期させます。

## Z80ソフトウェア

### ROMブートローダ

`firmware/boot/boot.asm`を`0000h`向けにアセンブルします。

1. 割り込み禁止
2. SPを`FFFFh`へ設定
3. アプリケーションを壊さない`FF00h`で`55h`/`AAh`のRAMテスト
4. 失敗時はLEDを消灯して停止
5. 成功時は`JP 2000h`でRAMへ制御を移す

### RAMプログラム

`firmware/psg_demo/main.asm`を`2000h`向けにアセンブルします。

1. デバッグLEDを点灯
2. PSGレジスタを初期化
3. PSG1のTone A/B/Cでカノン進行の3和音を設定
4. PSG2のTone A/Bで`+2`デチューンのメロディを演奏
5. 各音で減衰エンベロープを再トリガー
6. PSG2のNoise Cでキック／スネア／ハイハット風8ステップリズムを重ねてループ

`make firmware`は両ソースを実際に`z80asm`でアセンブルします。生成された38バイトのROMイメージを`0000h`、420バイトのPSGプログラムを`2000h`からBlock RAMへ初期配置します。PSG用HEXはRAM領域全体の56 KiBへ自動的にゼロ埋めするため、アプリが増えても固定バイト数で途切れません。

## 想定ディレクトリ構成

```text
.
├── README.md
├── THIRD_PARTY.md
├── Makefile
├── project.gprj
├── run.tcl
├── constraints/
│   ├── tang_primer_20k.cst
│   └── tang_primer_20k.sdc
├── rtl/
│   ├── top.v
│   ├── reset_sync.v
│   ├── z80_soc.v
│   ├── soc_memory.v
│   ├── io_decoder.v
│   ├── psg_wrapper.v
│   ├── audio_mixer.v
│   └── pt8211_tx.v
├── firmware/
│   ├── boot/
│   │   └── boot.asm
│   ├── psg_demo/
│   │   └── main.asm
│   └── generated/
│       ├── boot.hex
│       └── psg_demo.hex
├── tools/
│   └── bin2hex.py
└── sim/
    └── tb_top.v
```

この構成で初期RTL、起動ROM、制約、Gowinプロジェクト、テストベンチを実装済みです。

## ビルド

```sh
git clone --recurse-submodules https://github.com/GOROman/tang-primer-20k-z80.git
cd tang-primer-20k-z80
brew install z80asm icarus-verilog
make build
```

既にclone済みでsubmoduleが空の場合は、先に次を実行します。

```sh
make init
```

macOS版Gowin EDAの標準インストール先を使用します。別の場所へインストールした場合は`GOWIN_ROOT`を指定してください。

Z80ソフトウェアだけを再アセンブルする場合は次を実行します。

```sh
make firmware
```

生成される`boot.hex`と`psg_demo.hex`はGowinの`$readmemh`形式です。`.bin`と`.lst`は確認用生成物としてGit管理しません。

```sh
make build GOWIN_ROOT=/path/to/Gowin_EDA/IDE
```

### Mac Studioでのリモート実行

SSH接続可能なMac Studioへソースを同期し、重い合成やシミュレーションを
リモート実行できます。既定ホストは`mac-studio.local`、作業先は
`/tmp/tang-primer-20k-z80-remote`です。秘密鍵や認証情報は同期しません。

```sh
make remote-build
make remote-sim
make remote-sim-uvc
make remote-deploy
```

`remote-build`は成功後にアセンブル済みHEX、`project.fs`、配置配線レポートを
ローカルへ回収します。`remote-sim`もアセンブル済みHEXを回収します。
`remote-deploy`はフルSoCシミュレーション、合成、
成果物回収、ローカル接続されたFPGAの検出、SRAM転送までを順番に実行します。
接続先や作業先は必要に応じて変更できます。

```sh
make remote-build REMOTE_HOST=mac-studio.local \
  REMOTE_DIR=/tmp/tang-primer-20k-z80-remote
```

Mac Studio側にはGowin EDA、Homebrew版`z80asm`、シミュレーション時は
Homebrew版`iverilog`が必要です。

生成されるbitstreamは`impl/pnr/project.fs`です。`impl/`は生成物なのでGit管理しません。

ボードを接続した後、デバイスを確認してSRAMへ転送します。

```sh
openFPGALoader --detect
openFPGALoader --write-sram -b tangprimer20k impl/pnr/project.fs
```

> **重要:** SRAM転送に`--reset`を付けてはいけません。
> `openFPGALoader --reset`は操作後にFPGAをリセットするため、SRAMへ転送した
> 新しい構成が破棄され、Flash内の旧ビットストリームへ戻ります。
> 転送ログが100%および`DONE`でも、実機では旧版が動くため注意してください。
> S0はT10に接続したSoC内のActive-Lowリセットなので、SRAM転送後の
> Z80再起動にはS0を使用します。

検出結果がTang Primer 20K/GW2A-18でない場合は書き込まないでください。

Icarus Verilogがインストール済みなら、次のコマンドでSoCテストを実行できます。

```sh
make sim
make sim-uvc
```

`make sim`はROM上のRAMテスト、`2000h`からのRAMコード実行、両PSGのシャドウ値、Z80レジスタスナップショット、S2/S3音量操作、デチューン差、エンベロープ再トリガー、ノイズ、PT8211 BCK、PA_EN、PCMピークを検査します。`make sim-uvc`はUVC/YUY2パケット境界とフレーム長を検査します。

## 実装ステップ

### Phase 1: ボード基盤

- 27 MHzクロック、リセット、LEDを実装
- PT8211へFPGA生成の固定サイン波または矩形波を出力
- DAC、アンプ、ピン制約を単独で実機確認

### Phase 2: Z80 + ROM

- Z80コアと8 KiB ROMを接続
- 起動ROMからLEDを周期的に変化させる
- シミュレーションで命令フェッチを確認

### Phase 3: RAM

- 56 KiB RAMを追加
- ROMプログラムで書き込み／読み戻しテスト
- RAMエラーをLEDパターンで表示

### Phase 4: PSG I/O

- PSGコアと`A0h`/`A1h`デコーダを追加
- テストベンチでZ80の`OUT`命令からPSGレジスタ更新まで確認
- PSG出力波形の周期を確認

### Phase 5: 統合音声

- PSGミキサーをPT8211へ接続
- 起動ROMから3音を設定
- 実機で左右の音声出力と音程変化を確認

### Phase 6: 拡張

- UARTモニタまたはROMローダ
- タイマ割り込み
- RAMへのプログラム転送
- PSGレジスタダンプ
- ステレオパン、音量LUT、追加音源

## 検証計画

### RTLシミュレーション

- リセット後、最初の命令フェッチアドレスが`0000h`である
- ROMとRAMのchip selectが同時に有効にならない
- RAMの全テストパターンが正しく読み戻せる
- `OUT (A0h),A`でPSGレジスタ番号がラッチされる
- `OUT (A1h),A`で指定レジスタが1回だけ更新される
- Tone A/B/Cの出力周期が設定値と一致する
- PCMにオーバーフローやDCオフセット異常がない
- PT8211の1フレームが左右16 bitずつである

### 合成・配置配線

- 対象デバイスが`GW2A-LV18PG256C8/I7`である
- 27 MHzのタイミング制約を満たす
- すべての外部I/Oに正しいピンとI/O規格が設定されている
- inferred RAMがBlock SRAMへ割り当てられている
- 意図しないラッチや組み合わせループがない

### 実機

1. `openFPGALoader --detect`などで接続デバイスを確認する
2. FPGAへ最新ビルドのbitstreamを書き込む
3. LEDでリセット解除とRAMテスト合格を確認する
4. ロジックアナライザで`HP_BCK`、`HP_WS`、`HP_DIN`を確認する
5. 音量を下げた状態でオーディオ出力を接続する
6. 3音と周期的な音程／音量変化を聴いて確認する

合成成功、bitstream書き込み成功、DAC信号観測、実際の発音は別々の結果として記録します。書き込み時の`DONE`やCRC成功だけでは、Z80、RAM、PSG、音声出力の動作確認にはなりません。

## 完了条件

最初のマイルストーンは、次をすべて満たした状態です。

- Gowin EDAでエラーなく合成、配置配線できる
- Tang Primer 20Kを検出してbitstreamを書き込める
- Z80がROMのプログラムを繰り返し実行する
- ROMプログラムがRAMへ書き込み、正しく読み戻せる
- Z80の`OUT`命令でPSGの複数レジスタを更新できる
- PSGの3チャンネルが異なる周期で動作する
- PT8211の左右から同じ16-bit PCMを出力できる
- 実機のオーディオ出力から意図した3音と変化を確認できる

## 参考資料

- [Sipeed Tang Primer 20K examples](https://github.com/sipeed/TangPrimer-20K-example)
- [Tang Primer 20K Wiki](https://wiki.sipeed.com/hardware/en/tang/tang-primer-20k/primer-20k.html)
- [JT49 YM2149-compatible PSG core](https://github.com/jotego/jt49)
- [T80 Z80-compatible core](https://opencores.org/projects/t80)
- [TV80 Z80-compatible core](https://github.com/hutch31/tv80)
- [osafune/hdmi_tx](https://github.com/osafune/hdmi_tx)
- [Great Scott Gadgets LUNA](https://github.com/greatscottgadgets/luna)

## ライセンス

このプロジェクト独自のRTLと文書はMIT Licenseです。TV80とhdmi_txはMIT、LUNAはBSD-3-Clause、JT49はGPL-3.0-or-laterです。JT49を含むbitstreamを再配布する場合は、GPL-3.0-or-laterの条件に従って対応するソースを提供してください。詳細と固定コミットは`THIRD_PARTY.md`を参照してください。
