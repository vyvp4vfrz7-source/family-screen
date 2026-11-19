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
    case pages, pageHome, pagePhotos, pageClocks, rotatePages, everyPage
    case sendLink, linkOn, members, remove, leaveFamily, deleteFamily, confirmDelete, joinMessage
    case hidePosts, report, hiddenHomes, show, offline, privacy
    case photosSection, frame, framePlain, framePolaroid, frameMat, frameGold, festivalThemes, panZoom
    case sharedAlbum, noAlbum, allowPhotos, photosDenied, pin, unpin
    case setupTitle, setupShare, setupAlbum, setupPlus, setupPrivacy
    case merryChristmas, happyLunarNewYear, shareNoPhoto, shareSent, shareLater, shareNotSetUp

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
        .pages: [.english: "Pages", .cantonese: "頁面", .mandarin: "页面", .hindi: "पेज", .polish: "Strony"],
        .pageHome: [.english: "Home", .cantonese: "主頁", .mandarin: "主页", .hindi: "होम", .polish: "Start"],
        .pagePhotos: [.english: "Photos (full screen)", .cantonese: "相片（全螢幕）", .mandarin: "照片（全屏）", .hindi: "फ़ोटो (पूरी स्क्रीन)", .polish: "Zdjęcia (pełny ekran)"],
        .pageClocks: [.english: "Big clocks and weather", .cantonese: "大時鐘同天氣", .mandarin: "大时钟和天气", .hindi: "बड़ी घड़ियाँ और मौसम", .polish: "Duże zegary i pogoda"],
        .rotatePages: [.english: "Change page automatically", .cantonese: "自動轉頁", .mandarin: "自动翻页", .hindi: "अपने आप पेज बदलें", .polish: "Zmieniaj strony automatycznie"],
        .everyPage: [.english: "Every", .cantonese: "每", .mandarin: "每", .hindi: "हर", .polish: "Co"],
        .sendLink: [.english: "Send invite link", .cantonese: "傳送邀請連結", .mandarin: "发送邀请链接", .hindi: "आमंत्रण लिंक भेजें", .polish: "Wyślij link z zaproszeniem"],
        .linkOn: [.english: "Invite link works", .cantonese: "邀請連結生效", .mandarin: "邀请链接有效", .hindi: "आमंत्रण लिंक चालू", .polish: "Link z zaproszeniem aktywny"],
        .members: [.english: "Family members", .cantonese: "家庭成員", .mandarin: "家庭成员", .hindi: "परिवार के सदस्य", .polish: "Członkowie rodziny"],
        .remove: [.english: "Remove", .cantonese: "移除", .mandarin: "移除", .hindi: "हटाएँ", .polish: "Usuń"],
        .leaveFamily: [.english: "Leave this family", .cantonese: "退出呢個家庭", .mandarin: "退出这个家庭", .hindi: "इस परिवार को छोड़ें", .polish: "Opuść tę rodzinę"],
        .deleteFamily: [.english: "Delete family and all photos", .cantonese: "刪除家庭同所有相片", .mandarin: "删除家庭和所有照片", .hindi: "परिवार और सभी फ़ोटो हटाएँ", .polish: "Usuń rodzinę i wszystkie zdjęcia"],
        .confirmDelete: [.english: "This can't be undone.", .cantonese: "呢個動作無法復原。", .mandarin: "此操作无法撤销。", .hindi: "इसे वापस नहीं किया जा सकता।", .polish: "Tego nie można cofnąć."],
        .joinMessage: [.english: "Tap to join our Family Screen:", .cantonese: "撳呢條連結加入我哋嘅家庭屏幕：", .mandarin: "点此链接加入我们的家庭屏幕：", .hindi: "हमारी फ़ैमिली स्क्रीन से जुड़ने के लिए टैप करें:", .polish: "Dołącz do naszego Family Screen:"],
        .hidePosts: [.english: "Hide posts from this home", .cantonese: "隱藏呢個屋企嘅內容", .mandarin: "隐藏这个家的内容", .hindi: "इस घर की पोस्ट छिपाएँ", .polish: "Ukryj wpisy z tego domu"],
        .report: [.english: "Report", .cantonese: "舉報", .mandarin: "举报", .hindi: "रिपोर्ट करें", .polish: "Zgłoś"],
        .hiddenHomes: [.english: "Hidden homes", .cantonese: "已隱藏嘅屋企", .mandarin: "已隐藏的家", .hindi: "छिपाए गए घर", .polish: "Ukryte domy"],
        .show: [.english: "Show again", .cantonese: "再顯示", .mandarin: "重新显示", .hindi: "फिर दिखाएँ", .polish: "Pokaż ponownie"],
        .offline: [.english: "Offline · showing saved photos and messages", .cantonese: "離線 · 顯示已儲存嘅相片同留言", .mandarin: "离线 · 显示已保存的照片和留言", .hindi: "ऑफ़लाइन · सहेजी गई फ़ोटो और संदेश", .polish: "Offline · zapisane zdjęcia i wiadomości"],
        .privacy: [.english: "Privacy", .cantonese: "私隱", .mandarin: "隐私", .hindi: "गोपनीयता", .polish: "Prywatność"],
        .photosSection: [.english: "Photos", .cantonese: "相片", .mandarin: "照片", .hindi: "फ़ोटो", .polish: "Zdjęcia"],
        .frame: [.english: "Frame", .cantonese: "相框", .mandarin: "相框", .hindi: "फ़्रेम", .polish: "Ramka"],
        .framePlain: [.english: "None", .cantonese: "無", .mandarin: "无", .hindi: "कोई नहीं", .polish: "Brak"],
        .framePolaroid: [.english: "Polaroid with note", .cantonese: "即影即有（附留言）", .mandarin: "拍立得（附留言）", .hindi: "पोलरॉइड, नोट के साथ", .polish: "Polaroid z notatką"],
        .frameMat: [.english: "White mat", .cantonese: "白色卡紙框", .mandarin: "白色卡纸框", .hindi: "सफ़ेद मैट", .polish: "Białe passe-partout"],
        .frameGold: [.english: "Gold Chinese frame", .cantonese: "金色中式相框", .mandarin: "金色中式相框", .hindi: "सुनहरा चीनी फ़्रेम", .polish: "Złota chińska ramka"],
        .festivalThemes: [.english: "Festival themes (Christmas, Lunar New Year, birthdays)", .cantonese: "節日主題（聖誕、農曆新年、生日）", .mandarin: "节日主题（圣诞、农历新年、生日）", .hindi: "त्योहार थीम (क्रिसमस, चीनी नव वर्ष, जन्मदिन)", .polish: "Motywy świąteczne (Boże Narodzenie, Księżycowy Nowy Rok, urodziny)"],
        .panZoom: [.english: "Slow pan and zoom", .cantonese: "慢慢移動同放大", .mandarin: "缓慢平移和缩放", .hindi: "धीमा पैन और ज़ूम", .polish: "Powolne przesuwanie i zoom"],
        .sharedAlbum: [.english: "iCloud Shared Album", .cantonese: "iCloud 共享相簿", .mandarin: "iCloud 共享相簿", .hindi: "iCloud साझा एल्बम", .polish: "Udostępniony album iCloud"],
        .noAlbum: [.english: "None", .cantonese: "無", .mandarin: "无", .hindi: "कोई नहीं", .polish: "Brak"],
        .allowPhotos: [.english: "Show an iCloud Shared Album…", .cantonese: "顯示 iCloud 共享相簿…", .mandarin: "显示 iCloud 共享相簿…", .hindi: "iCloud साझा एल्बम दिखाएँ…", .polish: "Pokaż udostępniony album iCloud…"],
        .photosDenied: [.english: "Allow Photos access in the iPad's Settings ▸ Family Screen.", .cantonese: "請喺 iPad 嘅「設定」▸ Family Screen 容許存取相片。", .mandarin: "请在 iPad 的“设置”▸ Family Screen 中允许访问照片。", .hindi: "iPad की सेटिंग्स ▸ Family Screen में फ़ोटो की अनुमति दें।", .polish: "Zezwól na dostęp do Zdjęć w Ustawieniach iPada ▸ Family Screen."],
        .pin: [.english: "Keep (don't expire)", .cantonese: "保留（唔會過期）", .mandarin: "保留（不会过期）", .hindi: "रखें (समाप्त न हो)", .polish: "Zachowaj (bez wygasania)"],
        .unpin: [.english: "Stop keeping", .cantonese: "取消保留", .mandarin: "取消保留", .hindi: "रखना बंद करें", .polish: "Przestań zachowywać"],
        .setupTitle: [.english: "Send photos to this screen", .cantonese: "傳相片去呢個屏幕", .mandarin: "把照片发到这个屏幕", .hindi: "इस स्क्रीन पर फ़ोटो भेजें", .polish: "Wysyłaj zdjęcia na ten ekran"],
        .setupShare: [.english: "On your iPhone: open a photo, tap Share, then Family Screen. Works from Photos and WhatsApp too.", .cantonese: "喺 iPhone：打開相片，撳「分享」，再揀 Family Screen。「相片」同 WhatsApp 都用得。", .mandarin: "在 iPhone 上：打开照片，点“分享”，再选 Family Screen。“照片”和 WhatsApp 都可以用。", .hindi: "iPhone पर: फ़ोटो खोलें, शेयर दबाएँ, फिर Family Screen। Photos और WhatsApp से भी काम करता है।", .polish: "Na iPhonie: otwórz zdjęcie, stuknij Udostępnij, potem Family Screen. Działa też w Zdjęciach i WhatsAppie."],
        .setupAlbum: [.english: "Already use an iCloud Shared Album? Pick it in Settings ▸ Photos.", .cantonese: "已經用緊 iCloud 共享相簿？喺「設定」▸「相片」揀佢。", .mandarin: "已经在用 iCloud 共享相簿？在“设置”▸“照片”里选择。", .hindi: "पहले से iCloud साझा एल्बम है? सेटिंग्स ▸ फ़ोटो में चुनें।", .polish: "Masz już udostępniony album iCloud? Wybierz go w Ustawieniach ▸ Zdjęcia."],
        .setupPlus: [.english: "Or tap + to add one from this device.", .cantonese: "或者撳 + 由呢部機加相。", .mandarin: "或者点 + 从这台设备添加。", .hindi: "या इस डिवाइस से जोड़ने के लिए + दबाएँ।", .polish: "Albo stuknij +, aby dodać z tego urządzenia."],
        .setupPrivacy: [.english: "Only photos you choose are shared. Copies are made smaller, location is removed, and they're kept for 90 days unless kept on purpose (up to 300).", .cantonese: "只會分享你揀嘅相。副本會縮細、移除位置資料，保留 90 日（除非設為保留，最多 300 張）。", .mandarin: "只分享你选择的照片。副本会缩小、移除位置信息，保留 90 天（除非设为保留，最多 300 张）。", .hindi: "सिर्फ़ आपकी चुनी फ़ोटो साझा होती हैं। कॉपी छोटी की जाती है, लोकेशन हटाई जाती है, और 90 दिन रखी जाती है जब तक आप उसे न रखें (अधिकतम 300)।", .polish: "Udostępniane są tylko wybrane zdjęcia. Kopie są zmniejszane, lokalizacja usuwana, a zdjęcia trzymane 90 dni, chyba że je zachowasz (do 300)."],
        .merryChristmas: [.english: "Merry Christmas", .cantonese: "聖誕快樂", .mandarin: "圣诞快乐", .hindi: "क्रिसमस की शुभकामनाएँ", .polish: "Wesołych Świąt"],
        .happyLunarNewYear: [.english: "Happy Lunar New Year", .cantonese: "新年快樂 · 恭喜發財", .mandarin: "新年快乐 · 恭喜发财", .hindi: "चीनी नव वर्ष की शुभकामनाएँ", .polish: "Szczęśliwego Nowego Roku Księżycowego"],
        .shareNoPhoto: [.english: "No photo to send.", .cantonese: "冇相可以傳。", .mandarin: "没有可发送的照片。", .hindi: "भेजने के लिए कोई फ़ोटो नहीं।", .polish: "Brak zdjęcia do wysłania."],
        .shareSent: [.english: "Sent to the family", .cantonese: "已傳畀家人", .mandarin: "已发给家人", .hindi: "परिवार को भेज दी गई", .polish: "Wysłano do rodziny"],
        .shareLater: [.english: "Saved. It will send when Family Screen next opens.", .cantonese: "已儲存，下次打開 Family Screen 就會傳出。", .mandarin: "已保存，下次打开 Family Screen 时发送。", .hindi: "सहेजी गई। Family Screen अगली बार खुलने पर भेजी जाएगी।", .polish: "Zapisano. Wyślemy przy następnym otwarciu Family Screen."],
        .shareNotSetUp: [.english: "Open Family Screen on this device once to join your family first.", .cantonese: "請先喺呢部機打開 Family Screen 一次，加入你嘅家庭。", .mandarin: "请先在这台设备上打开 Family Screen 一次，加入你的家庭。", .hindi: "पहले इस डिवाइस पर Family Screen एक बार खोलकर परिवार से जुड़ें।", .polish: "Najpierw otwórz Family Screen na tym urządzeniu i dołącz do rodziny."],
    ]

    func text(_ lang: AppLanguage) -> String {
        L.table[self]?[lang] ?? L.table[self]?[.english] ?? rawValue
    }
}
