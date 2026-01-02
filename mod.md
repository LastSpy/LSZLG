# **Architectural Analysis and Technical Modding Potential in VCMI: A Comprehensive Report**

## **Executive Summary**

The VCMI project is not just a modification of the classic game *Heroes of Might and Magic III* (HoMM3), but a complete reconstruction of the game engine with open source code written in C++.1 This fundamental architectural difference determines the "ceiling of possibilities" for modding: instead of injecting code into a closed executable file or manipulating memory (as was done in the era of *In the Wake of Gods* or *HD Mod*), mod developers in VCMI interact with a system that was originally designed for extensibility.

This report presents a comprehensive technical analysis of the VCMI modding ecosystem. It examines the engine architecture based on the separation of data and logic, the JSON configuration system, the integration of Lua scripts for creating dynamic logic, and resource management pipelines. In addition, it evaluates the current limitations (hard-coded elements) in comparison with the broad possibilities offered by the new architecture, allowing us to form a roadmap of what is achievable within the current state of the engine.

The analysis is based on studying the project documentation, the structure of GitHub repositories, and the technical specifications of data formats. The main conclusion of the study is that VCMI transforms modding from a process of "hacking" into a process of systematic design, where the only significant limitations remain the labor intensity of creating assets and the complexity of AI algorithmic logic.

## --- 

1\. Architectural foundations of modding in VCMI 

To appreciate the depth of modding possibilities in VCMI, one must first understand the architecture of the engine, which is based on a strict separation of data from executable code and logic from presentation. This segregation is the cornerstone of the system's high extensibility.

### **1.1 Client-Server-Library Model**

Unlike the original HoMM3 engine, which was a monolithic application, VCMI is a distributed system consisting of three main components: Client (VCMI\_client), Server (VCMI\_server), and Shared Library (VCMI\_lib).3 This structure is critical to understanding how mods work.

**VCMI\_server** acts as an authoritative state manager. It handles all game mechanics, artificial intelligence (AI) logic, events on the map, and stores the "true" state of the game world. In single-player mode, the server runs as a separate thread or process, but its logical separation remains strict.3 This means that any modifications affecting the game rules (e.g., changing spell damage or hero movement logic) must be interpreted correctly by the server. The server thread (runServer) constantly runs the boost::asio I/O service and processes requests from players (both human and AI).3

**VCMI\_client** is responsible for visualizing the game state for the user, playing audio, and collecting input (key presses, mouse clicks). . The client communicates with the server via network packets, even if the game is running on a single local computer.4 For modding, this separation dictates an important rule: visual mods (interface, graphics replacement) work exclusively on the client side, while gameplay mods require synchronization. The client's main thread (MainGUI) is responsible for rendering and input processing, updating the screen based on data received from the server.3

**VCMI\_lib** is a dynamically linked library (DLL/.so) containing code and data structures common to both the client and server. It contains JSON configuration parsers, a resource management system, and definitions of base classes (creatures, artifacts, cities).3 It is important to note that although the library code is shared, the library instances in memory for the client and server are separate, which prevents accidental client interference with server data.

Impact on mod development:  
This architecture imposes certain requirements on the structure of mods. A mod that adds new mechanics (e.g., a unit with a unique ability) must be loaded correctly by both the client and the server to avoid desync errors. In older H3 modding methods, "Out of Sync" errors were the bane of multiplayer due to memory inconsistencies. In VCMI, strict isolation and batch data transfer minimize this risk, but require the modder to understand where their code is executed. Lua scripts, for example, can run both on the server (to change the state of the world) and on the client (to render effects), and data transfer between them must be carried out through the engine's synchronization mechanisms.5

### **1.2 Data-Driven Design and JSON Standardization**

The most significant departure from the original H3 architecture is the abandonment of hard-coded binary tables and text files (.txt, .bin) within monolithic archives (.lod). VCMI uses a data-driven approach, where virtually every game entity — cities, heroes, creatures, spells, and artifacts — is defined in external JSON configuration files.3

This shift significantly raises the ceiling for modding:

