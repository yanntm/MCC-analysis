// The browser side of an examination page: DATA holds sets, summary, pairs,
// instances and values (see crossref.py). Everything below is filtering and
// rendering; nothing is computed that the Python side did not already decide.
const sets = DATA.sets;
let A = sets[0], B = sets.length > 1 ? sets[1] : sets[0];
let pairFilter = null;

function fmt(x) { return x === null || x === undefined ? "" : x; }
// logs are served by serve.py under /logs/<absolute path>; a file:// link would not cross the tunnel
function logLink(s) { return s && s.log ? ` <a class="log" href="logs${s.log}" target="_blank">log</a>` : ""; }

function fillSelect(id, value) {
  const sel = document.getElementById(id);
  if (!sel) return;
  sel.innerHTML = sets.map(s => `<option ${s === value ? "selected" : ""}>${s}</option>`).join("");
  sel.onchange = () => { if (id === "setA" || id === "valSetA") A = sel.value; else B = sel.value; pairFilter = null; redraw(); };
}

function summaryTable() {
  const cols = ["set", "runs", "answered", "ok", "wrong", "missed", "bonus", "timeouts", "failures", "median s", "total h"];
  $("#summary").DataTable({ data: DATA.summary.map(r => cols.map(c => fmt(r[c]))), columns: cols.map(c => ({ title: c })),
    paging: false, searching: false, info: false, order: [[3, "desc"]] });
}

function pairsTable() {
  let h = "<table class='plain'><tr><th>A \\ B</th>" + sets.map(s => `<th>${s}</th>`).join("") + "</tr>";
  for (const a of sets) {
    h += `<tr><td>${a}</td>`;
    for (const b of sets) {
      if (a === b) { h += "<td>-</td>"; continue; }
      const p = DATA.pairs[`${a}|${b}`] || {};
      h += `<td data-a="${a}" data-b="${b}">${p.both || 0} / <span class="bonus">${p.onlyA || 0}</span> / <span class="missed">${p.onlyB || 0}</span> / <span class="wrong">${p.disagree || 0}</span></td>`;
    }
    h += "</tr>";
  }
  document.getElementById("pairs").innerHTML = h + "</table>";
  document.querySelectorAll("#pairs td[data-a]").forEach(td => td.onclick = () => {
    A = td.dataset.a; B = td.dataset.b; fillSelect("setA", A); fillSelect("setB", B);
    document.getElementById("valMode").value = "disagree"; redraw();
  });
}

let instTable = null, valTable = null;

function instanceRows() {
  const re = new RegExp(document.getElementById("famFilter").value || ".", "i");
  const mode = document.getElementById("instMode").value;
  return DATA.instances.filter(r => re.test(r.model)).filter(r => {
    const a = r.sets[A] || {}, b = r.sets[B] || {};
    if (mode === "lt") return (a.answered || 0) < (b.answered || 0);
    if (mode === "gt") return (a.answered || 0) > (b.answered || 0);
    if (mode === "wrong") return Object.values(r.sets).some(s => s.wrong > 0);
    if (mode === "timeout") return a.status === "timeout";
    return true;
  });
}

function instancesTable() {
  const rows = instanceRows();
  const cols = [{ title: "instance" }, { title: "formulas" }, { title: "known" }];
  for (const s of sets) cols.push({ title: `${s} answered/ok` }, { title: `${s} s` });
  const data = rows.map(r => {
    const out = [r.model, r.formulas, r.known];
    for (const s of sets) {
      const x = r.sets[s] || {};
      const cls = x.wrong ? "wrong" : "";
      out.push(`<span class="${cls}">${fmt(x.answered)}/${fmt(x.ok)}</span>${x.status && x.status !== "finished" ? ` <i>${x.status}</i>` : ""}${logLink(x)}`);
      out.push(x.time === null || x.time === undefined ? "" : x.time.toFixed(1));
    }
    return out;
  });
  if (instTable) { instTable.clear().rows.add(data).draw(); return; }
  instTable = $("#instances").DataTable({ data, columns: cols, pageLength: 25, order: [[0, "asc"]] });
}

function scatter() {
  const xs = [], ys = [], txt = [], col = [];
  for (const r of DATA.instances) {
    const a = r.sets[A], b = r.sets[B];
    if (!a || !b || a.time === null || b.time === null) continue;
    xs.push(Math.max(a.time, 0.1)); ys.push(Math.max(b.time, 0.1)); txt.push(`${r.model} (${a.answered} vs ${b.answered})`);
    col.push(a.answered > b.answered ? "#2a2" : a.answered < b.answered ? "#c22" : "#888");
  }
  const lim = [0.1, Math.max(...xs, ...ys, 1) * 1.5];
  Plotly.newPlot("scatter", [
    { x: xs, y: ys, text: txt, mode: "markers", type: "scatter", marker: { size: 6, color: col, opacity: .7 }, hoverinfo: "text" },
    { x: lim, y: lim, mode: "lines", line: { color: "#aaa", dash: "dot" }, hoverinfo: "skip" }],
    { xaxis: { title: `${A} (s)`, type: "log" }, yaxis: { title: `${B} (s)`, type: "log" }, margin: { t: 20 }, showlegend: false,
      annotations: [{ text: "green: A answered more, red: B answered more", showarrow: false, x: 0, y: 1.05, xref: "paper", yref: "paper" }] });
}

