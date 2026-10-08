# ECLOSION — REFERENCE PERMANENTE POUR CHAT


> **Dernière mise à jour : 8 octobre 2026.** Cette référence conserve les règles permanentes des sections 1 à 14 et les complète avec l’historique des échanges du 7–8 octobre 2026. La source de vérité du code reste GitHub. `AGENTS.md` définit les contraintes permanentes, `PROGRESS.md` suit les validations techniques et `ECLOSION_CHAT_REFERENCE.md` documente les décisions et la reprise entre conversations.
>
> **Point de reprise technique (avant le présent commit documentaire) :** branche `prototype/fragment-lab-v1`, commit `86562cd`. Vue expérimentale : `EggShellModel` commun + **F1 seul**, sans F2–F5 actifs. **La structure volumique et l’occlusion de F1 ne sont PAS encore validées.** Priorité : diagnostic/correction de profondeur entre F1 et le bol, pas nouvelles retouches cosmétiques.

## 1. Projet

Éclosion est un prototype Flutter destiné au visuel interactif d’un minuteur MorphoTime.

Application cible :
- Flutter
- Android à terme
- développement et validation rapide actuellement via Chrome

Dossier Flutter :
egg_timer/

Référence visuelle principale :
reference/Planche Eclosion.png

Cette planche est la référence visuelle pour :
- la chronologie de l’éclosion ;
- la morphologie générale de l’œuf ;
- l’évolution des fissures ;
- la fragmentation ;
- l’apparition du poussin ;
- l’ambiance finale de la scène.

Elle ne doit jamais être modifiée par une itération de développement.

---

## 2. Objectif final

Créer une animation interactive 2.5D d’éclosion convaincante, continue et physiquement cohérente.

Le résultat final doit associer :

1. la qualité visuelle de la planche de référence ;
2. une mécanique de fissuration et fragmentation crédible ;
3. une évolution temporelle continue ;
4. une interaction adaptée à un minuteur ;
5. une implémentation Flutter robuste et réutilisable.

Principe central :

Le spectateur doit voir une coquille qui se fissure et se sépare réellement.

Il ne doit jamais avoir l’impression de voir :
- une image remplacée par une autre ;
- un fragment qui apparaît ;
- un patch superposé ;
- un crossfade entre deux états.

---

## 3. Chronologie

La planche suit approximativement les états :

100 %
→ 75 %
→ 50 %
→ 25 %
→ 5 %
→ 00:01
→ 00:00

00:00 correspond au moment où le poussin a éclos.

Les derniers mouvements secondaires de coquille peuvent continuer brièvement après 00:00.

La rupture finale peut être rapide mais doit rester physiquement continue.

Rapide ne signifie pas :
remplacement brutal d’un état par un autre.

---

## 4. Mouvement de l’œuf

Deux phénomènes doivent rester distincts.

### Mouvement général

Il représente le poussin qui bouge ou change de position à l’intérieur.

Il doit être :
- doux ;
- inertiel ;
- irrégulier ;
- vivant ;
- ponctué de pauses.

Le crescendo vers l’éclosion vient surtout de l’augmentation de la fréquence et de la variété des mouvements.

Il ne doit pas principalement venir d’une augmentation excessive de leur amplitude.

### Pression locale

Elle représente une pression ciblée du poussin contre la coquille.

Elle peut être :
- plus courte ;
- plus localisée ;
- plus franche ;
- excentrée par rapport au futur fragment.

Cette pression provoque :
- extension de fissure ;
- ouverture locale ;
- rupture d’attaches ;
- pivot de plaques.

---

## 5. Morphologie des fissures

Référence stricte : Planche Eclosion.png.

Les fissures doivent être :

- fines au départ ;
- irrégulières ;
- anguleuses mais organiques ;
- asymétriques ;
- composées de segments courts et moyens ;
- enrichies de ramifications secondaires ;
- accompagnées de quelques branches mortes ;
- non répétitives ;
- non géométriques.

Éviter :
- étoile régulière ;
- zigzag répétitif ;
- polygone propre ;
- traits décoratifs indépendants de la matière.

Principe fondamental :

La fissure doit créer le futur bord du fragment.

La continuité recherchée est :

fissure
→ ouverture
→ deux bords de matière
→ tranche
→ fragment.

La géométrie du fragment ne doit pas remplacer une géométrie de fissure différente.

---

## 6. Coquille et fragmentation

La coquille est cassante, pas élastique.

Éviter :
- flexion caoutchouteuse ;
- étirement ;
- grand retour élastique.

