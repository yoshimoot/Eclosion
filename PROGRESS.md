# Eclosion — état courant

## Réseau statique V4 — diversification directionnelle, à valider dans Chrome

**Demande validée le 8 octobre 2026 :** les fissures principales de V3 descendaient presque toutes verticalement. La prochaine correction vise **uniquement les directions et les bifurcations du réseau**. La simplification de l'interface en un seul mode a été décidée mais est **reportée à une itération distincte**, afin de ne pas mélanger topologie et interface.

**Modification :** trois fissures principales réorientées avec des segments franchement obliques. Deux vrais embranchements en **Y** sont créés par deux nœuds internes partagés (`left[1]`, `right[1]`) : deux arêtes distinctes en repartent, avec longueurs/directions dissymétriques. La troisième bifurcation interne de V3 est retirée, sans interrompre la fissure centrale ; les ramifications secondaires gardent des terminaisons libres. Tous les points sont définis sur `EggShellModel`, les coudes rares/déterministes de V3 sont conservés, la seed reste `20261008` et les nœuds/arêtes sont construits une seule fois.

**Gel :** boucle F1 360° et `EggShellModel.crownFractureY`, pivot F1, forme de l'œuf, couleurs/matières, moteur temporel, épaisseur `2.5`, oscillation `1.5` et poussin inchangés. Pas encore de fragmentation ni de changement d'écran.

**Tests ajoutés (pas de succès présumé avant exécution Dart/Flutter) :** exactement deux Y internes de degré 3 avec branches réellement divergentes ; plusieurs arêtes principales obliques ; absence d'intersections fortuites entre fissures visibles non connectées. La validation artistique nécessite une capture Chrome du mode réseau statique, sans repères de cadrage, comparée à la planche de référence.

## Retour Chrome réseau statique V2 — réduction du motif en dents de scie (V3)

**Observation utilisateur, capture du 8 octobre 2026 :** les déviations sont devenues trop fréquentes, de longueur presque identique et produisent des dents de scie très régulières sur plusieurs branches. Le réseau paraît mécanique malgré des arêtes 3D partagées. La couronne reste trop lisse, mais elle est commune à F1 et ne doit pas être retouchée pendant cette correction.

**Itération V3 ciblée :** remplacer la déviation indépendante de chaque échantillon d'une branche par **1 à 3 coudes géométriques dominants** à espacement et amplitude déterministes non uniformes. Les points intermédiaires continuent d'être échantillonnés sur `EggShellModel` mais ne rajoutent pas de nouvelles oscillations visuelles. Tous les nœuds, arêtes communes, jonctions et extrémités sont inchangés. Une `seed` fixe, aucun caractère aléatoire entre sessions. La couronne `EggShellModel.crownFractureY` et l'ouverture F1 sont gelées.

**Critères de validation :** photographie Chrome du mode `Réseau de fissures 3D (statique)`, repères de cadrage désactivés : segments de longueurs distinctes, cassures moins nombreuses, absence de peigne/dents de scie systématiques, raccords toujours exacts. Test structurel ajouté pour limiter le nombre de coudes saillants par arête ; **non exécuté tant que Flutter n'est pas disponible**. Aucune validation artistique de V3 à ce stade.

## Réseau statique V1 — retour de capture et morphologie V2

La capture du 8 octobre montre un réseau fixé à la surface, mais les **ramifications présentent des segments presque droits** et leurs coudes restent insuffisamment irréguliers. La cassure circulaire supérieure est également trop lisse, mais **son tracé est actuellement partagé avec le F1 validé** : ne pas la modifier dans la même itération.

**Correction ciblée livrée :** échantillonnage intermédiaire des arêtes ramifiées avec déviations anguleuses déterministes, non uniformes et limitées. Reprojection systématique des nouveaux coins sur `EggShellModel`. La topologie, les nœuds, leurs connexions et la couronne F1 restent strictement inchangés, de même que le pivot. Aucun aléatoire par session.

