# Pokédex Bash 🔴🟢

Una Pokédex interactiva para la terminal escrita completamente en Bash Scripting. Este proyecto consume la [PokeAPI](https://pokeapi.co/) para consultar datos en tiempo real y renderiza la información utilizando una estética retro inspirada en los menús clásicos de Game Boy Advance (Como Pokemon Yellow).

## 🚀 Características (v1.1)

* **Interfaz Interactiva:** Menús navegables por teclado utilizando secuencias de escape ANSI.
* **Búsqueda Avanzada:** Consulta de Pokémon específicos por nombre o ID numérico.
* **Filtros Dinámicos:** Exploración del catálogo segmentado por Región de origen o por Tipo.
* **Arte ASCII en Tiempo Real:** Descarga y conversión de *sprites* oficiales a bloques de color en la terminal mediante `chafa`.
* **Árbol Evolutivo:** Parseo recursivo de JSON para calcular y mostrar la línea evolutiva cronológica completa.
* **Autogestión de Dependencias:** Comprobación e instalación automática (vía `apt`) de las herramientas requeridas para su funcionamiento.

## 🚀 Características (v1.1.2)

* **Interfaz Interactiva:** Menús navegables por teclado utilizando secuencias de escape ANSI.
* **Búsqueda Avanzada:** Consulta de Pokémon específicos por nombre o ID numérico.
* **Filtros Dinámicos:** Exploración del catálogo segmentado por Región de origen o por Tipo.
* **Arte ASCII en Tiempo Real:** Descarga y conversión de *sprites* oficiales a bloques de color en la terminal mediante `chafa`.
* **Árbol Evolutivo:** Parseo recursivo de JSON para calcular y mostrar la línea evolutiva cronológica completa.
* **Sistema de Captura (Zettelkasten):** Exportación automática de la ficha del Pokémon a un archivo Markdown con *frontmatter* YAML y enlaces bidireccionales, guardado en un directorio global.
* **Integración de Audio:** Reproducción en segundo plano del grito original del Pokémon consultado utilizando `mpv`.
* **Autogestión de Dependencias:** Comprobación e instalación automática (vía `apt`) de las herramientas requeridas (`curl`, `jq`, `chafa`, `mpv`).

## 🆕 Novedades v1.2.0

- **UI uniforme:** todas las ventanas (menú, filtros, listados y ficha)
  comparten un mismo ancho, controlado por la variable `ANCHO_INT`.
- **Alineación perfecta con acentos:** el ancho visual se calcula por
  puntos de código y no por bytes, así que `é`, `ñ` o `1ª` ya no
  descuadran los bordes.
- **Descripción de cada Pokémon:** la ficha muestra el texto oficial de
  la Pokédex en español (PokeAPI), ajustado al ancho del recuadro, y
  también se guarda en la nota `.md` de captura.

## 🛠️ Requisitos

El script verifica automáticamente si tienes instalados los paquetes necesarios. Si no los tienes, intentará instalarlos:
* `curl` (Peticiones HTTP)
* `jq` (Parseo de JSON)
* `chafa` (Renderizado de imágenes a texto)

## 🎮 Instalación y Uso

Clona este repositorio, otorga permisos de ejecución y lanza el script:

```bash
git clone [https://github.com/SorenCenteno/Poke-Bash.git](https://github.com/SorenCenteno/Poke-Bash.git)
cd Poke-Bash
chmod +x Poke-Bash.sh
./Poke-Bash.sh
