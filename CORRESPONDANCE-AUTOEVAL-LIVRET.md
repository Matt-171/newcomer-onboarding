# Correspondance — Auto-évaluation des journées ↔ Livret d'intégration

> **Statut : chantier de fond, à trancher.**
> Analyse produite le 25/08/2026. Décision prise à ce stade : l'onglet
> « Validation des journées » est **autonome** — les coches n'alimentent
> **pas** le Livret. Ce document sert à vérifier la couverture des
> compétences et à préparer une éventuelle mise en correspondance.

Deux référentiels coexistent dans l'app :

| Référentiel | Où | Contenu |
|---|---|---|
| **Auto-évaluation des journées** | onglet Validation des journées (`AUTOFORMATION` dans `docs/index.html`) | 40 lignes réparties sur 5 jours (J1 → J5), 3 niveaux : Maîtrisé / Points à revoir / Non maîtrisé |
| **Livret d'intégration** | onglet Livret (`LIVRET` dans `docs/index.html`) | 14 compétences en 3 sections : OB Gestion (6), OB Compta (4), Posture (4) |

Bilan du croisement : **19** lignes ont un rattachement net, **3** sont
transversales (elles couvrent 4 compétences à la fois), **18** n'ont aucune
correspondance. Côté Livret, **7 compétences sur 14** ne sont couvertes par
aucune ligne de journée.

## Méthode de rattachement

Le rattachement n'est pas arbitraire : il reprend le découpage déjà utilisé
par le cadre Formation `pl_gestion`, où chaque item est rangé sous un
sous-titre qui porte le nom exact d'une compétence du Livret (Paramétrages,
Connectivités, Achats, Ventes, Compte pro, Transactions). Quand une ligne
d'auto-évaluation parle d'un sujet déjà classé là, elle hérite du classement.

## 1. Ligne par ligne

### J1 — Parcours client et premiers paramétrages

| # | Ligne d'auto-évaluation | → Compétence Livret | Pourquoi |
|---|---|---|---|
| J1.1 | Expliquer les grandes étapes du parcours client | **Appréhender un nouveau client** | La description du Livret dit mot pour mot « Maîtrise et application du process parcours clients lors de l'onboarding » |
| J1.2 | Identifier les principaux services impliqués dans l'accompagnement | **Appréhender un nouveau client** | Savoir qui fait quoi (Sales / OB / AM / Support) fait partie du même process |
| J1.3 | Comprendre le rôle des différents outils du parcours client | ⛔ aucune | Pas de compétence « outils » au Livret |
| J1.4 | Me repérer dans le lexique de base de l'onboarding | ⛔ aucune | Pas de compétence « lexique » |
| J1.5 | Accompagner un client sur la connexion bancaire | **Connectivités** | « Connexion bancaire » est rangé sous le sous-titre *Connectivités* dans `pl_gestion` |
| J1.6 | Expliquer les différentes façons de transmettre des factures | **Paramétrages** | « Transmission de factures » est sous *Paramétrages* |
| J1.7 | Comprendre les premiers paramétrages de facturation client | **Paramétrages** | « Factures clients (Configuration, Personnalisation, Paiement…) » est sous *Paramétrages* |
| J1.8 | Savoir inviter un utilisateur, lui attribuer un rôle | **Paramétrages** | « Gestion d'équipe (Utilisateurs, Équipes, Circuits de validation) » est sous *Paramétrages* |

### J2 — Modules et outils internes

| # | Ligne d'auto-évaluation | → Compétence Livret | Pourquoi |
|---|---|---|---|
| J2.1 | Présenter les grands principes du module achats | **Achats** | direct |
| J2.2 | Présenter les grands principes du module ventes | **Ventes** | direct |
| J2.3 | Présenter les grands principes du module transactions | **Transactions** | direct |
| J2.4 | Expliquer le fonctionnement des circuits de validation | **Paramétrages** | « Circuits de validation » est nommé dans la ligne Gestion d'équipe, sous *Paramétrages* |
| J2.5 | Orienter un client sur le bon paramétrage de circuit selon son besoin | **Paramétrages** | même sujet que J2.4, un cran au-dessus (conseil) |
| J2.6 | Comprendre les premiers usages d'Intercom | ⛔ aucune | outil interne |
| J2.7 | Savoir où chercher l'information dans Intercom | ⛔ aucune | outil interne |
| J2.8 | Comprendre les premiers usages de Salesforce | ⛔ aucune | outil interne |
| J2.9 | Retrouver les informations client clés dans Salesforce | ⛔ aucune | outil interne |