**Contrôle à demander :** Chrome → `Réseau de fissures 3D (statique)`, idéalement avec `Repères de cadrage` désactivés, puis une capture pour comparer les fissures organiques à la planche. Le lissage de la cassure autour de la couronne sera une itération distincte nécessitant un contrôle du bord F1. Un test de non-colinéarité bornée est ajouté, mais il doit être exécuté sous Flutter avant de déclarer la correction techniquement testée. Validation visuelle en attente.

## Itération réseau statique 3D — code livré, validation Chrome attendue

**Objectif unique :** première topologie de fissures géométriques sur `EggShellModel`, sans rotation des fragments, sans changement de F1, et sans variabilité entre sessions.

- Un `EggFractureNetwork` immuable à `seed=20261008` contient des **nœuds paramétrés sur la surface** et des **arêtes uniques échantillonnées en 3D**. Une boucle de 24 arêtes parcourt la couronne complète ; cette limite appelle **la même** méthode `EggShellModel.crownFractureY(angle)` que F1, afin de ne pas définir deux cassures différentes.
- Ramifications asymétriques reliées à des nœuds réels (avec branches mortes) ; couleur et tracé projeté servent de **diagnostic de topologie**, pas de simulation d'ouverture ni de découpe de matière réalisée.
- Mode distinct `Réseau de fissures 3D (statique)` accessible dans l'atelier, sans toucher aux réglages F1 existants. L'œuf fixe est peint via `EggShellModelPainter` ; les tracés arrière sont occultés dans l'aperçu orthographique.
- Test structurel ajouté à `widget_test.dart` : déterminisme, arêtes non dupliquées, jonctions communes, compatibilité de la boucle avec la couronne F1 et tous les échantillons sur l'ellipsoïde local. **Ce test est écrit mais non exécuté** sans Flutter.
- Critères de validation utilisateur à venir : réseau visiblement attaché à la surface, contour inchangé, connexions exactes sans fissures flottantes, fissures non géométriques/répétitives et style proche du stade 25 % / 5 % de `reference/Planche Eclosion.png`. **Ne pas activer la variabilité ni la mécanique multi-fragments avant retour visuel.**

## Audit structurel préliminaire — 8 octobre 2026 (lecture seule du moteur)

**Portée exacte :** examen du code `egg_timer/lib/lab/egg_shell_model.dart` sur `5ea7d3d`, vérification numérique indépendante des formules `EggShellModel` et des transformations F1, et relecture de la vidéo Chrome de diagnostic du 8 octobre (ouvertures ~1, 37, 81 et 100 %). Aucun code Dart modifié, ni test Flutter exécuté ; aucun rendu non diagnostique supplémentaire vérifié pendant cet audit.

**Constats étayés :**
- `EggShellModel` définit les rayons, les points, les normales et l'inset suivant la normale. Le chapeau et les faces du bol s'appuient sur ce modèle ; les frontières F1/bol avant emploient la même fonction de rupture et les mêmes angles d'échantillonnage. Vérification arithmétique indépendante : raccordement échantillonné sans écart et épaisseur à `2.5` (écart numérique maximal mesuré ~`5.3e-14`) sur les ouvertures 0/25/50/75/100 %. La transformation du chapeau est rigide sur les échantillons examinés.
- `_DepthScene` compare les valeurs Z interpolées des triangles projetés et masque les groupes de faces par un propriétaire visible par pixel de modèle. Un cas synthétique de deux triangles se croisant vérifie que l'avant-plan change bien quand leurs profondeurs se croisent. Cela établit la **logique de comparaison**, non la qualité garantie du rasteriseur Flutter ni de tous les recouvrements.
- La vidéo de diagnostic montre F1 extérieur, F1 intérieur, paroi arrière intérieure et bol avant sans retour manifeste du contour fantôme. Leur faible lisibilité volumique à grande ouverture demeure, sans preuve que la cause soit exclusivement l'occlusion : la pose d'ouverture est encore provisoire.

**Limites et risques non levés :** `dart format`, `flutter analyze` et `flutter test --no-pub test/widget_test.dart` non exécutés (Dart/Flutter indisponibles dans cet environnement). L'échantillonnage du tampon de profondeur reste à environ 1 unité modèle, indépendamment de la densité de pixels et du zoom ; anti-crénelage, qualité des recouvrements à toutes les résolutions et coût CPU n'ont pas été mesurés. Ne **pas** déclarer le volume F1 entièrement validé ni sa cinématique définitive.

