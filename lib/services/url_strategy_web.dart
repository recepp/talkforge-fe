import 'dart:html' as html;

void setWebUrlHash(String hash) {
  html.window.location.hash = hash;
}

String getWebUrlHash() {
  return html.window.location.hash;
}
