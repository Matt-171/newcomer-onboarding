-- ============================================================
-- Requête Metabase — Vue portefeuille intégrateurs (Reseller Services)
-- À CRÉER dans sa propre collection Metabase (parcours d'accueil RS, jalon J60).
-- Périmètre = intégrateurs "Resellers" dont le CS owner ∈ équipe RS.
-- 7 sous-requêtes UNION ALL (colonnes alignées) :
--   1. Intégrateurs_Clients          — comptes clients + souscription + compte pro + PDP
--   2. Tickets_Zendesk               — tickets support partner_integrator
--   3. Intégrateurs_Users_Learnworlds— users cabinet + progression cours Learnworlds
--   4. Opportunités_Clients          — opportunités SF des clients
--   5. Événements_Livestorm          — inscriptions / présence webinars & formations
--   6. Learnworlds_Certifications    — certifications / accréditations
--   7. Détail_Dossiers_PL            — détail dossier PL (banques, users, FEC/PLUF, TVA, immos…)
-- ⚠️ Le filtre e-mails CS (identified_companies) est à mettre à jour selon la compo de l'équipe.
-- ============================================================

WITH

-- ============================================
-- PÉRIMÈTRE CENTRAL
-- Toutes les branches filtrent sur ce CTE.
-- ============================================
identified_companies AS (
    SELECT DISTINCT
        c.registration_number          AS siren,
        c.id                           AS id_sf_compte,
        i.id                           AS id_sf_integrateur,
        i.name                         AS nom_integrateur,
        i.customer_success_owner_email AS consultant_cs
    FROM salesforce.accounts i
    INNER JOIN salesforce.accounts c
        ON c.reseller_account_id = i.id
        AND c.account_type = 'Business Owner Account'
        AND c.status = 'Customer'
    WHERE i.partner_type = 'Resellers'
    AND i.customer_success_owner_email IN (
        'lise.guittet@pennylane.com',
        'sammy.vincent@pennylane.com',
        'maxime.ledonge@pennylane.com',
        'solange.rey@pennylane.com',
        'benoit.chalas@pennylane.com',
        'bruno.vincent@pennylane.com'
    )
),

-- ============================================
-- DOSSIERS PL identifiés (filtrés sur périmètre)
-- ============================================
company_base AS (
    SELECT
        c.id     AS company_id,
        c.name   AS company_name,
        c.reg_no AS siren,
        c.external_id,
        c.firm_id,
        f.name   AS firm_name
    FROM app.companies c
    LEFT JOIN app.firms f ON f.id = c.firm_id
    WHERE c.reg_no IN (SELECT siren FROM identified_companies)
),

-- ============================================
-- CTEs de détail — toutes filtrées sur company_base
-- ============================================
banks_counts AS (
    SELECT
        company_id,
        COUNT(DISTINCT CASE WHEN is_synchronized = TRUE THEN id END) AS nb_comptes_synchronises,
        COUNT(DISTINCT establishment_id)                               AS nb_etablissements_bancaires
    FROM app.accounts
    WHERE is_visible = TRUE
    AND company_id IN (SELECT company_id FROM company_base)
    GROUP BY 1
),
banks_lists AS (
    SELECT
        company_id,
        LISTAGG(establishment_name, ' | ') AS liste_banques,
        LISTAGG(connection, ' | ')         AS types_connexion_banque
    FROM app.accounts
    WHERE is_visible = TRUE
    AND company_id IN (SELECT company_id FROM company_base)
    GROUP BY 1
),
banks_detailed AS (
    SELECT
        bc.company_id,
        bc.nb_comptes_synchronises,
        bc.nb_etablissements_bancaires,
        bl.liste_banques,
        bl.types_connexion_banque
    FROM banks_counts bc
    LEFT JOIN banks_lists bl ON bl.company_id = bc.company_id
),

users_counts AS (
    SELECT
        uc.company_id,
        COUNT(DISTINCT u.id)                                                         AS nb_users_dossier,
        COUNT(DISTINCT CASE WHEN u.role = 'partner_accountant' THEN u.id END)        AS nb_comptables_dossier,
        COUNT(DISTINCT CASE WHEN u.role = 'regular_user'       THEN u.id END)        AS nb_profil_gestion_dossier
    FROM app.users_companies uc
    LEFT JOIN app.users u ON u.id = uc.user_id
    WHERE uc.company_id IN (SELECT company_id FROM company_base)
    GROUP BY 1
),
users_lists AS (
    SELECT
        uc.company_id,
        LISTAGG(CASE WHEN u.role = 'partner_accountant' THEN u.email END, ' | ') AS liste_comptables_dossier,
        LISTAGG(CASE WHEN u.role = 'regular_user'       THEN u.email END, ' | ') AS liste_users_gestion_dossier
    FROM app.users_companies uc
    LEFT JOIN app.users u ON u.id = uc.user_id
    WHERE uc.company_id IN (SELECT company_id FROM company_base)
    GROUP BY 1
),
users_detailed AS (
    SELECT
        uc.company_id,
        uc.nb_users_dossier,
        uc.nb_comptables_dossier,
        uc.nb_profil_gestion_dossier,
        ul.liste_comptables_dossier,
        ul.liste_users_gestion_dossier
    FROM users_counts uc
    LEFT JOIN users_lists ul ON ul.company_id = uc.company_id
),

fiscal_years_stats AS (
    SELECT
        company_id,
        COUNT(CASE WHEN validation_status = 'open'      THEN 1 END) AS nb_exercices_ouverts,
        MIN(CASE WHEN validation_status = 'open'        THEN start END) AS plus_ancien_exercice_ouvert,
        COUNT(CASE WHEN validation_status = 'validated' THEN 1 END) AS nb_exercices_clotures
    FROM app.fiscal_years
    WHERE company_id IN (SELECT company_id FROM company_base)
    GROUP BY 1
),

fiscal_params AS (
    SELECT
        c.id AS company_id,
        c.fiscal_regime,
        c.fiscal_category,
        c.vat_frequency,
        c.is_cash_based_accounting,
        CASE
            WHEN c.fiscal_regime IS NOT NULL
            AND c.fiscal_category IS NOT NULL
            THEN 'Oui'
            ELSE 'Non'
        END AS parametrage_fiscal_finalise
    FROM app.companies c
    WHERE c.id IN (SELECT company_id FROM company_base)
),

onboarding_status AS (
    SELECT
        company_id,
        score AS onboarding_score_sur_5,
        CASE
            WHEN company_activated_at IS NULL THEN 'Non démarré'
            WHEN score < 3                    THEN 'En cours (faible)'
            WHEN score < 5                    THEN 'En cours (avancé)'
            ELSE                                   'Complet'
        END AS statut_onboarding
    FROM (
        SELECT
            id AS company_id,
            company_activated_at,
            (CASE WHEN company_activated_at IS NOT NULL               THEN 1 ELSE 0 END +
             CASE WHEN bank_connected_at IS NOT NULL                  THEN 1 ELSE 0 END +
             CASE WHEN fec_imported_at IS NOT NULL
                    OR fec_not_needed_at IS NOT NULL                  THEN 1 ELSE 0 END +
             CASE WHEN first_supplier_invoice_created_at IS NOT NULL  THEN 1 ELSE 0 END +
             CASE WHEN first_customer_invoice_created_at IS NOT NULL  THEN 1 ELSE 0 END
            ) AS score
        FROM app.companies__onboarding_states
        WHERE id IN (SELECT company_id FROM company_base)
    ) sub
),

invoices_sources AS (
    SELECT
        company_id,
        LISTAGG(source, ', ') AS sources_import_factures
    FROM app.invoices
    WHERE source NOT IN ('manual', 'web', 'fec')
    AND company_id IN (SELECT company_id FROM company_base)
    GROUP BY 1
),

fec_counts AS (
    SELECT
        company_id,
        COUNT(DISTINCT CASE WHEN type = 'Fec'                      THEN id END) AS nb_fec_importes,
        COUNT(DISTINCT CASE WHEN type = 'QuadraMdb'                THEN id END) AS nb_mdb_importes,
        COUNT(DISTINCT CASE WHEN type = 'PennylaneUniversalFormat' THEN id END) AS nb_pluf_importes,
        MAX(CASE WHEN type = 'Fec'                      THEN created_at END)    AS dernier_fec_import,
        MAX(CASE WHEN type = 'QuadraMdb'                THEN created_at END)    AS dernier_mdb_import,
        MAX(CASE WHEN type = 'PennylaneUniversalFormat' THEN created_at END)    AS dernier_pluf_import
    FROM app.dumps
    WHERE type IN ('Fec', 'QuadraMdb', 'AssetDump', 'AssetSavDump', 'PennylaneUniversalFormat')
    AND dump_status = 'import_success'
    AND company_id IN (SELECT company_id FROM company_base)
    GROUP BY 1
),
fec_lists AS (
    SELECT
        company_id,
        LISTAGG(
            CASE
                WHEN type = 'Fec' AND dump_status = 'import_success'
                THEN first_entry_date::text || ' -> ' || last_entry_date::text
            END, ' | '
        ) AS detail_fecs_importes,
        LISTAGG(
            CASE
                WHEN type = 'QuadraMdb' AND dump_status = 'import_success'
                THEN first_entry_date::text || ' -> ' || last_entry_date::text
            END, ' | '
        ) AS detail_mdb_importes,
        LISTAGG(
            CASE
                WHEN type = 'PennylaneUniversalFormat' AND dump_status = 'import_success'
                THEN first_entry_date::text || ' -> ' || last_entry_date::text
            END, ' | '
        ) AS detail_pluf_importes
    FROM app.dumps
    WHERE type IN ('Fec', 'QuadraMdb', 'AssetDump', 'AssetSavDump', 'PennylaneUniversalFormat')
    AND dump_status = 'import_success'
    AND company_id IN (SELECT company_id FROM company_base)
    GROUP BY 1
),
fec_imports AS (
    SELECT
        fc.company_id,
        fc.nb_fec_importes,
        fc.nb_mdb_importes,
        fc.nb_pluf_importes,
        fc.dernier_fec_import,
        fc.dernier_mdb_import,
        fc.dernier_pluf_import,
        fl.detail_fecs_importes,
        fl.detail_mdb_importes,
        fl.detail_pluf_importes
    FROM fec_counts fc
    LEFT JOIN fec_lists fl ON fl.company_id = fc.company_id
),

assets_stats AS (
    SELECT company_id, COUNT(*) AS nb_immobilisations
    FROM app.assets
    WHERE company_id IN (SELECT company_id FROM company_base)
    GROUP BY 1
),

loans_stats AS (
    SELECT company_id, COUNT(*) AS nb_emprunts
    FROM app.loans
    WHERE company_id IN (SELECT company_id FROM company_base)
    GROUP BY 1
),

leases_stats AS (
    SELECT company_id, COUNT(*) AS nb_credit_bail
    FROM app.leases
    WHERE company_id IN (SELECT company_id FROM company_base)
    GROUP BY 1
),

subsidies_counts AS (
    SELECT
        company_id,
        COUNT(DISTINCT id) AS nb_subventions,
        SUM(amount)        AS montant_total_subventions
    FROM app.subsidies
    WHERE company_id IN (SELECT company_id FROM company_base)
    GROUP BY 1
),
subsidies_lists AS (
    SELECT
        company_id,
        LISTAGG(
            name || ' (' || ROUND(amount::numeric, 2)::text || 'EUR)', ' | '
        ) AS liste_subventions
    FROM app.subsidies
    WHERE company_id IN (SELECT company_id FROM company_base)
    GROUP BY 1
),
subsidies_stats AS (
    SELECT
        sc.company_id,
        sc.nb_subventions,
        sc.montant_total_subventions,
        sl.liste_subventions
    FROM subsidies_counts sc
    LEFT JOIN subsidies_lists sl ON sl.company_id = sc.company_id
),

vehicles_stats AS (
    SELECT company_id, COUNT(*) AS nb_vehicules
    FROM app.vehicles
    WHERE company_id IN (SELECT company_id FROM company_base)
    GROUP BY 1
),

vat_detailed AS (
    SELECT
        company_id,
        MAX(CASE WHEN sending_status = 'OK'  THEN period_start END) AS derniere_tva_envoyee,
        MAX(CASE WHEN is_teledec = TRUE       THEN period_start END) AS derniere_tva_validee
    FROM app.vat_returns
    WHERE company_id IN (SELECT company_id FROM company_base)
    GROUP BY 1
),

-- ============================================
-- Modèle opérationnel par compte SF (Cosell / Resell)
-- Déduit de la source de l'opportunité ou du revenu
-- ============================================
account_operating_model AS (
    SELECT DISTINCT
        rev.account_id,
        CASE
            WHEN opp.opportunity_source LIKE '%Partnership%' THEN 'Resell'
            WHEN rev.origin             LIKE '%Partnership%' THEN 'Resell'
            ELSE 'Cosell'
        END AS operating_model
    FROM salesforce.revenues rev
    LEFT JOIN (
        SELECT DISTINCT account_id, opportunity_source, closed_at
        FROM sales.opportunities
    ) opp
        ON  opp.account_id = rev.account_id
        AND DATE_TRUNC('day', rev.snapshot_date) = DATE_TRUNC('day', opp.closed_at)
    JOIN salesforce.accounts partner
        ON partner.id = rev.partner_account_id
    WHERE partner.partner_type = 'Resellers'
)

-- ============================================
-- QUERY 1 : Intégrateurs + Clients
-- ============================================
SELECT
    'Intégrateurs_Clients' AS type_donnee,

    i.id AS id_SF_integrateur,
    i.name AS nom_integrateur,
    i.customer_success_owner_email AS consultant_CS,
    c.id AS id_SF_compte,
    c.name AS nom_compte_SF,
    c.registration_number AS SIREN,
    c.account_group_id,
    g.name AS nom_grappe_SF,
    MIN(s.start_date) AS Date_Souscription,
    SUM(s.net_amount) AS Montant_souscription,
    p.id::text AS id_Dossier_PL,
    CASE WHEN p.simplified_status = 'Opened unlimited' THEN 'Oui' ELSE 'Non' END AS Compte_pro_ouvert,
    a.pdp_activation_status AS Statut_pdp,
    a.active_platforms AS Plateforme_active,
    CASE WHEN pcs.pilot_registered_at IS NULL THEN 'No' ELSE 'Yes' END AS registered_to_dgfip_pilot,
    CASE WHEN pcs.is_pilot_enabled IS TRUE THEN 'Active' ELSE 'Not Active' END AS is_active_in_dgfip_pilot,
    om.operating_model,

    NULL::timestamp AS start_date_ticket,
    NULL AS organization_name,
    NULL AS organization_type,
    NULL AS ticket_status,
    NULL AS agent_name,
    NULL AS subject,
    NULL AS contact_reason,
    NULL::numeric AS first_reply_time,
    NULL AS zendesk_link,
    NULL AS requester_email,
    NULL AS requester_name,
    NULL::timestamp AS ticket_solved_at,
    NULL::numeric AS ticket_first_resolution_time,
    NULL::numeric AS ticket_reply_to_resolution_time,
    NULL::timestamp AS ticket_assigned_at,
    NULL::numeric AS ticket_total_resolution_hours,
    NULL AS ticket_resolution_status,

    NULL::bigint AS firm_id,
    NULL AS firm_name,
    NULL::bigint AS user_id,
    NULL AS user_email,
    NULL AS user_first_name,
    NULL AS user_last_name,
    NULL AS user_firm_role,
    NULL::timestamp AS user_last_login,
    NULL::timestamp AS user_created_at,
    NULL AS course_title,
    NULL::float AS course_progress,
    NULL::integer AS time_on_course_seconds,
    NULL::boolean AS course_completed,
    NULL::boolean AS has_badge,

    NULL AS opportunity_id,
    NULL AS opportunity_name,
    NULL AS opportunity_stage,
    NULL AS opportunity_source,
    NULL AS opportunity_type,
    NULL::numeric AS opportunity_amount,
    NULL AS opportunity_owner_email,
    NULL AS opportunity_sdr_email,
    NULL::timestamp AS opportunity_created_at,
    NULL::timestamp AS opportunity_closed_won_at,
    NULL::timestamp AS opportunity_closed_lost_at,
    NULL::date AS opportunity_expected_close_date,
    NULL AS opportunity_closed_lost_reason,
    NULL AS opportunity_sf_link,

    NULL AS event_title,
    NULL::timestamp AS event_date,
    NULL AS attendee_email,
    NULL AS attendee_name,
    NULL AS attendance_status,
    NULL::integer AS attendance_duration_seconds,
    NULL AS event_type,
    NULL AS event_link,
    NULL::boolean AS has_viewed_replay,

    NULL AS certification_course_title,
    NULL::float AS certification_grade,
    NULL::boolean AS certification_passed,
    NULL::timestamp AS certification_submitted_at,

    NULL::integer AS nb_comptes_synchronises,
    NULL::integer AS nb_etablissements_bancaires,
    NULL AS liste_banques,
    NULL AS types_connexion_banque,
    NULL::integer AS nb_users_dossier,
    NULL::integer AS nb_comptables_dossier,
    NULL::integer AS nb_profil_gestion_dossier,
    NULL AS liste_comptables_dossier,
    NULL AS liste_users_gestion_dossier,
    NULL::integer AS nb_exercices_ouverts,
    NULL::date AS plus_ancien_exercice_ouvert,
    NULL::integer AS nb_exercices_clotures,
    NULL AS parametrage_fiscal_finalise,
    NULL AS fiscal_regime,
    NULL AS fiscal_category,
    NULL AS vat_frequency,
    NULL::boolean AS is_cash_based_accounting,
    NULL AS statut_onboarding,
    NULL::integer AS onboarding_score_sur_5,
    NULL AS import_factures_actives,
    NULL::bigint AS nb_fec_importes,
    NULL::bigint AS nb_mdb_importes,
    NULL::bigint AS nb_pluf_importes,
    NULL::timestamp AS dernier_fec_import,
    NULL::timestamp AS dernier_mdb_import,
    NULL::timestamp AS dernier_pluf_import,
    NULL AS detail_fecs_importes,
    NULL AS detail_mdb_importes,
    NULL AS detail_pluf_importes,
    NULL::bigint AS nb_immobilisations,
    NULL::bigint AS nb_emprunts,
    NULL::bigint AS nb_credit_bail,
    NULL::bigint AS nb_subventions,
    NULL::numeric AS montant_total_subventions,
    NULL AS liste_subventions,
    NULL::bigint AS nb_vehicules,
    NULL::date AS derniere_tva_envoyee,
    NULL::date AS derniere_tva_validee

FROM salesforce.accounts i

LEFT JOIN salesforce.accounts c
    ON c.reseller_account_id = i.id
    AND c.account_type = 'Business Owner Account'
    AND c.status = 'Customer'

LEFT JOIN salesforce.account_groups g
    ON c.account_group_id = g.id

LEFT JOIN salesforce.subscriptions s
    ON s.subscriber_account_id = c.id
    AND s.billed_account_id = c.reseller_account_id
    AND s.end_date IS NULL

LEFT JOIN pennylane.companies p
    ON p.reg_no = c.registration_number

LEFT JOIN accounting.pdp_companies a
    ON a.siren = c.registration_number

LEFT JOIN app.pdp_company_settings pcs
    ON a.company_id = pcs.company_id

LEFT JOIN account_operating_model om
    ON om.account_id = c.id

WHERE i.id IN (SELECT id_sf_integrateur FROM identified_companies)

GROUP BY
    i.id, i.name, i.customer_success_owner_email, c.id, p.id, c.name,
    c.registration_number, c.account_group_id, g.name, p.simplified_status,
    a.pdp_activation_status, pcs.pilot_registered_at, pcs.is_pilot_enabled,
    a.active_platforms, om.operating_model

UNION ALL

-- ============================================
-- QUERY 2 : Tickets Zendesk Partner Integrator
-- ============================================
SELECT
    'Tickets_Zendesk' AS type_donnee,

    NULL AS id_SF_integrateur,
    NULL AS nom_integrateur,
    NULL AS consultant_CS,
    NULL AS id_SF_compte,
    NULL AS nom_compte_SF,
    NULL AS SIREN,
    NULL AS account_group_id,
    NULL AS nom_grappe_SF,
    NULL::timestamp AS Date_Souscription,
    NULL::numeric AS Montant_souscription,
    NULL AS id_Dossier_PL,
    NULL AS Compte_pro_ouvert,
    NULL AS Statut_pdp,
    NULL AS Plateforme_active,
    NULL AS registered_to_dgfip_pilot,
    NULL AS is_active_in_dgfip_pilot,
    NULL AS operating_model,

    date_trunc('month', tickets.created_at) AS start_date_ticket,
    organizations.name AS organization_name,
    organizations.organization_type,
    tickets.status AS ticket_status,
    agent.name AS agent_name,
    tickets.subject,
    coalesce(tickets.cs_category, tickets.ps_category) AS contact_reason,
    tickets.first_reply_time,
    'https://pennylane3952.zendesk.com/agent/tickets/' || tickets.id AS zendesk_link,
    requester.email_address AS requester_email,
    requester.name AS requester_name,
    tickets.solved_at AS ticket_solved_at,
    tickets.first_resolution_time AS ticket_first_resolution_time,
    tickets.first_reply_to_first_resolution_time AS ticket_reply_to_resolution_time,
    tickets.initially_assigned_at AS ticket_assigned_at,
    CASE
        WHEN tickets.solved_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (tickets.solved_at - tickets.created_at)) / 3600
        ELSE NULL
    END AS ticket_total_resolution_hours,
    CASE
        WHEN tickets.status IN ('solved', 'closed') THEN 'Résolu'
        WHEN tickets.status = 'pending'             THEN 'En attente'
        WHEN tickets.status = 'open'                THEN 'Ouvert'
        ELSE tickets.status
    END AS ticket_resolution_status,

    NULL::bigint AS firm_id,
    NULL AS firm_name,
    NULL::bigint AS user_id,
    NULL AS user_email,
    NULL AS user_first_name,
    NULL AS user_last_name,
    NULL AS user_firm_role,
    NULL::timestamp AS user_last_login,
    NULL::timestamp AS user_created_at,
    NULL AS course_title,
    NULL::float AS course_progress,
    NULL::integer AS time_on_course_seconds,
    NULL::boolean AS course_completed,
    NULL::boolean AS has_badge,

    NULL AS opportunity_id,
    NULL AS opportunity_name,
    NULL AS opportunity_stage,
    NULL AS opportunity_source,
    NULL AS opportunity_type,
    NULL::numeric AS opportunity_amount,
    NULL AS opportunity_owner_email,
    NULL AS opportunity_sdr_email,
    NULL::timestamp AS opportunity_created_at,
    NULL::timestamp AS opportunity_closed_won_at,
    NULL::timestamp AS opportunity_closed_lost_at,
    NULL::date AS opportunity_expected_close_date,
    NULL AS opportunity_closed_lost_reason,
    NULL AS opportunity_sf_link,

    NULL AS event_title,
    NULL::timestamp AS event_date,
    NULL AS attendee_email,
    NULL AS attendee_name,
    NULL AS attendance_status,
    NULL::integer AS attendance_duration_seconds,
    NULL AS event_type,
    NULL AS event_link,
    NULL::boolean AS has_viewed_replay,

    NULL AS certification_course_title,
    NULL::float AS certification_grade,
    NULL::boolean AS certification_passed,
    NULL::timestamp AS certification_submitted_at,

    NULL::integer AS nb_comptes_synchronises,
    NULL::integer AS nb_etablissements_bancaires,
    NULL AS liste_banques,
    NULL AS types_connexion_banque,
    NULL::integer AS nb_users_dossier,
    NULL::integer AS nb_comptables_dossier,
    NULL::integer AS nb_profil_gestion_dossier,
    NULL AS liste_comptables_dossier,
    NULL AS liste_users_gestion_dossier,
    NULL::integer AS nb_exercices_ouverts,
    NULL::date AS plus_ancien_exercice_ouvert,
    NULL::integer AS nb_exercices_clotures,
    NULL AS parametrage_fiscal_finalise,
    NULL AS fiscal_regime,
    NULL AS fiscal_category,
    NULL AS vat_frequency,
    NULL::boolean AS is_cash_based_accounting,
    NULL AS statut_onboarding,
    NULL::integer AS onboarding_score_sur_5,
    NULL AS import_factures_actives,
    NULL::bigint AS nb_fec_importes,
    NULL::bigint AS nb_mdb_importes,
    NULL::bigint AS nb_pluf_importes,
    NULL::timestamp AS dernier_fec_import,
    NULL::timestamp AS dernier_mdb_import,
    NULL::timestamp AS dernier_pluf_import,
    NULL AS detail_fecs_importes,
    NULL AS detail_mdb_importes,
    NULL AS detail_pluf_importes,
    NULL::bigint AS nb_immobilisations,
    NULL::bigint AS nb_emprunts,
    NULL::bigint AS nb_credit_bail,
    NULL::bigint AS nb_subventions,
    NULL::numeric AS montant_total_subventions,
    NULL AS liste_subventions,
    NULL::bigint AS nb_vehicules,
    NULL::date AS derniere_tva_envoyee,
    NULL::date AS derniere_tva_validee