* **No hard limits:** In the original engine, adding a new city required replacing an existing one or performing complex memory hacks, as the sizes of city structure arrays were fixed. In VCMI, entities are stored in dynamic containers (std::vector, std::map), which allows you to add any number of new cities, creatures, and artifacts. The only limitation is the amount of RAM available on your system.2  
* ** Inheritance and overriding:** The JSON system supports object-oriented design concepts. A mod can define a new object that inherits properties from a "core" object (for example, a new archer based on core:archer) and override only specific fields (for example, change hitPoints or attack). This makes balance-changing mods extremely lightweight and compatible with each other, as they do not overwrite the entire object, but only make delta changes.6

### **1.3 Game Identifier System (Namespacing)**

VCMI implements a robust namespacing system to manage content from multiple mods simultaneously without identifier conflicts. In traditional modding, the use of numeric IDs (e.g., creature ID 15) led to conflicts when two different mods attempted to use the same slot. 

VCMI replaces numeric IDs with string identifiers structured as modScope:objectName 6:

* **Core Content:** Accessible via the core: prefix (e.g., core:archer, core:castle, core:resource.gold).  
* **Mod Content:** A mod named "myNewTown" would define objects as myNewTown:superDragon.  
* **Cross-Mod Reference:** A submod or compatibility patch can reference objects from the parent mod using the syntax parentMod:objectName.6

This system is the technical foundation for the "Mod Repository," allowing users to install dozens of creature packs and new towns simultaneously. The engine dynamically assigns numerical IDs during runtime, ensuring that myNewTown:superDragon receives a unique internal index regardless of what other mods are currently loaded. This solves one of the oldest and most painful problems of HoMM3 modding—incompatibility.6

**2\. Mod creation infrastructure and workflow**

The VCMI team has developed a standardized workflow for creating, packaging, and distributing modifications. This infrastructure is designed to resemble modern software package management systems.

### **2.1 Directory structure and mod.json manifest**

Each VCMI mod is a self-contained folder with a strictly defined structure, centered around the mod.json manifest file.6 This file serves as an entry point for the engine, explaining what the mod is, what its dependencies are, and how to load it.

mod.json manifest:  
This JSON object contains metadata and loading directives. Let's take a closer look at the key fields based on 7:

* **Identification:** name, author, version (e.g., "1.0"), description (supporting a subset of HTML for formatting in the launcher).  
* **Typing (modType):** Mod categorization, e.g., "Town," "Creatures," "Interface," "Mechanics," "Translation." The "Translation" type is only activated if the player's base language matches the mod's language.7  

* **Dependency management:**  
  * depends: Hard dependencies. The mod will not load without the mods listed here (array of ID strings).  
  * softDepends: Loading order directives. If the specified mod is present, it will be loaded *before* the current one. This is critical for compatibility patches that need to overwrite the original data.7  
  * conflicts: An explicit list of incompatible mods. The engine will issue a warning or error if the user attempts to enable them simultaneously.7  
* **Compatibility:** An object with min and max fields specifying the supported versions of the VCMI engine (e.g., "1.2.0" \- "1.3.0"). This prevents breakage when the engine API is updated.7  
* **Content registration:** The manifest explicitly lists the paths to configuration files for different types of entities. For example:  
  JSON  
  "creatures" :,  
  "factions" :,  
  "artifacts" :

  This allows the engine to load only the necessary files without scanning the entire directory.6

File system hierarchy:  
The typical structure separates configuration logic and binary assets 6:

* /config/: Contains JSON definitions of logic (creatures, cities, spells).  
* /content/: Contains raw assets (graphics in .def, .png, .bmp formats; audio in .ogg, .wav).  
* /sprites/: Contains JSON definitions of animations (an alternative to the outdated .def format).  
* /translations/: Localization files for multilingual support.  
* /maps/: Maps in .h3m or the new .vmap format added by the mod.

### **2.2 VCMI Mod Repository**

VCMI includes a mod manager built into the launcher that connects to a centralized repository hosted on GitHub (vcmi-mods-repository). This system provides:

