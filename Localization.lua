-- Ebon Affix Alert - localization
-- Only EAA's own interface/help text is localized. Affix names, item names,
-- and text supplied by WoW/Project Ebonhold remain unchanged.

EbonAffixAlertLocale = EbonAffixAlertLocale or {}
local M = EbonAffixAlertLocale

M.languages = {
    enUS = "English",
    frFR = "Français",
    deDE = "Deutsch",
    esES = "Español",
}

local fr = {
    ["Tracked affix looted:"] = "Affixe suivi obtenu :",
    ["Language:"] = "Langue :",
    ["Style:"] = "Style :",
    ["Modern"] = "Moderne",
    ["Fantasy"] = "Fantaisie",
    ["General"] = "Général",
    ["Weapon"] = "Arme",
    ["Filter:"] = "Filtre :",
    ["Tracked only"] = "Suivis uniquement",
    ["Affix"] = "Affixe",
    ["All"] = "Tous",
    ["Select All"] = "Tout sélectionner",
    ["Clear All"] = "Tout effacer",
    ["Alerts"] = "Alertes",
    ["Interface"] = "Interface",
    ["Enable loot tracking"] = "Activer le suivi du butin",
    ["Large on-screen alert"] = "Grande alerte à l'écran",
    ["Alert Sound"] = "Son d'alerte",
    ["Show minimap icon"] = "Afficher l'icône de la minicarte",
    ["Show loot history window"] = "Afficher l'historique du butin",
    ["Highlight tracked bag items"] = "Surligner les objets suivis dans les sacs",
    ["Auto-Keep tracked items\nin EbonClearance"] = "Conserver auto. les objets suivis\ndans EbonClearance",
    ["Auto-Keep tracked items in EbonClearance"] = "Conserver automatiquement les objets suivis dans EbonClearance",
    ["When enabled, items in your bags with an affix you are currently tracking in EAA are automatically added to EbonClearance's Keep List."] =
        "Lorsque cette option est activée, les objets de vos sacs possédant un affixe actuellement suivi dans EAA sont automatiquement ajoutés à la liste de conservation d'EbonClearance.",
    ["If you stop tracking that affix, EAA removes the Keep entry only if EAA originally added it. Manual EbonClearance Keep entries are left untouched."] =
        "Si vous cessez de suivre cet affixe, EAA retire l'entrée de conservation uniquement si EAA l'avait ajoutée. Les entrées ajoutées manuellement dans EbonClearance ne sont pas modifiées.",
    ["EbonClearance stores Keep rules by item ID. If two copies of the same item have different affixes, protecting one copy will therefore protect both."] =
        "EbonClearance enregistre les règles de conservation par ID d'objet. Si deux exemplaires du même objet ont des affixes différents, protéger l'un protégera donc les deux.",
    ["Tracking Enabled"] = "Suivi activé",
    ["Tracking Disabled"] = "Suivi désactivé",
    ["Waiting for Project Ebonhold affix data."] = "En attente des données d'affixes de Project Ebonhold.",
    ["Spell tooltip unavailable for this affix."] = "Infobulle de sort indisponible pour cet affixe.",
    ["Click to track all General affixes available at this rank."] = "Cliquez pour suivre tous les affixes généraux disponibles à ce rang.",
    ["If every available affix at this rank is already tracked, clicking clears them all."] = "Si tous les affixes disponibles à ce rang sont déjà suivis, un clic les désactive tous.",
    ["Click to track every available rank for this affix."] = "Cliquez pour suivre tous les rangs disponibles de cet affixe.",
    ["If every rank is already tracked, clicking clears them all."] = "Si tous les rangs sont déjà suivis, un clic les désactive tous.",
    ["Rank"] = "Rang",
    ["Ebon Affix Alert"] = "Ebon Affix Alert",
    ["Made By Kebbie"] = "Créé par Kebbie",
    ["Left-click: Open settings"] = "Clic gauche : ouvrir les paramètres",
    ["Right-click: Toggle tracking"] = "Clic droit : activer/désactiver le suivi",
    ["Ctrl + drag: Move minimap icon"] = "Ctrl + glisser : déplacer l'icône de la minicarte",
    ["Shift-left-click: Hide minimap icon"] = "Maj + clic gauche : masquer l'icône de la minicarte",
    ["Loot History"] = "Historique du butin",
    ["Looted Item / Tracked Affix"] = "Objet obtenu / Affixe suivi",
    ["Item"] = "Objet",
    ["Tracked Affix"] = "Affixe suivi",
    ["Affix:"] = "Affixe :",
    ["Clear"] = "Effacer",
    ["Newest first - up to 50 entries"] = "Plus récent d'abord - jusqu'à 50 entrées",
    ["Transparency"] = "Transparence",
    ["Shift-click: Link in chat"] = "Maj + clic : lien dans le chat",
    ["Right-click: Remove from history"] = "Clic droit : retirer de l'historique",
    ["Resize Loot History"] = "Redimensionner l'historique du butin",
    ["Drag the corner to resize"] = "Faites glisser le coin pour redimensionner",
    ["items"] = "objets",
    ["item"] = "objet",
    ["Enable EbonAffixAlert"] = "Activer EbonAffixAlert",
    ["Commands"] = "Commandes",
    ["Every EAA chat command is also available here:"] = "Toutes les commandes de chat EAA sont également disponibles ici :",
    ["Support"] = "Assistance",
    ["Export Tracked Config"] = "Exporter la configuration suivie",
    ["Creates selectable text showing exactly which affixes and ranks are tracked."] =
        "Crée un texte sélectionnable indiquant précisément quels affixes et rangs sont suivis.",
    ["Diagnostics"] = "Diagnostics",
    ["Update Check"] = "Vérifier les mises à jour",
    ["Close"] = "Fermer",
    ["Ctrl+A then Ctrl+C to copy the text below."] = "Ctrl+A puis Ctrl+C pour copier le texte ci-dessous.",
}


