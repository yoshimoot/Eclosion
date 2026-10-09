# Eclosion — état courant

## Validation V11.12–V11.17 — Contrôle local ciblé RÉUSSI (9 octobre 2026)

**Preuve utilisateur sur le commit `7884560` :** `git pull --ff-only origin prototype/fragment-lab-v1` : succès. `flutter analyze --no-pub` : **No issues found!** (3,6 s). `flutter test --no-pub` avec l'ensemble des fichiers `test/*_test.dart` **SAUF** `test/widget_test.dart` : **95 tests réussis, zéro échec** (environ 4 s). La commande a terminé en affichant `TESTS CIBLÉS TERMINÉS`. Ce résultat englobe les tests des pivots, de l'expulsion, du diagnostic géométrique/temporal et les deux nouveaux tests de démarrage/navigation de l'atelier 3D actif.

**Statut exact :** code analysé sans diagnostic et **sous-ensemble automatisé V11.12–V11.17 VALIDÉ par exécution locale**. Ne pas confondre avec une validation visuelle du naturel des mouvements ou avec une suite générale verte. Le lancement de `flutter test --no-pub` sans exclusion sur `4b4585b` a précédemment fait apparaître **16 échecs dans `widget_test.dart` et ses tests historiques `fragment_scene.dart`**, 113 réussites ; ces tests restent inchangés, actifs et en échec dans le périmètre général tant que leur état n'est pas réévalué. Ne pas les `skip` ni ajuster artificiellement les seuils.

**Suite du développement :** unifier à terme les diagnostics V11.14–V11.17 avec les mouvements V11.12/V11.13 dans l'aperçu 3D, en gardant **une itération mécanique/visuelle à la fois** ; ne pas considérer la modélisation validée artistiquement et demander à l'utilisateur un contrôle Chrome ponctuel au jalon d'intégration plutôt qu'à chaque petite correction. Aucun nouveau test ou intervention requis pour ce statut.

## Validation groupée V11.12–V11.17 — Diagnostic des 16 échecs historiques (9 octobre 2026)

**Résultat local réellement exécuté par l'utilisateur sur `4b4585b` :** `flutter analyze --no-pub` : **No issues found!**. `flutter test --no-pub` : **113 réussites / 16 échecs**. Les 16 échecs affichés dans le journal proviennent de `test/widget_test.dart` et de ses deux modules de tests importés `fragment_lab_continuity.dart` et `fragment_occlusion.dart`. Les six suites V11.12–V11.17 n'ont aucun échec signalé dans cette sortie, mais le résultat global est **rouge** ; ne pas annoncer « tous les tests réussis ».

**Cause architecturale vérifiée en lecture GitHub :** `lib/main.dart` charge `FragmentLab`, qui affiche `EggShellF1PreviewPainter` / `EggGeometryPreview`, tandis que `fragment_scene.dart` (prototype 2D historique) n'est plus accessible depuis cette interface. Pourtant les anciens tests attendent des pixels `FragmentScene`, une case « Afficher les ombres » absente, des points de texture et des anciens fragments F2/F3. Comparaison des blobs Git avant les nouveaux moteurs V11.13–V11.17 (commit `627d9f2`) et maintenant (`4b4585b`) : `main.dart`, `fragment_lab.dart`, `fragment_scene.dart`, `fragment_playback.dart`, `fragment_lab_continuity.dart` et `fragment_occlusion.dart` **identiques**. `widget_test.dart` n'a eu qu'un ajout d'accolades à un ancien prédicat V10.4 lors du correctif des warnings. La sortie ne démontre donc pas une régression des nouveaux maillages ou diagnostics de collision, mais **n'exonère pas l'ancien moteur de ses défauts**, qui restent visibles.

**Décision :** conserver les 16 échecs en place, sans modifier les valeurs attendues, sans `skip`, sans supprimer les tests et sans déclarer faussement la suite complète verte. Ajouter `test/egg_active_lab_smoke_test.dart` (2 tests) pour vérifier réellement l'atelier `MyApp → FragmentLab → EggGeometryPreview` et l'absence de `FragmentScene` dans son arbre de rendu. Ce test n'est pas une validation visuelle de F1 ni de l'éclosion.

**Prochain contrôle groupé local :** `flutter analyze --no-pub` puis `flutter test --no-pub` sur les fichiers `*_test.dart` **à l'exception de `widget_test.dart`**, avec mention explicite qu'il s'agit d'un **sous-ensemble actif**, non de toute la suite. Aucun besoin de demander de capture Chrome. Le traitement séparé du moteur 2D legacy ne doit pas prendre priorité sur les éléments 3D validés.

## Validation groupée V11.12–V11.17 — Correction des avertissements d'analyse (9 octobre 2026 ; tests en attente)

**Retour local exact reçu :** `git pull --ff-only origin prototype/fragment-lab-v1` a réussi, jusqu'au commit `e2473f2`. `flutter analyze --no-pub` a signalé **7 diagnostics** (5 warnings et 2 infos), puis le script PowerShell s'est arrêté sur le code retour non nul : **aucune suite `flutter test --no-pub` n'a été exécutée**. Il n'y a pas de compilation Flutter ou de test réussi à déclarer à cette étape.

**Correction ponctuelle :** supprimer le paramètre privé `_Surface.offset` de `egg_geometry_preview.dart` car aucun appel ne fournit une valeur autre que `Offset.zero` ; le rendu garde donc sa projection identique `Offset(p.x,p.y)`. Ajouter les accolades au `while` local (même incrémentation), et au `if` du test V10.4 (même prédicat et retour). Supprimer les imports inutilisés exactement signalés par l'analyseur dans `egg_bowl_temporal_sweep_test.dart` (`dart:math`, `egg_shell_model`), `egg_full_bowl_mesh_test.dart` (`egg_shell_fragment_mesh`) et `egg_panel_pair_collision_test.dart` (`egg_shell_model`). Les sept diagnostics sont corrigés par revue statique, mais le statut final de l'analyseur est **non confirmé avant sa prochaine exécution locale**.

**Aucun changement de mécanique ni de données :** `EggShellModel`, F1, réseau V10.4, seed, tessellations V11.2–V11.9, charnières V11.12, expulsion V11.13 et diagnostics V11.14–V11.17 gelés. Le fonctionnement logique des tests existants reste identique. Aucune mise à jour d'image, CI ou Chrome.

**Validation suivante :** un seul contrôle local : `flutter analyze --no-pub`, puis `flutter test --no-pub` uniquement si l'analyse passe. Attendre les sorties réelles pour corriger d'éventuelles erreurs de compilation ou échecs fonctionnels, sans les présumer.

## V11.17 — Balayage temporel du fragment contre le bol fixe (9 octobre 2026 ; tests Flutter en attente)

**Objet unique :** couvrir le dernier risque de traversée temporelle non diagnostiqué : le panneau 3D V11.13 peut contacter le bol fixe V11.9 **entre deux images** même lorsque des contrôles instantanés V11.14 sont négatifs. La V11.16 traite déjà les contacts inter-fragments dans le temps ; ce module la complète pour le bol **immobile**, sans modifier les trajectoires.

**Architecture :** ajout dans `EggBowlCollisionInspector` d'une requête pure `hasBroadPhaseCandidate(seconds, padding)` qui conserve et réutilise la BVH déjà construite sur les triangles physiques du bol V11.9. Nouveau `egg_bowl_temporal_sweep.dart` : sur chaque intervalle, majorant analytique du déplacement d'un sommet du panneau `(v0 + a * t_fin + |omega| * r_max) * durée/2`, où `r_max` est mesuré sur les deux faces du vrai panneau et `omega` sa rotation libre constante V11.13. Requête BVH au milieu avec boîtes des triangles mobiles élargies par cette marge. Si elles sont toutes disjointes des boîtes fixes, l'**intervalle entier** est certifié libre de contact sous ces cinématiques rigides. Sinon un contrôle V11.14 est effectué au milieu, puis l'intervalle est subdivisé jusqu'à preuve, observation ou limite de calcul.

