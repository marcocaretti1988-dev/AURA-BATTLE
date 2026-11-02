# AURA BATTLE

Gioco arcade di sfide a colpi di balletti, pose e *aura farming* nelle piazze italiane.
6 personaggi 3D (Meshy) ballano a tempo di musica sopra una pista stile Guitar Hero; il pubblico in piazza reagisce, e vince chi fa più Aura Points.

## Cartelle

| Cartella | Cosa contiene |
|---|---|
| [`web/`](web/) | **Il gioco completo e giocabile** (HTML + Three.js). Apri `web/index.html` da un server web, oppure attiva GitHub Pages sulla cartella. |
| [`godot/`](godot/) | **Progetto Godot 4** per l'app su App Store e Google Play: tutti i modelli, le piazze, le canzoni, i dati del gioco e gli script di base. Leggi [`godot/LEGGIMI_PER_IL_SOCIO.md`](godot/LEGGIMI_PER_IL_SOCIO.md). |
| [`sorgente/`](sorgente/) | Il codice sorgente della versione web (`template.html`), i dati dei personaggi aggiunti e gli strumenti usati per preparare modelli e canzoni. |

## Contenuti
- **Personaggi:** Masked Aura, Mr. Cavallo, Hug Monster, Red Titan, Stardust Muse, Steppe Warlord
- **Piazze:** Duomo (Milano), Piazza di Spagna (Roma), Plebiscito (Napoli), Colosseo (Roma), Piazza Maggiore (Bologna), Piazza della Vergogna (Palermo), ognuna con la sua canzone
- **Modalità:** Quick Battle / Tour d'Italia (5 sfide a velocità crescente), Free Style, Aura Challenge
- **Controlli:** pulsanti touch sul telefono; da tastiera 1-6 mosse, C combo, Spazio special, Esc pausa

## Giocarlo online con GitHub Pages
Settings → Pages → *Deploy from a branch* → `main`, cartella `/ (root)`. Il gioco sarà su
`https://marcocaretti1988-dev.github.io/AURA-BATTLE/web/`

## Aggiungere un personaggio Meshy (versione web)
Dalla cartella che contiene `template.html`, `build.py` e gli strumenti:
```
python3 add_char.py Meshy_..._All_Animations.glb foto.jpg id "NOME" "#colore" "NOME MOSSA SPECIALE"
python3 build.py
```
