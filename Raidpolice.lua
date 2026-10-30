-- RaidPolice v1.17 [LEGENDARY] - By Seth + OverLord Fix
-- Parry + Festin x99 + Manada + MC + First Hit (con dueño de Pet DK/Brujo/Caza)

local ADDON = "RaidPolice"
local frame = CreateFrame("Frame")

local stats = {parry={}, festin={}, manada={}, mc={}, firstHit={}}
local lastWarn, festinCount, manadaReported = {}, {}, {}
local petOwnerCache = {}
local firstHitDone = false
local settings = {manada=true, festin=true, parry=true, mc=true, firstHit=true}

local MC_SPELLS = {[71289]=true,[71290]=true,[72027]=true,[72028]=true,[73020]=true,[68904]=true}
local FESTIN_SPELLS = {[57301]=true,[57426]=true,[57291]=true,[57302]=true,[58465]=true,[58474]=true,[58506]=true,[57025]=true}
local ASPECTO_MANADA = 13159

local ICON_MANADA = "|TInterface\\Icons\\Ability_Mount_JungleTiger:20|t"
local ICON_FIRST = "|TInterface\\Icons\\Ability_Warrior_Charge:20|t"
local ICON_FESTIN = "|TInterface\\Icons\\INV_Misc_Food_64:20|t"
local ICON_CHEF = "|TInterface\\Icons\\Achievement_Profession_Cooking:20|t"

local FESTIN_MSGS = {
    "%s comio del festin! x1", "%s cata pescados, deja uno! x2",
    "%s, no es tu banco de peces! x3", "%s confirmado oficial del festin! x4",
    "%s, deja sin trabajo al de cocina! x5", "%s, Chef del Año! x6",
}

local function GetFestinMsg(c, name)
    if c <= 6 then return string.format(FESTIN_MSGS[c], name)
    elseif c == 7 then return string.format("%s ¡Ya 7! ¡Deja para el tanque! x7", name)
    elseif c < 10 then return string.format("%s ¡%d festines! Tragón oficial! x%d", name, c, c)
    elseif c < 20 then return string.format("%s ¡¡x%d!! ¡Cocina [450] sin trabajo! x%d", name, c, c)
    else return string.format("%s ¡¡¡x%d!!! ¡¡¡BOSS COMIENDO!!! x%d", name, c, c) end
end

local function AddStat(k, n) if not n or n=="" then return end stats[k][n]=(stats[k][n] or 0)+1 end
local function ClearStats() wipe(stats.parry) wipe(stats.festin) wipe(stats.manada) wipe(stats.mc) wipe(stats.firstHit) wipe(festinCount) wipe(petOwnerCache) firstHitDone=false print("|cFFFF8000[RaidPolice]|r |cFFFFD100Stats limpiados.|r") end

local function GetColoredName(name, guid)
    local color="|cFFFFFFFF" local class=nil
    if guid then local _, engClass=GetPlayerInfoByGUID(guid) class=engClass end
    if not class and name then local _, engClass=UnitClass(name) class=engClass end
    if class and RAID_CLASS_COLORS[class] then local c=RAID_CLASS_COLORS[class] color=string.format("|cFF%02x%02x%02x",c.r*255,c.g*255,c.b*255) end
    return color..(name or "???").."|r"
end

local function GetPetOwnerName(petGUID)
    if petOwnerCache[petGUID] then return petOwnerCache[petGUID] end
    local function Scan(u) if UnitExists(u) and UnitExists(u.."pet") and UnitGUID(u.."pet")==petGUID then return UnitName(u) end end
    if IsInRaid() then for i=1,40 do local o=Scan("raid"..i) if o then petOwnerCache[petGUID]=o return o end end
    else for i=1,4 do local o=Scan("party"..i) if o then petOwnerCache[petGUID]=o return o end end local o=Scan("player") if o then petOwnerCache[petGUID]=o return o end end
    return nil
end

local function IsPetGUID(g) if not g then return false end return g:sub(1,6)=="0xF130" or g:sub(1,6)=="0xF140" end
local function SendRaid(m) if IsInRaid() then pcall(SendChatMessage,m,"RAID") else print(m) end end
local function SendRW(m) if IsInRaid() and (IsRaidLeader() or IsRaidOfficer()) then pcall(SendChatMessage,m,"RAID_WARNING") end end
local function ShouldWarn(k,s) local n=GetTime() if lastWarn[k] and (n-lastWarn[k])<s then return false end lastWarn[k]=n return true end

local function PrintStats()
    print("|cFFFF8000==== [RaidPolice] v1.17 [Legendary] ====|r")
    for _, kind in ipairs({"parry","festin","manada","mc","firstHit"}) do
        local list={} for name,count in pairs(stats[kind]) do table.insert(list,{name=name,count=count}) end
        table.sort(list,function(a,b) return a.count>b.count end)
        if #list==0 then print("|cFF9D9D9D"..kind..": ninguno|r") 
        else print("|cFFFFD100["..kind.."]|r") 
            for i=1,#list do print("  |cFFFF8000"..list[i].name.."|r -> |cFFFFFFFF"..list[i].count.."|r") end 
        end
    end
