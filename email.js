(() => {
  const encodedAddress = "dGltZm94MjAyNUB0aW0uYXJteQ==";

  document.addEventListener("DOMContentLoaded", () => {
    const address = window.atob(encodedAddress);
    document.querySelectorAll("[data-masked-email]").forEach((link) => {
      link.href = `mailto:${address}`;
    });
  });
})();
