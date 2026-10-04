# 要件定義書（作業単位）

> **暫定版**：作業単位ドキュメントの様式（記載ルール）が未整備の状態で作成した。様式の整備（`docs/backlog.md` 023）にあたっては、本書を「正解の手本」ではなく比較材料の1つとして扱う。

## 目的
`docs/architecture.md`のデータフローのうち、まだ構築していない「dbtによる`RAW`から`ANALYTICS`（staging・marts）への変換」を構築する。これにより、`docs/requirements.md`の成功指標である「カテゴリ別の月次支出推移を折れ線グラフで確認できる状態」を、Snowsightでグラフを作るだけで達成できるデータを用意する。

本作業は本プロジェクトで初めてdbtを用いる作業単位であるため、dbtの導入（Python仮想環境を含む）とプロジェクトの初期設定も合わせて行う。

## スコープ

### 対象
- Python仮想環境（venv）の作成と、dbt（`dbt-snowflake`）の導入。導入するパッケージは`requirements.txt`でバージョンを固定する
- dbtプロジェクト（`dbt/`）の初期設定。`target`（`dev`／`prod`）の切り替えで、参照する`RAW_*`と書き込む`ANALYTICS_*`の組み合わせが丸ごと切り替わるようにする（`docs/architecture.md`の環境分離方針に準拠）
- `sources.yml`の作成（`RAW_*.MONEYFORWARD.TRANSACTIONS`の定義）
- stagingモデル`stg_moneyforward__transactions`の作成
- martsモデル`mart_transactions`の作成
- 上記に対するdbtテストの定義
- PRODへの初回リリースの手順書の作成（リリース作業自体はユーザーが手順書に沿って実施する）

### 対象外
- Snowsightでのグラフ（ダッシュボード）の作成（本作業の成果物を使って別途行う）
- 月次×カテゴリ別等の集計テーブルの作成（`docs/development-standards.md`2章のとおり、集計はBIツール側で行う）
- CDによるリリースの自動化（本作業の手動リリース手順をもとに、別の作業単位で対応する。`docs/backlog.md` 022）
- PROD環境（`RAW_PROD`／`ANALYTICS_PROD`）への書き込み・操作全般（実データの取り込みを含む。`CLAUDE.md`のデータ取扱いの原則に準拠し、ユーザーが実施する）

## 前提となるデータ仕様
ユーザーへの確認により判明した、マネーフォワードCSVの仕様。列単位の仕様は、実装時に`sources.yml`の各列の`description`に記載する（`docs/interfaces.md`の方針に準拠）。

- `金額（円）`：収入は正、支出は負の値で出力される。返金は正の値で、元の支出と同じ大項目（例：食費）に分類される
- `計算対象`：その取引をマネーフォワード上の収支の集計に含めるかどうかのフラグ（`1`：含める、`0`：含めない）。口座間の振替や、NISAの積立のような資産の総額が増減しない取引は`0`となる。また、マネーフォワードのアプリ上でユーザーが手動で計算対象外にすることもできる
- 振替の実際の出力形式は未確認（`docs/backlog.md` 021）。`計算対象=0`であるため、本作業の収支の判定には影響しない

## 要件

### dbt実行環境
- dbtが、リポジトリ直下のPython仮想環境（`.venv/`）にのみ導入されていること（PC全体のPython環境には導入しない）
- `requirements.txt`から、同じバージョンのdbtを再現して導入できること
- `target: dev`で実行した場合、`RAW_DEV`のみを参照し、`ANALYTICS_DEV`のみに書き込むこと。`target: prod`の場合は`RAW_PROD`／`ANALYTICS_PROD`の組み合わせとなること（環境を跨いだ参照をしない）
- Snowflakeへの接続に用いる認証情報（秘密鍵等）がリポジトリ・Gitの管理対象に含まれないこと

### staging（`stg_moneyforward__transactions`）
- `RAW`の取引テーブルと1対1で対応し、`docs/development-standards.md`2章のとおり最低限のクレンジングのみを行う（収入・支出の判定等のビジネスロジックは含めない）
- 取引の一意キー（元のCSVの`ID`）を`transaction_id`として持ち、重複・欠損がないこと

### marts（`mart_transactions`）
- 1行＝1取引の明細の粒度とし、`RAW`の全行（収入・支出・計算対象外のすべて）を含むこと
- 各取引を、以下のルールで「収入」「支出」「対象外」のいずれかに区分する列を持つこと
    - `計算対象=0`の取引は「対象外」
    - それ以外で、大項目が「収入」の取引は「収入」
    - それ以外の取引は「支出」（返金も、元の支出と同じ大項目で「支出」として扱う）
- 金額を以下の2通りで持つこと
    - グラフ用の金額：収入・支出とも正の値に揃えた金額。返金は支出の負の値となり、同じカテゴリの支出から差し引かれる
    - 元の符号のままの金額：合計すれば収支（収入－支出）になる
- Snowsightで、区分＝支出に絞り込み、取引日の月×大項目でグラフ用の金額を合計するだけで、カテゴリ別の月次支出推移が得られること

### テスト
- `docs/development-standards.md`3.2に従い、主キー（`transaction_id`）に`not_null`・`unique`のテストを、source・staging・martsのそれぞれで設定する
- 収入・支出・対象外の区分が上記のルールどおりになっていることを検証できること
- テストは`sample_data/`のダミーデータを取り込んだ`RAW_DEV`に対して実施する

### リリース
- PRODへの初回リリースに必要な作業（実データのPRODへの取り込み、`dbt run --target prod`、`dbt test --target prod`、結果の確認等）を、上から順に実施すれば完了する手順書として`.steering/20261004-dbt-modeling/release.md`にまとめること
- 手順書はユーザーが事前にレビューし、ユーザー自身が手順書に沿って実施する

### 永続ドキュメントの更新
- `docs/development-standards.md`に、Python実行環境のルール（venvの利用、`requirements.txt`によるバージョン固定と管理、環境の作成手順）を追加する
- `docs/repository-structure.md`に、`requirements.txt`・`.venv/`の扱いを追記する
- `docs/interfaces.md`の「列定義の詳細」の参照先（`sources.yml`）を、実際のファイルパスに更新する
- `docs/backlog.md`に、CDによるリリース自動化（022）・作業単位ドキュメントの様式整備（023）の課題を起票する（起票済み）

## 受け入れ基準
- `sample_data/`のダミーCSVを取り込んだ`RAW_DEV`に対して`dbt run`・`dbt test`（`target: dev`）が成功すること
- `ANALYTICS_DEV`の`mart_transactions`で、ダミーデータの各行が想定どおりの区分・金額になっていること（例：給与は収入、返金は支出の負の金額、振替は対象外）
- リリース手順書がユーザーのレビューで承認されていること
