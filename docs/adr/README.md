# アーキテクチャ決定記録

`lovyangfx_elixir` の長期的な設計判断を ADR (Architecture Decision Record) として記録する。

実装手順や一時的な調査メモではなく、public API、native layer、platform-specific behavior など、
将来の変更時にも前提として参照したい判断を対象とする。

## 決定マップ

| 番号 | 問い | 現在の判断 |
|---|---|---|
| [0001](0001-device固有のframebuffer差分をopt-in-capabilityとして扱う.md) | device 固有の framebuffer 差分をどこで扱うか | public drawing API を維持し、native presentation の opt-in capability として扱う |

## ADR の書き方

ADR は4桁の連番を付け、原則として次の構成で記述する。

```markdown
# NNNN: タイトル

## 状態

採用

## 背景

## 決定

## 理由

## 影響

## 再評価条件
```

採用済みの判断を変更する場合は既存 ADR を履歴として残し、新しい ADR から置き換える判断を明記する。
