(() => {
  const storageKey = "tim-fox-resume-theme";
  const root = document.documentElement;
  const themeColor = document.querySelector('meta[name="theme-color"]');
  const lightQuery = typeof window.matchMedia === "function"
    ? window.matchMedia("(prefers-color-scheme: light)")
    : null;

  const readSavedTheme = () => {
    try {
      const saved = window.localStorage.getItem(storageKey);
      return saved === "light" || saved === "dark" ? saved : null;
    } catch {
      return null;
    }
  };

  const saveTheme = (theme) => {
    try {
      window.localStorage.setItem(storageKey, theme);
    } catch {
      // The selected theme still applies when storage is unavailable.
    }
  };

  // An explicit choice wins. Otherwise follow the operating system, falling
  // back to dark where prefers-color-scheme is unsupported.
  const preferredTheme = () => {
    const saved = readSavedTheme();
    if (saved) {
      return saved;
    }
    return lightQuery && lightQuery.matches ? "light" : "dark";
  };

  const applyTheme = (theme) => {
    const isLight = theme === "light";
    root.dataset.theme = isLight ? "light" : "dark";
    if (themeColor) {
      themeColor.content = isLight ? "#ffffff" : "#1e1e1e";
    }
  };

  const updateToggle = () => {
    const toggle = document.querySelector("#theme-toggle");
    if (!toggle) {
      return;
    }
    const isLight = root.dataset.theme === "light";
    const nextTheme = isLight ? "dark" : "light";
    toggle.textContent = isLight ? "Dark mode" : "Light mode";
    toggle.href = `#${nextTheme}-mode`;
    toggle.setAttribute("aria-pressed", String(isLight));
    toggle.setAttribute("aria-label", `Switch to ${nextTheme} mode`);
  };

  applyTheme(preferredTheme());

  // Track the operating system until the visitor chooses for themselves.
  if (lightQuery && typeof lightQuery.addEventListener === "function") {
    lightQuery.addEventListener("change", (event) => {
      if (readSavedTheme()) {
        return;
      }
      applyTheme(event.matches ? "light" : "dark");
      updateToggle();
    });
  }

  document.addEventListener("DOMContentLoaded", () => {
    const toggle = document.querySelector("#theme-toggle");
    if (!toggle) {
      return;
    }

    updateToggle();

    toggle.addEventListener("click", (event) => {
      event.preventDefault();
      const nextTheme = root.dataset.theme === "light" ? "dark" : "light";
      applyTheme(nextTheme);
      saveTheme(nextTheme);
      updateToggle();
    });
  });
})();
