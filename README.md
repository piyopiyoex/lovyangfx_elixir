# lovyangfx_elixir

`lovyangfx_elixir` は、Linux framebuffer 向けの [LovyanGFX](https://github.com/lovyan03/LovyanGFX) を Elixir から使うための NIF ラッパーです。

Nerves を主な利用対象にしていますが、パッケージ自体は Nerves 専用ではありません。`/dev/fb0` を使える Linux 環境であれば利用できます。

## できること

- `LovyanGFX.start/1` で framebuffer 描画先を初期化
- `LovyanGFX.render/1` で描画コマンドをまとめて実行
- 図形、文字、画像、スプライトの基本操作
- `LovyanGFX.Nerves.Renderer` による Nerves 向け起動補助
- `LovyanGFX.Examples.MovingIcons.Renderer` による smoke test 用デモ

## このパッケージがやらないこと

このパッケージは表示デバイスの準備までは行いません。特に Nerves アプリ側で次を行う前提です。

- 必要なディスプレイドライバの読み込み
- `/dev/fb0` の出現待ち
- 必要なら framebuffer console の切り離し
- タッチ入力やシステム情報の収集

## インストール

現時点では Hex 公開を前提にしておらず、Git リポジトリ参照で使う想定です。

Git リポジトリを直接参照する場合の例:

```elixir
defp deps do
  [
    {:lovyangfx_elixir, github: "piyopiyoex/lovyangfx_elixir", branch: "main"}
  ]
end
```

## LovyanGFX 本体の扱い

LovyanGFX のソースは `c_src/vendor/lovyangfx` に取得して利用します。

- upstream のソースツリーはこのリポジトリに commit しません
- ディレクトリがなければビルド時に `1.2.24` を取得します
- 意図的に更新したい場合は `scripts/update_lovyangfx` を使います

## 基本的な使い方

```elixir
LovyanGFX.start(width: 800, height: 480, framebuffer: "/dev/fb0")

LovyanGFX.render([
  {:fill_screen, :black},
  {:set_font, :font4},
  {:set_text_color, :white},
  {:set_cursor, 10, 10},
  {:println, "Hello LovyanGFX"},
  {:draw_line, 0, 48, 200, 48, :red},
  {:draw_round_rect, 8, 72, 180, 80, 8, :green},
  {:fill_triangle, 260, 72, 320, 152, 200, 152, :blue},
  {:set_text_datum, :middle_center},
  {:draw_string, "READY", 400, 240, :font4}
])
```

## 画像コマンド

既存の LovyanGFX 学習資料を参照しやすいように、画像コマンドは upstream に近い名前を使います。

```elixir
rgb565_binary = <<...>>
png_binary = File.read!("priv/icon.png")

LovyanGFX.render([
  {:fill_screen, :black},
  {:push_image, 0, 0, 64, 64, rgb565_binary},
  {:draw_png, png_binary, 80, 0},
  {:draw_jpg_file, "priv/photo.jpg", 0, 100},
  {:draw_bmp_file, "priv/logo.bmp", 160, 100}
])
```

`*_file` コマンドは native 側で file path を直接開いて描画します。バイナリをすでに持っている場合は `draw_*` コマンドを使ってそのまま渡せます。

## ローカル IEx での確認

表示ハードウェアがない環境では、開発用設定として `LovyanGFX.NullBackend` を使えます。

```sh
LOVYANGFX_ELIXIR_SKIP_NATIVE=1 iex -S mix
```

- NIF を読み込みません
- `/dev/fb0` に触りません
- 描画呼び出しの内容を内部 state に記録します

```elixir
LovyanGFX.start(width: 800, height: 480, framebuffer: "/dev/fb0")

LovyanGFX.render([
  {:fill_screen, :black},
  {:set_text_color, :white},
  {:draw_string, "Hello local IEx", 10, 10, :font4}
])

LovyanGFX.NullBackend.state()
```

呼び出し内容をその場で見たい場合:

```elixir
Application.put_env(:lovyangfx_elixir, :null_backend_echo, true)
```

ローカル IEx から実 backend を使いたい場合:

```elixir
Application.put_env(:lovyangfx_elixir, :backend, LovyanGFX.NativeBackend)
```

この場合は NIF を実際にビルドできることと、利用可能な framebuffer が必要です。

## 対応コマンド

```text
:fill_screen
:clear
:draw_pixel
:draw_line
:draw_fast_hline
:draw_fast_vline
:draw_rect
:fill_rect
:draw_round_rect
:fill_round_rect
:draw_circle
:fill_circle
:draw_triangle
:fill_triangle
:push_image
:push_rgb565
:push_grayscale
:draw_jpg
:draw_png
:draw_bmp
:draw_qoi
:draw_jpg_file
:draw_png_file
:draw_bmp_file
:draw_qoi_file
:create_sprite
:delete_sprite
:target
:push_sprite
:push_sprite_with_key_color
:push_rotate_zoom
:set_font
:set_text_size
:set_text_color
:set_text_datum
:set_text_padding
:set_cursor
:set_rotation
:set_color_depth
:draw_string
:draw_number
:draw_float
:print
:println
:display
```

## 補助 API

表示状態を取得できます。

```elixir
LovyanGFX.width()
LovyanGFX.height()
LovyanGFX.rotation()
```

## 色の指定

次の形式をサポートします。

```elixir
:black
:white
:red
:green
:blue
:yellow
:cyan
:magenta
:tft_black
:tft_white
:tft_red
{:rgb, 255, 0, 0}
{:rgb565, 0xF800}
{:rgb888, 0xFF0000}
0xF800
```

## フォント名

```text
:font0
:font2
:font4
:font6
:font7
:font8
:japan_gothic_24
:japan_mincho_24
```

日本語 Gothic / Mincho フォントは 8, 12, 16, 20, 24, 28, 32, 36, 40 も利用できます。

## Nerves での利用

通常の描画 API を使う場合:

```elixir
children = [
  {LovyanGFX.Nerves.Renderer,
   width: 800,
   height: 480,
   framebuffer: "/dev/fb0"}
]
```

MovingIcons の smoke test を動かす場合:

```elixir
children = [
  {LovyanGFX.Examples.MovingIcons.Renderer,
   width: 800,
   height: 480,
   framebuffer: "/dev/fb0"}
]
```

`MovingIcons` はあくまでデモ兼 smoke test です。新しい描画コードは `LovyanGFX.render/1` を使う前提です。
MovingIcons の overlay を更新する場合だけ、次のデモ用 API を使います。

```elixir
LovyanGFX.Examples.MovingIcons.timings()
LovyanGFX.Examples.MovingIcons.set_status("CPU 48.0C")
LovyanGFX.Examples.MovingIcons.set_touch("Touch ON")
```

## テスト

通常のテスト:

```sh
mix test
```

native smoke test:

```sh
mix test --include native
```

framebuffer が必要な smoke test:

```sh
mix test --include framebuffer
```