function valueRows() {
  const mode = document.getElementById("valMode").value;
  const re = new RegExp(document.getElementById("famFilter").value || ".", "i");
  const instances = new Map(DATA.instances.map(r => [r.model, r.sets]));
  return DATA.values.filter(r => re.test(r.model)).filter(r => {
    const a = r.vals[A] || [null, "none"], b = r.vals[B] || [null, "none"];
    const runs = instances.get(r.model) || {};
    if (mode === "beatsA") return (runs[A]?.ok || 0) > (runs[B]?.ok || 0);
    if (mode === "beatsB") return (runs[B]?.ok || 0) > (runs[A]?.ok || 0);
    if (mode === "wrongAny") return Object.values(r.vals).some(v => v[1] === "wrong");
    if (mode === "wrongB") return b[1] === "wrong";
    if (mode === "timeoutA") return runs[A]?.status === "timeout";
    if (mode === "disagree") return a[0] !== null && b[0] !== null && a[0] !== b[0] && !(Math.abs(a[0] - b[0]) <= 1e-3 * Math.max(Math.abs(a[0]), Math.abs(b[0])));
    if (mode === "onlyA") return a[0] !== null && b[0] === null;
    if (mode === "onlyB") return a[0] === null && b[0] !== null;
    if (mode === "wrongA") return a[1] === "wrong";
    if (mode === "missedA") return a[1] === "missed";
    if (mode === "bonusA") return a[1] === "bonus";
    return true;
  });
}

function htmlText(value) {
  return String(value).replace(/[&<>"']/g, c => ({"&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;"}[c]));
}

function compactCount(value) {
  if (value === null || value === undefined) return "·";
  const text = String(value);
  if (!/^\d+$/.test(text)) return htmlText(text);
  const digits = text.replace(/^0+(?=\d)/, "");
  if (digits.length <= 6) return digits;
  let exponent = digits.length - 1;
  let leading = Number(digits.slice(0, 6)) + (digits[6] >= "5" ? 1 : 0);
  if (leading === 1000000) { leading = 100000; exponent++; }
  const mantissa = String(leading);
  return `≈${mantissa[0]}.${mantissa.slice(1)} × 10<sup>${exponent}</sup>`;
}

function metricStatus(row, tool, run) {
  const [value, status] = row?.vals[tool] || [null, "none"];
  const label = status === "ok" ? "✓" : status === "wrong" ? "✗" : status === "bonus" ? "+" : "?";
  const detail = value !== null ? `${tool}: ${value} (${status})` :
    `${tool}: ${run?.status ? "no answer; " + run.status : "no collected run"}`;
  const title = htmlText(detail);
  const mark = `<span class="metric-status ${status}" title="${title}" aria-label="${title}">${label}</span>`;
  return run?.log ? `<a href="/logs${encodeURI(run.log)}" target="_blank" title="${title}; open log">${mark}</a>` : mark;
}

function stateSpaceValuesTable() {
  const metrics = [["STATES", "States"], ["TRANSITIONS", "Transitions"],
    ["MAX_TOKEN_IN_PLACE", "Max/place"], ["MAX_TOKEN_PER_MARKING", "Max/marking"]];
  const selected = new Set(valueRows().map(r => r.model));
  const instances = new Map(DATA.instances.map(r => [r.model, r.sets]));
  const models = new Map();
  for (const r of DATA.values) {
    if (!selected.has(r.model)) continue;
    if (!models.has(r.model)) models.set(r.model, new Map());
    models.get(r.model).set(r.name, r);
  }
  const data = [...models].map(([model, values]) => [htmlText(model), ...metrics.flatMap(([metric]) => {
    const r = values.get(metric);
    const title = r ? `Oracle: ${r.cons ?? "unknown"}; backed by ${r.who.join(", ") || "unspecified"}` : "No oracle value";
    return [`<span title="${htmlText(title)}">${compactCount(r?.cons)}</span>`,
      metricStatus(r, A, instances.get(model)?.[A]), metricStatus(r, B, instances.get(model)?.[B])];
  })]);
  if (valTable) { valTable.clear().rows.add(data).draw(); return; }
  valTable = $("#values").DataTable({ data,
    columns: [{ title: "Model", width: "24%" }, ...metrics.flatMap(([, title]) => [
      { title: `${title}<br><small>oracle</small>`, width: "12%" },
      { title: "A", width: "3.5%", orderable: false }, { title: "B", width: "3.5%", orderable: false }])],
    autoWidth: false, pageLength: 25, deferRender: true, order: [[0, "asc"]] });
}

function valuesTable() {
  if (DATA.examination === "StateSpace") return stateSpaceValuesTable();
  const rows = valueRows();
  const cols = [{ title: "formula" }, { title: "consensus" }, { title: "backed by" }];
  for (const s of sets) cols.push({ title: s });
  const data = rows.map(r => {
    const out = [r.name, fmt(r.cons), r.who.join(" ")];
    for (const s of sets) { const v = r.vals[s] || [null, "none"]; out.push(`<span class="${v[1]}">${v[0] === null ? "·" : v[0]}</span>`); }
    return out;
  });
  if (valTable) { valTable.clear().rows.add(data).draw(); return; }
  valTable = $("#values").DataTable({ data, columns: cols, pageLength: 25, deferRender: true });
}

function redraw() {
  for (const id of ["setA", "valSetA"]) fillSelect(id, A);
  for (const id of ["setB", "valSetB"]) fillSelect(id, B);
  instancesTable(); scatter(); valuesTable();
}

fillSelect("setA", A); fillSelect("setB", B);
summaryTable(); pairsTable(); redraw();
document.getElementById("famFilter").oninput = () => {
  const local = document.getElementById("valFamily");
  if (local) local.value = document.getElementById("famFilter").value;
  redraw();
};
const valFamily = document.getElementById("valFamily");
if (valFamily) valFamily.oninput = () => {
  document.getElementById("famFilter").value = valFamily.value;
  redraw();
};
document.getElementById("instMode").onchange = redraw;
document.getElementById("valMode").onchange = redraw;
