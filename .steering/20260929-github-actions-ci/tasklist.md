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
- [x] 2. ~~Anthropic ConsoleでWorkload Identity Federationを設定する~~ → WIFは実装途中で断念（design.md参照）。Anthropic ConsoleでAPIキーを発行し、GitHub Secretsに`ANTHROPIC_API_KEY`として登録する方式に変更（ユーザーが実施）
- [x] 3. ~~発行された4つのIDをワークフローファイルに反映する~~ → ワークフローを`anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}`に書き換える
- [x] 4. featureブランチ（`feature/20260929-github-actions-ci`）にpushし、PRを作成する
- [x] 5. PR上でワークフローが起動することを確認する
    - 判明した制約：`anthropics/claude-code-action`は、PR上のワークフローファイルの内容が`main`上のものと一致しない場合、セキュリティ対策として実行を意図的にスキップする（悪意あるPRがワークフロー自体を改ざんしつつ自己レビューで通過させることを防ぐ仕様）。`claude-review.yml`を初めて追加する本PRはこれに該当するため、このPRに限り自動レビューは機能しない（公式に「気にしなくてよい、マージ後から動き出す」と案内されている既知の挙動）
    - 対応方針：本PRは人（ユーザー）の手動確認でマージする。ブランチ保護ルールは、本PRのマージ後（`claude-review.yml`が`main`に存在する状態になってから）設定する
- [x] 6. 本PRを手動確認の上でsquashマージし、featureブランチを削除する
- [x] 7. マージ後、`main`にRulesetsでブランチ保護を設定する（`review`ジョブを必須ステータスチェックに指定。Bypass listに「Repository admin」を追加）
- [x] 8. 試験用PR（#2）で動作確認を試みたところ、WIFの認証エラー（GitHubの仕様変更によるsubject claim不一致）に遭遇。原因調査を進めたが、実績のある方式を優先する判断でAPIキー方式に切り替えることにした
- [x] 9. ワークフローをAPIキー方式に書き換え、PRを作成（#4）・Bypassマージ
    - 判明した追加の問題：①`id-token: write`をWIF専用と誤認して削除していた（Anthropic認証方式に関係なく、GitHub App用トークン取得に必須と判明、PR #4で復元）。②発行したAPIキーが「組織」スコープで、ワークスペーススコープでないと認証エラーになることが判明（「デフォルトワークスペース」でキーを再発行）。③認証成功後も、Claudeがファイル書き込み・`gh pr comment`実行のたびに人間の承認待ちでブロックされることが判明（非対話のCI環境には承認者がいないため常に失敗）。`claude_args`で`--allowedTools Write,Bash`を指定し解決（PR #5, #6でそれぞれ対応・Bypassマージ）
- [x] 10. 試験用PR（#2）を最新mainに同期し、動作確認を完了
    - [x] レビューがPASSの場合、マージ操作ができることを確認した（`mergeStateStatus`が通常状態になることを確認）
    - [x] 意図的なバグ（`ci_test_bug.py`、税込み計算で減算している）を含めてFAILさせ、`mergeStateStatus: BLOCKED`になることを確認。確認後バグファイルを削除し、PR #2はマージせずクローズ・ブランチ削除
- [x] 11. 永続ドキュメント（`docs/development-standards.md`）に、CIワークフロー自体を変更するPRの既知の例外（自己スキップ・Bypassでの手動マージ）を追記し、実態と一致させた
