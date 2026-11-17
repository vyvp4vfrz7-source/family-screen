import Foundation

/// Languages the screen can show and speak. The family picks one per iPad.
enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case english = "en"
    case cantonese = "yue"
    case mandarin = "zh"
    case hindi = "hi"
    case polish = "pl"

    var id: String { rawValue }

    /// Name shown in the picker, in the language itself.
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .cantonese: return "廣東話（繁體）"
        case .mandarin: return "普通话（简体）"
        case .hindi: return "हिन्दी"
        case .polish: return "Polski"
        }
    }

    /// Voice used by the iPad's built-in speech.
    var voiceCode: String {
        switch self {
        case .english: return "en-GB"
        case .cantonese: return "zh-HK"
        case .mandarin: return "zh-CN"
        case .hindi: return "hi-IN"
        case .polish: return "pl-PL"
        }
    }

    /// Locale for dates and numbers.
    var locale: Locale {
        switch self {
        case .english: return Locale(identifier: "en_GB")
        case .cantonese: return Locale(identifier: "zh_Hant_HK")
        case .mandarin: return Locale(identifier: "zh_Hans_CN")
        case .hindi: return Locale(identifier: "hi_IN")
        case .polish: return Locale(identifier: "pl_PL")
        }
    }
}

/// All on-screen and spoken text. Add a language by adding a column.
enum L: String {
    case addPhoto, addNote, send, cancel, done, settings, messages, typeMessage, gotIt
    case calendar, noEvents, allDay, today, tomorrow, news, noFeeds, call, callNotSet
    case thisHome, homeName, language, cities, cityA, cityB, find, notFound
    case faceTime, contactName, contactAddress, audioOnly, nightHours, nightFrom, nightTo
    case voice, hourlyChime, readMessages, readNow, feeds, addFeed, feedURL
    case familySync, inviteHome, syncOff, slideshow, seconds, newMessageFrom, newPhotoFrom
    case itIs, degrees, calendarDenied, noPhotos, delete, photoNote

