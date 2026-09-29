# 基本設計書（作業単位）

## 概要
`anthropics/claude-code-action@v1`（公式のGitHub Actions用アクション）を使い、PR上でのコードレビューと、その結果に基づくマージブロックを実現する。

Anthropicが提供する管理型の「Code Review」機能（Team/Enterpriseプラン限定・マージを強制ブロックしない仕様）は、本プロジェクトの要件（個人プランで利用可能、レビュー未通過ならマージ不可）を満たさないため採用しない。

## 全体の流れ

```mermaid
flowchart LR
    A[featureにpush] --> B[PR作成・更新]
    B --> C[GitHub Actions起動]
    C --> D[claude-code-actionでレビュー実行]
    D --> E[レビュー結果にREVIEW_RESULT: PASS/FAILを出力]
    E --> F{判定結果は？}
    F -->|PASS| H[ジョブ成功]
    F -->|FAIL| G[ジョブを失敗させる]
    H --> J[mainへマージ可能]
    G --> I[ブランチ保護によりmainへマージ不可]
```

## 構成要素

### ワークフローファイル
`.github/workflows/claude-review.yml`として作成する。

- トリガー：`pull_request`の`opened`・`synchronize`（PR作成時、および追加push時）
- ジョブ内容：
    1. リポジトリをチェックアウトする
    2. `anthropics/claude-code-action@v1`を実行し、差分に対するコードレビューを行わせる。プロンプトで以下を指示する
        - **FAILとする基準**：正しさに関わるバグ（correctness bug）、セキュリティ上の重大な問題など、実害につながる指摘がある場合
        - **PASSとする基準**：スタイル・命名・将来的な改善提案など軽微な指摘のみの場合（指摘自体はコメントとして残すが、マージはブロックしない）
        - 末尾に`REVIEW_RESULT: PASS`または`REVIEW_RESULT: FAIL`を出力する
    3. 後続のステップで、Claudeの出力から`REVIEW_RESULT`を読み取る
    4. `FAIL`であれば、そのステップで`exit 1`しジョブ全体を失敗させる（→ブランチ保護によりマージ不可になる）
    5. `PASS`であれば、そのステップは何もせず正常終了する。ジョブ全体が成功として記録され、PR画面のチェックが緑になり、ブランチ保護の条件を満たす状態になる。ただし、この時点で自動的にマージされるわけではなく、「Merge」ボタンを押す操作自体は引き続き人が行う

### 認証情報
- Anthropicの直接APIキーではなく、**Workload Identity Federation（WIF）**を使用する。GitHub ActionsのOIDCトークンを、その場限りの短期間だけ有効なAnthropicアクセストークンに交換する仕組みで、長期間有効な秘密情報（APIキー）をリポジトリ・GitHub Secretsのどちらにも保存しない
- Anthropic ConsoleでService Account・Federation Ruleを作成し、対象リポジトリ・`pull_request`イベントに限定する
- ワークフロー側には`anthropic_federation_rule_id`／`anthropic_organization_id`／`anthropic_service_account_id`／`anthropic_workspace_id`の4つのIDを指定する。これらは識別子であり秘密情報ではないため、ワークフローファイルに直接記載してよい
- ワークフローに`id-token: write`権限を付与する（GitHubのOIDCトークン取得に必須）

### ブランチ保護ルール
`main`ブランチに対して、GitHubリポジトリのSettings → Branchesから設定する。

- 「Require status checks to pass before merging」を有効化
- 上記ワークフローのジョブを必須ステータスチェックとして指定する

## 前提条件
- Anthropic ConsoleでWorkload Identity Federationの設定（Service Account・Federation Ruleの作成）ができること

## 未確定事項
- `claude-code-action@v1`が、実行結果を後続ステップから直接参照できる形（例：`steps.<id>.outputs.*`）で提供しているかは、実装時に公式ドキュメント・実際の挙動で確認する。提供されていない場合は、出力ログをファイルに書き出して`grep`する等の代替手段を取る
