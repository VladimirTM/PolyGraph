// PolyGraph · graful terapeutic (B6), folosit de pagina farmacistului și de WKWebView-ul din aplicație (A3).
// Culorile vin din variabilele CSS, deci urmează light / dark / contrast mare ca restul paginii.
(function () {
  "use strict";

  var container = document.getElementById("graph");
  var dataEl = document.getElementById("graph-data");
  if (!container || !dataEl || typeof cytoscape !== "function") return;

  var data = JSON.parse(dataEl.textContent);
  var embed = document.body.classList.contains("embed");
  var page = document.body.classList.contains("page");
  var RING = { product: 2 };

  // Pentru citire, un medicament cu o singură substanță se desenează ca un singur nod: interacțiunile (care în date
  // leagă substanțe) ajung direct între medicamente. Nodul pacientului și clasele ATC rămân în date, dar nu se desenează:
  // pacientul ar sta în centru, exact unde se intersectează muchiile dintre medicamente opuse.
  function simplify(g) {
    var owners = {}, count = {};
    g.edges.forEach(function (e) {
      if (e.data.type !== "contains") return;
      (owners[e.data.target] = owners[e.data.target] || []).push(e.data.source);
      count[e.data.source] = (count[e.data.source] || 0) + 1;
    });
    var alias = {};
    Object.keys(owners).forEach(function (sub) {
      var o = owners[sub];
      if (o.length === 1 && count[o[0]] === 1) alias[sub] = o[0];
    });
    var nodes = g.nodes.filter(function (n) { return n.data.type !== "atc_class" && n.data.type !== "patient" && !alias[n.data.id]; });
    var keep = {};
    nodes.forEach(function (n) { keep[n.data.id] = true; });
    var edges = [];
    g.edges.forEach(function (e) {
      var d = Object.assign({}, e.data);
      d.source = alias[d.source] || d.source;
      d.target = alias[d.target] || d.target;
      if (d.source !== d.target && keep[d.source] && keep[d.target]) edges.push({ data: d });
    });
    return { nodes: nodes, edges: edges };
  }

  function css(name) {
    return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  }

  function sevColor(sev) {
    return css("--sev-" + (sev || "minor")) || css("--sev-minor");
  }

  function style() {
    var text = css("--text"), text2 = css("--text-2"), surface = css("--surface");
    var accent = css("--accent"), onAccent = css("--on-accent"), line = css("--line");
    var font = '-apple-system, system-ui, "Segoe UI", Roboto, sans-serif';
    return [
      { selector: "node", style: {
        "label": "data(label)", "font-family": font, "font-size": 11, "color": text2,
        "text-valign": "bottom", "text-margin-y": 4, "text-wrap": "wrap", "text-max-width": 110,
        "background-color": text2, "width": 10, "height": 10 } },
      { selector: "node[type = 'patient']", style: {
        "background-color": accent, "color": onAccent, "width": 54, "height": 54,
        "text-valign": "center", "text-margin-y": 0, "font-size": 13, "font-weight": 700 } },
      { selector: "node[type = 'product']", style: {
        "shape": "round-rectangle", "background-color": surface, "border-width": 1.5, "border-color": line,
        "width": function (n) { return Math.min(150, Math.max(60, n.data("label").length * 7.2)); }, "height": 30, "padding": 10, "color": text, "font-size": 13, "font-weight": 600,
        "text-valign": "center", "text-margin-y": 0, "text-max-width": 140 } },
      { selector: "node[type = 'product'][severity = 'critical'], node[type = 'product'][severity = 'major']",
        style: { "border-color": sevColor("major"), "border-width": 2.5 } },
      { selector: "node[type = 'product'][severity = 'moderate']",
        style: { "border-color": sevColor("moderate"), "border-width": 2 } },
      { selector: "node[type = 'substance']", style: { "width": 12, "height": 12, "background-color": text2 } },
      { selector: "node[type = 'atc_class']", style: {
        "shape": "diamond", "width": 9, "height": 9, "background-color": line, "font-size": 9 } },
      { selector: "node[type = 'food']", style: {
        "shape": "tag", "width": 14, "height": 14, "background-color": sevColor("moderate") } },
      { selector: "node[type = 'symptom']", style: {
        "shape": "star", "width": 16, "height": 16, "background-color": sevColor("info") } },
      { selector: "edge", style: {
        "width": 1, "line-color": line, "curve-style": "bezier", "opacity": 0.9 } },
      { selector: "edge[type = 'takes']", style: { "opacity": 0.35 } },
      { selector: "edge[type = 'interacts'], edge[type = 'food_interaction'], edge[type = 'reported'], edge[type = 'possibly_related']",
        style: { "line-color": function (e) { return sevColor(e.data("severity")); }, "width": 2.5 } },
      { selector: "edge[severity = 'critical'], edge[severity = 'major']", style: { "width": 4 } },
      { selector: "edge[severity = 'minor']", style: { "width": 1.5 } },
      { selector: "edge[type = 'food_interaction']", style: { "line-style": "dashed" } },
      { selector: "edge[alert_id]", style: { "overlay-padding": 8 } },
      { selector: ":selected", style: { "overlay-color": accent, "overlay-opacity": 0.15 } },
    ];
  }

  var cy = cytoscape({
    container: container,
    elements: simplify(data),
    style: style(),
    layout: {
      name: "concentric",
      concentric: function (n) { return RING[n.data("type")] || 1; },
      levelWidth: function () { return 1; },
      minNodeSpacing: 28,
      spacingFactor: 0.8,
      animate: false,
      padding: 12,
    },
    // pe pagina farmacistului graful nu fură derularea paginii
    userZoomingEnabled: !page,
    userPanningEnabled: !page,
    boxSelectionEnabled: false,
    autoungrabify: page,
    minZoom: 0.3,
    maxZoom: 3,
  });

  cy.on("tap", "edge[alert_id]", function (event) {
    var id = event.target.data("alert_id");
    if (!id) return;
    var handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.alert;
    if (handler) {
      handler.postMessage(id);
    } else if (!embed) {
      if (page) document.dispatchEvent(new CustomEvent("pg:alert", { detail: id }));
      else window.location.href = window.location.pathname.replace(/\/graph$/, "") + "#alert-" + id;
    }
  });

  ["(prefers-color-scheme: dark)", "(prefers-contrast: more)"].forEach(function (q) {
    var mq = window.matchMedia(q);
    var restyle = function () { cy.style(style()); };
    if (mq.addEventListener) mq.addEventListener("change", restyle);
  });
  window.addEventListener("resize", function () { cy.resize(); cy.fit(undefined, 16); });
})();
