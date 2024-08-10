# gridmap-plus
Plugin with an upgraded Minecraft-style editor.  

### How to use

Install the plugin like other Godot plugins, by copying the addons folder into your project and enabling the addon via project settings.

When selecting a Grid Map, a new dock is available at the bottom of the screen. It has a button "Enter build mode" which launches a Minecraft-style editor for a grid map. If you select a mesh in 3D mode you can also set some placement and shortcut rules for that mesh which will affect the editor behavior.

Inside the editor, the following controls can be used:

* WSAD - move around
* Move mouse to look around
* Mouse left click - place mesh
* Mouse right click - erase mesh
* Q and E - select mesh type
* Mouse middle click - select mesh type you're pointing at
* Space - fly upwards
* Control - fly downwards
* Shift + WSAD - pitch or yaw mesh
* Shift + QE - roll mesh
* Number key - hotbar
* Hold mouse left click when in open space - force placement of block at player location

This is a first version, improvements are planned to support different control styles, keyboards, etc.

### License

This code is public domain as per the unlicense license. However, the code for displaying axis lines inside the editor is a port of a function from the Godot engine, and as such that function is provided under the permissive MIT license, I guess.

### Contact

Feel free to report bugs here, or find me (Portponky) on the Godot official discord server. Have fun!
