# MC Texture Rater

## Pflege dieser Datei (bei jeder Session)
Diese CLAUDE.md ist lebendig und wird mitgepflegt, nicht nur gelesen.
- Neue Erkenntnis ueber Architektur, Invarianten, Helfer, Stolperfallen oder Fahrplan, die hier fehlt oder praeziser gehoert: ergaenzen oder schaerfen.
- Veraltete Angabe (umgebautes oder entferntes Feature, erledigter Fahrplan-Punkt, geloeschter settings-Schluessel, nicht mehr zutreffende Stolperfalle): sofort loeschen oder korrigieren.
- Erledigte Fahrplan-Punkte raus aus "Offener Fahrplan". Wenn sie dauerhaft etwas beschreiben, in den Architektur- oder Invarianten-Teil ueberfuehren, sonst ganz weg.
- Aenderungen knapp, gleiche Sprache und gleicher Stil wie der Rest, keine Redundanz.
- Am Ende jeder Session die Datei kurz gegen den echten Code-Stand abgleichen.

## Zweck
Werkzeug zum Bewerten der Texturen eines Minecraft-Resource-Packs auf Skala 1–100. Endziel: jede Textur der Population auf mindestens 50 ("Durchgespielt"). Darauf aufgesetzt ein Level-/Rang-System als Motivationsschicht.

## Starten & Entwickeln
- `start.bat`: `python -m http.server 8000` aus `C:\ClaudeCode`, öffnet `http://localhost:8000/texture_rater/`. Server nötig, weil IndexedDB + `crypto.subtle` keinen `file://`-Kontext mögen.
- `node --check` prüft nur Syntax (und nur reines JS, nicht die HTML). Echter Test braucht ein geladenes ZIP im Browser — es gibt keine Testdaten.

## Stack & Architektur
- Single-File Vanilla JS: alles in `index.html` (HTML + `<style>` + `<script>`). **Bindend:** keine Build-Tools, keine Modulzerlegung, kein zweites JS-File.
- Einzige externe Abhängigkeit: JSZip per CDN (`<script>` im `<head>`).
- Speicher: IndexedDB `mc-texture-rater`, zwei Stores: `textures` (keyPath `id` = ZIP-Pfad) und `settings` (keyPath `key`). Helfer: `openDB`, `getAll`, `getOne`, `putOne`, `putAll`, `clearDB`.
- Texturobjekt-Felder: `id, name, category, hash, dataUrl, rating, flag, isDefault, rateOverride, prevRating, prevDataUrl`.