FROM zendesk.tickets

LEFT JOIN zendesk.organizations
    ON organizations.id = tickets.organization_id

LEFT JOIN zendesk.users agent
    ON tickets.assignee_id = agent.id

LEFT JOIN zendesk.users requester
    ON tickets.requester_id = requester.id

WHERE organizations.organization_type = 'partner_integrator'

UNION ALL

-- ============================================
-- QUERY 3 : Intégrateurs + Users + Learnworlds
-- ============================================
SELECT
    'Intégrateurs_Users_Learnworlds' AS type_donnee,

    i.id AS id_SF_integrateur,
    i.name AS nom_integrateur,
    i.customer_success_owner_email AS consultant_CS,
    NULL AS id_SF_compte,
    NULL AS nom_compte_SF,
    NULL AS SIREN,
    NULL AS account_group_id,
    NULL AS nom_grappe_SF,
    NULL::timestamp AS Date_Souscription,
    NULL::numeric AS Montant_souscription,
    NULL AS id_Dossier_PL,
    NULL AS Compte_pro_ouvert,
    NULL AS Statut_pdp,
    NULL AS Plateforme_active,
    NULL AS registered_to_dgfip_pilot,
    NULL AS is_active_in_dgfip_pilot,
    NULL AS operating_model,

    NULL::timestamp AS start_date_ticket,
    NULL AS organization_name,
    NULL AS organization_type,
    NULL AS ticket_status,
    NULL AS agent_name,
    NULL AS subject,
    NULL AS contact_reason,
    NULL::numeric AS first_reply_time,
    NULL AS zendesk_link,
    NULL AS requester_email,
    NULL AS requester_name,
    NULL::timestamp AS ticket_solved_at,
    NULL::numeric AS ticket_first_resolution_time,
    NULL::numeric AS ticket_reply_to_resolution_time,
    NULL::timestamp AS ticket_assigned_at,
    NULL::numeric AS ticket_total_resolution_hours,
    NULL AS ticket_resolution_status,

    f.id AS firm_id,
    f.name AS firm_name,
    u.id AS user_id,
    u.email AS user_email,
    u.first_name AS user_first_name,
    u.last_name AS user_last_name,
    uf.role AS user_firm_role,
    u.current_sign_in_at AS user_last_login,
    u.created_at AS user_created_at,
    lw_courses.title AS course_title,
    lw_progress.progress_rate AS course_progress,
    lw_progress.time_on_course AS time_on_course_seconds,
    lw_progress.is_completed AS course_completed,
    lw_progress.has_badge AS has_badge,

    NULL AS opportunity_id,
    NULL AS opportunity_name,
    NULL AS opportunity_stage,
    NULL AS opportunity_source,
    NULL AS opportunity_type,
    NULL::numeric AS opportunity_amount,
    NULL AS opportunity_owner_email,
    NULL AS opportunity_sdr_email,
    NULL::timestamp AS opportunity_created_at,
    NULL::timestamp AS opportunity_closed_won_at,
    NULL::timestamp AS opportunity_closed_lost_at,
    NULL::date AS opportunity_expected_close_date,
    NULL AS opportunity_closed_lost_reason,
    NULL AS opportunity_sf_link,

    NULL AS event_title,
    NULL::timestamp AS event_date,
    NULL AS attendee_email,
    NULL AS attendee_name,
    NULL AS attendance_status,
    NULL::integer AS attendance_duration_seconds,
    NULL AS event_type,
    NULL AS event_link,
    NULL::boolean AS has_viewed_replay,

    NULL AS certification_course_title,
    NULL::float AS certification_grade,
    NULL::boolean AS certification_passed,
    NULL::timestamp AS certification_submitted_at,

    NULL::integer AS nb_comptes_synchronises,
    NULL::integer AS nb_etablissements_bancaires,
    NULL AS liste_banques,
    NULL AS types_connexion_banque,
    NULL::integer AS nb_users_dossier,
    NULL::integer AS nb_comptables_dossier,
    NULL::integer AS nb_profil_gestion_dossier,
    NULL AS liste_comptables_dossier,
    NULL AS liste_users_gestion_dossier,
    NULL::integer AS nb_exercices_ouverts,
    NULL::date AS plus_ancien_exercice_ouvert,
    NULL::integer AS nb_exercices_clotures,
    NULL AS parametrage_fiscal_finalise,
    NULL AS fiscal_regime,
    NULL AS fiscal_category,
    NULL AS vat_frequency,
    NULL::boolean AS is_cash_based_accounting,
    NULL AS statut_onboarding,
    NULL::integer AS onboarding_score_sur_5,
    NULL AS import_factures_actives,
    NULL::bigint AS nb_fec_importes,
    NULL::bigint AS nb_mdb_importes,
    NULL::bigint AS nb_pluf_importes,
    NULL::timestamp AS dernier_fec_import,
    NULL::timestamp AS dernier_mdb_import,
    NULL::timestamp AS dernier_pluf_import,
    NULL AS detail_fecs_importes,
    NULL AS detail_mdb_importes,
    NULL AS detail_pluf_importes,
    NULL::bigint AS nb_immobilisations,
    NULL::bigint AS nb_emprunts,
    NULL::bigint AS nb_credit_bail,
    NULL::bigint AS nb_subventions,
    NULL::numeric AS montant_total_subventions,
    NULL AS liste_subventions,
    NULL::bigint AS nb_vehicules,
    NULL::date AS derniere_tva_envoyee,
    NULL::date AS derniere_tva_validee

