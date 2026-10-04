# タイトル画面素材（ALAKAZAR）

Godot でタイトル画面を組むための素材です。メニューの文字は画像に入れていないので、Label で載せて、光る演出や選択カーソルを後から付けられます。

## ファイル

| ファイル | 中身 |
| --- | --- |
| `layer_00_background.png` | 背景。左が月夜の森、右が雨の監獄都市（不透明） |
| `layer_10_heroes.png` | 主人公と妖精たち（透過） |
| `layer_20_enemies.png` | 監獄軍勢と黒いシルエットの監獄の王（透過） |
| `layer_30_logo.png` | タイトル「ALAKAZAR」と一言「監獄都市に、妖精と挑め。」（透過） |
| `layer_40_menu_window.png` | 中身が空のメニューウィンドウ（透過） |
| `title_screen_no_menu_text.png` | 全レイヤーを重ねた完成形（メニュー文字なし） |
| `title_screen_reference.png` | 完成イメージ（メニュー文字あり）。見た目の参考用 |
| `layout.json` | メニューの座標、フォント、色 |

画像はすべて 1920×1080 の全画面サイズです。位置はレイヤー内で決まっているので、どれも (0,0) に置いて番号順に重ねれば完成形になります。キャラや背景を別々に揺らしたり、点滅させたりもできます。

## メニュー（後から Label で載せる部分）

- ウィンドウの位置: x 715, y 880, 幅 490, 高さ 193
- フォント: `res://assets/fonts/DotGothic16-Regular.ttf`、52px、中央揃え、黒（#07080f）のフチ
- 項目（中央揃え、上から順に）
  1. `GAME START`: 中心 (960, 939)
  2. `実績`: 中心 (960, 1013)
- 選択中の項目: 金色 #f2c14e、左に「▶」、金色の光（グロー）
- 選択していない項目: クリーム色 #fff6e0

正確な矩形は `layout.json` にあります。見た目は `title_screen_reference.png` に合わせてください。


## 1体ずつの画像（units/ と units.json）

主人公・妖精・敵を1体ずつ切り出した画像（全39体）と、その位置・重ね順（`units.json`）です。ゲームでは主人公側（23体）をこれで組み、**戦闘で使った妖精だけ色づく**ようにしています（`scripts/title/title_roster.gd`、`scripts/fairy_book.gd`）。敵側はまだ `layer_20_enemies.png`（と王を倒したあとの `layer_20_enemies_fallen.png`）を使っています。道化兵・竜装兵・バッテン兵・嵐鮫は、この2枚に `tools/add_title_enemies.py` で手前の列として貼り込んだものです。`layer_10_heroes.png` は今は使っていません（完成形の参考用）。