**Décision de progression :** aucun défaut structurel bloquant **démontré** par cet audit restreint. La prochaine itération peut porter exclusivement sur **la topologie statique du réseau de fissures 3D à seed fixe**, indépendamment du pivot provisoire, en conservant les invariants géométriques. Avant toute animation de détachement multi-fragments, revalider les recouvrements F1/bol à 0/25/50/75/100 %, y compris rendu normal, et effectuer les vérifications Flutter disponibles. Si un défaut structurel est révélé, suspendre le réseau pour le corriger isolément.

## Décision active — ordre de développement confirmé le 8 octobre 2026

**Statut : plan de travail approuvé, non équivalent à une validation du moteur.** Cette section remplace les anciennes listes « Prochaine étape » et « Ordre de développement » situées plus bas, qui restent historiques. Ne pas conclure que l'occlusion, la concavité ou l'animation F1 ont été validées.

### Priorité immédiate : vérification structurelle du socle 3D

- Référence : `EggShellModel` reste **l'unique géométrie** pour silhouette, faces, tranche et futures arêtes de rupture. Le Z-buffer logiciel introduit par `196718e` existe dans le code ; le diagnostic par couleurs `59fd82c` montre plusieurs surfaces distinctes ; **ni la correction de profondeur ni la qualité volumique ne sont entièrement validées**.
- Vérifier, sans changer d'emblée le pivot ou la forme, aux ouvertures **0 / 25 / 50 / 75 / 100 %** : profondeur/masquage des triangles qui se recouvrent, visibilité correcte du devant et de l'arrière, absence de surfaces artificielles, de trous non voulus, de contour fantôme et de bord en escalier, cohérence de la géométrie unique et de la tranche. Employer les couleurs de diagnostic puis le rendu normal. Contrôler les anomalies de calcul plutôt que rechercher déjà la finition artistique.
- **Critère de sortie :** fiabilité technique suffisante, examinée en code et en Chrome ; noter honnêtement les tests Flutter non exécutés et les imperfections restantes. Si une anomalie structurelle persiste, corriger celle-ci isolément avant d'avancer. Une concavité encore peu lisible à cause de l'orientation provisoire ne doit **pas** déclencher des retouches de pivot tant que les exigences techniques sont remplies.

### Séquence après passage de ce contrôle

1. **Topologie de fissuration 3D statique**, sur la coquille intacte : fissures fines, irrégulières, asymétriques, ramifiées et partiellement interrompues selon `reference/Planche Eclosion.png`. Éviter les motifs répétitifs. Les fissures sont des frontières de matière réelles : arête commune unique pour deux fragments voisins, géométrie compatible avec futures tranches et attaches. **Première configuration fixe, avec seed fixe pour tests/reproductibilité ; sans animation de rupture.**
2. **Variabilité déterministe et contrôlée** : seed créée une fois **par session d'éclosion**, géométrie préparée une fois puis conservée sur tous les frames. Variations bornées de forme, trajectoire et ramifications sans casser la topologie commune ; une même seed reproduit exactement le même réseau. Valider d'abord le réseau fixe avant d'activer des variantes.
3. **Mécanique physique et apparition du poussin** : propagation dans le réseau, pressions communes, fissure → ouverture → tranche → fragmentation, attaches/charnières puis libération, pivot et chute. Concevoir/ajuster alors le pivot de F1 et les autres mouvements selon la place nécessaire à l'apparition du poussin ; éviter des animations indépendantes par fragment.
4. **Rendu final et intégration** : poussin validé, matériaux/éclairage, intérieur et décor, son/haptique, synchronisation du timer (`00:00` = poussin éclos), performances Web puis Android.

**Gel du cycle en cours :** ne pas modifier prématurément le pivot F1, la forme de la coquille, le poussin, F2–F5, le décor ou l'aspect artistique. Conserver épaisseur `2.5`, oscillation `1.5`, `reference/Planche Eclosion.png`, et l'atelier 3D seul du commit `2b6af2d`. L'ancien `fragment_scene.dart` est historique et toujours requis par des tests ; ne pas le supprimer. Une itération = un défaut principal, commit ciblé, validation Chrome par l'utilisateur.

