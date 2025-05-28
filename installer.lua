-- Installation script for controller v2

-- Remove old files if they exist for a clean install
if fs.exists("main.lua") then
    fs.delete("main.lua")
end
if fs.exists("basalt") then -- Basalt often installs as a folder
    fs.delete("basalt")
end
-- Add other files/folders to clean here if needed, e.g., for Advanced Peripherals

-- Download the main file
print("[Installer] Downloading main.lua...")
shell.run("wget", "https://raw.githubusercontent.com/anaa98fdgdfgw/controllerv2/refs/heads/main/main.lua", "main.lua") -- Make sure 'main' is the correct branch

-- Download and install Basalt2 (official)
print("[Installer] Downloading and installing Basalt2 (UI)...")
local basalt_success, basalt_err = shell.run("wget run https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua")
if not basalt_success then
    printError("[Installer] Error installing Basalt2: " .. (basalt_err or "unknown"))
    return
end
print("[Installer] Basalt2 installed successfully!")

-- Download and install Advanced Peripherals
print("[Installer] Downloading and installing Advanced Peripherals...")
-- Note: The URL below is a common example for CC:Tweaked. Verify it's correct for your ComputerCraft/Modpack version.
local ap_success, ap_err = shell.run("wget run https://advanced-peripherals.chylex.com/installer.lua")
if not ap_success then
    printError("[Installer] Error installing Advanced Peripherals: " .. (ap_err or "unknown"))
    printWarn("[Installer] Script will continue, but AE2 features might not work.")
else
    print("[Installer] Advanced Peripherals installed successfully!")
end

print("---------------------------------------------------------")
print("Installation complete!")
print("Use the 'main' command to start the controller.")
print("---------------------------------------------------------")

-- Clean up global variables if necessary
basalt_success = nil
basalt_err = nil
ap_success = nil
ap_err = nil
