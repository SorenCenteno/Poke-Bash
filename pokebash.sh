#!/bin/bash

# ==============================================================================
# CONFIGURACIÓN Y COLORES RETRO (Estilo GBA Blanco/Negro)
# ==============================================================================
# Se usan escapes REALES ($'\e') en lugar de "\e" literal. Así podemos imprimir
# con printf '%s' de forma segura, aunque el texto (descripciones de la API)
# contenga barras invertidas u otros caracteres especiales.
BG=$'\e[107m'
FG=$'\e[30m'
ACCENT=$'\e[1m'
RESET=$'\e[0m'

# Validar dependencias esenciales
for cmd in curl jq chafa; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: Se requiere '$cmd' instalado en el sistema."
        exit 1
    fi
done

# Directorio por defecto para guardar capturas
DIR_CAPTURAS="$HOME/pokedex_capturas"

# ==============================================================================
# MOTOR DE CAJAS / UI  (ancho estándar para TODAS las ventanas)
# ==============================================================================
# ANCHO_INT = número de columnas INTERIORES entre los bordes ┃ ... ┃
# Cambia este único valor y todas las ventanas se reajustan a la vez.
ANCHO_INT=54

# Ancho visual REAL de una cadena. Cuenta puntos de código Unicode, no bytes,
# de forma independiente del locale. Esto es lo que arregla el descuadre con
# tildes (é, ó, ñ, 1ª, etc.).
_wl() {
    local s=$1
    local LC_ALL=C
    local limpio=${s//[$'\x80'-$'\xbf']/}   # elimina bytes de continuación UTF-8
    echo ${#limpio}
}

# Barras horizontales precalculadas una sola vez (rendimiento)
_hbar() { local i s=; for ((i=0; i<ANCHO_INT; i++)); do s+="$1"; done; printf '%s' "$s"; }
LINEA_H=$(_hbar '━')

# --- Primitivas de dibujo -----------------------------------------------------
ui_top()    { printf '%s ┏%s┓ %s\n' "$BG$FG" "$LINEA_H" "$RESET"; }
ui_sep()    { printf '%s ┣%s┫ %s\n' "$BG$FG" "$LINEA_H" "$RESET"; }
ui_bottom() { printf '%s ┗%s┛ %s\n' "$BG$FG" "$LINEA_H" "$RESET"; }
ui_blank()  { printf '%s ┃%*s┃ %s\n' "$BG$FG" "$ANCHO_INT" "" "$RESET"; }

# Línea de contenido, alineada a la izquierda con margen de 2 espacios.
ui_line() {
    local t="  $1"
    local pad=$(( ANCHO_INT - $(_wl "$t") ))
    (( pad < 0 )) && pad=0
    printf '%s ┃%s%*s┃ %s\n' "$BG$FG" "$t" "$pad" "" "$RESET"
}

# Título centrado en negrita.
ui_title() {
    local t="$1"
    local w=$(_wl "$t")
    local tot=$(( ANCHO_INT - w )); (( tot < 0 )) && tot=0
    local l=$(( tot / 2 )); local r=$(( tot - l ))
    printf '%s ┃%*s%s%s%s%s%*s┃ %s\n' \
        "$BG$FG" "$l" "" "$ACCENT" "$t" "$RESET" "$BG$FG" "$r" "" "$RESET"
}

# Ítem de menú. $1 = texto, $2 = "1" si está seleccionado.
ui_item() {
    local marca="  "
    [[ "$2" == "1" ]] && marca="▶ "
    ui_line "${marca}$1"
}

# Imprime un párrafo largo ajustado (word-wrap) dentro de la caja.
# Nota: el '\n' final y el guardia '|| [[ -n "$linea" ]]' son imprescindibles.
# Sin ellos, 'read' descartaría la ÚLTIMA línea generada por fold (no termina
# en salto de línea) y la descripción se cortaría antes de tiempo.
ui_parrafo() {
    printf '%s\n' "$1" | fold -s -w $(( ANCHO_INT - 4 )) | while IFS= read -r linea || [[ -n "$linea" ]]; do
        ui_line "$linea"
    done
}

# ==============================================================================
# FUNCIONES DE TRADUCCIÓN LOCAL (Para máxima velocidad)
# ==============================================================================
traducir_tipo() {
    case "$1" in
        normal) echo "Normal";; fighting) echo "Lucha";; flying) echo "Volador";;
        poison) echo "Veneno";; ground) echo "Tierra";; rock) echo "Roca";;
        bug) echo "Bicho";; ghost) echo "Fantasma";; steel) echo "Acero";;
        fire) echo "Fuego";; water) echo "Agua";; grass) echo "Planta";;
        electric) echo "Eléctrico";; psychic) echo "Psíquico";; ice) echo "Hielo";;
        dragon) echo "Dragón";; dark) echo "Siniestro";; fairy) echo "Hada";;
        *) echo "Desconocido";;
    esac
}

