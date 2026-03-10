# Zenith (ex-VPNTools-macOS) — Journal de développement

> Historique exhaustif des modifications effectuées lors des sessions de dev du 8-9 mars 2026 et jours suivants.
> Ce fichier sert de référence pour toute reprise du projet. Chaque étape correspond à un "commit logique".

---

## Périmètre et conventions

### Deux projets distincts

| | `vpn-tools` | `VPN Tools` (cette app) |
|---|---|---|
| **Nature** | CLI Python, outil autonome | App macOS SwiftUI, menu bar |
| **Langage** | Python 3.9+ | Swift 5.9+ |
| **Dépôt** | github.com/ArN-LaB/vpn-tools | github.com/ArN-LaB/Zenith |
| **Versioning** | Semver, tags git, GitHub Releases | Semver, tags git, GitHub Releases |
| **Dépendance** | Aucune — outil autonome | Consomme `vpn-tools` comme sous-processus |

> **Règle absolue** : `vpn-tools` ne sait pas que `VPN Tools.app` existe. La dépendance va dans un seul sens : l'app lance `mullvad_speed_test.py --machine-readable` et parse son stdout JSON.

### Conventions d'écriture dans ce fichier

- **`vpn-tools`** (tiret, minuscules) — désigne toujours le projet Python CLI
- **`VPN Tools`** — nom commercial de l'app macOS (identique au `.app`)
- **`VPNTools-macOS`** — nom du dossier du projet Swift
- Quand une phase documentée ici nécessite un changement dans `vpn-tools`, elle commence par un bloc
  `> **Prérequis vpn-tools** : …` et renvoie vers le CHANGELOG vpn-tools.
  Elle ne décrit **pas** l'implémentation Python — celle-ci est documentée dans vpn-tools.
- Tous les fichiers listés dans les phases sont des fichiers Swift sauf mention explicite contraire.

---

## Table des matières

