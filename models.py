import sqlite3
import json
from datetime import datetime
from pathlib import Path

DB_PATH = Path(__file__).parent / "onboarding.db"

TASKS_DEFINITION = [
    # Phase: à l'arrivée (fusion avant l'arrivée + lors de l'arrivée)
    {"key": "welcome_card", "phase": "a_larrivee", "label": "Carte de bienvenue envoyée", "auto": False,
     "link": None, "description": "Envoyer la carte de bienvenue quelques jours avant l'arrivée"},
    {"key": "newcomer_sheet", "phase": "a_larrivee", "label": "Ajout fichier accès newcomers", "auto": False,
     "link": "https://docs.google.com/spreadsheets/d/1K9KAAc3vQC2xsd0Jx_Cu5iiNzNu2K3e4XgF1DDrZk08/edit?gid=0#gid=0",
     "description": "Ajouter l'IC dans le fichier Google Sheets des accès newcomers"},
    {"key": "lucca_objectives", "phase": "a_larrivee", "label": "Objectifs dans Lucca", "auto": False,
     "link": None, "description": "Définir les objectifs de l'IC dans Lucca"},

    # Phase: accès - automatisés Slack
    {"key": "slack_channel", "phase": "access", "label": "Slack : ajout #proservices", "auto": True,
     "link": None, "description": "Ajouter le newcomer au canal Slack #proservices"},
    {"key": "slack_group_cs", "phase": "access", "label": "Slack : groupe @cs.services", "auto": True,
     "link": None, "description": "Ajouter le newcomer au groupe d'utilisateurs @cs.services"},
    {"key": "slack_group_ob", "phase": "access", "label": "Slack : groupe @ob", "auto": True,
     "link": None, "description": "Ajouter le newcomer au groupe d'utilisateurs @ob"},

    # Phase: accès - manuels
    {"key": "google_agenda", "phase": "access", "label": "Google Agenda Newcomers : accès lecture seule", "auto": False,
     "link": None, "description": "Donner un accès en lecture seule à l'agenda Google Newcomers à l'IC"},
    {"key": "google_group", "phase": "access", "label": "Google Group Professional Services : ajout IC", "auto": False,
     "link": None, "description": "Ajouter l'IC dans le Google Group Professional Services"},
    {"key": "salesforce_email", "phase": "access", "label": "SalesForce : vérif adresse mail", "auto": False,
     "link": None, "description": "Vérifier que l'adresse mail de l'IC est correcte dans SalesForce"},
    {"key": "salesforce_chili", "phase": "access", "label": "SalesForce : vérif lien Chili dans welcome mail", "auto": False,
     "link": None, "description": "Vérifier que le lien Chili est présent dans le welcome mail (ping OPS sinon)"},
    {"key": "pennylane_connect_login", "phase": "access", "label": "Pennylane Connect : tentative connexion IC", "auto": False,
     "link": None, "description": "L'IC doit d'abord tenter de se connecter à Pennylane Connect"},
    {"key": "pennylane_connect_jira", "phase": "access", "label": "Pennylane Connect : ticket Jira accès étendu", "auto": False,
     "link": None, "description": "Créer un ticket Jira pour accès étendu aux clients Pennylane Connect"},
    {"key": "chift_jira", "phase": "access", "label": "Chift : ticket Jira", "auto": False,
     "link": None, "description": "Créer un ticket Jira pour l'accès Chift"},
    {"key": "dash_swan", "phase": "access", "label": "Dash SWAN : demande accès Vincent Jean Pierre", "auto": False,
     "link": None, "description": "Demander l'accès au Dash SWAN à Vincent Jean Pierre en MP"},
    {"key": "modjo_check", "phase": "access", "label": "Modjo : vérif team Onboarding", "auto": False,
     "link": None, "description": "Vérifier que l'IC est dans la team Onboarding dans Modjo (ping OPS sinon)"},
    {"key": "intercom_check", "phase": "access", "label": "Intercom : vérif team Onboarding", "auto": False,
     "link": None, "description": "Vérifier que l'IC est dans la team Onboarding dans Intercom (ping OPS sinon)"},
    {"key": "tresorit_check", "phase": "access", "label": "Trésorit : vérif dossier Equipe OB", "auto": False,
     "link": None, "description": "Vérifier que le dossier de l'IC est présent dans Equipe OB sur Trésorit"},
    {"key": "braga_chili", "phase": "access", "label": "Braga : donner liens Chili pour relances", "auto": False,
     "link": None, "description": "Donner les liens Chili à Braga pour les ajouter aux tâches de relances #relances-rdv-ob-braga"},

    # Phase: à l'arrivée (suite — ex "lors de l'arrivée")
    {"key": "restau_tl", "phase": "a_larrivee", "label": "Restau TL / newcomers (NDF 30€)", "auto": False,
     "link": None, "description": "Organiser le restaurant TL/newcomers, NDF 30€"},
    {"key": "sme_slots", "phase": "a_larrivee", "label": "Agenda SME : MàJ créneaux formation", "auto": False,
     "link": None, "description": "Mettre à jour les créneaux de formation SME (dupliquer créneaux M-1)"},
    {"key": "visio_decouverte", "phase": "a_larrivee", "label": "Prévoir visios découverte équipe CS", "auto": False,
     "link": None, "description": "Planifier les visios de découverte de l'équipe CS"},
    {"key": "shadow_cadrages", "phase": "a_larrivee", "label": "Shadow : créneaux cadrages équipe OB", "auto": False,
     "link": None, "description": "Demander à l'équipe OB les créneaux des prochains cadrages pour shadow"},
    {"key": "rdv_antonio", "phase": "a_larrivee", "label": "RDV Antonio (2ème mois)", "auto": False,
     "link": None, "description": "Prévoir RDV avec Antonio sur le 2nd mois"},
    {"key": "check_weekly", "phase": "a_larrivee", "label": "Vérif IC dans meet weekly, Café OB, #proservices", "auto": False,
     "link": None, "description": "Vérifier que l'IC est dans les meet weekly, Café OB et Slack Proservices"},
]

