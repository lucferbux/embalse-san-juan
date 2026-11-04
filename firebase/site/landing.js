// The landing page: live figures from the same public Firestore document the apps read, scroll reveals and
// the phone that swaps screens as the steps scroll past. Everything works without it, with the static figures.
(() => {
  const SNAPSHOT = "https://firestore.googleapis.com/v1/projects/embalse-san-juan/databases/(default)/documents/public/snapshot";
  const number = (value, digits) => value.toLocaleString("es-ES", { minimumFractionDigits: digits, maximumFractionDigits: digits });
  const hm3 = (value) => `${number(value, Number.isInteger(value) ? 0 : 1)} hm³`;
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;

  // The hero's water stands at the reservoir's level, between a fifth and four fifths of the height.
  const water = document.getElementById("water");
  const setLevel = (percent) => { water.style.height = `${20 + percent * 0.6}%`; };
  setLevel(0);
  requestAnimationFrame(() => setLevel(48.5));

  const countUp = (element, to) => {
    if (still) { element.textContent = number(to, 1); return; }
    const start = performance.now();
    const step = (now) => {
      const t = Math.min((now - start) / 1600, 1);
      element.textContent = number(to * (1 - Math.pow(1 - t, 3)), 1);
      if (t < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  };

  let weekly = { volumeHm3: 70, lastYearHm3: 75, tenYearAvgHm3: 57.5, capacityHm3: 138 };

  fetch(SNAPSHOT)
    .then((response) => (response.ok ? response.json() : Promise.reject(response.status)))
    .then((document_) => JSON.parse(document_.fields.payload.stringValue))
    .then((snapshot) => {
      const live = snapshot.live;
      countUp(document.getElementById("percent"), live.percent);
      setLevel(live.percent);
      document.getElementById("volume").textContent = `${number(live.volumeHm3, 1)} hm³ de ${snapshot.weekly?.capacityHm3 ?? 138} hm³`;
      const at = new Date(live.observedAt).toLocaleString("es-ES", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
      document.getElementById("updated").textContent = `SAIH Tajo, ${at}. Dato provisional.`;
      if (snapshot.weekly) {
        weekly = snapshot.weekly;
        const date = new Date(`${weekly.date}T12:00:00`).toLocaleDateString("es-ES", { day: "numeric", month: "long" });
        document.getElementById("weekly-caption").textContent = `Boletín Hidrológico de MITECO, semana del ${date}. Es otra medición y no coincide con la de arriba.`;
        document.getElementById("capacity").textContent = number(weekly.capacityHm3, 0);
        document.querySelectorAll("[data-label]").forEach((label) => { label.textContent = hm3(weekly[label.dataset.label]); });
        if (bars.classList.contains("in")) fillBars();
      }
    })
    .catch(() => countUp(document.getElementById("percent"), 48.5));

  const bars = document.getElementById("bars");
  const fillBars = () => document.querySelectorAll(".fill").forEach((fill) => {
    fill.style.width = `${Math.min(100, (weekly[fill.dataset.key] / weekly.capacityHm3) * 100)}%`;
  });

  // Reveals
  const reveal = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add("in");
      if (entry.target === bars) fillBars();
      reveal.unobserve(entry.target);
    });
  }, { threshold: 0.2 });
  document.querySelectorAll(".reveal").forEach((element) => reveal.observe(element));

  // Scrollytelling
  const screens = document.querySelectorAll(".story .screen");
  const steps = document.querySelectorAll(".step");
  const story = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      const index = entry.target.dataset.step;
      steps.forEach((step) => step.classList.toggle("active", step === entry.target));
      screens.forEach((screen) => screen.classList.toggle("active", screen.dataset.step === index));
    });
  }, { rootMargin: "-45% 0px -45% 0px" });
  steps.forEach((step) => story.observe(step));

  const bar = document.querySelector(".bar");
  addEventListener("scroll", () => bar.classList.toggle("scrolled", scrollY > 10), { passive: true });
})();