## Validé — moteur antérieur et acquis historiques

Acquis explicitement validés, à préserver :
- Mouvement général doux de l'œuf ; oscillation `1.5` et épaisseur `2.5`.
- Pression interne excentrée, principe des attaches successives et pivot asymétrique.
- Continuité du même fragment, rotation, éclairage dépendant de l'orientation et chute globalement crédible.
- Correction CanvasKit validée : après opérations booléennes, réapplication explicite de `PathFillType.evenOdd` pour préserver correctement les trous/occlusions et supprimer la grande zone grise artificielle.
- Lèvre fixe validée : géométrie, exposition, épaisseur `2.5`, occlusions et matériau actuel à préserver.
- Cavité intérieure validée structurellement le 5 octobre 2026 : une seule surface intérieure globale de l'œuf, indépendante des fragments ; les ouvertures ne font que révéler cette surface. Le polish artistique de matière/éclairage reste différé.
- Refactor du fragment unique vers une définition générique `_FragmentSpec` validé visuellement le 5 octobre 2026 : aucune régression notable sur la fissure, l'ouverture, le soulèvement, la lèvre fixe, la cavité, la rotation, la chute ou les occlusions. La `seed` est présente comme métadonnée de reproductibilité mais ne modifie encore aucun rendu.
- Agrégation mono→liste validée visuellement le 5 octobre 2026 : les frames de fragments sont désormais préparées en liste et les apertures sont agrégées pour calculer la coquille fixe, sans changement visuel du fragment de référence.
- Introduction du cluster partagé validée visuellement le 5 octobre 2026 avec un seul fragment : les arêtes primaires et les impulsions de pression sont centralisées sans régression du rendu de référence.
- Premier voisin à arête réellement partagée validé visuellement le 5 octobre 2026 : continuité de la fissure commune, absence de double bord/patch et maintien crédible de la plaque voisine pendant le détachement du fragment principal.
- Couplage pression commune → flexion/dommage → pivot du voisin validé visuellement comme amélioration le 5 octobre 2026.
- Détachement complet du voisin validé visuellement le 5 octobre 2026 : dernière charnière rompue par dommage cumulé du cluster, transition continue pivot → libération → chute, trajectoire distincte et conservation correcte de la silhouette jusqu'au sol après généralisation du moteur.
- Tri d'occlusion dynamique validé visuellement le 5 octobre 2026 : l'ordre de peinture dépend désormais de la profondeur 3D courante des fragments et non de leur ordre dans la liste.
- Modèle de pression interne clarifié le 5 octobre 2026 : les événements représentent des efforts du poussin (appuis locaux puis effort plus large tête/corps sur la zone fragilisée). Un même effort peut affecter plusieurs plaques et produire des détachements simultanés ou quasi simultanés.

## Diagnostic F1 avec identification des surfaces — vidéo du 8 octobre 2026

La vidéo Chrome `20261008-1317-08.7434472.mp4` montre l'atelier **3D unifié** en couleurs de diagnostic lors d'une ouverture de 1 à 100 %. Le chapeau extérieur (vert), la face intérieure F1 (magenta), la paroi arrière intérieure du bol (bleu) et l'extérieur avant du bol (cyan) sont visibles comme quatre surfaces distinctes. La silhouette extérieure et le bord de rupture apparaissent continus sur les images observées. Ce constat n'établit pas une validation exhaustive du Z-buffer ni de la qualité volumique.

**Défaut dominant maintenant isolé :** même à 80–100 %, le chapeau expose surtout une bande de face intérieure, plutôt qu'une concavité évidente ; le bol arrière apparaît également comme une bande. Le rendu évoque deux parties de coquille séparées, non une véritable ouverture volumique. La correction de profondeur `196718e` ne suffit donc pas à valider F1.

