// The landing page: live figures from the same public Firestore document the apps read, scroll reveals,
// counters and the phone that swaps screens as the steps scroll past. Without it, the page shows static figures.
// When the live data has been applied or given up on, <html data-live> is "ok" or "fallback": the e2e tests wait for it.
(() => {
  const SNAPSHOT = "https://firestore.googleapis.com/v1/projects/embalse-san-juan/databases/(default)/documents/public/snapshot";
  const number = (value, digits) => value.toLocaleString("es-ES", { minimumFractionDigits: digits, maximumFractionDigits: digits });
  const hm3 = (value) => `${number(value, Number.isInteger(value) ? 0 : 1)} hm³`;
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const $ = (id) => document.getElementById(id);

  // The hero's water rises with the reservoir, from 10 % of the hero's height when empty to 40 % when full,
  // so it never covers the headline.
  const water = $("water");
  const setLevel = (percent) => { water.style.height = `${10 + percent * 0.3}%`; };
  setLevel(0);
  // A placeholder rise while the data loads, unless the real level is already there.
  requestAnimationFrame(() => { if (!document.documentElement.dataset.live) setLevel(48.5); });

  const countUp = (element, to, digits) => {
    if (still) { element.textContent = number(to, digits); return; }
    const start = performance.now();
    const step = (now) => {
      const t = Math.min((now - start) / 1600, 1);
      element.textContent = number(to * (1 - Math.pow(1 - t, 3)), digits);
      if (t < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  };

  const bars = $("bars");
  let weekly = { volumeHm3: 70, lastYearHm3: 75, tenYearAvgHm3: 57.5, capacityHm3: 138 };
  const fillBars = () => document.querySelectorAll(".fill").forEach((fill) => {
    fill.style.width = `${Math.min(100, (weekly[fill.dataset.key] / weekly.capacityHm3) * 100)}%`;
  });

  const showLive = (snapshot) => {
    const live = snapshot.live;
    countUp($("percent"), live.percent, 1);
    setLevel(live.percent);
    $("volume").textContent = `${number(live.volumeHm3, 1)} hm³ de ${snapshot.weekly?.capacityHm3 ?? 138} hm³`;
    const change = live.trend24hHm3 ?? 0;
    const [word, icon] = Math.abs(change) < 0.05 ? ["Estable", "→"] : change > 0 ? ["Subiendo", "↗"] : ["Bajando", "↘"];
    $("trend").textContent = word;
    $("trend-icon").textContent = icon;
    $("trend-detail").textContent = `${change > 0 ? "+" : change < 0 ? "−" : ""}${number(Math.abs(change), 2)} hm³ en 24 h`;
    const at = new Date(live.observedAt).toLocaleString("es-ES", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
    $("updated").textContent = `SAIH Tajo, ${at}`;
    if (snapshot.weekly) {
      weekly = snapshot.weekly;
      const date = new Date(`${weekly.date}T12:00:00`).toLocaleDateString("es-ES", { day: "numeric", month: "long" });
      $("weekly-caption").textContent = `Boletín Hidrológico de MITECO, semana del ${date}. Es otra medición y no coincide con la de arriba.`;
      $("capacity").textContent = number(weekly.capacityHm3, 0);
      document.querySelectorAll("[data-label]").forEach((label) => { label.textContent = hm3(weekly[label.dataset.label]); });
      if (bars.classList.contains("in")) fillBars();
    }
    document.documentElement.dataset.live = "ok";
  };

  fetch(SNAPSHOT)
    .then((response) => (response.ok ? response.json() : Promise.reject(new Error(`HTTP ${response.status}`))))
    .then((document_) => showLive(JSON.parse(document_.fields.payload.stringValue)))
    .catch(() => {
      countUp($("percent"), 48.5, 1);
      setLevel(48.5);
      document.documentElement.dataset.live = "fallback";
    });

  // Reveals and counters
  const reveal = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add("in");
      if (entry.target === bars) fillBars();
      entry.target.querySelectorAll("[data-count]").forEach((counter) => countUp(counter, Number(counter.dataset.count), 0));
      reveal.unobserve(entry.target);
    });
  }, { threshold: 0.15 });
  document.querySelectorAll(".reveal").forEach((element) => reveal.observe(element));

  // Years read better without a thousands separator.
  document.querySelectorAll("[data-count]").forEach((counter) => {
    if (Number(counter.dataset.count) > 1900) counter.removeAttribute("data-count");
  });

  // Scrollytelling
  const story = document.querySelector(".story");
  const shots = story.querySelectorAll(".shot");
  const dots = story.querySelectorAll(".progress li");
  const steps = story.querySelectorAll(".step");
  const storyObserver = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      const index = entry.target.dataset.step;
      story.dataset.active = index;
      steps.forEach((step) => step.classList.toggle("active", step === entry.target));
      shots.forEach((shot) => shot.classList.toggle("active", shot.dataset.step === index));
      dots.forEach((dot, i) => dot.classList.toggle("active", String(i) === index));
    });
  }, { rootMargin: "-45% 0px -45% 0px" });
  steps.forEach((step) => storyObserver.observe(step));

  const bar = document.querySelector(".bar");
  addEventListener("scroll", () => bar.classList.toggle("scrolled", scrollY > 10), { passive: true });
})();