La logique physique est :

résistance
→ fissuration
→ rupture locale
→ nouvelle résistance
→ rupture suivante.

Une plaque reste reliée par plusieurs attaches.

Lorsque les attaches cèdent successivement :
- certaines parties s’ouvrent ;
- d’autres restent raccordées ;
- le pivot évolue ;
- la mobilité augmente.

La pression étant excentrée, un bord peut commencer à se soulever avant l’autre.

---

## 7. Fragment 2.5D

Un fragment doit représenter la même matière avant et après son détachement.

Il possède :
- une face extérieure ;
- une face intérieure si elle devient visible ;
- une tranche cassée ;
- une orientation ;
- un éclairage dépendant de cette orientation.

La face du fragment ne doit jamais apparaître artificiellement.

Avant changement d’orientation réel, son aspect doit rester pratiquement identique à celui de la coquille environnante.

La tranche ne devient visible que lorsque :
- la cassure est suffisamment ouverte ;
- l’orientation permet réellement de voir l’épaisseur.

Ne jamais afficher une bordure uniforme autour du fragment.

---

## 8. Paramètres actuellement validés

Épaisseur :
2.5

Oscillation :
1.5

Ces valeurs sont gelées sauf décision explicite contraire.

Sont également considérés comme acquis et à préserver autant que possible :

- mouvement général actuel de l’œuf ;
- pression interne excentrée ;
- principe des attaches successives ;
- pivot asymétrique ;
- rotation du fragment ;
- éclairage dépendant de l’orientation ;
- chute du fragment globalement crédible.

---

## 9. Dette connue

À traiter plus tard, séparément :

- rebond final du fragment légèrement trop important pour une coquille légère ;
- trou / intérieur de l’œuf à perfectionner ;
- multi-fragments ;
- rendu artistique final de la matière ;
- décor final ;
- poussin final ;
- éclosion complète.

Ces éléments ne doivent pas être mélangés à une itération consacrée à un autre problème.

---

## 10. Règle d’itération

Une itération = un problème visuel principal.

Avant de modifier plusieurs systèmes, identifier d’abord le défaut dominant.

Les éléments déjà validés sont gelés.

Si une correction dégrade un élément validé, il s’agit d’une régression.

Après deux corrections successives sans amélioration claire :
ne pas continuer à empiler des ajustements.

Revenir au diagnostic de la cause ou à l’architecture.

---

## 11. Méthode de travail Chat / Codex

CHAT sert principalement à :
- analyser les vidéos ;
- comparer au visuel de référence ;
- identifier le défaut prioritaire ;
- déterminer ce qui doit rester gelé ;
- définir les critères visuels d’acceptation ;
- produire un prompt Codex précis.

CODEX sert principalement à :
- lire le dépôt actuel ;
- identifier la cause technique ;
- modifier le code ;
- effectuer le formatage ;
- lancer l’analyse Flutter ;
- exécuter les tests ;
- rendre compte des modifications.

Le test visuel final reste effectué dans Chrome puis analysé dans Chat.

Boucle normale :

vidéo actuelle
→ analyse Chat
→ un défaut prioritaire
→ prompt Codex court
→ diagnostic et correction
→ format / analyse / tests
→ validation Chrome
→ nouvelle vidéo
→ analyse Chat.

---

## 12. Prompts Codex

Ne pas répéter tout le cahier des charges à chaque itération.

Les règles permanentes appartiennent à :
AGENTS.md

L’état technique courant appartient à :
PROGRESS.md

Le prompt Codex d’une nouvelle itération doit principalement contenir :

- objectif unique ;
- symptôme observé ;
- éléments gelés si nécessaire ;
- critères d’acceptation ;
- éventuelle zone du code déjà identifiée.

Si la cause technique est incertaine :
demander d’abord à Codex de diagnostiquer.

Si la cause est suffisamment connue :
Codex peut diagnostiquer brièvement puis corriger dans la même tâche.

---

## 13. Validation visuelle

Une compilation réussie ne suffit jamais à valider une animation.

Pour valider une correction, examiner selon le besoin :

- frames avant/après une transition ;
- progression lente ;
- vidéo complète ;
- cohérence spatiale ;
- continuité des formes ;
- continuité du mouvement ;
- cohérence de l’éclairage ;
- absence de patch ;
- absence de remplacement brutal d’état.

La qualité visuelle et la continuité physique priment sur une simple réussite technique des tests.

---

## 14. Principe de décision

Lorsque plusieurs solutions techniques sont possibles :

