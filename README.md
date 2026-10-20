# Feuille de Perso

Fiche de personnage D&D 5.5 (2024) en français, pour téléphone, alimentée par les exports du créateur de personnage AideDD.

Application : https://homotopic-to-the-circle.github.io/DnD_Character/

## Exporter son personnage depuis AideDD

On utilise un **favori spécial** (un « bookmarklet ») : au lieu d'ouvrir une page, il lit la fiche AideDD affichée et en fait un texte à coller dans l'application. On ne le crée qu'une fois.

### 1. Créer le favori (une seule fois)

1. Copie tout le code ci-dessous (bouton de copie en haut à droite du bloc, ou appui long → Tout sélectionner → Copier). Il fait une seule ligne très longue, et il doit commencer par `javascript:`.
2. Ajoute n'importe quelle page en favori (celle-ci, par exemple).
3. Ouvre la liste des favoris, puis **modifie** ce favori :
   - **Nom** : `Export AideDD`
   - **Adresse (URL)** : efface tout et colle le code.
4. Enregistre.

Où trouver « Modifier » :
- **Firefox (Android)** : menu ⋮ → Favoris → ⋮ à côté du favori → Modifier.
- **Chrome (Android)** : menu ⋮ → Favoris → ⋮ à côté du favori → Modifier.
- **Safari (iPhone)** : icône livre → onglet Favoris → Modifier (en bas) → touche le favori.

Si le navigateur retire `javascript:` au début en collant, retape-le à la main.