1. **Automatic updates:** The launcher checks the repository's JSON files (e.g., vcmi-1.x.json) to detect new versions of installed mods.   
2. **Versioning:** Mods can be tied to specific engine development branches (develop vs stable), allowing users of "daily builds" to test experimental mods without breaking the game for users of stable versions.6  
3. **Quality control:** The VCMI team acts as gatekeepers, ensuring that mods in the default repository meet basic quality standards: they do not cause crashes on load, have correct JSON syntax, use optimized audio formats (Ogg/Vorbis), and do not contain direct links to third-party resources.6

Modder's toolkit:  
Although manual JSON editing is the primary method, the community has developed tools such as the Modders' Tool Pack to help generate template code and validate file structures. 9 Using GitHub to host individual mods 8 encourages the use of version control systems, open collaboration (forking), and issue tracking, raising the level of development from amateur to semi-professional.

## ---

**3\. Deep Dive: Modding Entities via JSON**

The core of modding in VCMI is defining game entities. The engine supports a wide range of configurable objects, going far beyond the capabilities of the original game. Let's take a look at the key formats.

### **3.1 Towns and Factions (Town Format)**

Creating a new town is one of the most complex but fully supported features of VCMI. A town mod includes defining faction logic, the town screen, map objects, and the building tree.

**City Architecture (JSON):**

* **General Settings:** Music themes, map icon, alignment, and native terrain.
* **Town Screen:** VCMI allows you to define the X/Y coordinates and Z-index (rendering order) of each building on the town screen. Unlike H3, where building positions were hard-coded to their IDs, VCMI provides complete visual freedom. Building animations can be defined via .def or image sequences.11  
* **Building Tree:** Modders define a dependency graph. For example, "Mage Guild Level 2 requires Mage Guild Level 1 and a Forge." This is not limited to the standard H3 tree; completely new dependency structures can be created.  
* **Special Buildings:** Support for "Grail" and "Horde" type buildings (which increase creature growth) is fully data-driven. The horde fields in the building configuration allow you to specify which creature's growth is increased and by how much.11  
* **Unique mechanics:** Buildings can provide bonuses through the **Bonus System**. For example, the "Order of Fire" building can give +1 to the Magic Power of the visiting hero. This is implemented through a bonus of type PRIMARY\_SKILL with subtype spellpower and value 1, tied to the visit event.11

Ceiling of possibilities for cities:  
There are practically no limitations in terms of structure. You can create a city with 10 upgradeable creature dwellings or a city with unique economic buildings that generate rare resources. The main limitation is artistic (creating high-resolution assets) rather than technical.

### **3.2 Creatures and Units (Creature Format)**

The creature configuration allows you to create completely new units or modify existing ones.

**Configuration parameters:**

* **Characteristics:** Attack, Defense, Damage (min/max), Health, Speed, Growth, Cost.  
* **AI Value:** Modders can manually set a unit's "value," which dictates how the AI prioritizes it in combat and how the Random Map Generator (RMG) balances guarding. If no value is set, the engine calculates it automatically based on stats.6  
* **Abilities (Bonus System):** This is where the power of VCMI is revealed. Instead of hard bit flags (as in H3 cr\_flags), abilities are defined as bonuses. A creature can receive bonuses such as FLYING, SHOOTER, or more complex ones such as SPELL\_AFTER\_ATTACK.13

**Extensibility:**

* **Upgrades:** The engine supports flexible upgrade paths. A unit can be upgraded into several different creatures (branching upgrades), or several different units can be upgraded into one. This is determined by the upgrades list in JSON.6
* **Graphics:** Support for 32-bit PNGs with alpha channels for creature animations allows for much higher visual clarity than the original 8-bit DEF files.6

### **3.3 Artifacts and Items (Artifact Format)**

Artifacts are defined similarly, specifying equipment slots and bonuses provided.

**Key features:**

* **New slots:** Although standard H3 slots are supported (Head, Torso, Miscellaneous, etc.) are supported, the flexibility of the engine theoretically allows for new slot types to be introduced if the mod interface supports their display.   
* **Set Items:** Set items (such as *Alliance of Angels*) are supported through configuration. Modders can create new "sets" that activate a hidden artifact (set bonus) when all components are equipped.14  
* **Active Abilities:** Through the Bonus System, artifacts can grant active abilities to spells or passive auras.