**Cause probable à diagnostiquer :** la transformation `_transformPoint` n'applique au maximum qu'une rotation X de `0.34 rad` (≈ 19,5°), ainsi qu'une faible rotation Z et un décalage. Selon le point de vue fixe et la projection orthographique, cette orientation peut présenter l'intérieur presque de profil. Ne pas confondre ce problème potentiel de pose/projection avec un nouvel ordre de peinture défectueux sans preuve.

**Décision en attente :** pour obtenir une ouverture volumique plus lisible, il pourrait falloir changer la cinématique F1 (angle/axe/position de charnière), actuellement **gelée** dans les règles de reprise. Demander accord utilisateur avant de modifier ce mouvement ; ne pas toucher en attendant au modèle géométrique commun, à l'épaisseur 2.5, à l'oscillation 1.5, ni au multi-fragments. Aucun correctif Dart supplémentaire apporté à ce stade. Les contrôles avec et sans mode diagnostic, à plusieurs ouvertures, restent requis pour valider le rendu final.

## Atelier 3D seul — simplification du 8 octobre 2026

À la demande de l'utilisateur, l'ancien mode de visualisation 2D n'est plus accessible depuis `FragmentLab`. Le commutateur « Valider le modèle 3D unifié » et les réglages liés à l'ancien mode (ralenti, format, visibilité de l'œuf et des ombres, ancienne progression/lecture) sont retirés. L'atelier ne présente désormais que l'œuf unifié intact et le chapeau F1 unifié, avec son curseur d'ouverture, les repères et l'identification des surfaces.

Le moteur historique `fragment_scene.dart` et `fragment_playback.dart` **ne sont pas supprimés** : les tests techniques historiques y font encore référence. Les tests d'interface de l'ancien atelier ont été remplacés par un test de l'interface F1 active. La géométrie, la cinématique F1 et les valeurs `2.5`/`1.5` ne sont pas modifiées. Le format 9:16 est fixe **dans cet atelier uniquement** ; le support 9:20 reste une exigence produit future.

Attention : la capture fournie montrait le mode unifié désactivé (ancien rendu 2D). Ce rendu ne permet donc pas de valider ni d'invalider le correctif F1 de profondeur `196718e`. Une nouvelle capture du modèle F1 seul avec et sans « Identifier les surfaces » reste nécessaire pour établir la cause de la bande.

## Validé sur le nouveau prototype F1 (8 octobre 2026)

Portée de la validation : atelier `EggShellModel`, **chapeau F1 seul**. Dans l'ancien cluster F1–F5, F1 ne désignait pas ce même chapeau : ne pas confondre les numérotations. L'ancien moteur `fragment_scene.dart` reste historiquement documenté, mais ses résultats n'établissent pas la validité volumique de F1 dans le nouvel aperçu.

- **`e7feb3d`** : restauration non destructive de la base `04f282b`, F1 enveloppant la couronne 360° et le profil issu de `EggShellModel`. C'est le point de départ de l'aperçu actuel, pas un certificat de rendu fini.
- **`eb3470b`** : ligne de rupture suivie par le premier rang de triangles du bol ; disparition des découpes rectangulaires **confirmée visuellement**.
- **`9ff48ab`** : rotation cohérente des normales et calcul d'éclairage interne. Amélioration partielle observée, volume intérieur **non validé**.
- **`6cf38a7`** : remplacement du remplissage 2D de la cavité par une paroi intérieure arrière maillée sur le modèle 3D. Changement de code effectué ; rendu 3D encore insuffisant.
- **`4a57b07`** : suppression du contour projeté de l'œuf intact par-dessus F1 ; disparition du contour fantôme **confirmée visuellement**.
- **`86562cd`** : tentative de réorganisation des couches d'occlusion (arrière du bol → intérieur F1 → extérieur du bol → tranche et extérieur F1). Vidéo suivante : défaut de bandes/superpositions **toujours présent**.

Les validations de l'ancien moteur multi-fragments (notamment son tri dynamique d'occlusion **inter-fragments**) sont conservées plus bas comme **historique**, et ne résolvent pas le problème différent d'intersection et d'occlusion **entre triangles du bol et de F1** dans la nouvelle vue.

## Défaut de profondeur signalé auparavant (historique, à recontrôler)

**Non résolu au 8 octobre 2026 : occlusion et lecture volumique de F1 à l'ouverture.**