```text
javascript:(async()=>{try{const $=i=>document.getElementById(i),v=i=>{const e=$(i);return e?(('value' in e&&e.tagName!=='DIV')?e.value:e.textContent).trim():''},ck=i=>{const e=$(i);return e?!!e.checked:false},L=i=>{const e=$(i);if(!e)return[];return e.innerHTML.split(/<br\s*\/?>|\n/i).map(s=>{const d=document.createElement('div');d.innerHTML=s;return d.textContent.trim()}).filter(s=>s&&s!=='...')},T=i=>v(i).split('\n').map(s=>s.trim()).filter(s=>s&&s!=='...'),fl=i=>{const e=$(i);return!!(e&&e.querySelector('.bxf'))},f=document.forms.form1;if(!f||!$('myAC')){alert('Page AideDD non reconnue : ouvre la fiche finale (Termine !)');return}const car=['FOR','DEX','CON','INT','SAG','CHA'].map((n,i)=>({n,val:+v('myCar'+i),mod:v('myBonus'+i),jds:v('myJds'+i),jdsM:ck('myJdsProf'+i)})),ski=[];for(let i=0;i<18;i++){const e=$('mySki'+i);if(e)ski.push({id:i,nom:((e.nextSibling&&e.nextSibling.textContent)||'').trim(),val:e.value,m:ck('mySkiProf'+i)})}const armes=[];for(let i=1;i<=6;i++)if(v('wname'+i))armes.push({nom:v('wname'+i),att:v('wbonus'+i),deg:v('wdg'+i),note:v('wnote'+i)});const capa=L('myFeatures1').concat(L('myFeatures2')).map(l=>{const m=l.match(/^(.+?)\s*\((\d+)\)$/);return m?{nom:m[1],max:+m[2]}:{nom:l}}),sorts=[];for(let i=0;i<75;i++){const n=$('sortName'+i);if(!n)break;const nom=n.textContent.trim();if(!nom)continue;const a=n.querySelector('a');sorts.push({niv:+v('sortLvl'+i),nom,url:a?a.href:'',inc:v('sortCast'+i),portee:v('sortRang'+i),C:fl('sortCon'+i),R:fl('sortRit'+i),M:fl('sortMat'+i),note:v('spellNote'+i)})}const choix={};f.querySelectorAll('input[type=hidden]').forEach(e=>choix[e.name]=e.value);let xml='';try{const r=await fetch(f.action,{method:'POST',body:new URLSearchParams(new FormData(f))});xml=await r.text()}catch(e){}const xmlOk=xml.includes('<creator>'),d={v:1,date:new Date().toISOString(),id:{nom:v('myName'),historique:v('myBack'),classe:v('myClass'),sousClasse:v('mySubClass'),espece:v('mySpecies'),niveau:v('myLevel'),xp:v('myXP'),alignement:v('myAlign'),taille:v('mySize')},combat:{ca:v('myAC'),pvMax:v('myHP'),dv:v('myDice'),maitrise:v('myPB'),init:v('myInit'),vitesse:v('mySpeed'),percPassive:v('myPerc')},car,ski,armes,capa,traits:T('myTrait'),dons:T('myFeats'),maitrises:{armures:{L:ck('profL'),I:ck('profM'),Lo:ck('profH'),B:ck('profS')},armes:v('profWeapons'),outils:v('profTools'),langues:v('profLanguages')},magie:{carac:v('mySpellAbi'),mod:v('mySpellMod'),dd:v('mySpellDC'),att:v('mySpellAtt'),slots:[1,2,3,4,5,6,7,8,9].map(k=>v('slot'+k))},sorts,equipement:v('myEquip'),harmo:[1,2,3].map(k=>v('myAttun'+k)).filter(Boolean),pieces:{pc:v('myCP'),pa:v('mySP'),pe:v('myEP'),po:v('myGP'),pp:v('myPP')},histoire:v('myBackstory'),choix,xml:xmlOk?xml:''},s=JSON.stringify(d),o=document.createElement('div');o.style.cssText='position:fixed;inset:0;z-index:99999;background:white;color:black;padding:12px;font:15px sans-serif;display:flex;flex-direction:column;gap:8px';o.innerHTML=`<b>Export ${d.id.classe} niv ${d.id.niveau}</b><div>${sorts.length} sorts, ${armes.length} armes, ${capa.length} capacites, XML ${xmlOk?'OK':'MANQUANT'} (${Math.round(s.length/1024)} Ko)</div><textarea style="flex:1;font:11px monospace"></textarea><button>Copier</button><button>Telecharger</button><button>Fermer</button>`;document.body.appendChild(o);const ta=o.querySelector('textarea'),b=o.querySelectorAll('button');ta.value=s;b[0].onclick=async()=>{try{await navigator.clipboard.writeText(s);b[0].textContent='Copie OK'}catch(e){ta.focus();ta.select();document.execCommand('copy');b[0].textContent='Copie (selection)'}};b[1].onclick=()=>{const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([s],{type:'application/json'}));a.download=(d.id.nom||'perso')+'.json';document.body.appendChild(a);a.click();a.remove()};b[2].onclick=()=>o.remove()}catch(e){alert('Erreur bookmarklet : '+e.message)}})();
```

Le même code est aussi dans le fichier [`bookmarklet-aidedd.txt`](bookmarklet-aidedd.txt).

### 2. Exporter le personnage

1. Crée ton personnage sur https://www.aidedd.org/dnd-creator/ jusqu'au bout, et appuie sur **Terminé !** pour afficher la fiche finale.
2. Lance le favori :
   - **Firefox et Chrome (Android)** : touche la barre d'adresse, tape `Export AideDD`, puis touche le favori dans les suggestions (pas la recherche web).
   - **Safari (iPhone)** : ouvre les favoris et touche `Export AideDD`.
3. Un écran blanc s'affiche avec le résumé (sorts, armes, capacités, « XML OK »). Appuie sur **Copier**.
4. Ouvre l'application, colle le texte dans **Importer**, puis appuie sur **Importer**.

### Monter de niveau

Dans l'application, onglet **Fiche** → **Télécharger le .xml**. Ouvre le créateur AideDD, importe ce fichier .xml et monte de niveau. Sur la nouvelle fiche finale, relance le favori et colle le résultat dans **Mettre à jour le personnage**. Les cases cochées, les notes, les armes et les sorts ajoutés sont conservés.

## Installer l'application sur le téléphone

