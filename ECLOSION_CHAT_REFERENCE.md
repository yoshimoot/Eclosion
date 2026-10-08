# ECLOSION — REFERENCE PERMANENTE POUR CHAT

## GUIDE DE REPRISE — Nouvelle conversation si l'ancien chat devient inaccessible

**Cette procédure fonctionne sans partager, exporter ou rouvrir l'ancienne conversation ChatGPT.** Le dépôt GitHub conserve le code et les décisions documentées ; il **ne reconstitue pas** les messages, vidéos ou fichiers joints à une conversation disparue.

### Message à copier dans le premier message du nouveau chat

> Je reprends le projet **MorfoTime — Éclosion** après la perte d'accès à la conversation précédente. **Ne recommence pas le projet de zéro.**
>
> Dépôt GitHub : `https://github.com/yoshimoot/Eclosion`
> Branche : `prototype/fragment-lab-v1`
>
> **Avant toute modification**, consulte sur cette branche, dans cet ordre :
> 1. `AGENTS.md` — règles permanentes et vérifications obligatoires ;
> 2. `PROGRESS.md` — état actif, validations, défaut prioritaire et prochaine tâche ;
> 3. `ECLOSION_CHAT_REFERENCE.md` — historique, décisions et critères visuels ;
> 4. `egg_timer/lib/lab/egg_shell_model.dart`, `egg_timer/lib/lab/fragment_lab.dart` et les derniers commits pertinents.
>
> `reference/Planche Eclosion.png` est la référence visuelle immuable. Distingue l'ancien moteur `fragment_scene.dart` de l'atelier 3D unifié **F1 seul** ; le nom F1 n'est pas identique dans les deux géométries.
>
> **État de reprise (8 octobre 2026)** : atelier 3D unifié avec F1 seul ; l'ancien mode 2D n'est plus accessible depuis l'interface. Les commits `196718e` (Z-buffer logiciel), `59fd82c` (identification des faces) et `2b6af2d` (nettoyage de l'atelier) sont présents ; **fiabilité structurelle et concavité finale restent à distinguer et à vérifier**. Nouvelle priorité : contrôle technique limité de la profondeur, puis réseau statique de fissures sur `EggShellModel` à seed fixe ; reporter le pivot définitif jusqu'à l'intégration du poussin. Lis toujours le **HEAD actuel** et la **Décision active** en haut de `PROGRESS.md`.
>
> Contraintes : préserver le profil de `EggShellModel`, la silhouette et l'ouverture déjà acquises, l'épaisseur `2.5` et l'oscillation `1.5` ; **une itération = un défaut principal**. Pas de crossfade ni de patch graphique, pas de GitHub Actions. Tester/formatter si l'outillage est disponible, distinguer clairement code vérifié et rendu validé par vidéo Chrome. Préserver les changements locaux non committés.
>
> **Dans le premier échange de reprise**, réponds avec la branche et le HEAD vérifiés, l'état validé / non validé, le défaut prioritaire et la prochaine étape. Si je fournis seulement ce message de reprise, **ne modifie aucun code**. Si je fournis ensuite une vidéo/capture avec une demande d'itération, applique directement la boucle **analyse → correction GitHub → commit → commande PowerShell → validation Chrome**, sans me redemander une autorisation pour chaque correction ciblée ; demande confirmation pour une modification destructive, ambiguë ou qui remet en cause un acquis validé.

### Si la nouvelle conversation n'a pas accès à GitHub

