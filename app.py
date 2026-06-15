from flask import Flask, render_template, request, redirect, url_for, flash, jsonify
from models import (
    init_db, create_newcomer, get_all_newcomers, get_newcomer,
    get_tasks_for_newcomer, set_task_status, TASKS_DEFINITION, PHASE_LABELS
)
from slack_service import run_slack_tasks, send_swan_request, send_braga_message, chili_link

app = Flask(__name__)
app.secret_key = "newcomer-onboarding-secret"

init_db()


@app.route("/")
def index():
    newcomers = get_all_newcomers()
    return render_template("index.html", newcomers=newcomers)


@app.route("/new", methods=["GET", "POST"])
def new_newcomer():
    if request.method == "POST":
        name = request.form["name"].strip()
        email = request.form["email"].strip()
        slack_handle = request.form.get("slack_handle", "").strip()
        role = request.form.get("role", "").strip()
        arrival_date = request.form.get("arrival_date", "").strip()
        notes = request.form.get("notes", "").strip()

        if not name or not email:
            flash("Nom et email obligatoires.", "error")
            return render_template("new.html")

        newcomer_id = create_newcomer(name, email, slack_handle, role, arrival_date, notes)
        flash(f"Newcomer {name} créé avec succès !", "success")
        return redirect(url_for("newcomer_detail", newcomer_id=newcomer_id))

    return render_template("new.html")


@app.route("/newcomer/<int:newcomer_id>")
def newcomer_detail(newcomer_id):
    newcomer = get_newcomer(newcomer_id)
    if not newcomer:
        flash("Newcomer introuvable.", "error")
        return redirect(url_for("index"))

    tasks = get_tasks_for_newcomer(newcomer_id)

    phases = {}
    for phase_key, phase_label in PHASE_LABELS.items():
        phase_tasks = [t for t in tasks if t["phase"] == phase_key]
        done = sum(1 for t in phase_tasks if t["status"] == "done")
        phases[phase_key] = {
            "label": phase_label,
            "tasks": phase_tasks,
            "done": done,
            "total": len(phase_tasks),
        }

    total_done = sum(1 for t in tasks if t["status"] == "done")
    total = len(tasks)

    return render_template(
        "detail.html",
        newcomer=newcomer,
        phases=phases,
        total_done=total_done,
        total=total,
    )


@app.route("/newcomer/<int:newcomer_id>/launch-slack", methods=["POST"])
def launch_slack(newcomer_id):
    newcomer = get_newcomer(newcomer_id)
    if not newcomer:
        return jsonify({"error": "Newcomer introuvable"}), 404

    results = run_slack_tasks(newcomer["email"])

    summary = []
    for task_key, (success, error) in results.items():
        status = "done" if success else "error"
        set_task_status(newcomer_id, task_key, status, error_msg=error if not success else None)
        summary.append({
            "task_key": task_key,
            "success": success,
            "error": error,
        })

    return jsonify({"results": summary})


@app.route("/newcomer/<int:newcomer_id>/task/<task_key>/toggle", methods=["POST"])
def toggle_task(newcomer_id, task_key):
    tasks = get_tasks_for_newcomer(newcomer_id)
    current = next((t for t in tasks if t["key"] == task_key), None)
    if not current:
        return jsonify({"error": "Tâche introuvable"}), 404

    new_status = "pending" if current["status"] == "done" else "done"
    set_task_status(newcomer_id, task_key, new_status)
    return jsonify({"status": new_status})


@app.route("/newcomer/<int:newcomer_id>/send-swan-dm", methods=["POST"])
def send_swan_dm(newcomer_id):
    newcomer = get_newcomer(newcomer_id)
    if not newcomer:
        return jsonify({"error": "Newcomer introuvable"}), 404
    success, error = send_swan_request(newcomer["name"], newcomer["role"])
    if success:
        set_task_status(newcomer_id, "dash_swan", "done")
    return jsonify({"success": success, "error": error})


@app.route("/newcomer/<int:newcomer_id>/send-braga", methods=["POST"])
def send_braga(newcomer_id):
    newcomer = get_newcomer(newcomer_id)
    if not newcomer:
        return jsonify({"error": "Newcomer introuvable"}), 404
    success, error = send_braga_message(newcomer["name"], newcomer["role"])
    if success:
        set_task_status(newcomer_id, "braga_chili", "done")
    return jsonify({"success": success, "error": error, "chili_link": chili_link(newcomer["name"])})


@app.route("/newcomer/<int:newcomer_id>/notes", methods=["POST"])
def save_notes(newcomer_id):
    import sqlite3
    from models import get_conn
    notes = request.form.get("notes", "")
    conn = get_conn()
    conn.execute("UPDATE newcomers SET notes=? WHERE id=?", (notes, newcomer_id))
    conn.commit()
    conn.close()
    flash("Notes sauvegardées.", "success")
    return redirect(url_for("newcomer_detail", newcomer_id=newcomer_id))


if __name__ == "__main__":
    import os
    init_db()
    port = int(os.environ.get("PORT", 8081))
    app.run(debug=os.environ.get("FLASK_ENV") != "production", host="0.0.0.0", port=port)
