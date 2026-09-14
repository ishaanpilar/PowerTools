// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import Foundation

/// Strings for the menu bar panel's feature search. Same contract as the
/// other FeatureStrings structs: memberwise init with labeled arguments in
/// declaration order, one static per language, all in this file.
struct PanelSearchStrings {
    let searchButton: String
    let placeholder: String
    let closeSearch: String
    /// %@ is what the person typed.
    let noResultsFormat: String
    let notInstalledSection: String
    let showInFeatures: String
    let opensInPanel: String
    let opensSeparately: String
    let shortcutSection: String
    let shortcutToggle: String
    let shortcutLabel: String
    let shortcutCaption: String
}

extension FeatureStrings {
    static func panelSearch(_ language: AppLanguage) -> PanelSearchStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        }
    }
}

extension PanelSearchStrings {
    static let enUS = PanelSearchStrings(
        searchButton: "Search features",
        placeholder: "Search features",
        closeSearch: "Close search",
        noResultsFormat: "No feature matches “%@”",
        notInstalledSection: "Not installed",
        showInFeatures: "Show on the Features page",
        opensInPanel: "Opens in the panel",
        opensSeparately: "Opens in its own window",
        shortcutSection: "Feature search",
        shortcutToggle: "Open feature search with a shortcut",
        shortcutLabel: "Shortcut",
        shortcutCaption: "Opens the menu bar panel with the search field ready, from any app."
    )

    static let ptBR = PanelSearchStrings(
        searchButton: "Buscar recursos",
        placeholder: "Buscar recursos",
        closeSearch: "Fechar busca",
        noResultsFormat: "Nenhum recurso corresponde a “%@”",
        notInstalledSection: "Não instalados",
        showInFeatures: "Mostrar na página Recursos",
        opensInPanel: "Abre no painel",
        opensSeparately: "Abre em uma janela própria",
        shortcutSection: "Busca de recursos",
        shortcutToggle: "Abrir a busca de recursos com um atalho",
        shortcutLabel: "Atalho",
        shortcutCaption: "Abre o painel da barra de menus com o campo de busca pronto, a partir de qualquer app."
    )

    static let tr = PanelSearchStrings(
        searchButton: "Özellik ara",
        placeholder: "Özellik ara",
        closeSearch: "Aramayı kapat",
        noResultsFormat: "“%@” ile eşleşen özellik yok",
        notInstalledSection: "Yüklü değil",
        showInFeatures: "Özellikler sayfasında göster",
        opensInPanel: "Panelde açılır",
        opensSeparately: "Kendi penceresinde açılır",
        shortcutSection: "Özellik arama",
        shortcutToggle: "Özellik aramasını bir kestirmeyle aç",
        shortcutLabel: "Kestirme",
        shortcutCaption: "Menü çubuğu panelini, arama alanı hazır olarak her uygulamadan açar."
    )

    static let ru = PanelSearchStrings(
        searchButton: "Поиск функций",
        placeholder: "Поиск функций",
        closeSearch: "Закрыть поиск",
        noResultsFormat: "Нет функций по запросу «%@»",
        notInstalledSection: "Не установлены",
        showInFeatures: "Показать на странице «Функции»",
        opensInPanel: "Открывается в панели",
        opensSeparately: "Открывается в отдельном окне",
        shortcutSection: "Поиск функций",
        shortcutToggle: "Открывать поиск функций сочетанием клавиш",
        shortcutLabel: "Сочетание",
        shortcutCaption: "Открывает панель в строке меню с готовым полем поиска из любого приложения."
    )

    static let es = PanelSearchStrings(
        searchButton: "Buscar funciones",
        placeholder: "Buscar funciones",
        closeSearch: "Cerrar búsqueda",
        noResultsFormat: "Ninguna función coincide con “%@”",
        notInstalledSection: "No instaladas",
        showInFeatures: "Mostrar en la página Funciones",
        opensInPanel: "Se abre en el panel",
        opensSeparately: "Se abre en su propia ventana",
        shortcutSection: "Búsqueda de funciones",
        shortcutToggle: "Abrir la búsqueda de funciones con un atajo",
        shortcutLabel: "Atajo",
        shortcutCaption: "Abre el panel de la barra de menús con el campo de búsqueda listo, desde cualquier app."
    )

    static let de = PanelSearchStrings(
        searchButton: "Funktionen suchen",
        placeholder: "Funktionen suchen",
        closeSearch: "Suche schließen",
        noResultsFormat: "Keine Funktion passt zu „%@“",
        notInstalledSection: "Nicht installiert",
        showInFeatures: "Auf der Seite „Funktionen“ zeigen",
        opensInPanel: "Öffnet sich im Panel",
        opensSeparately: "Öffnet sich in einem eigenen Fenster",
        shortcutSection: "Funktionssuche",
        shortcutToggle: "Funktionssuche per Kürzel öffnen",
        shortcutLabel: "Kürzel",
        shortcutCaption: "Öffnet das Menüleisten-Panel mit bereitem Suchfeld, aus jeder App."
    )