FROM salesforce.accounts i

LEFT JOIN app.firms f
    ON f.salesforce_account_id = i.id

LEFT JOIN app.users_firms uf
    ON uf.firm_id = f.id

LEFT JOIN app.users u
    ON u.id = uf.user_id

LEFT JOIN learnworlds.users lw_user
    ON lw_user.pennylane_user_id = u.id

LEFT JOIN learnworlds.user_progress lw_progress
    ON lw_progress.user_id = lw_user.id

LEFT JOIN learnworlds.courses lw_courses
    ON lw_courses.id = lw_progress.course_id

WHERE i.id IN (SELECT id_sf_integrateur FROM identified_companies)

UNION ALL

-- ============================================
-- QUERY 4 : Opportunités des clients des intégrateurs
-- ============================================
SELECT
    'Opportunités_Clients' AS type_donnee,

    i.id AS id_SF_integrateur,
    i.name AS nom_integrateur,
    i.customer_success_owner_email AS consultant_CS,
    c.id AS id_SF_compte,
    c.name AS nom_compte_SF,
    c.registration_number AS SIREN,
    c.account_group_id,
    g.name AS nom_grappe_SF,
    NULL::timestamp AS Date_Souscription,
    NULL::numeric AS Montant_souscription,
    NULL AS id_Dossier_PL,
    NULL AS Compte_pro_ouvert,
    NULL AS Statut_pdp,
    NULL AS Plateforme_active,
    NULL AS registered_to_dgfip_pilot,
    NULL AS is_active_in_dgfip_pilot,
    NULL AS operating_model,

    NULL::timestamp AS start_date_ticket,
    NULL AS organization_name,
    NULL AS organization_type,
    NULL AS ticket_status,
    NULL AS agent_name,
    NULL AS subject,
    NULL AS contact_reason,
    NULL::numeric AS first_reply_time,
    NULL AS zendesk_link,
    NULL AS requester_email,
    NULL AS requester_name,
    NULL::timestamp AS ticket_solved_at,
    NULL::numeric AS ticket_first_resolution_time,
    NULL::numeric AS ticket_reply_to_resolution_time,
    NULL::timestamp AS ticket_assigned_at,
    NULL::numeric AS ticket_total_resolution_hours,
    NULL AS ticket_resolution_status,

    NULL::bigint AS firm_id,
    NULL AS firm_name,
    NULL::bigint AS user_id,
    NULL AS user_email,
    NULL AS user_first_name,
    NULL AS user_last_name,
    NULL AS user_firm_role,
    NULL::timestamp AS user_last_login,
    NULL::timestamp AS user_created_at,
    NULL AS course_title,
    NULL::float AS course_progress,
    NULL::integer AS time_on_course_seconds,
    NULL::boolean AS course_completed,
    NULL::boolean AS has_badge,

    opp.id AS opportunity_id,
    opp.name AS opportunity_name,
    opp.opportunity_stage AS opportunity_stage,
    opp.opportunity_source AS opportunity_source,
    opp.opportunity_type AS opportunity_type,
    (opp.recurring_revenue_amount + opp.non_recurring_revenue_amount) AS opportunity_amount,
    opp.owner_email AS opportunity_owner_email,
    opp.sdr_owner_email AS opportunity_sdr_email,
    opp.created_at AS opportunity_created_at,
    opp.closed_won_at AS opportunity_closed_won_at,
    opp.closed_lost_at AS opportunity_closed_lost_at,
    opp.closed_at AS opportunity_expected_close_date,
    opp.closed_lost_reason AS opportunity_closed_lost_reason,
    'https://pennylane.lightning.force.com/lightning/r/Opportunity/' || opp.id || '/view' AS opportunity_sf_link,

    NULL AS event_title,
    NULL::timestamp AS event_date,
    NULL AS attendee_email,
    NULL AS attendee_name,
    NULL AS attendance_status,
    NULL::integer AS attendance_duration_seconds,
    NULL AS event_type,
    NULL AS event_link,
    NULL::boolean AS has_viewed_replay,

    NULL AS certification_course_title,
    NULL::float AS certification_grade,
    NULL::boolean AS certification_passed,
    NULL::timestamp AS certification_submitted_at,

    NULL::integer AS nb_comptes_synchronises,
    NULL::integer AS nb_etablissements_bancaires,
    NULL AS liste_banques,
    NULL AS types_connexion_banque,
    NULL::integer AS nb_users_dossier,
    NULL::integer AS nb_comptables_dossier,
    NULL::integer AS nb_profil_gestion_dossier,
    NULL AS liste_comptables_dossier,
    NULL AS liste_users_gestion_dossier,
    NULL::integer AS nb_exercices_ouverts,
    NULL::date AS plus_ancien_exercice_ouvert,
    NULL::integer AS nb_exercices_clotures,
    NULL AS parametrage_fiscal_finalise,
    NULL AS fiscal_regime,
    NULL AS fiscal_category,
    NULL AS vat_frequency,
    NULL::boolean AS is_cash_based_accounting,
    NULL AS statut_onboarding,
    NULL::integer AS onboarding_score_sur_5,
    NULL AS import_factures_actives,
    NULL::bigint AS nb_fec_importes,
    NULL::bigint AS nb_mdb_importes,
    NULL::bigint AS nb_pluf_importes,
    NULL::timestamp AS dernier_fec_import,
    NULL::timestamp AS dernier_mdb_import,
    NULL::timestamp AS dernier_pluf_import,
    NULL AS detail_fecs_importes,
    NULL AS detail_mdb_importes,
    NULL AS detail_pluf_importes,
    NULL::bigint AS nb_immobilisations,
    NULL::bigint AS nb_emprunts,
    NULL::bigint AS nb_credit_bail,
    NULL::bigint AS nb_subventions,
    NULL::numeric AS montant_total_subventions,
    NULL AS liste_subventions,
    NULL::bigint AS nb_vehicules,
    NULL::date AS derniere_tva_envoyee,
    NULL::date AS derniere_tva_validee