end

SLASH_RAIDPOLICE1="/RaidPolice" SLASH_RAIDPOLICE2="/rp"
SlashCmdList["RAIDPOLICE"]=function(msg)
    msg=(msg or ""):gsub("^%s+",""):gsub("%s+$","")
    if msg=="stats" then PrintStats()
    elseif msg=="clear" then ClearStats()
    elseif msg=="help" then print("|cFFFF8000RaidPolice:|r |cFFFFD100/rp stats|r | |cFFFFD100/rp clear|r")
    elseif msg=="status" then print("|cFFFF8000[RaidPolice]|r ON")
    else PrintStats() end
end

frame:RegisterEvent("ADDON_LOADED") frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") frame:RegisterEvent("PLAYER_REGEN_DISABLED") frame:RegisterEvent("ENCOUNTER_START")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event=="ADDON_LOADED" and arg1==ADDON then 
        print("|cFFFF8000|Hitem:0|h[RaidPolice]|h|r |cFFFFD100v1.17 [Legendary] ON!|r |cFF9D9D9DUsa /rp|r") 
        return 
    end
    if event=="PLAYER_REGEN_DISABLED" or event=="ENCOUNTER_START" then manadaReported={} firstHitDone=false wipe(petOwnerCache) wipe(lastWarn) return end
    if event~="COMBAT_LOG_EVENT_UNFILTERED" then return end
    local _, subEvent, _, sourceGUID, sourceName, _, destGUID, destName, _, _, spellId, spellName, _, _, missType=CombatLogGetCurrentEventInfo()
    if not subEvent then return end

    if subEvent=="SPELL_AURA_APPLIED" and spellId==ASPECTO_MANADA and sourceName and (InCombatLockdown() or IsEncounterInProgress()) then
        if not manadaReported[sourceName] then manadaReported[sourceName]=true AddStat("manada",sourceName) 
        if ShouldWarn(sourceName..":manada",30) then SendRaid(ICON_MANADA.." |cFFFF8000"..GetColoredName(sourceName,sourceGUID).." |cFFFFD100¡Quita Manada!|r") SendRW(sourceName.." ¡Quita Manada!") end end return
    end
    if subEvent=="SPELL_AURA_REMOVED" and spellId==ASPECTO_MANADA and sourceName then manadaReported[sourceName]=nil return end

    if subEvent=="SPELL_AURA_APPLIED" and FESTIN_SPELLS[spellId] and settings.festin and destName then
        festinCount[destName]=(festinCount[destName] or 0)+1 AddStat("festin",destName)
        local c=festinCount[destName] 
        local shouldSay=c<=7 or c==10 or c==15 or c==20 or c%10==0 or (c>=30 and c%5==0)
        if shouldSay and ShouldWarn(destName..":festin",4) then SendRaid((c==1 and ICON_FESTIN or ICON_CHEF).." |cFFFFD100FESTIN:|r "..GetFestinMsg(c,GetColoredName(destName,destGUID))) end return
    end

    if subEvent=="SWING_MISSED" and settings.parry and missType=="PARRY" and sourceName then AddStat("parry",sourceName) return end
    if subEvent=="SPELL_CAST_START" and settings.mc and (MC_SPELLS[spellId] or (spellName and spellName:lower():find("domin",1,true))) then AddStat("mc",sourceName or "Lady") end

    if settings.firstHit and not firstHitDone and (subEvent=="SWING_DAMAGE" or subEvent=="SPELL_DAMAGE" or subEvent=="RANGE_DAMAGE" or subEvent=="SPELL_CAST_SUCCESS") then
        if destName and (IsEncounterInProgress() or InCombatLockdown()) and sourceGUID and sourceName and destGUID and not destGUID:find("Player") then
            local realName=sourceName local realGUID=sourceGUID local isPet=IsPetGUID(sourceGUID)
            if isPet then local o=GetPetOwnerName(sourceGUID) if o then realName=o if IsInRaid() then for i=1,40 do local u="raid"..i if UnitExists(u) and UnitName(u)==realName then realGUID=UnitGUID(u) break end end end end end
            if realName then firstHitDone=true AddStat("firstHit",realName) local dName=GetColoredName(realName,realGUID)
                if isPet then SendRaid(ICON_FIRST.." |cFFFF8000FIRST HIT:|r "..dName.." |cFFFFD100¡Su pet [|r"..sourceName.."|cFFFFD100] pulleó!|r") else SendRaid(ICON_FIRST.." |cFFFF8000FIRST HIT:|r "..dName.." |cFFFFD100¡Pulleó a |r"..destName.."|cFFFFD100!|r") end
                SendRW(realName.." ¡PULLEASTE! - First Hit")
            end
        end
    end
end)
