# Eclosion — état courant

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

## Validé sur le nouveau prototype F1 (8 octobre 2026)

Portée de la validation : atelier `EggShellModel`, **chapeau F1 seul**. Dans l'ancien cluster F1–F5, F1 ne désignait pas ce même chapeau : ne pas confondre les numérotations. L'ancien moteur `fragment_scene.dart` reste historiquement documenté, mais ses résultats n'établissent pas la validité volumique de F1 dans le nouvel aperçu.

- **`e7feb3d`** : restauration non destructive de la base `04f282b`, F1 enveloppant la couronne 360° et le profil issu de `EggShellModel`. C'est le point de départ de l'aperçu actuel, pas un certificat de rendu fini.
- **`eb3470b`** : ligne de rupture suivie par le premier rang de triangles du bol ; disparition des découpes rectangulaires **confirmée visuellement**.
- **`9ff48ab`** : rotation cohérente des normales et calcul d'éclairage interne. Amélioration partielle observée, volume intérieur **non validé**.
- **`6cf38a7`** : remplacement du remplissage 2D de la cavité par une paroi intérieure arrière maillée sur le modèle 3D. Changement de code effectué ; rendu 3D encore insuffisant.
- **`4a57b07`** : suppression du contour projeté de l'œuf intact par-dessus F1 ; disparition du contour fantôme **confirmée visuellement**.
- **`86562cd`** : tentative de réorganisation des couches d'occlusion (arrière du bol → intérieur F1 → extérieur du bol → tranche et extérieur F1). Vidéo suivante : défaut de bandes/superpositions **toujours présent**.

Les validations de l'ancien moteur multi-fragments (notamment son tri dynamique d'occlusion **inter-fragments**) sont conservées plus bas comme **historique**, et ne résolvent pas le problème différent d'intersection et d'occlusion **entre triangles du bol et de F1** dans la nouvelle vue.

## Défaut prioritaire actuel

**Non résolu au 8 octobre 2026 : occlusion et lecture volumique de F1 à l'ouverture.**

La silhouette extérieure du chapeau, le bord désormais continu et l'animation d'ouverture sont à préserver. En revanche, la face intérieure reste trop proche d'une membrane beige ; des bandes ondulées se superposent entre F1 et la coquille fixe, particulièrement à grande ouverture. L'espace vide, la vraie concavité et la tranche ne se distinguent pas de façon crédible.

**Diagnostic de code :** `EggShellF1PreviewPainter`, dans `egg_timer/lib/lab/egg_shell_model.dart`, calcule des positions 3D mais peint des triangles projetés en `.xy` avec `canvas.drawVertices()`. La visibilité repose encore sur le placement des groupes dans un ordre fixe, sans test de profondeur global. La gestion d'occlusion est donc **une cause architecturale probable**, non une validation que toute la géométrie est correcte.

Les dernières corrections cosmétiques et les réordonnancements seuls n'ont pas suffi : **ne plus empiler d'artifices 2D**.

## Gelé pour l'itération actuelle

- `EggShellModel` comme source de géométrie unique pour la surface, la silhouette, les normales et l'épaisseur de la coquille.
- Chapeau F1 360° : forme extérieure, profil et mouvement actuellement observés, ligne de fracture continue ; conserver la progression manuelle 0–100 %.
- Épaisseur `2.5`, oscillation `1.5` ; ne pas modifier la mécanique validée de l'ancien atelier.
- `reference/Planche Eclosion.png` immuable ; aucun fond, poussin, moteur temporel, matériel artistique ou F2–F5 à retoucher.
- Éléments déjà corrigés : pas de marches au bord du bol ni de contour fantôme réintroduits.
- Seul objectif autorisé : profondeur/masquage cohérents entre les faces F1, la tranche et le bol inférieur.

## Prochaine étape

1. Inspecter la géométrie et la projection des faces extérieures/intérieures et de la tranche, la convention de profondeur et les triangles visibles, **sans modifier immédiatement leurs formes**.
2. Implémenter une visibilité réellement dépendante de la profondeur à l'échelle des triangles/surfaces (test de profondeur, rastérisation Z-buffer ou autre solution démontrablement correcte en Flutter/Web et compatible avec le projet Android). Un simple tri de groupes par centre Z ne constitue pas une garantie suffisante si les surfaces s'entrecroisent à l'écran.
3. Conserver `EggShellModel`, la trajectoire et les frontières partagées ; corriger **un seul défaut principal**. Ne pas ajouter de membrane, patch, gradient ou faux fond.
4. Vérifier `dart format` sur les seuls Dart modifiés, `flutter analyze` et `flutter test --no-pub test/widget_test.dart` **si les outils sont disponibles** ; déclarer précisément les vérifications non exécutées. Aucune GitHub Action.
5. Faire valider sous Chrome les ouvertures **0 %, 25 %, 50 %, 75 % et 100 %** : absence de bandes superposées, faces creuses lisibles, tranche crédible, continuité du mouvement, silhouette intacte, aucun retour du bord en escalier et du contour fantôme. Ne déclarer F1 validé qu'après retour visuel explicite.

**Point de reprise technique :** `86562cd` est le dernier commit modifiant le moteur F1 dans le fil du 8 octobre ; `d41a805` a ensuite mis à jour `ECLOSION_CHAT_REFERENCE.md`, et les commits documentaires suivants n'impliquent aucune modification Flutter.

La variabilité déterministe par session et les autres fragments sont à traiter **après** validation F1 : seed unique par éclosion, aucune randomisation d'un frame à l'autre.

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

### Ordre de développement

1. Obtenir un fragment unique visuellement et physiquement correct.
2. Rendre l'architecture `Fragment` générique.
3. Passer à quelques fragments.
4. Construire l'éclosion multi-fragments.
5. Mesurer et optimiser sur Android.
6. Introduire la génération procédurale déterministe par seed.
