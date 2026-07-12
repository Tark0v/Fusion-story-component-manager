local ReplicatedStorage = game:GetService("ReplicatedStorage")

local replicatedScripts = ReplicatedStorage.Scripts
local packages = replicatedScripts.Packages
local uiPackages = packages.UiPackages

local Fusion = require(uiPackages.Fusion)

export type SCOPE = Fusion.Scope
export type VALUE = Fusion.Value<any>

return Fusion