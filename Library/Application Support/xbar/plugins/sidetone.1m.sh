#!/bin/bash
# <xbar.title>Headset sidetone</xbar.title>
# <xbar.desc>Sets the headset sidetone level with headsetcontrol -s [0-128]. Hidden when no headset is connected.</xbar.desc>
# <xbar.dependencies>headsetcontrol</xbar.dependencies>

HSC=/opt/homebrew/bin/headsetcontrol
STATE="$HOME/.cache/xbar-sidetone"

if [ "$1" = "set" ]; then
  if "$HSC" -s "$2" >/dev/null 2>&1; then
    mkdir -p "$(dirname "$STATE")"
    echo "$2" > "$STATE"
  fi
  exit 0
fi

# No output makes xbar remove the item from the menu bar.
"$HSC" -o json 2>/dev/null | grep -q '"device_count": *[1-9]' || exit 0

ICON="iVBORw0KGgoAAAANSUhEUgAAACoAAAApCAYAAABDV7v1AAAAAXNSR0IArs4c6QAAAGxlWElmTU0AKgAAAAgABAEaAAUAAAABAAAAPgEbAAUAAAABAAAARgEoAAMAAAABAAIAAIdpAAQAAAABAAAATgAAAAAAAACQAAAAAQAAAJAAAAABAAKgAgAEAAAAAQAAACqgAwAEAAAAAQAAACkAAAAA+ZA23QAAAAlwSFlzAAAWJQAAFiUBSVIk8AAAA15JREFUWAntmDmMTVEYx59938koLJFJEEYUNEQ0EyqZiK0QSzHRiYiCREjUTGEIChJboTAJQWMKCRISayE0EvsSCtvYxfD7ZuZ4x/fOdq/3KLwv+b97zrf8v++e5Z57X6FQlf90BLqV6b5HwlMLhoP+4At4C+6Dp+AH+CfSm6wN4Ch4BKQQH15jOwPWgGHgr0gvsqwHT4CvsJD+A3HNYBSomMyA+Q4IFZJqewXPiiyVpq7RlZDuB3085DK9t8BjIKPWF9SAKWAs8MkeDOtAu88hi76xi0iPVhv6nWAmCN3wBOybwEOgOaR/GITiMcelHpdvQCc4hE52ehaR9b0RfAKabxu63CI79BmwSaXo1bkZOwNlrT8HNu93+nM6zdl/9yoyIV6encYZMQmtPGftYm/T7+H0DihlXekp3xfwz2NaSpBdqLRXZSVqUiR36ctOLrccgdAu9nqWBN1xfqEIMj3zMiQbj6+euWmp8bNVkS/py5FZKTkBsT2qW1yJZPS0zFWKU/S/Kl05u8cVmc6vzMVuC037Dsu104sZfm+NVvnkeE2Sm3jZhU5OivozJ/28LnnLck39GJVTjr5KywOVQNdQcBU60AqS405QadHTbdfQkdtVqL3DK7mJ7JuXLwJbSt7SXIXaQSUBNlsZ2/ow+ay5e2oFfTmD+3XphUDaI8B8IKPdCu6BvDKUwAYg03sZyOaVby1bpIao3MDD3vW76dunhyyHvI+sOmL1qXcMnfkANHmHoItKCx4mwHd9j48ehSgxDpcSuPXG6uB1rVF53YrJAByWxJyUfSL9WUrn6jrzuwq95op26BY7dCFVqv/VEIltkyltB75pN3pZq7IxUkUKMLGh66JUQvG7kkgqX6cpMg6nUHHGJpvWefOuqZfEp+UnQVKnM3WULpLzTULeXy61tMxdhq4f8ZONFZMLOIR4jK0xRuSyn08kl2+fkNRglK9MU4zv2obPYB+Rb+rFv9kXpPTzVF9361GE8hj/gzTemY6+hghO4ux8pikS5+K3fEreLS2bacr7RZPp5LkuIMg3VUa/NkI8HXvscbcjwpFklp29C2wF9pkvhcqoy181MdmMg16nB9BtBxuA6+UIdVGy/jk1ldBlQIhls7WCVKnDcSEYBM6Bs6Aq1RGIjcBPelxR5RYUGfUAAAAASUVORK5CYII="

current=$(cat "$STATE" 2>/dev/null)
echo "| templateImage=$ICON"
echo "---"
echo "Sidetone level (last set: ${current:-unknown})"
for level in 0 16 32 48 64 80 96 112 128; do
  mark=""
  [ "$level" = "$current" ] && mark=" ✓"
  echo "$level$mark | bash='$0' param1=set param2=$level terminal=false refresh=true"
done
