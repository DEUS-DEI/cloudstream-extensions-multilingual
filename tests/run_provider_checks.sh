#!/usr/bin/env bash
set -e
providers=(
  AnimefenixProvider
  AnimeflvIOProvider
  AnimeflvnetProvider
  CinecalidadProvider
  CuevanaProvider
  DoramasYTProvider
  ElifilmsProvider
  EntrepeliculasyseriesProvider
  EstrenosDoramasProvider
  JKAnimeProvider
  MonoschinosProvider
  MundoDonghuaProvider
  PeliSmartProvider
  PelisflixProvider
  PelisplusHDProvider
  PelisplusProvider
  SeriesflixProvider
  TocanimeProvider
)
OUT=tests/test_results.md
echo "# Resultado de pruebas de providers" > "$OUT"
echo "Fecha: $(date -u +'%Y-%m-%d %H:%M:%SZ') (UTC)" >> "$OUT"
echo "" >> "$OUT"
UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
for p in "${providers[@]}"; do
  echo "## $p" >> "$OUT"
  main=$(grep -R "override var mainUrl" -n "./$p" 2>/dev/null | head -n1 | sed -E 's/.*mainUrl = \"(.*)\".*/\1/')
  if [ -z "$main" ]; then
    echo "mainUrl: (no encontrado en código)" >> "$OUT"
    echo "status: no-check" >> "$OUT"
    echo "" >> "$OUT"
    continue
  fi
  echo "mainUrl: $main" >> "$OUT"

  # Default headers
  H_COMMON=( -H "User-Agent: $UA" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" )

  # Provider-specific header tweaks
  H_EXTRA=()
  case "$p" in
    AnimeflvIOProvider|AnimeflvnetProvider)
      H_EXTRA=( -H "Host: www3.animeflv.net" -H "Alt-Used: www3.animeflv.net" -H "Referer: https://www3.animeflv.net" ) ;;
    JKAnimeProvider)
      H_EXTRA=( -H "Host: jkanime.net" -H "Origin: https://jkanime.net" -H "Referer: https://jkanime.net" ) ;;
    TocanimeProvider)
      H_EXTRA=( -H "Host: tocanime.co" -H "Origin: https://tocanime.co" -H "Referer: https://tocanime.co" ) ;;
    MonoschinosProvider)
      # user provided monoschino2.com exact domain
      H_EXTRA=( -H "Host: monoschino2.com" -H "Referer: https://monoschino2.com" ) ;;
    *)
      H_EXTRA=()
      ;;
  esac

  # perform a HEAD-like check (follow redirects) to get final status and URL
  # Use curl -I -L may still return 405 for some servers; use -s -S -D - -o /dev/null -L
  CMD=(curl -s -S -L -m 15 -D - -o /dev/null)
  CMD+=("-A" "$UA")
  for h in "${H_EXTRA[@]}"; do CMD+=($h); done
  CMD+=("$main")

  # Run command and capture HTTP status and final URL
  # We'll run a lightweight GET to get status and first-line snippet as well
  STATUS_OUTPUT=$("${CMD[@]}" 2>/dev/null | head -n 20)
  # extract HTTP/.. status lines
  HTTP_CODES=$(echo "$STATUS_OUTPUT" | grep -E '^HTTP/' || true)
  if [ -z "$HTTP_CODES" ]; then
    echo "http_raw: (no response or blocked)" >> "$OUT"
  else
    echo "http_raw:" >> "$OUT"
    echo '```' >> "$OUT"
    echo "$HTTP_CODES" >> "$OUT"
    echo '```' >> "$OUT"
  fi

  # Try a small GET body capture (first 1200 chars) for basic validation
  GET_CMD=(curl -s -S -L -m 15)
  GET_CMD+=("-A" "$UA")
  for h in "${H_EXTRA[@]}"; do GET_CMD+=($h); done
  GET_CMD+=("$main")
  BODY=$("${GET_CMD[@]}" 2>/dev/null | tr -d '\r' | sed -n '1,80p') || true
  if [ -z "$BODY" ]; then
    echo "body_snippet: (no content fetched)" >> "$OUT"
  else
    echo "body_snippet:" >> "$OUT"
    echo '```html' >> "$OUT"
    echo "$BODY" >> "$OUT"
    echo '```' >> "$OUT"
  fi

  # Quick checks: presence of common keywords
  has_anime=$(echo "$BODY" | grep -Ei "anime|animes|episodios|pelicula" || true)
  if [ -n "$has_anime" ]; then
    echo "content_check: ok (contains anime-related keywords)" >> "$OUT"
  else
    echo "content_check: uncertain (no obvious anime keywords in snippet)" >> "$OUT"
  fi

  echo "" >> "$OUT"
done

echo "Tests completados. Resultado guardado en $OUT"
