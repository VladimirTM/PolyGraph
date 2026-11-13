// PolyGraph · pagina farmacistului (B6): antetul la derulare și „Am verificat” fără reîncărcare.
(function () {
  "use strict";

  // gradientul de sub antet apare doar după ce pagina a fost derulată
  var bar = document.querySelector("[data-topbar]");
  var sentinel = document.querySelector(".scroll-sentinel");
  if (bar && sentinel && "IntersectionObserver" in window) {
    new IntersectionObserver(function (entries) {
      bar.classList.toggle("is-scrolled", !entries[0].isIntersecting);
    }).observe(sentinel);
  }

  function formatNow() {
    var d = new Date();
    var p = function (n) { return String(n).padStart(2, "0"); };
    return p(d.getHours()) + ":" + p(d.getMinutes());
  }

  document.addEventListener("submit", function (event) {
    var form = event.target.closest(".verify-form");
    if (!form) return;
    event.preventDefault();
    var button = form.querySelector("button");
    var error = form.querySelector(".verify-error");
    if (button.disabled) return; // a doua apăsare cât timp prima e în curs
    var note = form.querySelector("input[name=note]").value.trim();
    button.disabled = true;
    error.hidden = true;

    fetch(form.action, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ note: note }),
      credentials: "omit",
    })
      .then(function (response) {
        if (!response.ok) throw new Error(response.status === 404 ? "expired" : "server");
        return response.json();
      })
      .then(function () {
        var state = document.createElement("p");
        state.className = "verified-state";
        state.setAttribute("role", "status");
        state.textContent = "Verificat de dumneavoastră acum (" + formatNow() + ")";
        if (note) {
          var noteEl = document.createElement("span");
          noteEl.className = "note";
          noteEl.textContent = "„" + note + "”";
          state.appendChild(document.createElement("br"));
          state.appendChild(noteEl);
        }
        var card = form.closest(".alert");
        if (card) card.classList.add("is-verified");
        form.replaceWith(state);
      })
      .catch(function (err) {
        error.textContent = err.message === "expired"
          ? "Linkul a expirat. Cereți familiei un cod QR nou."
          : "Nu s-a putut salva. Verificați conexiunea și încercați din nou.";
        error.hidden = false;
        button.disabled = false;
      });
  });

  // tap pe o muchie din graf → alerta corespunzătoare (graph.js trimite evenimentul)
  document.addEventListener("pg:alert", function (event) {
    var card = document.getElementById("alert-" + event.detail);
    if (!card) return;
    var details = card.querySelector("details");
    if (details) details.open = true;
    var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    card.scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "start" });
    document.querySelectorAll(".alert.is-highlighted").forEach(function (el) { el.classList.remove("is-highlighted"); });
    card.classList.add("is-highlighted");
  });
})();