La silhouette extérieure du chapeau, le bord désormais continu et l'animation d'ouverture sont à préserver. En revanche, la face intérieure reste trop proche d'une membrane beige ; des bandes ondulées se superposent entre F1 et la coquille fixe, particulièrement à grande ouverture. L'espace vide, la vraie concavité et la tranche ne se distinguent pas de façon crédible.

**Diagnostic de code :** `EggShellF1PreviewPainter`, dans `egg_timer/lib/lab/egg_shell_model.dart`, calcule des positions 3D mais peint des triangles projetés en `.xy` avec `canvas.drawVertices()`. La visibilité repose encore sur le placement des groupes dans un ordre fixe, sans test de profondeur global. La gestion d'occlusion est donc **une cause architecturale probable**, non une validation que toute la géométrie est correcte.

Les dernières corrections cosmétiques et les réordonnancements seuls n'ont pas suffi : **ne plus empiler d'artifices 2D**.

## Gel appliqué lors des anciens correctifs F1 (historique)

- `EggShellModel` comme source de géométrie unique pour la surface, la silhouette, les normales et l'épaisseur de la coquille.
- Chapeau F1 360° : forme extérieure, profil et mouvement actuellement observés, ligne de fracture continue ; conserver la progression manuelle 0–100 %.
- Épaisseur `2.5`, oscillation `1.5` ; ne pas modifier la mécanique validée de l'ancien atelier.
- `reference/Planche Eclosion.png` immuable ; aucun fond, poussin, moteur temporel, matériel artistique ou F2–F5 à retoucher.
- Éléments déjà corrigés : pas de marches au bord du bol ni de contour fantôme réintroduits.
- Seul objectif autorisé : profondeur/masquage cohérents entre les faces F1, la tranche et le bol inférieur.

## Plan d'action antérieur au Z-buffer (historique)

1. Inspecter la géométrie et la projection des faces extérieures/intérieures et de la tranche, la convention de profondeur et les triangles visibles, **sans modifier immédiatement leurs formes**.
2. Implémenter une visibilité réellement dépendante de la profondeur à l'échelle des triangles/surfaces (test de profondeur, rastérisation Z-buffer ou autre solution démontrablement correcte en Flutter/Web et compatible avec le projet Android). Un simple tri de groupes par centre Z ne constitue pas une garantie suffisante si les surfaces s'entrecroisent à l'écran.
3. Conserver `EggShellModel`, la trajectoire et les frontières partagées ; corriger **un seul défaut principal**. Ne pas ajouter de membrane, patch, gradient ou faux fond.
4. Vérifier `dart format` sur les seuls Dart modifiés, `flutter analyze` et `flutter test --no-pub test/widget_test.dart` **si les outils sont disponibles** ; déclarer précisément les vérifications non exécutées. Aucune GitHub Action.
5. Faire valider sous Chrome les ouvertures **0 %, 25 %, 50 %, 75 % et 100 %** : absence de bandes superposées, faces creuses lisibles, tranche crédible, continuité du mouvement, silhouette intacte, aucun retour du bord en escalier et du contour fantôme. Ne déclarer F1 validé qu'après retour visuel explicite.

**Point de reprise historique (avant `196718e`) :** `86562cd` était le dernier commit modifiant le moteur F1 dans le fil précédent, suivi de mises à jour documentaires. Il ne s'agit plus du HEAD courant : un Z-buffer logiciel a été ajouté par `196718e`, l'identification de surfaces par `59fd82c` et l'atelier a été simplifié par `2b6af2d`. Voir **Décision active** au début du fichier.

Dans le nouveau plan actif, la **topologie statique de fissures** commence après validation **structurelle** du socle 3D ; la variabilité par seed suit la validation du réseau fixe. Les fragments **animés** et le poussin restent postérieurs à ces étapes. Aucune randomisation d'un frame à l'autre.

## Dette connue / à traiter plus tard

