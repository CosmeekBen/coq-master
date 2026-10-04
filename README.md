# Coq Master — MVP

Jeu Roblox de combat de coqs, synchronisé avec Roblox Studio via [Rojo](https://rojo.space).

## Installation (Mac)

```bash
# 1. Installer Rokit (gestionnaire d'outils) puis les outils du projet
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | sh
rokit install

# 2. Installer le plugin Rojo dans Studio
rojo plugin install

# 3. Lancer le serveur de sync
rojo serve
```

Dans Roblox Studio : ouvrir une place vide (Baseplate), onglet **Plugins → Rojo → Connect**.
Pour tester la sauvegarde en Studio : *Game Settings → Security → Enable Studio Access to API Services*.

## Contenu du MVP

| Fonction | Où |
|---|---|
| Équilibrage (oeufs, stats, ligues, prix) | `src/shared/Config.luau` |
| Données + sauvegarde DataStore | `src/server/Data.luau` |
| Bases / poulaillers / oeufs cliquables | `src/server/Plots.luau` |
| Combat (simulation auto, ligues) | `src/server/Combat.luau` |
| Logique serveur (achats, éclosion, combat) | `src/server/Main.server.luau` |
| Interface (boutique, coqs, combat) | `src/client/Main.client.luau` |

## Boucle de jeu

1. Les **poules** génèrent des plumes (🪶) en continu.
2. Les plumes achètent des **oeufs** (Boutique). Plus l'oeuf est rare, plus il faut de clics pour l'éclore et meilleures sont les stats du coq.
3. Clique sur l'oeuf dans ta base pour le casser → un coq naît.
4. Onglet **Coqs** : choisis ton combattant. Onglet **Combat** : lance un match de ligue (adversaire = coq d'un autre joueur connecté, sinon coq fantôme). Victoire = plumes + trophées, défaite = perte de trophées.

Tout le visuel est procédural (blocs colorés) en attendant tes modèles.

## Pistes pour la suite
Combats contre joueurs hors-ligne (snapshots en DataStore), niveaux/entraînement des coqs, classement global, vrais modèles/animations, sons, monétisation.
