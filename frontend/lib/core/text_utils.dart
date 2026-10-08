// Utilidades de texto compartidas — usado por todas las barras de búsqueda
// del sistema (inventario, préstamos, permisos, guías, etc.) para que
// "Ácido" y "Acido" produzcan los mismos resultados.

const _kConTildes = 'ÁÀÂÄÃáàâäãÉÈÊËéèêëÍÌÎÏíìîïÓÒÔÖÕóòôöõÚÙÛÜúùûüÑñÇç';
const _kSinTildes  = 'AAAAAaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuNnCc';

/// Quita tildes/diacríticos de [texto] (ej. "Ácido" → "Acido").
String quitarTildes(String texto) {
  final buffer = StringBuffer();
  for (final rune in texto.runes) {
    final char = String.fromCharCode(rune);
    final idx = _kConTildes.indexOf(char);
    buffer.write(idx >= 0 ? _kSinTildes[idx] : char);
  }
  return buffer.toString();
}

/// Normaliza [texto] para comparar en una búsqueda: sin espacios en los
/// extremos, minúsculas y sin tildes. Úsalo en ambos lados de un
/// `.contains()` para que la búsqueda sea insensible a mayúsculas/
/// minúsculas, a acentos y a espacios sobrantes ("h2so4 " encuentra H2SO4,
/// algo habitual con el autocompletado del teclado móvil).
String normalizarBusqueda(String texto) =>
    quitarTildes(texto.trim().toLowerCase());