FROM salesforce.accounts i

INNER JOIN salesforce.accounts c
    ON c.reseller_account_id = i.id
    AND c.account_type = 'Business Owner Account'
    AND c.status = 'Customer'

LEFT JOIN salesforce.account_groups g
    ON g.id = c.account_group_id

INNER JOIN salesforce.opportunities opp
    ON opp.account_id = c.id

WHERE i.id IN (SELECT id_sf_integrateur FROM identified_companies)

UNION ALL

-- ============================================
-- QUERY 5 : Événements Livestorm
-- ============================================
SELECT
    'Événements_Livestorm' AS type_donnee,

    i.id AS id_SF_integrateur,
    i.name AS nom_integrateur,
    i.customer_success_owner_email AS consultant_CS,
    NULL AS id_SF_compte,
    NULL AS nom_compte_SF,
    NULL AS SIREN,
    NULL AS account_group_id,
    NULL AS nom_grappe_SF,
    NULL::timestamp AS Date_Souscription,
    NULL::numeric AS Montant_souscription,
    NULL AS id_Dossier_PL,
    NULL AS Compte_pro_ouvert,
    NULL AS Statut_pdp,
    NULL AS Plateforme_active,
    NULL AS registered_to_dgfip_pilot,
    NULL AS is_active_in_dgfip_pilot,
    NULL AS operating_model,

    NULL::timestamp AS start_date_ticket,
    NULL AS organization_name,
    NULL AS organization_type,
    NULL AS ticket_status,
    NULL AS agent_name,
    NULL AS subject,
    NULL AS contact_reason,
    NULL::numeric AS first_reply_time,
    NULL AS zendesk_link,
    NULL AS requester_email,
    NULL AS requester_name,
    NULL::timestamp AS ticket_solved_at,
    NULL::numeric AS ticket_first_resolution_time,
    NULL::numeric AS ticket_reply_to_resolution_time,
    NULL::timestamp AS ticket_assigned_at,
    NULL::numeric AS ticket_total_resolution_hours,
    NULL AS ticket_resolution_status,

    f.id AS firm_id,
    f.name AS firm_name,
    u.id AS user_id,
    u.email AS user_email,
    u.first_name AS user_first_name,
    u.last_name AS user_last_name,
    uf.role AS user_firm_role,
    u.current_sign_in_at AS user_last_login,
    u.created_at AS user_created_at,
    NULL AS course_title,
    NULL::float AS course_progress,
    NULL::integer AS time_on_course_seconds,
    NULL::boolean AS course_completed,
    NULL::boolean AS has_badge,

    NULL AS opportunity_id,
    NULL AS opportunity_name,
    NULL AS opportunity_stage,
    NULL AS opportunity_source,
    NULL AS opportunity_type,
    NULL::numeric AS opportunity_amount,
    NULL AS opportunity_owner_email,
    NULL AS opportunity_sdr_email,
    NULL::timestamp AS opportunity_created_at,
    NULL::timestamp AS opportunity_closed_won_at,
    NULL::timestamp AS opportunity_closed_lost_at,
    NULL::date AS opportunity_expected_close_date,
    NULL AS opportunity_closed_lost_reason,
    NULL AS opportunity_sf_link,

    events.title AS event_title,
    session_people.registered_at AS event_date,
    session_people.email AS attendee_email,
    COALESCE(session_people.first_name, '') || ' ' || COALESCE(session_people.last_name, '') AS attendee_name,
    CASE
        WHEN session_people.has_attended = true       THEN 'attended'
        WHEN session_people.registered_at IS NOT NULL THEN 'registered'
        ELSE                                               'missed'
    END AS attendance_status,
    session_people.attendance_duration AS attendance_duration_seconds,
    CASE
        WHEN events.title ILIKE '%webinar%'                                      THEN 'webinar'
        WHEN events.title ILIKE '%workshop%'                                     THEN 'workshop'
        WHEN events.title ILIKE '%formation%' OR events.title ILIKE '%training%' THEN 'training'
        ELSE                                                                          'event'
    END AS event_type,
    events.registration_link AS event_link,
    CAST(session_people.registrant_detail.has_viewed_replay AS boolean) AS has_viewed_replay,

    NULL AS certification_course_title,
    NULL::float AS certification_grade,
    NULL::boolean AS certification_passed,
    NULL::timestamp AS certification_submitted_at,

    NULL::integer AS nb_comptes_synchronises,
    NULL::integer AS nb_etablissements_bancaires,
    NULL AS liste_banques,
    NULL AS types_connexion_banque,
    NULL::integer AS nb_users_dossier,
    NULL::integer AS nb_comptables_dossier,
    NULL::integer AS nb_profil_gestion_dossier,
    NULL AS liste_comptables_dossier,
    NULL AS liste_users_gestion_dossier,
    NULL::integer AS nb_exercices_ouverts,
    NULL::date AS plus_ancien_exercice_ouvert,
    NULL::integer AS nb_exercices_clotures,
    NULL AS parametrage_fiscal_finalise,
    NULL AS fiscal_regime,
    NULL AS fiscal_category,
    NULL AS vat_frequency,
    NULL::boolean AS is_cash_based_accounting,
    NULL AS statut_onboarding,
    NULL::integer AS onboarding_score_sur_5,
    NULL AS import_factures_actives,
    NULL::bigint AS nb_fec_importes,
    NULL::bigint AS nb_mdb_importes,
    NULL::bigint AS nb_pluf_importes,
    NULL::timestamp AS dernier_fec_import,
    NULL::timestamp AS dernier_mdb_import,
    NULL::timestamp AS dernier_pluf_import,
    NULL AS detail_fecs_importes,
    NULL AS detail_mdb_importes,
    NULL AS detail_pluf_importes,
    NULL::bigint AS nb_immobilisations,
    NULL::bigint AS nb_emprunts,
    NULL::bigint AS nb_credit_bail,
    NULL::bigint AS nb_subventions,
    NULL::numeric AS montant_total_subventions,
    NULL AS liste_subventions,
    NULL::bigint AS nb_vehicules,
    NULL::date AS derniere_tva_envoyee,
    NULL::date AS derniere_tva_validee