- Rebond final légèrement trop marqué pour une coquille légère.
- Polish artistique de la cavité intérieure à reprendre plus tard : contraste, teinte, ombres internes et apport de lumière selon l'ensemble des ouvertures.
- Le cluster partagé, l'arête commune, le couplage pression → flexion/dommage/pivot, le détachement complet du voisin, la continuité de forme post-libération et le tri d'occlusion inter-fragments par profondeur 3D courante sont validés visuellement. La phase tardive utilise maintenant une trajectoire continue de contact du poussin et un couple de rotation spatial ; cette extension reste à valider.
- Décor, matière et œuf provisoires ; éléments artistiques séparés et poussin validé à intégrer.
- Compte à rebours produit et interactions +5/−5 absents ; intégrer l'éclosion à `00:00` et formaliser la visibilité du poussin avant zéro.
- Réglages d'affichage non persistants après rechargement.

## Historique antérieur — moteur multi-fragments (non actif dans F1 seul)

Les deux sous-sections ci-dessous sont archivées **sans transformer leurs affirmations en validations du nouvel aperçu F1**. Elles décrivent les itérations multi-fragments et les tests correspondants réalisés avant la reprise de `EggShellModel`.

### Ancien défaut prioritaire et corrections associées

Le fragment unique et l'ouverture sont désormais sur une base structurelle cohérente : continuité fissure → ouverture → tranche → fragment, clip evenOdd corrigé, lèvre fixe intégrée et cavité intérieure globale indépendante des fragments.

Le tri d'occlusion inter-fragments par profondeur 3D courante est validé visuellement. Les fragments 2 et 3 ont été redessinés pour former un cluster plus naturel tout en conservant leurs arêtes réellement partagées. Leur départ en vol suit maintenant la normale locale complète 3D de la coquille, puis la gravité domine, et la transition attache → vol ne comporte plus de snap artificiel à 0,001.

La dernière vidéo a montré un défaut plus précis : malgré des trajectoires latérales devenues distinctes, les fragments 2 et 3 tendaient encore vers des orientations de chute trop semblables. La rotation du vol couplé a donc été reprise : chaque plaque conserve désormais l'angle et la vitesse angulaire acquis au moment de la rupture de sa dernière attache, puis cette vitesse est amortie progressivement. La pression du poussin ne continue plus à piloter leur rotation après libération, et la hauteur d'atterrissage est calculée avec leur orientation réelle d'arrivée.

Avant de poursuivre cette validation de mouvement, la géométrie statique a été reprise une nouvelle fois le 6 octobre 2026 pour se rapprocher davantage de la planche de référence. La silhouette de l'œuf est maintenant plus large et plus pleine au milieu/bas, avec un sommet plus doux, tout en gardant la même hauteur et le même contact au sol. Le modèle 3D de surface, la cavité intérieure et le grain utilisent désormais la même largeur de référence pour éviter qu'une simple retouche 2D de silhouette désynchronise la matière.

Le cluster a également été redessiné pour rompre l'alignement horizontal : fragment 1 reste dominant, fragment 2 devient clairement le plus petit et le plus compact, et fragment 3 a été déplacé au-dessus-gauche du point de pression utilisateur, avec une vraie arête partagée sur la bonne couture du fragment 2. Les trois plaques conservent une topologie commune.

La vidéo du 7 octobre a ensuite montré que la position était meilleure mais que les fragments se détachaient encore trop séquentiellement. La cause était mécanique : un événement local ancien chargeait F2 beaucoup plus tôt que F3, tandis que les contacts du poussin arrivaient trop tard pour produire une libération réellement commune. La correction actuelle fait intervenir le poussin sur le cluster pendant la fin du détachement de F1, garde le premier contact local sous le seuil de rupture, puis applique un appui tête/corps beaucoup plus large sur F2 et F3. Les ligaments couplés utilisent désormais les mêmes bandes de résistance ; les faibles écarts de rupture doivent venir de leur géométrie et de leur distance à la pression, non de mini-timers propres aux fragments.

Un nouveau test « Vol couple: les voisins se libèrent dans la même poussée » impose que F2 et F3 se détachent dans une fenêtre de moins de 0,035 de progression et restent proches de la libération de F1.

