# Dupe Editor
A dupe editor and viewer for GMOD inspired by NBTEdit for Minecraft.

# Installation

1) Open a window here ``\Steam\steamapps\common\GarrysMod\garrysmod\addons`` 
2) Drop the ``dupe_editor`` folder in there
3) Start a new map if already in one

# Usage
1) Open the console and type ``dupe_editor``
2) Select a dupe you would like to mess with
   
NOTE: Every table key/value can be right-clicked

![image](https://github.com/user-attachments/assets/a6082f2e-6f0a-4fd1-9c78-ac5712c8bd85)

# Features
## Clone Armed Dupe
> it's basically a dupe stealer if you want to call it like this,

Arm a dupe that you are subscribed to in the workshop (load one in the duplicator tool) this button will locally save it

## Open entity list
Will open a new window that will show you all entities on the map

![image](https://github.com/user-attachments/assets/a5d7200c-c947-4c37-a202-35e799cba4f8)

# Development notes

Basically I wrote this because I wanted to find potential bugs/exploits in either gmod itself or addons, which I did !

SOOO, some features are purely made for myself like ``Remove bottom 5% smallest props`` if you find it, don't click it, because it will calculate all ``Mins`` and ``Maxs`` of all entities in a dupe, and remove the smallest.

Stuff like that

--

You can copy and paste an entity's data directly into the dupe you are editing, by simply right-clicking on a table and hitting ``Insert copied entity`` 
**NOTE**: There are two methods to copy data, ``NET`` and ``JSON``. JSON will save everything (best one) NET is slightly limited in its own way, but works.

The advantage of copying with JSON, is that the copy gets saved to ``\Steam\steamapps\common\GarrysMod\garrysmod\data\dupe_editor_json.json`` 
which will make editing a dupe also viable externally

-- 

Also there are tiny bugs, will not fix anytime soon, or perhaps whenever I have time/will to update.

Other than that.. don't publish this in the workshop pls? It's in a stable but unfinished state