FROM salesforce.accounts i

LEFT JOIN app.firms f
    ON f.salesforce_account_id = i.id

LEFT JOIN app.users_firms uf
    ON uf.firm_id = f.id

LEFT JOIN app.users u
    ON u.id = uf.user_id

INNER JOIN livestorm.session_people
    ON session_people.email = u.email

INNER JOIN livestorm.events
    ON events.id = session_people.event_id

WHERE i.id IN (SELECT id_sf_integrateur FROM identified_companies)

UNION ALL

-- ============================================
-- QUERY 6 : Certifications Learnworlds
-- ============================================
SELECT
    'Learnworlds_Certifications' AS type_donnee,

    i.id AS id_SF_integrateur,
    i.name AS nom_integrateur,
    i.customer_success_owner_email AS consultant_CS,
    NULL AS id_SF_compte,
    NULL AS nom_compte_SF,
    NULL AS SIREN,
    NULL AS account_group_id,
    NULL AS nom_grappe_SF,
    NULL::timestamp AS Date_Souscription,
    NULL::numeric AS Montant_souscription,
    NULL AS id_Dossier_PL,
    NULL AS Compte_pro_ouvert,
    NULL AS Statut_pdp,
    NULL AS Plateforme_active,
    NULL AS registered_to_dgfip_pilot,
    NULL AS is_active_in_dgfip_pilot,
    NULL AS operating_model,

    NULL::timestamp AS start_date_ticket,
    NULL AS organization_name,
    NULL AS organization_type,
    NULL AS ticket_status,
    NULL AS agent_name,
    NULL AS subject,
    NULL AS contact_reason,
    NULL::numeric AS first_reply_time,
    NULL AS zendesk_link,
    NULL AS requester_email,
    NULL AS requester_name,
    NULL::timestamp AS ticket_solved_at,
    NULL::numeric AS ticket_first_resolution_time,
    NULL::numeric AS ticket_reply_to_resolution_time,
    NULL::timestamp AS ticket_assigned_at,
    NULL::numeric AS ticket_total_resolution_hours,
    NULL AS ticket_resolution_status,

    f.id AS firm_id,
    f.name AS firm_name,
    u.id AS user_id,
    u.email AS user_email,
    u.first_name AS user_first_name,
    u.last_name AS user_last_name,
    uf.role AS user_firm_role,
    u.current_sign_in_at AS user_last_login,
    u.created_at AS user_created_at,
    NULL AS course_title,
    NULL::float AS course_progress,
    NULL::integer AS time_on_course_seconds,
    NULL::boolean AS course_completed,
    NULL::boolean AS has_badge,

    NULL AS opportunity_id,
    NULL AS opportunity_name,
    NULL AS opportunity_stage,
    NULL AS opportunity_source,
    NULL AS opportunity_type,
    NULL::numeric AS opportunity_amount,
    NULL AS opportunity_owner_email,
    NULL AS opportunity_sdr_email,
    NULL::timestamp AS opportunity_created_at,
    NULL::timestamp AS opportunity_closed_won_at,
    NULL::timestamp AS opportunity_closed_lost_at,
    NULL::date AS opportunity_expected_close_date,
    NULL AS opportunity_closed_lost_reason,
    NULL AS opportunity_sf_link,

    NULL AS event_title,
    NULL::timestamp AS event_date,
    NULL AS attendee_email,
    NULL AS attendee_name,
    NULL AS attendance_status,
    NULL::integer AS attendance_duration_seconds,
    NULL AS event_type,
    NULL AS event_link,
    NULL::boolean AS has_viewed_replay,

    assessments.course_title AS certification_course_title,
    assessments.grade AS certification_grade,
    assessments.has_passed AS certification_passed,
    assessments.submitted_at AS certification_submitted_at,

    NULL::integer AS nb_comptes_synchronises,
    NULL::integer AS nb_etablissements_bancaires,
    NULL AS liste_banques,
    NULL AS types_connexion_banque,
    NULL::integer AS nb_users_dossier,
    NULL::integer AS nb_comptables_dossier,
    NULL::integer AS nb_profil_gestion_dossier,
    NULL AS liste_comptables_dossier,
    NULL AS liste_users_gestion_dossier,
    NULL::integer AS nb_exercices_ouverts,
    NULL::date AS plus_ancien_exercice_ouvert,
    NULL::integer AS nb_exercices_clotures,
    NULL AS parametrage_fiscal_finalise,
    NULL AS fiscal_regime,
    NULL AS fiscal_category,
    NULL AS vat_frequency,
    NULL::boolean AS is_cash_based_accounting,
    NULL AS statut_onboarding,
    NULL::integer AS onboarding_score_sur_5,
    NULL AS import_factures_actives,
    NULL::bigint AS nb_fec_importes,
    NULL::bigint AS nb_mdb_importes,
    NULL::bigint AS nb_pluf_importes,
    NULL::timestamp AS dernier_fec_import,
    NULL::timestamp AS dernier_mdb_import,
    NULL::timestamp AS dernier_pluf_import,
    NULL AS detail_fecs_importes,
    NULL AS detail_mdb_importes,
    NULL AS detail_pluf_importes,
    NULL::bigint AS nb_immobilisations,
    NULL::bigint AS nb_emprunts,
    NULL::bigint AS nb_credit_bail,
    NULL::bigint AS nb_subventions,
    NULL::numeric AS montant_total_subventions,
    NULL AS liste_subventions,
    NULL::bigint AS nb_vehicules,
    NULL::date AS derniere_tva_envoyee,
    NULL::date AS derniere_tva_validee