### **3.4 Heroes and Classes (Hero Format)**

Modders can define new hero classes (e.g., "Death Knight") and individual heroes.

**Hero Customization:**

* **Specializations:** Hero specializations are defined through the Bonus System. This allows you to create specializations that are not possible in H3, such as a hero who grants a specific resource bonus or increases the speed of *all* infantry units, not just a specific type.   
* **Starting Army:** Fully configurable.  
* **Skills:** The probability of secondary skills appearing when leveling up for each class is set in probability tables inside JSON.16.  

## ---

**4\. Scripting layer: Lua integration**

While JSON manages static data and standard mechanics, the "ceiling of possibilities" is raised to unlimited heights thanks to the Scripting System. VCMI has integrated **Lua** (via LuaJIT) to replace and surpass the outdated ERM (Event Related Model) used in WoG.5

### **4.1 Scripting Engine Architecture**

The scripting system is event-driven. Scripts do not run in a continuous loop, but respond to specific triggers (Events) generated by the engine.5

**Execution contexts:**

* **Server scripts:** Handle game logic, state changes, AI decisions, and events on the map. This is the most important part for gameplay mods.  
* **Client scripts:** Process UI updates, visual effects, and local user input.  
* **Shared scripts:** Code that runs on both sides to ensure consistency.5

Event Bus:  
The central mechanism is EVENT\_BUS. Scripts "subscribe" to events using the subscribeBefore (execute before the engine processes the event) or subscribeAfter (execute after) hooks.

* *Example:* A script can subscribe to the PlayerGotTurn event. When this event occurs, the script executes custom logic (e.g., gives the player resources or spawns a monster on the map).5

### **4.2 Lua API Capabilities**

The VCMI Lua API provides access to the deep internal state of the game through global objects:

* **SERVICES:** Provides "raw" access to static data (artifacts, creatures, spells). This allows a script to dynamically query: "What is the Black Dragon's value in gold?"5   
* **GAME / BATTLE:** Access to the current state of the adventure map or active combat session. You can get information about hero positions, squad health, etc.  
* **DATA:** A persistent storage table that allows mods to save their custom data (e.g., quest state variables) to the game save file, allowing progress to be tracked between sessions.5

Comparison with ERM:  
The outdated ERM used cryptic digital receivers (e.g., \!\!UN:P). Lua offers readable, structured code with standard control structures (loops, functions, tables). VCMI supports some ERM commands for backward compatibility with WoG mods, but Lua is the main vector of development. For example, the complex taxation logic ("Peasant Taxes"), which checks the composition of the army and deducts gold, is written in Lua in a few lines of understandable code, while in ERM it requires complex manipulation of variables.17

### **4.3 Scripting Limitations (Current Status)**

Despite its power, the system is still evolving.

* **Documentation:** The API is under active development, and documentation may lag behind.  
* **Event coverage:** Not every engine event is exported to Lua. While "start of turn" or "visit object" are covered, deep hooks into the combat AI decision-making process or the low-level rendering pipeline may not be available.5

## ---

**5\. "Bonus System": The logical core of the engine**

A unique and powerful feature of VCMI is the **Bonus System**. It serves as a middleware layer between raw JSON data and hard-coded C++ mechanics.

### **5.1 Mechanics as Bonuses**

In traditional engines, an artifact that gives "+2 Attack" may be hard-coded as hero.attack \+= 2\. In VCMI, it is an instance of the **Bonus** object.

* **Structure:** A bonus has a type (e.g., PRIMARY\_SKILL), subtype (e.g., ATTACK), val (value), and propagator (who gets the bonus?).13

### **5.2 Bonus Extensibility**

This system allows mechanics to be applied in a generalized way.