### J3 — RFE, compte pro et OB

| # | Ligne d'auto-évaluation | → Compétence Livret | Pourquoi |
|---|---|---|---|
| J3.1 | Expliquer les bases de la facturation électronique | ⛔ aucune | La RFE n'existe pas au Livret. La coller sur *Ventes* serait faux |
| J3.2 | Identifier les impacts de la facturation électronique pour les clients | ⛔ aucune | idem |
| J3.3 | Présenter la proposition de valeur du compte pro | **Compte pro** | direct |
| J3.4 | Identifier les principaux cas d'usage du compte pro | **Compte pro** | direct |
| J3.5 | Comprendre les grands principes des connectivités | **Connectivités** | La description Livret dit « Présenter les grandes lignes pour les connectivités les plus utilisées » |
| J3.6 | Orienter un client vers les bons supports sur les connectivités | **Connectivités** | même compétence, versant conseil |
| J3.7 | Mobiliser les connaissances vues sur les modules de gestion | 🔀 **transversale** | voir §3 |
| J3.8 | Utiliser une checklist pour préparer un OB | **Appréhender un nouveau client** | préparer un OB = appliquer le process parcours client |
| J3.9 | Identifier les points clés à observer dans un OB (extraits Modjo) | **Appréhender un nouveau client** | même compétence, versant observation |

### J4 — IA et analytique

Aucune des 7 lignes n'a de destination au Livret.

| # | Ligne d'auto-évaluation | → Compétence Livret | Pourquoi |
|---|---|---|---|
| J4.1 | Identifier les principaux cas d'usage de l'IA | ⛔ aucune | L'IA n'existe pas au Livret |
| J4.2 | Appliquer les bonnes pratiques d'utilisation de l'IA | ⛔ aucune | idem |
| J4.3 | Identifier les situations où l'IA fait gagner du temps | ⛔ aucune | *Priorisation des tâches* serait tiré par les cheveux |
| J4.4 | Réaliser un premier cas pratique avec l'IA | ⛔ aucune | idem |
| J4.5 | Comprendre les bases de l'analytique | ⛔ aucune | voir l'avertissement ci-dessous |
| J4.6 | Identifier les cas d'usage analytiques utiles en accompagnement | ⛔ aucune | idem |
| J4.7 | Mobiliser les premiers réflexes analytiques en contexte client | ⛔ aucune | idem |

**Avertissement sur l'analytique.** Techniquement l'analytique *pourrait* être
rattachée à *Transactions*, parce que dans `pl_gestion` la ligne « Analytique :
comment ça marche dans les grandes lignes » est rangée sous le sous-titre
*Transactions*. Mais la description Livret de Transactions est « Rapprochement
bancaire de premier niveau et qualification des flux » — elle ne parle pas
d'analytique. Un newcomer bon en rapprochement et perdu en analytique
afficherait la même coche. C'est le seul cas où le découpage de `pl_gestion` et
le Livret se contredisent.

### J5 — OB blanc et débrief

| # | Ligne d'auto-évaluation | → Compétence Livret | Pourquoi |
|---|---|---|---|
| J5.1 | Structurer un échange client de manière claire | **Appréhender un nouveau client** | conduite d'un point client = le process |
| J5.2 | Mobiliser les connaissances de la semaine en mise en situation | 🔀 **transversale** | voir §3 |
| J5.3 | Présenter les principaux modules Pennylane avec mes propres mots | 🔀 **transversale** | voir §3 |
| J5.4 | Me repérer dans les outils internes utiles à l'accompagnement | ⛔ aucune | outil interne |
| J5.5 | Utiliser une checklist pendant la préparation / l'observation d'un OB | **Appréhender un nouveau client** | même compétence que J3.8 |
| J5.6 | Identifier mes points forts après l'OB blanc | ⛔ aucune | Ce n'est pas une compétence mais un exercice de recul → relève du commentaire, pas d'une coche à 3 niveaux |
| J5.7 | Identifier mes axes d'amélioration après l'OB blanc | ⛔ aucune | idem |