PHASE_LABELS = {
    "a_larrivee": "À l'arrivée",
    "access": "Accès",
}


def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_conn()
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS newcomers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            slack_handle TEXT,
            role TEXT,
            arrival_date TEXT,
            created_at TEXT DEFAULT (datetime('now')),
            notes TEXT
        );

        CREATE TABLE IF NOT EXISTS task_status (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            newcomer_id INTEGER NOT NULL,
            task_key TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            done_at TEXT,
            error_msg TEXT,
            FOREIGN KEY (newcomer_id) REFERENCES newcomers(id),
            UNIQUE(newcomer_id, task_key)
        );
    """)
    conn.commit()
    conn.close()


def create_newcomer(name, email, slack_handle, role, arrival_date, notes=""):
    conn = get_conn()
    cur = conn.execute(
        "INSERT INTO newcomers (name, email, slack_handle, role, arrival_date, notes) VALUES (?,?,?,?,?,?)",
        (name, email, slack_handle, role, arrival_date, notes)
    )
    newcomer_id = cur.lastrowid
    for task in TASKS_DEFINITION:
        conn.execute(
            "INSERT INTO task_status (newcomer_id, task_key, status) VALUES (?,?,'pending')",
            (newcomer_id, task["key"])
        )
    conn.commit()
    conn.close()
    return newcomer_id


def get_all_newcomers():
    conn = get_conn()
    rows = conn.execute("""
        SELECT n.*,
               COUNT(ts.id) as total_tasks,
               SUM(CASE WHEN ts.status='done' THEN 1 ELSE 0 END) as done_tasks
        FROM newcomers n
        LEFT JOIN task_status ts ON ts.newcomer_id = n.id
        GROUP BY n.id
        ORDER BY n.arrival_date DESC
    """).fetchall()
    conn.close()
    return rows


def get_newcomer(newcomer_id):
    conn = get_conn()
    row = conn.execute("SELECT * FROM newcomers WHERE id=?", (newcomer_id,)).fetchone()
    conn.close()
    return row


def get_tasks_for_newcomer(newcomer_id):
    conn = get_conn()
    rows = conn.execute(
        "SELECT * FROM task_status WHERE newcomer_id=?", (newcomer_id,)
    ).fetchall()
    conn.close()
    status_map = {r["task_key"]: dict(r) for r in rows}
    result = []
    for task in TASKS_DEFINITION:
        ts = status_map.get(task["key"], {"status": "pending", "done_at": None, "error_msg": None})
        result.append({**task, **ts})
    return result


def set_task_status(newcomer_id, task_key, status, error_msg=None):
    conn = get_conn()
    done_at = datetime.now().isoformat() if status == "done" else None
    conn.execute("""
        INSERT INTO task_status (newcomer_id, task_key, status, done_at, error_msg)
        VALUES (?,?,?,?,?)
        ON CONFLICT(newcomer_id, task_key) DO UPDATE SET
            status=excluded.status,
            done_at=excluded.done_at,
            error_msg=excluded.error_msg
    """, (newcomer_id, task_key, status, done_at, error_msg))
    conn.commit()
    conn.close()