Ouvre l'adresse de l'application, puis :
- **Firefox (Android)** : menu ⋮ → Ajouter à l'écran d'accueil.
- **Chrome (Android)** : menu ⋮ → Ajouter à l'écran d'accueil (ou Installer l'application).
- **Safari (iPhone)** : bouton Partager → Sur l'écran d'accueil.

**iPhone :** l'app de l'écran d'accueil ne voit pas les données de Safari. Installe d'abord l'icône, puis importe ton personnage **dans l'app installée**.

Les personnages sont gardés sur le téléphone. Pour récupérer une nouvelle version, bouton **Mettre à jour l'application** sur l'écran d'accueil de l'app.

## Bon à savoir : la liste à vérifier

Ton perso est importé ? Passe cette liste, **livre de règles à côté**. AideDD fait l'essentiel des calculs mais pas tout, et l'app affiche ce qu'AideDD lui donne. Les corrections se font en mode crayon (✎) et sont gardées aux montées de niveau.

### Fiche (une fois, à la création)
- [ ] **Nom** : AideDD garde parfois celui du perso précédent (onglet Fiche).
- [ ] **Caractéristiques** (FOR, DEX…) : justes dans AideDD, elles ne se modifient pas dans l'app.
- [ ] **Code du MJ** entré (Fiche → Sauvegarde en ligne), sinon la fiche n'existe que sur ce téléphone. iPhone : tout se fait dans l'app de l'écran d'accueil, pas dans Safari.

### Caracs : compétences et jets de sauvegarde
Compare chaque bonus au livre. Le losange se touche pour corriger : ◇ rien → ◆ maîtrise → double losange expertise → ◇.
- [ ] Don **Doué** : les 3 compétences choisies (AideDD ne les compte pas).
- [ ] Don **Résilient** : le jet de sauvegarde choisi (AideDD ne le compte pas).
- [ ] **Expertise** (Roublard, Barde, don Expert…) : déjà comptée par AideDD en général, vérifie.
- [ ] **Avantage à un jet de sauvegarde** qui s'applique toujours : bouton « av. » à côté du jet. Exemple : **Gnome** (Ruse gnome) → av. sur INT, SAG et CHA.
- [ ] Avantage **sous condition** (Nain contre le poison, Halfelin contre la peur, Elfe contre le charme…) : l'app ne sait pas le gérer, écris-le dans une **note** du trait.
- [ ] Bonus de **classe** sur les jets ou compétences (Touche-à-tout du Barde, Aura de protection du Paladin…) : AideDD ne les compte pas toujours. Vérifie, et note ce qui manque.

### Selon ton espèce
Vérifié sur les règles 2024 d'AideDD. « Compté » = AideDD l'applique déjà, rien à faire.
- [ ] **Drakéide** : résistance au type de ton ascendance → note sur le trait.
- [ ] **Elfe** : avantage contre l'état Charmé → note. Sens aiguisés et vitesse de l'elfe des bois : comptés.
- [ ] **Gnome** : bouton « av. » sur les jets de sauvegarde d'INT, SAG et CHA.
- [ ] **Goliath** : avantage pour se libérer d'Agrippé → note. Vitesse : comptée.
- [ ] **Halfelin** : avantage contre l'état Effrayé → note.
- [ ] **Humain** : compétence de Compétent comptée ; vérifie les effets du don d'origine choisi.
- [ ] **Nain** : résistance au poison et avantage contre Empoisonné → note. PV en plus (Ténacité naine) : comptés.
- [ ] **Tieffelin** : résistance selon ton héritage (poison, nécrotique ou feu) → note.
- Orc : rien à corriger.

### Selon ta classe
Vérifié sur les règles 2024 d'AideDD et sur des fiches de test (niveaux 1 à 10). Au-delà du niveau 10, vérifie toi-même.
- [ ] **Barbare** : Sens du danger (niv. 2) → « av. » sur le jet de DEX. Instinct sauvage (niv. 7, avantage à l'initiative) → note. Défense sans armure et Déplacement rapide : comptés.
- [ ] **Barde** : Touche-à-tout (niv. 2, +½ maîtrise aux compétences non maîtrisées) **n'est pas compté** → à ajouter de tête. Expertise : comptée. Collège du Savoir (3 maîtrises) et de la Danse (CA) : vérifie.
- [ ] **Clerc** : Ordre divin Thaumaturge (+SAG en Arcanes et Religion) : vérifie.
- [ ] **Druide** : Ordre primitif Mage : compté.
- [ ] **Ensorceleur** draconique : PV en plus et CA sans armure (Résistance draconique) : vérifie.
- [ ] **Guerrier** : style Archerie compté ; style Défense (+1 CA) : vérifie. Champion : avantage à l'initiative (niv. 3) → note.
- [ ] **Magicien** : Érudition (expertise) : comptée.
- [ ] **Moine** : Défense et Déplacement sans armure : comptés. Survivant discipliné (niv. 14, maîtrise de tous les jets de sauvegarde) : vérifie, losanges si besoin.
- [ ] **Occultiste** : une manifestation qui change la CA (Armure d'ombres) : vérifie la CA.
- [ ] **Paladin** : Aura de protection (niv. 6, +CHA à tous tes jets de sauvegarde) : vérifie ; si absent, note-le. Serment de Gloire (niv. 7, +3 m) : vérifie la Vitesse.
- [ ] **Rôdeur** : Fin explorateur (expertise) et Embuscade effrayante (initiative) : comptés. Traqueur des ténèbres, Mental d'acier (niv. 7, maîtrise des JS de SAG) **n'est pas compté** → losange du jet de SAG. Arpenteur (niv. 6, +3 m) : vérifie la Vitesse.
- [ ] **Roublard** : Expertise comptée. Esprit fuyant (niv. 15, maîtrise des JS de SAG et CHA) : vérifie, losanges si besoin.

### Combat
- [ ] **CA** : armure et bouclier bien choisis dans AideDD. Sinon tape la bonne CA (champ vide = valeur d'AideDD).
- [ ] **Initiative** (don Vigilant…), **Vitesse** (don Mobile, classe…), **PV max** (don Robuste, Nain…) : vérifie, tape la bonne valeur si besoin.
- [ ] **Résistances** (Tieffelin, Drakéide, Nain, Aasimar…) : pas de case dans l'app, note-les sur le trait.
- [ ] **Armes d'AideDD** : justes, et elles suivent les montées de niveau.
- [ ] **Arme ajoutée dans l'app** (tape le début du nom et choisis dans la liste) : attaque et dégâts calculés, maîtrise comprise (losange **Maîtrise** pour corriger). À ajuster à la main : style **Archerie** (+2 attaque à distance), **Duel** (+2 dégâts), arme **magique** (+1…), arme de **moine** avec DEX ou dé d'Arts martiaux, **Pacte de la lame**. Une arme retouchée à la main n'est plus recalculée ensuite.

### Sorts
- [ ] **Sorts préparés** : losange à gauche du sort (les autres passent en fin de liste).
- [ ] Sorts toujours préparés (domaine, serment…) et sorts gagnés par un don ou une espèce : présents ? Sinon ajoute-les (tape le début du nom, le reste se remplit).
- [ ] **Emplacements** par niveau : comme dans le livre (réglables en mode crayon).

### Capacités et ressources
- [ ] Chaque capacité à utilisations limitées a ses **cases** (sinon bouton **Cases** en mode crayon), avec le bon maximum.
- [ ] Les effets à retenir qui n'ont pas de place ailleurs : en **note** sur la capacité.

### Sac
- [ ] Objets et quantités. Pour en ajouter : tape le début du nom et choisis dans la liste (le lien AideDD se fait tout seul).

### À chaque montée de niveau
- [ ] Onglet Fiche → **Télécharger le .xml** → monte de niveau sur AideDD → nouvel export → **Mettre à jour le personnage**.
- [ ] Repasse la liste pour ce qui a changé : nouveau don (Doué, Résilient…), nouvelle capacité, nouveaux sorts, nouveaux emplacements.

### Ce que l'app ne fait pas
Multiclasse, effets temporaires (Rage, bénédiction…), avantages sous condition, jets de concentration (l'app te le rappelle seulement), repos court (décoche les cases à la main) : à gérer toi-même.
