-- Hive Spawn Selector
-- lua/HiveSpawnSelector/HiveSpawnSelector_Predict.lua
--
-- Loads the shared defs into the client prediction VM. This is needed so the countdown
-- freeze (the Player:GetCanControl and Player:UpdateViewAngles overrides in the shared file)
-- is applied when the local player's movement is predicted, keeping it in sync with the
-- server and avoiding rubber-banding / jitter while frozen.

Script.Load("lua/HiveSpawnSelector/HiveSpawnSelector_Utility.lua")
Script.Load("lua/HiveSpawnSelector/HiveSpawnSelector_Shared.lua")
