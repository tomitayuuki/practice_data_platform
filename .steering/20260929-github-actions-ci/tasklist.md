# 実装タスク一覧

## 進め方について
このワークフロー自体が、本プロジェクトで初めてPRを介してマージする作業単位になる。ブランチ保護ルールで「必須のステータスチェック」として指定するには、そのチェックが最低1回は実行された実績が必要（GitHubの仕様上、実行されたことのないチェックは選択肢に出てこない）。そのため、以下の順序で進める。

1. ワークフローファイルを作成し、featureブランチにpushしてPRを作成する（この時点でブランチ保護はまだ設定しない）
2. PR上でワークフローが実際に起動し、レビュー結果が確認できることを確かめる
3. 実行実績ができた時点で、`main`のブランチ保護ルールを設定する
4. 以降のPR（このPR自身も含め、必要なら再pushして再実行させる）でブロックが機能することを確認する

## タスク

- [x] 1. `.github/workflows/claude-review.yml`を作成する
    - [x] トリガー：`pull_request`の`opened`・`synchronize`
    - [x] `actions/checkout@v4`でリポジトリをチェックアウト
    - [x] `anthropics/claude-code-action@v1`を実行するステップ（`design.md`のFAIL/PASS基準をプロンプトに含める）
    - [x] `REVIEW_RESULT`を読み取り、`FAIL`なら`exit 1`する後続ステップ
- [x] 2. Anthropic ConsoleでWorkload Identity Federationを設定する（ユーザーが実施：Service Account・Federation Ruleの作成、対象リポジトリ・`pull_request`イベントへの限定）
- [x] 3. 発行された4つのID（federation_rule_id／organization_id／service_account_id／workspace_id）をワークフローファイルに反映する（秘密情報ではないため直接記載）
- [x] 4. featureブランチ（`feature/20260929-github-actions-ci`）にpushし、PRを作成する
- [x] 5. PR上でワークフローが起動することを確認する
    - 判明した制約：`anthropics/claude-code-action`は、PR上のワークフローファイルの内容が`main`上のものと一致しない場合、セキュリティ対策として実行を意図的にスキップする（悪意あるPRがワークフロー自体を改ざんしつつ自己レビューで通過させることを防ぐ仕様）。`claude-review.yml`を初めて追加する本PRはこれに該当するため、このPRに限り自動レビューは機能しない（公式に「気にしなくてよい、マージ後から動き出す」と案内されている既知の挙動）
    - 対応方針：本PRは人（ユーザー）の手動確認でマージする。ブランチ保護ルールは、本PRのマージ後（`claude-review.yml`が`main`に存在する状態になってから）設定する
- [x] 6. 本PRを手動確認の上でsquashマージし、featureブランチを削除する
- [ ] 7. マージ後、`main`のブランチ保護ルールを設定する（`review`ジョブを必須ステータスチェックに指定）
- [ ] 8. 試験用の新しいPRを作成し、動作確認する
    - [ ] レビューがPASSの場合、マージ操作ができることを確認する
    - [ ] 意図的に問題のある差分を加えてFAILさせ、マージがブロックされることを確認する（確認後、その差分は取り除く）
- [ ] 9. 永続ドキュメント（`docs/development-standards.md`等）の記載が実態と一致しているか再確認する
