# AURA BATTLE – progetto Godot (completo)

Questa è la versione Godot **completa** di Aura Battle: tutto quello che c'è nel gioco web è stato rifatto in GDScript.
Si apre, si gioca e resta solo da esportare per App Store e Google Play.

> ✅ Provato con **Godot 4.7.2**: tutte le modalità sono state giocate da un bot automatico, senza errori di script (Tour, Free Style, Aura Challenge e Tutorial, più tutte le schermate del menu). Gli script delle prove sono nella cartella `tests/`.

> 🖥️ Il renderer è **Compatibility (OpenGL)**. Non va cambiato: con Vulkan/Forward+ sui Mac Intel la grafica si rompe, e Compatibility è anche la scelta più sicura per i telefoni.

> ⚠️ **Se i personaggi sono fermi in T-pose o la grafica è "sporca"**: chiudi Godot, cancella la cartella nascosta `.godot` dentro il progetto e riaprilo. Godot reimporta tutto in qualche minuto e il problema sparisce: era solo la cache vecchia.

## Come aprirlo
1. Usa **Godot 4.7** o più recente, nella versione standard (non .NET).
2. Scegli *Importa* e poi `project.godot`. Al primo avvio Godot importa i modelli e le immagini, e ci vuole qualche minuto.
3. Premi Play: parte `scenes/menu.tscn`.

## Cosa c'è nel gioco (tutto come nel web)

**Menu**
- C'è il logo, con il personaggio scelto che balla in grande in piazza e gli altri dietro, sulla canzone del menu.
- Le schermate sono queste:
  - **PLAY**: il Tour d'Italia contro 5 rivali. La prima volta parte da solo il tutorial.
  - **FREE STYLE**: si balla senza fine, e la pista accelera ogni 10 colpi.
  - **AURA CHALLENGE**: bisogna ripetere sequenze di mosse sempre più lunghe, con 3 vite.
  - **CHARACTERS**: la galleria. Per ogni personaggio si possono provare tutti i balli.
  - **SETTINGS**: musica, effetti, voce, difficoltà, piazze di notte, lingua, calibrazione dell'audio e link alla privacy.
  - **HOW TO PLAY** e **TUTORIAL** (8 passi guidati).
  - Il pulsante **IT/EN** cambia la lingua di tutto il gioco.
- **Progressione**: all'inizio sono disponibili 3 personaggi e 3 piazze. Gli altri si sbloccano vincendo. Viene salvato il record per ogni piazza.
- **Calibrazione audio**: si tocca a tempo con un metronomo e il ritardo dell'audio viene salvato.

**Battle**
- Si apre con la schermata **VS** con le foto dei due ballerini, poi ci sono 3 round con il turno del giocatore e il turno del rivale (IA).
- **Pista Guitar Hero**:
  - le note hanno l'icona della mossa;
  - quelle d'oro valgono x3, le doppie x2, e ci sono note lunghe da tenere premute;
  - la pista accelera man mano che si va avanti;
  - il tasto si illumina mezzo battito prima della nota.
- **Camera**: si avvicina al ballerino a ogni mossa, con primi piani sulle combo e sulla mossa speciale.
- **Effetti**:
  - aura e scintille intorno al ballerino;
  - colonna di luce e anello sulla mossa speciale;
  - coriandoli e getti di CO2;
  - stelle che brillano e stelle cadenti nel cielo.
- **Pubblico**:
  - 38 persone che ballano più forte quando l'hype sale e guardano chi sta ballando;
  - si sentono applausi, cori, fischi e "buu" sugli errori;
  - il rivale reagisce alle tue mosse.
- **Annunciatore** con la sintesi vocale del telefono, in italiano o in inglese.
- **Risultato finale**: il voto S/A/B/C/D, le statistiche (perfect/great/good/miss, combo migliore) e i nuovi sblocchi.
- Il pulsante **Condividi** crea un'immagine 1080×1350 con il risultato.
- **Pausa**: con il pulsante, con Esc, oppure da sola quando l'app va in background.

