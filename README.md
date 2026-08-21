# Tang Primer 20K Z80 + PSG Sound System

Tang Primer 20K Dock 上に、Z80 互換CPU、ROM、RAM、AY-3-8910/YM2149互換PSGを構成し、Z80プログラムからI/Oポート経由でPSGを演奏する小型SoCを実装するプロジェクトです。

PSGが生成した3チャンネルの音声をFPGA内部でミックスし、16-bit PCMへ変換して、Dock搭載のPT8211ステレオDACから出力します。

> [!IMPORTANT]
> RTL実装とGowinでの合成・配置配線・bitstream生成までは完了しています。FPGAへの書き込みと実機での発音確認はまだ行っていません。

## 現在の実装状況

- TV80 Z80互換CPUを3.375 MHzで動作
- 8 KiB boot ROM + 56 KiB RAMを合計32個のBSRAMで構成
- Z80 I/Oポート`A0h`/`A1h`からJT49 PSGを制御
- PSG出力を16-bitモノラルPCMへ変換し左右へ複製
- 27 MHzからfractional dividerで48 kHz相当のPT8211信号を生成
- 起動ROMにRAMテスト、Cメジャー3音、Channel A音量変化を実装
- Icarus VerilogでRAMテスト、PSG書き込み11回、PT8211 BCKを確認済み
- Gowin EDA V1.9.11.03 Educationでbitstream生成済み

未確認項目は実機への転送、DAC信号の実測、実際の発音です。

## 目標

- Tang Primer 20KのFPGA上でZ80互換CPUを動作させる
- Z80からアクセスできるROMとRAMをBlock SRAMで構成する
- Z80の`OUT`/`IN`命令でPSGレジスタを操作する
- 3矩形波、ノイズ、エンベロープを利用できるようにする
- Dock搭載PT8211 DACとオーディオアンプから音を出す
- 最初の起動ROMだけで自動的に3音のテスト演奏を行う
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
| `0000h–1FFFh` | 8 KiB | ROM | 起動コードとテスト演奏プログラム |
| `2000h–FFFFh` | 56 KiB | RAM | プログラム、スタック、ワーク領域 |

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
| `B0h` | W | デバッグLED出力 |
| その他 | - | 予約。読み出し値は`FFh` |

I/Oライトパルスは、次の条件を27 MHzクロックへ同期させて1回だけ生成します。Z80の1回のバスサイクル中に同じPSGレジスタへ複数回書き込まないよう、前サイクルの状態を使って立ち上がりを検出します。

```text
io_write = !IORQ_n && !WR_n
io_read  = !IORQ_n && !RD_n
```

## PSG

PSGにはAY-3-8910/YM2149互換の[JT49](https://github.com/jotego/jt49)を採用しています。JT49の簡易インターフェースを使い、Z80側にアドレスラッチとデータポートを追加しています。

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

起動ROMではA、B、C各チャンネルに異なる周期を設定し、Cメジャー相当の3音が連続して聞こえるテストを実装します。Z80が停止してもPSGレジスタの設定は保持されるため、音が継続すればCPUからPSGまでの制御経路を確認できます。

## 音声データパス

JT49が生成する3チャンネル合成済み10-bit出力を、安全な範囲の16-bit unipolar PCMへスケーリングします。

```text
JT49 tone/noise/envelope --> 10-bit summed sound --> 16-bit scale
                                                --> L/R duplicate
```

初期版の方針：

- 中間加算器にはガードビットを持たせる
- 最大音量の3チャンネル同時発音でもオーバーフローさせない
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

## その他のピン割り当て

| 信号 | FPGAピン | 備考 |
| --- | --- | --- |
| `clk` | `H11` | 27 MHz |
| `rst_n` | `T3` | Sipeed PT8211サンプルに合わせたリセット入力 |
| `led` | `L16` | Active-lowデバッグLED |

現在の制約は、Sipeed公式PT8211サンプルに合わせて`rst_n=T3`を採用しています。別資料には`T10`の記載もあるため、手元のDockでリセットボタンが反応しない場合は、基板版と回路図を確認します。

## リセットシーケンス

1. 外部`rst_n`を27 MHzドメインへ2段同期する
2. PLLを使用する場合はlockを待つ
3. 1024システムクロック以上、内部リセットを保持する
4. ROM、RAM、PSG、PT8211シリアライザをリセット解除する
5. Z80のリセットを解除し、`0000h`から命令フェッチを開始する
6. PT8211へ無音を送り、最後に`PA_EN`をHighにする

非同期入力によるリセットアサートは許可しても、解除は必ずシステムクロックへ同期させます。

## 起動ROM

最初のROMプログラムは次を行います。

1. 割り込み禁止
2. SPを`FFFFh`へ設定
3. RAMの先頭数バイトへテストパターンを書き込んで読み戻す
4. 成功時はデバッグLEDを点灯、失敗時は消灯
5. PSGレジスタを初期化
6. Tone A/B/Cへ3音を設定
7. CPUレジスタのカウンタで一定時間待つ
8. 音程または音量を変更して、Z80が継続動作していることを示す
9. ループ

RAMテストとPSG更新を同じプログラムで行うことで、単なる固定ハードウェア発振ではなく、Z80がROMから実行し、RAMを使用し、I/Oポートを通じて音源を操作していることを確認します。

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
│   ├── boot.asm
│   └── boot.hex
└── sim/
    └── tb_top.v
```

この構成で初期RTL、起動ROM、制約、Gowinプロジェクト、テストベンチを実装済みです。

## ビルド

```sh
git clone --recurse-submodules https://github.com/GOROman/tang-primer-20k-z80.git
cd tang-primer-20k-z80
make build
```

既にclone済みでsubmoduleが空の場合は、先に次を実行します。

```sh
make init
```

macOS版Gowin EDAの標準インストール先を使用します。別の場所へインストールした場合は`GOWIN_ROOT`を指定してください。

```sh
make build GOWIN_ROOT=/path/to/Gowin_EDA/IDE
```

生成されるbitstreamは`impl/pnr/project.fs`です。`impl/`は生成物なのでGit管理しません。

ボードを接続した後、デバイスを確認してSRAMへ転送します。

```sh
openFPGALoader --detect
openFPGALoader --write-sram --reset -b tangprimer20k impl/pnr/project.fs
```

検出結果がTang Primer 20K/GW2A-18でない場合は書き込まないでください。

Icarus Verilogがインストール済みなら、次のコマンドでSoCテストを実行できます。

```sh
make sim
```

テストは、Z80によるRAMテスト成功、PSGレジスタ書き込み回数、PT8211 BCKの発生を検査します。

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

## ライセンス

このプロジェクト独自のRTLと文書はMIT Licenseです。TV80はMIT、JT49はGPL-3.0-or-laterです。JT49を含むbitstreamを再配布する場合は、GPL-3.0-or-laterの条件に従って対応するソースを提供してください。詳細と固定コミットは`THIRD_PARTY.md`を参照してください。