## Domänenmodell & Invarianten
- **Population / Repräsentanten** — `dashPopulation()` = `allTextures.filter(effectiveRatable)`. Eine Recolor-/Familien-Gruppe (`groups`, `groupByMember`) zählt nur über ihren Repräsentanten. Ausgeschlossen: `isDefault` (Vanilla-Default) und `isExcluded(t)`. Diese Menge ist die Basis für Durchschnitte, Tier-Leiter und XP.
- **Exclude (zentraler Helfer `isExcluded`)** — einzige Quelle für „ist ausgeschlossen". In einer Gruppe entscheidet **allein** die `rateOverride` des Repräsentanten (`repId`-Datensatz); ungruppiert die eigene `rateOverride`. Ein Nicht-Repräsentant trägt nie eigenständige exclude-Wirkung. Alle Zählungen (`effectiveRatable`, `dashPopulation`, Durchschnitte, XP, Tier-Leiter, Coverage, Anzeige) konsumieren `isExcluded`, nie direkt `t.rateOverride`. **Speicherung rep-only:** `toggleExclude`/`excludeCurrent`/`liftExclude` schreiben nur den Rep (bzw. die ungruppierte Textur), nie alle Mitglieder. Einzel-exclude eines Mitglieds bleibt gespeichert, wird in der Gruppe nur ignoriert und greift beim Verlassen/Auflösen wieder. **`ensureValidRep` ignoriert exclude** bei der Rep-Wahl (`!t.isDefault` reicht), damit der Rep Träger des Gruppen-exclude sein kann — sonst würde ein exkludierter Rep sofort ersetzt. `repEligible` (exclude disqualifiziert) gilt nur noch für die **Vorschlags**-Rep-Wahl in `chooseRep`. Rep-Wechsel → sofort `rateOverride` des neuen Reps; Auflösen → Mitglieder fallen auf eigene `rateOverride` zurück (beides automatisch, da kein Override angefasst wird). Nicht-Reps bieten in der Übersicht keinen exclude-Schalter; ihre Karte zeigt das GRUPPE-Icon, bei exkludierter Gruppe das AUSGESCHLOSSEN-Icon.
- **Gruppen-Controls (Bewerten-Cluster 4)** — Split-Control „Gruppen": Hauptklick (`#grp-open-btn`) toggelt das Verwaltungs-Panel (`groupPanelOpen` → `renderGroupPanel`), der Chevron-Teil rechts öffnet ein `<details>`-Dropdown direkt darunter (`.grp-pop`) mit „Nur Repräsentanten anzeigen" (`onlyReps`), „Vorschläge ergänzen" (`suggestGroups`), Trenner, „Markierungen zurücksetzen" (`clearFlags`). Daneben „Gruppieren" (`groupMode`, umbenannter Auswahl-Modus, Funktion unverändert). **Markierungen zurücksetzen** = `clearFlags`: löscht nur die NEU/GEÄNDERT-Badges des letzten ZIP-Diffs (`flag`), **nicht** Gruppen/Ratings/Exclude — nicht destruktiv, daher neutral.
- **Panel-Automatik** — Ein offenes Verwaltungs-Panel schließt bei jeder anderen Interaktion über **einen** zentralen Capture-Click-Hook (`document`, Phase `true`): schließt `groupPanelOpen`, außer der Klick liegt in `#grouppanel` oder auf `#grp-open-btn`. Nicht an jede Stelle einzeln kopieren.
- **Bewertung** Slider/Eingabe 1–100. decent-Schwelle 50 (`isDecent`, `effectiveRating` = `rating ?? 0`).
- **Bewerten-Übersicht: Kopf, Filter & Sortierung** — Oben der **Kennzahlen-Hero** (`#hero`, `renderHero`): Ø gesamt groß in Teal mit Glow (Text-Shadow analog zum XP-Balken), dazu Bewertet X/Y (blauer Balken), Durchgespielt 50+ X/Y (Teal-Balken, `effectiveRating>=50`) und die Ø-Schnitte der aktiven Kategorien. Basis ist die **Population** (`dashPopulation`), nicht die gefilterte Sicht. Ersetzt frühere Dropzone, obere Ordner-Checkboxen und Stats-Chipzeile (`#statsbar` entfernt; `#statusbar` trägt nur noch den Diff). Die Ordner-Checkboxen (`#categories`) sind eingeklappt, sichtbar nur über den Button „Erfasste Ordner" (`foldersOpen`, persistiert). Filterleiste in vier Clustern mit Trennern (`.fcluster`/`.fdiv`): Status · Selektoren (Erfasste Ordner, Sortierung, Kategorien) · Sichtbarkeit · Gruppen; Suche (`#tsearch`) rechtsbündig (`margin-left:auto`). Sortierung als Dropdown (`sortMode` low|high|alpha, Default `low`, `sortList` über `effectiveRating`). Sichtbarkeits-Schalter heißt jetzt **„Standard-Texturen anzeigen"** (invertiert: Haken an = Defaults sichtbar); intern weiter `hideDefault` (Default `true`). Suche (`searchText`, **nicht** persistiert) filtert die Übersicht live per Teilstring im `name`, case-insensitive, zusätzlich zu allen Filtern (`searchMatch` in `renderAll`). Tier-Leiter (`renderLadder`, Klick setzt `binFilter`) nur hier, **nicht** im Dashboard. `binFilter` fällt auf „Alle" (null) zurück, sobald ein anderer Filter angefasst wird: Kategorie (Checkbox + `#catfilter`), Status, Sortierung, „Standard-Texturen anzeigen".
- **Re-Upload-Diff** in `handleZip`: Vergleich über Pfad (`id`) + SHA-256-`hash`. Geänderte Textur → altes Bild/Rating nach `prevDataUrl`/`prevRating` gesichert, `rating = null`, `flag = "changed"`. Neue → `rating = null`, `flag = "new"`. Verschwundene → `flag = "removed"` (nicht gelöscht). null-Rating taucht wieder in der Queue auf.
- **Re-Upload-Einstieg (`renderDiffAction`)** — kontextuelle Aktion `#diff-rate-flagged` in der Diff-Zeile (`#statusbar`): erscheint nur solange die `diffbox` gefüllt ist UND `flaggedOpenCount()` > 0, Text „Nur diese bewerten (N)", löst `startRating(true)` aus (nur offene neue/geänderte). Verschwindet bei leerer `diffbox` (Markierungen zurückgesetzt) oder wenn nichts Geflaggtes mehr offen ist. Der Header-Button „Bewerten starten" bleibt der Voll-Queue-Einstieg.
- **Inline-Bewertung ohne Rebuild** — `openInlineEdit`-Commit ruft **nicht** `renderAll`, sondern `refreshTileRating` (Kachel in-place: Rating-Text + `unrated`-Klasse) + die billigen Kopf-Widgets `renderHero`/`renderLadder`/`renderRateBadge`. Bei `sortMode` low/high bleibt die Kachel bis zum nächsten vollen Rebuild an Ort (Position wird nicht nachsortiert). Die Vollbild-Bewertung ist davon unberührt.
- **Event-Log** `settings["ratingEvents"]`, append-only (`logRatingEvent`). Pro Eintrag: `ts, date` (lokaler Tag via `localDay`), `id, category, old, new, delta`. `crossedFifty` wird nicht mehr geschrieben; Alt-Events behalten das Feld unangetastet. Rating wird zentral über `applyRating` gesetzt.
- **Streak & Woche** (Dashboard) — Streak deltaunabhängig: aktiver Tag = jeder `localDay` mit ≥1 `ratingEvents`-Eintrag (`activeDaySet`, `currentStreak`, `bestStreak`). Wochenkarte zeigt distinkte bearbeitete Textur-`id`s + Summe positiver Deltas der laufenden Woche (kein „Abgaben"-Wording, kein Tagesziel).
- **XP/Level/Rang sind monoton** — einzige XP-Quelle ist der Akkumulator `earnedXP` (`settings["earnedXP"]`): `applyRating` verbucht `max(0, newVal - oldVal)` und persistiert sofort; Absenkungen ändern `earnedXP` nicht. **Migration:** fehlt der Schlüssel, setzt `refresh()` ihn einmalig auf Score-Summe der Population plus 20 je bewertetem Nicht-Repräsentanten (entspricht dem früheren Live-Stand, kein sichtbarer Sprung). `levelInfo(totalXP)` erwartet einen **rohen XP-Wert** (kein Populations-Array): `XP_PER_LEVEL = 700`, `level = floor(totalXP/700)` ohne Cap, `xpInLevel`, `progress`, `rankIndex = min(10, floor(level/10))`. **Nur XP/Level/Rang sind monoton** — Durchschnitt, Auf Stufe 50+, Durchgespielt, Queue, Coverage, Tier-Leiter bleiben live und fallen beim Absenken.
- **Session-Delta** — `startRating` merkt `snapshotEarnedXP = earnedXP`; `buildReport.gainedXP = earnedXP - snapshotEarnedXP` (nie negativ), `levelBefore = floor(snapshotEarnedXP/700)`. Kein eingefrorenes id-Set, kein `sessionXP`/`xpValue` mehr. `renderFinish` animiert `snapshotEarnedXP → earnedXP`; `buildReport` überspringt ausgeschlossene Texturen in den Listen.
- **Erfolge (Achievements)** — `ACHIEVEMENTS`-Registry: `{id,name,desc,cond(ctx),xp}`. `achievementCtx(pop,events)` liefert `decentCount/ratedCount/popLen/donePct/level/streak` (`level` aus `earnedXP`). `checkAchievements` schaltet neu erfüllte frei, persistiert `settings["achievements"]` (ID-Liste) und zeigt je einen Toast (`showAchievement` → `nextAchievement`, `soundAchievement`). Geprüft in `renderDashboard` (Pop + Events liegen vor). Dashboard-Karte `achievementsCardHtml`. **Seeds haben `xp:0`** — ein echter Achievement-XP-Bonus müsste beim Freischalten in `earnedXP` verbucht werden.
- **Ränge** `RANK_NAMES` (Holz, Stein, Bronze, Eisen, Gold, Redstone, Lapis, Smaragd, Amethyst, Diamant für Level 0–99; Netherit ab 100), Farben in `RANK_COLORS`. Anzeige überall über `rankLabel(level)`: <100 → `RANK_NAMES`, 100 → "Netherit", >100 → "Netherit N" (N = level − 100, offen nach oben). Die Rang-Leiter (`rankSegsHtml`) bleibt bei den 11 Namen, Netherit-Segment ab Level 100 dauerhaft `cur`.
- **XP-Animation nur aufwärts** — `animateStatus` setzt `toXP >= fromXP` voraus (Monotonie); Abwärts-Zweig, `easeDamped` und `fxLevelDown` sind entfernt. Bei Differenz <1 wird ohne Animation gesnappt.
- **Berichts-Zeitstempel** — `buildReport.time` = `localDay` + `"HH:MM Uhr"` (ohne Sekunden).
- **Durchgespielt** (Population auf ≥50) ist eine eigene Größe, unabhängig vom Level.

## Ansichten & Ablauf
- Drei Tabs (`#view-rate`, `#view-dashboard`, `#view-reports`) plus transienter Abschluss-Screen `#view-finish` nach Session-Ende. Umschalten ausschließlich über `setView` / `applyView`.
- Bewerten-Flow: `startRating` → `renderRate` → `commitRate` → bei leerer Queue `maybeFinish` → `finishSession` → `renderFinish` (baut Status-Hero `statusHeroHtml` + Listen, startet XP-Animation `snapshotEarnedXP` → `earnedXP`).
- **Backup-Erinnerung** — `exportReminderHtml()` liefert einen nicht blockierenden Hinweis mit direktem Export-Trigger, fällig (`exportReminderDue`) wenn `ratingsSinceExport > EXPORT_REMINDER_AFTER` (200) oder `lastExportAt` > 14 Tage her. Erscheint in `renderFinish` und `renderDashboard`; nach dem Einfügen via `innerHTML` jeweils `wireExportReminder(root)` aufrufen (kein automatischer Download ohne Nutzergeste).
- **Stolperfalle (so im Code gelöst):** Sektionen werden über das `hidden`-Attribut ein-/ausgeblendet. Eine eigene `display`-Regel würde `hidden` schlagen — darum explizit `#view-rate[hidden], … {display:none}`. Beim Hinzufügen neuer Ansichten mitziehen.

## Persistenz (`settings`-Schlüssel)
- `selectedCategories` — aktive Kategorie-Auswahl
- `baseline` — `{normPath: hash}` der Vanilla-Baseline für `isDefault`
- `hideDefault` — Standard-Texturen verbergen (Default `true`); UI-Schalter ist invertiert beschriftet („Standard-Texturen anzeigen")
- `foldersOpen` — „Erfasste Ordner"-Checkboxen ausgeklappt (Default `false`)
- `groups` — Gruppen `[{id,name,repId,memberIds}]`
- `sortMode` — Sortierung der Bewerten-Übersicht: `low` (niedrigste zuerst, Default) | `high` | `alpha`
- `ratingEvents` — Event-Log (s.o.)
- `earnedXP` — monotoner XP-Akkumulator; fehlt er, migriert `refresh()` einmalig vom Live-Stand
- `reports` — gespeicherte Session-Berichte (max. 50)
- `lastShownXP` — zuletzt animierter XP-Stand (verhindert Riesen-Animation beim Reload)
- `achievements` — Liste freigeschalteter Erfolg-IDs
- `view` — zuletzt aktive Ansicht
- `lastExportAt` — ISO-Zeit des letzten Backup-Exports (für Backup-Erinnerung)
- `ratingsSinceExport` — Zähler echter Wertänderungen seit letztem Export; `applyRating` +1, `exportBackup` → 0

## Konventionen (verbindlich)
- UI durchgängig **deutsch**.
- Dunkles Theme über die CSS-Variablen in `:root` — Farben **nicht** ändern (Aufgaben betreffen nur Größe/Layout/Anordnung).
- **Keine Emojis** im UI. Stattdessen Tabler-Outline-Icons als Inline-SVG (`ICON_FLAME`, `ICON_MEDAL`, `ICON_TROPHY`).
- Vorhandene Helfer wiederverwenden (`$`, `escapeHtml`, `fmtNum`, `localDay`, `effectiveRating`, `effectiveRatable` …) statt neu erfinden.
- Nutzerzustand immer in IndexedDB persistieren, nicht nur im RAM-State.
- Status-Hero (`statusHeroHtml`) ist identisch in Dashboard und Abschluss — nur einmal pflegen; doppelte `sp-*`-IDs vermeiden.

## Offener Fahrplan
- **Dashboard-Karte (Teil 2):** Stelle der früheren Tier-Leiter im Dashboard. **Offen, welcher Inhalt** — die neue Erfolge-Karte besetzt diese Stelle bereits; falls eine *andere* Karte gemeint ist, hier konkretisieren.
- **Sounds:** synthetisch via Web Audio (`synthTone`, `soundLevelUp`, `soundRankUp`, `soundAchievement`, `startSwoosh`). Später optional gegen echte Dateien tauschen — markierte Stelle „MARKER Sound-Hook" über `synthTone` (noch keine Dateien vorhanden).

## Bekannte Stolperfallen
- **CSS-Spezifität Ansichten:** siehe oben — `hidden` muss per `[hidden]{display:none}` durchgesetzt werden. Gilt auch für neue per `hidden` geschaltete Elemente (`#categories[hidden]`, `#dropzone-overlay[hidden]`).
- **ZIP-Import per Vollflächen-Overlay:** keine Dropzone mehr; `#dropzone-overlay` legt sich übers Fenster, sobald eine Datei darüber gezogen wird (Erkennung über `dataTransfer.types` enthält `Files`). Flacker-Schutz über `dragDepth`-Zähler (dragenter ++ / dragleave --, bei 0 ausblenden). Drop läuft über `handleZip`; „ZIP laden" im Header bleibt Fallback.
- **„Alles neu" beim Import:** im aktuellen Code kein Problem — `importBackup` schreibt die Datensätze verbatim (kein Re-Diff), und der ZIP-Diff in `handleZip` behält bei gleichem Hash Rating + `dataUrl`. Beim Ändern dieser Pfade die Hash-Gleichheit als Erhaltungsbedingung beibehalten.
