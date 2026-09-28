import Foundation

enum L {
    static func count(_ english: String, _ value: Int) -> String {
        fill(english, "\(value)")
    }

    static func fill(_ english: String, _ value: String) -> String {
        t(english).replacingOccurrences(of: "%@", with: value)
    }

    static func t(_ english: String) -> String {
        if let forced = Debug.value("LANG") {
            return forced == "ja" ? (japanese[english] ?? english) : english
        }
        guard Preferences.shared.language == .japanese
                || (Preferences.shared.language == .system && systemPrefersJapanese)
        else { return english }
        return japanese[english] ?? english
    }

    private static let checked: Bool = {
        assert(japanese.count > 0)
        return true
    }()

    private static var systemPrefersJapanese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    private static let japanese: [String: String] = [
        "Tray": "トレイ",
        "Bounce": "跳ね",
        "0 removes overshoot entirely and everything eases to a stop. Higher values let the panel and the tab switcher spring past their target before settling.": "0 で行き過ぎがなくなり、すべてが減速して止まります。上げるとパネルや切り替えバーが目標を通り過ぎてから落ち着きます。",
        "Colour from the album art": "ジャケットから色を取る",
        "The playing bars and the scrubber take their colour from the current cover. Artwork with no colour in it falls back to the standard blue.": "再生バーとシークバーの色を、再生中のジャケットから取ります。色味のないアートワークでは標準の青に戻ります。",
        "Notes": "メモ",
        "New event": "予定を追加",
        "Edit event": "予定を編集",
        "Title": "タイトル",
        "Location": "場所",
        "All day": "終日",
        "Save": "保存",
        "Delete": "削除",
        "Keep": "戻る",
        "Delete this event?": "この予定を削除しますか？",
        "Repeats": "繰り返し",
        "This calendar is read-only.": "このカレンダーは編集できません。",
        "Give the event a title": "タイトルを入力してください",
        "No writable calendar available": "書き込めるカレンダーがありません",
        "Step 1": "手順 1",
        "Step 2": "手順 2",
        "Step 3": "手順 3",
        "Register a free app on Spotify": "Spotify で無料のアプリを登録",
        "Open dashboard": "ダッシュボードを開く",
        "Copy": "コピー",
        "Copied": "コピーしました",
        "Cancel": "キャンセル",
        "Paste this as the app's Redirect URI and tick the Web API.": "これを Redirect URI に貼り付け、Web API にチェックを入れてください。",
        "Optional — only the queue needs it. Notchbase asks for the user-read-playback-state scope and nothing else; there is no client secret to store.": "任意です。次に再生される曲の表示にのみ使用します。要求する権限は user-read-playback-state だけで、クライアントシークレットは保存しません。",
        "Enter your Spotify app's Client ID first": "先に Spotify アプリの Client ID を入力してください",
        "That does not look like a Client ID — it should be 32 letters and digits": "Client ID の形式ではありません。英数字32文字です",
        "Spotify does not recognise that Client ID": "その Client ID は Spotify に登録されていません",
        "Could not reach Spotify": "Spotify に接続できませんでした",
        "Token exchange failed": "トークンの取得に失敗しました",
        "Authorization timed out": "認証がタイムアウトしました",
        "State mismatch": "状態が一致しません",
        "Malformed callback": "コールバックが不正です",
        "No authorization code in callback": "コールバックに認証コードがありません",
        "Transparency": "透明度",
        "How solid the switcher looks. Icons and labels stay readable at any setting.": "切り替えバーの濃さです。アイコンと文字はどの値でも読める明るさを保ちます。",
        "Updates": "アップデート",
        "Check for updates automatically": "自動的にアップデートを確認",
        "Download and install automatically": "自動的にダウンロードしてインストール",
        "Last checked": "最終確認",
        "Check now": "今すぐ確認",
        "Never": "未確認",
        "Updates are downloaded from the project's GitHub releases and verified before installing.": "アップデートはGitHubのリリースから取得し、署名を検証してからインストールします。",
        "Notchbase needs permission to read your events.": "予定を読み取るには許可が必要です。",
        "Allow access": "許可する",
        "Pick a preset above to start one.": "上のプリセットから開始できます。",
        "Clipboard": "クリップボード",
        "Media": "ミュージック",
        "Terminal": "ターミナル",
        "Agents": "エージェント",
        "Calendar": "カレンダー",
        "all day": "終日",
        "Resume in %@": "%@ で再開",
        "%@ item": "%@ 件",
        "%@ items": "%@ 件",
        "Send %@": "%@ 件を送信",
        "Reveal in Finder": "Finder で表示",
        "Open in Terminal": "ターミナルで開く",
        "Remove": "削除",
        "Open %@": "%@ を開く",
        "Allow Notchbase under Privacy & Security › Accessibility to paste": "ペーストするには、プライバシーとセキュリティ › アクセシビリティで Notchbase を許可してください",
        "Timer": "タイマー",
        "Stopwatch": "ストップウォッチ",
        "Presets": "プリセット",
        "Laps": "ラップ",
        "Laps appear here": "ラップがここに表示されます",
        "Lap %@": "ラップ %@",
        "Time's up": "時間です",
        "Drop files here": "ここにドロップ",
        "Release to stash": "離して保存",
        "Or drag anything to the top of the screen": "画面上端へドラッグしても開きます",
        "Clear all": "すべて消去",
        "AirDrop": "AirDrop",
        "Search": "検索",
        "Clear": "消去",
        "History is empty": "履歴がありません",
        "No matches": "一致なし",
        "Anything you copy shows up here.": "コピーしたものがここに並びます。",
        "Playing Next": "次に再生",
        "Nothing playing": "再生していません",
        "Start a track in Music or Spotify.": "ミュージックか Spotify で再生してください。",
        "Check again": "再確認",
        "Music and Spotify are not running": "ミュージックと Spotify が起動していません",
        "Open either app and playback shows up here.": "どちらかを起動すると表示されます。",
        "Automation access needed": "オートメーションの許可が必要です",
        "Open Privacy Settings": "プライバシー設定を開く",
        "Nothing queued after this track": "この曲の後の予定はありません",
        "Connect a Spotify account in Settings to see the queue": "設定で Spotify を連携するとキューが見えます",
        "Looking for lyrics…": "歌詞を検索中…",
        "Marked instrumental on LRCLIB": "LRCLIB でインスト曲として登録されています",
        "LRCLIB has no lyrics for this track": "LRCLIB にこの曲の歌詞がありません",
        "No recent agent sessions": "最近のセッションがありません",
        "Claude Code and Codex transcripts from the last three days show up here.":
            "Claude Code と Codex の直近の記録が表示されます。",
        "Open in Finder": "Finder で開く",
        "Upcoming": "今後の予定",
        "Today": "今日",
        "Nothing in the next week": "1週間先まで予定はありません",
        "Calendar access needed": "カレンダーの許可が必要です",
        "Allow Notchbase under Privacy & Security › Calendars.": "プライバシーとセキュリティ › カレンダー で許可してください。",
        "General": "一般",
        "Appearance": "外観",
        "Modules": "モジュール",
        "About": "情報",
        "Launch at login": "ログイン時に起動",
        "Language": "言語",
        "Applies to the panel and this window.": "パネルとこの画面に適用されます。",
        "Open on": "起動時のタブ",
        "The tab the panel starts on each time you open it.": "パネルを開いたときに最初に表示するタブです。",
        "Opening": "開き方",
        "Hover delay": "ホバー遅延",
        "How long the pointer rests on the notch before the panel opens. A short delay stops it firing when you reach for the menu bar.":
            "ノッチにポインタを乗せてからパネルが開くまでの時間です。メニューバーへ向かう途中で開くのを防ぎます。",
        "Tab hover delay": "タブ切替の遅延",
        "Resume window": "再開ウィンドウ",
        "Reopening within this time keeps the tab you were last on. Set to 0 to always start on the tab above.":
            "この時間以内に開き直すと直前のタブを保ちます。0 にすると常に上のタブで開きます。",
        "Activity strip": "アクティビティ表示",
        "Show when closed": "閉じているときに表示",
        "Priority": "優先表示",
        "Announce for": "通知を表示する時間",
        "How long a finished agent keeps the strip before it hands back to whatever else is showing.":
            "エージェント完了の表示を保つ時間です。経過後は他の表示に戻ります。",
        "Agent completions": "エージェントの完了",
        "Now playing": "再生中の曲",
        "Tabs": "タブ",
        "Drag to reorder. Unticked tabs are hidden from the switcher.":
            "ドラッグで並び替えできます。チェックを外すと非表示になります。",
        "Lower edge": "下端",
        "Fade into the desktop": "デスクトップへ溶け込ませる",
        "Amount": "強さ",
        "The bottom of the panel dissolves into glass so it does not end on a hard edge. Turn it off for a solid panel.":
            "パネル下端をガラスへ溶かし、硬い境界で終わらないようにします。オフにすると不透明になります。",
        "Tab switcher": "タブ切替",
        "Clear glass": "クリアガラス",
        "Clear glass lets more of the desktop through than the regular material.":
            "通常のマテリアルより背景がよく透けます。",
        "Show label on the selected tab": "選択中のタブに名前を表示",
        "Motion": "アニメーション",
        "Animation": "動きの速さ",
        "Scales every spring in the app. Snappy is roughly 30% quicker than balanced; calm is about 45% slower.":
            "アプリ全体のバネを一括で調整します。Snappy は約30%速く、Calm は約45%遅くなります。",
        "Snappy": "きびきび",
        "Balanced": "標準",
        "Calm": "ゆったり",
        "Show AirDrop zone": "AirDrop ゾーンを表示",
        "Copy dropped files into Notchbase": "ドロップしたファイルを複製して保持",
        "Files are duplicated, so moving the original does not break the tray.":
            "複製するため、元のファイルを移動してもトレイは壊れません。",
        "Only a reference is kept; moving or deleting the original removes the item.":
            "参照のみを保持します。元を移動・削除すると項目も消えます。",
        "Record history": "履歴を記録",
        "Items marked concealed or transient — password managers use these — are never recorded.":
            "パスワードマネージャなどが付ける concealed / transient 指定の項目は記録しません。",
        "Fetch lyrics from LRCLIB": "LRCLIB から歌詞を取得",
        "Lyric offset": "歌詞のずれ補正",
        "Sessions are read from Claude Code and Codex transcripts on disk. Clicking one resumes it in the terminal.":
            "Claude Code と Codex の記録から読み取ります。クリックするとターミナルで再開します。",
        "Shell": "シェル",
        "Resume in": "再開する場所",
        "Claude / Codex app": "Claude / Codex アプリ",
        "Terminal app": "ターミナル.app",
        "Notchbase terminal": "Notchbase 内蔵ターミナル",
        "Visual Studio Code": "Visual Studio Code",
        "Takes effect the next time Notchbase launches.": "次回起動時から反映されます。",
        "Spotify queue": "Spotify のキュー",
        "Connected": "接続済み",
        "Disconnect": "切断",
        "Connect": "接続",
        "Retry": "再試行",
        "Waiting for the browser…": "ブラウザの応答を待っています…",
        "Client ID": "クライアント ID",
        "Version": "バージョン",
        "Requires": "動作要件",
        "Permissions": "権限",
        "Third party": "サードパーティ",
        "Open": "開く",
        "Automation": "オートメーション",
        "Reads what Music and Spotify are playing.": "ミュージックと Spotify の再生情報を読み取ります。",
        "Shows your upcoming events.": "今後の予定を表示します。",
        "Reset all settings": "設定をすべて初期化",
        "Optional. Create a free app at developer.spotify.com/dashboard, add this redirect URI, then paste the Client ID here. Only the user-read-playback-state scope is requested.":
            "任意です。developer.spotify.com/dashboard で無料アプリを作り、下のリダイレクト URI を登録してから Client ID を貼り付けてください。要求するスコープは user-read-playback-state のみです。",
        "Keep %@ items": "%@ 件まで保持",
        "Show %@ upcoming tracks": "次の %@ 曲を表示",
        "Show the last %@ days": "直近 %@ 日分を表示",
        "macOS 15 or later": "macOS 15 以降",
        "LRCLIB — no account required": "LRCLIB — アカウント不要",
        "Simple Icons (CC0); trademarks belong to their owners": "Simple Icons (CC0)。商標は各社に帰属します",
        "Lyrics": "歌詞",
        "Icons": "アイコン",
        "Notchbase is not sandboxed and is signed ad-hoc by default. macOS ties these grants to the code signature, so they reset on every rebuild unless you sign with a stable development certificate.":
            "Notchbase はサンドボックス外で、既定ではアドホック署名です。macOS はこれらの許可をコード署名に紐づけるため、安定した開発証明書で署名しない限りリビルドのたびにリセットされます。",
    ]
}
