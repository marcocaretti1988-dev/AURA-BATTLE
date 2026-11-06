# AURA BATTLE – progetto Godot

Questo è il punto di partenza per portare Aura Battle in Godot e pubblicarlo su App Store e Google Play.
Il gioco originale è una pagina HTML (Three.js). Godot non può importare l'HTML: qui dentro ci sono **tutti i materiali del gioco, già pronti**, e **gli script di base, scritti da zero in GDScript**, che rifanno il cuore della battle.

> ⚠️ Gli script **non sono mai stati aperti in Godot**: sono stati scritti senza poterli eseguire. Aspettati qualche piccolo errore da correggere alla prima apertura (nomi di proprietà, tipi). La logica e i numeri invece sono gli stessi del gioco HTML.

## Come aprirlo
1. Godot **4.3 o più recente** (versione standard, non .NET).
2. *Importa* → scegli `project.godot`. Al primo avvio Godot importa i modelli GLB e le immagini (qualche minuto).
3. Premi Play: parte `scenes/menu.tscn`.

## Cosa c'è
| Cartella | Contenuto |
|---|---|
| `assets/characters/` | i 6 personaggi Meshy (`jester`, `horse`, `monster`, `titan`, `muse`, `warlord`): GLB riggati con tutti i balli (~20.000 triangoli, texture 1024), più la foto per la scheda (`*_card.jpg`) |
| `assets/crowd/` | 3 modelli del pubblico (GLB leggeri, ~2.600 triangoli) |
| `assets/venues/` | le 6 piazze (Milano, Roma Spagna, Napoli, Roma Colosseo, Bologna, Palermo) |
| `assets/music/` | canzone del menu + una canzone per ognuna delle 6 piazze |
| `data/game_data.json` | **tutti i numeri del gioco**: personaggi, quale ballo va su quale mossa, punteggi, round, difficoltà, velocità della pista, battiti misurati di ogni canzone, calibrazione delle piazze |
| `scripts/` | il codice (vedi sotto) |
| `reference/codice_originale_aura_battle.html` | il codice completo della versione HTML, da consultare per ogni dettaglio |

## Gli script
- `game_data.gd` (autoload `GameData`) – legge il JSON, tiene personaggio scelto, piazza, Tour d'Italia (5 rivali), difficoltà, salvataggio, tasti.
- `conductor.gd` – suona la canzone e calcola **il battito esatto** usando i tempi misurati sul file audio (non un bpm fisso). Fa il loop dopo l'intro senza perdere il tempo.
- `dancer.gd` – carica un personaggio, assegna i balli alle mosse, toglie lo spostamento del corpo (balla sul posto), **continua la coreografia da dove era rimasta**, lo tiene sopra il pavimento.
- `note_lane.gd` – la pista stile Guitar Hero (note normali, d'oro x3, doppie x2, lunghe da tenere).
- `battle.gd` – la sfida: 3 round, turno del giocatore con le note, turno dell'avversario (IA), punteggio, combo, barra aura e mossa speciale, hype del pubblico, annunciatore (sintesi vocale), voto finale S/A/B/C/D.
- `menu.gd` – scelta del personaggio, della piazza e della difficoltà.

## Regole principali (sono nel JSON e in `battle.gd`)
- Giudizio del tempismo: PERFECT ≤ 0,06 s (x1,5), GREAT ≤ 0,11 s (x1,25), GOOD ≤ 0,17 s (x1), altrimenti OFF BEAT (x0,5).
- Punti = base mossa × giudizio × combo (+15% a mossa, max 10) × pubblico (0,85–1,25) × CLEAN (x2 ogni 4 GREAT/PERFECT di fila).
- Ripetere la stessa mossa dimezza i punti e azzera la combo.
- Barra aura piena → SPECIAL; se cade sul primo battito della battuta +400 (MAX AURA).
- Round: 16 s / 22 s / 14 s. La pista accelera a ogni rivale (`speed_step` e `speed_ahead` nel JSON).

## Novità della versione web (6 novembre) già preparate qui
- **Progressione**: si parte con 3 personaggi e 3 piazze (`start_unlocked` nel JSON); battere un rivale nel Tour lo sblocca, vincere in una piazza la sblocca. Record e voto per ogni piazza. → già in `game_data.gd`, `menu.gd`, `battle.gd`.
- **Calibrazione audio**: `GameData.audio_offset` (secondi) è già usato dal `conductor.gd`. Manca la schermata: metronomo a 100 bpm, 8 tocchi, ritardo = mediana(tocco − click), tra 0 e 0,4 s.
- **Lingua IT/EN**: tutte le frasi tradotte sono in `i18n_en` nel JSON e `GameData.tr_text()` le applica (già usato per banner e scritte a comparsa). Manca il pulsante e la traduzione dei testi del menu.
- **Tasto illuminato**: il pulsante della prossima mossa si accende solo mezzo battito prima della nota (`hint_beats`).

## Cosa manca rispetto alla versione HTML
Da rifare guardando `reference/codice_originale_aura_battle.html` (cerca i nomi tra parentesi):
- **Tutorial giocato** (`Tutorial`): 8 passi già scritti in `tutorial` nel JSON, parte al primo PLAY
- **Condivisione** (`shareResult`): immagine 1080×1350 con piazza, personaggio, voto e punteggio → condivisione del telefono
- **Telecamera** (`camera(`): avvicinamento lento al ballerino durante il turno, piccolo scatto a ogni mossa, primi piani solo su CLEAN COMBO / nota d'oro / combo 6-9-12
- **Cielo** (`buildSky`): stelle che brillano a tempo, stelle che si accendono, stelle cadenti
- schermata VS animata tra i due sfidanti
- effetti: alone d'aura e scintille, colonna di luce della special, CO2, coriandoli, cerchio luminoso a tempo
- voci e cori del pubblico (fischi, "AU-RA!"), effetti sonori
- modalità Free Style e Aura Challenge, galleria personaggi, impostazioni, filtro notte
- il rivale che reagisce (ride, si impressiona) e il pubblico che si sposta verso il vincitore
- grafica dell'interfaccia (font pixel "Press Start 2P", icone delle mosse)

## Privacy
`privacy.html` (italiano + inglese) è la pagina da indicare negli store. Online è su
`https://marcocaretti1988-dev.github.io/AURA-BATTLE/web/privacy.html`. Aggiungete un'email di contatto prima della pubblicazione.

## Pubblicazione
- **iOS**: Editor → Gestisci modelli di esportazione → scarica i template; Progetto → Esporta → aggiungi *iOS*, inserisci Team ID e Bundle ID, esporta il progetto Xcode e da lì archivia e carica su App Store Connect (serve un Mac e l'account Apple Developer).
- **Android**: aggiungi *Android*, crea una keystore di release, esporta in formato **AAB** per Google Play.
- L'orientamento è già impostato su **orizzontale** (ruota da solo tra le due direzioni).
- L'icona in `assets/ui/icon.png` è ricavata dal logo, che è piccolo: per gli store serve un'icona 1024×1024 vera.
- Va attivata la sintesi vocale (già messa in `project.godot`: `audio/general/text_to_speech=true`).