local de = {
    ["Tracked affix looted:"] = "Verfolgtes Affix erbeutet:",
    ["Language:"] = "Sprache:",
    ["Style:"] = "Stil:",
    ["Modern"] = "Modern",
    ["Fantasy"] = "Fantasie",
    ["General"] = "Allgemein",
    ["Weapon"] = "Waffe",
    ["Filter:"] = "Filter:",
    ["Tracked only"] = "Nur verfolgte",
    ["Affix"] = "Affix",
    ["All"] = "Alle",
    ["Select All"] = "Alle auswählen",
    ["Clear All"] = "Alle löschen",
    ["Alerts"] = "Warnungen",
    ["Interface"] = "Oberfläche",
    ["Enable loot tracking"] = "Beuteverfolgung aktivieren",
    ["Large on-screen alert"] = "Große Bildschirmwarnung",
    ["Alert Sound"] = "Warnton",
    ["Show minimap icon"] = "Minikarten-Symbol anzeigen",
    ["Show loot history window"] = "Beuteverlauf anzeigen",
    ["Highlight tracked bag items"] = "Verfolgte Gegenstände in Taschen hervorheben",
    ["Auto-Keep tracked items\nin EbonClearance"] = "Verfolgte Gegenstände automatisch\nin EbonClearance behalten",
    ["Auto-Keep tracked items in EbonClearance"] = "Verfolgte Gegenstände automatisch in EbonClearance behalten",
    ["When enabled, items in your bags with an affix you are currently tracking in EAA are automatically added to EbonClearance's Keep List."] =
        "Wenn aktiviert, werden Gegenstände in deinen Taschen mit einem Affix, das du derzeit in EAA verfolgst, automatisch zur Behalten-Liste von EbonClearance hinzugefügt.",
    ["If you stop tracking that affix, EAA removes the Keep entry only if EAA originally added it. Manual EbonClearance Keep entries are left untouched."] =
        "Wenn du dieses Affix nicht mehr verfolgst, entfernt EAA den Behalten-Eintrag nur dann, wenn EAA ihn ursprünglich hinzugefügt hat. Manuelle EbonClearance-Einträge bleiben unverändert.",
    ["EbonClearance stores Keep rules by item ID. If two copies of the same item have different affixes, protecting one copy will therefore protect both."] =
        "EbonClearance speichert Behalten-Regeln nach Gegenstands-ID. Wenn zwei Exemplare desselben Gegenstands unterschiedliche Affixe haben, werden beim Schützen eines Exemplars daher beide geschützt.",
    ["Tracking Enabled"] = "Verfolgung aktiviert",
    ["Tracking Disabled"] = "Verfolgung deaktiviert",
    ["Waiting for Project Ebonhold affix data."] = "Warte auf Affix-Daten von Project Ebonhold.",
    ["Spell tooltip unavailable for this affix."] = "Zauber-Tooltip für dieses Affix nicht verfügbar.",
    ["Click to track all General affixes available at this rank."] = "Klicken, um alle allgemeinen Affixe dieses Rangs zu verfolgen.",
    ["If every available affix at this rank is already tracked, clicking clears them all."] = "Wenn bereits alle verfügbaren Affixe dieses Rangs verfolgt werden, entfernt ein Klick alle.",
    ["Click to track every available rank for this affix."] = "Klicken, um alle verfügbaren Ränge dieses Affixes zu verfolgen.",
    ["If every rank is already tracked, clicking clears them all."] = "Wenn bereits alle Ränge verfolgt werden, entfernt ein Klick alle.",
    ["Rank"] = "Rang",
    ["Ebon Affix Alert"] = "Ebon Affix Alert",
    ["Made By Kebbie"] = "Von Kebbie",
    ["Left-click: Open settings"] = "Linksklick: Einstellungen öffnen",
    ["Right-click: Toggle tracking"] = "Rechtsklick: Verfolgung umschalten",
    ["Ctrl + drag: Move minimap icon"] = "Strg + Ziehen: Minikarten-Symbol verschieben",
    ["Shift-left-click: Hide minimap icon"] = "Umschalt + Linksklick: Minikarten-Symbol ausblenden",
    ["Loot History"] = "Beuteverlauf",
    ["Looted Item / Tracked Affix"] = "Erbeuteter Gegenstand / Verfolgtes Affix",
    ["Item"] = "Gegenstand",
    ["Tracked Affix"] = "Verfolgtes Affix",
    ["Affix:"] = "Affix:",
    ["Clear"] = "Leeren",
    ["Newest first - up to 50 entries"] = "Neueste zuerst - bis zu 50 Einträge",
    ["Transparency"] = "Transparenz",
    ["Shift-click: Link in chat"] = "Umschalt + Klick: Im Chat verlinken",
    ["Right-click: Remove from history"] = "Rechtsklick: Aus Verlauf entfernen",
    ["Resize Loot History"] = "Beuteverlauf skalieren",
    ["Drag the corner to resize"] = "Zum Skalieren die Ecke ziehen",
    ["items"] = "Gegenstände",
    ["item"] = "Gegenstand",
    ["Enable EbonAffixAlert"] = "EbonAffixAlert aktivieren",
    ["Commands"] = "Befehle",
    ["Every EAA chat command is also available here:"] = "Alle EAA-Chatbefehle sind auch hier verfügbar:",
    ["Support"] = "Support",
    ["Export Tracked Config"] = "Verfolgte Konfiguration exportieren",
    ["Creates selectable text showing exactly which affixes and ranks are tracked."] =
        "Erstellt auswählbaren Text, der genau zeigt, welche Affixe und Ränge verfolgt werden.",
    ["Diagnostics"] = "Diagnose",
    ["Update Check"] = "Nach Updates suchen",
    ["Close"] = "Schließen",
    ["Ctrl+A then Ctrl+C to copy the text below."] = "Strg+A und dann Strg+C, um den Text unten zu kopieren.",
}