traducir_region() {
    case "$1" in
        "generation-i")   echo "Kanto (1ª Gen)";;
        "generation-ii")  echo "Johto (2ª Gen)";;
        "generation-iii") echo "Hoenn (3ª Gen)";;
        "generation-iv")  echo "Sinnoh (4ª Gen)";;
        "generation-v")   echo "Teselia/Unova (5ª Gen)";;
        "generation-vi")  echo "Kalos (6ª Gen)";;
        "generation-vii") echo "Alola (7ª Gen)";;
        "generation-viii")echo "Galar (8ª Gen)";;
        "generation-ix")  echo "Paldea (9ª Gen)";;
        *) echo "Desconocida";;
    esac
}

# ==============================================================================
# VALIDACION E INSTALACION DE DEPENDENCIAS
# ==============================================================================
verificar_dependencias() {
    local dependencias=("curl" "jq" "chafa" "mpv")
    local faltantes=()

    for cmd in "${dependencias[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            faltantes+=("$cmd")
        fi
    done

    if [ ${#faltantes[@]} -ne 0 ]; then
        clear
        ui_top
        ui_title "INSTALACIÓN"
        ui_sep
        ui_line "Instalando dependencias necesarias..."
        ui_line "Paquetes: ${faltantes[*]}"
        ui_bottom
        echo ""

        sudo apt-get update -qq
        sudo apt-get install -y "${faltantes[@]}"

        clear
        ui_top
        ui_line "¡Todo listo! Iniciando Pokédex..."
        ui_bottom
        sleep 1.5
    fi
}

# ==============================================================================
# LÓGICA DE LA API Y RENDERIZADO DE FICHA
# ==============================================================================
buscar_pokemon() {
    local BUSQUEDA="$1"

    if [[ -z "$BUSQUEDA" ]]; then
        clear
        printf '%s Introduce el nombre o ID del Pokémon: %s\n' "$BG$FG" "$RESET"
        read -r BUSQUEDA
    fi

    # --- INICIO DEL INTERCEPTOR CTF (MISSINGNO) ---
    if [[ "$BUSQUEDA" == "bWlzc2luZ25v" ]]; then
        mostrar_missingno
        return
    fi
    # --- FIN DEL INTERCEPTOR CTF ---

    BUSQUEDA=$(echo "$BUSQUEDA" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
    if [[ -z "$BUSQUEDA" ]]; then return; fi

    clear
    echo -e "\n Cargando datos desde la Base de Datos Celadon..."

    # 1. Petición Principal
    POKE_DATA=$(curl -s --max-time 5 "https://pokeapi.co/api/v2/pokemon/$BUSQUEDA")
    if [[ -z "$POKE_DATA" || "$POKE_DATA" == "Not Found" ]]; then
        echo -e "\n[!] Pokémon no encontrado. Verifica el nombre."
        read -rsn1 -p "Presiona cualquier tecla para continuar..."
        return
    fi

    ID=$(echo "$POKE_DATA" | jq -r '.id')
    SPRITE_NORMAL=$(echo "$POKE_DATA" | jq -r '.sprites.front_default')
    SPRITE_SHINY=$(echo "$POKE_DATA" | jq -r '.sprites.front_shiny')
    CRY_URL=$(echo "$POKE_DATA" | jq -r '.cries.latest // empty')

    ALTURA=$(echo "$POKE_DATA" | jq -r '.height' | awk '{printf "%.1f m", $1/10}')
    PESO=$(echo "$POKE_DATA" | jq -r '.weight' | awk '{printf "%.1f kg", $1/10}')

    T1=$(echo "$POKE_DATA" | jq -r '.types[0].type.name')
    T2=$(echo "$POKE_DATA" | jq -r '.types[1].type.name // empty')
    TIPO_FINAL=$(traducir_tipo "$T1")
    if [[ -n "$T2" ]]; then TIPO_FINAL="$TIPO_FINAL / $(traducir_tipo "$T2")"; fi

    # 2. Petición de Especie
    SPECIES_URL=$(echo "$POKE_DATA" | jq -r '.species.url')
    SPECIES_DATA=$(curl -s "$SPECIES_URL")

    NOMBRE_ES=$(echo "$SPECIES_DATA" | jq -r '.names[] | select(.language.name=="es") | .name' | head -n1)
    [[ -z "$NOMBRE_ES" ]] && NOMBRE_ES=$(echo "$POKE_DATA" | jq -r '.name | upcase')

    GEN_RAW=$(echo "$SPECIES_DATA" | jq -r '.generation.name')
    REGION=$(traducir_region "$GEN_RAW")

    # 2.b DESCRIPCIÓN (flavor text de la Pokédex, en español)
    #     La API mete saltos de línea y form-feed (\f) dentro del texto:
    #     los normalizamos a espacios y colapsamos los espacios repetidos.
    DESCRIPCION=$(echo "$SPECIES_DATA" | jq -r \
        '[.flavor_text_entries[] | select(.language.name=="es") | .flavor_text] | .[0] // empty')
    DESCRIPCION=$(printf '%s' "$DESCRIPCION" | tr '[:cntrl:]' ' ' | tr -s ' ' | sed 's/^ *//; s/ *$//')
    [[ -z "$DESCRIPCION" ]] && DESCRIPCION="Sin descripción disponible para este Pokémon."

    # 3. Cadena de Evolución
    EVO_URL=$(echo "$SPECIES_DATA" | jq -r '.evolution_chain.url')
    EVO_DATA=$(curl -s "$EVO_URL")
    CADENA_EVO=$(echo "$EVO_DATA" | jq -r '[.. | .species? | .name? | select(. != null)] | map((.[0:1] | ascii_upcase) + .[1:]) | join(" -> ")')

    # 4. Preparación de Recursos (Audio e Imágenes)
    if [[ -n "$CRY_URL" && "$CRY_URL" != "null" ]]; then
        curl -s "$CRY_URL" -o /tmp/pokecry.ogg
        mpv --no-video --really-quiet --volume=50 /tmp/pokecry.ogg > /dev/null 2>&1 &
    fi

    [[ "$SPRITE_NORMAL" != "null" ]] && curl -s "$SPRITE_NORMAL" -o /tmp/pokesprite_normal.png
    [[ "$SPRITE_SHINY" != "null" ]] && curl -s "$SPRITE_SHINY" -o /tmp/pokesprite_shiny.png

    # ==========================================================================
    # FACTOR SHINY ALEATORIO (1 en 4096)
    # ==========================================================================
    local MOSTRANDO_SHINY=0
    [[ $((RANDOM % 4096)) -eq 0 ]] && MOSTRANDO_SHINY=1
    # *Testing: cambia 4096 por 2 para forzar ~50% de apariciones shiny.*

    clear

    if [[ $MOSTRANDO_SHINY -eq 1 ]]; then
        IMG_ACTUAL="/tmp/pokesprite_shiny.png"
        INDICADOR_SHINY=" [SHINY]"
    else
        IMG_ACTUAL="/tmp/pokesprite_normal.png"
        INDICADOR_SHINY=""
    fi

    # Dibujar Sprite
    if [[ -f "$IMG_ACTUAL" ]]; then
        chafa --size=40x16 --colors=256 "$IMG_ACTUAL"
    else
        echo -e "\n[ Sin Ilustración Disponible ]\n"
    fi

    # ------------------------------------------------------------------
    # FICHA (ahora con ancho uniforme y sección de DESCRIPCIÓN)
    # ------------------------------------------------------------------
    ui_top
    ui_title "INFO POKÉMON"
    ui_sep
    ui_line "• Nombre:  ${NOMBRE_ES^^}${INDICADOR_SHINY} (#$ID)"
    ui_line "• Tipo:    $TIPO_FINAL"
    ui_line "• Región:  $REGION"
    ui_line "• Medidas: $ALTURA / $PESO"
    ui_sep
    ui_title "DESCRIPCIÓN"
    ui_sep
    ui_parrafo "$DESCRIPCION"
    ui_sep
    ui_title "LÍNEA EVOLUTIVA"
    ui_sep
    ui_parrafo "$CADENA_EVO"
    ui_bottom
    echo ""

    # Menú inferior simplificado (Sin bucle)
    printf '%s [C] Capturar  |  [Enter] Regresar %s\n' "$BG$FG" "$RESET"
    read -rsn1 tecla

    if [[ "${tecla^^}" == "C" ]]; then
        # --- SISTEMA DE CAPTURA ZETTELKASTEN ---
        mkdir -p "$DIR_CAPTURAS"
        local TAG_REGION=$(echo "$REGION" | awk '{print tolower($1)}' | sed 'y/áéíóú/aeiou/')
        local TAG_TIPO=$(echo "$TIPO_FINAL" | sed 's/ \/ /-/g' | tr '[:upper:]' '[:lower:]' | sed 'y/áéíóú/aeiou/')
        local EVO_WIKI="[[${CADENA_EVO// -> /]] -> [[}]]"

        local NOMBRE_CAPITALIZADO="${NOMBRE_ES^}"
        local ARCHIVO="$DIR_CAPTURAS/${NOMBRE_CAPITALIZADO}.md"
        local SHINY_LINE=""
        local SPRITE_FINAL="$SPRITE_NORMAL"

        if [[ $MOSTRANDO_SHINY -eq 1 ]]; then
            ARCHIVO="$DIR_CAPTURAS/${NOMBRE_CAPITALIZADO}_Shiny.md"
            SHINY_LINE=$'\n  - pokemon/variante/shiny'
            SPRITE_FINAL="$SPRITE_SHINY"
            NOMBRE_CAPITALIZADO="✨ $NOMBRE_CAPITALIZADO ✨"
        fi

        cat <<EOF > "$ARCHIVO"
---
aliases: ["${NOMBRE_ES^^}"]
tags:
  - pokemon/tipo/$TAG_TIPO
  - pokemon/region/$TAG_REGION${SHINY_LINE}
id: $ID
altura: $ALTURA
peso: $PESO
---

# $NOMBRE_CAPITALIZADO

![Sprite Oficial]($SPRITE_FINAL)

## Descripción
$DESCRIPCION

## Datos Biométricos
- **Tipo:** $TIPO_FINAL
- **Región:** $REGION
- **Medidas:** $ALTURA / $PESO

## Línea Evolutiva
$EVO_WIKI
EOF
        printf '\n %s%s ¡%s registrado en la base de datos! %s\n' "$BG$FG" "$ACCENT" "$NOMBRE_CAPITALIZADO" "$RESET"
        printf ' %s 💾 Archivo guardado en: %s %s\n' "$BG$FG" "$ARCHIVO" "$RESET"
        sleep 2.5
    fi

    # Limpieza de archivos temporales
    rm -f /tmp/pokesprite_normal.png /tmp/pokesprite_shiny.png /tmp/pokecry.ogg
}

# ==============================================================================
# FILTROS (REGIÓN Y TIPO)
# ==============================================================================
filtrar_por_region() {
    local regiones=("Kanto" "Johto" "Hoenn" "Sinnoh" "Teselia" "Kalos" "Alola" "Galar" "Paldea" "Volver")
    local sel=0

    while true; do
        clear
        ui_top
        ui_title "SELECCIONA UNA REGIÓN"
        ui_sep
        for i in "${!regiones[@]}"; do
            [[ $i -eq $sel ]] && ui_item "${regiones[$i]}" 1 || ui_item "${regiones[$i]}" 0
        done
        ui_bottom

        read -rsn1 tecla
        if [[ $tecla == $'\e' ]]; then
            read -rsn2 tecla
            case "$tecla" in
                "[A") ((sel--)); if [[ $sel -lt 0 ]]; then sel=$((${#regiones[@]} - 1)); fi ;;
                "[B") ((sel++)); if [[ $sel -ge ${#regiones[@]} ]]; then sel=0; fi ;;
            esac
        elif [[ -z $tecla ]]; then
            if [[ "${regiones[$sel]}" == "Volver" ]]; then return; fi

            clear
            echo "Explorando la región de ${regiones[$sel]}..."
            local gen_id=$((sel + 1))
            local data=$(curl -s "https://pokeapi.co/api/v2/generation/$gen_id")

            ui_top
            ui_title "REGIÓN: ${regiones[$sel]^^}"
            ui_sep
            echo "$data" | jq -r '.pokemon_species[].name' | sort | xargs -n 3 | while read -r c1 c2 c3; do
                ui_line "$(printf '%-16s %-16s %-16s' "${c1^^}" "${c2^^}" "${c3^^}")"
            done
            ui_bottom
            echo ""
            printf '%s Escribe un nombre para inspeccionarlo (o Enter para Volver): %s\n' "$BG$FG" "$RESET"
            read -r poke_elegido
            [[ -n "$poke_elegido" ]] && buscar_pokemon "$poke_elegido"
            return
        fi
    done
}

filtrar_por_tipo() {
    local tipos_es=("Normal" "Lucha" "Volador" "Veneno" "Tierra" "Roca" "Bicho" "Fantasma" "Acero" "Fuego" "Agua" "Planta" "Eléctrico" "Psíquico" "Hielo" "Dragón" "Siniestro" "Hada" "Volver")
    local tipos_en=("normal" "fighting" "flying" "poison" "ground" "rock" "bug" "ghost" "steel" "fire" "water" "grass" "electric" "psychic" "ice" "dragon" "dark" "fairy")
    local sel=0

    while true; do
        clear
        ui_top
        ui_title "SELECCIONA UN TIPO"
        ui_sep
        for i in "${!tipos_es[@]}"; do
            [[ $i -eq $sel ]] && ui_item "${tipos_es[$i]}" 1 || ui_item "${tipos_es[$i]}" 0
        done
        ui_bottom

        read -rsn1 tecla
        if [[ $tecla == $'\e' ]]; then
            read -rsn2 tecla
            case "$tecla" in
                "[A") ((sel--)); if [[ $sel -lt 0 ]]; then sel=$((${#tipos_es[@]} - 1)); fi ;;
                "[B") ((sel++)); if [[ $sel -ge ${#tipos_es[@]} ]]; then sel=0; fi ;;
            esac
        elif [[ -z $tecla ]]; then
            if [[ "${tipos_es[$sel]}" == "Volver" ]]; then return; fi

            clear
            echo "Descargando registros de tipo ${tipos_es[$sel]}..."
            local tipo_id="${tipos_en[$sel]}"
            local data=$(curl -s "https://pokeapi.co/api/v2/type/$tipo_id")

            ui_top
            ui_title "TIPO: ${tipos_es[$sel]^^}"
            ui_sep
            echo "$data" | jq -r '.pokemon[].pokemon.name' | sort | xargs -n 3 | while read -r c1 c2 c3; do
                ui_line "$(printf '%-16s %-16s %-16s' "${c1^^}" "${c2^^}" "${c3^^}")"
            done
            ui_bottom
            echo ""
            printf '%s Escribe un nombre para inspeccionarlo (o Enter para Volver): %s\n' "$BG$FG" "$RESET"
            read -r poke_elegido
            [[ -n "$poke_elegido" ]] && buscar_pokemon "$poke_elegido"
            return
        fi
    done
}

# ==============================================================================
# MENU INTERACTIVO PRINCIPAL
# ==============================================================================
OPCIONES=("Buscar Pokémon" "Filtrar por región" "Filtrar por tipo" "Acerca de" "Salir")
SELECCION=0

dibujar_menu() {
    clear
    ui_top
    ui_title "POKÉDEX BASH"
    ui_sep
    for i in "${!OPCIONES[@]}"; do
        [[ $i -eq $SELECCION ]] && ui_item "${OPCIONES[$i]}" 1 || ui_item "${OPCIONES[$i]}" 0
    done
    ui_bottom
}

while true; do
    dibujar_menu
    read -rsn1 tecla
    if [[ $tecla == $'\e' ]]; then
        read -rsn2 tecla
        case "$tecla" in
            "[A") ((SELECCION--))
                 if [[ $SELECCION -lt 0 ]]; then SELECCION=$((${#OPCIONES[@]} - 1)); fi ;;
            "[B") ((SELECCION++))
                 if [[ $SELECCION -ge ${#OPCIONES[@]} ]]; then SELECCION=0; fi ;;
        esac
    elif [[ -z $tecla ]]; then
        case $SELECCION in
            0) buscar_pokemon ;;
            1) filtrar_por_region ;;
            2) filtrar_por_tipo ;;
            3) clear
               ui_top
               ui_title "ACERCA DE"
               ui_sep
               ui_line "Poke-Bash v1.2.0 - Desarrollado por s0rcen."
               ui_line "Usa PokeAPI y Chafa para gráficos de terminal."
               ui_bottom
               read -rsn1 -p "Presiona cualquier tecla para volver..." ;;
            4) clear; echo "¡Adios, Entrenador!"; exit 0 ;;
        esac
    fi
done
