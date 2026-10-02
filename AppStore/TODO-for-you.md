# App Store 公開までに、あなたがすること

上から順に進めてください。☐ は未着手です。
Claude が用意したもの: アプリ本体、アプリ内課金(広告を消す)、広告の組み込み(テスト ID)、アイコン、スクリーンショット(`AppStore/screenshots/`、6.9 インチ 1320×2868)、掲載文(`AppStore/listing-ja.md`)、プライバシーポリシーの下書き(`docs/privacy-policy.md`)、AdMob の手順書(`docs/ads-setup.md`)。

氏名・住所・電話・メール・口座・税の情報は、リポジトリに書かない。Apple / Google の画面には、あなた自身が入力する。

## 0. 先に決めること
- ☐ **アプリ名**(仮: のこりメモ)。他のアプリと重複すると使えない。手順 4 で分かる。決めたら Claude に伝える(表示名と Bundle ID を合わせる)。
- ☐ **公開名義**(アプリの提供者として表示される名前)。数独ヘルパーと同じでよいか。
- ☐ **配信地域**: 日本だけにすると、広告の同意管理(UMP)の実装が要らず、簡単。
- ☐ **「広告を消す」の価格**: ¥160 で仮置き。¥160〜¥300 で検討。

## 1. AdMob(広告)
- ☐ `docs/ads-setup.md` の手順で、アカウント作成 → アプリ追加 → バナーの広告ユニット作成。
- ☐ **アプリ ID と広告ユニット ID を Claude に伝える**(差し替えは Claude がする)。
- 差し替えるまで、Release ビルド(App Store 用)は**広告が出ない**。テスト広告のまま公開されることはない。

## 2. プライバシーポリシーを公開する(URL が必須)
- ☐ `docs/privacy-policy.md` の `〔 〕` を埋める(提供者名、問い合わせ先、日付)。日本語・英語の両方。
- ☐ 公開する場所を決める(数独ヘルパーと同じ GitHub Pages なら、このアプリ用のリポジトリを作る)。公開後、URL が開けることを確認する。
- ☐ 公開した URL を、`App/SettingsView.swift` の `AppLinks.privacyPolicy` に入れる(Claude に伝えれば入れる)。

## 3. Xcode の署名
- ☐ Signing & Capabilities で、Team に有料の開発者チームを選ぶ(Team ID は数独ヘルパーと同じ)。
- ☐ Bundle Identifier が `com.taiki.StockNote` になっていることを確認する(アプリ名を変えたら合わせる)。
- 注意: 署名のチーム設定は `project.pbxproj` に入る。公開リポジトリに載せたくないなら、数独ヘルパーと同じく、その変更はコミットしない。

## 4. App Store Connect でアプリを作る
https://appstoreconnect.apple.com → マイApp →「+」→ 新規App
- ☐ プラットフォーム: iOS / プライマリ言語: 日本語
- ☐ 名前、バンドル ID、SKU(自由な英数字。あとで変えられない)

## 5. アプリ内課金「広告を消す」を登録する
- ☐ 「収益化」→「アプリ内課金」→ 非消耗型。製品 ID は必ず **`com.taiki.StockNote.removeads`**(コードと同じ)。
- ☐ 価格、表示名、説明、審査用スクリーンショット(`AppStore/screenshots/05-settings.png`)。詳細は `AppStore/listing-ja.md`。
- ☐ アプリの初回審査に、このアプリ内課金を含めて提出する。

## 6. アプリの情報を入力する(`AppStore/listing-ja.md` を貼る)
- ☐ 説明文、キーワード、サブタイトル、プロモーションテキスト、URL、著作権。
- ☐ スクリーンショット: `AppStore/screenshots/` の 5 枚(6.9 インチ)。
- ☐ 年齢制限の質問票 → すべて「なし」。
- ☐ **App のプライバシー**: 「データを収集しない」は選べない(広告 SDK があるため)。`docs/ads-setup.md` の該当欄の通り、Google の最新ガイドを見て回答する。
- ☐ 価格と配信状況: 無料。配信地域。
- ☐ 審査メモ: `AppStore/listing-ja.md` の文を貼る。

## 7. ビルドを提出する
- ☐ Xcode の Product → Archive → Distribute App → App Store Connect。
- ☐ ビルドを選び、「審査に提出」。

## 8. 提出前の最終確認(実機で)
- ☐ 実機で 1 週間ほど使い、記録の手間(何タップか)と、通知が届くことを確認する。
- ☐ 本番の広告 ID を入れたあと、**自分の広告をタップしない**(無効なクリックで AdMob のアカウントが止められることがある)。
- ☐ 「広告を消す」の購入と復元を、サンドボックスのテスターで確認する(App Store Connect → ユーザーとアクセス → サンドボックス)。
