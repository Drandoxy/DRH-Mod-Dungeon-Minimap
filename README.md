# Dungeon Minimap

<!-- drh:show -->
A zoomable map with dungeon-specific palettes, walls, purple breakable-wall markers, chests, and party portraits. The footer shows gold and XP collected during the run.

Use **- / +** to zoom. At higher zoom, the map follows you. Drag inside the map to look around, or drag the header to move the panel. Drag a bottom corner to resize it. The mod remembers your layout and zoom.

Exit colors follow Xk's Minimap: orange for a trigger, purple for enemy kills, cyan for a breakable blocker, green for open, red for closed, and grey for unknown.

Press **Ctrl + Shift + M** or use **Enable minimap** in Settings to turn it on or off. Turning it off stops map rendering and updates.

Based on [Xk's Minimap](https://github.com/Xkaka505/DRH-Mod-Minimap). Use one minimap mod at a time. This mod can run alongside Party DPS Meter, which uses the same player colors.
<!-- /drh:show -->

## Preview

![Dungeon minimap](docs/images/knight-fortress.png)

### Zoomed view

![Zoomed minimap](docs/images/zoomed.png)

*Knight Fortress (zoomed in)*

### Hidden wall marker

![A cracked wall in the dungeon and its purple minimap marker](docs/images/hidden-wall.png)

*Breakable walls are marked with a purple crack on the minimap.*

### Map themes

One screenshot per palette, ordered by first appearance in the campaign.

<table>
  <tr>
    <td align="center" width="25%"><img src="docs/images/knight-fortress.png" alt="Knight Fortress / Arena minimap" width="180"><br><sub>Knight Fortress / Arena</sub></td>
    <td align="center" width="25%"><img src="docs/images/icewater-cavern.png" alt="Caverns / Icewater Caverns minimap" width="180"><br><sub>Caverns / Icewater Caverns</sub></td>
    <td align="center" width="25%"><img src="docs/images/barrows.png" alt="Dark Barrows / Barrows minimap" width="180"><br><sub>Dark Barrows / Barrows</sub></td>
    <td align="center" width="25%"><img src="docs/images/jungle.png" alt="Twisted Jungle / Jungle minimap" width="180"><br><sub>Twisted Jungle / Jungle</sub></td>
  </tr>
  <tr>
    <td align="center" width="25%"><img src="docs/images/prison.png" alt="Prisoner's Keep / Prison minimap" width="180"><br><sub>Prisoner's Keep / Prison</sub></td>
    <td align="center" width="25%"><img src="docs/images/battleheim.png" alt="Battleheim minimap" width="180"><br><sub>Battleheim</sub></td>
    <td align="center" width="25%"><img src="docs/images/dino-park.png" alt="Cretaceous Park / Dino Park minimap" width="180"><br><sub>Cretaceous Park / Dino Park</sub></td>
    <td align="center" width="25%"><img src="docs/images/frostgaard.png" alt="Frostgaard / Norse Nightmare minimap" width="180"><br><sub>Frostgaard / Norse Nightmare</sub></td>
  </tr>
  <tr>
    <td align="center" width="25%"><img src="docs/images/ruins.png" alt="The Lost Ruins / Ruins minimap" width="180"><br><sub>The Lost Ruins / Ruins</sub></td>
    <td width="25%"></td>
    <td width="25%"></td>
    <td width="25%"></td>
  </tr>
</table>

Requires DRH 18 and Mod API 1.4.0 or a compatible later 1.x version. [GPLv3](LICENSE).