## 2. Lu depuis le Livret — couverture des 14 compétences

| Section | Compétence | Alimentée par | Nb |
|---|---|---|---|
| OB Gestion | **Paramétrages** | J1.6, J1.7, J1.8, J2.4, J2.5 | **5** |
| OB Gestion | **Connectivités** | J1.5, J3.5, J3.6 | **3** |
| OB Gestion | **Achats** | J2.1 | 1 |
| OB Gestion | **Ventes** | J2.2 | 1 |
| OB Gestion | **Compte pro** | J3.3, J3.4 | **2** |
| OB Gestion | **Transactions** | J2.3 | 1 |
| OB Compta | Saisie | — | 0 |
| OB Compta | Révision | — | 0 |
| OB Compta | TVA | — | 0 |
| OB Compta | Imports | — | 0 |
| Posture | Gérer un conflit avec un client | — | 0 |
| Posture | Priorisation des tâches | — | 0 |
| Posture | **Appréhender un nouveau client** | J1.1, J1.2, J3.8, J3.9, J5.1, J5.5 | **6** |
| Posture | Communication inter/intra-service | — | 0 |

Les 4 compétences **OB Compta** non couvertes sont normales et attendues : leur
jalon est à intégration + 6 semaines, la comptabilité n'est pas au programme de
la semaine 1. Rien à corriger de ce côté.

Les 3 compétences **Posture** non couvertes (conflit client, priorisation,
communication inter-service) s'observent sur plusieurs semaines, pas en fin de
journée 1 — leur absence de l'auto-évaluation est cohérente. Elles restent en
saisie manuelle au Livret.

## 3. Les 3 lignes transversales

- **J3.7** — « Mobiliser les connaissances vues sur les modules de gestion. »
- **J5.2** — « Mobiliser les connaissances vues pendant la semaine dans une mise en situation. »
- **J5.3** — « Présenter les principaux modules Pennylane avec mes propres mots. »

Elles recouvrent **4 compétences simultanément** : Paramétrages, Achats, Ventes,
Transactions — c'est-à-dire ce que « les modules de gestion » désigne dans le
Livret.

Le problème : ces 3 lignes ne portent pas *un* sujet mais une **synthèse de tous
les sujets**. Les 19 autres lignes disent « je sais faire X » ; celles-là disent
« je sais rassembler X + Y + Z ». Elles n'ont donc pas une destination, elles en
ont quatre.

Si elles propageaient :

```
Situation : le newcomer a bien tenu ses journées J1-J2, mais s'est
            emmêlé pendant la mise en situation du vendredi.

Coches détaillées déjà posées :
   Paramétrages ..... Maîtrisé   (J1.6, J1.7, J1.8, J2.4, J2.5)
   Achats ........... Maîtrisé   (J2.1)
   Ventes ........... Maîtrisé   (J2.2)
   Transactions ..... Maîtrisé   (J2.3)

Il coche J5.2 « mise en situation » = Points à revoir
   → un seul clic ferait basculer les 4 compétences
   → le signal fin des 8 lignes précédentes serait effacé
```

Et dans l'autre sens, avec une règle « le dernier saisi gagne », cocher J5.3
« Maîtrisé » validerait d'un coup 4 compétences du Livret sans qu'aucune ligne
détaillée ne soit renseignée.

## 4. Les 18 lignes sans correspondance, par thème

| Thème | Nb | Lignes |
|---|---|---|
| **Outils internes** | 6 | J1.3 rôle des outils du parcours client · J2.6 premiers usages d'Intercom · J2.7 où chercher l'info dans Intercom · J2.8 premiers usages de Salesforce · J2.9 retrouver les infos client clés dans Salesforce · J5.4 se repérer dans les outils internes |
| **IA** | 4 | J4.1 cas d'usage de l'IA · J4.2 bonnes pratiques d'utilisation · J4.3 situations de gain de temps · J4.4 premier cas pratique |
| **Analytique** | 3 | J4.5 bases de l'analytique · J4.6 cas d'usage en accompagnement client · J4.7 réflexes analytiques en contexte |
| **Facturation électronique (RFE)** | 2 | J3.1 bases de la RFE · J3.2 impacts pour les clients |
| **Lexique** | 1 | J1.4 me repérer dans le lexique de l'onboarding |
| **Méta-réflexion OB blanc** | 2 | J5.6 identifier mes points forts · J5.7 identifier mes axes d'amélioration |