**Trois résultats honnêtes :** `certifiedClear` (majorant conservateur prouvant l'absence de contact sur tout l'intervalle pour cette géométrie/cinématique), `observedContact` (contact observé à un instant, sans prétendre avoir calculé le premier instant d'impact), `inconclusive` (contact possible sans preuve/observation, budget épuisé). Une trame instantanée négative ne suffit **jamais** à prouver un intervalle positif. Les prédicats ont une tolérance numérique, pas une validation de moteur physique général.

**Six tests ajoutés non encore exécutés en Flutter** : bornes de déplacement, comparaison directe de sommets mobiles des deux panneaux, reproductibilité de rapport, refus de faux succès avec budget nul, intervalle nul, temps et budgets illégaux. Rejouer `egg_shell_collision_diagnostic_test.dart`, `egg_bowl_temporal_sweep_test.dart`, `egg_panel_release_motion_test.dart` et les suites V11.12–V11.16 lors du prochain jalon local. Aucune capture Chrome demandée. Ne pas multiplier les modules sans compléter ce jalon.

**Gel :** F1, fissures et seed V10.4, maillages V11.2–V11.9, épaisseur 2.5, rotation V11.12, expulsion V11.13, rendu Chrome, poussin et minuteur inchangés. Ajouts limités au diagnostic bol V11.14, au module temporel V11.17 et aux tests. Ni déformation du fragment, ni correction forcée, ni gravité, ni changement d'angle validé. Statut : GitHub publié à confirmer, tests Dart/Flutter non disponibles dans cet environnement.

## V11.16 — Balayage temporel conservateur des collisions (9 octobre 2026 ; tests locaux en attente)

**Problème traité :** les diagnostics instantanés V11.14/V11.15 peuvent manquer une traversée entre deux instants échantillonnés. La V11.16 ajoute une recherche adaptative qui distingue trois résultats : **certifiedClear** (une enveloppe géométrique conservatrice prouve l'absence de contact sur TOUS les instants de l'intervalle), **observedContact** (contact réellement observé sur une trame, instant non assimilable à l'heure exacte d'impact) et **inconclusive** (budget ou résolution insuffisante). Aucune absence de collision n'est inférée d'échantillons simplement négatifs.

**Architecture :** `EggPanelPairCollisionInspector.hasBroadPhaseCandidate` utilise la BVH V11.15, dans le repère matériel du premier panneau, et des boîtes de triangles mobiles élargies d'une marge de déplacement. Nouveau module `egg_pair_temporal_sweep.dart` : bornes analytiques de vitesse relative des sommets selon V11.13, `v1+v2+w2*r2+w1*(distance_centres_majorée+r2)`. Le majorant des centres utilise la distance au milieu et les vitesses bornées par la FIN de la fenêtre. Pour chaque intervalle, déplacer théoriquement chaque sommet de `L*(durée/2)` autour du milieu ; si aucune boîte élargie ne rejoint le panneau indexé, l'intervalle entier est libre sous les cinématiques rigides définies. Sinon inspection au milieu et découpe récursive des intervalles, avec limites explicites `maxDepth`, `maxFrames`, `maxPairsPerFrame` et `minInterval`. Tous les temps individuels restent entre 0 et 2 s ; les deux horloges peuvent être décalées.

**Limites :** cette garantie concerne les maillages/trajectoires V11.13 et une enveloppe conservatrice sous tolérance numérique, pas une simulation physique complète, ni une résolution de collision, ni un calcul exact du premier instant d'impact. Les régions candidates peuvent être indéterminées. Aucun déplacement, fissure, attache ou surface source n'est modifié. L'atelier Chrome demeure identique.

**Tests ajoutés :** six tests `egg_pair_temporal_sweep_test.dart`, couvrant borne nulle et positive, contrôle indépendant de la majoration sur sommets physiques, déterminisme, refus de faux verdict en cas de budget nul, instant ponctuel et entrées invalides. `flutter analyze` et tests Flutter restent **non exécutés dans cet environnement**. Les suites V11.12–V11.15 doivent être rejouées lors du prochain lot de tests locaux. Aucune capture Chrome demandée maintenant.

## V11.15 — Diagnostic 3D des collisions ENTRE panneaux mobiles (9 octobre 2026 ; tests en attente)

**Priorité actuelle :** poursuivre l'inspection des libérations V11.13 sans solliciter de captures Chrome à chaque itération. La V11.14 a introduit le classement triangle–triangle et son correctif de traversée (commit `52f07f3`) ; une comparaison mathématique indépendante de six cas synthétiques est passée, **mais les tests Flutter V11.12–V11.14 restent non confirmés**. Ne pas présenter le mouvement comme visuellement ou physiquement validé.

**Objet unique V11.15 :** inspecter les contacts et traversées **entre les deux vrais maillages mobiles**, en conservant leurs propres temps écoulés depuis libération (les libérations peuvent être décalées). Nouveau `egg_panel_pair_collision.dart` utilisant le même classifieur `EggTriangleCollision` que V11.14. Au lieu de rebâtir une hiérarchie spatiale à chaque trame, le premier panneau est indexé **une seule fois dans son repère matériel initial**. Le second panneau est transformé selon V11.13, puis reprojeté par l'**inverse rigide exact du mouvement du premier** : angle total = angle de charnière + rotation libre (même axe), centre déplacé selon V11.13. La classification 3D a alors lieu dans un repère commun non déformé, avec boîtes 3D et budget maximal de paires.

**Rapport par instant :** temps distincts `firstSeconds` et `secondSeconds`, paires comparées, contacts et intersections, identifiants des deux premiers triangles concernés et drapeau `complete`. Une recherche interrompue ne permet jamais d'affirmer l'absence de collision ; une trame exhaustive sans contact ne prouve pas les instants **entre** échantillons. L'outil est uniquement diagnostique : **aucun ajustement de trajectoire, rupture, gravité, repoussée par collision ni modification de l'affichage**. Les contacts entre deux faces coplanaires sont qualifiés de contacts, pas d'intersection pénétrante par défaut.

**Six tests prévus, non exécutés ici :** retour exact d'un point du premier panneau à son repère matériel après un mouvement complet ; transformation croisée des deux mouvements ; contrôle d'un échantillon avec deux horloges indépendantes et quota ; déterminisme + ordre inversé ; rejets des temps/budgets illégaux et des mauvais propriétaires des trajectoires. Les tests ne présupposent **aucun résultat de collision sur les panneaux réels**, puisque ces valeurs nécessitent une exécution Flutter. Garder V11.12/V11.13/V11.14 en régression.

**Gel permanent :** géométrie V10.4 et seed, F1, maillages V11.2–V11.9, normalisation 2.5, mouvement V11.12/V11.13, rendu Chrome, poussin, timer. Ce module ne nécessite aucune action ou capture de la part de l'utilisateur avant un jalon de validation groupée.

## V11.14 — Correction du classement contact/intersection (9 octobre 2026 ; tests Flutter en attente)

Une vérification numérique indépendante des exemples de test a révélé que le simple critère « pénétration positive sur tous les axes séparateurs » échouait sur deux triangles qui **se traversent réellement** : un triangle infiniment mince a nécessairement une épaisseur nulle le long de sa propre normale. Le commit initial `db34c89` classait cette intersection transverse comme un simple `touching`, ce qui était incorrect. La classification utilise maintenant les axes séparateurs pour **rejeter les paires disjointes**, puis teste explicitement une **traversée stricte du plan du triangle opposé avec coordonnées barycentriques intérieures**. Les contacts coplanaires ou aux frontières restent classés `touching`, conformément au contrat actuel. Nouveau test de traversée très peu profonde. Ce contrôle géométrique non exécuté en Flutter ne constitue pas une garantie de collision continue, de résolution ni de robustesse sur tout le maillage réel. Le total de tests nouveaux est désormais de **8**.

## V11.14 — Diagnostic de contact triangle/triangle entre fragment et bol (9 octobre 2026 ; tests en attente)

**Accord utilisateur :** poursuivre les corrections techniques avec peu d'interventions ; demander Chrome seulement aux jalons visuels importants. À la V11.13, la rotation libre + poussée selon la normale existe en **données**, mais n'est pas encore animée sur Chrome ; les tests V11.12/V11.13 restent à confirmer. Ne pas parler d'expulsion validée.

**Objectif unique V11.14 :** construire un **détecteur de collision 3D non intrusif** pour diagnostiquer la trajectoire V11.13 par rapport au bol fixe V11.9, sans encore corriger les intersections. Nouveau `egg_shell_collision_diagnostic.dart` : classification de deux triangles dans les trois dimensions avec axes séparateurs (normales, produits des arêtes, axes dans le plan pour les cas coplanaires), en distinguant `separated`, `touching`, et `intersecting` avec une tolérance explicite. Les contacts tangents ne sont pas automatiquement des collisions pénétrantes.

**Performances :** le bol fermé `EggFullBowlMesh` est indexé une fois dans un arbre de boîtes 3D (BVH) ; le fragment mobile V11.13 est transformé rigidement au temps demandé. Seules les boîtes qui se croisent déclenchent la classification géométrique. Le rapport de trame fournit nombre de paires effectivement comparées, paires en contact, intersections détectées, et indicateur `complete` ; un quota de calcul interrompu **n'autorise jamais** à déclarer l'absence d'intersection. Les changements entre échantillons de temps ne sont pas couverts par ce contrôle discret, même lorsque la trame est exhaustive. Pas d'auto-correction par écrêtage de déplacement ni de faux masque d'écran.

**Tests ajoutés, non exécutés dans ChatGPT :** `egg_shell_collision_diagnostic_test.dart` (7 tests) sur paires synthétiques séparées, intersection transverse, arête partagée, zones coplanaires superposées ou séparées, mauvais paramètres/dégénérescences et diagnostic borné sur les maillages physiques. Les tests V11.12/V11.13 restent à rejouer séparément. Après validation, compléter avec une vérification **inter-fragments** et une détection temporelle continue ou à pas adaptatif ; ces deux points sont encore explicitement absents.

**Gel :** aucun changement de la géométrie, du seed V10.4, de F1, des fissures, de l'épaisseur 2.5, des maillages avant/arrière, du modèle de rotation, des courbes d'expulsion et du rendu Chrome. Ajout uniquement d'une fonction diagnostique et de ses tests ; aucune nouvelle capture demandée. Les vrais résultats de collision sur toute la trajectoire ne sont **pas connus** tant que les contrôles n'ont pas été exécutés.

## V11.13 — Trajectoire de libération continue après charnière (9 octobre 2026 ; tests en attente)

**Accord de workflow utilisateur :** avancer en autonomie entre les jalons visuels ; ne plus exiger une capture Chrome à chaque petite itération. Dernier HEAD connu de V11.12 : `627d9f2`. Les tests locaux V11.12 n'ont pas encore été transmis ; ne pas considérer ce pivot comme visuellement validé.

**Objet unique V11.13 :** séparer proprement la **fin du mouvement attaché** du début du **mouvement libre**, sans modifier les panneaux validés ni l'atelier. Nouveau `egg_panel_release_motion.dart` : reçoit un `EggPanelHingePose` calculé au moment de la dernière rupture, calcule le centre de surface du panneau par pondération de l'aire de ses triangles physiques et la normale extérieure moyenne à partir de `EggShellModel.normalAt`. La direction de poussée est la normale moyenne **transformée par le pivot**, plutôt qu'un faux déplacement latéral ou une coordonnée d'écran. Au temps libre `t=0`, chaque point coincide précisément avec la position obtenue par la charnière (continuité de **position**). Ensuite, le centre est déplacé sur cette direction par `d=v0*t + 0,5*a*t²` avec paramètres bornés, et la coquille tourne rigidement autour de son **centre matériel libéré**, dans la continuité du sens angulaire du pivot. Transformation identique pour faces extérieure/intérieure/tranches et normales ; aucune échelle ni fonte de fragment.

**Limites intentionnelles :** les coefficients de vitesse/accélération/rotation par défaut sont des **paramètres expérimentaux non validés artistiquement**, et la vitesse à l'instant de libération n'est pas encore raccordée à une horloge d'animation attachée. Les résultats garantissent une continuité de position, **pas de vitesse**. Aucune rupture automatique, gravité, collision ni chute n'est simulée ; il n'y a pas de garantie d'absence d'intersections avec le bol. `EggPanelReleaseMotion` est une primitive pure non intégrée au moteur de rendu ; Chrome reste identique à V11.12 jusqu'à une future intégration contrôlée.

**Tests ajoutés mais non exécutés dans l'environnement ChatGPT :** `test/egg_panel_release_motion_test.dart` (6 tests). Ils couvrent les deux panneaux, zéro saut à l'instant de rupture, monotonie de la poussée le long de la normale, rigidité des maillages/épaisseur `2.5`, rotation du centre libéré, indépendance de l'ordre d'évaluation temporelle et rejets d'entrées invalides. Les tests `test/egg_panel_hinge_pose_test.dart` de V11.12 restent à confirmer. Avant tout jalon Chrome, exécuter localement ces deux suites ensemble et corriger leurs éventuelles erreurs. **Ne pas demander de nouvelles captures pour cette itération géométrique seule.**

**Gel strict :** fichiers de fissures V10.4 et seed `20261008`, F1, contours et épaisseur des panneaux V11.2, jonctions V11.5, bol fermé V11.9, poses de pivot V11.12, atelier Chrome, poussin et timer ne changent pas. Aucun GitHub Action, changement d'image ou fichier visuel.

## V11.12 — Correction de l'orientation des charnières basses (9 octobre 2026 ; tests et Chrome en attente)

**Nouveau retour Chrome :** captures à Pivot **0°, 20° et 45°** sur V11.11. L'état à 0° reste correct ; l'ouverture croissante est visible, mais la bascule est asymétrique et se lit surtout comme un mouvement **latéral de volets**, pas comme une mise en relief de coquille expulsée vers l'avant. Les faces/tranches sont préservées, mais le pivot actuel n'est **pas validé visuellement**.

**Cause identifiée dans le code :** `EggPanelHingePose.fromGraph` choisissait des arêtes **PRIMARY** du bord du bol fixe, en privilégiant leur profondeur Y maximale. Ces arêtes longeaient les côtés des panneaux, de direction principalement verticale ; leur axe tend donc à produire une rotation proche d'un volet de porte. Une force interne ne devrait pas être représentée exclusivement par ce lacet. Ne pas compenser par un faux décalage en XY.

**Correction unique V11.12 :** sélectionner, pour chaque panneau, une arête **CONNECTION** existante et non partagée avec son voisin sur sa bordure inférieure. Choisir la plus **horizontale en projection XY**, sur la base du rapport `abs(dy)/hypot(dx,dy)` des deux extrémités de graphe ; départage stable par ID. L'axe reste le vrai **sous-segment central 3D** de cette arête, dont les deux points d'ancrage sont strictement immobiles. Le sens de rotation reste calculé vers la normale extérieure et ne crée aucun déplacement libre. Faces, tranches, épaisseur `2.5` et normales pivotent rigidement ensemble.

**Portée :** seulement `egg_panel_hinge_pose.dart`, ses tests, la description du mode Pivot et ce suivi. Les modes Assemblé/Écarté sont inchangés. Aucun changement du réseau V10.4, F1, des contours V11.2–V11.9, du moteur visuel principal, de l'oscillation, du poussin ou du temps. **Ce pivot reste diagnostique** : une arête courbe complète n'est pas une charnière rigide et les autres attaches n'ont pas encore de mécanique de rupture. Pas d'expulsion/chute. Vérifier les interférences dans le bol après validation du pivot.

**Tests locaux requis :** `flutter test --no-pub test/egg_panel_hinge_pose_test.dart test/egg_panel_inspection_pose_test.dart`. Le test d'origine du pivot vérifie désormais le type CONNECTION, qu'il n'est pas partagé, la provenance de ses points et le choix de la connexion la plus horizontale. Les tests existants de rigidité, points fixes et direction sortante restent actifs. **Ne pas annoncer de succès de tests sans exécution locale.** Chrome mode Pivot à 0°, 20°, 45° ; comparer la lisibilité de la bascule au comportement V11.11 avant de l'accepter.

## V11.11 — Rotation attachée sur sous-segment de fissure (9 octobre 2026 ; tests en attente)

**Décision utilisateur après V11.10 :** coupler à terme rotation et expulsion, mais **commencer par un pivot physique attaché** pour ne pas rendre indépendants des fragments encore reliés. Les captures V11.10 à ~40° et 70° montrent que l'inclinaison révèle les tranches ; ces images ne prouvent pas un mouvement de rupture. La V11.9 dispose de **10/10 tests locaux réussis**. Les 4 tests V11.10 ne sont pas encore confirmés par la conversation.

**Objet unique V11.11 :** création de `egg_panel_hinge_pose.dart`, une rotation 3D rigide et déterministe attachée à deux points **réels du graphe V10.4**, sans translation ni chute. Chaque panneau choisit une arête **primaire en contact avec le bol fixe**, non partagée avec l'autre panneau, en privilégiant celle située le plus bas. L'axe est le court sous-segment central de cette arête (deux échantillons originaux directement représentés dans son maillage) ; ses deux points restent fixes à chaque angle. Le sens de rotation est déduit de `EggShellModel.normalAt` et du point du panneau le plus éloigné de l'axe pour dégager le fragment vers l'extérieur, pas d'un signe arbitraire. Transformation de Rodrigues identique pour extérieur, intérieur, murs de tranche et normales ; la géométrie, l'épaisseur 2.5 et la zone fixe ne changent jamais.

**Important :** une fissure 3D courbe ne peut pas constituer une charnière rigide droite sur toute sa longueur. Cette première V11.11 préserve **les deux extrémités du sous-segment candidat**, pas toutes les autres attaches. Ce n'est ni la simulation de rupture définitive, ni le pivot final validé, ni une garantie d'absence de collision : ces contrôles viendront ensuite. Ne pas prétendre que la chaîne F1→2→3 est animée ni que la gravité existe déjà.

**Chrome :** sur la page de géométrie, l'ancien sélecteur devient « Assemblé / Écarté / Pivot » ; les modes Assemblé et Écarté conservent strictement leur ancien fonctionnement. Le nouveau mode Pivot applique seulement le pivot attaché (sans translation) à 0–55° et laisse indépendant le curseur d'inclinaison diagnostique Écarté. Le moteur d'occultation par profondeur continue de prendre les vraies positions 3D ; la surface extérieure, la face intérieure et la tranche sont cohérentes. Les tests `test/egg_panel_hinge_pose_test.dart` (5 tests) couvrent l'origine des attaches, l'immobilité des deux points, les distances et l'épaisseur, l'ouverture vers l'extérieur et le rejet des entrées invalides.

**Gel :** F1, propagation et fissures V10.4 (seed 20261008), subdivisions V11.5, bol fermé V11.9, forme des deux panneaux, épaisseur 2.5, oscillation 1.5, poussin, time engine et références inchangés. Aucune image ou masque et aucun changement au peintre F1. Code poussé sur `prototype/fragment-lab-v1`, tests Flutter non exécutables dans l'environnement de ChatGPT. Faire d'abord `flutter test --no-pub test/egg_panel_hinge_pose_test.dart` puis Chrome, mode Pivot à **0°, 20° et 45°**, idéalement une vidéo lente. Attendre validation avant de coupler expulsion et rotation.

## V11.10 — Inclinaison diagnostique des fragments V11.8 (9 octobre 2026 ; validation Chrome en attente)

**Retour local V11.9 confirmé :** `flutter test --no-pub test/egg_full_bowl_mesh_test.dart test/egg_rear_bowl_mesh_test.dart` → **`00:01 +10: All tests passed!`**. Le volume global avant+arrière passe les cinq contrôles de V11.9, dont l'incidence orientée et Euler=2 ; cinq tests V11.8 de régression également réussis. Ce résultat technique ne signifie pas que le relief des panneaux ou le rendu final est validé visuellement.

**Défaut ciblé V11.10 :** dans les captures Chrome V11.8 « Assemblé/Écarté », les panneaux paraissent plats malgré deux faces et une tranche d'épaisseur 2.5. Cela s'explique principalement par la projection frontale orthographique et le décalage XY seul, qui ne révèle quasiment pas la profondeur (z) des tranches. Ne pas augmenter artificiellement l'épaisseur ni peindre des bandes décoratives.

**Correction d'inspection ciblée :** `egg_panel_inspection_pose.dart` introduit une transformation 3D **rigide**, réversible, autour de l'axe Y et du centre XZ de chaque panneau ; une translation de diagnostic est appliquée ensuite. L'angle peut être réglé de 0° à 70° via un curseur dans **la vue V11.8 « Écarté » uniquement**, avec 42° comme valeur d'inspection initiale, en opposé pour panneau gauche/droit. Les faces extérieure et intérieure et toutes les tranches sont transformées avec la même matrice, et les normales diagnostiques sont tournées de la même manière avant éclairage simplifié. La profondeur z réellement transformée est réutilisée par le moteur d'occultation au pixel. En mode **« Assemblé »**, aucune transformation n'est appliquée : même dessin et mêmes objets qu'en V11.8, sans discontinuité de couture.

**Interprétation :** il s'agit d'une **rotation d'observation**, pas d'une animation, d'un pivot validé, ni d'une modification du mouvement d'éclosion. Ne pas juger le pivot physique sur cet exemple. La coque fixe avant+arrière et les deux maillages de panneaux V11.2 restent inchangés. Aucune dérive vers F2–F5, poussin, timer, changement de seed, refonte de fissures ou remplacement d'images.

**Validation :** nouveau `test/egg_panel_inspection_pose_test.dart` (4 tests), contrôlant l'identité géométrique à 0°, la préservation des distances/épaisseur 2.5 par rotation 3D, la conservation des indices de parois et les paramètres invalides. Aucun Flutter/Chrome disponible dans cet environnement : exécuter localement `flutter test --no-pub test/egg_panel_inspection_pose_test.dart`, puis `flutter run -d chrome`, comparer le mode Écarté à **0°, 42° et 70°** pour apprécier faces et tranches. Renvoyer captures/vidéo. Ne pas déclarer la lisibilité volumétrique validée avant inspection Chrome.

## V11.9 — Contrôle du volume de coquille avant + arrière (9 octobre 2026 ; tests en attente)

**Retours Chrome V11.8 reçus :** les captures de la page dédiée montrent (1) les deux panneaux **assemblés**, contour des fissures visible et bol inférieur continu ; (2) les panneaux **écartés**, mêmes contours, trou apparent entre eux sans disparition. La bande brune près de la couronne est **compatible avec la face intérieure arrière visible sans F1** et ne suffit pas à démontrer un défaut. Les panneaux ont encore une apparence mince/plate du fait de la projection orthographique statique : leur épaisseur 2.5 existe mais sa lisibilité artistique n'est **pas validée**. Le rendu ne valide ni l'orientation ni le manifold de la jonction arrière.

**Objet unique V11.9 :** vérification d'assemblage topologique **sans changement d'affichage**, dans `egg_full_bowl_mesh.dart`. Le builder accepte la `EggStationaryBowlShell` V11.6 et la `EggRearBowlMesh` V11.8 correspondantes. Il réutilise **par identité** tous les sommets latéraux validés V11.7 (y compris le pôle commun), reconstruit un espace d'indices global [extérieur, intérieur], et remappe les triangles avant, arrière et les tranches supérieures existantes. **Aucune paroi latérale** n'est ajoutée ; les deux bandes de tranche de la couronne avant et arrière se rejoignent aux mêmes sommets. Le modèle et les deux maillages sources restent inchangés.

**Cinq tests ajoutés mais non exécutés ici :** (1) fusion exacte des sommets de couture et invariance des positions, (2) pour CHAQUE arête de triangle, exactement deux faces d'incidence et directions opposées, plus caractéristique d'Euler = 2 pour un volume monocoquille, (3) uniquement les parois supérieures existantes, (4) épaisseur 2.5 sur tous les sommets, (5) déterminisme et rejet d'un assemblage incohérent. Le constructeur vérifie l'identité des deux demi-coquilles et l'identité des faces intérieures le long des côtés. Un échec sera corrigé **dans la structure**, jamais par un cache ou une bande de dissimulation.

**Ne rien changer aux validations :** F1, fissures V10.4, contours, épaisseur, oscillation, modèle, atelier et vue V11.8, poussin, propagation et temps. Tests à exécuter localement : `flutter test --no-pub test/egg_full_bowl_mesh_test.dart test/egg_rear_bowl_mesh_test.dart`. Attendre les résultats avant d'intégrer `EggFullBowlMesh` dans le moteur visuel et de travailler la lisibilité volumétrique.

## V11.8 — Premier aperçu Chrome des maillages validés (9 octobre 2026 ; validation visuelle en attente)

**Retour utilisateur :** après `a477453`, `flutter test --no-pub test/egg_rear_bowl_mesh_test.dart test/egg_rear_bowl_boundary_test.dart` → **`00:01 +10: All tests passed!`**. Les deux faces du bol arrière et son contour ont ainsi passé les dix tests techniques ; aucun affichage artistique validé à ce stade. Demande explicite : « je voudrais voir ce que ça donne sur Chrome ».

**Ajout isolé :** bouton **« Voir les maillages V11.8 »** dans les contrôles de `FragmentLab`, ouvrant une page indépendante `EggGeometryPreview` dans `egg_geometry_preview.dart`. Le peintre actif `EggShellF1PreviewPainter` ne change PAS. Cette page assemble en lecture seule les données réelles de `EggShellFrontAssemblyBuilder`, `EggStationaryBowlShellBuilder` et `EggRearBowlMeshBuilder`, et affiche le bol fixe, deux panneaux et l'intérieur arrière. Diagnostic 9:16, ombrage géométrique simplifié et test d'occultation **par profondeur 3D au pixel**, plutôt qu'un ordre arbitraire des groupes Canvas.

**Interactions de diagnostic uniquement :** assemblé/écarté (les positions décalées sont une **mise en présentation**, pas un mouvement d'éclosion), masquer chaque panneau, afficher la face intérieure arrière ou extérieure, et afficher les contours de matière. Les frontières et triangles proviennent des **maillages existants** ; aucune réduction/disparition, crossfade, clip de fissure décoratif ou modification de géométrie n'est ajoutée. Le grand chapeau F1 n'est **pas représenté** dans cet assemblage V11.8 : son animation validée reste visible dans l'atelier précédent. Ne pas interpréter l'aperçu comme une scène 3D produit complète.

**Gel :** `egg_shell_model.dart`, fissures V10.4, F1, ses animations, maillages V11.2–V11.8, timing, poussin, référence visuelle et paramètres restent inchangés. Seules une nouvelle vue, la navigation UI de l'atelier et cette section de suivi sont ajoutées. Ne pas basculer le moteur temporel produit. La fermeture globale avant/arrière doit encore être validée séparément (V11.9), ainsi que la profondeur/occlusion **par inspection réelle dans Chrome**.

**Contrôles :** vérification statique et publication GitHub seulement dans ce chat : ni Flutter SDK ni Chrome utilisables dans l'environnement de l'assistant. Tester `flutter run -d chrome`, puis bouton « Voir les maillages V11.8 » ; transmettre capture ou courte vidéo de la vue assemblée et écartée. En cas d'erreur de compilation Flutter, la corriger avant d'annoncer une validation visuelle.

## V11.8 — Correctif de paramétrisation arrière (9 octobre 2026 ; tests locaux en attente)

**Échec utilisateur confirmé sur `a0d17ac` :** le test V11.8 compile après l'ajout de l'import `EggShellPoint3`, mais `setUpAll` échoue avec `Bad state: Rear boundary has an unexpected angular winding` dans `EggRearBowlMeshBuilder._angle`. **Aucun des cinq tests géométriques V11.8 n'a pu s'exécuter.** Le contour V11.7 est déjà validé par ses propres cinq tests et ne doit pas être modifié.

**Cause matérielle :** les côtés de la demi-coquille avant ont été raffinés par projection `EggShellModel.surfaceAt(x,y)`. En particulier près du **pôle inférieur**, ces vrais sommets se décalent légèrement hors des méridiens angulaires idéaux `π/2` et `3π/2`. L'ancienne V11.8 tentait de convertir tous les points en angles continus sur le seul hémisphère arrière puis d'interpoler ces angles vers `π`. La garde rejetait donc des points physiques valides ; supprimer la garde sans changer la construction est également incorrect, car l'interpolation angulaire autour du pôle peut engendrer des triangles repliés.

**Correctif géométrique ciblé :** dans `egg_rear_bowl_mesh.dart`, supprimer seulement le calcul d'angle `_angle` et conserver **par identité** tous les sommets du périmètre V11.7. Pour les nouvelles bandes intérieures, interpoler chaque coordonnée `(x,y)` vers un centre arrière fixe `(0,centerY)`, puis calculer les sommets 3D par **`EggShellModel.surfaceAt(x,y,back:true)`**. Le centre lui-même utilise la même projection arrière. La continuité de la couture avant/arrière n'est pas touchée ; les triangles, la face intérieure de 2.5 et les tranches de F1 reprennent les mêmes règles d'indices, sans masque ni substitution visuelle.

**Contrôle renforcé :** le deuxième test V11.8 vérifie en plus que tous les **sommets nouvellement créés** sont effectivement sur la surface arrière (z négatif ou nul, même x/y que `surfaceAt(back:true)`). Les sommets originaux des côtés gardent leurs coordonnées 3D originales et n'ont pas à vérifier `z<=0`. Le test d'orientation des triangles déjà présent reste intact : il **doit** passer, sans désactivation ni inversion arbitraire des normales. Le contour V11.7, les maillages V11.2–V11.6, F1, les fissures, l'atelier, le poussin et l'animation restent gelés.

**Vérification exigée :** `flutter test --no-pub test/egg_rear_bowl_mesh_test.dart test/egg_rear_bowl_boundary_test.dart`. Attendre la réussite locale des dix tests avant de démarrer V11.9. Aucun test Flutter exécuté ici : validation GitHub/statique uniquement.

## V11.8 — Faces incurvées du bol arrière et tranche de couronne F1 (tests en attente, 9 octobre 2026)

**Retour local V11.7 confirmé :** `flutter test --no-pub test/egg_rear_bowl_boundary_test.dart test/egg_stationary_bowl_shell_test.dart` → **`00:01 +10: All tests passed!`**. Le contour arrière V11.7 et le bol avant V11.6 sont donc techniquement vérifiés par ces suites, sans validation de l'affichage.

**Objet unique V11.8 :** construire la **demi-coquille arrière statique** avec face extérieure sur `EggShellModel`, face intérieure normale de `2.5`, et parois de tranche **seulement** sur la couronne arrière F1. `egg_rear_bowl_mesh.dart` consomme le contour V11.7 avec **exactement les objets `EggShellPoint3` d'origine sur ses bords**. La triangulation se fait par trois bandes concentriques en espace paramétrique (angle de révolution, hauteur) vers un centre arrière. Toutes les bandes internes restent sur `model.pointAt` ; le contour externe conserve les vrais sommets de l'avant, même si leur reprojection a légèrement décalé les méridiens. Pas de nouvelles subdivisions ni de triangles de liaison sur ces côtés, donc pas de T-junction introduite lors du raccord futur.

**Délimitation :** 12 arêtes arrière de couronne F1 × 16 segments réels par arête = **192 segments supérieurs**. Seules ces 192 arêtes reçoivent des faces de tranche. Les deux arcs latéraux avant/arrière restent ouverts et partagent déjà le même échantillonnage V11.7 ; les deux extrémités verticales des tranches restent libres tant que les deux demi-coquilles ne sont pas réunies en un seul maillage. Les faces internes sont obtenues par `model.inset(point, 2.5)` et les triangles sont inversés.

**Vérifications prévues (cinq tests non exécutés ici) :** identité exacte des sommets latéraux/du contour, géométrie sur l'ellipsoïde de révolution, normale et épaisseur 2.5, incidences topologiques des arêtes ouvertes limitées aux seuls arcs latéraux et à leurs extrémités, absence de triangle de face extérieure inversé, stabilité et entrées invalides. La fermeture globale (weld des deux demi-coquilles, recouvrement et orientation des triangles, éventuelles intersections) doit être validée **séparément**, sans modifier le peintre actif avant ce contrôle.

**Gel intégral :** F1, fissures V10.4, seed, oscillation, propagation, modèle, volumes V11.2, bol avant V11.6, contour V11.7, poussin, scène et timing restent inchangés. Aucun rendu visible attendu sous Chrome. Après succès des tests V11.8 : vérifier et souder conceptuellement avant + arrière, puis valider continuité/occlusion avant toute animation physique.

## V11.7 — Couture latérale réelle et contour arrière F1 (tests en attente, 9 octobre 2026)

**Retour PowerShell confirmé sur `e5fdbc3` :** les deux suites `egg_stationary_bowl_shell_test.dart` et `egg_shell_front_assembly_test.dart` passent **9/9** (`00:01 +9: All tests passed!`). La V11.6 (face intérieure et tranche supérieure du bol fixe AVANT) est ainsi validée par les tests, pas encore visuellement.

**Objectif unique V11.7 :** préparer le **raccord matériel continu avec la coquille ARRIÈRE** sans inventer un contour latéral théorique ou une bande de détourage. Le raffinement V11.4/V11.5 reprojette ses milieux d'arêtes sur `EggShellModel` : les côtés raffinés ne sont donc pas nécessairement exactement sur le plan `z=0`. Pour assurer une vraie continuité, les côtés arrière doivent partager les **SOMMETS 3D RÉELS** du maillage avant et non des points nouvellement calculés avec `pointAt(y,±π/2)`.

**Nouveau `egg_rear_bowl_boundary.dart` :** parcourt exclusivement le contour ouvert de `EggStationaryBowlShell` entre couronne droite F1 (nœud 18), pôle inférieur commun, et couronne gauche F1 (nœud 6). Expose les IDs des sommets de droite/gauche, **par référence directe aux sommets extérieurs avant**, et garantit le même sommet au bas. Complète ce contour par les **12 arêtes arrière de la couronne F1 existante** (`18–23`, `0–5`, 16 sous-segments par arête), sans reformuler leur géométrie. La frontière arrière candidate devient un cycle 3D fermé : couronne arrière droite→gauche, flanc gauche→pôle, flanc droit inversé→droite. Le raccord des épaisseurs arrière sera réalisé depuis les mêmes normales du modèle.

**Portée vérifiable :** uniquement les frontières, pas encore de maillage arrière triangulé, de paroi arrière, de rendu, de charnière ni de mouvement. Les deux arêtes verticales encore ouvertes à V11.6 ne sont volontairement pas masquées. Le prochain changement devra construire la surface incurvée arrière **sur cette frontière partagée exacte**, et contrôler les normales/occlusions avant tout affichage.

**Acquis gelés :** F1, le réseau V10.4 (50 nœuds/52 arêtes), seed, profondeur du modèle, épaisseur `2.5`, oscillation `1.5`, propulsion/propagation, volumes V11.2, maillage du bol V11.4, assemblage V11.5, atelier et poussin. Aucun fichier existant de production n'est changé.

**Cinq tests ajoutés (non exécutés ici) :** `flutter test --no-pub test/egg_rear_bowl_boundary_test.dart` ; ils vérifient l'identité des sommets communs, la continuité des arêtes de contour, les 12 arêtes de couronne arrière, la fermeture 3D et la stabilité pour un échantillonnage grossier. Rejouer V11.6 si nécessaire. **Ne pas poursuivre à la triangulation arrière avant leur réussite locale.**

## V11.6 — Correction du test d'incidence des deux extrémités (8 octobre 2026)

**Retour réel PowerShell :** après récupération de `d9f5429`, exécution des suites V11.6 et V11.5 ensemble : **8 tests réussis, 1 échec**, dans `V11.6: interior and cut walls share manifold edges only`. Comptage réel des arêtes ouvertes = `4098` ; test attendait `4096`. Les autres vérifications (épaisseur 2.5, faces, tranches, stabilité, assemblage V11.5) passent.

**Diagnostic topologique :** la demi-coquille avant comporte deux arcs de silhouette ouverts, un extérieur et un intérieur (ensemble `2 × openSilhouetteEdgeCount` arêtes), **plus exactement deux arêtes de liaison verticale entre les faces** situées aux extrémités gauche et droite de la tranche supérieure. Tant que la face arrière n'est pas raccordée, ces deux arêtes verticales doivent rester **ouvertes**, sans créer de fausse paroi sur les côtés. Il s'agit d'une attente de test incorrecte, pas d'un défaut de maillage démontré.

**Correctif ciblé et renforcé :** dans `egg_stationary_bowl_shell_test.dart` uniquement, reconstruire l'ensemble attendu des arêtes ouvertes à partir du contour raffiné, en excluant les segments de la tranche supérieure, puis ajouter les deux liaisons verticales aux extrémités. Comparer **les identifiants de toutes les arêtes d'incidence 1** à cet ensemble exact : cela détecte les manques, doublons et trous inattendus, au-delà du simple total `2×N+2`. Le code de production, les maillages, F1, les fissures et le rendu ne changent pas.

**Tests :** correctif publié, mais sa réussite locale **reste à confirmer**. Exécuter `flutter test --no-pub test/egg_stationary_bowl_shell_test.dart test/egg_shell_front_assembly_test.dart`. Résultat attendu : **9/9**. Ne pas passer au raccord arrière avant confirmation.

## V11.6 — Face intérieure et tranches réelles du bol fixe avant (tests en attente, 8 octobre 2026)

**Retour PowerShell V11.5 confirmé :** `flutter test --no-pub test/egg_shell_front_assembly_test.dart` → **`00:01 +4: All tests passed!`**. Après les 15 tests V11.2/V11.3/V11.4 déjà réussis, la topologie commune de l'assemblage V11.5 a passé ses quatre nouveaux tests. Cela reste une validation technique, pas une validation du rendu.

**Objectif unique V11.6 :** créer la face intérieure incurvée et les tranches de découpe du **bol fixe AVANT**, à partir de l'assemblage V11.5 déjà cohérent. Nouveau module `egg_stationary_bowl_shell.dart` : garde sans modification les sommets et triangles externes du bol fixe ; génère une face intérieure par `EggShellModel.inset(outer, 2.5)` et inverse les triangles internes ; suit le bord supérieur depuis le nœud F1 `6` vers `18`, en intégrant les trois segments de couronne F1 encore intacts et la chaîne des 15 arêtes de fissure partagée. Les subdivisions sont exactement celles du maillage V11.5 (`2^refinementPasses` par segment source). Les parois de tranche sont construites directement entre sommets extérieurs et intérieurs de ce bord, avec 2 triangles par segment.

**Précaution architecturale :** **NE PAS créer de tranche sur les méridiens de silhouette**. Ceux-ci forment une frontière temporairement ouverte entre la demi-surface avant et la future demi-surface arrière ; les fermer indépendamment produirait une fausse bande de coquille plate. Le nouveau volume partiel est donc intentionnellement **ouvert sur les côtés**, pas un maillage solide complet de l'œuf. L'enveloppe arrière et le raccord final restent des étapes distinctes. Aucun patch alpha ni forme écran.

**Gel :** aucun changement de `EggShellModel`, de F1, des fissures V10.4, de la seed, des épaisseurs et oscillations validées, des volumes V11.2, de la propagation, du moteur temporel ou du peintre atelier. Pas de mouvement, charnière, chute ou poussin à cette étape. Le rendu Chrome actuel reste strictement identique.

**Tests V11.6 ajoutés (non exécutés dans cet environnement) :** `flutter test --no-pub test/egg_stationary_bowl_shell_test.dart` ; vérification de l'épaisseur et des normales, conservation de la surface avant, continuité de la tranche supérieure, incidences topologiques à deux faces et ouvertures latérales intentionnelles, déterminisme et paramètres invalides. Si réussis, passer au raccord avec l'arrière avant toute substitution du rendu existant. Rejouer en régression V11.5 et V11.4 si nécessaire.

## V11.5 — Raffinement commun des frontières entre les trois maillages (tests en attente, 8 octobre 2026)

**Retour utilisateur confirmé :** les trois suites V11.2/V11.3/V11.4 réussissent ensemble, `00:01 +15: All tests passed!` sur le commit `68399e1`. La structure actuelle du bol fixe est donc validée techniquement sur ces tests, mais reste non intégrée au rendu.

**Problème unique de cette itération :** le raffinement adaptatif actuel choisit séparément ses passes 1→4 par région ; deux faces voisines peuvent ainsi avoir des sommets différents entre les mêmes échantillons de fissure, donnant des T-junctions lors de leur séparation. Le tracé de la fissure et les points d'origine ne doivent pas bouger.

**Solution :** l'option `refinementPasses` (0–5) permet d'utiliser un nombre explicite de passes sur les maillages existants sans modifier le mode adaptatif par défaut. `egg_shell_front_assembly.dart` construit d'abord les deux panneaux et le bol, mesure leurs vrais niveaux de subdivision, sélectionne le plus élevé, puis reconstruit les seuls maillages qui étaient moins raffinés. Pour chacun des **15 segments de graphe panneau–bol et 3 segments de graphe panneau–panneau** (18 arêtes de matière au total), le constructeur compare les sommets 3D de chaque sous-segment d'origine et refuse une divergence de densité (T-junction) ou de position. L'algorithme n'impose pas arbitrairement un nombre de subdivisions ; il se base sur les triangulations réelles.

**Invariants :** V10.4, F1, couronne, modèle, seed, oscillation `1.5`, épaisseur nominale `2.5`, propagation, peintre et rendu Chrome inchangés. Ce travail est **uniquement géométrique**, sans trou rendu, nouvelle animation, pivot, chute ou poussin. Le coût du raffinement commun et la jonction avec les surfaces intérieures et tranches du bol devront être évalués avant tout rendu animé Android.

**Tests ajoutés, pas encore exécutés dans ce chat :** `flutter test --no-pub test/egg_shell_front_assembly_test.dart`, puis les 3 suites de régression V11.2/V11.3/V11.4. Ne pas considérer le raccord comme validé avant la réussite des tests locaux.

## V11.4 — correction après tests locaux (8 octobre 2026)

**Résultats confirmés par PowerShell :** V11.3 `egg_stationary_bowl_boundary_test.dart` **5/5 réussis**, V11.2 `egg_shell_fragment_mesh_test.dart` **5/5 réussis** ; V11.4 `egg_stationary_bowl_mesh_test.dart` **2 réussis, 3 échecs** sur le commit `30fbfcb`. Détails : comparaison d'identité d'objets pour des points latéraux régénérés ; aire projetée des triangles `58247.82323821751` contre aire du contour source `58247.91105950529` (écart `0.087821...`) ; `Degenerate final shell triangle` lorsque `sideSegments=24`.

**Diagnostic et correction ciblée :** les deux méridiens de silhouette sont échantillonnés sur `EggShellModel` ; à densité latérale trop faible, les cordes discrètes peuvent légèrement inverser la frontière près de leurs intersections avec le raccord de couronne F1, laissant un polygone localement non simple. `EggStationaryBowlMeshBuilder` applique désormais un **minimum de 64 subdivisions de méridiens**, tout en acceptant des demandes plus fines. Aucune modification de la vraie courbe, de F1, des fissures V10.4, du moteur de triangulation des panneaux ou de l'atelier.

**Assertions V11.4 améliorées :** comparaison des coordonnées 3D pour les points de silhouette recalculés (l'égalité par identité était invalide) et **identité des échantillons des arêtes matérielles** testée séparément ; aire des triangles comparée rigoureusement à l'aire du **contour effectivement raffiné** (les nouveaux sommets sont reprojetés sur la coquille courbe, ce qui peut modifier légèrement l'aire par rapport aux cordes initiales) et dérive du contour d'origine bornée à `5e-6` en relatif ; couverture explicite des densités demandées `2`, `24` et `64`.

**Validation :** aucun résultat des nouveaux tests n'est encore connu. Rejouer `flutter test --no-pub test/egg_stationary_bowl_mesh_test.dart` et, en régression, `flutter test --no-pub test/egg_shell_fragment_mesh_test.dart` et `flutter test --no-pub test/egg_stationary_bowl_boundary_test.dart`. Les deux volumes statiques et leur contour restent validés au regard des résultats locaux antérieurs, mais **le bol V11.4 n'est pas encore validé**. Les T-junction possibles lors de futurs bords raffinés partagés restent explicitement à résoudre avant le rendu mobile.

## V11.4 — Triangulation du bol fixe restant (tests locaux à confirmer, 8 octobre 2026)

**Accord de poursuite :** l'utilisateur a répondu `ok` après la livraison de V11.3. V11.2 : **5/5 tests locaux réussis**, confirmé par PowerShell. Les tests dédiés V11.3 n'ont pas encore été rapportés et ne sont donc pas déclarés réussis.

**Implémentation statique :** `EggStationaryBowlMeshBuilder` produit un véritable maillage triangulé de la **surface avant du bol fixe sans les deux fragments candidats**. Il part exclusivement du contour V11.3, avec les arêtes d'origine et les deux méridiens de `EggShellModel`. L'ancien maillage F1/bol dessiné en Chrome n'est **pas remplacé** dans cette étape : aucun changement visible ni animation. Les coupures ne sont ni des masques alpha ni des bandes dessinées.

**Réutilisation du moteur 3D :** la triangulation extérieure de V11.2 a été extraite dans `EggShellPanelMeshBuilder.tessellateExterior`, produisant un `EggShellSurfacePatch` (points, triangles, contour). Les deux volumes V11.2 se construisent désormais par cette même routine sans changer leurs triangles externes attendus, leur épaisseur de `2.5`, leurs faces intérieures ou leurs tranches. Le bol fixe en bénéficie aussi. Les nouveaux sommets sont reprojetés sur le vrai profil de coquille, avec échantillons de fissures originaux préservés.

**Limites encore ouvertes :** bol arrière et face interne restant à raccorder, tranches de l'ouverture, attaches, charnières, mouvement et passage du poussin. Le contour original est géométriquement commun ; les raffinements de maille propres à chaque région peuvent encore différer le long d'une même fissure : **vérifier et unifier la tessellation des frontières avant tout rendu actif**, pour éliminer les T-junction. F1, le réseau V10.4, les peintres, la seed et la propagation sont inchangés.

**Tests V11.4 ajoutés mais non exécutés ici :** `flutter test --no-pub test/egg_stationary_bowl_mesh_test.dart` (aire triangulée, bord unique, reprojection, coordonnées de la découpe et déterminisme). Rejouer obligatoirement `flutter test --no-pub test/egg_shell_fragment_mesh_test.dart` en raison de la factorisation et `flutter test --no-pub test/egg_stationary_bowl_boundary_test.dart` (V11.3). Corriger tout échec avant de poursuivre.

## V11.3 — Contour matériel du bol fixe restant (code livré, tests locaux en attente, 8 octobre 2026)

**Retour utilisateur V11.2 :** sur le commit `ca39e57`, `git pull --ff-only` indique `Already up to date`, puis `flutter test --no-pub test/egg_shell_fragment_mesh_test.dart` → **`00:01 +5: All tests passed!`**. Les cinq contrôles dédiés de génération des deux volumes statiques de coquille ont donc réussi sur la machine de l'utilisateur. Cela ne constitue pas encore une validation de leur rendu ou de leur animation.

**Nouvelle intervention ciblée :** préparer le *véritable contour* permettant de reconstruire ultérieurement le bol fixe sans les deux régions candidates. Le bol actuel `EggShellF1PreviewPainter._drawBody` est triangulé en grille indépendante des fissures ; éliminer uniquement les triangles proches des fissures créerait des bords en escalier et violerait la géométrie commune. Il faut donc utiliser un contour contraint avant de trianguler.

**Nouveau module `egg_stationary_bowl_boundary.dart` :** part de `EggFragmentRegionPlan` V11.1, compte les appartenances des arêtes aux deux panneaux, élimine les **trois arêtes centrales partagées `28,29,30`** (frontière interne, qui ne doit pas devenir une fausse ouverture), et déduit **une unique chaîne de 15 arêtes** de fissure originale reliant les nœuds de couronne F1 `7` et `16`. Elle contient exactement les arêtes `24–27,31–41` (sauf `28–30`). Le bord supérieur du bol fixe restant garde **les seuls trois segments de couronne frontale F1 `6,16,17`**, et enchaîne `node6 → node7 → [découpe] → node16 → node18`. Le contour fermé diagnostic complète ce sommet par les deux méridiens du modèle `EggShellModel` jusqu'au bas de l'œuf. Il réutilise directement les échantillons 3D d'origine pour toutes les fissures ; pas de contour ajouté à l'écran.

**État exact :** le *contour 3D contraint de la future surface du bol fixe* est établi, **pas encore sa triangulation ni la suppression des triangles du bol peint**, qui restera inchangé dans Chrome. Le contour de silhouette est construit exclusivement depuis `EggShellModel`, pas depuis un masque alpha ni un tracé plat. Ni le modèle, ni la géométrie validée V10.4/F1, ni les volumes V11.2, ni la propagation, ni le peintre n'ont été modifiés.

**Tests ajoutés non exécutés ici :** `flutter test --no-pub test/egg_stationary_bowl_boundary_test.dart` : chaîne unique, exclusion des frontières internes, continuité de la couronne F1, points 3D préservés, échantillonnage des deux méridiens, déterminisme. **Prochaine itération (après réussite locale) :** triangulation contrainte de cette surface restante, comparaison des frontières avec V11.2 et vérification d'absence d'intersection avant la substitution du maillage fixe dans l'aperçu. Aucune animation F2/F3, pas de trou via patch ou transparence, pas de moteur temporel.

## V11.2 — Construction statique des deux volumes de coquille (tests locaux en attente, 8 octobre 2026)

**V11.1 testée :** retour PowerShell utilisateur après `d829666` : `flutter test --no-pub test/egg_fragment_regions_test.dart` → **`00:01 +5: All tests passed!`**. Les contours fermés et leurs frontières communes sont donc techniquement vérifiés par ces cinq tests. L'utilisateur conserve la répartition V10.4 comme base visuelle.

**Objectif unique V11.2 :** construire deux volumes 3D fermés depuis les régions V11.1, avec **surface extérieure, surface intérieure et tranche**. Nouveau `egg_shell_fragment_mesh.dart` : les échantillons exacts des fissures composent le bord initial ; une triangulation en x/y des deux contours fermés est raffinementée uniformément avec des milieux d'arêtes partagés, projetés sur `EggShellModel.surfaceAt`. La face intérieure provient de `model.inset(point, 2.5)`. Les mêmes arêtes du contour raffiné forment les quads des tranches, découpés en triangles. Aucun contour indépendant dessiné pour masquer une imperfection.

**Invariants préservés :** F1/couronne/ses fissures, réseau V10.4 (`50 nœuds, 52 arêtes`), moteur V9/V10, seed `20261008`, oscillation `1.5`, épaisseur de `2.5`, vue atelier et poussin ; aucun fichier existant de géométrie ou de peintre changé. **Limite :** les nouvelles pièces sont des maillages statiques en données, **pas des fragments affichés ou détachés** ; le bol fixe conserve intégralement ses triangles dans l'atelier. La soustraction physique correspondante, les attaches/pivots, l'occlusion en déplacement et le passage du poussin restent à construire séparément.

**Tests ajoutés mais pas encore exécutés dans ce chat :** `test/egg_shell_fragment_mesh_test.dart` (5 contrôles dédiés : faces et tranches, manifold, projection 3D, épaisseur, frontières originales et stabilité). Lancer `flutter test --no-pub test/egg_shell_fragment_mesh_test.dart` localement. Ne pas déclarer cette V11.2 validée sans retour des tests ; en cas d'échec, corriger uniquement la triangulation.

## V11.1 — Validation de la répartition et cartographie des deux régions candidates (8 octobre 2026)

**Validation utilisateur :** après examen de la vidéo V10.4, l'utilisateur confirme **« ok »** à la demande explicite de retenir la **répartition des fissures V10.4 comme base de la fragmentation**. C'est une validation de la **répartition artistique comme base de travail**, pas une approbation de l'existence de maillages séparés, d'une cavité réaliste, de charnières, d'un passage libre du poussin ou d'une animation d'éclosion.

**Nouvelle priorité (une seule étape) :** identifier les **régions effectivement closes par des arêtes 3D partagées** avant de découper une quelconque surface. Le module `egg_fragment_regions.dart` reconstruit directement sur `EggFractureNetwork.fixed()` deux circuits orientés `left` et `right` à partir des deux chaînes `connection`, des chemins `primary` jusqu'aux racines F1 et du plus court arc sur les 24 arêtes de la couronne F1. Les contours se referment **par identifiants de nœuds communs**, et non par une projection 2D ou une juxtaposition approximative. Trois arêtes centrales (`28, 29, 30`) sont communes aux deux régions et parcourues dans des sens opposés. Une région peut retourner son périmètre pour diagnostic en **réutilisant exclusivement les échantillons 3D des arêtes d'origine**.

**Périmètre strict :** aucune modification de `EggShellModel`, du profil de l'œuf, de F1, de la couronne, des fissures et angles V10.4, de la seed, de la propagation V9/V10, des peintres ni de l'atelier. Les sorties latérales sont des **fissures ouvertes**, pas des bords de fragments : elles n'atteignent pas l'arrière 3D. Le bol inférieur non délimité n'est **pas** compté comme un fragment mobile. Le nouveau plan ne génère **ni triangle, ni face intérieure, ni tranche, ni charnière, ni mouvement, ni espace de sortie vérifié pour le poussin**.

**Vérification préalable :** calcul indépendant des parcours dans le graphe à 50 nœuds / 52 arêtes : région gauche de **14 arêtes orientées** (4 de couronne + 7 principales + 3 de connexion), région droite de **16 arêtes orientées** (5 de couronne + 8 principales + 3 de connexion). Les deux parcours sont fermés ; ils partagent exactement les trois arêtes principales centrales `28, 29, 30`, sans ajout de géométrie. Cette vérification ne remplace **pas** les tests Dart/Flutter.

**Tests ajoutés mais non exécutés ici :** `flutter test --no-pub test/egg_fragment_regions_test.dart` ; contrôle de fermeture, orientation opposée des arêtes communes, conservation des objets `EggShellPoint3`, exclusion des fissures ouvertes et de F1 chapeau, stabilité du seed. Prochaine phase séparée (après retour de tests) : segmentation volumique à faces extérieure/intérieure/tranche communes, identification des attaches et validation de l'ouverture réellement dégagée pour le poussin **avant** toute animation.

## V10.4 — abaissement léger des fissures, à valider dans Chrome (8 octobre 2026)

**Demande utilisateur :** la répartition V10.3 convient à peu près ; proposer et essayer des fissures descendant légèrement plus bas, sans reconstruire le réseau ni densifier la partie inférieure. **Seul changement visuel : abaissement des portions inférieures** et de leurs jonctions, selon les valeurs acceptées.

**Déplacements 3D (coordonnée Y du modèle, positive vers le bas) :**
- extrémité gauche `13 → 31` ;
- jonctions centrale supérieure `10 → 26`, centrale inférieure `37 → 55` ;
- extrémité droite `-9 → 11` ;
- liaison basse gauche `26 → 44` puis `28 → 48` ;
- liaison basse droite `6 → 26` puis `23 → 42` ;
- sortie latérale gauche basse `32 → 48` puis `62 → 78` ;
- sortie droite `10 → 28` puis `44 → 61`.

**Strictement préservés :** premiers points des trois fissures et leurs racines de couronne, branche latérale gauche supérieure, topologie du graphe, ids des nœuds et connexions, couronne F1 et ses deux fissures, modèle et pivot F1, seed `20261008`, valeurs `2.5` et `1.5`, peintre et propagation V9/V10, atelier et minuteur. Les liaisons restent des **frontières candidates**, aucun véritable fragment physique n'est créé.

**Contrôle préparatoire indépendant** (reproduction des règles de génération de points du réseau) : **50 nœuds / 52 arêtes / 3 cycles** avant et après ; degré maximal 3 ; aucun nouveau croisement parasite hors F1, aucun échantillon hors de la coquille, aucun franchissement de la frontière F1 ; durée maximale calculée de propagation `0.8751` sur une échelle `0–1`. Les deux croisements historiques entre la couronne et les deux fines fissures du chapeau sont inchangés. Cela ne vaut **ni test Dart/Flutter exécuté ni validation esthétique**.

**Tests :** mise à jour des anciennes hauteurs attendues dans le test de topologie V10.3, adaptation de la limite verticale du réseau à `0.37 × halfHeight` et ajout du contrôle ciblé `V10.4 : abaissement ciblé sans ajouter de fragments` (positions, conservation de F1, absence de doublons et jonctions partagées). **Tests Flutter non exécutés dans cet environnement.** Exécuter localement `flutter test --no-pub test/egg_crack_propagation_test.dart` et `flutter test --no-pub test/widget_test.dart`.

**Validation visuelle attendue :** comparer V10.4 avec la V10.3 à F1 fermé (0 %), propagation des fissures à 100 %, repères désactivés. Observer surtout l'équilibre entre espace de libération du poussin et partie inférieure encore intacte. Ne pas passer à la séparation physique avant validation explicite de la répartition.

## V10.3 — adaptation du dernier croquis rouge (8 octobre 2026)

**Nouvelle priorité confirmée :** conserver la logique de l'annotation rouge de l'utilisateur sur la capture V10.2 : trois fissures mères verticales/obliques, deux liaisons basses non rectilignes rejoignant la fissure centrale à deux hauteurs différentes, trois sorties vers les côtés. Le défaut unique est la **répartition hors F1**, pas l'animation.

**Réseau candidat :** racines F1 `7, 11, 16` inchangées ; douze arêtes mères, six arêtes de connexion et six petites arêtes latérales, plus quatre arêtes inchangées des deux fissures sur le chapeau. La liaison gauche rejoint `middle[2]`, la droite rejoint `middle[3]` : pas de jonction à quatre branches. **50 nœuds, 52 arêtes, trois cycles au total (F1 + deux régions candidates), degré maximal 3.** Les sorties latérales se terminent juste sur la partie avant de la surface courbe, près du contour projeté : ce sont des fissures réelles du graphe, mais elles ne constituent pas encore des coupes physiques rejoignant l'arrière de la coquille. Aucun fragment n'est découpé ni détaché.

**Gel :** modèle `EggShellModel`, profil, couronne F1, ses deux fines fissures, ouverture F1, pivot, seed `20261008`, épaisseur `2.5`, oscillation `1.5`, moteur de propagation V9/V10 et atelier unique inchangés. Ne pas substituer une image 2D ou une géométrie indépendante au réseau.

**Contrôles préparatoires non-Flutter :** simulation des coordonnées, profils et échantillons sur la même géométrie : 50 nœuds/52 arêtes, aucun croisement parasite entre arêtes hors couronne non connectées, aucun point hors surface, pas d'arête passant d'un côté à l'autre de F1 et propagation théorique terminée avant 100 %. Deux intersections projetées historiques entre couronne et fines fissures du chapeau restent hors périmètre. **Tests Dart/Flutter non exécutés ici :** tests topologiques et de propagation actualisés, à vérifier localement.

**Prochaine validation :** `flutter test --no-pub test/egg_crack_propagation_test.dart`, puis `flutter test --no-pub test/widget_test.dart --plain-name "V10.3 : deux jonctions basses et sorties latérales partagées"`. Comparer dans Chrome une capture avec F1 fermé, propagation à 100 %, repères désactivés, au croquis rouge. Si le tracé est accepté, observer une courte vidéo 0→100 % avant toute implémentation de fragments mobiles.

## V10.2 — combinaison visuelle 2 + 3 + 7 : grandes régions centrales (8 octobre 2026)

**Décision de l'utilisateur :** préférer une combinaison des études visuelles numérotées **2** (organique proche du croquis rouge), **3** (dégagement au centre) et **7** (peu de branches, grandes zones) à la distribution V10.1. Ne pas recopier l'image générée pixel par pixel : l'utiliser comme orientation artistique, puis construire les vraies arêtes 3D de la coquille. **Seul défaut traité : la répartition et les connexions hors F1.**

**Nouvelle topologie candidate :** trois fractures principales de tailles et orientations différentes, implantées aux mêmes trois racines non équidistantes `7, 11, 16` sur la couronne, descendent vers la région haute/médiane. Une frontière gauche (3 arêtes) rejoint l'extrémité de la mère centrale ; une frontière droite (3 arêtes) rejoint **la même jonction 3D centrale**, constituant un « U » irrégulier. Chaque parcours relie une mère latérale à la mère centrale **et délimite avec la couronne une grande région fermée**, plutôt que des petites boucles autour d'une seule mère. Deux courtes branches secondaires latérales restent ouvertes. Pas de grandes fissures dans la moitié inférieure.

**Topologie / dépendances attendues :** 24 arêtes de couronne F1, 12 arêtes mères, 6 arêtes de connexion, 8 secondaires (dont les **4 arêtes des deux fissures validées du chapeau F1**) : **48 nœuds / 50 arêtes**, deux cycles sous F1 et son cycle de couronne = 3, nœuds de degré maximum 3. Les deux liaisons naissent de leurs mères latérales et aboutissent à la même pointe centrale ; cette orientation évite de faire dépendre artificiellement leur déclenchement l'une de l'autre. Le calendrier V9 et le dévoilement V10 sont **inchangés**.

**Vérification préparatoire indépendante :** simulation numérique fondée sur le profil `EggShellModel` actuel et le même échantillonnage : aucun nouveau croisement entre fissures indépendantes hors F1, aucun point hors coquille, aucun basculement entre la région F1 et la région fixe, degré max 3 et achèvement théorique des connexions avant la progression 1. Les intersections historiques entre les deux fines fissures du chapeau et la couronne demeurent hors de cette itération. Cette simulation n'est **pas** un test Flutter/Dart ni une validation artistique.

**Tests modifiés :** assertions héritées de V10.1 exigeant deux boucles locales, une densité excessive de branches ou des hauteurs anciennes remplacées par des critères V10.2 vérifiables (jonction centrale réellement partagée, cycles, racines, branches limitées, raccordement et propagation tardive). **Tests locaux à exécuter** : `flutter test --no-pub test/egg_crack_propagation_test.dart` et `flutter test --no-pub test/widget_test.dart`. F1, les paramètres `2.5` et `1.5`, la seed `20261008`, l'atelier, le moteur temporel et le poussin ne changent pas.

**Porte de validation :** d'abord une capture Chrome `Ouverture F1 0 %` + `Propagation fissures 100 %` + repères désactivés, comparée aux études 2/3/7 et au dernier croquis rouge. Si la géométrie est acceptée, observer ensuite la propagation en vidéo 0→100 % avant toute animation de séparation. Les deux cycles sont **des régions candidates**, pas encore deux fragments mobiles ou des ouvertures physiques validées.

## Retour des tests PowerShell V10.1 — correction ciblée (8 octobre 2026)

**Compte rendu local utilisateur sur `c6233ec` :** `git status --short` vide et `git pull --ff-only` réussi. Test ciblé `V10.1 : répartition asymétrique et deux fermetures locales` : **1 réussi**. Suite `egg_crack_propagation_test.dart` : **6 réussis, 1 échec** dans `V10: 3D prefix follows cumulative length without moving nodes` à la comparaison des listes de points 3D ligne 27. La classe `EggShellPoint3` ne redéfinit pas `==` : une interpolation déterministe recrée un objet différent ayant les mêmes coordonnées. L'échec indique donc une assertion inappropriée, pas un défaut de propagation démontré.

**Correction :** remplacement de la seule comparaison de listes de points par la vérification des coordonnées `x/y/z` avec une tolérance `1e-12`, après contrôle de longueur. Aucun code moteur ou géométrique modifié. **Nouveaux tests non exécutés ici** : relancer la suite de propagation avant de conclure.

**Chrome :** lancement en cours dans la dernière sortie transmise, sans message final de connexion. Le signalement de versions de packages disponibles est informatif. Capture encore attendue à `Ouverture F1 = 0 %`, `Propagation fissures = 100 %`, repères désactivés ; la distribution V10.1 n'est pas validée visuellement.

## V10.1 — redistribution des fissures hors F1 (code livré, rendu Chrome à valider)

**Décision utilisateur (8 octobre 2026) :** la répartition V8/V10 à 100 % ne convient pas, indépendamment de la propagation technique. Le défaut principal est la topologie spatiale : réseau trop central, liaisons longues artificielles et trois axes ayant une organisation trop systématique. **Une itération = recomposer uniquement cette répartition** pour préparer des futurs fragments plausibles, sans toucher aux acquis.

**Nouvelle implantation candidate :** trois mères partent de points **non équidistants** de la couronne F1 (`7, 11, 16`). À gauche, une fissure oblique de longueur moyenne ; au centre, une fissure plus courte ; à droite, une trajectoire dominante qui descend davantage sur le haut-milieu de l'œuf. Deux connexions **locales** quittent puis rejoignent chacune sa propre fissure mère, formant une petite zone en coin gauche et une zone plus grande à droite. Elles remplacent les deux anciennes diagonales qui reliaient des fractures éloignées à travers le centre. Quelques terminaisons courtes restent ouvertes ; la partie inférieure de l'œuf demeure largement intacte.

**Architecture conservée :** toujours un unique `EggFractureNetwork` sur `EggShellModel`, trois chaînes, six arêtes de connexion, deux cycles additionnels au cycle F1, arêtes sans doublon et jonctions partagées. Les deux zones closes sont des **candidates** à la fragmentation, pas des maillages ni des morceaux physiques déjà validés. Les fissures sont révélées par la propagation existante V9/V10, non dessinées par un autre moteur. Aucune modification du calendrier de propagation, des peintres, du curseur, du profil, de l'ouverture F1, du pivot, de la couronne, des deux fissures du chapeau, de l'épaisseur `2.5`, de l'oscillation `1.5` ni de la seed fixe `20261008`.

**Vérifications effectuées avant commit :** simulation indépendante des coordonnées/samples de la surface projetée : graphe à 55 nœuds/57 arêtes, trois cycles (dont F1), sept bifurcations internes de degré 3, degré maximal 3, huit arêtes majeures obliques, aucune nouvelle intersection entre fissures hors couronne non connectées, aucun échantillon hors de la surface ni passant de l'autre côté de la couronne. Deux croisements historiques touchant le tracé de la couronne et ses petites fissures restent hors périmètre. La qualité esthétique et les futures dynamiques de fragment **ne sont pas déduites** de cette analyse numérique.

**Tests Flutter :** adapter le test devenu obsolète de V8, contrôler racines non équidistantes, hauteurs différentes, reconnexions locales, cycles et absence de doubles arêtes ; garder les tests V9/V10 de causalité et de visibilité. Les tests Flutter ne sont **pas encore exécutés dans l'environnement GitHub de ce cycle**. Les exécuter localement avant validation (`flutter test --no-pub test/egg_crack_propagation_test.dart` et `flutter test --no-pub test/widget_test.dart`). **Priorité de validation :** capture Chrome à `Ouverture F1 = 0 %`, `Propagation fissures = 100 %`, repères désactivés. Après retour sur la répartition, examiner la propagation 0→100 % ; ne pas passer aux fragments mobiles sans validation de ces étapes.

## Reprise opérationnelle — V10, captures Chrome du 8 octobre 2026

**HEAD technique avant cette mise à jour documentaire :** `b471f51`, branche `prototype/fragment-lab-v1`. **V9 : cinq tests dédiés réussis localement** après `flutter test --no-pub test/egg_crack_propagation_test.dart` (retour PowerShell utilisateur : `00:02 +5: All tests passed!`, sur le commit `7097007`). **Les tests V10 nouvellement ajoutés ne sont pas encore confirmés exécutés** ; ne pas extrapoler le résultat V9.

**Deux captures V10 reçues :** (1) vue fermée F1, `Propagation fissures = 0 %` : la couronne et les deux fissures du chapeau restent visibles, pas de réseau sous F1 ; (2) capture de l'atelier avec `Ouverture F1 = 0 %`, `Propagation fissures = 100 %` : le réseau hors F1 est présent. Ces deux extrémités sont conformes **visuellement sur les captures**, mais ne prouvent **ni continuité intermédiaire ni bonne chronologie des bifurcations**. Aucune vidéo du curseur 0→100 % fournie.

**État artistique :** le réseau complet, fondé sur la géométrie provisoire V8, reste **non validé** : lignes trop géométriques et connexions peu naturelles, difficile de voir comment naîtra une véritable éclosion. La couronne et l'ouverture F1 ont été acceptées pour le stade actuel par l'utilisateur ; conserver ce qui est acquis sans confondre avec un pivot final adapté au poussin.

**Prochain travail :** observer une **courte vidéo Chrome de propagation 0→100 % avec F1 à 0 %**, puis vérifier F1 partiellement ouvert ; contrôler apparition, continuité, dépendances causales aux jonctions et connexions tardives avant de retoucher la géométrie. Exécuter si besoin les tests locaux V10 : `flutter test --no-pub test/egg_crack_propagation_test.dart`, puis `flutter test --no-pub test/widget_test.dart --plain-name "V10 : fissures pilotées par un curseur sans modifier F1"`. Aucun résultat V10 n'est présumé réussi. La séparation physique/fragments/poussin (V11 et suivantes) reste non implémentée.

**Méthode :** une correction principale par itération, GitHub direct sur la branche → commit ciblé → PowerShell → validation Chrome ; aucune GitHub Action, aucun crossfade, aucun nouveau ON/OFF. Le futur chat commence par relire `AGENTS.md`, `PROGRESS.md`, `ECLOSION_CHAT_REFERENCE.md` et vérifier le HEAD.

## V10 — apparition progressive sur les arêtes 3D (code livré ; Chrome à valider)

**Validation technique V9 obtenue localement le 8 octobre 2026 :** l'utilisateur a exécuté `flutter test --no-pub test/egg_crack_propagation_test.dart` sous Windows/PowerShell sur le commit `7097007`. Résultat communiqué : **`00:02 +5: All tests passed!`** (5 tests dédiés). Cette preuve porte uniquement sur les tests de V9, pas sur le rendu visuel V8 ni sur l'ensemble des tests Flutter.

**Périmètre unique V10 :** connecter les fractions de propagation V9 aux traits du peintre 3D existant, sans changer un seul point ou nœud de `EggFractureNetwork`, la couronne F1, son ouverture, ses fissures propres, ses paramètres ni le minuteur. `visibleCrackPrefix` retourne le préfixe d'une polyligne **mesuré en longueur spatiale 3D**, avec interpolation du dernier point sur le segment échantillonné d'origine. Elle ne modifie pas les arêtes ; aucun alpha/crossfade ni tracé indépendant. `ShellCrackStroke` porte désormais sa fraction visible ; `EggShellF1PreviewPainter` dessine seulement ce préfixe au sein du même masque de profondeur et applique toujours la même transformation rigide aux fissures du chapeau.

**Atelier :** un seul aperçu 3D, un curseur `Propagation fissures` (0–100 %) **indépendant** du curseur `Ouverture F1`. À progression zéro, les arêtes hors F1 sont cachées ; à 100 %, elles sont toutes visibles sur leur tracé d'origine. Les petites fissures du chapeau F1 restent à 100 % quelle que soit la progression. Le réglage est purement diagnostique, sans synchronisation actuelle au timer et sans retour aux modes ON/OFF.

**Tests ajoutés / mis à jour mais non exécutés dans cet environnement :** découpe selon la longueur réelle d'une polyligne 3D (y compris angle non uniforme), reproductibilité, contrôle que l'extrémité visible appartient à un segment de l'arête d'origine, non-mutation, et test UI sur les deux curseurs, le maintien F1 et le mode diagnostic. Exécuter localement `flutter test --no-pub test/egg_crack_propagation_test.dart` puis `flutter test --no-pub test/widget_test.dart`, et valider dans Chrome aux progressions 0/25/50/75/100 % avec F1 fermé puis ouvert. Le rendu des futures régions physiques et le style géométrique V8 demeurent **non validés**.

## V9 — calendrier causal de propagation (implémenté ; tests locaux à exécuter)

**Nouvelle décision (8 octobre 2026) :** la capture V8 n'est **pas artistiquement validée**. Les retouches successives des liaisons géométriques ne donnent pas une éclosion naturelle. La bonne direction est de **séparer la topologie potentielle, la propagation visible et la fragmentation réelle** ; les fissures peuvent n'apparaître que progressivement, les jonctions et fermetures restant latentes tant que la rupture ne les atteint pas.

**Périmètre unique V9 : architecture temporelle uniquement**, sans déplacer un seul nœud de `EggFractureNetwork.fixed`, sans modifier les peintres, l'atelier, F1, le pivot ou le timer. Nouveau module `egg_crack_propagation.dart` : un `EggCrackPropagationPlan` immuable pour chaque `EggCrackEdge.id` existant, avec instant de départ/fin, parent réel au nœud commun, avancement continu entre 0 et 1 et temps déterministes indépendants des frames. Les mères commencent en premier, les branches n'apparaissent qu'après la complétion de leur parent, et les liaisons `connection` se propagent plus tard pour fermer des régions. Les 24 arêtes de couronne F1 et les quatre arêtes des deux petites fissures du chapeau sont marquées **préservées**, donc non reprogrammées. Pour les liaisons tardives rejoignant des axes déjà actifs, la provenance des axes mères n'est pas retardée par cette jonction.

**Critère V9 :** un calendrier reproductible, purement calculé à partir du réseau 3D et d'une progression normalisée, capable de donner la portion visible de chaque arête **sans altérer son échantillonnage ni ses jonctions**. Ce n'est pas une simulation physique validée ; les timings sont provisoires et devront être synchronisés au minuteur ultérieurement. Tests ciblés ajoutés dans `test/egg_crack_propagation_test.dart` : invariance F1, déterminisme, dépendances aux jonctions, connexions tardives, continuité, réversibilité et aucune mutation des points 3D. **Tests écrits, non encore exécutés localement.**

**À ne pas confondre :** V9 ne change **volontairement pas** la capture Chrome : l'affichage actuel reste celui de V8, même si celui-ci n'est pas validé. **V10** sera une itération distincte consacrée au dévoilement progressif des *mêmes* arêtes géométriques dans `EggShellF1PreviewPainter`, avec un contrôle de progression dans l'atelier. Ne pas ajouter de nouveau mode ON/OFF ni de crossfade. **V11**, seulement ensuite, traitera les véritables séparations, tranches et attaches permettant l'apparition du poussin.

## Réseau V8 — liaisons décalées, validation Chrome en attente (8 octobre 2026)

**Observation V7 à 0 % :** le réseau conserve une apparence d'escalier transversal au centre. Les deux liaisons restaient proches en hauteur à travers la chaîne centrale, et chaque petite arête ajoutait plusieurs coudes indépendants.

**Correction ciblée V8 :** la première connexion descend de `left[0]` (`y=-93`) vers `middle[2]` (`y=-15`) en passant par deux nouveaux nœuds intermédiaires sur `EggShellModel`. La seconde remonte de `middle[4]` (`y=47`) vers `right[1]` (`y=-48`), avec deux points intermédiaires distincts. Ainsi, les deux grandes diagonales ne composent plus une bande au même niveau. Les arêtes de type `connection` conservent **un seul coude limité par arête** ; le tracé des fissures principales et secondaires reste inchangé.

**Gels préservés :** F1 et ses deux fissures, coupe de couronne, pivot F1, trois chaînes principales, ramifications secondaires, seed `20261008`, épaisseur `2.5`, oscillation `1.5` et atelier unique. Les deux liaisons gardent des nœuds communs aux chaînes et deux zones théoriquement fermées, non encore fragmentées.

**Statut :** implémentation livrée, vérification Dart/Flutter non exécutée ici. Tests de décalage vertical et de limitation des coudes ajoutés. À confirmer visuellement dans Chrome à 0 % sans repères, puis aux ouvertures F1 intermédiaires ; ne pas marquer V8 validée sans ce retour.

## Réseau V7 — suppression de la bande transversale en escalier (capture Chrome du 8 octobre 2026)

**Observation V6, 0 % :** la nouvelle capture montre un réseau bien connecté mais les deux liaisons transversales se combinent visuellement en une **longue bande quasi horizontale à petits escaliers** dans la partie haute/médiane de l'œuf, rappelant davantage une découpe géométrique qu'une cassure organique. Le code confirme la cause : la première liait des nœuds aux hauteurs `-20/-15`, la seconde des nœuds aux hauteurs `13/13`. Il ne s'agit pas d'un défaut de F1.

**Correction unique V7 :** repositionner uniquement ces deux chemins de trois arêtes en **diagonales réellement distinctes** : première liaison de `left[1]` (`y=-59`) vers `middle[2]` (`y=-15`), seconde de `middle[3]` (`y=13`) vers `right[1]` (`y=-48`). Les deux points intermédiaires de chacun des chemins sont recalculés sur `EggShellModel`. La courte branche secondaire gauche conserve sa géométrie mais son attache passe de `left[1]` à `left[2]` afin qu'aucun nœud ne dépasse le degré 3. Aucun autre axe, ramification, échantillonnage ou rendu modifié.

**Invariants maintenus :** le graphe conserve trois cycles dont le F1 validé, six arêtes de connexion, la même seed `20261008`, les trois longues fractures, les deux fissures du chapeau F1 et la coupe commune inchangées. Contrôle arithmétique préparatoire : aucune intersection **entre branches non connectées** dans la projection examinée, aucun point nouveau hors surface, deux liaisons obliques et jonctions partagées. Les croisements apparents déjà observés entre des fissures courtes du chapeau et le parcours arrière projeté de la couronne ne sont pas concernés par cette itération.

**Tests :** test ciblé sur les deux différences de hauteur et angles diagonaux ajouté aux tests V6. Dart/Flutter non exécutés dans cet environnement. **Validation artistique à venir :** capture Chrome à 0 % sans repères, puis ouverture F1 aux pourcentages intermédiaires. Ne pas déclarer le style du réseau validé avant comparaison avec le dessin rouge (orientation de référence, non tracé à copier) et la planche d'origine.

## Réseau V6 — grandes fractures structurantes (en attente de validation Chrome)

**Demande du 8 octobre 2026 :** prendre le croquis rouge comme orientation stylistique, et non comme un tracé exact. Les fissures indépendantes V5 sont remplacées par **trois axes de fracture longs** (gauche, centre, droite), **deux liaisons transversales** et quelques ramifications mortes. Les segments principaux sont irréguliers et asymétriques pour former un réseau cohérent, plutôt qu'une texture de traits.

**Architecture :** deux chemins de connexion en `EggCrackKind.connection` comportent chacun trois arêtes et se raccordent aux nœuds déjà présents des trois chaînes. Le graphe reste entièrement connexe et gagne **exactement deux cycles** sous F1, susceptibles de délimiter plus tard des régions de fragments ; ces régions **ne sont pas encore découpées**, ni affectées à des fragments mobiles. Une seule arête géométrique partagée par jonction. Les polylignes continuent de s'appuyer sur `EggShellModel`.

**Gel respecté :** aucune modification du modèle `EggShellModel`, de la couronne `crownFractureY` (24 arêtes), des deux fissures propres au chapeau F1, de son pivot/ouverture, de l'épaisseur `2.5`, de l'oscillation `1.5`, de l'atelier et de la seed `20261008`. Pas de variation entre sessions.

**Contrôle :** contrôle numérique préparatoire de la projection des arêtes : absence de croisements fortuits entre branches non connectées, surfaces projetées dans les limites du modèle, deux nouveaux cycles. Les tests Dart du graphe, de la non-intersection et de la répartition ont été révisés mais **non exécutés ici**. Une capture Chrome à 0 % puis quelques ouvertures F1 est nécessaire pour valider le style et l'intégration des nouvelles frontières. La validité future de la découpe physique ne peut pas être déduite du seul tracé statique.

## Réseau statique V5 — repositionnement des fissures hors F1 (8 octobre 2026)

**Décision utilisateur :** l'ouverture F1 est jugée OK. Ne pas la retoucher. Prochaine priorité : **positionner correctement les autres fissures** selon la planche de référence, notamment les stades 25 % et 5 % où les ruptures les plus importantes se concentrent sur le haut et le haut-milieu de la coquille, au lieu de longues fissures verticales isolées.

**Implémentation ciblée :** dans `EggFractureNetwork.fixed`, les trois trajectoires situées **sous la couronne** sont redistribuées en une branche gauche oblique, un parcours transversal au centre et un groupe asymétrique droit. Les deux jonctions internes en Y sont conservées, les branches secondaires divergent et les terminaisons ne sont plus alignées à une même hauteur. Les deux fissures courtes situées sur le chapeau F1, la boucle de couronne de 24 arêtes et `EggShellModel.crownFractureY` ne sont pas modifiées. Aucun changement du modèle, du pivot F1, de l'épaisseur `2.5`, du mode atelier ou de la seed `20261008`.

**Vérifications :** contrôle géométrique indépendant des nouvelles coordonnées projetées : aucune intersection entre branches non connectées dans le réseau examiné ; deux jonctions en Y maintenues ; absence de sortie de surface dans l'échantillonnage utilisé. Les capillaires du chapeau déjà existants ne sont pas modifiés. Tests Flutter de topologie V4 et nouveau test V5 de répartition écrits ; **non exécutés ici** sans Dart/Flutter. La conformité visuelle reste à valider sous Chrome à 0 % (réseau visible) puis F1 aux ouvertures intermédiaires, sans dégrader les acquis.

**À ne pas confondre :** « F1 OK » correspond au retour utilisateur sur F1 ; cela ne certifie pas encore la future découpe multi-fragments ni la fermeture complète de toutes les arêtes du réseau. La topologie des régions et la variabilité par session restent à développer séparément.

## Atelier 3D unique — retrait du switch Ouverture F1 (8 octobre 2026)

**Décision utilisateur :** le mode OFF du commutateur `Ouverture F1 (diagnostic)` n'apporte rien : le curseur d'ouverture permet déjà de fermer F1 à 0 %. Le commutateur est supprimé de `fragment_lab.dart` ; le seul peintre utilisé par l'atelier est désormais `EggShellF1PreviewPainter`, avec le réseau statique permanent, même à ouverture nulle.

**Contrôles restants :** `Ouverture F1` (curseur 0–100 %), `Repères de cadrage`, `Identifier les surfaces`, `Copier les réglages`. La seed `20261008`, la topologie V4, la coupe commune, le pivot, la géométrie et l'épaisseur `2.5` sont inchangés. L'aperçu intact alternatif `EggCrackNetworkPainter` reste dans le code mais n'est plus sélectionné dans l'atelier, pour conserver cet outil historique sans suppression destructrice.

**Validation :** test d'interface adapté pour vérifier l'absence des deux anciens switches et un unique peintre F1 aux ouvertures 0/25/50/75/100 %. Test écrit, non exécuté ici sans Flutter. État : **code livré, validation Chrome en attente** ; notamment vérifier la continuité de la coquille et des fissures à 0 %.

## Atelier 3D unifié — réseau permanent (8 octobre 2026)

**Décision mise en œuvre :** le bouton ON/OFF `Réseau de fissures 3D (statique)` est retiré. Le réseau V4 reste présent sur la coquille intacte **et pendant l'ouverture F1** ; `Ouverture F1 (diagnostic)` ne sert plus qu'à examiner deux états de la même géométrie. `Repères de cadrage` et `Identifier les surfaces` restent des contrôles de diagnostic.

**Mécanique d'affichage :** sur l'œuf intact, `EggCrackNetworkPainter` dessine toujours le réseau partagé. En diagnostic F1, les fissures du bol restent fixes ; celles sur le chapeau reçoivent exactement `_transformPoint`, puis leurs tracés sont découpés dans les masques de profondeur associés aux faces visibles du bol ou du chapeau. La fracture circulaire propre à F1 demeure unique. Aucune modification de `EggFractureNetwork`, des deux Y, de la seed `20261008`, de la géométrie, du pivot, de l'épaisseur ou des valeurs validées.

**Tests :** nouveau test UI vérifiant l'absence du commutateur séparé, la présence de fissures des deux côtés à cinq ouvertures, la conservation de la seed et le passage œuf intact/F1. `dart format`, `flutter analyze` et les tests Flutter n'ont pas été exécutés sans Flutter local. Validation Chrome obligatoire avant acceptation du rendu, notamment pour déceler tout défaut de masquage dans F1 ouvert.

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
