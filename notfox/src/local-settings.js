// Carga el archivo de configuración de NotFox.
pref("general.config.filename", "notfox.cfg");
pref("general.config.obscure_value", 0);
// sandbox desactivado: notfox.cfg registra observadores de ventana
// (recordar pantalla completa), para lo que necesita contexto chrome.
pref("general.config.sandbox_enabled", false);