* **Propagators:** A bonus can be set to propagate from a Hero to their Army (HERO\_TO\_CREATURE), from a City to a visiting Hero, or from a Player to all of their Heroes (PLAYER\_PROPAGATOR).  
* **Limiters:** Bonuses can be conditional. The Mountain Slayer sword can give +50 Attack, but only if the limiter is set to terrain:mountains or creature.alignment:dungeon.  
* **New mechanics:** Modders can combine these parameters to create complex effects without writing code. For example, an artifact that gives "+1 Speed to all Dragons" is simply a bonus of type STACKS\_SPEED with a value of 1 and a limiter subtype:dragon.11

**List of configurable mechanics (partial):**

* STACK\_HEALTH (stack health), STACKS\_SPEED (speed), CREATURE\_DAMAGE (damage).  
* SPELL IMMUNITY, SPELL SCHOOL IMMUNITY.   
* DOUBLE DAMAGE CHANCE, FEARFUL (fear), RECEPTIVE (receptive to healing/resurrection).13   
* FREE_SHOOTING (shooting without penalty), BLOCKS_RETALIATION (non-retaliatory attack).

## ---

**6\. Asset Management Pipeline**

VCMI modernizes the asset pipeline, eliminating the need for archaic tools (such as MMArchive) to inject files into binary archives.

### **6.1 Graphics**

* **Formats:** Supports .png, .bmp, and the outdated .pcx (inside LOD archives).
* **Animation:** Supports the original .def format. However, VCMI has also implemented the **JSON Animation Format**. This allows modders to use a folder with regular PNG frames and a JSON text file to define the animation sequence, frame rate, and offsets. This radically lowers the entry threshold for artists by eliminating the need to compile complex binary files.6  
* **High Resolution:** The engine natively handles high resolutions and interface scaling. This means that assets can be created with higher detail than in the original game.18

### **6.2 Audio and Video**

* **Audio:** The preferred format is Ogg/Vorbis (.ogg), which provides better compression and quality compared to the original WAV. MP3 is also supported.6 Sound configuration (binding a file to an event) is done via JSON.  
* **Video:** Modern codecs such as .webm (VP8/VP9) are supported, along with the older .bik (Bink) and .smk (Smacker). This allows for the integration of high-quality cutscenes with high compression efficiency.19

## ---

7. Ceiling of possibilities: Reality versus Theory

To answer the user's question about the "ceiling of possibilities," it is necessary to clearly distinguish between what can be created with standard tools and what requires intervention in the engine's source code (C++).

### **7.1 What we can create (Possibilities)**

1. **Infinite content expansion:** There is no hard limit on the *number* of cities, creatures, or artifacts. Theoretically, it is possible to create a mod with 100 new factions, if the user's RAM allows it.20  
2. **Total Conversions:** Since the interface, map objects, and text are stored in external files, you can completely "redress" the game in a science fiction setting, replacing gold with "Credits" and horses with "Hoverbikes" using the string replacement and asset redefinition system.   
3. **Complex RPG maps:** Using Lua scripts and the quest system, map builders can create deep narrative adventures with branching dialogues, custom inventory systems (via DATA variables), and scripted cutscenes (via camera control and text output).17  
4. **Advanced combat mechanics:** Through the Bonus System and Lua hooks (e.g., subscribeBefore attack), you can implement mechanics such as "Vampirism that only works at night" or "Units that explode upon death and deal area damage."  
5. **New spells:** By combining effects and scripts, you can create spells with complex logic that goes beyond the standard "deal damage" or "summon a creature."

### **7.2 What remains hard-coded (Limitations)**