Ouvrir les trois fichiers dans le navigateur à partir des URLs :
- [AGENTS.md](https://github.com/yoshimoot/Eclosion/blob/prototype/fragment-lab-v1/AGENTS.md)
- [PROGRESS.md](https://github.com/yoshimoot/Eclosion/blob/prototype/fragment-lab-v1/PROGRESS.md)
- [ECLOSION_CHAT_REFERENCE.md](https://github.com/yoshimoot/Eclosion/blob/prototype/fragment-lab-v1/ECLOSION_CHAT_REFERENCE.md)

Les déposer dans le nouveau chat avec le message ci-dessus, puis joindre la **dernière vidéo ou capture locale pertinente** si une analyse visuelle est attendue. Les anciennes pièces jointes ne sont pas garanties accessibles dans un nouveau chat.

### Procédure opérationnelle désormais utilisée

L'utilisateur fournit **une vidéo ou une capture du test Chrome**. ChatGPT examine le rendu, identifie **un défaut principal**, vérifie le code et le HEAD, **modifie directement les fichiers nécessaires sur GitHub**, crée un commit ciblé (aucune GitHub Action), puis transmet le commit et **la commande PowerShell** pour actualiser le clone local et lancer `flutter run -d chrome`. L'utilisateur teste puis renvoie son observation. **Une réussite technique n'est pas une validation visuelle.**

Codex n'est plus une étape obligatoire de ce cycle ; l'ancienne méthode Chat → prompt Codex → correction est archivée plus bas comme historique. Après une capture assortie d'une demande de nouvelle itération, ne pas exiger d'autorisation répétée pour les corrections ciblées ordinaires ; demander confirmation si suppression, changement architectural sensible ou risque sur les acquis gelés.

### Préservation entre deux itérations

- Le code livré doit être committé sur la branche avant la fin du cycle. Ne pas supposer que des modifications locales ou des fichiers non committés se trouvent sur GitHub.
- Mettre à jour `PROGRESS.md` lorsqu'une étape est **visuellement validée**, qu'un défaut prioritaire change, ou qu'un blocage de reprise doit être consigné. Identifier sans ambiguïté « corrigé dans le code » versus « validé dans Chrome ».
- Garder cette référence durable pour les choix historiques et les critères. `AGENTS.md` reste le contrat permanent ; éviter de multiplier les documents parallèles.
- Si `git status --short` montre `fragment_scene.dart` modifié, ne jamais le supprimer ni écraser sans inspection/sauvegarde. L'atelier actif 3D ne l'importe plus, mais des tests et l'ancien moteur historique en dépendent encore.
- **Pour relancer localement** après sauvegarde éventuelle des modifications : `git switch prototype/fragment-lab-v1`, puis `git pull --ff-only origin prototype/fragment-lab-v1` et `cd egg_timer; flutter run -d chrome`.

---


> **Dernière mise à jour : 8 octobre 2026.** Cette référence conserve les règles permanentes des sections 1 à 14 et les complète avec l’historique des échanges du 7–8 octobre 2026. La source de vérité du code reste GitHub. `AGENTS.md` définit les contraintes permanentes, `PROGRESS.md` suit les validations techniques et `ECLOSION_CHAT_REFERENCE.md` documente les décisions et la reprise entre conversations.
>
> **Instantané historique du précédent fil (avant les correctifs `196718e`, `59fd82c` et `2b6af2d`) :** branche `prototype/fragment-lab-v1`, commit `86562cd`. Cet état décrit les anciennes décisions, **pas la priorité actuelle**. Le point de reprise vivant est en tête de `PROGRESS.md` et dans la section 21 ci-dessous.

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

## 11. Méthode de travail active — Chat → GitHub → Chrome

Depuis le 8 octobre 2026, l'assistant intervient **directement sur le dépôt GitHub** dans le cadre d'une itération demandée. Il n'est plus nécessaire de rédiger un prompt Codex à chaque cycle.

**Cycle normal :**

1. L'utilisateur teste localement dans Chrome et transmet une **vidéo/capture** (éventuellement avec une observation).
2. ChatGPT **analyse visuellement** la scène, compare la référence et les validations précédentes, puis choisit **un seul défaut principal**. Si la cause est inconnue, il examine le code plutôt que modifier au hasard.
3. ChatGPT vérifie la branche `prototype/fragment-lab-v1`, son HEAD et les fichiers en vigueur ; il **corrige directement sur GitHub**, uniquement les fichiers nécessaires, puis **commite** la modification sans réécrire l'historique.
4. Il réalise les vérifications Dart/Flutter **si son environnement dispose des outils**. Les vérifications non exécutées doivent être dites explicitement. **Ne pas lancer de GitHub Actions.**
5. Il livre le **SHA et le lien du commit**, le défaut ciblé, les éléments conservés et la **commande PowerShell** permettant de récupérer GitHub puis lancer Chrome.
6. L'utilisateur vérifie dans Chrome, envoie une nouvelle capture/vidéo et confirme ou signale la régression. **Le rendu n'est validé qu'après cet examen visuel.**
7. Si une validation, un blocage ou la priorité changent, ChatGPT met à jour `PROGRESS.md`. Une décision durable nouvelle va dans cette référence ou dans `AGENTS.md` selon sa nature.

Ce cycle est autorisé pour les **corrections ciblées demandées par les captures** ; demander l'accord de l'utilisateur avant une suppression importante ou un changement de direction qui toucherait les éléments déjà validés. Ne pas se substituer à la validation Chrome.

**Cycle court à retenir :** vidéo/capture utilisateur → analyse d'un défaut → correctif GitHub + commit → PowerShell `git pull --ff-only` → `flutter run -d chrome` → nouvelle vidéo/capture.

### Ancien workflow, conservé pour l'historique

L'approche antérieure séparait les responsabilités : **CHAT** analysait les vidéos et formulait un prompt Codex (objectif, symptôme, acquis gelés, critères d'acceptation) ; **CODEX** lisait le dépôt, corrigeait, formatait, analysait et testait ; l'utilisateur validait ensuite sous Chrome. Cette approche peut rester une solution alternative **si la correction directe sur GitHub n'est pas possible**, mais elle n'est **plus la méthode par défaut**.

---

## 12. Consignes pour les corrections directes (Codex facultatif)

Ne pas recopier tout le cahier des charges dans chaque cycle. Le référentiel est réparti ainsi :
- `AGENTS.md` : règles permanentes et vérifications obligatoires ;
- `PROGRESS.md` : état courant, acquis confirmés, point bloquant, prochaine tâche ;
- `ECLOSION_CHAT_REFERENCE.md` : historique des choix, références et guide de reprise ;
- historique Git : code réellement livré.

Le **correctif GitHub** doit comporter un objectif unique, le symptôme reproduit, les éléments non modifiables, des changements minimaux et les critères concrets de vérification. Ne pas présenter un simple patch ou un tri fixe des couches comme un véritable rendu volumique.

Si la cause technique est incertaine : commencer par un diagnostic du code et des captures. Si la cause est suffisamment établie : corriger dans la même itération et livrer le commit avec un bilan exact.

**Contrôles :** `dart format` des seuls fichiers modifiés, `flutter analyze` et `flutter test --no-pub test/widget_test.dart`, **lorsque les outils sont disponibles** ; documenter honnêtement toute impossibilité. Jamais de GitHub Actions pour ces corrections.

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
- **Méthode active : ChatGPT analyse les médias de l'utilisateur et modifie directement GitHub**, fournit le commit et une commande PowerShell ; l'utilisateur valide dans Chrome et transmet le nouveau résultat. Codex reste une option de secours, pas une étape obligatoire. **Ne pas lancer GitHub Actions** pour ces itérations.
- Une itération = un défaut principal, avec un commit ciblé, un résultat des vérifications sincère, puis une validation vidéo par l’utilisateur.
- Selon `AGENTS.md` : après modification Dart, `dart format` des seuls fichiers changés, `flutter analyze`, puis `flutter test --no-pub test/widget_test.dart`. Le succès de compilation ne remplace pas la validation visuelle.

### Synchronisation locale à partir de GitHub

Le 8 octobre 2026, le clone local `C:\Users\User\Dev\Eclosion` présentait une modification de `fragment_scene.dart`. Elle a été sauvegardée en stash, examinée via `Eclosion_stash.diff`, jugée obsolète pour le nouvel atelier F1, puis le stash a été supprimé par l'utilisateur. `git status --short` et `git stash list` étaient ensuite vides ; `git pull --ff-only` a synchronisé local et distant sur `6a7efbc`. **Cet état est historique, à revérifier pour toute session ultérieure**. Le fichier `fragment_scene.dart` reste présent et requis par l'ancien moteur et ses tests ; ne pas le supprimer sans traiter ses dépendances.

Commandes PowerShell (à lancer sur le bon poste et dans le bon clone) :

```powershell
cd "$env:USERPROFILE\Dev\Eclosion"
git status --short
# Si des modifications locales existent, les examiner/sauvegarder d'abord.
git switch prototype/fragment-lab-v1
git pull --ff-only origin prototype/fragment-lab-v1
git status --short
git log -1 --oneline
cd egg_timer
flutter run -d chrome
```

Ne **pas** exécuter `git stash pop` automatiquement : cela pourrait restaurer une modification obsolète. `git pull --ff-only` protège contre un merge automatique inattendu. **La synchronisation du 8 octobre a été confirmée par la sortie PowerShell transmise par l'utilisateur, au commit `6a7efbc`** ; les cycles suivants doivent vérifier leur propre état.

Le chemin dépend de `$env:USERPROFILE` : il ne faut pas supposer que les différents comptes Windows (`User`, `alrad`, etc.) pointent vers le même clone. Vérifier `git remote -v` et `git branch --show-current` en cas d’ambiguïté.

---

## 20. État de reprise et limites de la consolidation

**État au 8 octobre 2026, avant mise à jour du présent document :** commit technique `86562cd`, atelier F1 seul sur `EggShellModel` ; défaut d’occlusion toujours présent. La prochaine tâche est **une seule correction architecturale de profondeur**, suivie de comparaison Chrome. Aucune intégration F2–F5, poussin, finalisation artistique ou nouveau mouvement ne doit être mélangée à cette itération.

Cette synthèse repose sur :
- les échanges effectivement présents dans ce fil ;
- les extraits de la conversation liée retranscrits par l’utilisateur et les éléments d’historique disponibles ;
- `AGENTS.md`, `PROGRESS.md` et l’historique des commits GitHub.

Le contenu intégral de la conversation ChatGPT accessible uniquement par l’URL fournie n’a **pas été importé mot pour mot**. D’éventuels détails non présents dans ces sources ne sont donc pas présumés connus. Lorsqu’une validation visuelle n’est pas explicite, elle est considérée comme **en attente**.

---

## 21. Ordre de développement consolidé — décision du 8 octobre 2026

Cet ordre a été confirmé après analyse du nouveau rendu diagnostic F1. Il actualise le plan indiqué dans les sections historiques précédentes, sans effacer celles-ci.

1. **Contrôle technique de base (immédiat) :** vérifier `EggShellModel`, les surfaces externe/interne, la tranche et les masquages Z entre F1 et le bol aux ouvertures 0/25/50/75/100 %. Le Z-buffer logiciel existe depuis `196718e`, mais la démonstration de sa fiabilité reste à achever. Corriger toute cause structurelle prouvée, **sans rechercher le pivot visuellement définitif**.
2. **Réseau fixe de fissures 3D :** générer sur la surface commune un réseau de fissures organiques, non répétitives, à frontières réellement partagées par les futurs fragments. Une seed fixe sert à reproduire la première configuration ; aucune rupture animée à ce stade. Valider la topologie et la continuité avec la référence.
3. **Réseau variable entre éclosions :** seed nouvelle par session, conservée durant l'animation, variantes bornées du réseau sans randomisation frame par frame ; garder la reproductibilité des tests.
4. **Mécanique causale d'éclosion :** fissuration puis ouverture/tranche/attaches/pivots/libération/chute selon des efforts de poussin partagés entre fragments ; adapter alors le pivot F1 et les autres mouvements afin que le poussin puisse apparaître naturellement à `00:00`.
5. **Finalisation et intégration MorphoTime :** matériaux, lumière, cavité, décor, poussin déjà validé, minuteur/interactions, sons/haptique et performances Android.

**Différencier deux critères d'acceptation :** (A) système géométrique et profondeur fiables, nécessaire **avant** le réseau ; (B) volume intérieur artistiquement convaincant et pivot final compatible avec le poussin, à finaliser **après** la topologie et la mécanique. Le rendu F1 actuel **n'est pas déclaré validé** sur le critère B.

**État du dépôt à la décision :** dernier HEAD connu avant cette mise à jour documentaire `9109c2a`. `PROGRESS.md` est l'état actif ; l'historique antérieur `86562cd` reste archivé. `AGENTS.md` contient les règles permanentes. Aucune modification Dart, aucun test Flutter, aucune GitHub Action lors de cette mise à jour de documentation.
