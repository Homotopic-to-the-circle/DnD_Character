# Consignes pour Claude — DnD_Character (Fiches, app des joueurs)

App servie sur https://homotopic-to-the-circle.github.io/DnD_Character/ (GitHub Pages, branche `main`). Pousser directement sur `main` est autorisé par le propriétaire.

## Code partagé avec DnD_MJ
L'app MJ (dépôt **DnD_MJ**) est une copie de ce `index.html` avec des blocs MJ en plus (2ᵉ `<style>`, écrans MJ). Il n'y a **pas d'outil de génération** : toute modification du code commun (CSS du premier `<style>`, fonctions partagées) doit être appliquée **à l'identique dans les deux dépôts**, dans le même travail.

## Thème et couleurs (Dal-Mor UI) — obligatoire

Les couleurs, les polices et le thème jour / nuit viennent du dépôt commun **[dalmor-ui](https://github.com/Homotopic-to-the-circle/dalmor-ui)** (lire son README). Il est chargé dans `<head>` :
`<script src="/dalmor-ui/theme.js"></script>` puis `<link rel="stylesheet" href="/dalmor-ui/theme.css">` — ne pas les retirer, ne pas les déplacer après les styles de l'app.

- **Aucune couleur en dur** (ni dans le CSS, ni dans le HTML généré par le JS) : toujours `var(--bg)`, `var(--card)`, `var(--fg)`, `var(--muted)`, `var(--accent)`, `var(--line)`… Transparence : `color-mix(in srgb, var(--accent) 20%, transparent)`. Ombre : `rgba(var(--ombre), .3)`.
- Les couleurs se changent **dans dalmor-ui**, jamais ici. Le bloc `:root{…}` en haut du CSS n'est qu'un **secours** si dalmor-ui ne charge pas : ne pas y toucher.
- Il faut une variable qui n'existe pas ? L'ajouter dans `dalmor-ui/theme.css` (dans les deux thèmes) et l'utiliser ici avec une valeur de secours : `var(--nouvelle, #valeur)`.
- **Le thème (jour / nuit) se change uniquement depuis le d20 du Portail**, pour cette app seulement (clé `dalmor-theme:<app>`). Ne pas ajouter de bouton ni de réglage de thème dans l'app.
- Toujours vérifier un changement d'interface **dans les deux thèmes** (jour et nuit). Pour tester : `Dalmor.theme.set('nuit')` dans la console.
- Exceptions assumées : visionneuse d'images plein écran (toujours sombre), pages imprimables, canvas.

## Textes AideDD intégrés (sorts, dons, états, capacités de classe, espèces, traits, historiques, équipement, objets magiques)
Les textes complets sont dans Supabase (`ref_textes`, fonction `ref_textes()`, script `DnD_Character/supabase/08_textes_aidedd.sql`). `chargerTextes()` les télécharge (1×/semaine) dans le cache du navigateur `dalmor-textes` (jamais dans localStorage, réservé aux fiches). Un écouteur de clic en capture ouvre tout lien AideDD `spell/fr/…`, `feat/fr/…` ou `glossaire/etats/#…`, et tout lien `data-capa="classe|sous-classe|nom"` (posé par `itemLien` dans Fiches, clé `capa:…` via `cleCapa`) et `data-orig="trait|espèce|nom"` (traits, espèce, historique ; `cleOrig`), `data-equip="nom"` (armes, objets du sac ; `cleEquip`, sinon objet magique du même nom) et `data-botte` (`cleBotte`) ; liens `magic-item/fr/…` → `objmag:`, dans la fenêtre `.regle-fen` ; texte absent → lien AideDD normal. Le HTML est nettoyé (`texteSur`) avant affichage. Bloc identique dans les deux dépôts. Nouveaux textes sur le serveur → augmenter `TXT_V` (sinon les téléphones attendent 1 semaine).