1. **Battlefield topology:** The game is strictly tied to a hexagonal grid. It is impossible to change the battlefield to a square grid or free movement without rewriting the engine core.  
2. **Core Combat Loop:** The sequence "Initiative \-\> Movement \-\> Attack \-\> Counterattack" is hard-coded into the engine's state machine. Although parts of this loop can be interrupted by scripts, it is impossible to fundamentally change the turn-based nature of combat.  
3. **Artificial Intelligence (AI):** Adventure AI (Nullkiller) and Combat AI are written in C++. Modders can adjust *parameters* (e.g., how much the AI values a particular mine or unit via aiValue), but cannot easily script entirely new strategic behaviors (e.g., "AI pacifist") via Lua. AI decision trees are largely compiled.2   
4. **Network protocol:** The client synchronization method is implemented at the engine level. Mods cannot easily change the network layer to implement new multiplayer modes (e.g., simultaneous cooperative combat control) unless the engine explicitly supports it.3  
5. **Obsolete hardcode:** Some specific interactions (e.g., how Siege works or the logic behind the Dimension Door spell) have historically been hardcoded. VCMI has moved many of these to JSON (e.g., deityOfFire is now a building type rather than a hardcoded check), but some rare mechanics may still require C++ patches.22

## ---

**8\. Strategic roadmap for modding**

To realize the potential of modding in VCMI, the following project complexity scale is recommended:

| Level | Goal | Tools | Actions |
| :---- | :---- | :---- | :---- |
| **Beginner** | Adding an Artifact or Hero | Text editor, mod.json | Copy existing JSON, change ID, name, icon, and bonuses. Pack into folder structure. |
| **Intermediate** | Creating a new Faction (City) | Graphic editor, JSON | Drawing the city screen. Configuring the building tree in town.json. Creating unit stats. Using Modders' Tool Pack. |
| **Advanced** | Creating new game mechanics | Lua Scripting API | Writing a script that subscribes to events (e.g., NewDay). Iterating over heroes, checking conditions, applying dynamic bonuses. |
| **Expert** | Global conversion | All of the above \+ GitHub | Creating a complete set of replacement assets, rewriting texts, creating campaigns with deep scripting. |

## ---

**9\. Conclusion**

The VCMI engine has successfully transformed Heroes of Might and Magic III from a closed legacy product into an open modern platform. The "ceiling of possibilities" is now determined not by the limitations of the original game, but by the author's ability to manipulate JSON structures and Lua logic.

Although deep core changes (such as changing the geometry of the battlefield or the network model) still require the involvement of C++ developers, virtually every aspect of *content creation* — new civilizations, magic systems, campaigns, and audiovisual reworks — is fully accessible to modders. The transfer of hard-coded mechanics to the universal **Bonus System** is a key achievement, effectively turning the engine into a turn-based strategy constructor wrapped in Heroes III.

For researchers or developers wishing to utilize this platform, the **VCMI Mod Repository** and **Lua Scripting System** are the primary vectors of innovation, offering a standardized yet limitless canvas for creative expansion.

#### **Citētie darbi**