FROM salesforce.accounts i

INNER JOIN app.firms f
    ON f.salesforce_account_id = i.id

INNER JOIN app.users_firms uf
    ON uf.firm_id = f.id

INNER JOIN app.users u
    ON u.id = uf.user_id

INNER JOIN learnworlds.users lw_user
    ON lw_user.pennylane_user_id = u.id

INNER JOIN learnworlds.assessments
    ON assessments.user_id = lw_user.id

WHERE i.id IN (SELECT id_sf_integrateur FROM identified_companies)
AND assessments.course_title IN (
    'Certification Pennylane Interface Comptabilité',
    'Certification Pennylane Interface Comptabilité - mettre à jour son diplôme',
    'Certification Spécialiste Facture Électronique',
    'Examen Accréditation Consultant Intégrateur'
)

UNION ALL

-- ============================================
-- QUERY 7 : Détail dossiers Pennylane
-- ============================================
SELECT
    'Détail_Dossiers_PL' AS type_donnee,

    ic.id_sf_integrateur,
    ic.nom_integrateur,
    ic.consultant_cs,
    ic.id_sf_compte,
    cb.company_name AS nom_compte_SF,
    cb.siren AS SIREN,
    sf_acc.account_group_id,
    ag.name AS nom_grappe_SF,
    NULL::timestamp AS Date_Souscription,
    NULL::numeric AS Montant_souscription,
    cb.company_id::text AS id_Dossier_PL,
    NULL AS Compte_pro_ouvert,
    NULL AS Statut_pdp,
    NULL AS Plateforme_active,
    NULL AS registered_to_dgfip_pilot,
    NULL AS is_active_in_dgfip_pilot,
    NULL AS operating_model,

    NULL::timestamp AS start_date_ticket,
    NULL AS organization_name,
    NULL AS organization_type,
    NULL AS ticket_status,
    NULL AS agent_name,
    NULL AS subject,
    NULL AS contact_reason,
    NULL::numeric AS first_reply_time,
    NULL AS zendesk_link,
    NULL AS requester_email,
    NULL AS requester_name,
    NULL::timestamp AS ticket_solved_at,
    NULL::numeric AS ticket_first_resolution_time,
    NULL::numeric AS ticket_reply_to_resolution_time,
    NULL::timestamp AS ticket_assigned_at,
    NULL::numeric AS ticket_total_resolution_hours,
    NULL AS ticket_resolution_status,

    NULL::bigint AS firm_id,
    cb.firm_name,
    NULL::bigint AS user_id,
    NULL AS user_email,
    NULL AS user_first_name,
    NULL AS user_last_name,
    NULL AS user_firm_role,
    NULL::timestamp AS user_last_login,
    NULL::timestamp AS user_created_at,
    NULL AS course_title,
    NULL::float AS course_progress,
    NULL::integer AS time_on_course_seconds,
    NULL::boolean AS course_completed,
    NULL::boolean AS has_badge,

    NULL AS opportunity_id,
    NULL AS opportunity_name,
    NULL AS opportunity_stage,
    NULL AS opportunity_source,
    NULL AS opportunity_type,
    NULL::numeric AS opportunity_amount,
    NULL AS opportunity_owner_email,
    NULL AS opportunity_sdr_email,
    NULL::timestamp AS opportunity_created_at,
    NULL::timestamp AS opportunity_closed_won_at,
    NULL::timestamp AS opportunity_closed_lost_at,
    NULL::date AS opportunity_expected_close_date,
    NULL AS opportunity_closed_lost_reason,
    NULL AS opportunity_sf_link,

    NULL AS event_title,
    NULL::timestamp AS event_date,
    NULL AS attendee_email,
    NULL AS attendee_name,
    NULL AS attendance_status,
    NULL::integer AS attendance_duration_seconds,
    NULL AS event_type,
    NULL AS event_link,
    NULL::boolean AS has_viewed_replay,

    NULL AS certification_course_title,
    NULL::float AS certification_grade,
    NULL::boolean AS certification_passed,
    NULL::timestamp AS certification_submitted_at,

    COALESCE(bd.nb_comptes_synchronises, 0)::integer     AS nb_comptes_synchronises,
    COALESCE(bd.nb_etablissements_bancaires, 0)::integer AS nb_etablissements_bancaires,
    bd.liste_banques,
    bd.types_connexion_banque,
    COALESCE(ud.nb_users_dossier, 0)::integer            AS nb_users_dossier,
    COALESCE(ud.nb_comptables_dossier, 0)::integer       AS nb_comptables_dossier,
    COALESCE(ud.nb_profil_gestion_dossier, 0)::integer   AS nb_profil_gestion_dossier,
    ud.liste_comptables_dossier,
    ud.liste_users_gestion_dossier,
    COALESCE(fy.nb_exercices_ouverts, 0)::integer        AS nb_exercices_ouverts,
    fy.plus_ancien_exercice_ouvert,
    COALESCE(fy.nb_exercices_clotures, 0)::integer       AS nb_exercices_clotures,
    fp.parametrage_fiscal_finalise,
    fp.fiscal_regime,
    fp.fiscal_category,
    fp.vat_frequency,
    fp.is_cash_based_accounting,
    os.statut_onboarding,
    os.onboarding_score_sur_5,
    COALESCE(isrc.sources_import_factures, 'Aucun')      AS import_factures_actives,
    COALESCE(fi.nb_fec_importes, 0)                      AS nb_fec_importes,
    COALESCE(fi.nb_mdb_importes, 0)                      AS nb_mdb_importes,
    COALESCE(fi.nb_pluf_importes, 0)                     AS nb_pluf_importes,
    fi.dernier_fec_import,
    fi.dernier_mdb_import,
    fi.dernier_pluf_import,
    fi.detail_fecs_importes,
    fi.detail_mdb_importes,
    fi.detail_pluf_importes,
    COALESCE(ast.nb_immobilisations, 0)                  AS nb_immobilisations,
    COALESCE(ln.nb_emprunts, 0)                          AS nb_emprunts,
    COALESCE(ls.nb_credit_bail, 0)                       AS nb_credit_bail,
    COALESCE(ss.nb_subventions, 0)                       AS nb_subventions,
    ss.montant_total_subventions,
    ss.liste_subventions,
    COALESCE(vs.nb_vehicules, 0)                         AS nb_vehicules,
    vd.derniere_tva_envoyee,
    vd.derniere_tva_validee

