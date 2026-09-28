# Éclosion — règles permanentes

- Projet Flutter : `egg_timer/`. Itérations Web ; contrôle Android physique avant les finitions.
- Référence visuelle principale : `reference/Planche Eclosion.png`. Ne jamais modifier les fichiers de référence visuelle.
- Priorité absolue à la continuité physique de l'animation : ne jamais la remplacer par un crossfade, un remplacement d'image ou un patch visuel. Préférer les corrections architecturales aux artifices limités à quelques frames.
- Géométrie commune aux fissures, ouvertures et fragments ; deux faces et une tranche. Pas de disparition par réduction de taille. Préserver une architecture extensible au futur multi-fragments.
- Formats portrait 9:16 et 9:20 sans étirement ; fond fixe, œuf, ombre et fragments indépendants, sans halo ni rectangle de détourage.
- `00:00` correspond à l'éclosion du poussin ; les mouvements résiduels des fragments peuvent continuer discrètement ensuite. Préserver le poussin validé et formaliser sa visibilité avant zéro lors de son intégration.
- Épaisseur validée = `2.5` ; oscillation validée = `1.5`. Préserver les mécanismes explicitement validés sauf nécessité directe de la tâche.
- L'atelier fragment est un diagnostic, pas le rendu artistique validé ni le moteur temporel produit.
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