1. VCMI Project | Heroes III Wiki \- Fandom, piekļuves datums: janvāris 1, 2026, [https://homm.fandom.com/wiki/VCMI\_Project](https://homm.fandom.com/wiki/VCMI_Project)  
2. FAQ \- VCMI, piekļuves datums: janvāris 1, 2026, [https://vcmi.eu/faq/](https://vcmi.eu/faq/)  
3. Code Structure \- VCMI, piekļuves datums: janvāris 1, 2026, [https://vcmi.eu/developers/Code\_Structure/](https://vcmi.eu/developers/Code_Structure/)  
4. vcmi/docs/developers/Code\_Structure.md at develop \- GitHub, piekļuves datums: janvāris 1, 2026, [https://github.com/vcmi/vcmi/blob/develop/docs/developers/Code\_Structure.md](https://github.com/vcmi/vcmi/blob/develop/docs/developers/Code_Structure.md)  
5. Lua Scripting System \- VCMI, piekļuves datums: janvāris 1, 2026, [https://vcmi.eu/developers/Lua\_Scripting\_System/](https://vcmi.eu/developers/Lua_Scripting_System/)  
6. Modding Readme \- VCMI, piekļuves datums: janvāris 1, 2026, [https://vcmi.eu/modders/Readme/](https://vcmi.eu/modders/Readme/)  
7. Mod File Format \- VCMI, piekļuves datums: janvāris 1, 2026, [https://vcmi.eu/modders/Mod\_File\_Format/](https://vcmi.eu/modders/Mod_File_Format/)  
8. Mods repository for VCMI \- GitHub, piekļuves datums: janvāris 1, 2026, [https://github.com/vcmi/vcmi-mods-repository](https://github.com/vcmi/vcmi-mods-repository)  
9. vcmi-mods/modder-tools-pack: Collection of tools and templates for modders \- GitHub, piekļuves datums: janvāris 1, 2026, [https://github.com/vcmi-mods/modder-tools-pack](https://github.com/vcmi-mods/modder-tools-pack)  
10. Modders' Tool Pack \- VCMI, piekļuves datums: janvāris 1, 2026, [https://vcmi.eu/Mod%20Repository/Other/Modders%27%20Tool%20Pack/](https://vcmi.eu/Mod%20Repository/Other/Modders%27%20Tool%20Pack/)  
11. Town Building Format \- VCMI, piekļuves datums: janvāris 1, 2026, [https://vcmi.eu/modders/Entities\_Format/Town\_Building\_Format/](https://vcmi.eu/modders/Entities_Format/Town_Building_Format/)  
12. HotA supported features · Issue \#1614 · vcmi/vcmi \- GitHub, piekļuves datums: janvāris 1, 2026, [https://github.com/vcmi/vcmi/issues/1614](https://github.com/vcmi/vcmi/issues/1614)  
13. Bonus Types \- VCMI, piekļuves datums: janvāris 1, 2026, [https://vcmi.eu/modders/Bonus/Bonus\_Types/](https://vcmi.eu/modders/Bonus/Bonus_Types/)  
14. Json config for artifacts \- Development \- VCMI Project Forums, piekļuves datums: janvāris 1, 2026, [https://forum.vcmi.eu/t/json-config-for-artifacts/532](https://forum.vcmi.eu/t/json-config-for-artifacts/532)  
15. vcmi/docs/modders/Map\_Objects/Rewardable.md at develop \- GitHub, piekļuves datums: janvāris 1, 2026, [https://github.com/vcmi/vcmi/blob/develop/docs/modders/Map\_Objects/Rewardable.md](https://github.com/vcmi/vcmi/blob/develop/docs/modders/Map_Objects/Rewardable.md)  
16. Modding \- VCMI Project Wiki, piekļuves datums: janvāris 1, 2026, [https://wiki.vcmi.eu/Modding](https://wiki.vcmi.eu/Modding)  
17. Scripting suggestions (Lua, (V)ERM) \- Content creation \- VCMI Project Forums, piekļuves datums: janvāris 1, 2026, [https://forum.vcmi.eu/t/scripting-suggestions-lua-v-erm/5207](https://forum.vcmi.eu/t/scripting-suggestions-lua-v-erm/5207)  
18. VCMI | Might and Magic Wiki \- Fandom, piekļuves datums: janvāris 1, 2026, [https://mightandmagic.fandom.com/wiki/VCMI](https://mightandmagic.fandom.com/wiki/VCMI)  
19. File Formats \- VCMI, piekļuves datums: janvāris 1, 2026, [https://vcmi.eu/modders/File\_Formats/](https://vcmi.eu/modders/File_Formats/)  
20. Game Mechanics \- VCMI, piekļuves datums: janvāris 1, 2026, [https://vcmi.eu/players/Game\_Mechanics/](https://vcmi.eu/players/Game_Mechanics/)  
21. HoMM 3 VCMI engine has improved significantly in recent years in terms of mod support and especially gameplay. All the new towns you see in the picture can be easily installed via VCMI Launcher. Link in comments. : r/heroes3 \- Reddit, piekļuves datums: janvāris 1, 2026, [https://www.reddit.com/r/heroes3/comments/1ieahe7/homm\_3\_vcmi\_engine\_has\_improved\_significantly\_in/](https://www.reddit.com/r/heroes3/comments/1ieahe7/homm_3_vcmi_engine_has_improved_significantly_in/)  
22. vcmi/ChangeLog.md at develop \- GitHub, piekļuves datums: janvāris 1, 2026, [https://github.com/vcmi/vcmi/blob/develop/ChangeLog.md](https://github.com/vcmi/vcmi/blob/develop/ChangeLog.md)