## Cartelle
| Cartella | Contenuto |
|---|---|
| `assets/characters/` | i 6 personaggi Meshy (`jester`, `horse`, `monster`, `titan`, `muse`, `warlord`) con tutti i balli, più la foto per la scheda |
| `assets/crowd/` | i 3 modelli del pubblico |
| `assets/venues/` | le 6 piazze: Milano, Roma Spagna, Napoli, Roma Colosseo, Bologna, Palermo |
| `assets/music/` | la canzone del menu più una canzone per ogni piazza |
| `assets/sfx/` | effetti sonori e suoni del pubblico (generati da noi, nessuna licenza esterna) |
| `assets/ui/` | logo, icone delle mosse, foto |
| `assets/fonts/` | Press Start 2P (licenza **SIL OFL**, gratuita anche per uso commerciale) |
| `data/game_data.json` | **tutti i numeri del gioco**: personaggi, balli per ogni mossa, punteggi, round, velocità, battiti delle canzoni, testi IT/EN |
| `scripts/` | il codice |
| `privacy.html` | la pagina della privacy (IT+EN), da mettere online e da indicare negli store |
| `reference/` | il codice HTML originale, da consultare |

## Gli script
- `game_data.gd` (autoload `GameData`): dati, modalità, sblocchi, record, salvataggio (`user://aura_battle_save.cfg`), lingua e tasti.
- `ui.gd` (autoload `UI`): font, pulsanti, pannelli, effetti sonori, audio del pubblico, voce dell'annunciatore.
- `conductor.gd`: tiene il tempo della musica sui battiti misurati, compreso il ritardo audio calibrato.
- `stage.gd`: la piazza 3D, cioè sfondo, pubblico, cielo, camera ed effetti.
- `dancer.gd`: il personaggio. Balla sul posto, continua la coreografia e non va sotto il pavimento.
- `note_lane.gd`: la pista con le note.
- `battle.gd`: la sfida e tutte le modalità (tour, free, challenge, tutorial), la schermata VS, la pausa, il risultato e la condivisione.
- `menu.gd`: tutte le schermate del menu.

## Comandi
- Su **telefono** si usano i pulsanti a schermo: le 6 mosse, COMBO e SPECIAL.
- Su **PC** si usano i tasti 1-6 per le mosse, C per COMBO, Spazio per SPECIAL ed Esc per la pausa.

## Da fare per pubblicare
1. **Template di esportazione**: in Godot vai su *Editor → Manage Export Templates → Download*.
2. **Android**:
   - installa Android SDK e JDK 17 e impostali in *Editor Settings → Export → Android*;
   - crea il preset Android: nome pacchetto (es. `com.aurabattle.game`), icona, orientamento orizzontale (è già impostato);
   - crea il keystore di release ed esporta un **AAB** per Google Play.
3. **iOS**:
   - serve un Mac con Xcode e l'account Apple Developer;
   - crea il preset iOS (Bundle ID, Team ID, icone), esporta il progetto Xcode, poi da Xcode fai *Archive* e carica su App Store Connect.
4. **Condividi**: per ora l'immagine viene salvata in `user://aura_battle_risultato.png`, e su PC si apre da sola. Per il menu "Condividi" nativo del telefono serve un plugin di share per Android e iOS (ce ne sono di gratuiti nell'Asset Library), da collegare alla funzione `_share()` in `battle.gd`.
5. **Store**:
   - schede, screenshot e link alla privacy (`privacy.html`);
   - classificazione dei contenuti (gioco musicale, nessun contenuto sensibile);
   - il gioco non raccoglie dati personali: il salvataggio resta sul telefono.

## Diritti
Canzoni (Suno, abbonamento a pagamento) e modelli 3D (Meshy, piano a pagamento) sono di proprietà di Marco. Il font è OFL, gli effetti sonori sono generati da codice.
