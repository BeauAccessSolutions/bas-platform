/*
 * WCAG 3.1.1 Language of Page (Level A) — guarantee an html[lang].
 *
 * Keycloak only renders `lang` on <html> when the realm has
 * internationalization enabled; the `bas` realm currently does not, so the
 * default keycloak.v2 login page ships without it. Rather than mutate shared
 * realm state (which affects every app on the realm and would not travel with
 * this committed theme), set the platform default here — but never clobber a
 * value the server did provide, so this stays correct if i18n is enabled later.
 *
 * Runs synchronously from <head> (before the body is parsed), so assistive
 * technology sees the language before it builds its virtual buffer.
 */
(function () {
  var el = document.documentElement;
  if (!el.getAttribute("lang")) {
    el.setAttribute("lang", "en");
  }
})();
