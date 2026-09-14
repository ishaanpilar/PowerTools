// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import Foundation

/// Strings for the panel's fallback when its dashboard has nothing to show.
/// Same contract as the other FeatureStrings structs: memberwise init with
/// labeled arguments in declaration order, one static per language.
struct PanelEmptyStateStrings {
    let noFeaturesTitle: String
    let noFeaturesBody: String
    let runSetup: String
    let browseFeatures: String
    let hiddenTitle: String
    let hiddenBody: String
    let backgroundBody: String
    let chooseSections: String
}

extension FeatureStrings {
    static func panelEmptyState(_ language: AppLanguage) -> PanelEmptyStateStrings {
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

extension PanelEmptyStateStrings {
    static let enUS = PanelEmptyStateStrings(
        noFeaturesTitle: "No features installed",
        noFeaturesBody: "PowerTools AI only runs what you install. Pick a ready setup or choose features one by one.",
        runSetup: "Run setup",
        browseFeatures: "Browse features",
        hiddenTitle: "Nothing to show here",
        hiddenBody: "The sections you installed are hidden from the panel.",
        backgroundBody: "Your installed features work in the background, without a panel section.",
        chooseSections: "Choose what shows"
    )

    static let ptBR = PanelEmptyStateStrings(
        noFeaturesTitle: "Nenhum recurso instalado",
        noFeaturesBody: "O PowerTools só executa o que você instala. Escolha uma configuração pronta ou selecione recursos um a um.",
        runSetup: "Abrir configuração",
        browseFeatures: "Ver recursos",
        hiddenTitle: "Nada para mostrar aqui",
        hiddenBody: "As seções que você instalou estão ocultas no painel.",
        backgroundBody: "Os recursos instalados funcionam em segundo plano, sem seção no painel.",
        chooseSections: "Escolher o que aparece"
    )

    static let tr = PanelEmptyStateStrings(
        noFeaturesTitle: "Yüklü özellik yok",
        noFeaturesBody: "PowerTools yalnızca yüklediklerinizi çalıştırır. Hazır bir kurulum seçin veya özellikleri tek tek belirleyin.",
        runSetup: "Kurulumu başlat",
        browseFeatures: "Özelliklere göz at",
        hiddenTitle: "Burada gösterilecek bir şey yok",
        hiddenBody: "Yüklediğiniz bölümler panelde gizli.",
        backgroundBody: "Yüklü özellikleriniz panel bölümü olmadan arka planda çalışır.",
        chooseSections: "Görünenleri seç"
    )

    static let ru = PanelEmptyStateStrings(
        noFeaturesTitle: "Функции не установлены",
        noFeaturesBody: "PowerTools запускает только то, что вы установили. Выберите готовый набор или отдельные функции.",
        runSetup: "Открыть настройку",
        browseFeatures: "Обзор функций",
        hiddenTitle: "Здесь нечего показать",
        hiddenBody: "Установленные разделы скрыты из панели.",
        backgroundBody: "Установленные функции работают в фоне и не имеют раздела в панели.",
        chooseSections: "Выбрать, что показывать"
    )

    static let es = PanelEmptyStateStrings(
        noFeaturesTitle: "No hay funciones instaladas",
        noFeaturesBody: "PowerTools solo ejecuta lo que instalas. Elige una configuración lista o selecciona funciones una a una.",
        runSetup: "Iniciar configuración",
        browseFeatures: "Ver funciones",
        hiddenTitle: "Nada que mostrar aquí",
        hiddenBody: "Las secciones que instalaste están ocultas en el panel.",
        backgroundBody: "Tus funciones instaladas trabajan en segundo plano, sin sección en el panel.",
        chooseSections: "Elegir qué se muestra"
    )

    static let de = PanelEmptyStateStrings(
        noFeaturesTitle: "Keine Funktionen installiert",
        noFeaturesBody: "PowerTools führt nur aus, was du installierst. Wähle eine fertige Auswahl oder einzelne Funktionen.",
        runSetup: "Einrichtung starten",
        browseFeatures: "Funktionen ansehen",
        hiddenTitle: "Hier gibt es nichts anzuzeigen",
        hiddenBody: "Deine installierten Bereiche sind im Panel ausgeblendet.",
        backgroundBody: "Deine installierten Funktionen arbeiten im Hintergrund, ohne eigenen Bereich im Panel.",
        chooseSections: "Auswählen, was erscheint"
    )

    static let fr = PanelEmptyStateStrings(
        noFeaturesTitle: "Aucune fonction installée",
        noFeaturesBody: "PowerTools n’exécute que ce que vous installez. Choisissez une configuration prête ou des fonctions une par une.",
        runSetup: "Lancer la configuration",
        browseFeatures: "Parcourir les fonctions",
        hiddenTitle: "Rien à afficher ici",
        hiddenBody: "Les sections installées sont masquées dans le panneau.",
        backgroundBody: "Vos fonctions installées travaillent en arrière-plan, sans section dans le panneau.",
        chooseSections: "Choisir ce qui s’affiche"
    )

    static let it = PanelEmptyStateStrings(
        noFeaturesTitle: "Nessuna funzione installata",
        noFeaturesBody: "PowerTools esegue solo ciò che installi. Scegli una configurazione pronta o seleziona le funzioni una per una.",
        runSetup: "Avvia configurazione",
        browseFeatures: "Sfoglia funzioni",
        hiddenTitle: "Niente da mostrare qui",
        hiddenBody: "Le sezioni installate sono nascoste nel pannello.",
        backgroundBody: "Le funzioni installate lavorano in background, senza una sezione nel pannello.",
        chooseSections: "Scegli cosa mostrare"
    )

    static let ja = PanelEmptyStateStrings(
        noFeaturesTitle: "インストール済みの機能はありません",
        noFeaturesBody: "PowerToolsはインストールしたものだけを実行します。用意されたセットを選ぶか、機能を1つずつ選んでください。",
        runSetup: "セットアップを開始",
        browseFeatures: "機能を見る",
        hiddenTitle: "表示するものがありません",
        hiddenBody: "インストールしたセクションはパネルで非表示になっています。",
        backgroundBody: "インストール済みの機能はバックグラウンドで動作し、パネルにセクションはありません。",
        chooseSections: "表示する項目を選ぶ"
    )

    static let ko = PanelEmptyStateStrings(
        noFeaturesTitle: "설치된 기능 없음",
        noFeaturesBody: "PowerTools는 설치한 기능만 실행합니다. 준비된 구성을 고르거나 기능을 하나씩 선택하세요.",
        runSetup: "설정 시작",
        browseFeatures: "기능 둘러보기",
        hiddenTitle: "표시할 항목 없음",
        hiddenBody: "설치한 섹션이 패널에서 숨겨져 있습니다.",
        backgroundBody: "설치된 기능은 패널 섹션 없이 백그라운드에서 작동합니다.",
        chooseSections: "표시할 항목 선택"
    )

    static let zhHans = PanelEmptyStateStrings(
        noFeaturesTitle: "未安装任何功能",
        noFeaturesBody: "PowerTools 只运行你安装的功能。选择一套现成配置，或逐个挑选功能。",
        runSetup: "开始设置",
        browseFeatures: "浏览功能",
        hiddenTitle: "这里没有可显示的内容",
        hiddenBody: "你安装的分区已在面板中隐藏。",
        backgroundBody: "已安装的功能在后台运行，没有面板分区。",
        chooseSections: "选择要显示的内容"
    )

    static let zhTW = PanelEmptyStateStrings(
        noFeaturesTitle: "尚未安裝任何功能",
        noFeaturesBody: "PowerTools 只會執行你安裝的功能。選擇一套現成設定，或逐一挑選功能。",
        runSetup: "開始設定",
        browseFeatures: "瀏覽功能",
        hiddenTitle: "這裡沒有可顯示的內容",
        hiddenBody: "你安裝的區塊已在面板中隱藏。",
        backgroundBody: "已安裝的功能在背景運作，沒有面板區塊。",
        chooseSections: "選擇要顯示的內容"
    )

    static let zhHK = PanelEmptyStateStrings(
        noFeaturesTitle: "尚未安裝任何功能",
        noFeaturesBody: "PowerTools 只會執行你安裝的功能。選擇一套現成設定，或逐一挑選功能。",
        runSetup: "開始設定",
        browseFeatures: "瀏覽功能",
        hiddenTitle: "這裡沒有可顯示的內容",
        hiddenBody: "你安裝的區塊已在面板中隱藏。",
        backgroundBody: "已安裝的功能在背景運作，沒有面板區塊。",
        chooseSections: "選擇要顯示的內容"
    )
}