préférer celle qui produit une continuité physique réelle et une architecture réutilisable.

Éviter les artifices destinés uniquement à masquer un défaut à quelques frames.

Le prototype doit progressivement constituer une base propre pour l’éclosion complète et le futur multi-fragments.

---

## 15. Décisions et changements d’architecture (7 octobre 2026)

### 15.1. Pourquoi le modèle précédent a été écarté

Auparavant, la silhouette était dessinée par un `Path()` 2D tandis que des fragments étaient construits/projetés selon une géométrie distincte. Les essais sur la partition F1–F5 (dont `c84ab72` et les changements précédents) n’avaient pas résolu le défaut de fond : morceaux perçus comme des plaques collées en façade, couronne insuffisamment enveloppée et silhouette d’œuf imparfaite.

La décision utilisateur est : **cesser les retouches du contour `Path()` indépendant et employer une source géométrique unique**.

### 15.2. Modèle de référence unique

`EggShellModel` doit définir et relier :
- hauteur, rayon horizontal variable avec l’altitude, profondeur et profil longitudinal mesuré sur l’œuf intact de la planche ;
- surface 3D de révolution continue, courbure sommet → épaules → ventre → base ;
- silhouette 2D **déduite automatiquement de cette surface**, et non retracée séparément ;
- normales, épaisseur suivant la normale, coque intérieure, éclairage, arêtes, charnières et forces reposant sur la même géométrie ;
- fragments appartenant réellement à la coquille et enveloppant ses flancs et sa couronne.

Cette décision concerne à terme F1–F5 ; **elle ne signifie pas que l’ancien moteur multi-fragments est déjà entièrement migré**. La vue de validation du modèle unifié est aujourd’hui séparée de `fragment_scene.dart`, ancien moteur encore présent.

### 15.3. Décomposition cible et nomenclature

Dans la **partition ancienne**, le grand chapeau sommital était appelé **F3** et F1 désignait une plaque supérieure/droite. Dans le **nouvel atelier de validation 3D**, **F1 est le grand chapeau supérieur testé seul**. Cette différence de nom est historique : **ne pas confondre les deux topologies** ni déclarer F2–F5 migrés par simple analogie.

Objectif à terme selon la planche : chapeau supérieur de coquille courbe, poussin au centre au moment de l’éclosion, bol inférieur conservé, autres fragments latéraux issus d’arêtes partagées. La numérotation définitive devra être harmonisée **après validation** de la base F1.

---

## 16. Séquence de validation du nouveau modèle 3D

1. **Œuf seul** : tester le `EggShellModel` intact, sa vraie silhouette 3D et ses proportions face à `reference/Planche Eclosion.png`. Aucun fragment dans cette vue. Les commits fondateurs sont `6cf0bb0` et `0ac63d2`.
2. **F1 seul** (demande explicite de l’utilisateur) : tester le chapeau supérieur sur cette même surface. Le fragment doit envelopper la couronne, prolonger sa matière sur les côtés **et vers l’arrière**, avec face extérieure, face intérieure et tranche d’épaisseur 2.5. L’ouverture se teste de 0 à 100 % dans Chrome. Cette étape a été implémentée initialement à partir de `0a42640`, `08f8a74` et améliorée avec `04f282b`.
3. **Valider le volume avant le mouvement détaillé** : l’ouverture ne doit pas créer une membrane beige, une bande artificielle, un fond brun peint à plat, une silhouette fantôme ni des bords à escalier ; les occlusions doivent évoluer correctement avec la rotation.
4. **Seulement ensuite** : re-projeter/réintégrer F2–F5 et l’ancien cluster sur le modèle commun, puis reprendre la mécanique de pression, la fissuration, les pivots, la chute, le poussin et le rendu artistique.

Réglages de la vue diagnostique (dans `egg_timer/lib/lab/fragment_lab.dart`) :
- « Valider le modèle 3D unifié » ;
- « Afficher F1 3D seul » ;
- « Ouverture F1 » : de 0 à 100 %.

Le réglage F1 seul est intentionnel ; **ne pas réactiver le multi-fragments ni l’ancien `FragmentScene` pour une validation de volume F1**.

---

## 17. Historique Git utile et décisions de retour arrière

Les SHA suivants permettent de retrouver les états exacts. Tous les retours arrière ont été réalisés avec de **nouveaux commits contenant l’ancien arbre**, en conservant l’historique Git (pas de réécriture destructive).

