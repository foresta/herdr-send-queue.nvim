# herdr-send-queue.nvim

Neovim から [herdr](https://herdr.dev/) 上のコーディングエージェント（Claude Code 等）へ、
**レビューコメントをキューに溜めて一括送信**するプラグイン。

`auto` モードでエージェントに書かせたコードを vim-fugitive で diff レビューし、
気になった行にコメントを積み、まとめて1つのプロンプトとしてエージェントへ流す、という運用を想定している。

## コンセプト

- **汎用コア + レビュー preset** の2層構成
  - 汎用: `nvim → queue → herdr` で任意の pane/agent にテキストを送る transport
  - 旗艦機能: 行アンカー付きレビューコメントの queue と一括 flush
- エージェントへの送信は herdr の端末入力注入（`herdr agent prompt`）を使う。
  本プラグインは Anthropic API にも pty にも直接触らない。

## ステータス

設計フェーズ。背景・アーキテクチャ・設計判断は [`docs/`](./docs) を参照。

## ライセンス

[MIT](./LICENSE)