## 5. Décisions du 26/08/2026

Après analyse de la cohérence des deux instruments, trois décisions ont été prises.
Elles rendent la correspondance ligne à ligne des sections 1 à 4 **caduque comme
projet** : elle reste utile comme photographie des écarts de couverture, pas comme
spécification.

**Statut de la saisie quotidienne : formatif, mais visible du mentor et du TL.**
Elle ne compte pas dans l'évaluation, tout en restant lisible par l'encadrement
pour piloter les débriefs. À dire explicitement au newcomer dans le bandeau de
l'onglet, sinon la visibilité est implicite et il sur-déclarera quand même.

**Mesure de progression plutôt que correspondance.** Les 40 points seront repassés
au jalon des 3 semaines, sur des items identiques. On obtient une courbe que
nulle correspondance ne peut donner, et le Livret garde ses 14 compétences pour le
jugement du mentor. Deux instruments cohérents chacun, aucun mapping bancal.

**Périmètre du Livret : à examiner avec les mentors.** Les écarts de couverture
(IA, analytique, RFE, outils internes absents du Livret ; 3 compétences de Posture
que personne ne mesure en semaine 1) sont un sujet d'équipe, pas une décision
technique. Les sections 2 et 4 de ce document servent de base à cette revue.

### Incohérences relevées et non encore corrigées

1. **Collision de nom.** L'onglet s'appelle « Auto-évaluation » et la première
   colonne du Livret aussi. Deux objets, deux dates, deux étalons, un seul nom.
   À renommer, par exemple « Acquis de fin de journée ».
2. **Échelle identique, étalon différent.** « Maîtrisé » sur un objectif de
   compréhension au jour 3 n'a pas le même sens que sur une compétence à trois
   semaines. Les libellés identiques invitent à une comparaison fausse : un
   newcomer « Maîtrisé » partout en semaine 1 puis « Points à revoir » au jalon
   ressemble à une régression alors que c'est la barre qui a monté.
3. **Aucun contre-regard.** Le document source prévoit que les points non acquis
   soient repris avec le mentor, mais l'app n'offre aucun endroit pour tracer que
   ça a été fait. Une case « repris avec le mentor » par ligne suffirait.
4. **Pondération accidentelle.** Paramétrages pèse 5 lignes et Appréhender un
   nouveau client 6, tandis qu'Achats, Ventes et Transactions pèsent 1 ligne
   chacune, alors qu'ils font le cœur de l'OB Gestion. Effet du découpage par jour.
5. **Compteur global du dashboard.** `ALL_TOTAL` = 147 additionne des tâches
   administratives, des ressources diffusées et des points annoncés en OB blanc,
   et exclut les 40 points de maîtrise. Un newcomer à 147/147 a reçu tout ce
   qu'on devait lui donner ; ça ne dit rien de ce qu'il sait faire.

## 6. Ce qui restait à trancher (état antérieur, conservé pour mémoire)

1. **Les 18 lignes orphelines** — trois voies possibles :
   - les laisser sans effet Livret (état actuel) ;
   - **étendre le Livret** avec de nouvelles compétences (Outils internes, IA,
     Analytique, RFE) pour qu'il reflète la formation réellement dispensée —
     attention : le Livret est un document signé et verrouillable, et les fiches
     déjà remplies auraient des lignes vides ;
   - les rattacher au plus proche — déconseillé, les coches Livret ne voudraient
     plus dire ce qu'elles annoncent.
2. **Les 3 lignes transversales** — coche seule, ou propagation aux 4 compétences.
3. **La règle d'agrégation**, si une correspondance est un jour activée : 4
   compétences sont alimentées par plusieurs lignes (Appréhender un nouveau
   client : 6 · Paramétrages : 5 · Connectivités : 3 · Compte pro : 2). Options
   envisagées : le niveau le plus faible (prudent), la majorité, le dernier
   saisi, ou l'affichage côte à côte sans écrasement.
