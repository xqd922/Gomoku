{{flutter_js}}
{{flutter_build_config}}

window.addEventListener("flutter-first-frame", () => {
  document.getElementById("loading")?.remove();
});
_flutter.loader.load({
  config: { canvasKitBaseUrl: "canvaskit/" },
  onEntrypointLoaded: async (initializer) => {
    const engine = await initializer.initializeEngine();
    await engine.runApp();
  },
});
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/offline_worker.js").catch(() => {
      // Offline installation is optional; the game still works in this tab.
    });
  });
}
