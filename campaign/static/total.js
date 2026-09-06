// The browser side of a total examination page: DATA holds sets, summary,
// pairs, runs (one per instance, a record per set) and families (see
// totals.py). Filtering and rendering only.
const sets = DATA.sets;
let A = sets[0];
function fmt(x, d) { return x === null || x === undefined ? "" : (d !== undefined && typeof x === "number" ? x.toFixed(d) : x); }
function logLink(s) { return s && s.log ? ` <a class="log" href="logs${s.log}" target="_blank">log</a>` : ""; }
function natural(a, b) { return a.localeCompare(b, undefined, { numeric: true }); }

function summaryTable() {
  const cols = ["set", "runs", "atoms", "answered", "completion", "complete", "timeouts", "failures", "witnessed", "proved", "open bounds", "confirmed", "contradicted", "engines", "total h", "walker h"];
  $("#summary").DataTable({ data: DATA.summary.map(r => cols.map(c => fmt(r[c]))), columns: cols.map(c => ({ title: c })), paging: false, searching: false, info: false, ordering: false });
}

function pairsTable() {
  let h = "<table class='plain'><tr><th>A \\ B</th>" + sets.map(s => `<th>${s}</th>`).join("") + "</tr>";
  for (const a of sets) {
    h += `<tr><td>${a}</td>`;
    for (const b of sets) {
      if (a === b) { h += "<td>-</td>"; continue; }
      const p = DATA.pairs[`${a}|${b}`] || {};
      h += `<td>${p.shared || 0} runs: ${p.both || 0} / <span class="bonus">${p.onlyA || 0}</span> / <span class="missed">${p.onlyB || 0}</span> / <span class="wrong">${p.disagree || 0}</span></td>`;
    }
    h += "</tr>";
  }
  document.getElementById("pairs").innerHTML = h + "</table>";
}

function progression() {
  const fam = document.getElementById("family").value;
  const y = document.getElementById("yaxis").value;
  const f = DATA.families.find(x => x.family === fam);
  if (!f) return;
  const byModel = Object.fromEntries(DATA.runs.map(r => [r.model, r]));
  const traces = sets.map(s => ({
    name: s, type: "scatter", mode: "lines+markers",
    x: f.instances, y: f.instances.map(m => { const x = (byModel[m].sets || {})[s]; return x ? x[y] : null; }),
    text: f.instances.map(m => { const x = (byModel[m].sets || {})[s]; return x ? `${m}: ${x.answered}/${x.atoms} in ${fmt(x.time, 0)} s, ${x.status}` : m; }),
    hoverinfo: "text+y"
  }));
  Plotly.newPlot("progression", traces, { xaxis: { type: "category", tickangle: -45 }, yaxis: { title: y, rangemode: "tozero" }, margin: { t: 20, b: 140 }, legend: { orientation: "h" } });
}

function scatter() {
  const xs = [], ys = [], txt = [], col = [], size = [];
  for (const r of DATA.runs) {
    const x = r.sets[A];
    if (!x || x.time === null) continue;
    xs.push(Math.max(x.time, 0.1)); ys.push(x.completion); txt.push(`${r.model} ${x.answered}/${x.atoms}, ${x.status}`);
    col.push(x["walk calls"] > 0 ? "#2a2" : "#c22"); size.push(4 + 2 * Math.log10(1 + x.atoms));
  }
  Plotly.newPlot("scatter", [{ x: xs, y: ys, text: txt, mode: "markers", type: "scatter", marker: { size, color: col, opacity: .6 }, hoverinfo: "text" }],
    { xaxis: { title: `${A} wall time (s)`, type: "log" }, yaxis: { title: "completion", range: [-0.02, 1.02] }, margin: { t: 20 } });
}

let runTable = null;
function runsTable() {
  const re = new RegExp(document.getElementById("famFilter").value || ".", "i");
  const mode = document.getElementById("runMode").value;
  const rows = DATA.runs.filter(r => re.test(r.model)).filter(r => {
    const x = r.sets[A];
    if (mode === "all") return true;
    if (!x) return false;
    if (mode === "incomplete") return x.completion < 1;
    if (mode === "wall") return x.status === "timeout";
    if (mode === "nowalk") return x.status === "timeout" && x["walk calls"] === 0;
    if (mode === "contradiction") return x.check === "CONTRADICTION";
    if (mode === "early") return x.completion < 1 && x.status !== "timeout";
    return true;
  });
  const cols = [{ title: "instance" }, { title: "atoms" }];
  for (const s of sets) cols.push({ title: `${s} answered` }, { title: "completion" }, { title: "s" }, { title: "status" }, { title: "walk calls / s" }, { title: "t25 / t50 / t75 / t100 s" }, { title: "engines" }, { title: "check" }, { title: "last activity" });
  const data = rows.map(r => {
    const out = [r.model, r.atoms];
    for (const s of sets) {
      const x = r.sets[s];
      if (!x) { out.push("", "", "", "", "", "", "", "", ""); continue; }
      out.push(`${x.answered}${logLink(x)}`, fmt(x.completion, 3), fmt(x.time, 0), x.status,
        `${x["walk calls"]} / ${fmt(x["walk s"], 0)}`, [x.t25, x.t50, x.t75, x.t100].map(v => fmt(v, 0)).join(" / "),
        Object.entries(x.engines).filter(([k, v]) => v).map(([k, v]) => `${k} ${v}`).join(" "),
        `<span class="${x.check === "CONTRADICTION" ? "wrong" : ""}">${x.check || ""}</span>`, (x.last || "").slice(0, 50));
    }
    return out;
  });
  if (runTable) { runTable.clear().rows.add(data).draw(); return; }
  runTable = $("#runs").DataTable({ data, columns: cols, pageLength: 25, deferRender: true });
}

function fillSelects() {
  const fs = document.getElementById("family");
  fs.innerHTML = DATA.families.map(f => `<option>${f.family}</option>`).join("");
  fs.onchange = progression;
  document.getElementById("yaxis").onchange = progression;
  const sa = document.getElementById("setA");
  sa.innerHTML = sets.map(s => `<option>${s}</option>`).join("");
  sa.onchange = () => { A = sa.value; scatter(); runsTable(); };
  document.getElementById("famFilter").oninput = runsTable;
  document.getElementById("runMode").onchange = runsTable;
}

fillSelects(); summaryTable(); pairsTable(); progression(); scatter(); runsTable();
