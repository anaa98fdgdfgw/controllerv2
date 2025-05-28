-- Script d'installation pour le contrôleur v2

-- Supprimer les anciens fichiers s'ils existent pour une installation propre
if fs.exists("main.lua") then
    fs.delete("main.lua")
end
if fs.exists("basalt") then -- Basalt s'installe souvent comme un dossier
    fs.delete("basalt")
end
-- Ajoutez ici d'autres fichiers/dossiers à nettoyer si nécessaire, par exemple pour Advanced Peripherals

-- Téléchargement du fichier principal
print("[Installer] Téléchargement de main.lua...")
shell.run("wget", "https://raw.githubusercontent.com/anaa98fdgdfgw/controllerv2/main/main.lua", "main.lua") -- Assurez-vous que 'main' est la branche correcte

-- Téléchargement et installation de Basalt2 (officiel)
print("[Installer] Téléchargement et installation de Basalt2 (UI)...")
local basalt_success = सफलता, err = shell.run("wget run https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua -r")
if not basalt_success then
    printError("[Installer] Erreur lors de l'installation de Basalt2: " .. (err or "inconnue"))
    return
end
print("[Installer] Basalt2 installé avec succès !")

-- Téléchargement et installation d'Advanced Peripherals
print("[Installer] Téléchargement et installation d'Advanced Peripherals...")
-- Note: L'URL ci-dessous est un exemple commun pour CC:Tweaked. Vérifiez si elle est correcte pour votre version de ComputerCraft/Modpack.
local ap_success, ap_err = shell.run("wget run https://advanced-peripherals.chylex.com/installer.lua")
if not ap_success then
    printError("[Installer] Erreur lors de l'installation d'Advanced Peripherals: " .. (ap_err or "inconnue"))
    printWarn("[Installer] Le script continuera, mais les fonctionnalités AE2 pourraient ne pas fonctionner.")
else
    print("[Installer] Advanced Peripherals installé avec succès !")
end

print("---------------------------------------------------------")
print("Installation terminée !")
print("Utilisez la commande 'main' pour démarrer le contrôleur.")
print("---------------------------------------------------------")

-- Petit nettoyage des variables globales si nécessaire
basalt_success = nil
err = nil
ap_success = nil
ap_err = nil
