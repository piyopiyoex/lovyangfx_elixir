# 0001: device 固有の framebuffer 差分を opt-in capability として扱う

## 状態

採用

## 背景

`lovyangfx_elixir` は Linux framebuffer 上の LovyanGFX を Elixir から利用するための wrapper であり、
既存 consumer では `LovyanGFX.start/1` と `LovyanGFX.render/1` を中心とした API を利用している。

一方、SHARP Brain PW-SH6 では、既存の `Panel_fb` による直接描画ではなく、次の経路で安定して描画できることを
`nerves_system_brain/examples/hello_kiosk` で確認している。

```text
Elixir
  -> render commands
  -> offscreen LGFX_Sprite (854x480 / RGB565)
  -> frame complete
  -> mmap(/dev/fb0)
  -> framebuffer stride を考慮して copy
  -> RGB565 byte swap
  -> framebuffer
```

この実装を KIOSK 側に持ち続けると、LovyanGFX の NIF、command interpreter、font、build 設定などが
`lovyangfx_elixir` と重複する。

ただし `lovyangfx_elixir` は Brain 専用 package ではなく、既存 consumer の public API と default behavior を
Brain 対応のために変更することも避けたい。

## 決定

SHARP Brain を含む device 固有の framebuffer 差分は、drawing command API ではなく
**native presentation behavior の opt-in capability** として `lovyangfx_elixir` に実装する。

具体的には次の方針とする。

- `LovyanGFX.start/1`、`LovyanGFX.render/1`、既存 command tuple の意味を維持する。
- option を追加しない既存呼び出しでは、現在の framebuffer behavior を維持する。
- offscreen full-frame rendering、stride-aware copy、RGB565 byte swap などが必要な環境だけ、新しい display option で opt-in する。
- Brain 固有 command は追加せず、既存 command interpreter は display presentation method から独立させる。
- buffered mode では一連の command を offscreen target に描画し、frame 完成後に framebuffer へ present する。
- framebuffer path、画面サイズ、byte swap の有無などは configuration として渡し、Brain という board 名を drawing API に埋め込まない。
- device driver の読み込み、`/dev/fb0` の出現待ち、framebuffer console の切り離し、input、power 管理などの board bring-up は consumer 側の責務とする。

API は例えば次のような形を想定する。

```elixir
LovyanGFX.start(
  width: 854,
  height: 480,
  framebuffer: "/dev/fb0",
  framebuffer_mode: :buffered_rgb565,
  swap_bytes: true
)
```

option 名や native 内部構造は実装時に調整できるが、次の compatibility rule は維持する。

> 新しい framebuffer capability を opt-in しなければ、既存 behavior は変わらない。

## 理由

- Brain KIOSK にある LovyanGFX native implementation を package 側へ集約できる。
- drawing command と hardware-specific presentation を分離できるため、既存 Elixir API に Brain 固有知識を持ち込まずに済む。
- default behavior を維持することで、既存 consumer への影響を最小化できる。
- framebuffer の stride や byte order のような差異は描画 primitive の差ではなく、完成した frame を表示する方法の差として扱う方が責務が明確になる。
- 将来、同様に offscreen presentation を必要とする Linux framebuffer device が増えた場合にも再利用できる。

## 影響

- native layer は direct framebuffer path に加えて buffered presentation path を持つ。
- display option の validation / normalization を拡張する必要がある。
- buffered mode では framebuffer と同サイズの offscreen buffer を保持するため、direct path より memory を使用する。
- `render/1` は public API を変えず、buffered mode では command 実行後の frame presentation までを1回の render として扱う。
- Brain では 854x480 / RGB565、framebuffer stride、byte swap、full-frame update を package 側で扱えるようになる。
- `hello_kiosk` は高レベルな UI / state machine を維持したまま、独自 LovyanGFX NIF と command interpreter を削除できる。
- package-level compatibility tests で既存 API / default option を固定する。
- Brain 対応時の実機検証対象は PW-SH6 とし、他 hardware の実機 regression test は必須とはしない。

## 再評価条件

- LovyanGFX upstream の Linux framebuffer support だけで、PW-SH6 の stride / byte order を追加処理なしに正しく扱えるようになった場合。
- buffered RGB565 以外にも複数の presentation strategy が必要になり、単純な option 分岐では native layer の責務が不明瞭になった場合。
- Linux framebuffer 以外の display backend を同じ package で扱う必要が生じた場合。
- existing default behavior を維持することが技術的に難しく、semver major change として API を再設計する方が妥当になった場合。