La validation visuelle suivante a montré un nouveau défaut isolé : F3, placé plus haut sur la coquille, héritait de la composante verticale de sa normale locale et montait brutalement à la libération, comme après un coup distinct. Cette composante Y locale a été supprimée du lancement couplé. La courbure locale continue de différencier la séparation en X/Z, mais dès la rupture la gravité pilote Y pour tous les fragments couplés. Un nouveau test « aucun fragment ne reçoit de coup vertical local » verrouille ce comportement. Les 8 tests ciblés « Vol couple » passent. La suite complète reste au niveau connu : 24 tests passés / 5 échecs existants.

### Anciennes contraintes d'itération

- Mouvement général, oscillation, épaisseur, principe des attaches, pivot, éclairage et chute ; préserver ces acquis.
- Le remapping temporel artificiel a été abandonné. L'itération actuelle valide désormais la vraie chaîne causale : P1 mouvements internes → P2 bec → P3 tête/front → P4 tête + haut du corps → fissures → dommages → pivots → ruptures.
- Cinq plaques principales sont présentes dans le cluster : F1/F2/F3 existants + F4 latérale gauche + F5 avant/droite. Le bas de la coquille reste structurellement présent parce que F4/F5 conservent des attaches tardives ou persistantes.
- Rebond final, polish artistique de la cavité et rendu artistique global reportés.
- Le multi-fragments peut désormais commencer sur la base du `_FragmentSpec` validé ; ne pas introduire encore d'aléatoire libre.
- L'atelier reste un diagnostic à fragment unique, avec progression déterministe, lecture/pause, ralenti, rejeu et aperçus 9:16 / 9:20 ; ce n'est pas encore le timer produit.

## Multi-fragments et variabilité future

Décision d'architecture future, à prendre en compte sans l'implémenter maintenant. La priorité reste d'obtenir un fragment unique visuellement et physiquement correct ; cette décision ne vaut pas validation du rendu actuel.

Le futur système devra permettre qu'une nouvelle utilisation du timer ne produise pas toujours exactement la même coquille cassée.

### Architecture à prévoir

- Les fragments appartiennent à un **cluster de fracture commun** : ils ne sont pas générés comme des trous indépendants.
- Une arête entre deux fragments voisins est une seule cassure géométrique, référencée par les deux fragments.
- Les impulsions de pression sont définies au niveau du cluster ; elles propagent l'endommagement dans le réseau puis libèrent les attaches successivement.
- Le détachement d'une plaque peut redistribuer la contrainte et modifier la mobilité de ses voisines.
- Multi-fragments et fragmentation procédurale contrôlée.
- Génération déterministe à partir d'une seed créée au début d'une nouvelle éclosion et conservée pendant toute l'éclosion.
- Aucune génération aléatoire de géométrie frame par frame.
- Variations contraintes du réseau de fissures, de la forme et de la taille des fragments, des ramifications, des positions et de l'ordre de rupture des attaches, des pivots, ainsi que de petites variations de trajectoire et de timing.
- Une même seed doit permettre de reproduire exactement une éclosion pour le debug et les tests.

### Contraintes visuelles et physiques

- Conserver le langage visuel de `reference/Planche Eclosion.png`.
- Fissures irrégulières, organiques, asymétriques et non répétitives.
- La fissure doit toujours devenir réellement le bord du futur fragment.
- Préserver la continuité physique fissure → ouverture → tranche → fragment.
- Éviter un aléatoire libre pouvant produire des géométries incohérentes.

### Performance

- Cible finale Android.
- Générer et préparer la géométrie d'une éclosion une seule fois, puis la réutiliser pendant l'animation.
- Mutualiser autant que possible textures, matériaux et ressources ; éviter les allocations inutiles à chaque frame.
- Valider ultérieurement les performances sur appareil Android réel.
- Objectif de conception : animation fluide à 60 fps sur un appareil Android milieu de gamme, à confirmer par mesures réelles.

### Ancien ordre de développement (historique ; voir décision active en tête)

1. Obtenir un fragment unique visuellement et physiquement correct.
2. Rendre l'architecture `Fragment` générique.
3. Passer à quelques fragments.
4. Construire l'éclosion multi-fragments.
5. Mesurer et optimiser sur Android.
6. Introduire la génération procédurale déterministe par seed.