FROM company_base cb
LEFT JOIN identified_companies ic  ON ic.siren          = cb.siren
LEFT JOIN salesforce.accounts sf_acc ON sf_acc.registration_number = cb.siren
    AND sf_acc.account_type = 'Business Owner Account'
LEFT JOIN salesforce.account_groups ag ON ag.id = sf_acc.account_group_id
LEFT JOIN banks_detailed bd        ON bd.company_id    = cb.company_id
LEFT JOIN users_detailed ud       ON ud.company_id   = cb.company_id
LEFT JOIN fiscal_years_stats fy   ON fy.company_id   = cb.company_id
LEFT JOIN fiscal_params fp        ON fp.company_id   = cb.company_id
LEFT JOIN onboarding_status os    ON os.company_id   = cb.company_id
LEFT JOIN invoices_sources isrc   ON isrc.company_id = cb.company_id
LEFT JOIN fec_imports fi          ON fi.company_id   = cb.company_id
LEFT JOIN assets_stats ast        ON ast.company_id  = cb.company_id
LEFT JOIN loans_stats ln          ON ln.company_id   = cb.company_id
LEFT JOIN leases_stats ls         ON ls.company_id   = cb.company_id
LEFT JOIN subsidies_stats ss      ON ss.company_id   = cb.company_id
LEFT JOIN vehicles_stats vs       ON vs.company_id   = cb.company_id
LEFT JOIN vat_detailed vd         ON vd.company_id   = cb.company_id;