| Époque | Commit(s) | Signification |
| --- | --- | --- |
| Avant modèle unifié | `c84ab72` | Dernier état de la géométrie antérieure, encore basé sur plusieurs représentations ; F3 couvrant la couronne. Ce n’est **pas** le point de reprise choisi. |
| Création source 3D | `6cf0bb0`, `0ac63d2` | `EggShellModel` + validation de l’œuf seul, silhouette dérivée de la surface. |
| Premier test F1 | `0a42640`, `08f8a74`, `0946bff`, `2829495`, `e619703` | Prévisualisation F1 sur le modèle, contrôle d’ouverture et suivi de l’étape. |
| F1 autour de la couronne | `04f282b` | Chapeau 360° sur la couronne et l’arrière ; référence technique de la **reprise F1 seule**. |
| Expérimentations suivantes | jusqu’à `d466b483` | Fissures déterministes, cavité, bol inférieur 3D, lèvres et paroi arrière ; état testé mais rendu toujours problématique. |
| Premier retour arrière erroné | `a3c4831` | Retour à `c84ab72` : ne correspondait pas au souhait de reprise utilisateur. |
| Restauration intermédiaire | `718005e` | Rétablissement de l’état `d466b483`, mais ce n’était pas le point précis demandé ensuite. |
| **Reprise correcte du dialogue F1 seul** | **`e7feb3d`** | Réinstaure exactement l’arbre `04f282b` : modèle unifié, aperçu F1 uniquement, aucune expérience ultérieure sur le bol. |
| Correction bord inférieur | `eb3470b` | Maillage du bol calé sur la même limite de fracture ; disparition de la découpe par triangles entiers et des marches rectangulaires (confirmée visuellement). |
| Éclairage intérieur | `9ff48ab` | Normales tournées selon la même rotation que F1 et ombrage intérieur dérivé des normales ; amélioration partielle, **pas de validation volumique**. |
| Cavité arrière | `6cf38a7` | Remplace un `_aperturePath()` brun plat par un maillage intérieur arrière calculé à partir du modèle 3D. |
| Contour fantôme | `4a57b07` | Retire le contour 2D de l’œuf intact dessiné par-dessus l’aperçu F1 ; disparition confirmée dans la vidéo suivante. Le mode œuf seul reste intact. |
| Dernier changement technique | **`86562cd`** | Peinture réordonnée : arrière du bol → intérieur F1 → devant du bol → tranche et extérieur F1. **Le défaut de superposition demeure sur la dernière vidéo.** |

Attention : un correctif commité n’est pas automatiquement validé visuellement. Les tests Dart/Flutter des petites corrections réalisées directement via GitHub n’ont pas été exécutés dans ce flux. Il ne faut jamais les présenter comme réussis.

---

## 18. Observations visuelles, régressions et diagnostic actuel (8 octobre)

Les captures et vidéos fournies ont été comparées à l’œuf intact et au chapeau supérieur de la planche de référence.

### Confirmé / à préserver

- Le chapeau F1 conserve globalement sa silhouette extérieure et épouse la couronne de l’œuf.
- Le bord inférieur **en escalier** a été supprimé par la reconstruction du premier rang de triangles sur la ligne de rupture.
- Le **contour fantôme** de l’œuf entier, visible à travers F1 ouvert, a été supprimé.
- La continuité temporelle de l’ouverture est observable ; cette seule continuité ne prouve pas la justesse du volume.
- Le modèle et les paramètres `2.5` / `1.5` restent les références ; ne pas les modifier pour masquer un défaut de rendu.

### Toujours non validé

- La face intérieure de F1 demeure trop proche d’une **membrane beige**.
- Des **bandes ondulées / surfaces superposées** persistent entre F1 et le bol à grande ouverture.
- On ne lit pas de manière fiable le **vide réel**, la **tranche fine** et les **faces concaves** respectives.
- L’ouverture à **0, 25, 50, 75, 100 %** doit être revue après correction de profondeur avant validation F1.

### Cause architecturale constatée dans le code

Dans `EggShellF1PreviewPainter` (`egg_timer/lib/lab/egg_shell_model.dart`), les maillages ont des coordonnées 3D, mais le rendu Flutter utilise des projections `.xy` passées à `canvas.drawVertices()`. L’occlusion est simulée par **l’ordre de peinture fixe**, y compris un rappel de `_drawBody()` entre les faces de F1.

**Il n’y a pas de test de profondeur général (Z-buffer)** entre tous les triangles visibles. Réordonner simplement les appels de dessin ne garantit pas de bon masquage lorsque les surfaces pivotent et se recouvrent. C’est la **cause structurelle la plus probable**, à vérifier visuellement après correction ; ne pas la considérer comme démonstration que la géométrie 3D est entièrement bonne.