local es = {
    ["Tracked affix looted:"] = "Afijo seguido obtenido:",
    ["Language:"] = "Idioma:",
    ["Style:"] = "Estilo:",
    ["Modern"] = "Moderno",
    ["Fantasy"] = "Fantasía",
    ["General"] = "General",
    ["Weapon"] = "Arma",
    ["Filter:"] = "Filtro:",
    ["Tracked only"] = "Solo seguidos",
    ["Affix"] = "Afijo",
    ["All"] = "Todos",
    ["Select All"] = "Marcar todo",
    ["Clear All"] = "Borrar todo",
    ["Alerts"] = "Alertas",
    ["Interface"] = "Interfaz",
    ["Enable loot tracking"] = "Activar seguimiento de botín",
    ["Large on-screen alert"] = "Alerta grande en pantalla",
    ["Alert Sound"] = "Sonido de alerta",
    ["Show minimap icon"] = "Mostrar icono del minimapa",
    ["Show loot history window"] = "Mostrar historial de botín",
    ["Highlight tracked bag items"] = "Resaltar objetos seguidos en las bolsas",
    ["Auto-Keep tracked items\nin EbonClearance"] = "Mantener automáticamente los objetos\nseguidos en EbonClearance",
    ["Auto-Keep tracked items in EbonClearance"] = "Mantener automáticamente los objetos seguidos en EbonClearance",
    ["When enabled, items in your bags with an affix you are currently tracking in EAA are automatically added to EbonClearance's Keep List."] =
        "Cuando está activado, los objetos de tus bolsas con un afijo que estés siguiendo actualmente en EAA se añaden automáticamente a la lista de conservar de EbonClearance.",
    ["If you stop tracking that affix, EAA removes the Keep entry only if EAA originally added it. Manual EbonClearance Keep entries are left untouched."] =
        "Si dejas de seguir ese afijo, EAA elimina la entrada de conservar solo si EAA la añadió originalmente. Las entradas manuales de EbonClearance no se modifican.",
    ["EbonClearance stores Keep rules by item ID. If two copies of the same item have different affixes, protecting one copy will therefore protect both."] =
        "EbonClearance guarda las reglas de conservar por ID de objeto. Si dos copias del mismo objeto tienen afijos distintos, al proteger una copia se protegerán ambas.",
    ["Tracking Enabled"] = "Seguimiento activado",
    ["Tracking Disabled"] = "Seguimiento desactivado",
    ["Waiting for Project Ebonhold affix data."] = "Esperando los datos de afijos de Project Ebonhold.",
    ["Spell tooltip unavailable for this affix."] = "Información de hechizo no disponible para este afijo.",
    ["Click to track all General affixes available at this rank."] = "Haz clic para seguir todos los afijos generales disponibles de este rango.",
    ["If every available affix at this rank is already tracked, clicking clears them all."] = "Si todos los afijos disponibles de este rango ya están seguidos, al hacer clic se desmarcan todos.",
    ["Click to track every available rank for this affix."] = "Haz clic para seguir todos los rangos disponibles de este afijo.",
    ["If every rank is already tracked, clicking clears them all."] = "Si todos los rangos ya están seguidos, al hacer clic se desmarcan todos.",
    ["Rank"] = "Rango",
    ["Ebon Affix Alert"] = "Ebon Affix Alert",
    ["Made By Kebbie"] = "Hecho por Kebbie",
    ["Left-click: Open settings"] = "Clic izquierdo: abrir ajustes",
    ["Right-click: Toggle tracking"] = "Clic derecho: activar/desactivar seguimiento",
    ["Ctrl + drag: Move minimap icon"] = "Ctrl + arrastrar: mover el icono del minimapa",
    ["Shift-left-click: Hide minimap icon"] = "Mayús + clic izquierdo: ocultar el icono del minimapa",
    ["Loot History"] = "Historial de botín",
    ["Looted Item / Tracked Affix"] = "Objeto obtenido / Afijo seguido",
    ["Item"] = "Objeto",
    ["Tracked Affix"] = "Afijo seguido",
    ["Affix:"] = "Afijo:",
    ["Clear"] = "Limpiar",
    ["Newest first - up to 50 entries"] = "Más reciente primero - hasta 50 entradas",
    ["Transparency"] = "Transparencia",
    ["Shift-click: Link in chat"] = "Mayús + clic: enlazar en el chat",
    ["Right-click: Remove from history"] = "Clic derecho: eliminar del historial",
    ["Resize Loot History"] = "Cambiar tamaño del historial de botín",
    ["Drag the corner to resize"] = "Arrastra la esquina para cambiar el tamaño",
    ["items"] = "objetos",
    ["item"] = "objeto",
    ["Enable EbonAffixAlert"] = "Activar EbonAffixAlert",
    ["Commands"] = "Comandos",
    ["Every EAA chat command is also available here:"] = "Todos los comandos de chat de EAA también están disponibles aquí:",
    ["Support"] = "Soporte",
    ["Export Tracked Config"] = "Exportar configuración seguida",
    ["Creates selectable text showing exactly which affixes and ranks are tracked."] =
        "Crea un texto seleccionable que muestra exactamente qué afijos y rangos se están siguiendo.",
    ["Diagnostics"] = "Diagnóstico",
    ["Update Check"] = "Buscar actualizaciones",
    ["Close"] = "Cerrar",
    ["Ctrl+A then Ctrl+C to copy the text below."] = "Pulsa Ctrl+A y luego Ctrl+C para copiar el texto de abajo.",
}

function M.GetLanguage()
    if EbonAffixAlertDB and EbonAffixAlertDB.language and M.languages[EbonAffixAlertDB.language] then
        return EbonAffixAlertDB.language
    end
    return "enUS"
end

function M.Get(text)
    local language = M.GetLanguage()
    if language == "frFR" then
        return fr[text] or text
    elseif language == "deDE" then
        return de[text] or text
    elseif language == "esES" then
        return es[text] or text
    end
    return text
end

function EAA_L(text)
    return M.Get(text)
end