1. [Phase 1 — Audit initial](#phase-1--audit-initial)
2. [Phase 2 — Diagnostic et identification des bugs critiques](#phase-2--diagnostic-et-identification-des-bugs-critiques)
3. [Phase 3 — Protocole JSON machine-readable (prérequis vpn-tools)](#phase-3--protocole-json-machine-readable-prérequis-vpn-tools)
4. [Phase 4 — Réécriture du parseur Swift (abandon regex)](#phase-4--réécriture-du-parseur-swift-abandon-regex)
5. [Phase 5 — Enrichissement PATH pour dépendances](#phase-5--enrichissement-path-pour-dépendances)
6. [Phase 6 — Enrichissement du modèle ServerResult](#phase-6--enrichissement-du-modèle-serverresult)
7. [Phase 7 — Réécriture DependencyManager](#phase-7--réécriture-dependencymanager)
8. [Phase 8 — PreflightCheckView (popup de vérification)](#phase-8--preflightcheckview-popup-de-vérification)
9. [Phase 9 — Intégration preflight dans ContentView](#phase-9--intégration-preflight-dans-contentview)
10. [Phase 10 — Mise à jour ResultsView (jitter + viable)](#phase-10--mise-à-jour-resultsview-jitter--viable)
11. [Phase 11 — Simplification MenuBarView dependencySection](#phase-11--simplification-menubarview-dependencysection)
12. [Phase 12 — Fix bouton Settings (openSettings)](#phase-12--fix-bouton-settings-opensettings)
13. [Phase 13 — Fix valeurs statiques / progression dynamique](#phase-13--fix-valeurs-statiques--progression-dynamique)
14. [Phase 14 — Zone géographique dans Settings](#phase-14--zone-géographique-dans-settings)
15. [Phase 15 — Dispatching MainActor (SpeedTestRunner)](#phase-15--dispatching-mainactor-speedtestrunner)
16. [Phase 16 — JSON Status Events (prérequis vpn-tools)](#phase-16--json-status-events-prérequis-vpn-tools)
17. [Phase 17 — Parsing StatusEvent côté Swift](#phase-17--parsing-statusevent-côté-swift)
18. [Phase 18 — Modèles StatusEvent et LogEntry](#phase-18--modèles-statusevent-et-logentry)
19. [Phase 19 — ViewModel enrichi (continent, viable, expansion)](#phase-19--viewmodel-enrichi-continent-viable-expansion)
20. [Phase 20 — LogView redesign (log riche vs raw)](#phase-20--logview-redesign-log-riche-vs-raw)
21. [Phase 21 — MenuBarView réordonnement et continent](#phase-21--menubarview-réordonnement-et-continent)
22. [Phase 22 — Dashboard header enrichi](#phase-22--dashboard-header-enrichi)
23. [Phase 23 — Icône app (style Final Cut Pro)](#phase-23--icône-app-style-final-cut-pro)
24. [Phase 24 — Géocodage dynamique ville → coordonnées](#phase-24--géocodage-dynamique-ville--coordonnées)
25. [Phase 25 — Fix layout onglet Test (Settings)](#phase-25--fix-layout-onglet-test-settings)
26. [Phase 26 — Fix détection continent (KEYWORD_TO_CONTINENT, prérequis vpn-tools)](#phase-26--fix-détection-continent-keyword_to_continent-prérequis-vpn-tools)
27. [Phase 27 — Valeurs live à côté des steppers](#phase-27--valeurs-live-à-côté-des-steppers)
28. [Phase 28 — LogView v2 (StatusEvent → LogEntry + SF Symbols)](#phase-28--logview-v2-statusevent--logentry--sf-symbols)
29. [Phase 29 — Géocodage riche (ville/pays/continent) Settings + MenuBar](#phase-29--géocodage-riche-villepayscontinent-settings--menubar)
30. [Phase 30 — LocationResolver (fix géocodage CLGeocoder)](#phase-30--locationresolver-fix-géocodage-clgeocoder)
31. [Phase 31 — ResultsTableView redesign + StatsCardsView](#phase-31--resultstableview-redesign--statscardsview)
32. [Phase 32 — Fix détection continent (user vs serveur)](#phase-32--fix-détection-continent-user-vs-serveur)
33. [Phase 33 — Préflight startup + affichage progressif des étapes](#phase-33--préflight-startup--affichage-progressif-des-étapes)
34. [Phase 34 — TestStep/StepStatus + suppression sidebar](#phase-34--teststepstepstatus--suppression-sidebar)
35. [Phase 35 — Refonte UI/UX complète (MenuBar, Settings, Préflight, Résultats)](#phase-35--refonte-uiux-complète-menubar-settings-préflight-résultats)
36. [Phase 36 — Gestion MTR fallback (mtr_ping_fallback + badge ping)](#phase-36--gestion-mtr-fallback-mtr_ping_fallback--badge-ping)
37. [Phase 37 — Visibilité ping fallback sur toutes les surfaces UI](#phase-37--visibilité-ping-fallback-sur-toutes-les-surfaces-ui)
38. [Phase 38 — Diagnostic mtr-packet SUID (cause racine)](#phase-38--diagnostic-mtr-packet-suid-cause-racine)

---

## Phase 1 — Audit initial

**Objectif** : Analyser les deux projets (vpn-tools Python CLI + VPNTools-macOS Swift app) pour comprendre l'architecture et identifier les problèmes.

**Constat** :
- `vpn-tools` : CLI Python 3.9+, utilise `speedtest-cli`, `geopy`, `colorama`, `mtr`, `mullvad`. Fonctionne correctement.
- `VPNTools-macOS` : App SwiftUI macOS 14+, menu bar (`LSUIElement=true`), architecture MVVM, SPM build. L'app ne fonctionnait pas correctement.
- Le code Python bundlé dans `.app/Contents/Resources/python/` était **identique** au source (vérifié par diff).
- La compilation Swift était **propre** (0 erreurs, 0 warnings).
- Le problème était donc **à l'exécution**, pas à la compilation.

**Fichiers analysés** : tous les fichiers Swift + Python + build_app.sh + Package.swift

---

## Phase 2 — Diagnostic et identification des bugs critiques

**Bugs identifiés** :

### Bug 1 — Parseur regex cassé (critique)
- **Fichier** : `SpeedTestRunner.swift` (ancien code)
- **Problème** : Le parseur utilisait une regex pour extraire les résultats depuis stdout du script Python. Cette regex ne matchait **jamais** le format de sortie réel de Python (qui utilise colorama avec codes ANSI, tables formatées, etc.).
- **Conséquence** : Aucun résultat n'était jamais capturé par l'app.

### Bug 2 — PATH incomplet (critique)
- **Fichier** : `SpeedTestRunner.swift` (ancien code)
- **Problème** : L'app bundle macOS hérite d'un PATH minimal (`/usr/bin:/bin`). Les dépendances sont installées dans des chemins non-standard :
  - `speedtest-cli` → `~/Library/Python/3.9/bin/`
  - `mtr` → `/opt/homebrew/sbin/`
  - `mullvad` → `/usr/local/bin/`
- **Conséquence** : Le script Python ne trouvait pas ses dépendances CLI.

### Bug 3 — VPN non déconnecté après annulation
- **Problème** : Si l'utilisateur annulait un test, Mullvad restait connecté au dernier serveur testé.

### Bug 4 — `check_dependencies()` Python utilisait `subprocess.run`
- **Fichier** : `mullvad_speed_test.py`
- **Problème** : `subprocess.run(["which", "speedtest-cli"])` ne respectait pas le PATH enrichi injecté par l'app.

---

## Phase 3 — Protocole JSON machine-readable (prérequis vpn-tools)

**Prérequis vpn-tools** : ajout du flag `--machine-readable` dans vpn-tools — VPNTools-macOS injecte cet argument lors du lancement du processus Python.

> Les détails d'implémentation Python appartiennent au projet vpn-tools. Voir [CHANGELOG vpn-tools v1.1.0](https://github.com/ArN-LaB/vpn-tools/blob/main/docs/CHANGELOG.md).

**Impact VPNTools-macOS** : permet de remplacer le parseur regex fragile par un parseur JSON robuste (voir Phase 4 — Réécriture du parseur Swift).

- `SpeedTestConfig.cliArguments` inclut `--machine-readable` parmi les arguments injectés
- `SpeedTestRunner` route les lignes JSON `{"type":"result",...}` vers `parseJSONResultLine()`

---

## Phase 4 — Réécriture du parseur Swift (abandon regex)

**Fichier modifié** : `VPNTools-macOS/VPNTools/Services/SpeedTestRunner.swift`

**Changements** :
- Suppression complète de l'ancien parseur regex
- Ajout `static let toolPaths: [String]` — array de tous les chemins connus :
  ```swift
  ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin", "/usr/local/sbin",
   "/usr/bin", "/usr/sbin", "/Applications/Mullvad VPN.app/Contents/Resources",
   home + "/Library/Python/3.9/bin", ..., home + "/Library/Python/3.13/bin",
   home + "/.local/bin"]
  ```
- Ajout `static var enrichedPath: String` — combine system PATH + toolPaths
- Ajout `parseJSONResultLine(_ line: String) -> ServerResult?` — décode `{"type":"result",...}`
- Ajout `disconnectMullvad()` — exécute `mullvad disconnect` après test/cancel
- Ajout `static func findExecutable(_ name: String) -> String`
- Injection `env["PATH"] = Self.enrichedPath` dans le Process
- Injection `env["PYTHONUNBUFFERED"] = "1"` pour flush immédiat
- Appel `disconnectMullvad()` dans `terminationHandler` et `cancel()`

---

## Phase 5 — Enrichissement PATH pour dépendances

**Fichier modifié** : `SpeedTestRunner.swift`

**Changements** :
- Ajout des répertoires pip user bin pour Python 3.9 à 3.13 dans `toolPaths`
- Ajout `~/.local/bin` 
- `enrichedPath` filtre les doublons et combine tout

**Raison** : `speedtest-cli` installé via `pip install --user` se retrouve dans `~/Library/Python/3.x/bin/` qui n'est jamais dans le PATH d'une app bundle.

---

## Phase 6 — Enrichissement du modèle ServerResult

**Fichier modifié** : `VPNTools-macOS/VPNTools/Models/SpeedTestModels.swift`

**Changements sur `ServerResult`** :
- Ajout champs : `connectionTime`, `jitter`, `packetLoss`, `mtrLatency`, `mtrPacketLoss`, `mtrHops`, `viable`
- Ajout computed property `connectionTimeFormatted`
- Mise à jour de l'`init()` avec valeurs par défaut pour les nouveaux champs

**Changements sur `SpeedTestConfig`** :
- `cliArguments` inclut maintenant `--machine-readable` dans les args par défaut
- `--countdown-seconds` forcé à `"0"` (pas de countdown dans la GUI)

---

## Phase 7 — Réécriture DependencyManager

**Fichier modifié** : `VPNTools-macOS/VPNTools/Services/DependencyManager.swift`

**Changements** :
- Ajout `foundPath: String` dans le struct `Dependency` (pour afficher le chemin trouvé)
- Ajout `@Published var hasChecked: Bool` (pour savoir si la vérification a été faite)
- Ajout `@Published var pythonPath: String` (chemin Python détecté)
- Remplacement `isCommandAvailable()` par `findCommand(_ command: String) -> (Bool, String)` :
  - Cherche d'abord dans `SpeedTestRunner.toolPaths` (accès direct fichier)
  - Fallback : exécute `which` avec PATH enrichi
  - Retourne le tuple `(found, path)`
- `install()` : fallback `python3 -m pip install --user` si pip direct non trouvé
- `runInstall()` : injecte `SpeedTestRunner.enrichedPath` dans l'environnement du Process
- `checkAll()` : met à jour `foundPath` + `hasChecked` + `pythonPath`
- Re-check automatique après chaque tentative d'installation
- Ajout `findPython() -> String`

---

## Phase 8 — PreflightCheckView (popup de vérification)

**Fichier créé** : `VPNTools-macOS/VPNTools/Views/PreflightCheckView.swift` (NOUVEAU)

**Description** : Popup modal glassmorphism affiché au démarrage pour vérifier toutes les dépendances avant d'autoriser le lancement d'un test.

**Composants** :
- Header avec icône shield + titre "System Check"
- Liste des dépendances avec `DependencyRow` (struct privée) :
  - Checkmark vert / X rouge + nom + chemin trouvé ou commande d'install
  - Bouton "Install" individuel
  - Spinner pendant installation
- Ligne Python 3 (détection séparée)
- Zone de log d'installation (ScrollView, max 80px)
- Boutons d'action :
  - "All set — Continue" (vert, quand tout est OK) — dismiss le popup
  - "Install Missing" (bleu, bulk install des deps auto-installables)
  - "Re-check" (bordé)
- `.task` : lance `depManager.checkAll()` si pas encore fait
- Style : `.regularMaterial`, coins arrondis 16, ombre portée

---

## Phase 9 — Intégration preflight dans ContentView

**Fichier modifié** : `VPNTools-macOS/VPNTools/Views/ContentView.swift`

**Changements** :
- Ajout `@EnvironmentObject var depManager: DependencyManager`
- Ajout `@State private var preflightDismissed = false`
- Ajout computed `showPreflight: Bool` — affiché si pas dismissed OU si deps manquantes détectées
- Body wrappé dans `ZStack` :
  - `NavigationSplitView` existante avec `.blur(radius: 4)` et `.allowsHitTesting(false)` quand preflight affiché
  - Overlay noir semi-transparent (`Color.black.opacity(0.3)`)
  - `PreflightCheckView(dismissed: $preflightDismissed)`
- Animation `.easeInOut(duration: 0.25)` sur `showPreflight`

---

## Phase 10 — Mise à jour ResultsView (jitter + viable)

**Fichier modifié** : `VPNTools-macOS/VPNTools/Views/ResultsView.swift`

**Changements** :
- Ajout colonne "Jitter" dans le `Table` de `ResultsTableView`
- Ajout indicateur ⚠ (orange) sur les serveurs non-viables dans la colonne Server
- `.help("Non-viable (below min speed)")` sur l'icône

---

## Phase 11 — Simplification MenuBarView dependencySection

**Fichier modifié** : `VPNTools-macOS/VPNTools/Views/MenuBarView.swift`

**Changements** :
- Suppression du bloc "Install All" inline (batch install)
- Suppression de l'affichage du `installLog` inline
- Conservation des lignes individuelles par dépendance (checkmark/X + Install)
- Ajout bouton "Open Dashboard for details" → `openDashboard()` pour voir le PreflightCheckView complet
- Raison : le PreflightCheckView gère maintenant l'UX détaillée, le menu bar reste compact

---

## Phase 12 — Fix bouton Settings (openSettings)

**Fichiers modifiés** : `VPNToolsApp.swift`, `MenuBarView.swift`

**Problème** : Le bouton "Settings…" utilisait `NSApp.sendAction(Selector(("showSettingsWindow:")))` — ce selector Cocoa ne fonctionne pas avec les apps `LSUIElement` (menu bar only) utilisant SwiftUI Settings scene.

**Solution** :
- `VPNToolsApp.swift` : ajout `@Environment(\.openSettings) private var openSettings`
- Passage de `openSettings` en closure à `MenuBarView`
- `MenuBarView.swift` : ajout propriété `let openSettings: () -> Void`
- Bouton Settings appelle `NSApp.activate(ignoringOtherApps: true)` puis `openSettings()`
- Couleur changée de `.secondary` (paraissait inactif) à `.primary`

---

## Phase 13 — Fix valeurs statiques / progression dynamique

**Fichiers modifiés** : `SpeedTestViewModel.swift`, `MenuBarView.swift`

**Problème** : Le texte de progression restait bloqué sur "Mullvad VPN Server Performance Tester" (le banner ASCII). L'ancien `updateProgress()` matchait tout mot contenant "server" → capturait le banner.

**Solution dans SpeedTestViewModel** :
- `updateProgress()` réécrit avec des patterns précis :
  - `"calibrat"` → "Calibrating connections…"
  - `"searching for servers on continents"` → "Expanding search zone…"
  - `"connecting to"` → "Connecting: {server}"
  - `"running speed test"` → "Speed test in progress…"
  - `"selected"` + `"servers from"` → affiche la ligne telle quelle
- Callback `onResult` enrichi : met à jour `state` avec `"{hostname} — {download} [{N}/{total}]"`

**Solution dans MenuBarView** :
- `.id("results-\(vm.results.count)")` sur `resultsSummary` → force SwiftUI à re-render
- `.id("progress-\(count)-\(progress)")` sur le bloc progress
- Ajout compteur "N server(s) tested" sous la progression

---

## Phase 14 — Zone géographique dans Settings

**Fichier modifié** : `VPNTools-macOS/VPNTools/Views/SettingsView.swift`

**Changements** :
- Nouvelle section "Geographic zone" dans l'onglet Test :
  - Toggle "Limit search radius" — active/désactive `maxDistance`
  - Stepper 500–50000 km (pas de 500) — édite `config.maxDistance`
  - Texte explicatif : "Nearby servers are tested first. If not enough are viable, the search automatically expands to other continents."
- Frame Settings agrandi de 340 → 420 px hauteur

**Note** : `maxDistance` existait déjà dans `SpeedTestConfig` et était passé en CLI args, mais n'était jamais exposé dans l'UI.

---

## Phase 15 — Dispatching MainActor (SpeedTestRunner)

**Fichier modifié** : `VPNTools-macOS/VPNTools/Services/SpeedTestRunner.swift`

**Changements** :
- Remplacement de tous les `DispatchQueue.main.async { ... }` par `Task { @MainActor in ... }` :
  - `pipe.fileHandleForReading.readabilityHandler` → onOutput
  - `errorPipe.fileHandleForReading.readabilityHandler` → onOutput stderr
  - `process.terminationHandler` → onComplete
  - `processOutput()` → onResult, onOutput

**Raison** : `SpeedTestViewModel` est `@MainActor`, les callbacks doivent être dispatchées via le même mécanisme pour garantir la cohérence des mises à jour `@Published`.

---

## Phase 16 — JSON Status Events (prérequis vpn-tools)

**Prérequis vpn-tools** : émission d'événements `{"type":"status","phase":...}` à chaque étape du test, permettant le suivi de progression en temps réel.

> Protocole JSON défini dans vpn-tools. Voir [CHANGELOG vpn-tools v1.1.0](https://github.com/ArN-LaB/vpn-tools/blob/main/docs/CHANGELOG.md).

**Phases émises** (consommées côté Swift via `onStatus` callback) : `calibration`, `calibration_test`, `selection`, `testing`, `progress`, `extension`.

**Impact VPNTools-macOS** : déclenche la mise à jour du ViewModel en temps réel sans attendre la fin du test (voir Phase 17 — Parsing StatusEvent côté Swift).

---

## Phase 17 — Parsing StatusEvent côté Swift

**Fichier modifié** : `VPNTools-macOS/VPNTools/Services/SpeedTestRunner.swift`

**Changements** :
- Ajout paramètre `onStatus: @escaping (StatusEvent) -> Void` dans `run()`
- Ajout `parseJSONStatusLine(_ line: String) -> StatusEvent?` avec struct `JSONStatus: Decodable`
- Modification `processOutput()` : accepte `onStatus`, route les JSON `{"type":"status",...}` vers `onStatus` callback
- Le processOutput dispatch : JSON result → onResult, JSON status → onStatus, texte brut → onOutput

---

## Phase 18 — Modèles StatusEvent et LogEntry

**Fichier modifié** : `VPNTools-macOS/VPNTools/Models/SpeedTestModels.swift`

**Ajouts** :

### `StatusEvent` (struct)
- Propriétés : `phase`, `message`, `continent?`, `continents?`, `hostname?`, `city?`, `country?`, `distanceKm?`, `index?`, `total?`, `viable?`, `target?`, `tested?`, `successful?`, `excludeContinent?`

### `LogEntry` (struct, Identifiable)
- Propriétés : `id` (UUID), `timestamp` (Date), `kind` (Kind), `text` (String)
- Enum `Kind` : `.header`, `.info`, `.success`, `.warning`, `.error`, `.result`, `.server`, `.json`
- Méthode statique `classify(_ line: String) -> LogEntry` :
  - Détecte les patterns Unicode (✓, ⚠, ✗) et les mots-clés
  - Classifie les séparateurs (`───`, `===`) en headers
  - Masque les lignes JSON de l'affichage visuel (kind `.json`)
  - Classifie les lignes contenant "Mbps" en `.result`

---

## Phase 19 — ViewModel enrichi (continent, viable, expansion)

**Fichier modifié** : `VPNTools-macOS/VPNTools/Models/SpeedTestViewModel.swift`

**Nouvelles @Published** :
- `logEntries: [LogEntry]` — log structuré en parallèle du log brut
- `userContinent: String` — continent détecté par Python
- `availableContinents: [String]` — tous les continents avec serveurs
- `currentTestInfo: StatusEvent?` — dernier status event reçu
- `viableCount: Int` — nombre de serveurs viables trouvés
- `viableTarget: Int` — objectif min_viable_servers
- `isExpanding: Bool` — true si on cherche hors du continent initial

**Nouvelle méthode `handleStatus(_ status: StatusEvent)`** :
- `"calibration"` → set continent, continents, state "🌐 Calibrating"
- `"calibration_test"` → state "⏱ Calibrating: {hostname}"
- `"selection"` → state "📍 Selected N servers"
- `"testing"` → set currentServer, state "🖥 hostname [idx/total] dist"
- `"progress"` → update viableCount, viableTarget
- `"extension"` → set isExpanding, state "🌍 Expanding beyond {continent}"

**`updateProgress()` simplifié** : ne réagit qu'aux lignes texte non-couvertes par les status JSON (speed test, connecting, MTR, stabilizing).

**`startTest()` enrichi** : reset de tous les nouveaux champs, passage de `onStatus` au runner.

---

## Phase 20 — LogView redesign (log riche vs raw)

**Fichier modifié** : `VPNTools-macOS/VPNTools/Views/ResultsView.swift`

**Remplacement complet de `LogView`** :

### Barre d'outils (toolbar)
- Label 🌐 continent (cyan) + badge "→ expanding" (orange) si expansion en cours
- Compteur "Viable: N/M" (vert si atteint, orange sinon)
- Toggle ⌨ pour basculer raw/rich

### Mode riche (`richLogView`)
- `LazyVStack` de `LogEntry` filtrés (exclut `.json`)
- Chaque kind a un style dédié via `logEntryView(_ entry:)` :
  - `.header` : barre cyan latérale 3px + texte bold cyan. Si texte vide → `Divider()`
  - `.success` : "✓" vert + texte vert, font monospaced 11pt
  - `.warning` : "⚠" orange + texte orange
  - `.error` : "✗" rouge + texte rouge
  - `.result` : texte vert bold monospaced
  - `.server` : texte cyan monospaced
  - `.info` : "ℹ" bleu + texte gris clair
  - `.json` : `EmptyView()`
- Auto-scroll vers la dernière entrée visible

### Mode raw (`rawLogView`)
- Identique à l'ancien LogView : `LazyVStack` de strings brutes, monospaced, rouge pour stderr
- Auto-scroll

---

## Phase 21 — MenuBarView réordonnement et continent

**Fichier modifié** : `VPNTools-macOS/VPNTools/Views/MenuBarView.swift`

**Changements** :
- **Ordre inversé** : le bloc progression (serveur en test) est affiché **AVANT** le résumé des résultats (meilleur serveur). Plus cohérent : on voit d'abord ce qui se passe, puis le bilan.
- **Bloc progression enrichi** :
  - Label 🌐 continent (cyan)
  - Compteur viable "N/M viable" (vert/orange)
  - Badge "expanding zone" (orange) si expansion en cours
  - Sous-ligne "N tested • ↓ X.X Mbps avg" quand des résultats existent
- Suppression du bloc progression dupliqué qui traînait (leftovers du refactoring)

---

## Phase 22 — Dashboard header enrichi

**Fichier modifié** : `VPNTools-macOS/VPNTools/Views/ContentView.swift`

**Changements dans `HeaderView`** :
- Sous-titre enrichi avec infos continent en temps réel :
  - Label 🌐 continent (cyan) — visible dès la calibration
  - "→ expanding zone" (orange) — visible pendant l'expansion
  - "N/M viable" (vert/orange) — visible pendant le test

---

## Résumé des fichiers

### Fichiers créés (1)
| Fichier | Rôle |
|---------|------|
| `VPNTools/Views/PreflightCheckView.swift` | Popup modal de vérification des dépendances |

### Fichiers modifiés côté Swift (9)
| Fichier | Modifications principales |
|---------|-------------------------|
| `VPNToolsApp.swift` | `@Environment(\.openSettings)`, passage closure `openSettings` à MenuBarView |
| `Models/SpeedTestModels.swift` | +`StatusEvent`, +`LogEntry` (classify), enrichissement `ServerResult` (7 champs), `--machine-readable` dans `cliArguments` |
| `Models/SpeedTestViewModel.swift` | +`logEntries`, +`handleStatus()`, +continent/viable/expansion tracking, réécriture `updateProgress()`, `onStatus` callback |
| `Services/SpeedTestRunner.swift` | Réécriture complète : JSON parser, `toolPaths`/`enrichedPath`, `onStatus` callback, `parseJSONStatusLine()`, `disconnectMullvad()`, `@MainActor` dispatch |
| `Services/DependencyManager.swift` | `findCommand()` remplace `isCommandAvailable()`, `foundPath`, `hasChecked`, `pythonPath`, `findPython()`, PATH enrichi pour installs |
| `Views/ContentView.swift` | Preflight overlay ZStack, header enrichi continent/viable/expansion |
| `Views/MenuBarView.swift` | `openSettings` closure, ordre inversé progress/results, continent/viable/expansion, section deps simplifiée |
| `Views/ResultsView.swift` | +colonne Jitter, +icône viable, LogView complètement réécrit (rich/raw toggle) |
| `Views/SettingsView.swift` | +section "Geographic zone" (maxDistance toggle + stepper), frame 420px |

### Dépendance vpn-tools
Les modifications Python nécessaires sont documentées dans le [CHANGELOG vpn-tools v1.1.0](https://github.com/ArN-LaB/vpn-tools/blob/main/docs/CHANGELOG.md).

---

## Architecture finale

```
VPNTools-macOS/
├── VPNToolsApp.swift              ← Point d'entrée, 3 scènes (MenuBar, Dashboard, Settings)
├── Models/
│   ├── SpeedTestModels.swift      ← ServerResult, SpeedTestConfig, StatusEvent, LogEntry, TestState
│   └── SpeedTestViewModel.swift   ← MVVM ViewModel, bridge Python↔SwiftUI
├── Services/
│   ├── SpeedTestRunner.swift      ← Subprocess Python, parsing JSON, PATH enrichi
│   └── DependencyManager.swift    ← Vérification/installation dépendances
└── Views/
    ├── ContentView.swift          ← Dashboard principal + overlay preflight
    ├── MenuBarView.swift          ← Popover menu bar (280px)
    ├── PreflightCheckView.swift   ← Modal vérification dépendances
    ├── ResultsView.swift          ← Table résultats, stats, logs (rich/raw)
    └── SettingsView.swift         ← Onglets General/Test/Paths
```

## Protocole de communication Python → Swift

```
Python stdout (--machine-readable) :
  {"type":"status","phase":"calibration","continent":"Europe","continents":["Europe","Asia",...]}
  {"type":"status","phase":"testing","hostname":"fr-par-wg-005","index":1,"total":15,...}
  {"type":"result","hostname":"fr-par-wg-005","download_speed":45.2,...}
  {"type":"status","phase":"progress","tested":1,"viable":1,"target":8}
  {"type":"status","phase":"extension","exclude_continent":"Europe",...}

Swift parsing :
  processOutput() → parseJSONResultLine() → onResult callback
                   → parseJSONStatusLine() → onStatus callback
                   → texte brut          → onOutput callback
```

## Dépendances système vérifiées

| Outil | Chemin sur la machine | Ajouté dans toolPaths |
|-------|----------------------|----------------------|
| `speedtest-cli` | `~/Library/Python/3.9/bin/speedtest-cli` | ✅ |
| `mtr` | `/opt/homebrew/sbin/mtr` | ✅ |
| `mullvad` | `/usr/local/bin/mullvad` | ✅ |
| `python3` | `/usr/bin/python3` | ✅ (fallback) |

## Build

```bash
# Compilation Swift (debug)
cd VPNTools-macOS && swift build

# Build app bundle (release)
bash build_app.sh
# → VPN Tools.app (2.5 MB)

# Installation
cp -R 'VPN Tools.app' /Applications/
open '/Applications/VPN Tools.app'

# Tests Python
cd vpn-tools && python3 -m pytest tests/ -q
# → 8/8 passed
```

---

## Phase 23 — Icône app (style Final Cut Pro)

**Date** : 9 mars 2026

**Fichier créé** : `VPNTools-macOS/generate_icon.py` (NOUVEAU)

**Fichiers modifiés** : tous les PNG dans `Assets.xcassets/AppIcon.appiconset/` + `VPNTools.icns`

**Description** : Remplacement de l'icône app par un design inspiré du style Final Cut Pro pour iPad (fond sombre premium, éléments vibrants néon), tout en restant unique pour VPN Tools.

**Éléments visuels** :
- **Fond** : dégradé vertical indigo profond (`(15,10,40)`) → violet sombre → quasi-noir, avec lueur radiale subtile (centre haut) et micro-texture de points
- **Bouclier** : silhouette shield modernisée (polygon calculé avec courbes), remplissage gradient intérieur, bordure violette lumineuse (glow gaussien 12px)
- **Arc speedomètre** : arc dégradé cyan → vert → violet (210°–330°), 12 graduations (majeures/mineures), aiguille rouge pointant à 78% (= rapide)
- **Cadenas VPN** : petit symbole lock cyan au-dessus de l'arc (corps arrondi + shackle)
- **Détails** : 40 points de connexion réseau discrets autour du shield (cyan/vert/violet, alpha 20-70), lignes de connexion entre points proches, reflet bas
- **Masque squircle** : coins arrondis macOS (22.37% du rayon), feather 1px

**Génération** : script Pillow Python → master 1024×1024 → resize LANCZOS vers 11 tailles → `iconutil --convert icns`

**Fichiers générés** :
- 11 PNG (`icon_16x16.png` → `icon_512x512@2x.png`) dans `AppIcon.appiconset/`
- `icon_master_1024.png` (référence)
- `VPNTools.icns` (294 KB) à la racine du projet
- Script `generate_icon.py` conservé pour itération future

---

## Phase 24 — Géocodage dynamique ville → coordonnées

**Date** : 9 mars 2026

**Fichier modifié** : `VPNTools/Views/SettingsView.swift`

**Problème** : Quand l'utilisateur entrait un nom de ville dans "Reference location", les champs lat/lon restaient vides. Il fallait les remplir manuellement.

**Solution** :
- Ajout `import CoreLocation`
- Ajout `@State` : `resolvedLat`, `resolvedLon`, `geocodeStatus`, `geocodeTask`
- `.onChange(of: vm.config.location)` → appelle `geocodeCity()`
- `geocodeCity(_ input:)` :
  - Annule le task précédent (`geocodeTask?.cancel()`)
  - Debounce 600ms (`Task.sleep`)
  - Appelle `CLGeocoder().geocodeAddressString()`
  - Met à jour `resolvedLat`/`resolvedLon` ou `geocodeStatus = "Location not found"`
- Affichage sous le TextField :
  - Pin vert + `48.8566, 2.3522` + bouton **"Use"** → copie vers `defaultLat`/`defaultLon`
  - Ou icône orange + "Location not found"

---

## Phase 25 — Fix layout onglet Test (Settings)

**Date** : 9 mars 2026

**Fichier modifié** : `VPNTools/Views/SettingsView.swift`

**Problèmes** :
1. Contenu coupé en bas de l'onglet Test (Thresholds non visible)
2. Labels "Mbps" / "seconds" mal alignés et texte retournant à la ligne ("sec-\nonds")
3. Fenêtre trop petite

**Solutions** :
- Onglet Test wrappé dans `ScrollView` → plus de coupure
- Fenêtre agrandie de 420 → 520 px hauteur
- Section Thresholds réécrite :
  - `TextField` réduit à 60px, `.multilineTextAlignment(.trailing)`
  - Unités avec largeur fixe 40px, `.foregroundStyle(.secondary)`, `.frame(alignment: .leading)`
  - Plus de retour à la ligne

---

## Phase 26 — Fix détection continent (KEYWORD_TO_CONTINENT)

**Date** : 9 mars 2026

**Prérequis vpn-tools** : `KEYWORD_TO_CONTINENT` enrichi dans vpn-tools — résout correctement le continent à partir du nom de ville de référence saisi dans Settings.

> Voir [CHANGELOG vpn-tools v1.1.0](https://github.com/ArN-LaB/vpn-tools/blob/main/docs/CHANGELOG.md) (CONTINENT_MAPPING enrichi, ~80 entrées).

**Symptôme visible dans VPNTools-macOS** : saisir "tokyo" dans Settings → continent "Unknown" au lieu de "Asia".

**Impact** : le continent de l'utilisateur (`userContinent`) s'affiche correctement dans le header Dashboard et MenuBarView.

---

## Phase 27 — Valeurs live à côté des steppers

**Date** : 9 mars 2026

**Fichier modifié** : `VPNTools/Views/SettingsView.swift`

**Problème** : Les steppers affichaient la valeur dans le label ("Max servers: 15") mais le format n'était pas idéal — texte collé au label, pas de distinction visuelle.

**Solution** :
- Nouvelle méthode `stepperRow(_ label:value:range:step:unit:) -> some View` :
  ```swift
  Stepper(value: value, in: range, step: step) {
      HStack {
          Text(label)
          Spacer()
          Text("\(value.wrappedValue) \(unit)")
              .foregroundStyle(.secondary)
              .monospacedDigit()
      }
  }
  ```
- Tous les steppers de l'onglet Test utilisent `stepperRow()` (Server limits + Geographic zone)
- La valeur apparaît à droite en gris monospaced, séparée du label → lecture claire

---

## Phase 28 — LogView v2 (StatusEvent → LogEntry + SF Symbols)

**Date** : 9 mars 2026

**Fichiers modifiés** : `SpeedTestModels.swift`, `SpeedTestRunner.swift`, `SpeedTestViewModel.swift`, `ResultsView.swift`

### Problème
Les logs montraient les lignes JSON brutes non parsées et les entrées riches étaient visuellement ternes (emoji texte ✓/⚠/✗ au lieu de vrais symboles).

### StatusEvent enrichi (`SpeedTestModels.swift`)
- Ajout champs `count: Int?` et `totalAvailable: Int?` dans `StatusEvent`
- Nouvelle méthode `toLogEntry() -> LogEntry` — convertit chaque phase en entrée riche :
  - `calibration` → `.header` cyan "Calibrating connections — Europe • Available: Europe, Asia, …"
  - `calibration_test` → `.server` "⏱ Calibrating: jp-tyo-wg-001 (Tokyo, Japan)"
  - `selection` → `.success` "Selected 8 servers from 553 available — Europe"
  - `testing` → `.server` "[2/8] cz-prg-wg-101 — Prague, Czech Republic 281 km"
  - `progress` → `.success`/`.info` "✓ Progress: 3 tested, 2/4 viable, 1 successful"
  - `extension` → `.warning` "Expanding search beyond Europe…"

### JSONStatus enrichi (`SpeedTestRunner.swift`)
- `JSONStatus` Decodable : ajout `count`, `total_available`
- `StatusEvent` init : mapping `count` → `json.count`, `totalAvailable` → `json.total_available`

### ViewModel : génération d'entrées depuis StatusEvent (`SpeedTestViewModel.swift`)
- Callback `onStatus` enrichi : après `handleStatus(status)`, appelle `status.toLogEntry()` et l'ajoute à `logEntries`
- Fix `"selection"` phase : utilise `status.count` au lieu de `status.index`

### LogView redesignée (`ResultsView.swift`)

**Toolbar améliorée** :
- Globe + continent en `.bold()` cyan
- Badge "→ expanding" dans une `Capsule()` orange semi-transparente
- Pastille ronde colorée (6px) devant "Viable: N/M"
- Toggle icône contextuelle (`terminal.fill` / `list.bullet.rectangle`)

**Remplacement emoji → SF Symbols** pour chaque `LogEntry.Kind` :
| Kind | Avant | Après |
|------|-------|-------|
| `.success` | `✓` texte | `checkmark.circle.fill` vert |
| `.warning` | `⚠` texte | `exclamationmark.triangle.fill` orange |
| `.error` | `✗` texte | `xmark.circle.fill` rouge |
| `.result` | texte vert | `arrow.down.circle.fill` vert + texte semibold |
| `.server` | texte cyan | `server.rack` cyan + texte |
| `.info` | `ℹ` texte | `info.circle` bleu + texte opacity 0.7 |
| `.header` | barre cyan | `Divider` + barre cyan + texte semibold monospaced |

**Autres améliorations** :
- Espacement `VStack` réduit de 2 à 1
- Padding vertical 1px sur chaque entrée (respiration)
- Background `.opacity(0.5)` au lieu de opaque
- Auto-scroll avec `withAnimation(.easeOut(duration: 0.15))`
- État vide : icône `text.alignleft` + texte tertiaire
- `visibleEntries` computed property (filtrage `.json` pré-calculé)

---

## Phase 29 — Géocodage riche (ville/pays/continent) Settings + MenuBar

**Date** : 9 mars 2026

**Fichiers modifiés** : `SettingsView.swift`, `MenuBarView.swift`

### Problème
Lorsqu'on tapait une ville dans Settings ou MenuBar, seules les coordonnées brutes (lat/lon) s'affichaient. Pas de confirmation visuelle du nom de ville, pays ou continent résolu. L'UX obligeait l'utilisateur à valider à l'aveugle sans voir à quoi correspondaient les coordonnées.

### SettingsView — Bouton de validation enrichi
- Ajout d'états `resolvedCity`, `resolvedCountry`, `resolvedContinent`
- Le géocodeur `CLGeocoder` extrait maintenant `pm.locality`, `pm.country` et `pm.isoCountryCode` du `CLPlacemark`
- Nouveau bouton de validation (remplace l'ancien "Use") :
  - Icône `mappin.circle.fill` verte
  - Ligne 1 : **Ville** • Pays • Continent (cyan)
  - Ligne 2 : coordonnées monospacées `48.8566, 2.3522`
  - Icône `checkmark.circle` verte à droite
  - Background `.green.opacity(0.08)` avec `RoundedRectangle(cornerRadius: 6)`
  - Click → valide lat/lon dans config ET met à jour `location` avec "Ville, Pays"

### Fonction `continentFromCode()` (static, réutilisable)
- Nouvelle méthode statique `SettingsView.continentFromCode(_ code: String?) -> String`
- Map ISO 3166-1 alpha-2 → nom de continent
- Couvre Asia (JP, KR, CN, HK, TW, SG, …), Oceania (AU, NZ, …), North/South America, Africa
- Set `.european` de 40 codes pour l'Europe
- Retourne `""` pour les codes inconnus

### MenuBarView — Géocodage dans le champ Location
- Ajout `import CoreLocation` et états de géocodage identiques
- `onChange(of: vm.config.location)` → déclenche le géocodage avec debounce 600ms
- Sous le champ TextField :
  - Si résolu : bouton vert identique au style Settings (formatage compact pour 280px)
  - Si en cours : `ProgressView()` mini + "Resolving…"
  - Si erreur : icône `location.slash` orange + message
- Click sur le bouton → valide coordonnées + met à jour le nom de location → masque le bouton
- Réutilise `SettingsView.continentFromCode()` pour le continent

---

## Résumé des fichiers (mis à jour phase 29)

### Fichiers créés (2)
| Fichier | Rôle |
|---------|------|
| `VPNTools/Views/PreflightCheckView.swift` | Popup modal de vérification des dépendances |
| `generate_icon.py` | Script Pillow de génération de l'icône app |

### Fichiers modifiés côté Swift (9)
| Fichier | Modifications principales |
|---------|-------------------------|
| `VPNToolsApp.swift` | `@Environment(\.openSettings)`, passage closure `openSettings` à MenuBarView |
| `Models/SpeedTestModels.swift` | +`StatusEvent` (+ `count`, `totalAvailable`, `toLogEntry()`), +`LogEntry` (classify), enrichissement `ServerResult` (7 champs), `--machine-readable` dans `cliArguments` |
| `Models/SpeedTestViewModel.swift` | +`logEntries`, +`handleStatus()`, +continent/viable/expansion tracking, réécriture `updateProgress()`, `onStatus` callback, `status.toLogEntry()` |
| `Services/SpeedTestRunner.swift` | Réécriture complète : JSON parser, `toolPaths`/`enrichedPath`, `onStatus` callback, `parseJSONStatusLine()` (+ count/totalAvailable), `disconnectMullvad()`, `@MainActor` dispatch |
| `Services/DependencyManager.swift` | `findCommand()` remplace `isCommandAvailable()`, `foundPath`, `hasChecked`, `pythonPath`, `findPython()`, PATH enrichi pour installs |
| `Views/ContentView.swift` | Preflight overlay ZStack, header enrichi continent/viable/expansion |
| `Views/MenuBarView.swift` | `openSettings` closure, ordre inversé progress/results, continent/viable/expansion, section deps simplifiée, géocodage CLGeocoder + bouton ville/pays/continent |
| `Views/ResultsView.swift` | +colonne Jitter, +icône viable, LogView v2 (SF Symbols, StatusEvent→LogEntry, toolbar enrichie, auto-scroll animé) |
| `Views/SettingsView.swift` | CLGeocoder dynamique, bouton de validation riche (ville/pays/continent), `continentFromCode()` static, `stepperRow()` réutilisable, `ScrollView` onglet Test, frame 520px |

### Dépendance vpn-tools
Les modifications Python nécessaires sont documentées dans le [CHANGELOG vpn-tools v1.1.0](https://github.com/ArN-LaB/vpn-tools/blob/main/docs/CHANGELOG.md).

### Fichiers générés (icône)
| Fichier | Description |
|---------|-------------|
| `VPNTools.icns` | Icône macOS .icns (294 KB) |
| `Assets.xcassets/AppIcon.appiconset/icon_*.png` | 11 PNG (16×16 → 1024×1024) |
| `Assets.xcassets/AppIcon.appiconset/icon_master_1024.png` | Master haute résolution |

---

## Phase 30 — LocationResolver (fix géocodage CLGeocoder)

**Objectif** : Corriger 5 bugs liés au géocodage CLGeocoder qui retournait des résultats erronés (madrid → Macau, lima → Haidong, Sydney/Vienne en "Asie", Bordeaux introuvable, validation persistante).

**Cause racine** : `CLGeocoder.geocodeAddressString()` est non fiable pour les noms courts de villes — il retourne des résultats incorrects selon la locale macOS (ex: "madrid" → "Macau SAR, China").

**Solution** : Nouveau service `LocationResolver` qui interroge la base Mullvad (`coordinates.json`, ~90 villes) **avant** CLGeocoder.

### Nouveau fichier

| Fichier | Description |
|---------|-------------|
| `Services/LocationResolver.swift` | Service singleton qui charge `coordinates.json` (bundled ou dev fallback), construit un index ville→coordonnées, et résout instantanément les noms de villes Mullvad. Inclut `countryContinent` (nom pays → continent) et `continentFromCode()` (ISO alpha-2 → continent, ex-`SettingsView.continentFromCode`). |

### Modifications

| Fichier | Changements |
|---------|-------------|
| `Views/SettingsView.swift` | `geocodeCity()` : LocationResolver.shared.resolve() d'abord, CLGeocoder en fallback. `skipNextGeocode` flag pour éviter re-géocodage après validation. Suppression de `static func continentFromCode()` (déplacée dans LocationResolver). |
| `Views/MenuBarView.swift` | Idem : `skipNextGeocode`, LocationResolver en priorité, button action nettoie resolved* et set skip flag. Affichage last-result avec hostname du serveur (✓ hostname ↓ speed ((•)) ping). |
| `Views/ContentView.swift` | Last-result dans statusBadge affiche hostname du serveur testé pour clarifier la provenance des valeurs. |

### Bugs corrigés

1. **Mauvaise ville** : "madrid" → Madrid, Spain (via coordinates.json) au lieu de "Macau SAR" (CLGeocoder)
2. **Validation persistante** : `skipNextGeocode` empêche onChange de re-déclencher geocodeCity après validation
3. **Continents erronés** : Résolution via `countryContinent` dict (nom pays → continent) au lieu de dépendre de CLGeocoder pour le country code
4. **Bordeaux introuvable** : Présent dans coordinates.json → résolu instantanément
5. **Valeurs last-result** : Hostname du serveur affiché à côté des stats pour éviter la confusion avec le serveur en cours de test

### Flux de résolution

```
geocodeCity(input)
  1. LocationResolver.shared.resolve(input)     ← coordinates.json (~90 villes Mullvad)
     → Match exact "Madrid, Spain"
     → Match ville seule "madrid" → "Madrid, Spain"
     → Si trouvé : set resolved* immédiatement, return
  2. CLGeocoder fallback (avec debounce 600ms)   ← pour villes hors Mullvad
     → LocationResolver.continentFromCode(isoCountryCode)
```

---

## Build (mis à jour)

```bash
# Compilation Swift (debug)
cd VPNTools-macOS && swift build

# Build app bundle (release)
bash build_app.sh
# → VPN Tools.app (3.0 MB)

# Régénérer l'icône
python3 generate_icon.py

# Installation
cp -R 'VPN Tools.app' /Applications/
open '/Applications/VPN Tools.app'

# Tests Python
cd vpn-tools && python3 -m pytest tests/ -q
# → 8/8 passed
```

---

## Phase 31 — ResultsTableView redesign + StatsCardsView

**Fichiers modifiés** : `Views/ResultsView.swift`, `Models/SpeedTestViewModel.swift`

### Problème
La table de résultats affichait une liste brute de serveurs sans résumé visuel. Aucun indicateur de performance globale, et les colonnes manquaient de hiérarchie visuelle.

### StatsCardsView (nouveau composant)
- Trois cartes de statistiques agrégées affichées au-dessus de la table :
  - **Download moyen** : vitesse moyenne en Mbps sur tous les serveurs viables
  - **Ping moyen** : latence moyenne en ms
  - **Serveurs viables** : compteur N/M (viables sur testés)
- Chaque carte : fond sombre semi-transparent, icône SF Symbol colorée, valeur monospaced, label secondaire
- Mise à jour réactive via `@ObservedObject vm`

### Table résultats enrichie
- Colonne **Continent** ajoutée (cyan, affiche le continent du serveur)
- Colonne **Distance** affichée en km arrondi
- Colonne **Jitter** supprimée plus tard (toujours 0.0 — `speedtest-cli --json` ne retourne pas ce champ)
- Colonnes réordonnées : Serveur | Ville | Pays | Continent | Distance | ↓ Download | Ping
- Badge "viable" (✓ vert) et icône d'avertissement (⚠ orange) pour non-viable
- Ligne "meilleur serveur" mise en évidence avec fond `.green.opacity(0.08)`

### ViewModel — nouveaux publiés
- `averageDownload: Double` — moyenne download sur viables
- `averagePing: Double` — moyenne ping sur viables
- `currentServerContinent: String` — continent du serveur en cours de test
- `currentServerDistance: Double` — distance de référence en km

---

## Phase 32 — Fix détection continent (user vs serveur)

**Fichiers modifiés** : `Views/ContentView.swift`, `Views/MenuBarView.swift`, `Models/SpeedTestViewModel.swift`

### Problème
Les labels de continent dans le header Dashboard et dans MenuBarView affichaient parfois le continent **de l'utilisateur** (référence) au lieu du continent **du serveur en cours de test**. Confusion dans le contexte géographique affiché.

### Corrections
- `currentServerContinent` publié par le ViewModel suit strictement le continent du serveur testé (champ `continent` de l'événement `StatusEvent`)
- `userContinent` nouveau publié distinct : continent de la ville de référence de l'utilisateur (calculé depuis `config.location` via `LocationResolver`)
- Dashboard header : affiche `userContinent` (fixe, lieu de référence) vs `currentServerContinent` (dynamique, serveur testé)
- MenuBarView : même séparation user/serveur dans le bloc progression
- Fix `handleStatus()` : la phase `calibration` transmet correctement le continent serveur, la phase `calibration_test` le met à jour par serveur

---

## Phase 33 — Préflight startup + affichage progressif des étapes

**Date** : Session courante

**Fichiers modifiés** : `VPNToolsApp.swift`, `Views/PreflightCheckView.swift`, `Views/MenuBarView.swift`, `Models/SpeedTestViewModel.swift`

### Fenêtre préflight au démarrage
- `@AppStorage("hidePreflightAtStartup")` : booléen mémorisé entre sessions
- Case à cocher "Ne plus afficher au prochain lancement" dans `PreflightCheckView` — visible uniquement quand `depManager.allInstalled`
- Comportement : fenêtre préflight s'ouvre au démarrage **sauf** si l'utilisateur a coché la case ET que tout est installé
- `NSApp.activate(ignoringOtherApps: true)` pour s'assurer que la fenêtre préflight passe au premier plan même si l'app est lancée depuis le menu bar

### MenuBarView — nettoyage visuel
- Suppression de la ligne "dernier serveur testé" (redondante avec la table de résultats)
- Moyennes (download avg, ping avg) déplacées **au-dessus** du bloc meilleur serveur
- Compteur "tested" retiré du bloc progression (non pertinent dans cette zone)

### Affichage progressif des étapes (première itération)
- Indicateur d'étape dans MenuBarView affichant l'étape courante : `connecting → stabilizing → testing → mtr`
- Chaque étape colorée selon son état : gris (en attente), cyan (active), vert (complète)
- Affiché dès le début d'un test, masqué quand idle

---

## Phase 34 — TestStep/StepStatus + suppression sidebar

**Date** : Session courante

**Fichiers modifiés** : `Models/SpeedTestViewModel.swift`, `Models/SpeedTestModels.swift`, `Views/ContentView.swift`

> **Prérequis vpn-tools** : `CONTINENT_MAPPING` complet (tous codes pays Mullvad) — voir [CHANGELOG vpn-tools v1.1.0](https://github.com/ArN-LaB/vpn-tools/blob/main/docs/CHANGELOG.md).

### TestStep / StepStatus (Swift)
- Nouveau model `StepStatus` (enum) :
  - `.pending` — étape pas encore démarrée
  - `.active` — étape en cours (animation)
  - `.done(String?)` — étape terminée avec valeur optionnelle (ex: "45.2 Mbps")
- Nouveau struct `TestStep` (Identifiable, Hashable) : `id: String`, `label: String`, `status: StepStatus`
- `makeTestSteps() -> [TestStep]` : 4 étapes fixes `[connect, stabilize, speedtest, mtr]`
- `makeCalibrationSteps() -> [TestStep]` : 2 étapes `[connect, calibrate]`
- `@Published var currentTestSteps: [TestStep]` remplace le simple `String` de phase
- `activateStep(_ id:)` : dérive l'ordre depuis `currentTestSteps.map(\.id)` — dynamique, non codé en dur
- `userContinent: String` publié : continent de l'utilisateur (lieu de référence), affiché dans le header

### Suppression de la sidebar Dashboard
- Le Dashboard utilisait une `NavigationSplitView` à 2 colonnes (liste de serveurs à gauche + détails à droite)
- Sidebar supprimée — vue unique centrée sur les onglets
- Stats (StatsCardsView) déplacées dans l'onglet **Results** au-dessus de la table
- Continent de l'utilisateur (`userContinent`) affiché dans le header à côté de l'origine (ville de référence)

---

## Phase 35 — Refonte UI/UX complète (MenuBar, Settings, Préflight, Résultats)

**Date** : Session courante

**Fichiers modifiés** : `VPNToolsApp.swift`, `Views/ContentView.swift`, `Views/MenuBarView.swift`, `Views/ResultsView.swift`, `Views/SettingsView.swift`, `Views/PreflightCheckView.swift`, `Views/StartupPreflightView.swift`, `Models/SpeedTestViewModel.swift`

### 35a — MenuBar élargi + étapes en ligne horizontale

**MenuBar width** : 280px → 350px → **356px** final  
**Étapes** : colonne unique → grille 2×2 → **`HStack` horizontal** (identique au header Dashboard)

```swift
// MenuBarView.swift — étapes en ligne
HStack(spacing: 12) {
    ForEach(vm.currentTestSteps) { step in
        StepPillView(step: step)
    }
}
```

- Chaque étape : pastille compacte avec label + icône d'état
- Cohérence visuelle parfaite entre MenuBar et Dashboard header

### 35b — Fix étape MTR (pipeline calibration séparé + reset différé)

**Problème** : L'étape MTR n'apparaissait jamais en état `.done` — le statut `testing` du serveur suivant déclenchait un reset immédiat des étapes avant que le rendu SwiftUI ne capture l'état `.done`.

**Solution** :
```swift
// SpeedTestViewModel.swift
var stepResetTask: Task<Void, Never>?

// Quand phase "testing" reçue → reset différé 600ms
stepResetTask = Task { @MainActor in
    try? await Task.sleep(nanoseconds: 600_000_000)
    currentTestSteps = makeTestSteps()
}

// Quand phase "connecting" reçue → flush immédiat du reset
stepResetTask?.cancel()
stepResetTask = nil
currentTestSteps = makeTestSteps()
```

**Pipeline calibration séparé** : `makeCalibrationSteps()` retourne 2 étapes `[connect, calibrate]` utilisées uniquement pendant la phase de calibration — évite d'afficher 4 étapes inutiles lors de la calibration initiale.

> **Prérequis vpn-tools** : `mtr_running` n'est émis que lorsque `download_speed > 0` — évite d'activer l'étape MTR pour les serveurs non-viables. Voir [CHANGELOG vpn-tools v1.1.0](https://github.com/ArN-LaB/vpn-tools/blob/main/docs/CHANGELOG.md).

### 35c — Settings intégré dans Dashboard (suppression scène séparée)

- Scène `Settings { SettingsView() }` **supprimée** de `VPNToolsApp.swift`
- `@Environment(\.openSettings)` supprimé partout
- `SettingsView` devient le **3ème onglet** du Dashboard : Results (0) | Log (1) | **Settings (2)**
- `.frame(width: 480, height: 520)` retiré de `SettingsView` (elle s'adapte au Dashboard)
- Bouton "Settings…" dans MenuBarView :

```swift
// MenuBarView.swift
Button("Settings…") {
    NotificationCenter.default.post(name: .openSettingsTab, object: nil)
    openDashboard()
}
```

- `ContentView.swift` :

```swift
extension Notification.Name {
    static let openSettingsTab = Notification.Name("openSettingsTab")
}

// Dans MainContentView
.onReceive(NotificationCenter.default.publisher(for: .openSettingsTab)) { _ in
    selectedTab = 2
}
```

### 35d — Préflight obligatoire au premier lancement

- `@AppStorage("hasCompletedFirstPreflight")` ajouté dans `VPNToolsApp.swift` et `PreflightCheckView.swift`
- Logique de déclenchement :

```swift
// VPNToolsApp.swift
if !hasCompletedFirstPreflight || !hidePreflightAtStartup {
    openWindow(id: "preflight")
    NSApp.activate(ignoringOtherApps: true)
}
```

- Bouton "Dismiss" dans `PreflightCheckView` : `hasCompletedFirstPreflight = true`
- Case "Don't show at next launch" uniquement quand `depManager.allInstalled` (dépendances OK)
- `StartupPreflightView` : `.onAppear { NSApp.activate(ignoringOtherApps: true) }` — garantit le premier plan même si l'app est lancée en arrière-plan

### 35e — Barre de statut dépendances dans le header Dashboard

- `HeaderView` dans `ContentView.swift` utilise `@EnvironmentObject var depManager: DependencyManager`
- Barre de statut sous le titre dashboard :
  - Vert : "● All installed" si `depManager.allInstalled`
  - Orange : "● N missing" avec liste des outils manquants sinon
- Permet de voir d'un coup d'œil si l'environnement est prêt sans ouvrir la préflight

### 35f — Compteur viable déplacé + "tested" supprimé

- Compteur "N tested" retiré définitivement du bloc progression MenuBar
- Compteur viable "• N/M viable" déplacé dans le **bloc meilleur serveur** (à côté de la ville/pays)
- Résultat : progression plus épurée, context viable dans la zone résultats

### 35g — Colonne Jitter → MTR latency + badge "non-viable"

**Jitter supprimé** : `speedtest-cli --json` ne retourne pas de champ `jitter` — la colonne affichait toujours 0.0.

**Colonne MTR latency** :
```swift
// ResultsView.swift
TableColumn("MTR") { result in
    Text(result.mtrLatency > 0 ? String(format: "%.0f ms", result.mtrLatency) : "—")
        .foregroundStyle(result.mtrLatency > 0 ? .primary : .secondary)
}
```

**Badge "non-viable"** : le triangle ⚠ orange (illisible à petite taille) remplacé par une capsule texte :
```swift
// ResultsView.swift
if !result.isViable {
    Text("non-viable")
        .font(.caption2)
        .padding(.horizontal, 5).padding(.vertical, 2)
        .background(Capsule().fill(Color.orange.opacity(0.25)))
        .foregroundStyle(.orange)
}
```

### 35h — Dashboard — ratio d'or (φ ≈ 1.618)

- Taille par défaut : **900 × 556 px** (900 / 556 ≈ 1.618)
- Taille minimale : **700 × 433 px** (700 / 433 ≈ 1.617)

```swift
// VPNToolsApp.swift
Window("VPN Tools", id: "dashboard") {
    MainContentView()
        .frame(minWidth: 700, minHeight: 433)
}
.defaultSize(width: 900, height: 556)
```

---

## Résumé des fichiers (mis à jour — Phase 35)

### Fichiers créés (3)
| Fichier | Rôle |
|---------|------|
| `VPNTools/Views/PreflightCheckView.swift` | Popup modal de vérification des dépendances |
| `VPNTools/Views/StartupPreflightView.swift` | Fenêtre préflight dédiée au premier lancement |
| `generate_icon.py` | Script Pillow de génération de l'icône app |

### Fichiers modifiés côté Swift (9)
| Fichier | Modifications principales |
|---------|-------------------------|
| `VPNToolsApp.swift` | Scène Settings supprimée, `hasCompletedFirstPreflight` AppStorage, préflight obligatoire 1er lancement, `openSettings` retiré, taille Dashboard ratio d'or 900×556 |
| `Models/SpeedTestModels.swift` | `StepStatus` enum (pending/active/done), `TestStep` struct Identifiable+Hashable |
| `Models/SpeedTestViewModel.swift` | `makeTestSteps()` 4 étapes, `makeCalibrationSteps()` 2 étapes, `activateStep()` dynamique, `stepResetTask` (reset différé 600ms), `userContinent` publié |
| `Services/SpeedTestRunner.swift` | Inchangé depuis Phase 30 |
| `Services/DependencyManager.swift` | Inchangé depuis Phase 30 |
| `Views/ContentView.swift` | 3 onglets Results/Log/Settings, `Notification.Name.openSettingsTab`, `HeaderView` barre statut dépendances, `userContinent` dans header |
| `Views/MenuBarView.swift` | Largeur 356px, étapes HStack horizontal, bouton Settings via notification, viable dans bloc meilleur serveur, "tested" supprimé |
| `Views/ResultsView.swift` | Colonne Jitter → MTR latency, triangle → capsule "non-viable" texte, StatsCardsView au-dessus de la table |
| `Views/SettingsView.swift` | `.frame()` retiré (onglet Dashboard), intégration sans redimensionnement fixe |

### Dépendance vpn-tools
Les modifications Python nécessaires sont documentées dans le [CHANGELOG vpn-tools v1.1.0](https://github.com/ArN-LaB/vpn-tools/blob/main/docs/CHANGELOG.md).

---

## Phase 36 — Gestion MTR fallback (mtr_ping_fallback + badge ping)

**Date** : 9 mars 2026

**Fichiers modifiés** : `Models/SpeedTestModels.swift`, `Models/SpeedTestViewModel.swift`, `Views/ResultsView.swift`

**Contexte** : vpn-tools v1.1.0 introduit un fallback automatique vers `ping` lorsque `mtr-packet` Homebrew ne peut pas ouvrir de raw sockets (voir Phase 38 pour le diagnostic complet). Deux nouveaux événements sont émis : `mtr_ping_fallback` et `mtr_failed`.

### SpeedTestModels.swift — toLogEntry()
- `mtr_ping_fallback` → entrée `.warning` : “MTR unavailable — using ping (macOS Tahoe / mtr 0.96 incompatibility)”
- `mtr_failed` → entrée `.warning` : “MTR failed — no latency data”

### SpeedTestViewModel.swift — handleStatus()
- `mtr_ping_fallback` : active l'étape “mtr” normalement (l'utilisateur voit la progression sans interruption)
- `mtr_failed` : no-op silencieux (l'étape MTR reste en attente, le test continue)
- `updateProgress()` : reconnaît les textes “ping test in progress” et “mtr unavailable” pour afficher l'étape active

### ResultsView.swift — colonne MTR
- Lorsque `result.mtrHops == 0` (signal de fallback) : affiche la latence en ms + badge gris “ping” dans une `Capsule`
- Largeur de colonne agrandie : `min:60, ideal:85` (accommode badge + valeur)

```swift
// ResultsView.swift — badge fallback
if result.mtrHops == 0 && result.mtrLatency > 0 {
    HStack(spacing: 4) {
        Text(String(format: "%.0f ms", result.mtrLatency))
        Text("ping")
            .font(.caption2)
            .padding(.horizontal, 4).padding(.vertical, 2)
            .background(Capsule().fill(Color.secondary.opacity(0.2)))
            .foregroundStyle(.secondary)
    }
}
```

---

## Phase 37 — Visibilité ping fallback sur toutes les surfaces UI

**Date** : 9 mars 2026

**Fichiers modifiés** :
- `Models/SpeedTestViewModel.swift` — `usePingFallback` flag + label MTR→Ping dynamique
- `Views/ContentView.swift` — indicateur "Ping mode" dans le header Dashboard
- `Views/MenuBarView.swift` — badge "ping" dans le résumé best server

**Contexte** : Phase 36 ne rendait le fallback visible que dans la table ResultsView. L'utilisateur ne pouvait pas voir la différence pendant l'exécution ni dans le MenuBar.

### SpeedTestViewModel.swift
- Nouveau `@Published var usePingFallback: Bool` (reset à `false` dans `startTest()`)
- `mtr_ping_fallback` handler : met `usePingFallback = true`, change le label de l'étape "mtr" de "MTR" à "Ping" et l'icône à `wave.3.right`
- `TestStep.icon` et `.label` passés de `let` à `var` pour permettre la mutation

### ContentView.swift — Header Dashboard
- Affiche `Label("Ping mode", systemImage: "wave.3.right")` en orange dans la barre de sous-titre quand `vm.usePingFallback == true`
- Tooltip : "MTR unavailable — using ping fallback"

### MenuBarView.swift — Best server
- Quand `best.mtrHops == 0 && best.mtrLatency > 0` : badge gris "ping" en capsule à côté de la latence

### vpn-tools Python — format_mtr_results()
- `display_manager.py` : le label passe dynamiquement de "MTR" à "Ping" selon `result.hops == 0`
- Le champ "Hops:" n'est affiché que si `hops > 0`

---

## Phase 38 — Diagnostic mtr-packet SUID (cause racine)

**Date** : 9 mars 2026

**Fichiers modifiés** (vpn-tools) : `README.md`, `docs/CHANGELOG.md`

**Contexte** : Le fallback ping (Phase 36) était basé sur l'hypothèse d'une incompatibilité kernel Darwin 25.3.0 / macOS 26 Tahoe avec les raw sockets. Une investigation approfondie a identifié la vraie cause.

### Diagnostic

Tests effectués :

| Test | Résultat |
|---|---|
| Programme C : `socket(SOCK_RAW, IPPROTO_ICMP)` sous sudo | **Fonctionne** (fd=3) |
| `sudo traceroute -I` | **Fonctionne** |
| `sudo mtr` (Homebrew) | **Échoue** : `Failure to open IPv4 sockets` |
| mtr compilé depuis les sources (`/tmp/mtr-src/`) | **Fonctionne** sous sudo |
| mtr Homebrew + `MTR_PACKET=/tmp/mtr-src/mtr-packet` | **Fonctionne** |

### Cause racine

`brew install mtr` installe `mtr-packet` avec le bit SUID activé mais **owned par l'utilisateur courant** (pas root) :

```
-r-sr-xr-x  1 luc  admin  55624  mtr-packet
```

Quand `mtr` fork+exec `mtr-packet` (via `execlp`), le SUID force `euid = owner = 501 (luc)` — même sous sudo. `socket(SOCK_RAW)` échoue avec `EPERM` car l'euid effectif n'est pas root.

Debug binaire modifié confirmant :
```
# Via symlink Homebrew → euid forcé à 501
DEBUG open_ip4: uid=0 euid=501
DEBUG SOCK_RAW+ICMP failed: errno=1 (Operation not permitted)

# Même binaire lancé directement → euid=0
DEBUG open_ip4: uid=0 euid=0
DEBUG open_ip4 SUCCESS: icmp=3 udp=4 recv=5
```

### Fix

```bash
sudo chown root:wheel $(brew --prefix)/Cellar/mtr/0.96/sbin/mtr-packet
sudo chmod 4755 $(brew --prefix)/Cellar/mtr/0.96/sbin/mtr-packet
```

Résultat : SUID + owner=root → `euid=0` → raw sockets autorisés → **mtr fonctionne sans sudo**.

### Impact

- Ce n'est **pas** un bug kernel Darwin 25.3.0 ni une restriction macOS Tahoe
- Le fallback ping (Phase 36–37) reste pertinent pour les machines où le fix n'est pas appliqué
- README et CHANGELOG vpn-tools mis à jour avec le diagnostic corrigé et les instructions de fix

---

## Build (mis à jour — Phase 35)

```bash
# Compilation Swift (debug)
cd VPNTools-macOS && swift build

# Build app bundle (release)
bash build_app.sh
# → VPN Tools.app (3.0 MB)

# Régénérer l'icône
python3 generate_icon.py

# Installation
cp -R 'VPN Tools.app' /Applications/
open '/Applications/VPN Tools.app'

# Tests Python
cd vpn-tools && python3 -m pytest tests/ -q
# → 8/8 passed ✓
```
