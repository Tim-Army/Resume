(() => {
  const storageKey = "tim-fox-resume-theme";
  const root = document.documentElement;
  const themeColor = document.querySelector('meta[name="theme-color"]');

  const readSavedTheme = () => {
    try {
      return window.localStorage.getItem(storageKey);
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

  const applyTheme = (theme) => {
    const isLight = theme === "light";
    root.dataset.theme = isLight ? "light" : "dark";
    if (themeColor) {
      themeColor.content = isLight ? "#eaf0f4" : "#000000";
    }
  };

  applyTheme(readSavedTheme() === "light" ? "light" : "dark");

  document.addEventListener("DOMContentLoaded", () => {
    const toggle = document.querySelector("#theme-toggle");
    if (!toggle) {
      return;
    }

    const updateToggle = () => {
      const isLight = root.dataset.theme === "light";
      const nextTheme = isLight ? "dark" : "light";
      toggle.textContent = isLight ? "Dark mode" : "Light mode";
      toggle.href = `#${nextTheme}-mode`;
      toggle.setAttribute("aria-pressed", String(isLight));
      toggle.setAttribute("aria-label", `Switch to ${nextTheme} mode`);
    };

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