    private static let table: [L: [AppLanguage: String]] = [
        .addPhoto: [.english: "Add photo", .cantonese: "加相", .mandarin: "添加照片", .hindi: "फ़ोटो जोड़ें", .polish: "Dodaj zdjęcie"],
        .addNote: [.english: "Add a note…", .cantonese: "寫句說話…", .mandarin: "写一句话…", .hindi: "एक नोट लिखें…", .polish: "Dodaj notatkę…"],
        .send: [.english: "Send", .cantonese: "傳送", .mandarin: "发送", .hindi: "भेजें", .polish: "Wyślij"],
        .cancel: [.english: "Cancel", .cantonese: "取消", .mandarin: "取消", .hindi: "रद्द करें", .polish: "Anuluj"],
        .done: [.english: "Done", .cantonese: "完成", .mandarin: "完成", .hindi: "हो गया", .polish: "Gotowe"],
        .settings: [.english: "Settings", .cantonese: "設定", .mandarin: "设置", .hindi: "सेटिंग्स", .polish: "Ustawienia"],
        .messages: [.english: "Message board", .cantonese: "留言板", .mandarin: "留言板", .hindi: "संदेश बोर्ड", .polish: "Tablica wiadomości"],
        .typeMessage: [.english: "Write a message…", .cantonese: "留個言…", .mandarin: "留个言…", .hindi: "संदेश लिखें…", .polish: "Napisz wiadomość…"],
        .gotIt: [.english: "❤️ Got it", .cantonese: "❤️ 收到", .mandarin: "❤️ 收到", .hindi: "❤️ मिल गया", .polish: "❤️ Mam"],
        .calendar: [.english: "Coming up", .cantonese: "日程", .mandarin: "日程", .hindi: "आगे क्या है", .polish: "Wkrótce"],
        .noEvents: [.english: "Nothing planned this week", .cantonese: "今個星期冇安排", .mandarin: "本周没有安排", .hindi: "इस हफ़्ते कुछ नहीं", .polish: "Nic w tym tygodniu"],
        .allDay: [.english: "All day", .cantonese: "全日", .mandarin: "全天", .hindi: "पूरा दिन", .polish: "Cały dzień"],
        .today: [.english: "Today", .cantonese: "今日", .mandarin: "今天", .hindi: "आज", .polish: "Dziś"],
        .tomorrow: [.english: "Tomorrow", .cantonese: "聽日", .mandarin: "明天", .hindi: "कल", .polish: "Jutro"],
        .news: [.english: "News", .cantonese: "新聞", .mandarin: "新闻", .hindi: "समाचार", .polish: "Wiadomości"],
        .noFeeds: [.english: "Add news feeds in Settings", .cantonese: "喺設定加新聞來源", .mandarin: "在设置中添加新闻源", .hindi: "सेटिंग्स में समाचार फ़ीड जोड़ें", .polish: "Dodaj kanały w Ustawieniach"],
        .call: [.english: "Call", .cantonese: "打畀", .mandarin: "打给", .hindi: "कॉल करें", .polish: "Zadzwoń do"],
        .callNotSet: [.english: "Set who to call in Settings", .cantonese: "喺設定揀打畀邊個", .mandarin: "在设置中选择联系人", .hindi: "सेटिंग्स में चुनें किसे कॉल करना है", .polish: "Wybierz osobę w Ustawieniach"],
        .thisHome: [.english: "This home", .cantonese: "呢個屋企", .mandarin: "这个家", .hindi: "यह घर", .polish: "Ten dom"],
        .homeName: [.english: "Home name (e.g. Grandma's)", .cantonese: "屋企名（例如：嫲嫲屋企）", .mandarin: "家的名字（例如：奶奶家）", .hindi: "घर का नाम (जैसे दादी का घर)", .polish: "Nazwa domu (np. U babci)"],
        .language: [.english: "Language and voice", .cantonese: "語言同聲音", .mandarin: "语言和语音", .hindi: "भाषा और आवाज़", .polish: "Język i głos"],
        .cities: [.english: "Two cities", .cantonese: "兩個城市", .mandarin: "两个城市", .hindi: "दो शहर", .polish: "Dwa miasta"],
        .cityA: [.english: "First city", .cantonese: "第一個城市", .mandarin: "第一个城市", .hindi: "पहला शहर", .polish: "Pierwsze miasto"],
        .cityB: [.english: "Second city", .cantonese: "第二個城市", .mandarin: "第二个城市", .hindi: "दूसरा शहर", .polish: "Drugie miasto"],
        .find: [.english: "Find", .cantonese: "搵", .mandarin: "查找", .hindi: "खोजें", .polish: "Szukaj"],
        .notFound: [.english: "Not found", .cantonese: "搵唔到", .mandarin: "找不到", .hindi: "नहीं मिला", .polish: "Nie znaleziono"],
        .faceTime: [.english: "FaceTime button", .cantonese: "FaceTime 掣", .mandarin: "FaceTime 按钮", .hindi: "FaceTime बटन", .polish: "Przycisk FaceTime"],
        .contactName: [.english: "Name on the button", .cantonese: "掣上面嘅名", .mandarin: "按钮上的名字", .hindi: "बटन पर नाम", .polish: "Imię na przycisku"],
        .contactAddress: [.english: "Phone number or Apple ID email", .cantonese: "電話號碼或 Apple ID 電郵", .mandarin: "电话号码或 Apple ID 邮箱", .hindi: "फ़ोन नंबर या Apple ID ईमेल", .polish: "Numer telefonu lub e-mail Apple ID"],
        .audioOnly: [.english: "Audio only", .cantonese: "只用語音", .mandarin: "仅语音", .hindi: "केवल ऑडियो", .polish: "Tylko dźwięk"],
        .nightHours: [.english: "Night clock", .cantonese: "夜間時鐘", .mandarin: "夜间时钟", .hindi: "रात की घड़ी", .polish: "Zegar nocny"],
        .nightFrom: [.english: "From", .cantonese: "由", .mandarin: "从", .hindi: "से", .polish: "Od"],
        .nightTo: [.english: "Until", .cantonese: "到", .mandarin: "到", .hindi: "तक", .polish: "Do"],
        .voice: [.english: "Voice", .cantonese: "聲音", .mandarin: "语音", .hindi: "आवाज़", .polish: "Głos"],
        .hourlyChime: [.english: "Say the time every hour", .cantonese: "每個鐘報時", .mandarin: "每小时报时", .hindi: "हर घंटे समय बताएँ", .polish: "Podawaj godzinę co godzinę"],
        .readMessages: [.english: "Read new messages aloud", .cantonese: "讀出新留言", .mandarin: "朗读新留言", .hindi: "नए संदेश पढ़कर सुनाएँ", .polish: "Czytaj nowe wiadomości"],
        .readNow: [.english: "Read time and weather", .cantonese: "讀出時間同天氣", .mandarin: "朗读时间和天气", .hindi: "समय और मौसम सुनाएँ", .polish: "Przeczytaj godzinę i pogodę"],
        .feeds: [.english: "News feeds (RSS)", .cantonese: "新聞來源（RSS）", .mandarin: "新闻源（RSS）", .hindi: "समाचार फ़ीड (RSS)", .polish: "Kanały wiadomości (RSS)"],
        .addFeed: [.english: "Add feed", .cantonese: "加來源", .mandarin: "添加", .hindi: "फ़ीड जोड़ें", .polish: "Dodaj kanał"],
        .feedURL: [.english: "Feed address (https://…)", .cantonese: "來源網址（https://…）", .mandarin: "源地址（https://…）", .hindi: "फ़ीड पता (https://…)", .polish: "Adres kanału (https://…)"],
        .familySync: [.english: "Link the two homes", .cantonese: "連接兩個屋企", .mandarin: "连接两个家", .hindi: "दोनों घरों को जोड़ें", .polish: "Połącz dwa domy"],
        .inviteHome: [.english: "Invite the other home", .cantonese: "邀請另一個屋企", .mandarin: "邀请另一个家", .hindi: "दूसरे घर को आमंत्रित करें", .polish: "Zaproś drugi dom"],
        .syncOff: [.english: "Linking homes turns on once the app is signed with a paid Apple Developer account.", .cantonese: "用付費 Apple 開發者帳戶簽署之後，就可以連接兩個屋企。", .mandarin: "使用付费 Apple 开发者账户签名后即可连接两个家。", .hindi: "ऐप को पेड Apple डेवलपर खाते से साइन करने के बाद घर जुड़ेंगे।", .polish: "Łączenie domów działa po podpisaniu aplikacji płatnym kontem Apple Developer."],
        .slideshow: [.english: "Photo slideshow", .cantonese: "相片輪播", .mandarin: "照片轮播", .hindi: "फ़ोटो स्लाइडशो", .polish: "Pokaz zdjęć"],
        .seconds: [.english: "seconds", .cantonese: "秒", .mandarin: "秒", .hindi: "सेकंड", .polish: "s"],
        .newMessageFrom: [.english: "New message from", .cantonese: "新留言，來自", .mandarin: "新留言，来自", .hindi: "नया संदेश, भेजने वाले", .polish: "Nowa wiadomość od"],
        .newPhotoFrom: [.english: "New photo from", .cantonese: "新相片，來自", .mandarin: "新照片，来自", .hindi: "नई फ़ोटो, भेजने वाले", .polish: "Nowe zdjęcie od"],
        .itIs: [.english: "It is", .cantonese: "而家係", .mandarin: "现在是", .hindi: "अभी समय है", .polish: "Jest"],
        .degrees: [.english: "degrees", .cantonese: "度", .mandarin: "度", .hindi: "डिग्री", .polish: "stopni"],
        .calendarDenied: [.english: "Allow calendar access in Settings", .cantonese: "請喺設定允許使用日曆", .mandarin: "请在设置中允许访问日历", .hindi: "सेटिंग्स में कैलेंडर की अनुमति दें", .polish: "Zezwól na dostęp do kalendarza"],
        .noPhotos: [.english: "Tap + to add the first family photo", .cantonese: "撳 + 加第一張相", .mandarin: "点 + 添加第一张照片", .hindi: "पहली फ़ोटो जोड़ने के लिए + दबाएँ", .polish: "Stuknij +, aby dodać pierwsze zdjęcie"],
        .delete: [.english: "Delete", .cantonese: "刪除", .mandarin: "删除", .hindi: "हटाएँ", .polish: "Usuń"],
        .photoNote: [.english: "Note with the photo", .cantonese: "相片留言", .mandarin: "照片留言", .hindi: "फ़ोटो के साथ नोट", .polish: "Notatka do zdjęcia"],
    ]

    func text(_ lang: AppLanguage) -> String {
        L.table[self]?[lang] ?? L.table[self]?[.english] ?? rawValue
    }
}