    static let fr = PanelSearchStrings(
        searchButton: "Rechercher des fonctions",
        placeholder: "Rechercher des fonctions",
        closeSearch: "Fermer la recherche",
        noResultsFormat: "Aucune fonction ne correspond à «\u{00A0}%@\u{00A0}»",
        notInstalledSection: "Non installées",
        showInFeatures: "Afficher dans la page Fonctions",
        opensInPanel: "S’ouvre dans le panneau",
        opensSeparately: "S’ouvre dans sa propre fenêtre",
        shortcutSection: "Recherche de fonctions",
        shortcutToggle: "Ouvrir la recherche de fonctions avec un raccourci",
        shortcutLabel: "Raccourci",
        shortcutCaption: "Ouvre le panneau de la barre des menus avec le champ de recherche prêt, depuis n’importe quelle app."
    )

    static let it = PanelSearchStrings(
        searchButton: "Cerca funzioni",
        placeholder: "Cerca funzioni",
        closeSearch: "Chiudi ricerca",
        noResultsFormat: "Nessuna funzione corrisponde a “%@”",
        notInstalledSection: "Non installate",
        showInFeatures: "Mostra nella pagina Funzioni",
        opensInPanel: "Si apre nel pannello",
        opensSeparately: "Si apre in una finestra propria",
        shortcutSection: "Ricerca funzioni",
        shortcutToggle: "Apri la ricerca funzioni con una scorciatoia",
        shortcutLabel: "Scorciatoia",
        shortcutCaption: "Apre il pannello della barra dei menu con il campo di ricerca pronto, da qualsiasi app."
    )

    static let ja = PanelSearchStrings(
        searchButton: "機能を検索",
        placeholder: "機能を検索",
        closeSearch: "検索を閉じる",
        noResultsFormat: "「%@」に一致する機能はありません",
        notInstalledSection: "未インストール",
        showInFeatures: "「機能」ページで表示",
        opensInPanel: "パネル内で開きます",
        opensSeparately: "専用のウインドウで開きます",
        shortcutSection: "機能検索",
        shortcutToggle: "ショートカットで機能検索を開く",
        shortcutLabel: "ショートカット",
        shortcutCaption: "どのアプリからでも、検索フィールドを準備した状態でメニューバーのパネルを開きます。"
    )

    static let ko = PanelSearchStrings(
        searchButton: "기능 검색",
        placeholder: "기능 검색",
        closeSearch: "검색 닫기",
        noResultsFormat: "“%@”와(과) 일치하는 기능이 없습니다",
        notInstalledSection: "설치되지 않음",
        showInFeatures: "기능 페이지에서 보기",
        opensInPanel: "패널에서 열림",
        opensSeparately: "별도 윈도우에서 열림",
        shortcutSection: "기능 검색",
        shortcutToggle: "단축키로 기능 검색 열기",
        shortcutLabel: "단축키",
        shortcutCaption: "어느 앱에서든 검색 필드가 준비된 상태로 메뉴 막대 패널을 엽니다."
    )

    static let zhHans = PanelSearchStrings(
        searchButton: "搜索功能",
        placeholder: "搜索功能",
        closeSearch: "关闭搜索",
        noResultsFormat: "没有与“%@”匹配的功能",
        notInstalledSection: "未安装",
        showInFeatures: "在“功能”页面中显示",
        opensInPanel: "在面板中打开",
        opensSeparately: "在独立窗口中打开",
        shortcutSection: "功能搜索",
        shortcutToggle: "使用快捷键打开功能搜索",
        shortcutLabel: "快捷键",
        shortcutCaption: "在任何 App 中打开菜单栏面板，并准备好搜索栏。"
    )

    static let zhTW = PanelSearchStrings(
        searchButton: "搜尋功能",
        placeholder: "搜尋功能",
        closeSearch: "關閉搜尋",
        noResultsFormat: "沒有符合「%@」的功能",
        notInstalledSection: "未安裝",
        showInFeatures: "在「功能」頁面中顯示",
        opensInPanel: "在面板中開啟",
        opensSeparately: "在獨立視窗中開啟",
        shortcutSection: "功能搜尋",
        shortcutToggle: "使用快速鍵開啟功能搜尋",
        shortcutLabel: "快速鍵",
        shortcutCaption: "在任何 App 中開啟選單列面板，並準備好搜尋欄位。"
    )

    static let zhHK = PanelSearchStrings(
        searchButton: "搜尋功能",
        placeholder: "搜尋功能",
        closeSearch: "關閉搜尋",
        noResultsFormat: "沒有符合「%@」的功能",
        notInstalledSection: "未安裝",
        showInFeatures: "在「功能」頁面中顯示",
        opensInPanel: "在面板中開啟",
        opensSeparately: "在獨立視窗中開啟",
        shortcutSection: "功能搜尋",
        shortcutToggle: "使用快捷鍵開啟功能搜尋",
        shortcutLabel: "快捷鍵",
        shortcutCaption: "在任何 App 中開啟選單列面板，並準備好搜尋欄位。"
    )
}
