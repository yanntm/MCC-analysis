// The browser side of a total examination page: DATA holds sets, summary,
// pairs, runs (one per instance, a record per set) and families (see
// totals.py). Filtering and rendering only. Two sets A and B are compared
// throughout, as on the examination pages.
const sets = DATA.sets;
let A = sets[0], B = sets.length > 1 ? sets[1] : sets[0];
function fmt(x, d) { return x === null || x === undefined ? "" : (d !== undefined && typeof x === "number" ? x.toFixed(d) : x); }
function logLink(s) { return s && s.log ? ` <a class="log" href="logs${s.log}" target="_blank">log</a>` : ""; }
function fillSelect(id, value) {
  const sel = document.getElementById(id);
  sel.innerHTML = sets.map(s => `<option${s === value ? " selected" : ""}>${s}</option>`).join("");
  sel.onchange = () => { if (id === "setA") A = sel.value; else B = sel.value; redraw(); };
}

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
      h += `<td class="pick" data-a="${a}" data-b="${b}" title="compare these two">${p.shared || 0} runs: ${p.both || 0} / <span class="bonus">${p.onlyA || 0}</span> / <span class="missed">${p.onlyB || 0}</span> / <span class="wrong">${p.disagree || 0}</span></td>`;
    }
    h += "</tr>";
  }
  document.getElementById("pairs").innerHTML = h + "</table>";
  for (const td of document.querySelectorAll("#pairs td.pick")) td.onclick = () => { A = td.dataset.a; B = td.dataset.b; fillSelect("setA", A); fillSelect("setB", B); redraw(); };
}

// One line per set along the instances of a family; wall time by default, where two runs always differ.
function progression() {
  const fam = document.getElementById("family").value;
  const y = document.getElementById("yaxis").value;
  const f = DATA.families.find(x => x.family === fam);
  if (!f) return;
  const byModel = Object.fromEntries(DATA.runs.map(r => [r.model, r]));
  const traces = sets.map((s, i) => ({
    name: s, type: "scatter", mode: "lines+markers", marker: { symbol: i, size: 8 }, line: { dash: i % 2 ? "dot" : "solid" },
    x: f.instances, y: f.instances.map(m => { const x = (byModel[m].sets || {})[s]; return x ? x[y] : null; }),
    text: f.instances.map(m => { const x = (byModel[m].sets || {})[s]; return x ? `${s}<br>${m}: ${x.answered}/${x.atoms} in ${fmt(x.time, 0)} s, ${x.status}` : m; }),
    hoverinfo: "text"
  }));
  Plotly.newPlot("progression", traces, { xaxis: { type: "category", tickangle: -45 }, yaxis: { title: y, rangemode: "tozero", type: y === "time" ? "log" : "linear" }, margin: { t: 20, b: 140 }, legend: { orientation: "h" } });
}

// A against B on the shared instances: wall time (log-log) and atoms answered (log-log), the diagonal as the tie.
function abScatter(id, key, unit) {
  const xs = [], ys = [], txt = [], col = [];
  for (const r of DATA.runs) {
    const a = r.sets[A], b = r.sets[B];
    if (!a || !b || a[key] === null || b[key] === null) continue;
    xs.push(Math.max(a[key], 0.1)); ys.push(Math.max(b[key], 0.1));
    txt.push(`${r.model}: ${A} ${a.answered}/${a.atoms} in ${fmt(a.time, 0)} s (${a.status}), ${B} ${b.answered}/${b.atoms} in ${fmt(b.time, 0)} s (${b.status})`);
    col.push(a.answered > b.answered ? "#2a2" : a.answered < b.answered ? "#c22" : "#888");
  }
  const lim = [0.1, Math.max(...xs, ...ys, 1) * 1.5];
  Plotly.newPlot(id, [
    { x: xs, y: ys, text: txt, mode: "markers", type: "scatter", marker: { size: 6, color: col, opacity: .7 }, hoverinfo: "text" },
    { x: lim, y: lim, mode: "lines", line: { color: "#aaa", dash: "dot" }, hoverinfo: "skip" }],
    { xaxis: { title: `${A} ${unit}`, type: "log" }, yaxis: { title: `${B} ${unit}`, type: "log" }, margin: { t: 30 }, showlegend: false,
      annotations: [{ text: "green: A answered more, red: B answered more, grey: the same", showarrow: false, x: 0, y: 1.06, xref: "paper", yref: "paper" }] });
}

// Answered against atoms for set A: the diagonal is completion, the distance below it what is left.
function completionScatter() {
  const xs = [], ys = [], txt = [], col = [];
  for (const r of DATA.runs) {
    const x = r.sets[A];
    if (!x || !x.atoms) continue;
    xs.push(x.atoms); ys.push(Math.max(x.answered, 0.5)); txt.push(`${r.model} ${x.answered}/${x.atoms} in ${fmt(x.time, 0)} s, ${x.status}`);
    col.push(x.status === "timeout" ? "#c22" : x.status === "finished" ? "#2a2" : "#888");
  }
  const lim = [1, Math.max(...xs, 1) * 1.5];
  Plotly.newPlot("completion", [
    { x: xs, y: ys, text: txt, mode: "markers", type: "scatter", marker: { size: 6, color: col, opacity: .7 }, hoverinfo: "text" },
    { x: lim, y: lim, mode: "lines", line: { color: "#aaa", dash: "dot" }, hoverinfo: "skip" }],
    { xaxis: { title: `${A}: atoms of the instance`, type: "log" }, yaxis: { title: "atoms answered", type: "log" }, margin: { t: 30 }, showlegend: false });
}

let runTable = null;
function runsTable() {
  const re = new RegExp(document.getElementById("famFilter").value || ".", "i");
  const mode = document.getElementById("runMode").value;
  const rows = DATA.runs.filter(r => re.test(r.model)).filter(r => {
    const x = r.sets[A], b = r.sets[B];
    if (mode === "all") return true;
    if (mode === "differ") return x && b && x.answered !== b.answered;
    if (mode === "aBetter") return x && b && x.answered > b.answered;
    if (mode === "bBetter") return x && b && x.answered < b.answered;
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

function redraw() { abScatter("timeScatter", "time", "wall time (s)"); abScatter("answeredScatter", "answered", "atoms answered"); completionScatter(); runsTable(); }

function fillSelects() {
  const fs = document.getElementById("family");
  fs.innerHTML = DATA.families.map(f => `<option>${f.family}</option>`).join("");
  fs.onchange = progression;
  document.getElementById("yaxis").onchange = progression;
  fillSelect("setA", A); fillSelect("setB", B);
  document.getElementById("famFilter").oninput = runsTable;
  document.getElementById("runMode").onchange = runsTable;
}

fillSelects(); summaryTable(); pairsTable(); progression(); redraw();