**Prochaine priorité décidée :** remplacer la gestion de visibilité manuelle par une solution d’occlusion réellement fondée sur la profondeur ; conserver `EggShellModel`, le profil, la fissure, l’épaisseur et la transformation actuelle de F1. Évaluer une technique adaptée à Flutter et aux contraintes 2.5D/Android (test de profondeur réel ou solution équivalente correctement démontrée), en distinguant un simple tri de maillages d’un vrai Z-buffer. **Aucun correctif de profondeur n’a encore été commité** à la date de ce bilan.

Après deux retouches sans progrès visuel : arrêter les ajustements ponctuels, établir la cause et reprendre l’architecture. Ne pas réintroduire de surfaces artificielles, de crossfade ni de patch pour cacher les mauvais recouvrements.

---

## 19. Workflow GitHub, travail local et validation

### Sources et responsabilités

- Dépôt : `https://github.com/yoshimoot/Eclosion`.
- Branche de travail : `prototype/fragment-lab-v1` ; `main` n’est pas la branche de ce prototype.
- Fichiers importants : `AGENTS.md` (règles et vérifications), `PROGRESS.md` (état des validations), `ECLOSION_CHAT_REFERENCE.md` (référence entre conversations), `egg_timer/lib/lab/egg_shell_model.dart`, `egg_timer/lib/lab/fragment_lab.dart`, ancien `fragment_scene.dart`.
- `reference/Planche Eclosion.png` est immuable.
- Conserver le travail dans Chat/Codex et les tests visuels locaux dans Chrome ; **ne pas lancer GitHub Actions** pour ces itérations.
- Une itération = un défaut principal, avec un commit ciblé, un résultat des vérifications sincère, puis une validation vidéo par l’utilisateur.
- Selon `AGENTS.md` : après modification Dart, `dart format` des seuls fichiers changés, `flutter analyze`, puis `flutter test --no-pub test/widget_test.dart`. Le succès de compilation ne remplace pas la validation visuelle.

### Synchronisation locale à partir de GitHub

L’utilisateur a observé dans son clone local : ` M egg_timer/lib/lab/fragment_scene.dart`. Le dépôt distant était plus avancé. Cette modification locale **ne doit pas être écrasée silencieusement**, mais elle ne doit pas non plus être réintroduite dans le modèle validé.

Commandes PowerShell (à lancer sur le bon poste et dans le bon clone) :

```powershell
cd "$env:USERPROFILE\Dev\Eclosion"
git status --short
git stash push -m "Sauvegarde avant synchronisation" -- egg_timer/lib/lab/fragment_scene.dart
git switch prototype/fragment-lab-v1
git pull --ff-only origin prototype/fragment-lab-v1
git status --short
git log -1 --oneline
cd egg_timer
flutter run -d chrome
```

Ne **pas** exécuter `git stash pop` automatiquement : cela restaurerait une modification potentiellement dépassée. `git pull --ff-only` protège contre un merge automatique inattendu. La synchronisation est **une procédure proposée**, pas une preuve qu’elle a été effectivement terminée sur le PC.

Le chemin dépend de `$env:USERPROFILE` : il ne faut pas supposer que les différents comptes Windows (`User`, `alrad`, etc.) pointent vers le même clone. Vérifier `git remote -v` et `git branch --show-current` en cas d’ambiguïté.

---

## 20. État de reprise et limites de la consolidation

**État au 8 octobre 2026, avant mise à jour du présent document :** commit technique `86562cd`, atelier F1 seul sur `EggShellModel` ; défaut d’occlusion toujours présent. La prochaine tâche est **une seule correction architecturale de profondeur**, suivie de comparaison Chrome. Aucune intégration F2–F5, poussin, finalisation artistique ou nouveau mouvement ne doit être mélangée à cette itération.

Cette synthèse repose sur :
- les échanges effectivement présents dans ce fil ;
- les extraits de la conversation liée retranscrits par l’utilisateur et les éléments d’historique disponibles ;
- `AGENTS.md`, `PROGRESS.md` et l’historique des commits GitHub.

Le contenu intégral de la conversation ChatGPT accessible uniquement par l’URL fournie n’a **pas été importé mot pour mot**. D’éventuels détails non présents dans ces sources ne sont donc pas présumés connus. Lorsqu’une validation visuelle n’est pas explicite, elle est considérée comme **en attente**.
