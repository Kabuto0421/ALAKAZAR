# 語源の旅（ショート動画パイプライン）

ひとつの単語の語源を、地球儀の上で国と時代をまたいでたどる縦型ショート動画（1080×1920、30fps）を作ります。
第1回は **sin（罪）**。ヘブライ語・ギリシャ語・ラテン語・古英語、約6000年前の印欧祖語、漢字の「罪」をめぐります。

```
episodes/sin.json   台本・読み・地図の停留所・カード・演出（1本＝1ファイル）
tts.py              ナレーション合成（WEB版VOICEVOX API／ローカルVOICEVOX／Open JTalk仮音声）
audio.py            BGM・効果音の自動生成とミックス（素材ファイル不要）
render/             1フレームを描くページ（地球儀・カード・字幕・演出）
render.mjs          ヘッドレスChromiumで全フレームを撮影し、ffmpegでMP4化
build.py            全工程をまとめて実行
```

## 準備

```sh
cd etymology_shorts
npm install                      # 地図データ・フォント・Playwright
npx playwright install chromium  # 初回のみ
pip install numpy imageio-ffmpeg # ffmpegも同梱されます
pip install pyopenjtalk-plus     # 任意：VOICEVOXが使えない時の仮音声
```

## 作る

```sh
export VOICEVOX_API_KEY=xxxxxxxx   # WEB版VOICEVOX APIのキー（リポジトリには書かない）
python3 build.py sin
```

`build/sin/` に次のファイルができます。

| ファイル | 中身 |
| --- | --- |
| `sin.mp4` | 完成動画 |
| `description.txt` | 投稿文（クレジット・参考文献・ハッシュタグ入り） |
| `timeline.json` | 各セリフ・演出の秒数 |
| `audio.wav` | ミックス済み音声 |

音声エンジンは `--engine` で選べます。既定の `auto` は、APIキーがあればWEB版API、なければローカルのVOICEVOX（`127.0.0.1:50021`）、どちらも無ければOpen JTalkの仮音声を使います。仮音声の動画には左上に「PREVIEW｜仮音声」と表示されます。

```sh
python3 build.py sin --engine local        # VOICEVOXアプリを起動した状態で
python3 build.py sin --stills 0,12,45,90   # 指定秒の静止画だけ確認
python3 build.py sin --remux               # 音だけ作り直して、描画済みの映像に載せ直す
```

セリフごとの音声は `cache/tts/` にキャッシュされるので、台本を直しても変わった行だけ合成し直します。

## 台本の書き方（episodes/*.json）

- `voice` … `speaker` はVOICEVOXのスタイルID（14＝冥鳴ひまり、3＝ずんだもん など）、`speed`・`intonation`。
- `scenes[].lines[]` … `text` は字幕（`{…}` で囲んだ語が金色で光る）、`say` は読み上げ用の文。外国語や難読字はカタカナ・ひらがなで書きます。
- 各行で使える指定
  - `cards` … 下部に出すカード（`cards` 定義のID）。`pair`・`title`・`end` は画面中央の大きな演出になります。
  - `mark` … 地図上で光らせる地点、`routes` … 地点をつなぐ線（`faith`・`root`・`branch`・`east`）。
  - `camera` … 地球儀の向きとズーム、`era` … ヘッダーの年代カウンター。
  - `fx` … 行の途中で起きる演出。`at`・`len` はセリフの長さに対する割合（0〜1）なので、音声エンジンを変えても口とタイミングがずれません。
    `flash`・`shake`・`punch`・`stamp`（ハンコ）・`pop`（大きな文字）・`counter`（数字が回る）・`montage`（文字のフラッシュ）・`state`（カードの段階を進める）・`sfx`（`boom`・`thud`・`pop`・`shine`・`whoosh`・`glitch`・`ticks`）。

## クレジットと出典

- 音声：VOICEVOX（キャラクターごとの利用規約に従い、動画内と投稿文に「VOICEVOX:キャラ名」を表記します）
- 地図：Natural Earth（world-atlas経由、パブリックドメイン）
- フォント：しっぽり明朝、Noto Serif／Noto Serif JP／Hebrew／Devanagari、Cormorant Garamond（いずれもSIL Open Font License）
- BGM・効果音：`audio.py` がその場で合成（外部素材なし）
- 語源の出典は各エピソードの `sources` と、生成される `description.txt` に載ります。
