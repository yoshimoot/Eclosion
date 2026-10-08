# Éclosion — règles permanentes

- Projet Flutter : `egg_timer/`. Itérations Web ; contrôle Android physique avant les finitions.
- Référence visuelle principale : `reference/Planche Eclosion.png`. Ne jamais modifier les fichiers de référence visuelle.
- Priorité absolue à la continuité physique de l'animation : ne jamais la remplacer par un crossfade, un remplacement d'image ou un patch visuel. Préférer les corrections architecturales aux artifices limités à quelques frames.
- Géométrie commune aux fissures, ouvertures et fragments ; deux faces et une tranche. Pas de disparition par réduction de taille. Préserver une architecture extensible au futur multi-fragments.
- Formats portrait 9:16 et 9:20 sans étirement ; fond fixe, œuf, ombre et fragments indépendants, sans halo ni rectangle de détourage.
- `00:00` correspond à l'éclosion du poussin ; les mouvements résiduels des fragments peuvent continuer discrètement ensuite. Préserver le poussin validé et formaliser sa visibilité avant zéro lors de son intégration.
- Épaisseur validée = `2.5` ; oscillation validée = `1.5`. Préserver les mécanismes explicitement validés sauf nécessité directe de la tâche.
- L'atelier fragment est un diagnostic, pas le rendu artistique validé ni le moteur temporel produit.
- Dans l'aperçu 3D unifié, `EggShellModel` est la source géométrique unique : profil de l'œuf, silhouette calculée à partir de la surface, coupe, face extérieure, face intérieure, tranche, épaisseur et normales. Pas de contour 2D indépendant réintroduit pour simuler une ouverture.
- La validation active porte sur **F1 seul, le grand chapeau supérieur** de l'aperçu 3D. La nomenclature diffère de l'ancien cluster F1–F5 ; les validations historiques de `fragment_scene.dart` ne valent pas validation automatique du nouvel aperçu F1. Ne réintégrer ni F2–F5 ni le poussin avant validation de F1.
- Lorsqu'une vue 2.5D projette des maillages 3D en `.xy`, ne pas assimiler l'ordre fixe de `Canvas.drawVertices` ou un tri de groupes à un véritable test de profondeur. Vérifier les occlusions sur toutes les faces et phases pertinentes ; privilégier une méthode réellement sensible à la profondeur et démontrée plutôt qu'une bande, un gradient, un patch ou une correction valable à une seule frame.
- Séparer les statuts : code modifié, format/analyse/tests exécutés, puis validation visuelle dans Chrome. Ne marquer « validé » qu'après une observation/validation explicite du résultat correspondant ; signaler sans ambiguïté les vérifications impossibles à exécuter.
- Reprendre en priorité le défaut architectural d'occlusion de F1 et du bol inférieur avant de poursuivre le multi-fragments. Après deux corrections visuelles inefficaces, revenir au diagnostic plutôt que d'empiler les retouches.
- Pas de GitHub Actions pour les itérations du prototype ; préférer les vérifications locales quand l'environnement le permet, puis la vidéo Chrome de l'utilisateur. Préserver les modifications locales : `git pull --ff-only`, `git stash` ciblé si nécessaire, jamais de `stash pop` automatique.
- Lire `PROGRESS.md` (état actif et validé) et `ECLOSION_CHAT_REFERENCE.md` (décisions, historique et critères visuels) avant de reprendre une itération.
- Une itération visuelle = un défaut principal. Si la cause technique est incertaine, inspecter et diagnostiquer avant de modifier.
- Modifications ciblées sur une branche ; préserver les changements locaux de l'utilisateur. Pas de ZIP ni de régénération d'images sans nécessité ; aucun gros fichier de spécification supplémentaire sans demande explicite.
- Mettre à jour `PROGRESS.md` seulement lorsqu'une étape est réellement validée ou que la priorité change ; distinguer tests exécutés et validation visuelle utilisateur.

## Vérification après modification de code Dart

Depuis `egg_timer/`, exécuter soi-même, dans cet ordre :
1. `dart format` uniquement sur les fichiers Dart réellement modifiés.
2. `flutter analyze`.
3. `flutter test --no-pub test/widget_test.dart`.
4. Corriger les erreurs provoquées par la modification et relancer les vérifications concernées avant de terminer.

Ne pas demander à l'utilisateur de lancer ces vérifications. Ne pas lancer automatiquement `flutter run -d chrome` : la validation visuelle interactive est effectuée séparément par l'utilisateur.
