/* Contrôle du 16/09/2026 : les échelles à 3 niveaux du Livret d'intégration et de l'onglet
   « Mises en situation » (profil RS, supportRadioCol) doivent porter le même code couleur que
   l'onglet Acquis — Maîtrisé vert, Points à revoir ambre, Non maîtrisé rouge — et le tampon
   « validé par … » doit suivre le niveau retenu.
   Firebase est BLOQUÉ (réseau) : sans ça le test écrirait dans la vraie base de prod.
   Données de test : noms fictifs (le dépôt est public). */
import pkg from "/Users/mtabareau/node_modules/playwright-core/index.js";
const { chromium } = pkg;

const STORE_KEY = "newcomer_onboarding_v1";
const AT = "2026-09-16T09:00:00.000Z";
const niv = (who, val) => ({ [who]: val, [who + "By"]: "Test", [who + "At"]: AT });

const DATA = {
  seq: 3,
  newcomers: [
    { id: 1, name: "Fiche Test OB", email: "fiche.test@pennylane.com",
      arrival_date: "2026-09-14", role: "Consultant Fonctionnel Comptable",
      livret: { niveaux: {
        lv_g_param:        niv("auto", "maitrise"),
        lv_g_connect:      niv("auto", "a_revoir"),
        lv_g_achats:       niv("auto", "non_maitrise"),
        lv_g_ventes:       niv("mentor", "non_maitrise"),
      }, comments: {}, signatures: {} } },
    { id: 2, name: "Fiche Test RS", email: "fiche.rs@pennylane.com", profil: "RS",
      arrival_date: "2026-09-14", role: "Consultant Fonctionnel Comptable" },
  ],
  structure: {},
};

const ATTENDU = { maitrise: "vert", a_revoir: "ambre", non_maitrise: "rouge" };

async function ouvrir(browser, route) {
  const ctx = await browser.newContext();
  for (const p of ["**://*.gstatic.com/**", "**://*.firebasedatabase.app/**",
                   "**://*.googleapis.com/**", "**://*.firebaseio.com/**"]) {
    await ctx.route(p, r => r.abort());
  }
  const page = await ctx.newPage();
  await page.addInitScript(([k, d]) => {
    localStorage.setItem(k, d);
    localStorage.setItem("newcomer_onboarding_user", "Test");
  }, [STORE_KEY, JSON.stringify(DATA)]);
  await page.goto("file:///Users/mtabareau/newcomer-onboarding/docs/index.html" + route);
  await page.waitForTimeout(1400);
  return { ctx, page };
}

const browser = await chromium.launch();

/* ---------- 1. Livret d'intégration ---------- */
{
  const { ctx, page } = await ouvrir(browser, "#/newcomer/1/livret");
  const rows = await page.evaluate(() => {
    const nom = c => ({ "rgb(0, 189, 87)": "vert", "rgb(224, 155, 45)": "ambre",
                        "rgb(197, 48, 48)": "rouge" }[c] || c);
    const cas = [["lv_g_param", "auto", "maitrise"], ["lv_g_connect", "auto", "a_revoir"],
                 ["lv_g_achats", "auto", "non_maitrise"], ["lv_g_ventes", "mentor", "non_maitrise"]];
    return cas.map(([key, who, val]) => {
      const el = [...document.querySelectorAll("div[onclick]")].find(d =>
        d.getAttribute("onclick").includes(`toggleLivret`) &&
        d.getAttribute("onclick").includes(`'${key}'`) &&
        d.getAttribute("onclick").includes(`'${who}'`) &&
        d.getAttribute("onclick").includes(`'${val}'`));
      if (!el) return { key, who, val, absent: true };
      const box = el.querySelector("span");
      const lab = el.querySelectorAll("span")[1];
      // le tampon est le frère suivant du dernier niveau de la colonne
      const col = el.parentElement;
      const stamp = [...col.querySelectorAll("div")].find(d => /validé/.test(d.textContent));
      return { key, who, val,
        coche: nom(getComputedStyle(box).backgroundColor),
        libelle: nom(getComputedStyle(lab).color),
        tampon: stamp ? nom(getComputedStyle(stamp).color) : "(absent)" };
    });
  });
  console.log("LIVRET D'INTÉGRATION");
  let ok = true;
  for (const r of rows) {
    const att = ATTENDU[r.val];
    const bon = !r.absent && r.coche === att && r.libelle === att && r.tampon === att;
    if (!bon) ok = false;
    console.log(`  ${bon ? "✅" : "❌"} ${r.key.padEnd(16)} ${String(r.who).padEnd(7)} ${r.val.padEnd(13)}` +
      (r.absent ? " INTROUVABLE" : ` coche=${r.coche} libellé=${r.libelle} tampon=${r.tampon} (attendu ${att})`));
  }
  console.log(`  → ${ok ? "les 3 niveaux se distinguent" : "ÉCART"}\n`);
  await ctx.close();
}

/* ---------- 2. Mises en situation (profil RS) ---------- */
{
  const { ctx, page } = await ouvrir(browser, "#/newcomer/2/supports");
  const res = await page.evaluate(() => {
    const nom = c => ({ "rgb(0, 189, 87)": "vert", "rgb(224, 155, 45)": "ambre",
                        "rgb(197, 48, 48)": "rouge" }[c] || c);
    const lignes = [...document.querySelectorAll("div[onclick]")]
      .filter(d => d.getAttribute("onclick").includes("toggleSupport"));
    if (!lignes.length) return { vide: true };
    const cle = lignes[0].getAttribute("onclick").match(/'([^']+)'/)[1];
    const out = {};
    // on clique chaque niveau à tour de rôle et on relit la couleur de la coche sélectionnée
    for (const val of ["maitrise", "a_revoir", "non_maitrise"]) {
      const el = [...document.querySelectorAll("div[onclick]")].find(d => {
        const o = d.getAttribute("onclick");
        return o.includes("toggleSupport") && o.includes(`'${cle}'`) && o.includes(`'${val}'`);
      });
      el.click();
      const apres = [...document.querySelectorAll("div[onclick]")].find(d => {
        const o = d.getAttribute("onclick");
        return o.includes("toggleSupport") && o.includes(`'${cle}'`) && o.includes(`'${val}'`);
      });
      const box = apres.querySelector("span");
      out[val] = { coche: nom(getComputedStyle(box).backgroundColor),
                   selectionne: /✓/.test(box.textContent),
                   stocke: (JSON.parse(localStorage.getItem("newcomer_onboarding_v1"))
                     .newcomers.find(n => n.id === 2).autoformation || {}).niveaux || {} };
    }
    return { cle, out };
  });
  console.log("MISES EN SITUATION (profil RS, supportRadioCol)");
  if (res.vide) console.log("  ⚠️ aucune ligne à 3 niveaux rendue sur cet onglet");
  else for (const [val, r] of Object.entries(res.out)) {
    console.log(`  ${r.selectionne ? "✅" : "❌"} ${val.padEnd(13)} coche=${r.coche} sélectionnée=${r.selectionne ? "oui" : "NON"} (attendu ${ATTENDU[val]})`);
    console.log(`     stocké : ${JSON.stringify(r.stocke[res.cle] || null)}`);
  }
  await ctx.close();
}

await browser.close();
