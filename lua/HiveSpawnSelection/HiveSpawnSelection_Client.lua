-- Hive Spawn Selection
-- lua/HiveSpawnSelection/HiveSpawnSelection_Client.lua
--
-- Attaches the spawn-selection menu to the alien commander.

Script.Load("lua/HiveSpawnSelection/HiveSpawnSelection_Utility.lua")
Script.Load("lua/HiveSpawnSelection/HiveSpawnSelection_Shared.lua")

AddClientUIScriptForClass("AlienCommander", "HiveSpawnSelection/GUIHiveSpawnSelectionMenu")
