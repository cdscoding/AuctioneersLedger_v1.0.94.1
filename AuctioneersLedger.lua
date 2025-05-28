-- Auctioneer's Ledger - v1.0.0 - Created by Clint Seewald (CS&A-Software)
local ADDON_NAME = "AuctioneersLedger";
local LDB_PREFIX = "AuctioneersLedgerDB";

local AL = {};
_G.AL = AL;

AL.VERSION = "1.0.0";

-- Constants (Layout and Appearance) 
AL.COL_PADDING = 5;
AL.ICON_TEXT_PADDING = 4;
AL.ITEM_ICON_SIZE = 18; AL.COL_ICON_WIDTH = AL.ITEM_ICON_SIZE; AL.COL_NAME_TEXT_WIDTH = 230;
AL.COL_LOCATION_WIDTH = 100; AL.COL_OWNED_WIDTH = 60;
AL.COL_NOTES_WIDTH = 130;
AL.COL_CHARACTER_WIDTH = 100;
AL.COL_REALM_WIDTH = 110;
AL.COL_DELETE_BTN_AREA_WIDTH = 80; 
AL.DELETE_BUTTON_SIZE = 16;
AL.EXPAND_BUTTON_SIZE = 16;
AL.CHILD_ROW_INDENT = 50;
AL.PARENT_ICON_AREA_X_OFFSET = 0;
AL.CHILD_ICON_AREA_X_OFFSET = 0;
AL.EFFECTIVE_NAME_COL_WIDTH = AL.EXPAND_BUTTON_SIZE + AL.ICON_TEXT_PADDING + AL.COL_ICON_WIDTH + AL.ICON_TEXT_PADDING + AL.COL_NAME_TEXT_WIDTH;
AL.LEFT_PANEL_WIDTH = 200;
AL.MIN_WINDOW_WIDTH = 1100;
AL.MIN_WINDOW_HEIGHT = 720;
AL.DIVIDER_THICKNESS = 4; AL.WINDOW_DIVIDER_COLOR = {0.45, 0.45, 0.45, 0.8};
AL.HELP_WINDOW_WIDTH = 740;
AL.HELP_WINDOW_HEIGHT = 600;
AL.LABEL_BACKDROP_COLOR = {1, 1, 1, 1};
AL.LABEL_TEXT_COLOR = {1, 0.82, 0, 1};
AL.CHILD_ROW_DATA_JUSTIFY_H = "CENTER";

-- Constants (Functional)
AL.DEFAULT_WINDOW_WIDTH = 1100;
AL.DEFAULT_WINDOW_HEIGHT = 720;
AL.BUTTON_HEIGHT = 24; AL.BUTTON_SPACING = 6;
AL.POPUP_WIDTH = 240; AL.POPUP_HEIGHT = 160;
AL.POPUP_OFFSET_X = 10; AL.ORIGINAL_POPUP_TEXT = "Drag an item from your bags here\nto add it for tracking."; AL.POPUP_FEEDBACK_DURATION = 4;
AL.ITEM_ROW_HEIGHT = 22; AL.MAX_TRACKED_ITEMS = 150;
AL.COLUMN_HEADER_HEIGHT = 20;
AL.EVENT_DEBOUNCE_TIME = 0.75;
AL.PERIODIC_REFRESH_INTERVAL = 7.0; AL.MAIL_REFRESH_DELAY = 0.25;
AL.MAX_MAIL_ATTACHMENTS_TO_SCAN = 12;
AL.STALE_DATA_THRESHOLD = 300;

-- Constants (Colors)
AL.ROW_COLOR_EVEN = {0.17, 0.17, 0.20, 0.7}; AL.ROW_COLOR_ODD = {0.14, 0.14, 0.17, 0.7};
AL.COLOR_LIMBO = {0.6, 0.6, 0.6, 1.0};
AL.COLOR_STALE_MULTIPLIER = 0.75;
AL.COLOR_DEFAULT_TEXT_RGB = {221/255, 221/255, 221/255, 1.0};
AL.COLOR_BANK_GOLD = {0.9, 0.7, 0.3, 1.0};
AL.COLOR_AH_BLUE = {0.5, 0.8, 1.0, 1.0};
AL.COLOR_MAIL_TAN = {0.82, 0.70, 0.55, 1.0};
AL.COLOR_PARENT_ROW_TEXT_NEUTRAL = {0.85, 0.85, 0.95, 0.7};

-- Sort Criteria Constants
AL.SORT_ALPHA = "ALPHA";
AL.SORT_BAGS = "BAGS";
AL.SORT_BANK = "BANK";
AL.SORT_MAIL = "MAIL";
AL.SORT_AUCTION = "AUCTION";
AL.SORT_LIMBO = "LIMBO";
AL.SORT_CHARACTER = "CHARACTER";
AL.SORT_REALM = "REALM";
AL.SORT_QUALITY_PREFIX = "QUALITY_";

_G.AL_SavedData = _G.AL_SavedData or {
    window={x=nil,y=nil,width=AL.DEFAULT_WINDOW_WIDTH,height=AL.DEFAULT_WINDOW_HEIGHT,visible=true},
    firstRun=true, minimapIcon={},
    trackedItems={},
    lastSortCriteria = AL.SORT_ALPHA,
    itemExpansionStates = {},
    activeQualityFilter = nil,
    viewMode = "GROUPED_BY_ITEM",
};

local function InitializeTrackedItemEntry(itemEntry, currentCharacterName, currentCharacterRealm)
    itemEntry.lastVerifiedLocation = itemEntry.lastVerifiedLocation or nil;
    itemEntry.lastVerifiedCount = itemEntry.lastVerifiedCount or 0;
    itemEntry.lastVerifiedTimestamp = itemEntry.lastVerifiedTimestamp or 0;
    itemEntry.characterName = itemEntry.characterName or currentCharacterName;
    itemEntry.characterRealm = itemEntry.characterRealm or currentCharacterRealm;
end

-- Initialize AL table fields
AL.reminderPopupLastX = nil; AL.reminderPopupLastY = nil; AL.revertPopupTextTimer = nil;
AL.itemRowFrames = {}; AL.eventRefreshTimer = nil; AL.eventDebounceCounter = 0; AL.periodicRefreshTimer = nil;
AL.addonLoadedProcessed = false; AL.libsReady = false;
AL.LDB_Lib = nil; AL.LibDBIcon_Lib = nil; AL.LDBObject = nil;
AL.MainWindow = nil; AL.LeftPanel = nil; AL.CreateReminderButton = nil; AL.RefreshListButton = nil; AL.HelpWindowButton = nil; AL.ToggleMinimapButton = nil;
AL.SortAlphaButton = nil; AL.SortBagsButton = nil; AL.SortBankButton = nil; AL.SortMailButton = nil; AL.SortAuctionButton = nil; AL.SortLimboButton = nil;
AL.SortCharacterButton = nil; AL.SortRealmButton = nil;
AL.SortQualityButtons = {};
AL.LabelSortBy = nil; AL.LabelFilterLocation = nil; AL.LabelFilterQuality = nil;
AL.ColumnHeaderFrame = nil; AL.ScrollFrame = nil; AL.ScrollChild = nil;
AL.ReminderPopup = nil;
AL.HelpWindow = nil; AL.HelpWindowScrollFrame = nil; AL.HelpWindowScrollChild = nil; AL.HelpWindowFontString = nil;
AL.testSetScriptControlDone = false;
AL.mainDividers = {};
AL.postItemHooked = false;
AL.mailAPIsMissingLogged = false;
AL.mailRefreshTimer = nil;
AL.ahEntryDumpDone = false;
AL.gameFullyInitialized = false; 
AL.currentSortCriteria = _G.AL_SavedData.lastSortCriteria or AL.SORT_ALPHA;
AL.currentViewMode = _G.AL_SavedData.viewMode or "GROUPED_BY_ITEM";
AL.currentQualityFilter = _G.AL_SavedData.activeQualityFilter;

-- Helper function to get container number of slots, trying C_Container first
local function GetSafeContainerNumSlots(bagIndex)
    if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
        return C_Container.GetContainerNumSlots(bagIndex);
    elseif type(GetContainerNumSlots) == "function" then 
        return GetContainerNumSlots(bagIndex);
    end
    return 0; 
end

-- Helper function to get container item link, trying C_Container first
local function GetSafeContainerItemLink(bagIndex, slotIndex)
    if C_Container and type(C_Container.GetContainerItemLink) == "function" then
        return C_Container.GetContainerItemLink(bagIndex, slotIndex);
    elseif type(GetContainerItemLink) == "function" then 
        return GetContainerItemLink(bagIndex, slotIndex);
    end
    return nil; 
end


function AL:InitializeLibs()
    if self.libsReady then return; end
    self.LDB_Lib = LibStub("LibDataBroker-1.1", true);
    self.LibDBIcon_Lib = LibStub("LibDBIcon-1.0", true);
    if not self.LDB_Lib then DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. " (v" .. AL.VERSION .. ") Warning: LibDataBroker-1.1 not found!"); end
    if not self.LibDBIcon_Lib then DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. " (v" .. AL.VERSION .. ") Warning: LibDBIcon-1.0 not found!"); end
    self.libsReady = (self.LDB_Lib ~= nil and self.LibDBIcon_Lib ~= nil);
    if not self.libsReady then DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. " (v" .. AL.VERSION .. ") Error: Library initialization failed. LDB/Minimap features may be unavailable."); end
end

function AL:CreateLDBSourceAndMinimapIcon()
    if not self.libsReady or not self.LDB_Lib then DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. " (v" .. AL.VERSION .. ") Warning: Cannot create LDB object or Minimap Icon - Libs not ready or LDB_Lib missing."); return; end;
    if self.LDBObject then
        self.LDB_Lib:UpdateDataObject(LDB_PREFIX,{type = "launcher", label = ADDON_NAME, icon = "Interface\\Icons\\inv_7xp_inscription_talenttome01", OnClick = function(_, button)
            if IsShiftKeyDown() and IsControlKeyDown() and button == "LeftButton" then
                _G.AL_SavedData.minimapIcon.hide = not _G.AL_SavedData.minimapIcon.hide;
                if AL.LibDBIcon_Lib then
                    if _G.AL_SavedData.minimapIcon.hide then AL.LibDBIcon_Lib:Hide(LDB_PREFIX);
                    else AL.LibDBIcon_Lib:Show(LDB_PREFIX); end
                end
            elseif IsShiftKeyDown() and button == "LeftButton" then
                _G.AL_SavedData.window.x = nil; _G.AL_SavedData.window.y = nil;
                _G.AL_SavedData.window.width = AL.DEFAULT_WINDOW_WIDTH;
                _G.AL_SavedData.window.height = AL.DEFAULT_WINDOW_HEIGHT;
                _G.AL_SavedData.firstRun = true;
                if AL.MainWindow and AL.MainWindow:IsShown() then AL:ApplyWindowState(); else AL:ToggleMainWindow(); end
            elseif button == "LeftButton" then AL:ToggleMainWindow(); end
        end, OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            tooltip:AddLine(ADDON_NAME);
            tooltip:AddLine("Left-Click: Toggle Window");
            tooltip:AddLine("Shift + Left-Click: Reset Window Position/Size.");
            tooltip:AddLine("Ctrl + Shift + Left-Click: Toggle Minimap Icon.");
        end });
        return;
    end;
    self.LDBObject = self.LDB_Lib:NewDataObject(LDB_PREFIX,{ type = "launcher", label = ADDON_NAME, icon = "Interface\\Icons\\inv_7xp_inscription_talenttome01", OnClick = function(_, button)
        if IsShiftKeyDown() and IsControlKeyDown() and button == "LeftButton" then
            _G.AL_SavedData.minimapIcon.hide = not _G.AL_SavedData.minimapIcon.hide;
            if AL.LibDBIcon_Lib then
                if _G.AL_SavedData.minimapIcon.hide then AL.LibDBIcon_Lib:Hide(LDB_PREFIX);
                else AL.LibDBIcon_Lib:Show(LDB_PREFIX); end
            end
        elseif IsShiftKeyDown() and button == "LeftButton" then
            _G.AL_SavedData.window.x = nil; _G.AL_SavedData.window.y = nil;
            _G.AL_SavedData.window.width = AL.DEFAULT_WINDOW_WIDTH;
            _G.AL_SavedData.window.height = AL.DEFAULT_WINDOW_HEIGHT;
            _G.AL_SavedData.firstRun = true;
            if AL.MainWindow and AL.MainWindow:IsShown() then AL:ApplyWindowState(); else AL:ToggleMainWindow(); end
        elseif button == "LeftButton" then AL:ToggleMainWindow(); end
    end, OnTooltipShow = function(tooltip)
        if not tooltip or not tooltip.AddLine then return end
        tooltip:AddLine(ADDON_NAME);
        tooltip:AddLine("Left-Click: Toggle Window");
        tooltip:AddLine("Shift + Left-Click: Reset Window Position/Size.");
        tooltip:AddLine("Ctrl + Shift + Left-Click: Toggle Minimap Icon.");
    end });
    if self.LibDBIcon_Lib and self.LDBObject then _G.AL_SavedData.minimapIcon = _G.AL_SavedData.minimapIcon or {}; self.LibDBIcon_Lib:Register(LDB_PREFIX, self.LDBObject, _G.AL_SavedData.minimapIcon);
    else DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. " (v" .. AL.VERSION .. ") Warning: Could not register LDB object/Minimap Icon (LibDBIcon: " .. tostring(self.LibDBIcon_Lib) .. ", LDBObject: " .. tostring(self.LDBObject) .. ")."); end
end

function AL:GetItemIDFromLink(itemLink) if not itemLink or type(itemLink) ~= "string" then return nil; end; return tonumber(string.match(itemLink, "item:(%d+)")); end
function AL:GetItemNameFromLink(itemLink) if not itemLink or type(itemLink) ~= "string" then return "Unknown Item"; end; local iN=GetItemInfo(itemLink); return iN or "Unknown Item"; end
function AL:IsItemAuctionable_Fallback(itemLink) if not itemLink then return false; end; local iN,_,_,_,_,_,_,_,_,_,_,_,_,bT=GetItemInfo(itemLink); if not iN then return false; end; if bT==1 then return false; end; if bT==4 then return false; end; return true; end

function AL:TriggerDebouncedRefresh(reason)
    local debounceSeconds = tonumber(self.EVENT_DEBOUNCE_TIME);
    if type(debounceSeconds) ~= "number" or debounceSeconds <= 0 then
        -- Keep this message as it's a config error, not typical debug.
        DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ":|cFFFF0000 ERROR!|r EVENT_DEBOUNCE_TIME is not a valid positive number. Using fallback 0.75s.");
        debounceSeconds = 0.75;
    end
    self.eventDebounceCounter = (self.eventDebounceCounter or 0) + 1;
    if self.eventRefreshTimer then self.eventRefreshTimer:Cancel(); self.eventRefreshTimer = nil; end
    local success, err = pcall(function()
        self.eventRefreshTimer = C_Timer.After(debounceSeconds, function()
            self.eventDebounceCounter = 0;
            if self.RefreshLedgerDisplay then self:RefreshLedgerDisplay();
            else DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ":|cFFFF0000 ERROR!|r AL.RefreshLedgerDisplay is nil in debounced call!"); end;
            self.eventRefreshTimer = nil;
        end);
    end)
    if not success then DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ":|cFFFF0000 FATAL ERROR|r in TriggerDebouncedRefresh pcall! Error: " .. tostring(err)); end
end

function AL:GetItemOwnershipDetails(trackedItemEntry)
    local d = {
        liveLocation = nil, liveCount = 0,
        locationText = "Limbo",
        colorR, colorG, colorB, colorA = unpack(AL.COLOR_LIMBO),
        displayText = "00", notesText = "", isStale = false, isLink = false
    };
    if not trackedItemEntry or not trackedItemEntry.itemID then return d; end

    local itemID = trackedItemEntry.itemID;
    local itemCharacterName = trackedItemEntry.characterName;
    local itemCharacterRealm = trackedItemEntry.characterRealm;

    local currentCharacter = UnitName("player");
    local currentRealm = GetRealmName();
    local isCurrentCharacterItem = (itemCharacterName == currentCharacter and itemCharacterRealm == currentRealm);

    local itemNameLog = trackedItemEntry.itemName or "ItemID("..itemID..")";

    if isCurrentCharacterItem then
        local mailScannedThisPass = false;
        local ahScannedThisPass = false;
        local bagsCount = GetItemCount(itemID, false, false, false);
        if bagsCount > 0 then d.liveLocation = "Bags"; d.liveCount = bagsCount; end
        if not d.liveLocation then
            local totalInBagsAndBank = GetItemCount(itemID, true, false, false);
            local bankCount = totalInBagsAndBank - bagsCount;
            if bankCount > 0 then d.liveLocation = "Bank"; d.liveCount = bankCount; end
        end

        if d.liveLocation then
            d.locationText = d.liveLocation;
            d.displayText = string.format("%02d", d.liveCount);
            if d.liveLocation == "Bags" then d.isLink = true; end
            trackedItemEntry.lastVerifiedLocation = d.liveLocation;
            trackedItemEntry.lastVerifiedCount = d.liveCount;
            trackedItemEntry.lastVerifiedTimestamp = GetTime();
            d.notesText = ""; d.isStale = false;
        else
            local mailCountThisScan = 0;
            if MailFrame and MailFrame:IsShown() then
                mailScannedThisPass = true;
                local ginType = type(GetInboxNumItems); local gihType = type(GetInboxHeaderInfo); local giType  = type(GetInboxItem); 
                if ginType == "function" and gihType == "function" and giType == "function" then
                    local numInboxItems = GetInboxNumItems();
                    if numInboxItems and numInboxItems > 0 then
                        for mailIndex = 1, numInboxItems do
                            local _, _, _, _, _, _, _, hasItem = GetInboxHeaderInfo(mailIndex);
                            if hasItem then
                                for attachIndex = 1, AL.MAX_MAIL_ATTACHMENTS_TO_SCAN do
                                    local _, mailItemID_R2, _, mailItemCount_R4 = GetInboxItem(mailIndex, attachIndex);
                                    if mailItemID_R2 and mailItemCount_R4 and mailItemCount_R4 > 0 and tonumber(mailItemID_R2) == itemID then mailCountThisScan = mailCountThisScan + mailItemCount_R4; end
                                    if not mailItemID_R2 and attachIndex == 1 then break; elseif not mailItemID_R2 then break; end
                                end
                            end
                        end
                    end; AL.mailAPIsMissingLogged = false;
                else
                    if not AL.mailAPIsMissingLogged then DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. " (v" .. AL.VERSION .. ") Mail API Issue for ["..itemNameLog.."]: Required functions missing."); AL.mailAPIsMissingLogged = true; end
                end
                if mailCountThisScan > 0 then
                    d.liveLocation = "Mail"; d.liveCount = mailCountThisScan;
                    trackedItemEntry.lastVerifiedLocation = "Mail"; trackedItemEntry.lastVerifiedCount = d.liveCount; trackedItemEntry.lastVerifiedTimestamp = GetTime();
                elseif trackedItemEntry.lastVerifiedLocation == "Mail" then trackedItemEntry.lastVerifiedLocation = nil; trackedItemEntry.lastVerifiedCount = 0; end
            end
            local ahCountThisScan = 0;
            if not d.liveLocation then
                local cahType = type(C_AuctionHouse); local goaType = cahType == "table" and type(C_AuctionHouse.GetOwnedAuctions) or "nil";
                if goaType == "function" then
                    if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
                        ahScannedThisPass = true;
                        local ownedAuctionsTable = C_AuctionHouse.GetOwnedAuctions();
                        if ownedAuctionsTable and type(ownedAuctionsTable) == "table" then
                            for i, auctionEntry in ipairs(ownedAuctionsTable) do
                                local entryItemID, entryItemCount;
                                if auctionEntry and type(auctionEntry) == "table" then
                                    if auctionEntry.itemKey and type(auctionEntry.itemKey) == "table" and auctionEntry.itemKey.itemID and type(auctionEntry.itemKey.itemID) == "number" then entryItemID = auctionEntry.itemKey.itemID; end
                                    if auctionEntry.quantity and type(auctionEntry.quantity) == "number" then entryItemCount = auctionEntry.quantity; end
                                    if not entryItemID and auctionEntry.itemLink and type(auctionEntry.itemLink) == "string" then entryItemID = self:GetItemIDFromLink(auctionEntry.itemLink); if not entryItemCount and auctionEntry.count and type(auctionEntry.count) == "number" then entryItemCount = auctionEntry.count; end end
                                end
                                if entryItemID and entryItemCount and tonumber(entryItemID) == itemID then ahCountThisScan = ahCountThisScan + entryItemCount; end
                            end
                        end
                        if ahCountThisScan > 0 then
                            d.liveLocation = "AH"; d.liveCount = ahCountThisScan;
                            trackedItemEntry.lastVerifiedLocation = "AH"; trackedItemEntry.lastVerifiedCount = d.liveCount; trackedItemEntry.lastVerifiedTimestamp = GetTime();
                        elseif trackedItemEntry.lastVerifiedLocation == "AH" then trackedItemEntry.lastVerifiedLocation = nil; trackedItemEntry.lastVerifiedCount = 0; end
                    end
                end
            end
            if d.liveLocation then
                if d.liveLocation == "AH" then d.locationText = "Auction House"; else d.locationText = d.liveLocation; end
                d.displayText = string.format("%02d", d.liveCount); d.notesText = ""; d.isStale = false;
            else
                local usedStaleData = false;
                if trackedItemEntry.lastVerifiedLocation and trackedItemEntry.lastVerifiedCount > 0 then
                    local useStale = false; local noteForStale = ""; local locationForDisplayStale = trackedItemEntry.lastVerifiedLocation;
                    if trackedItemEntry.lastVerifiedLocation == "Mail" then useStale = true; noteForStale = "Inside mailbox."; locationForDisplayStale = "Mail";
                    elseif trackedItemEntry.lastVerifiedLocation == "AH" then useStale = true; noteForStale = "Being auctioned."; locationForDisplayStale = "Auction House"; end
                    if useStale then
                        d.locationText = locationForDisplayStale; d.displayText = string.format("%02d", trackedItemEntry.lastVerifiedCount);
                        d.isStale = true; d.notesText = noteForStale; usedStaleData = true;
                    end
                end
                if not usedStaleData then d.locationText = "Limbo"; d.displayText = "00"; d.notesText = ""; end
            end
        end
    else -- Item belongs to an alt
        d.locationText = trackedItemEntry.lastVerifiedLocation or "Limbo";
        if d.locationText == "AH" then d.locationText = "Auction House"; end
        d.displayText = string.format("%02d", trackedItemEntry.lastVerifiedCount or 0);
        d.isStale = true;
        if trackedItemEntry.lastVerifiedLocation == "Mail" then d.notesText = "Inside mailbox.";
        elseif trackedItemEntry.lastVerifiedLocation == "AH" then d.notesText = "Being auctioned.";
        else d.notesText = ""; end
        d.isLink = false;
    end

    if d.locationText == "Bags" then d.colorR, d.colorG, d.colorB = GetItemQualityColor(trackedItemEntry.itemRarity or 1); d.colorA = 1.0;
    elseif d.locationText == "Bank" then d.colorR, d.colorG, d.colorB, d.colorA = unpack(AL.COLOR_BANK_GOLD);
    elseif d.locationText == "Mail" then d.colorR, d.colorG, d.colorB, d.colorA = unpack(AL.COLOR_MAIL_TAN);
    elseif d.locationText == "Auction House" then d.colorR, d.colorG, d.colorB, d.colorA = unpack(AL.COLOR_AH_BLUE);
    elseif d.locationText == "Limbo" then d.colorR, d.colorG, d.colorB, d.colorA = unpack(AL.COLOR_LIMBO);
    else d.colorR, d.colorG, d.colorB = GetItemQualityColor(trackedItemEntry.itemRarity or 1); d.colorA = 1.0; end

    if d.isStale and d.locationText ~= "Limbo" then
        d.colorR, d.colorG, d.colorB = d.colorR * AL.COLOR_STALE_MULTIPLIER, d.colorG * AL.COLOR_STALE_MULTIPLIER, d.colorB * AL.COLOR_STALE_MULTIPLIER;
    end

    return d;
end

function AL:InternalAddItem(itemLink, forCharName, forCharRealm)
    local itemName, realItemLink, itemRarity, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink);
    realItemLink = realItemLink or itemLink;
    if not itemName or not itemTexture then return false, "Could not get item info."; end
    local itemID = self:GetItemIDFromLink(realItemLink);
    if not itemID then return false, "Could not get item ID."; end

    for _, trackedItem in ipairs(_G.AL_SavedData.trackedItems) do
        if trackedItem.itemID == itemID and trackedItem.characterName == forCharName and trackedItem.characterRealm == forCharRealm then
            return false, "Already tracked";
        end
    end
    if #_G.AL_SavedData.trackedItems >= AL.MAX_TRACKED_ITEMS then return false, "Max items limit reached."; end

    local itemData = {
        itemID = itemID, itemLink = realItemLink, itemName = itemName, itemTexture = itemTexture, itemRarity = itemRarity,
        characterName = forCharName, characterRealm = forCharRealm,
        lastVerifiedLocation = nil, lastVerifiedCount = 0, lastVerifiedTimestamp = 0
    };
    InitializeTrackedItemEntry(itemData, forCharName, forCharRealm);
    table.insert(_G.AL_SavedData.trackedItems, itemData);
    return true, itemName;
end

function AL:ProcessAndStoreItem(itemLink)
    local charName = UnitName("player");
    local charRealm = GetRealmName();
    local success, resultOrMsg = self:InternalAddItem(itemLink, charName, charRealm);

    if success then
        self:SetReminderPopupFeedback("'"..resultOrMsg.."' added for " .. charName .. "!", true);
        self:RefreshLedgerDisplay();
    else
        if resultOrMsg == "Already tracked" then
            local itemNameForFeedback = self:GetItemNameFromLink(itemLink) or "Item";
            self:SetReminderPopupFeedback("'"..itemNameForFeedback.."' is already tracked for " .. charName .. ".", false);
        else
            self:SetReminderPopupFeedback(resultOrMsg, false);
        end
    end
end

function AL:SetReminderPopupFeedback(message,isSuccess)
    if self.ReminderPopup and self.ReminderPopup.InstructionText then
        if isSuccess then self.ReminderPopup.InstructionText:SetTextColor(0.2,1,0.2); else self.ReminderPopup.InstructionText:SetTextColor(1,0.2,0.2);end;
        self.ReminderPopup.InstructionText:SetText(message);
        if self.revertPopupTextTimer then self.revertPopupTextTimer:Cancel();self.revertPopupTextTimer=nil;end;
        self.revertPopupTextTimer=C_Timer.After(AL.POPUP_FEEDBACK_DURATION,function() if AL.ReminderPopup and AL.ReminderPopup:IsShown()and AL.ReminderPopup.InstructionText then AL.ReminderPopup.InstructionText:SetText(AL.ORIGINAL_POPUP_TEXT); AL.ReminderPopup.InstructionText:SetTextColor(1,1,1); end; AL.revertPopupTextTimer=nil; end);
    end
end

-- This is the core bag scanning logic
function AL:AddAllEligibleItemsFromBags_ActualScan()
    local currentVersion = AL.VERSION or "N/A";
    local charName = UnitName("player");
    local charRealm = GetRealmName();
    local addedCount = 0;
    local skippedAlreadyTracked = 0;
    local skippedIneligible = 0;
    local skippedMaxReachedCount = 0;
    local maxItems = AL.MAX_TRACKED_ITEMS;

    local alreadyTrackedForChar = {};
    for _, trackedItem in ipairs(_G.AL_SavedData.trackedItems) do
        if trackedItem.characterName == charName and trackedItem.characterRealm == charRealm then
            alreadyTrackedForChar[trackedItem.itemID] = true;
        end
    end

    local maxLimitReachedInScan = false;
    
    local firstBag = (type(Enum) == "table" and type(Enum.BagIndex) == "table" and type(Enum.BagIndex.Backpack) == "number" and Enum.BagIndex.Backpack) or 0;
    local lastBag  = (type(Enum) == "table" and type(Enum.BagIndex) == "table" and type(Enum.BagIndex.Bag4) == "number" and Enum.BagIndex.Bag4) or 4;

    if firstBag > lastBag then 
        -- This message can stay as it indicates a fundamental problem with bag constants.
        DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. " (v" .. currentVersion .. "): Error (ActualScan) - Invalid bag range (" .. tostring(firstBag) .. " to " .. tostring(lastBag) .. "). Aborting.");
        self:SetReminderPopupFeedback("Error: Invalid bag range. Aborting.", false);
        return;
    end
    
    for bag = firstBag, lastBag do
        local numSlotsAttempt = GetSafeContainerNumSlots(bag); 
        local numSlots = (type(numSlotsAttempt) == "number" and numSlotsAttempt) or 0;

        for slot = 1, numSlots do
            if #_G.AL_SavedData.trackedItems >= maxItems then
                skippedMaxReachedCount = skippedMaxReachedCount + (numSlots - slot + 1);
                for b = bag + 1, lastBag do 
                    local slotsInNextBagAttempt = GetSafeContainerNumSlots(b); 
                    local slotsInNextBag = (type(slotsInNextBagAttempt) == "number" and slotsInNextBagAttempt) or 0;
                    skippedMaxReachedCount = skippedMaxReachedCount + slotsInNextBag;
                end
                maxLimitReachedInScan = true;
                break; 
            end

            local itemLink = GetSafeContainerItemLink(bag, slot); 
            if itemLink then
                local itemID = self:GetItemIDFromLink(itemLink);
                if itemID then
                    if alreadyTrackedForChar[itemID] then
                        skippedAlreadyTracked = skippedAlreadyTracked + 1;
                    elseif not self:IsItemAuctionable_Fallback(itemLink) then
                        skippedIneligible = skippedIneligible + 1;
                    else
                        local success, _ = self:InternalAddItem(itemLink, charName, charRealm);
                        if success then
                            addedCount = addedCount + 1;
                            alreadyTrackedForChar[itemID] = true; 
                        else
                            skippedIneligible = skippedIneligible + 1; 
                        end
                    end
                else
                    skippedIneligible = skippedIneligible + 1;
                end
            end
        end 
        if maxLimitReachedInScan then
            break; 
        end
    end 

    local feedbackMsg = addedCount .. " new item(s) added from bags.";
    local details = {};
    if skippedAlreadyTracked > 0 then table.insert(details, skippedAlreadyTracked .. " already tracked"); end
    if skippedIneligible > 0 then table.insert(details, skippedIneligible .. " ineligible/invalid"); end
    if skippedMaxReachedCount > 0 then table.insert(details, "Max item limit ("..maxItems..") reached, " .. skippedMaxReachedCount .. " potential items not checked/skipped"); end

    if #details > 0 then
        feedbackMsg = feedbackMsg .. " (" .. table.concat(details, ", ") .. ").";
    end

    self:SetReminderPopupFeedback(feedbackMsg, addedCount > 0);

    if addedCount > 0 then
        self:RefreshLedgerDisplay();
    end
end

-- Simplified check before actual scan; no retry loop needed now
function AL:AttemptAddAllEligibleItemsFromBags()
    local currentVersion = AL.VERSION or "N/A";

    local cApiGCSAvailable = (C_Container and type(C_Container.GetContainerNumSlots) == "function")
    local cApiGCILAvailable = (C_Container and type(C_Container.GetContainerItemLink) == "function")
    local globalGCSAvailable = (type(GetContainerNumSlots) == "function")
    local globalGCILAvailable = (type(GetContainerItemLink) == "function")

    local canProceed = (cApiGCSAvailable and cApiGCILAvailable) or (globalGCSAvailable and globalGCILAvailable)

    if not canProceed then
        -- This message is important for the user if something is fundamentally wrong with bag APIs.
        DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. " (v" .. currentVersion .. "): Bag API functions are not available. Please try /reload ui or ensure your game client is up to date. (C_GCS: " .. tostring(cApiGCSAvailable) .. ", C_GCIL: " .. tostring(cApiGCILAvailable) .. ", G_GCS: " .. tostring(globalGCSAvailable) .. ", G_GCIL: " .. tostring(globalGCILAvailable) .. ")");
        self:SetReminderPopupFeedback("Error: Bag functions unavailable. Try /reload.", false);
        return;
    end
    
    self:AddAllEligibleItemsFromBags_ActualScan();
end


function AL:CreateReminderPopup()
    local frameNameSuffix = "_v" .. AL.VERSION:gsub("%.", "_");
    if self.ReminderPopup and self.ReminderPopup:IsObjectType("Frame") and self.ReminderPopup:GetName() == "AL_ReminderPopup" .. frameNameSuffix then return;end;
    local p=CreateFrame("Frame","AL_ReminderPopup" .. frameNameSuffix,UIParent,"BasicFrameTemplateWithInset");self.ReminderPopup=p;
    p:SetSize(AL.POPUP_WIDTH,AL.POPUP_HEIGHT);p:SetFrameStrata("DIALOG");p:SetFrameLevel(10);p:EnableMouse(true);p:SetMovable(true);p:SetClampedToScreen(true);p.TitleText:SetText("Track New Item");
    p:RegisterForDrag("LeftButton");p:SetScript("OnDragStart",function(s)if s.isMoving then return;end s:StartMoving();s.isMoving=true;end); p:SetScript("OnDragStop",function(s)s:StopMovingOrSizing();s.isMoving=false;AL.reminderPopupLastX=s:GetLeft();AL.reminderPopupLastY=UIParent:GetHeight()-s:GetTop();end);
    
    local t=p:CreateFontString(nil,"ARTWORK","GameFontNormal");
    t:SetPoint("CENTER", 0, 20);
    t:SetText(AL.ORIGINAL_POPUP_TEXT);t:SetJustifyH("CENTER");t:SetJustifyV("MIDDLE");self.ReminderPopup.InstructionText=t;
    
    local addAllBtn = CreateFrame("Button", "AL_ReminderAddAllButton" .. frameNameSuffix, p, "UIPanelButtonTemplate");
    addAllBtn:SetSize(AL.POPUP_WIDTH - 40, AL.BUTTON_HEIGHT);
    addAllBtn:SetText("Add All Eligible Items From Bags"); 
    addAllBtn:SetPoint("BOTTOM", p, "BOTTOM", 0, 10);
    addAllBtn:SetScript("OnClick", function()
        if not AL.gameFullyInitialized then
            AL:SetReminderPopupFeedback("Game systems are initializing, please wait a moment and try again.", false);
            return;
        end
        AL:AttemptAddAllEligibleItemsFromBags(); 
    end);
    self.ReminderPopup.AddAllButton = addAllBtn;

    p:SetScript("OnReceiveDrag", function(dragSelf) local cT,_,iL=GetCursorInfo();ClearCursor(); if cT=="item"and iL then local iN=AL:GetItemNameFromLink(iL); local iAA=AL:IsItemAuctionable_Fallback(iL); if iAA then AL:ProcessAndStoreItem(iL); else AL:SetReminderPopupFeedback("This item cannot be auctioned.",false);end; else AL:SetReminderPopupFeedback("Drag valid item.",false);end; end);
    p.CloseButton:SetScript("OnClick",function()AL:HideReminderPopup();end);
    p:SetScript("OnHide",function() 
        if GetCursorInfo()then ClearCursor();end; 
        if AL.revertPopupTextTimer then AL.revertPopupTextTimer:Cancel();AL.revertPopupTextTimer=nil;end; 
        if AL.ReminderPopup and AL.ReminderPopup.InstructionText then AL.ReminderPopup.InstructionText:SetText(AL.ORIGINAL_POPUP_TEXT); AL.ReminderPopup.InstructionText:SetTextColor(1,1,1); end;
    end);
    p:Hide();
end

function AL:ShowReminderPopup()
    if not self.MainWindow or not self.MainWindow:IsShown()then return;end;
    if not self.ReminderPopup then self:CreateReminderPopup();if not self.ReminderPopup then return;end end;
    self.ReminderPopup:ClearAllPoints();
    if self.reminderPopupLastX and self.reminderPopupLastY then self.ReminderPopup:SetPoint("TOPLEFT",nil,"TOPLEFT",self.reminderPopupLastX,-self.reminderPopupLastY);
    else self.ReminderPopup:SetPoint("TOPLEFT",self.MainWindow,"TOPRIGHT",AL.POPUP_OFFSET_X,0); local rE=self.ReminderPopup:GetLeft()+self.ReminderPopup:GetWidth();local sW=GetScreenWidth()/UIParent:GetEffectiveScale(); if rE>sW-10 then self.ReminderPopup:ClearAllPoints();self.ReminderPopup:SetPoint("TOPRIGHT",self.MainWindow,"TOPLEFT",-AL.POPUP_OFFSET_X,0);end; end;
    if self.ReminderPopup.InstructionText then self.ReminderPopup.InstructionText:SetText(AL.ORIGINAL_POPUP_TEXT);self.ReminderPopup.InstructionText:SetTextColor(1,1,1);end;
    if self.revertPopupTextTimer then self.revertPopupTextTimer:Cancel();self.revertPopupTextTimer=nil;end;
    self.ReminderPopup:Show();self.ReminderPopup:Raise();
end

function AL:HideReminderPopup()
    if self.ReminderPopup and self.ReminderPopup:IsObjectType("Frame") and self.ReminderPopup:IsShown()then self.ReminderPopup:Hide();end
end

function AL:RemoveTrackedItem(itemIDToRemove, charNameToRemove, realmNameToRemove)
    local itemRemoved = false;
    for i = #_G.AL_SavedData.trackedItems, 1, -1 do
        local entry = _G.AL_SavedData.trackedItems[i];
        InitializeTrackedItemEntry(entry, entry.characterName, entry.characterRealm);
        if entry.itemID == itemIDToRemove and entry.characterName == charNameToRemove and entry.characterRealm == realmNameToRemove then
            table.remove(_G.AL_SavedData.trackedItems, i);
            itemRemoved = true;
            break;
        end;
    end;
    if itemRemoved then self:RefreshLedgerDisplay(); end;
end

function AL:RemoveAllInstancesOfItem(itemIDToRemove)
    local itemsRemoved = false;
    local removedItemName = nil;
    for i = #_G.AL_SavedData.trackedItems, 1, -1 do
        local entry = _G.AL_SavedData.trackedItems[i];
        if entry.itemID == itemIDToRemove then
            if not removedItemName then removedItemName = entry.itemName or ("Item ID: " .. itemIDToRemove); end
            table.remove(_G.AL_SavedData.trackedItems, i);
            itemsRemoved = true;
        end;
    end;

    if itemsRemoved then
        if _G.AL_SavedData.itemExpansionStates and _G.AL_SavedData.itemExpansionStates[itemIDToRemove] then
            _G.AL_SavedData.itemExpansionStates[itemIDToRemove] = nil;
        end
        DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. ": Removed all instances of " .. removedItemName .. ".");
        self:RefreshLedgerDisplay();
    end;
end

function AL:CreateItemRowFrame(parent, itemData, yOffset, isEvenRow, precomputedDetails, isParentRow, isExpanded)
    local r = CreateFrame("Frame", nil, parent);
    if not (r and r.IsObjectType and r:IsObjectType("Frame")) then return CreateFrame("Frame", nil, UIParent):Hide(); end
    r.isEvenRow = isEvenRow;
    r.itemID = itemData.itemID;
    r.characterName = itemData.characterName;
    r.characterRealm = itemData.characterRealm;
    r.isParentRow = isParentRow;

    if not parent or not parent.GetWidth then return r:Hide(); end
    local parentWidth = parent:GetWidth(); if not parentWidth or parentWidth <= 10 then parentWidth = 200; end
    r:SetSize(parentWidth, AL.ITEM_ROW_HEIGHT);

    r:SetPoint("TOPLEFT", 0, -yOffset); 

    r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(true);
    if isEvenRow then r.bg:SetColorTexture(unpack(AL.ROW_COLOR_EVEN)); else r.bg:SetColorTexture(unpack(AL.ROW_COLOR_ODD)); end

    local internalContentStartX = AL.COL_PADDING; 
    if not isParentRow then
        internalContentStartX = internalContentStartX + AL.CHILD_ROW_INDENT; 
    end

    local currentX = internalContentStartX; 
    local iconAreaXUserOffset = 0;

    if isParentRow then
        r.expandButton = CreateFrame("Button", nil, r);
        r.expandButton:SetSize(AL.EXPAND_BUTTON_SIZE, AL.EXPAND_BUTTON_SIZE);
        r.expandButton:SetPoint("LEFT", currentX, 0); 
        r.expandButton.icon = r.expandButton:CreateTexture(nil, "ARTWORK");
        r.expandButton.icon:SetAllPoints(true);
        r.expandButton.icon:SetTexture(isExpanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up");
        r.expandButton.itemID = itemData.itemID;
        r.expandButton:SetScript("OnClick", function(selfBtn)
            local itemID = selfBtn.itemID;
            _G.AL_SavedData.itemExpansionStates = _G.AL_SavedData.itemExpansionStates or {};
            _G.AL_SavedData.itemExpansionStates[itemID] = not _G.AL_SavedData.itemExpansionStates[itemID];
            AL:RefreshLedgerDisplay();
        end)
        iconAreaXUserOffset = AL.PARENT_ICON_AREA_X_OFFSET;
    else
        iconAreaXUserOffset = AL.CHILD_ICON_AREA_X_OFFSET;
    end
    currentX = currentX + AL.EXPAND_BUTTON_SIZE + AL.ICON_TEXT_PADDING; 

    local iconActualX = currentX + iconAreaXUserOffset;
    r.icon = r:CreateTexture(nil, "ARTWORK");
    r.icon:SetSize(AL.ITEM_ICON_SIZE, AL.ITEM_ICON_SIZE);
    r.icon:SetPoint("LEFT", r, "LEFT", iconActualX, 0);
    r.icon:SetTexture(itemData.itemTexture or "Interface\\Icons\\inv_misc_questionmark");

    local nameFsX = iconActualX + AL.ITEM_ICON_SIZE + AL.ICON_TEXT_PADDING;
    r.nameFS = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall");
    r.nameFS:SetHeight(AL.ITEM_ROW_HEIGHT);
    r.nameFS:SetJustifyH("LEFT"); 
    r.nameFS:SetJustifyV("MIDDLE");
    r.nameFS:SetWidth(AL.COL_NAME_TEXT_WIDTH);
    r.nameFS:SetPoint("LEFT", r, "LEFT", nameFsX, 0);

    local dataColBaseX = AL.COL_PADDING + AL.EFFECTIVE_NAME_COL_WIDTH + AL.COL_PADDING;

    r.locationFS = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); r.locationFS:SetHeight(AL.ITEM_ROW_HEIGHT); r.locationFS:SetJustifyH(AL.CHILD_ROW_DATA_JUSTIFY_H); r.locationFS:SetJustifyV("MIDDLE"); r.locationFS:SetWidth(AL.COL_LOCATION_WIDTH); r.locationFS:SetPoint("LEFT", r, "LEFT", dataColBaseX, 0);
    dataColBaseX = dataColBaseX + AL.COL_LOCATION_WIDTH + AL.COL_PADDING;

    r.ownedFS = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); r.ownedFS:SetHeight(AL.ITEM_ROW_HEIGHT); r.ownedFS:SetJustifyH(AL.CHILD_ROW_DATA_JUSTIFY_H); r.ownedFS:SetJustifyV("MIDDLE"); r.ownedFS:SetWidth(AL.COL_OWNED_WIDTH); r.ownedFS:SetPoint("LEFT", r, "LEFT", dataColBaseX, 0);
    dataColBaseX = dataColBaseX + AL.COL_OWNED_WIDTH + AL.COL_PADDING;

    r.notesFS = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); r.notesFS:SetHeight(AL.ITEM_ROW_HEIGHT); r.notesFS:SetJustifyH(AL.CHILD_ROW_DATA_JUSTIFY_H); r.notesFS:SetJustifyV("MIDDLE"); r.notesFS:SetWidth(AL.COL_NOTES_WIDTH); r.notesFS:SetPoint("LEFT", r, "LEFT", dataColBaseX, 0);
    dataColBaseX = dataColBaseX + AL.COL_NOTES_WIDTH + AL.COL_PADDING;

    r.characterFS = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); r.characterFS:SetHeight(AL.ITEM_ROW_HEIGHT); r.characterFS:SetJustifyH(AL.CHILD_ROW_DATA_JUSTIFY_H); r.characterFS:SetJustifyV("MIDDLE"); r.characterFS:SetWidth(AL.COL_CHARACTER_WIDTH); r.characterFS:SetPoint("LEFT", r, "LEFT", dataColBaseX, 0);
    dataColBaseX = dataColBaseX + AL.COL_CHARACTER_WIDTH + AL.COL_PADDING;

    r.realmFS = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); r.realmFS:SetHeight(AL.ITEM_ROW_HEIGHT); r.realmFS:SetJustifyH(AL.CHILD_ROW_DATA_JUSTIFY_H); r.realmFS:SetJustifyV("MIDDLE"); r.realmFS:SetWidth(AL.COL_REALM_WIDTH); r.realmFS:SetPoint("LEFT", r, "LEFT", dataColBaseX, 0);

    local actionsColFinalX = dataColBaseX + AL.COL_REALM_WIDTH + AL.COL_PADDING;
    local ownership = precomputedDetails;

    if isParentRow then
        local pr, pg, pb = GetItemQualityColor(itemData.itemRarity or 1); local pa = 1.0;
        r.nameFS:SetText(itemData.itemName or "Unknown Item");
        r.locationFS:SetText(""); r.ownedFS:SetText(""); r.notesFS:SetText("");
        r.characterFS:SetText(""); r.realmFS:SetText("");

        r.nameFS:SetTextColor(pr,pg,pb,pa);
        local nr, ng, nb, na = unpack(AL.COLOR_PARENT_ROW_TEXT_NEUTRAL);
        r.locationFS:SetTextColor(nr,ng,nb,na); r.ownedFS:SetTextColor(nr,ng,nb,na); r.notesFS:SetTextColor(nr,ng,nb,na);
        r.characterFS:SetTextColor(nr,ng,nb,na); r.realmFS:SetTextColor(nr,ng,nb,na);
        if r.expandButton then r.expandButton:Show(); end

        r.parentDeleteButton = CreateFrame("Button", nil, r, "UIPanelCloseButton");
        r.parentDeleteButton:SetSize(AL.DELETE_BUTTON_SIZE, AL.DELETE_BUTTON_SIZE);
        local buttonX = actionsColFinalX + (AL.COL_DELETE_BTN_AREA_WIDTH / 2) - (AL.DELETE_BUTTON_SIZE / 2);
        r.parentDeleteButton:SetPoint("LEFT", r, "LEFT", buttonX, 0);
        r.parentDeleteButton:Show();
        r.parentDeleteButton.itemID = itemData.itemID;
        r.parentDeleteButton.itemName = itemData.itemName or "Unknown Item";
        r.parentDeleteButton:SetScript("OnClick", function(selfBtn)
            if StaticPopupDialogs["AL_CONFIRM_DELETE_ALL_ITEM_INSTANCES"] then
                StaticPopup_Show("AL_CONFIRM_DELETE_ALL_ITEM_INSTANCES", selfBtn.itemName, nil, { itemID = selfBtn.itemID });
            else
                AL:RemoveAllInstancesOfItem(selfBtn.itemID);
            end
        end);
    else -- Child row
        if r.expandButton then r.expandButton:Hide(); end
        r.childDeleteButton = CreateFrame("Button", nil, r, "UIPanelCloseButton");
        r.childDeleteButton:SetSize(AL.DELETE_BUTTON_SIZE, AL.DELETE_BUTTON_SIZE);
        r.childDeleteButton:SetPoint("RIGHT", r, "RIGHT", -AL.COL_PADDING, 0);
        r.childDeleteButton:Show();
        r.childDeleteButton:SetScript("OnClick", function()
            AL:RemoveTrackedItem(r.itemID, r.characterName, r.characterRealm);
        end);

        if ownership.isLink then r.nameFS:SetText(itemData.itemLink); else r.nameFS:SetText(itemData.itemName); end
        r.nameFS:SetTextColor(ownership.colorR, ownership.colorG, ownership.colorB, ownership.colorA);
        r.locationFS:SetText(ownership.locationText); r.locationFS:SetTextColor(ownership.colorR, ownership.colorG, ownership.colorB, ownership.colorA);
        r.ownedFS:SetText(ownership.displayText); r.ownedFS:SetTextColor(ownership.colorR, ownership.colorG, ownership.colorB, ownership.colorA);
        r.notesFS:SetText(ownership.notesText); r.notesFS:SetTextColor(ownership.colorR, ownership.colorG, ownership.colorB, ownership.colorA);
        r.characterFS:SetText(itemData.characterName or "N/A"); r.characterFS:SetTextColor(ownership.colorR, ownership.colorG, ownership.colorB, ownership.colorA);
        r.realmFS:SetText(itemData.characterRealm or "N/A"); r.realmFS:SetTextColor(ownership.colorR, ownership.colorG, ownership.colorB, ownership.colorA);
    end

    r.nameFS:EnableMouse(true);
    r.nameFS:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); if not isParentRow and ownership and ownership.isLink and itemData.itemLink then GameTooltip:SetHyperlink(itemData.itemLink); else GameTooltip:SetItemByID(itemData.itemID); end; GameTooltip:Show(); end);
    r.nameFS:SetScript("OnLeave", function(s) GameTooltip:Hide(); end);
    return r;
end

function AL:RefreshLedgerDisplay()
    if not self.ScrollChild then return; end
    for _, f in ipairs(self.itemRowFrames) do f:Hide(); f:SetParent(nil); end
    wipe(self.itemRowFrames);
    local yOffset = 0;
    if self.ScrollChild:GetWidth() <= 10 and self.MainWindow and self.MainWindow:IsShown() then self:UpdateLayout(); end

    local allTrackedItemsWithDetails = {};
    for _, entry in ipairs(_G.AL_SavedData.trackedItems) do
        InitializeTrackedItemEntry(entry, entry.characterName, entry.characterRealm);
        local details = self:GetItemOwnershipDetails(entry);
        table.insert(allTrackedItemsWithDetails, { original = entry, details = details });
    end

    local itemsToProcess = allTrackedItemsWithDetails;
    if AL.currentQualityFilter ~= nil and AL.currentQualityFilter ~= -1 then
        local filteredItems = {};
        for _, item in ipairs(allTrackedItemsWithDetails) do
            if item.original.itemRarity == AL.currentQualityFilter then
                table.insert(filteredItems, item);
            elseif AL.currentQualityFilter == 5 and (item.original.itemRarity or 0) >= 5 then 
                table.insert(filteredItems, item);
            end
        end
        itemsToProcess = filteredItems;
    end

    if AL.currentViewMode == "GROUPED_BY_ITEM" then
        local groupedByItem = {};
        for _, augmentedEntry in ipairs(itemsToProcess) do
            local itemID = augmentedEntry.original.itemID;
            groupedByItem[itemID] = groupedByItem[itemID] or {
                itemID = itemID,
                itemName = augmentedEntry.original.itemName,
                itemTexture = augmentedEntry.original.itemTexture,
                itemRarity = augmentedEntry.original.itemRarity,
                isExpanded = _G.AL_SavedData.itemExpansionStates and _G.AL_SavedData.itemExpansionStates[itemID] or false,
                characters = {}
            };
            table.insert(groupedByItem[itemID].characters, augmentedEntry);
        end

        local parentRowDataForSorting = {};
        for itemID, groupData in pairs(groupedByItem) do table.insert(parentRowDataForSorting, groupData); end

        table.sort(parentRowDataForSorting, function(a,b) return (a.itemName or "") < (b.itemName or ""); end);

        for i, groupData in ipairs(parentRowDataForSorting) do
            local isEvenParent = (#self.itemRowFrames % 2 == 0);
            local parentRowFrame = self:CreateItemRowFrame(self.ScrollChild, groupData, yOffset, isEvenParent, nil, true, groupData.isExpanded);
            if parentRowFrame and parentRowFrame.IsObjectType and parentRowFrame:IsObjectType("Frame") then
                parentRowFrame:Show(); table.insert(self.itemRowFrames, parentRowFrame); yOffset = yOffset + AL.ITEM_ROW_HEIGHT;
            end

            if groupData.isExpanded then
                table.sort(groupData.characters, function(a,b)
                    if a.original.characterName == b.original.characterName then
                        return (a.original.characterRealm or "") < (b.original.characterRealm or "");
                    end
                    return (a.original.characterName or "") < (b.original.characterName or "");
                end);
                for _, childAugmentedEntry in ipairs(groupData.characters) do
                    local isEvenChild = (#self.itemRowFrames % 2 == 0);
                    local childRowFrame = self:CreateItemRowFrame(self.ScrollChild, childAugmentedEntry.original, yOffset, isEvenChild, childAugmentedEntry.details, false);
                    if childRowFrame and childRowFrame.IsObjectType and childRowFrame:IsObjectType("Frame") then
                        childRowFrame:Show(); table.insert(self.itemRowFrames, childRowFrame); yOffset = yOffset + AL.ITEM_ROW_HEIGHT;
                    end
                end
            end
        end
    else 
        local function sortFlatList(a,b)
            local a_name = a.original.itemName or "";    local b_name = b.original.itemName or "";
            local a_char = a.original.characterName or "";  local b_char = b.original.characterName or "";
            local a_realm = a.original.characterRealm or ""; local b_realm = b.original.characterRealm or "";
            local a_locDetails = a.details;                local b_locDetails = b.details;

            if AL.currentSortCriteria == AL.SORT_CHARACTER then
                if a_char ~= b_char then return a_char < b_char; end
                if a_name ~= b_name then return a_name < b_name; end
                return a_realm < b_realm;
            elseif AL.currentSortCriteria == AL.SORT_REALM then
                if a_realm ~= b_realm then return a_realm < b_realm; end
                if a_char ~= b_char then return a_char < b_char; end
                return a_name < b_name;
            elseif AL.currentSortCriteria == AL.SORT_BAGS or AL.currentSortCriteria == AL.SORT_BANK or AL.currentSortCriteria == AL.SORT_MAIL or AL.currentSortCriteria == AL.SORT_AUCTION or AL.currentSortCriteria == AL.SORT_LIMBO then
                local targetLoc = "";
                if AL.currentSortCriteria == AL.SORT_BAGS then targetLoc = "Bags";
                elseif AL.currentSortCriteria == AL.SORT_BANK then targetLoc = "Bank";
                elseif AL.currentSortCriteria == AL.SORT_MAIL then targetLoc = "Mail";
                elseif AL.currentSortCriteria == AL.SORT_AUCTION then targetLoc = "Auction House";
                elseif AL.currentSortCriteria == AL.SORT_LIMBO then targetLoc = "Limbo";
                end
                local aIsTarget = (a_locDetails.locationText == targetLoc);
                local bIsTarget = (b_locDetails.locationText == targetLoc);
                if aIsTarget and not bIsTarget then return true; end
                if not aIsTarget and bIsTarget then return false; end
                if a_name ~= b_name then return a_name < b_name; end
                if a_char ~= b_char then return a_char < b_char; end
                return a_realm < b_realm;
            else 
                if a_name ~= b_name then return a_name < b_name; end
                if a_char ~= b_char then return a_char < b_char; end
                return a_realm < b_realm;
            end
        end
        table.sort(itemsToProcess, sortFlatList);

        for i, augmentedEntry in ipairs(itemsToProcess) do
            local isEvenRow = (#self.itemRowFrames % 2 == 0); 
            local rowFrame = self:CreateItemRowFrame(self.ScrollChild, augmentedEntry.original, yOffset, isEvenRow, augmentedEntry.details, false);
            if rowFrame and rowFrame.IsObjectType and rowFrame:IsObjectType("Frame") then
                rowFrame:Show(); table.insert(self.itemRowFrames, rowFrame); yOffset = yOffset + AL.ITEM_ROW_HEIGHT;
            end
        end
    end

    local newScrollChildHeight = 0;
    if #self.itemRowFrames > 0 then newScrollChildHeight = #self.itemRowFrames * AL.ITEM_ROW_HEIGHT; else newScrollChildHeight = 10; end
    self.ScrollChild:SetHeight(math.max(10, newScrollChildHeight));
end

function AL:UpdateLayout()
    if not self.MainWindow then return; end
    local frameNameSuffix = "_v" .. AL.VERSION:gsub("%.","_");
    local topInset, bottomInset, sideInset = 28, 8, 8;

    if self.LeftPanel then
        self.LeftPanel:ClearAllPoints();
        self.LeftPanel:SetPoint("TOPLEFT", self.MainWindow, "TOPLEFT", sideInset, -topInset);
        self.LeftPanel:SetPoint("BOTTOMLEFT", self.MainWindow, "BOTTOMLEFT", sideInset, bottomInset);
        self.LeftPanel:SetWidth(AL.LEFT_PANEL_WIDTH);

        local currentButtonY = -AL.BUTTON_SPACING;

        local buttonStructure = {
            {type = "button", ref = self.CreateReminderButton},
            {type = "button", ref = self.RefreshListButton},
            {type = "button", ref = self.HelpWindowButton},
            {type = "button", ref = self.ToggleMinimapButton},
            {type = "label",  refName = "LabelSortBy", text = "Sort View:"},
            {type = "button", ref = self.SortAlphaButton},
            {type = "button", ref = self.SortCharacterButton},
            {type = "button", ref = self.SortRealmButton},
            {type = "label",  refName = "LabelFilterLocation", text = "Filter Location (Flat List):"},
            {type = "button", ref = self.SortBagsButton},
            {type = "button", ref = self.SortBankButton},
            {type = "button", ref = self.SortMailButton},
            {type = "button", ref = self.SortAuctionButton},
            {type = "button", ref = self.SortLimboButton},
            {type = "label",  refName = "LabelFilterQuality", text = "Filter Quality:"},
        };
        for _, qualityBtn in ipairs(AL.SortQualityButtons or {}) do
            table.insert(buttonStructure, {type = "button", ref = qualityBtn});
        end

        for _, itemDef in ipairs(buttonStructure) do
            if itemDef.type == "label" then
                local labelFrame = self[itemDef.refName];
                if labelFrame and type(labelFrame.ClearAllPoints) == "function" and labelFrame.text then
                    currentButtonY = currentButtonY - (AL.BUTTON_HEIGHT / 4);
                    labelFrame:ClearAllPoints();
                    labelFrame.text:SetText(itemDef.text);
                    labelFrame:SetPoint("TOPLEFT", self.LeftPanel, "TOPLEFT", AL.BUTTON_SPACING, currentButtonY);
                    labelFrame:SetPoint("TOPRIGHT", self.LeftPanel, "TOPRIGHT", -AL.BUTTON_SPACING, currentButtonY);
                    labelFrame:SetHeight(AL.BUTTON_HEIGHT / 1.5 * 1.2);
                    labelFrame.text:SetJustifyH("CENTER");
                    labelFrame.text:SetJustifyV("MIDDLE");
                    labelFrame:Show();
                    currentButtonY = currentButtonY - (AL.BUTTON_HEIGHT / 1.5 * 1.2) - AL.BUTTON_SPACING;
                end
            elseif itemDef.type == "button" then
                local button = itemDef.ref;
                if button and type(button.ClearAllPoints) == "function" then
                    button:ClearAllPoints();
                    button:SetHeight(AL.BUTTON_HEIGHT);
                    button:SetPoint("TOPLEFT", self.LeftPanel, "TOPLEFT", AL.BUTTON_SPACING, currentButtonY);
                    button:SetPoint("TOPRIGHT", self.LeftPanel, "TOPRIGHT", -AL.BUTTON_SPACING, currentButtonY);
                    button:Show();
                    currentButtonY = currentButtonY - AL.BUTTON_HEIGHT - AL.BUTTON_SPACING;
                end
            end
        end
    end

    local scrollContentLeftOffset = sideInset;
    if self.LeftPanel and self.LeftPanel:IsShown() then
        scrollContentLeftOffset = sideInset + AL.LEFT_PANEL_WIDTH + AL.BUTTON_SPACING;
    end

    if self.ColumnHeaderFrame then
        self.ColumnHeaderFrame:ClearAllPoints();
        self.ColumnHeaderFrame:SetPoint("TOPLEFT",self.MainWindow,"TOPLEFT",scrollContentLeftOffset,-(topInset + 0));
        self.ColumnHeaderFrame:SetPoint("TOPRIGHT",self.MainWindow,"TOPRIGHT",-sideInset,-(topInset + 0));
        self.ColumnHeaderFrame:SetHeight(AL.COLUMN_HEADER_HEIGHT);
        self.ColumnHeaderFrame:SetFrameLevel(self.MainWindow:GetFrameLevel() + 2);
        local currentHeaderContentX = AL.COL_PADDING;

        self.ColumnHeaderFrame.NameHFS:ClearAllPoints(); self.ColumnHeaderFrame.NameHFS:SetPoint("LEFT", self.ColumnHeaderFrame, "LEFT", currentHeaderContentX, 0); self.ColumnHeaderFrame.NameHFS:SetWidth(AL.EFFECTIVE_NAME_COL_WIDTH); self.ColumnHeaderFrame.NameHFS:SetJustifyH("CENTER");
        currentHeaderContentX = currentHeaderContentX + AL.EFFECTIVE_NAME_COL_WIDTH + AL.COL_PADDING;

        self.ColumnHeaderFrame.LocationHFS:ClearAllPoints(); self.ColumnHeaderFrame.LocationHFS:SetPoint("LEFT", self.ColumnHeaderFrame, "LEFT", currentHeaderContentX, 0); self.ColumnHeaderFrame.LocationHFS:SetWidth(AL.COL_LOCATION_WIDTH); self.ColumnHeaderFrame.LocationHFS:SetJustifyH("CENTER");
        currentHeaderContentX = currentHeaderContentX + AL.COL_LOCATION_WIDTH + AL.COL_PADDING;

        self.ColumnHeaderFrame.OwnedHFS:ClearAllPoints(); self.ColumnHeaderFrame.OwnedHFS:SetPoint("LEFT", self.ColumnHeaderFrame, "LEFT", currentHeaderContentX, 0); self.ColumnHeaderFrame.OwnedHFS:SetWidth(AL.COL_OWNED_WIDTH); self.ColumnHeaderFrame.OwnedHFS:SetJustifyH("CENTER");
        currentHeaderContentX = currentHeaderContentX + AL.COL_OWNED_WIDTH + AL.COL_PADDING;

        self.ColumnHeaderFrame.NotesHFS:ClearAllPoints(); self.ColumnHeaderFrame.NotesHFS:SetPoint("LEFT", self.ColumnHeaderFrame, "LEFT", currentHeaderContentX, 0); self.ColumnHeaderFrame.NotesHFS:SetWidth(AL.COL_NOTES_WIDTH); self.ColumnHeaderFrame.NotesHFS:SetJustifyH("CENTER");
        currentHeaderContentX = currentHeaderContentX + AL.COL_NOTES_WIDTH + AL.COL_PADDING;

        self.ColumnHeaderFrame.CharacterHFS:ClearAllPoints(); self.ColumnHeaderFrame.CharacterHFS:SetPoint("LEFT", self.ColumnHeaderFrame, "LEFT", currentHeaderContentX, 0); self.ColumnHeaderFrame.CharacterHFS:SetWidth(AL.COL_CHARACTER_WIDTH); self.ColumnHeaderFrame.CharacterHFS:SetJustifyH("CENTER");
        currentHeaderContentX = currentHeaderContentX + AL.COL_CHARACTER_WIDTH + AL.COL_PADDING;

        self.ColumnHeaderFrame.RealmHFS:ClearAllPoints(); self.ColumnHeaderFrame.RealmHFS:SetPoint("LEFT", self.ColumnHeaderFrame, "LEFT", currentHeaderContentX, 0); self.ColumnHeaderFrame.RealmHFS:SetWidth(AL.COL_REALM_WIDTH); self.ColumnHeaderFrame.RealmHFS:SetJustifyH("CENTER");
        currentHeaderContentX = currentHeaderContentX + AL.COL_REALM_WIDTH + AL.COL_PADDING;

        self.ColumnHeaderFrame.ActionsHFS:ClearAllPoints(); 
        self.ColumnHeaderFrame.ActionsHFS:SetPoint("LEFT", self.ColumnHeaderFrame, "LEFT", currentHeaderContentX, 0); 
        self.ColumnHeaderFrame.ActionsHFS:SetWidth(AL.COL_DELETE_BTN_AREA_WIDTH); 
        self.ColumnHeaderFrame.ActionsHFS:SetJustifyH("CENTER"); 
    end
    if self.ScrollFrame then
        self.ScrollFrame:ClearAllPoints();
        local scrollFrameTopOffset = topInset + AL.COLUMN_HEADER_HEIGHT;
        self.ScrollFrame:SetPoint("TOPLEFT",self.MainWindow,"TOPLEFT",scrollContentLeftOffset,-scrollFrameTopOffset);
        self.ScrollFrame:SetPoint("BOTTOMRIGHT",self.MainWindow,"BOTTOMRIGHT",-sideInset,bottomInset);
        self.ScrollFrame:SetFrameLevel(self.MainWindow:GetFrameLevel() + 2);
        if self.ScrollChild then
            local sbw=0; if self.ScrollChild:GetHeight()>self.ScrollFrame:GetHeight() then sbw=16; end;
            local totalContentWidthInScrollChild = AL.COL_PADDING + AL.EFFECTIVE_NAME_COL_WIDTH + AL.COL_PADDING + AL.COL_LOCATION_WIDTH + AL.COL_PADDING + AL.COL_OWNED_WIDTH + AL.COL_PADDING + AL.COL_NOTES_WIDTH + AL.COL_PADDING + AL.COL_CHARACTER_WIDTH + AL.COL_PADDING + AL.COL_REALM_WIDTH + AL.COL_PADDING + AL.COL_DELETE_BTN_AREA_WIDTH + AL.COL_PADDING;
            local scrollChildVisibleWidth = self.ScrollFrame:GetWidth() - sbw;
            self.ScrollChild:SetWidth(math.max(totalContentWidthInScrollChild, scrollChildVisibleWidth));
            for _, ir in ipairs(self.itemRowFrames) do
                if ir and ir.IsObjectType and ir:IsObjectType("Frame") then ir:SetWidth(self.ScrollChild:GetWidth()); end;
            end;
        end;
    end;
    local numDividersNeeded = 7;
    for i = 1, #self.mainDividers do if self.mainDividers[i] and self.mainDividers[i]:IsObjectType("Frame") then self.mainDividers[i]:Hide(); end; end;
    local divX_centers_abs = {};
    local currentDivCenterX = scrollContentLeftOffset + AL.COL_PADDING / 2; table.insert(divX_centers_abs, currentDivCenterX );
    currentDivCenterX = currentDivCenterX + (AL.COL_PADDING / 2) + AL.EFFECTIVE_NAME_COL_WIDTH + (AL.COL_PADDING / 2); table.insert(divX_centers_abs, currentDivCenterX );
    currentDivCenterX = currentDivCenterX + (AL.COL_PADDING / 2) + AL.COL_LOCATION_WIDTH + (AL.COL_PADDING / 2); table.insert(divX_centers_abs, currentDivCenterX );
    currentDivCenterX = currentDivCenterX + (AL.COL_PADDING / 2) + AL.COL_OWNED_WIDTH + (AL.COL_PADDING / 2); table.insert(divX_centers_abs, currentDivCenterX );
    currentDivCenterX = currentDivCenterX + (AL.COL_PADDING / 2) + AL.COL_NOTES_WIDTH + (AL.COL_PADDING / 2); table.insert(divX_centers_abs, currentDivCenterX );
    currentDivCenterX = currentDivCenterX + (AL.COL_PADDING / 2) + AL.COL_CHARACTER_WIDTH + (AL.COL_PADDING / 2); table.insert(divX_centers_abs, currentDivCenterX );
    currentDivCenterX = currentDivCenterX + (AL.COL_PADDING / 2) + AL.COL_REALM_WIDTH + (AL.COL_PADDING / 2); table.insert(divX_centers_abs, currentDivCenterX );

    for i = 1, numDividersNeeded do
        if divX_centers_abs[i] then
            local div = self.mainDividers[i];
            if not div then div = CreateFrame("Frame", "AL_MainDivider" .. i .. frameNameSuffix, self.MainWindow); if BackdropTemplateMixin then Mixin(div, BackdropTemplateMixin); end; self.mainDividers[i] = div; end;
            div:ClearAllPoints(); div:SetFrameLevel(self.MainWindow:GetFrameLevel() + 1); div:SetWidth(AL.DIVIDER_THICKNESS);
            if div.SetBackdrop then div:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"}); div:SetBackdropColor(unpack(AL.WINDOW_DIVIDER_COLOR));
            else local tex = div.texture or div:CreateTexture(nil, "BACKGROUND"); div.texture = tex; tex:SetAllPoints(true); tex:SetColorTexture(unpack(AL.WINDOW_DIVIDER_COLOR)); end;
            div:SetPoint("TOP", self.ColumnHeaderFrame, "TOP", 0, 0); div:SetPoint("BOTTOM", self.ScrollFrame, "BOTTOM", 0, 0); div:SetPoint("LEFT", self.MainWindow, "LEFT", divX_centers_abs[i] - (AL.DIVIDER_THICKNESS / 2), 0); div:Show();
        end
    end;
    for i = numDividersNeeded + 1, #self.mainDividers do if self.mainDividers[i] then self.mainDividers[i]:Hide(); end; end;
end

function AL:CreateHelpWindow()
    if self.HelpWindow then return; end
    local frameNameSuffix = "_v" .. AL.VERSION:gsub("%.","_");
    local hw = CreateFrame("Frame", "AL_HelpWindow" .. frameNameSuffix, UIParent, "BasicFrameTemplateWithInset");
    self.HelpWindow = hw;
    hw:SetSize(AL.HELP_WINDOW_WIDTH, AL.HELP_WINDOW_HEIGHT);
    hw:SetFrameStrata("DIALOG");
    local mainWinLevel = self.MainWindow and self.MainWindow:GetFrameLevel() or 5;
    hw:SetFrameLevel(mainWinLevel + 5);
    hw.TitleText:SetText("Auctioneer's Ledger - How To Use");
    hw:SetMovable(true); hw:RegisterForDrag("LeftButton");
    hw:SetScript("OnDragStart", function(self) self:StartMoving(); end);
    hw:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); end);
    hw:SetClampedToScreen(true);
    hw.CloseButton:SetScript("OnClick", function() self:HideHelpWindow(); end);
    local scroll = CreateFrame("ScrollFrame", "AL_HelpScrollFrame" .. frameNameSuffix, hw, "UIPanelScrollFrameTemplate");
    self.HelpWindowScrollFrame = scroll;
    scroll:SetPoint("TOPLEFT", hw, "TOPLEFT", 8, -30); scroll:SetPoint("BOTTOMRIGHT", hw, "BOTTOMRIGHT", -30, 8);
    local child = CreateFrame("Frame", "AL_HelpScrollChild" .. frameNameSuffix, scroll);
    self.HelpWindowScrollChild = child;
    child:SetWidth(AL.HELP_WINDOW_WIDTH - 50); child:SetHeight(10);
    scroll:SetScrollChild(child);
    local fs = child:CreateFontString("AL_HelpFontString" .. frameNameSuffix, "ARTWORK", "GameFontNormal");
    self.HelpWindowFontString = fs;
    fs:SetPoint("TOPLEFT", child, "TOPLEFT", 10, -10); fs:SetWidth(child:GetWidth() - 20);
    fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP");
    fs:SetTextColor(unpack(AL.COLOR_DEFAULT_TEXT_RGB));
    self:PopulateHelpWindowText(); hw:Hide();
end

function AL:PopulateHelpWindowText()
    if not self.HelpWindowFontString then return; end
    local function getWoWColorHex(colorTable, alphaOverride)
        if not colorTable or type(colorTable) ~= "table" or #colorTable < 3 then return "FFFFFFFF"; end
        local r_val = math.max(0, math.min(1, colorTable[1] or 0)); local g_val = math.max(0, math.min(1, colorTable[2] or 0)); local b_val = math.max(0, math.min(1, colorTable[3] or 0));
        local a_val = colorTable[4]; if alphaOverride ~= nil then a_val = alphaOverride end; if a_val == nil then a_val = 1.0 end
        local finalA = math.floor(math.max(0, math.min(1, a_val)) * 255 + 0.5); local finalR = math.floor(r_val * 255 + 0.5); local finalG = math.floor(g_val * 255 + 0.5); local finalB = math.floor(b_val * 255 + 0.5);
        return string.format("%02X%02X%02X%02X", finalA, finalR, finalG, finalB);
    end
    local GOLD_C = "|c" .. getWoWColorHex(AL.COLOR_BANK_GOLD); local TAN_C = "|c" .. getWoWColorHex(AL.COLOR_MAIL_TAN); local AH_BLUE_C = "|c" .. getWoWColorHex(AL.COLOR_AH_BLUE);
    local LIMBO_C = "|c" .. getWoWColorHex(AL.COLOR_LIMBO);
    
    local Q_POOR_HEX = (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[0] and ITEM_QUALITY_COLORS[0].hex) or "|cff9d9d9d";
    local Q_COMMON_HEX = (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[1] and ITEM_QUALITY_COLORS[1].hex) or "|cffffffff";
    local Q_UNCOMMON_HEX = (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[2] and ITEM_QUALITY_COLORS[2].hex) or "|cff1eff00";
    local Q_RARE_HEX = (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[3] and ITEM_QUALITY_COLORS[3].hex) or "|cff0070dd";
    local Q_EPIC_HEX = (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[4] and ITEM_QUALITY_COLORS[4].hex) or "|cffa335ee";
    local Q_LEGENDARY_HEX = (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[5] and ITEM_QUALITY_COLORS[5].hex) or "|cffff8000";

    local Q_POOR = Q_POOR_HEX; 
    local Q_COMMON = Q_COMMON_HEX; 
    local Q_UNCOMMON = Q_UNCOMMON_HEX;
    local Q_RARE = Q_RARE_HEX; 
    local Q_EPIC = Q_EPIC_HEX;
    local Q_LEGENDARY = Q_LEGENDARY_HEX;


    local WHITE = "|cFFFFFFFF"; local YELLOW = "|cFFD4AF37"; local ORANGE = "|cFFFF8000";
    local DIMMED_TEXT_C  = "|c" .. getWoWColorHex({(AL.COLOR_LIMBO[1] or 0)*0.85, (AL.COLOR_LIMBO[2] or 0)*0.85, (AL.COLOR_LIMBO[3] or 0)*0.85, 1.0});
    local SECTION_TITLE_C = YELLOW; local HIGHLIGHT_C = WHITE; local SUB_HIGHLIGHT_C = ORANGE;
    local r_reset = "|r";
    local function CT(colorPipe, textSegment) return colorPipe .. textSegment .. r_reset; end
    local textParts = {};

    local indent = "    ";
    local bullet = "  • ";

    table.insert(textParts, CT(SECTION_TITLE_C, "Welcome to Auctioneer's Ledger v" .. AL.VERSION .. "!") .. "\n");
    table.insert(textParts, "This addon helps you track items across characters and realms, manage stock, and streamline your gold-making.\n\n");

    table.insert(textParts, CT(SECTION_TITLE_C, "Core Concept: Tracking Items Across Characters") .. "\n");
    table.insert(textParts, "Auctioneer's Ledger allows you to track specific items. For each item, it stores:\n");
    table.insert(textParts, indent .. bullet .. "Icon & Item Name (rarity colored)\n");
    table.insert(textParts, indent .. bullet .. "Current Verifiable Location (Bags, Bank, Mail, Auction House, or Limbo)\n");
    table.insert(textParts, indent .. bullet .. "Quantity Owned in that location\n");
    table.insert(textParts, indent .. bullet .. CT(HIGHLIGHT_C, "Character Name") .. " who owns/is tracking it\n");
    table.insert(textParts, indent .. bullet .. CT(HIGHLIGHT_C, "Realm Name") .. " of that character\n");
    table.insert(textParts, indent .. bullet .. "Contextual Notes (e.g., for items on alts or in closed Mail/AH)\n");
    table.insert(textParts, "You can track the same item multiple times if it's on different characters or realms.\n\n");

    table.insert(textParts, CT(SECTION_TITLE_C, "Adding and Removing Tracked Items") .. "\n");
    table.insert(textParts, bullet .. "To " .. CT(HIGHLIGHT_C, "add an item") .. ":\n");
    table.insert(textParts, indent .. "1. Open your bags.\n");
    table.insert(textParts, indent .. "2. Open Auctioneer's Ledger (type " .. CT(SUB_HIGHLIGHT_C, "/al") .. " or " .. CT(SUB_HIGHLIGHT_C, "/aledger") .. ", or use the Minimap/LDB icon).\n");
    table.insert(textParts, indent .. "3. Click the \"" .. CT(HIGHLIGHT_C, "Track New Item") .. "\" button on the left panel.\n");
    table.insert(textParts, indent .. "4. A small popup will appear. Drag the item from your bag onto this popup.\n");
    table.insert(textParts, indent .. "5. The item will be added for the " .. CT(HIGHLIGHT_C, "currently logged-in character") .. ".\n");
    table.insert(textParts, indent .. bullet .. "The popup also has an \"" .. CT(HIGHLIGHT_C, "Add All Eligible Items From Bags") .. "\" button to scan your bags for eligible, untracked items and add them in batch.\n");
    table.insert(textParts, bullet .. "To " .. CT(HIGHLIGHT_C, "remove an individual item entry (per character/realm)") .. ": Click the 'X' button on the far right of its " .. CT(SUB_HIGHLIGHT_C, "child row") .. " in the ledger.\n");
    table.insert(textParts, bullet .. "To " .. CT(HIGHLIGHT_C, "remove all entries for an item (across all characters/realms)") .. ": Click the 'X' button in the \"Delete\" column of that item's " .. CT(SUB_HIGHLIGHT_C, "parent row") .. ". You will be asked for confirmation.\n\n");


    table.insert(textParts, CT(SECTION_TITLE_C, "The Main Window & Ledger Display") .. "\n");
    table.insert(textParts, "The main window is resizable (down to " .. AL.MIN_WINDOW_WIDTH .. "x" .. AL.MIN_WINDOW_HEIGHT .. " minimum) and movable.\n");
    table.insert(textParts, CT(HIGHLIGHT_C, "Display Views:") .. "\n");
    table.insert(textParts, indent .. bullet .. CT(SUB_HIGHLIGHT_C, "Item Name (Grouped) View (Default):") .. "\n");
    table.insert(textParts, indent .. indent .. "Shows unique items as " .. CT(HIGHLIGHT_C, "Parent Rows") .. ". Parent rows display a " .. CT(SUB_HIGHLIGHT_C, "+/-") .. " button, item icon, and rarity-colored item name. Other data columns on parent rows are intentionally blank. Parent rows have an 'X' button to remove all data for that item.\n");
    table.insert(textParts, indent .. indent .. "Click " .. CT(SUB_HIGHLIGHT_C, "+") .. " to expand and see " .. CT(HIGHLIGHT_C, "Child Rows") .. ". Each child row represents that item on a specific character/realm.\n");
    table.insert(textParts, indent .. indent .. "Child rows show full details: Icon, Item Name, Location, Owned, Notes, Character, and Realm, and an 'X' button to delete that specific entry.\n");
    table.insert(textParts, indent .. bullet .. CT(SUB_HIGHLIGHT_C, "Flat List Views:") .. " Accessed via buttons like \"" .. CT(HIGHLIGHT_C, "By Character (Flat)") .. "\", \"" .. CT(HIGHLIGHT_C, "By Realm (Flat)") .. "\", or location filters. These show all tracked entries as individual rows without grouping.\n");
    table.insert(textParts, CT(HIGHLIGHT_C, "Columns:") .. " Icon, Item Name, Location, Owned, Notes, Character, Realm, Delete.\n\n");

    table.insert(textParts, CT(SECTION_TITLE_C, "Understanding Locations & Data Accuracy") .. "\n");
    table.insert(textParts, bullet .. CT(HIGHLIGHT_C, "Bags (" .. CT(WHITE, "Rarity Color") .. "): ") .. "Checked live. Clickable item link if on current character.\n");
    table.insert(textParts, bullet .. CT(HIGHLIGHT_C, "Bank (" .. CT(GOLD_C, "Gold Color") .. "): ") .. "Checked live for current character.\n");
    table.insert(textParts, bullet .. CT(HIGHLIGHT_C, "Mail (" .. CT(TAN_C, "Tan Color") .. "):") .. "\n");
    table.insert(textParts, indent .. "For the " .. CT(WHITE, "current character") .. ", your " .. CT(ORANGE, "Mailbox window MUST BE OPEN") .. " to detect items.\n");
    table.insert(textParts, indent .. "If Mailbox is closed, last known mail items show with a note \"" .. CT(TAN_C, "Inside mailbox.") .. "\" and " .. CT(DIMMED_TEXT_C, "dimmed color") .. ".\n");
    table.insert(textParts, bullet .. CT(HIGHLIGHT_C, "Auction House (AH) (" .. CT(AH_BLUE_C, "Light Blue Color") .. "):") .. "\n");
    table.insert(textParts, indent .. "For the " .. CT(WHITE, "current character") .. ", AH window " .. CT(ORANGE, "MUST BE OPEN") .. " & you " .. CT(ORANGE, "MUST") .. " have clicked your \"" .. CT(HIGHLIGHT_C, "My Auctions") .. "\" tab that session to detect auctions.\n");
    table.insert(textParts, indent .. "If AH is closed/inactive, last known items show with a note \"" .. CT(AH_BLUE_C, "Being auctioned.") .. "\" and " .. CT(DIMMED_TEXT_C, "dimmed color") .. ".\n");
    table.insert(textParts, bullet .. CT(HIGHLIGHT_C, "Limbo (" .. CT(LIMBO_C, "Gray Color") .. "):") .. " Item not found in Bags, Bank, or verified Mail/AH for the " .. CT(WHITE, "current character") .. ". For " .. CT(WHITE, "alts") .. ", 'Limbo' (or a last known Mail/AH status with a note) is shown until you log into them and update their status.\n");
    table.insert(textParts, bullet .. CT(HIGHLIGHT_C, "Data for Alts:") .. " Information for characters you are not currently logged into reflects the " .. CT(WHITE, "last known state") .. " from when you last played that character with Auctioneer's Ledger active. This data will often appear " .. CT(DIMMED_TEXT_C, "dimmed") .. " (stale) and may include notes like \"Inside mailbox.\" or \"Being auctioned.\" based on their last saved status.\n\n");

    table.insert(textParts, CT(SECTION_TITLE_C, "Sorting & Filtering the Ledger") .. "\n");
    table.insert(textParts, "Use the buttons on the left panel (which have a " .. CT(DIMMED_TEXT_C, "stone texture background") .. ") to organize your view:\n");
    table.insert(textParts, CT(HIGHLIGHT_C, "Main View Sort Buttons:") .. "\n");
    table.insert(textParts, indent .. bullet .. CT(SUB_HIGHLIGHT_C, "Item Name (Grouped):") .. " (Default) Groups by unique items, sorted alphabetically. This is the primary view for seeing all character holdings of an item.\n");
    table.insert(textParts, indent .. bullet .. CT(SUB_HIGHLIGHT_C, "By Character (Flat):") .. " Shows an ungrouped (flat) list, sorted by Character -> Item Name -> Realm.\n");
    table.insert(textParts, indent .. bullet .. CT(SUB_HIGHLIGHT_C, "By Realm (Flat):") .. " Shows an ungrouped (flat) list, sorted by Realm -> Character -> Item Name.\n");
    table.insert(textParts, CT(HIGHLIGHT_C, "Filter Location Buttons (Switches to Flat List):") .. "\n");
    table.insert(textParts, indent .. bullet .. CT(SUB_HIGHLIGHT_C, "Bags First (Flat), Bank First (Flat), etc.:") .. " Shows a flat list, prioritizing items in the selected location (live for current char, last known for alts), then sorts by Item -> Character -> Realm.\n");
    table.insert(textParts, CT(HIGHLIGHT_C, "Filter Quality Buttons:") .. "\n");
    table.insert(textParts, indent .. bullet .. "Filters the " .. CT(WHITE, "currently displayed items") .. " (both grouped and flat views) by item rarity.\n");
    table.insert(textParts, indent .. bullet .. "Options: " .. CT(Q_POOR, "Poor") .. ", ".. CT(Q_COMMON, "Common") .. ", " .. CT(Q_UNCOMMON, "Uncommon") .. ", " .. CT(Q_RARE, "Rare") .. ", " .. CT(Q_EPIC, "Epic") .. ", " .. CT(Q_LEGENDARY, "Legendary+") .. ", and " .. CT(WHITE, "All Qualities") .. " (clears quality filter).\n\n");

    table.insert(textParts, CT(SECTION_TITLE_C, "Minimap Icon / LDB Launcher") .. "\n");
    table.insert(textParts, bullet .. CT(HIGHLIGHT_C, "Left-Click:") .. " Toggle main window visibility.\n");
    table.insert(textParts, bullet .. CT(HIGHLIGHT_C, "Shift + Left-Click:") .. " Reset window to default position and size.\n");
    table.insert(textParts, bullet .. CT(HIGHLIGHT_C, "Ctrl + Shift + Left-Click:") .. " Toggle the minimap icon's visibility itself.\n");
    table.insert(textParts, bullet .. "A \"" .. CT(HIGHLIGHT_C, "Toggle Minimap Icon") .. "\" button is also available at the bottom of the addon's left panel.\n\n");

    table.insert(textParts, CT(SECTION_TITLE_C, "General Tips") .. "\n");
    table.insert(textParts, bullet .. "Regularly open your Mailbox and the \"My Auctions\" tab on the AH (on each character) to keep data fresh.\n");
    table.insert(textParts, bullet .. "Use the \"" .. CT(HIGHLIGHT_C, "Refresh List") .. "\" button if you suspect data isn't up-to-date.\n");
    table.insert(textParts, bullet .. "The addon aims to provide a snapshot; always double-check in-game for critical decisions.\n\n");

    table.insert(textParts, CT(YELLOW, "Happy auctioneering and inventory management!"))

    local helpText = table.concat(textParts, ""); self.HelpWindowFontString:SetText(helpText);
    C_Timer.After(0.05, function() if self.HelpWindowFontString and self.HelpWindowScrollChild and self.HelpWindowScrollFrame then local fsHeight = self.HelpWindowFontString:GetHeight(); local scrollFrameHeight = self.HelpWindowScrollFrame:GetHeight(); self.HelpWindowScrollChild:SetHeight(math.max(scrollFrameHeight - 10, fsHeight + 20)); end end)
end


function AL:ShowHelpWindow()
    if not self.HelpWindow then self:CreateHelpWindow(); end
    if not self.HelpWindow then return; end
    self:PopulateHelpWindowText();
    self.HelpWindow:ClearAllPoints();
    self.HelpWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
    self.HelpWindow:Show(); self.HelpWindow:Raise();
end

function AL:HideHelpWindow()
    if self.HelpWindow and self.HelpWindow:IsShown() then self.HelpWindow:Hide(); end
end

function AL:ToggleHelpWindow()
    if not self.HelpWindow or not self.HelpWindow:IsShown() then self:ShowHelpWindow();
    else self:HideHelpWindow(); end
end

function AL:CreateFrames()
    local frameNameSuffix = "_v" .. AL.VERSION:gsub("%.","_");
    local mainWindowName = "AL_MainWindow" .. frameNameSuffix;
    if self.MainWindow and self.MainWindow:IsObjectType("Frame") and self.MainWindow:GetName() == mainWindowName then self:UpdateLayout(); return;
    elseif self.MainWindow then
        self.MainWindow,self.LeftPanel,self.CreateReminderButton,self.RefreshListButton,self.HelpWindowButton,self.ToggleMinimapButton,self.ColumnHeaderFrame,self.ScrollFrame,self.ScrollChild,self.ReminderPopup=nil,nil,nil,nil,nil,nil,nil,nil,nil,nil;
        self.SortAlphaButton, self.SortBagsButton, self.SortBankButton, self.SortMailButton, self.SortAuctionButton, self.SortLimboButton, self.SortCharacterButton, self.SortRealmButton = nil,nil,nil,nil,nil,nil,nil,nil;
        self.LabelSortBy, self.LabelFilterLocation, self.LabelFilterQuality = nil, nil, nil;
        wipe(self.SortQualityButtons or {});
    end;

    self.MainWindow,self.LeftPanel,self.CreateReminderButton,self.RefreshListButton,self.HelpWindowButton,self.ToggleMinimapButton,self.ColumnHeaderFrame,self.ScrollFrame,self.ScrollChild,self.ReminderPopup=nil,nil,nil,nil,nil,nil,nil,nil,nil,nil;
    self.SortAlphaButton, self.SortBagsButton, self.SortBankButton, self.SortMailButton, self.SortAuctionButton, self.SortLimboButton,self.SortCharacterButton, self.SortRealmButton = nil,nil,nil,nil,nil,nil,nil,nil;
    self.SortQualityButtons = {};
    self.LabelSortBy, self.LabelFilterLocation, self.LabelFilterQuality = nil, nil, nil;


    local f=CreateFrame("Frame", mainWindowName, UIParent,"BasicFrameTemplateWithInset");self.MainWindow=f;
    f:SetClampedToScreen(true);f:SetMovable(true);f:SetResizable(true);f:SetFrameStrata("DIALOG");f:SetFrameLevel(5);f.TitleText:SetText(ADDON_NAME .. " (v" .. AL.VERSION .. ")");
    f:EnableMouse(true);f:RegisterForDrag("LeftButton");f:SetScript("OnDragStart",function(s,b)if b=="LeftButton"then s:StartMoving();end end);
    f:SetScript("OnDragStop",function(s) s:StopMovingOrSizing(); local x,y = s:GetLeft(), UIParent:GetHeight()-s:GetTop(); _G.AL_SavedData.window.x = x; _G.AL_SavedData.window.y = y; end);
    f.CloseButton:SetScript("OnClick",function()AL.MainWindow:Hide();_G.AL_SavedData.window.visible=false;AL:HideReminderPopup(); AL:HideHelpWindow(); AL:StartStopPeriodicRefresh();end);
    local rh=CreateFrame("Button","AL_Resize" .. frameNameSuffix,f);rh:SetSize(16,16);rh:SetPoint("BOTTOMRIGHT",-4,4);rh:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up");rh:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight");rh:SetScript("OnMouseDown",function(_,b)if b=="LeftButton"then AL.MainWindow:StartSizing("BOTTOMRIGHT");end end);rh:SetScript("OnMouseUp",function(_,b)if b=="LeftButton"then AL.MainWindow:StopMovingOrSizing();end end);
    f:SetScript("OnSizeChanged",function(s)
        local cw,ch=s:GetWidth(),s:GetHeight();
        local clW,clH=math.max(AL.MIN_WINDOW_WIDTH,cw),math.max(AL.MIN_WINDOW_HEIGHT,ch);
        local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight();
        local currentLeft = s:GetLeft() or 0;
        local currentTop = s:GetTop() or 0;
        clW = math.min(clW, screenWidth - currentLeft); 
        clH = math.min(clH, currentTop); 
        if clW~=cw or clH~=ch then s:SetSize(clW,clH); return; end
        _G.AL_SavedData.window.width,_G.AL_SavedData.window.height=clW,ch;AL:UpdateLayout();
    end);

    local lp=CreateFrame("Frame","AL_LeftPanel" .. frameNameSuffix,self.MainWindow);self.LeftPanel=lp;
    if BackdropTemplateMixin then Mixin(lp,BackdropTemplateMixin);end
    lp:SetBackdrop({bgFile="Interface/DialogFrame/UI-DialogBox-Background-Dark",edgeFile="Interface/Tooltips/UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}});
    lp:SetBackdropColor(0.15,0.15,0.2,0.9);

    local function createLeftPanelButton(name, text, criteriaOrFunc, isSortOrFilterButton)
        local btn = CreateFrame("Button", "AL_"..name.."Button" .. frameNameSuffix, self.LeftPanel, "UIPanelButtonTemplate");
        btn:SetText(text);
        if isSortOrFilterButton then
            btn.criteria = criteriaOrFunc;
            btn:SetScript("OnClick", function(selfBtn)
                if selfBtn.criteria == AL.SORT_CHARACTER or selfBtn.criteria == AL.SORT_REALM then
                    AL.currentViewMode = (selfBtn.criteria == AL.SORT_CHARACTER and "SORTED_BY_CHARACTER") or "SORTED_BY_REALM";
                    AL.currentSortCriteria = selfBtn.criteria;
                    AL.currentQualityFilter = nil; 
                elseif type(selfBtn.criteria) == "string" and string.sub(selfBtn.criteria, 1, #AL.SORT_QUALITY_PREFIX) == AL.SORT_QUALITY_PREFIX then
                    local qualityValue = tonumber(string.sub(selfBtn.criteria, #AL.SORT_QUALITY_PREFIX + 1));
                    AL.currentQualityFilter = (qualityValue == -1 and nil or qualityValue);
                else 
                    AL.currentViewMode = "FILTERED_FLAT_LIST"; 
                    AL.currentSortCriteria = selfBtn.criteria;
                    AL.currentQualityFilter = nil; 
                    if selfBtn.criteria == AL.SORT_ALPHA then
                        AL.currentViewMode = "GROUPED_BY_ITEM";
                    end
                end
                _G.AL_SavedData.lastSortCriteria = AL.currentSortCriteria;
                _G.AL_SavedData.viewMode = AL.currentViewMode;
                _G.AL_SavedData.activeQualityFilter = AL.currentQualityFilter;
                AL:RefreshLedgerDisplay();
            end);
        elseif type(criteriaOrFunc) == "function" then
            btn:SetScript("OnClick", criteriaOrFunc);
        end
        return btn;
    end

    self.CreateReminderButton = createLeftPanelButton("CreateReminder", "Track New Item", function() AL:ShowReminderPopup(); end, false);
    self.RefreshListButton = createLeftPanelButton("RefreshList", "Refresh List", function() AL:RefreshLedgerDisplay(); end, false);
    self.HelpWindowButton = createLeftPanelButton("HelpWindow", "How To Use", function() AL:ToggleHelpWindow(); end, false);
    self.ToggleMinimapButton = createLeftPanelButton("ToggleMinimap", "Toggle Minimap Icon", function()
        _G.AL_SavedData.minimapIcon.hide = not _G.AL_SavedData.minimapIcon.hide;
        if AL.LibDBIcon_Lib then
            if _G.AL_SavedData.minimapIcon.hide then AL.LibDBIcon_Lib:Hide(LDB_PREFIX);
            else AL.LibDBIcon_Lib:Show(LDB_PREFIX); end
        end
    end, false);

    self.SortAlphaButton = createLeftPanelButton("SortAlpha", "Item Name (Grouped)", AL.SORT_ALPHA, true);
    self.SortCharacterButton = createLeftPanelButton("SortCharacter", "By Character (Flat)", AL.SORT_CHARACTER, true);
    self.SortRealmButton = createLeftPanelButton("SortRealm", "By Realm (Flat)", AL.SORT_REALM, true);

    self.SortBagsButton = createLeftPanelButton("SortBags", "Bags First (Flat)", AL.SORT_BAGS, true);
    self.SortBankButton = createLeftPanelButton("SortBank", "Bank First (Flat)", AL.SORT_BANK, true);
    self.SortMailButton = createLeftPanelButton("SortMail", "Mail First (Flat)", AL.SORT_MAIL, true);
    self.SortAuctionButton = createLeftPanelButton("SortAuction", "Auction First (Flat)", AL.SORT_AUCTION, true);
    self.SortLimboButton = createLeftPanelButton("SortLimbo", "Limbo First (Flat)", AL.SORT_LIMBO, true);

    local qualities = {
        {label = "Poor", value = 0, color = (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[0] and ITEM_QUALITY_COLORS[0].hex) or "|cff9d9d9d"},
        {label = "Common", value = 1, color= (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[1] and ITEM_QUALITY_COLORS[1].hex) or "|cffffffff"},
        {label = "Uncommon", value = 2, color= (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[2] and ITEM_QUALITY_COLORS[2].hex) or "|cff1eff00"},
        {label = "Rare", value = 3, color= (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[3] and ITEM_QUALITY_COLORS[3].hex) or "|cff0070dd"},
        {label = "Epic", value = 4, color= (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[4] and ITEM_QUALITY_COLORS[4].hex) or "|cffa335ee"},
        {label = "Legendary+", value = 5, color= (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[5] and ITEM_QUALITY_COLORS[5].hex) or "|cffff8000"} 
    }
    self.SortQualityButtons = {};
    for i, qualityInfo in ipairs(qualities) do
        local qualityButton = createLeftPanelButton("SortQuality"..qualityInfo.value, (qualityInfo.color or WHITE_FONT_COLOR_CODE) ..qualityInfo.label.."|r", AL.SORT_QUALITY_PREFIX .. qualityInfo.value, true);
        table.insert(self.SortQualityButtons, qualityButton);
    end
    local clearQualityFilterButton = createLeftPanelButton("ClearQualityFilter", "All Qualities", AL.SORT_QUALITY_PREFIX .. "-1", true)
    table.insert(self.SortQualityButtons, clearQualityFilterButton);

    local function createLabelFrame(name, parentPanel)
        local labelFrame = CreateFrame("Frame", "AL_"..name.."Frame" .. frameNameSuffix, parentPanel);
        if BackdropTemplateMixin then Mixin(labelFrame, BackdropTemplateMixin); end
        labelFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Header", 
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        });
        labelFrame:SetBackdropColor(unpack(AL.LABEL_BACKDROP_COLOR));
        labelFrame.text = labelFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
        labelFrame.text:SetAllPoints(true);
        labelFrame.text:SetTextColor(unpack(AL.LABEL_TEXT_COLOR));
        return labelFrame;
    end

    self.LabelSortBy = createLabelFrame("LabelSortBy", self.LeftPanel);
    self.LabelFilterLocation = createLabelFrame("LabelFilterLocation", self.LeftPanel);
    self.LabelFilterQuality = createLabelFrame("LabelFilterQuality", self.LeftPanel);


    local headerFrame=CreateFrame("Frame","AL_ColumnHeaderFrame" .. frameNameSuffix,self.MainWindow);self.ColumnHeaderFrame=headerFrame;
    if BackdropTemplateMixin then Mixin(headerFrame,BackdropTemplateMixin);end;
    headerFrame:SetBackdrop({bgFile="Interface/DialogFrame/UI-DialogBox-Background", edgeSize=0, tile=true, tileSize=16, insets = {left=0,right=0,top=0,bottom=0}});
    headerFrame:SetBackdropBorderColor(0,0,0,0); headerFrame:SetBackdropColor(0.1,0.1,0.12,0.0); headerFrame:SetFrameLevel(AL.MainWindow:GetFrameLevel() + 2);
    
    local function CreateHeaderText(p,fsns,txt,jstH_param)
        local fs=p:CreateFontString(p:GetName()..fsns,"ARTWORK","GameFontNormalSmall");
        fs:SetHeight(AL.COLUMN_HEADER_HEIGHT-4);
        fs:SetText(txt);
        fs:SetJustifyH(jstH_param or "CENTER"); 
        fs:SetJustifyV("MIDDLE");
        return fs;
    end;
    
    headerFrame.NameHFS=CreateHeaderText(headerFrame,"_NameHFS","Item / Name","CENTER");
    headerFrame.LocationHFS=CreateHeaderText(headerFrame,"_LocationHFS","Location","CENTER");
    headerFrame.OwnedHFS=CreateHeaderText(headerFrame,"_OwnedHFS","Owned","CENTER");
    headerFrame.NotesHFS=CreateHeaderText(headerFrame,"_NotesHFS","Notes","CENTER");
    headerFrame.CharacterHFS=CreateHeaderText(headerFrame,"_CharacterHFS","Character","CENTER");
    headerFrame.RealmHFS=CreateHeaderText(headerFrame,"_RealmHFS","Realm","CENTER");
    headerFrame.ActionsHFS=CreateHeaderText(headerFrame,"_ActionsHFS","Delete","CENTER");

    local sf=CreateFrame("ScrollFrame","AL_ItemScrollFrame" .. frameNameSuffix,self.MainWindow,"UIPanelScrollFrameTemplate");self.ScrollFrame=sf;
    self.ScrollFrame:SetFrameLevel(AL.MainWindow:GetFrameLevel() + 2);
    local sc=CreateFrame("Frame","AL_ItemScrollChild" .. frameNameSuffix,sf);self.ScrollChild=sc;
    sc:SetSize(100,10);sf:SetScrollChild(sc);
end

StaticPopupDialogs["AL_CONFIRM_DELETE_ALL_ITEM_INSTANCES"] = {
    text = "Are you sure you want to remove all tracked entries for %s?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        if data and data.itemID then
            AL:RemoveAllInstancesOfItem(data.itemID);
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3, 
};

function AL:StartStopPeriodicRefresh() if self.MainWindow and self.MainWindow:IsShown()then if not self.periodicRefreshTimer then local interval=tonumber(AL.PERIODIC_REFRESH_INTERVAL)or 7.0;if type(interval)~="number"or interval<=0 then interval=7.0;end;self.periodicRefreshTimer=C_Timer.NewTicker(interval,function()if AL.MainWindow and AL.MainWindow:IsShown()then AL:RefreshLedgerDisplay();else if AL.periodicRefreshTimer then AL.periodicRefreshTimer:Cancel();AL.periodicRefreshTimer=nil;end;end;end);end;else if self.periodicRefreshTimer then self.periodicRefreshTimer:Cancel();AL.periodicRefreshTimer=nil;end;end;end
function AL:ApplyWindowState() local frameNameSuffix = "_v" .. AL.VERSION:gsub("%.","_"); local mainWindowName = "AL_MainWindow" .. frameNameSuffix; if not self.MainWindow then return;end; if self.MainWindow:GetName() ~= mainWindowName then end ; local sv=_G.AL_SavedData;local sW,sH=GetScreenWidth(),GetScreenHeight();local w=tonumber(sv.window.width)or AL.DEFAULT_WINDOW_WIDTH;local h=tonumber(sv.window.height)or AL.DEFAULT_WINDOW_HEIGHT;local xFL,yFTpd=tonumber(sv.window.x),tonumber(sv.window.y);local rP=false; local VME=25; if sv.firstRun then rP=true;elseif type(xFL)~="number"or type(yFTpd)~="number"then rP=true;else if xFL>(sW-(w/2))then rP=true;elseif(xFL+(w/2))<0 then rP=true;end;if not rP then if yFTpd>(sH-(VME))then rP=true;elseif(yFTpd+h)<VME then rP=true;end;end;end; local function Fin(doReset,targetX,targetY,targetW,targetH) if not AL.MainWindow then return;end; AL.MainWindow:ClearAllPoints(); if doReset then AL.MainWindow:SetSize(AL.DEFAULT_WINDOW_WIDTH,AL.DEFAULT_WINDOW_HEIGHT); AL.MainWindow:SetPoint("CENTER",UIParent,"CENTER",0,0); sv.window.x=AL.MainWindow:GetLeft();sv.window.y=UIParent:GetHeight()-AL.MainWindow:GetTop(); sv.window.width=AL.DEFAULT_WINDOW_WIDTH; sv.window.height=AL.DEFAULT_WINDOW_HEIGHT; sv.window.visible=true; else AL.MainWindow:SetSize(targetW,targetH); AL.MainWindow:SetPoint("TOPLEFT",nil,"TOPLEFT",targetX,-targetY); end; C_Timer.After(0, function() if AL.MainWindow and AL.MainWindow:IsShown() and AL.UpdateLayout then AL:UpdateLayout(); end end); if sv.window.visible then AL.MainWindow:Show();else AL.MainWindow:Hide();AL:HideReminderPopup(); AL:HideHelpWindow(); end; sv.firstRun=false; AL:StartStopPeriodicRefresh(); end; Fin(rP,xFL,yFTpd,w,h); end
function AL:ToggleMainWindow() local frameNameSuffix = "_v" .. AL.VERSION:gsub("%.","_"); local mainWindowName = "AL_MainWindow" .. frameNameSuffix; if not self.MainWindow or self.MainWindow:GetName() ~= mainWindowName then AL:CreateFrames(); if self.MainWindow and self.MainWindow:GetName() == mainWindowName then AL:ApplyWindowState(); else return; end; end; if self.MainWindow:IsShown()then self.MainWindow:Hide();_G.AL_SavedData.window.visible=false;AL:HideReminderPopup(); AL:HideHelpWindow(); else AL:ApplyWindowState();if not self.MainWindow:IsShown()then AL.MainWindow:Show();_G.AL_SavedData.window.visible=true;AL:UpdateLayout();else _G.AL_SavedData.window.visible=true;end;end;AL:StartStopPeriodicRefresh();end

function AL:RunSetScriptControlTest()
    if self.testSetScriptControlDone then return end;
    local testFrameName = "AL_SetScriptControlTest_v" .. AL.VERSION:gsub("%.","_")
    local testFrame = CreateFrame("Button", testFrameName, UIParent);
    local function controlOnClick_Handler(selfCtrl) end
    if testFrame then
        testFrame:SetSize(20,20); testFrame:SetText("T"); testFrame:Hide();
        pcall(testFrame.SetScript, testFrame, "OnClick", controlOnClick_Handler);
        testFrame:SetParent(nil); 
    else
        DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. " (v" .. AL.VERSION .. ") Warning: ControlTestFrame failed to create.");
    end
    self.testSetScriptControlDone = true;
end

function AL:AttemptPostItemHook()
    if self.postItemHooked then return; end
    local cahType = type(C_AuctionHouse);
    local postItemType = cahType == "table" and type(C_AuctionHouse.PostItem) or "N/A";
    if cahType == "table" and postItemType == "function" then
        local hookSuccess, hookErr = pcall(hooksecurefunc, C_AuctionHouse, "PostItem", AuctioneersLedger_Global_OnPostItemHook)
        if hookSuccess then
            self.postItemHooked = true;
        else
            DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. " (v" .. AL.VERSION .. ") Hook Error: FAILED to hook C_AuctionHouse.PostItem. Error: " .. tostring(hookErr));
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage(ADDON_NAME .. " (v" .. AL.VERSION .. ") Hook Warning: C_AuctionHouse.PostItem is NOT hookable.");
    end
end

function AL:HandleAddonLoaded(arg)
    if not (arg == ADDON_NAME and not self.addonLoadedProcessed) then return end;
    self.addonLoadedProcessed=true; self.mailAPIsMissingLogged = false;
    AL.gameFullyInitialized = false; 

    local currentCharacter = UnitName("player");
    local currentRealm = GetRealmName();

    _G.AL_SavedData = _G.AL_SavedData or { window={width=AL.DEFAULT_WINDOW_WIDTH,height=AL.DEFAULT_WINDOW_HEIGHT,visible=true},firstRun=true,minimapIcon={},trackedItems={},lastSortCriteria=AL.SORT_ALPHA, itemExpansionStates={}, viewMode="GROUPED_BY_ITEM", activeQualityFilter=nil };
    _G.AL_SavedData.trackedItems = _G.AL_SavedData.trackedItems or {};
    _G.AL_SavedData.itemExpansionStates = _G.AL_SavedData.itemExpansionStates or {};

    for _, itemEntry in ipairs(_G.AL_SavedData.trackedItems) do
        InitializeTrackedItemEntry(itemEntry, currentCharacter, currentRealm); 
    end
    if _G.AL_SavedData.firstRun == nil then _G.AL_SavedData.firstRun = true; end;
    if type(_G.AL_SavedData.window) ~= "table" then _G.AL_SavedData.window = {width=AL.DEFAULT_WINDOW_WIDTH,height=AL.DEFAULT_WINDOW_HEIGHT,visible=true,x=nil,y=nil}; end;
    if type(_G.AL_SavedData.window.visible) ~= "boolean" then _G.AL_SavedData.window.visible = true; end;
    if type(_G.AL_SavedData.lastSortCriteria) ~= "string" then _G.AL_SavedData.lastSortCriteria = AL.SORT_ALPHA; end
    if type(_G.AL_SavedData.viewMode) ~= "string" then _G.AL_SavedData.viewMode = "GROUPED_BY_ITEM"; end

    local loadedSort = _G.AL_SavedData.lastSortCriteria;
    if loadedSort == "NOTOWNED" then loadedSort = AL.SORT_LIMBO; _G.AL_SavedData.lastSortCriteria = AL.SORT_LIMBO; end 
    self.currentSortCriteria = loadedSort or AL.SORT_ALPHA;
    self.currentViewMode = _G.AL_SavedData.viewMode or "GROUPED_BY_ITEM";
    self.currentQualityFilter = _G.AL_SavedData.activeQualityFilter; 

    local function CmdH(m) self:ToggleMainWindow();end;
    SLASH_ALEDGER1="/aledger";SLASH_ALEDGER2="/al";SLASH_ALEDGER3="/auctioneersledger"; SlashCmdList["ALEDGER"]=CmdH;
    
    self:InitializeLibs(); if self.libsReady then self:CreateLDBSourceAndMinimapIcon(); end;
end

function AL:HandlePlayerLogin()
    self.mailAPIsMissingLogged = false;
    self.ahEntryDumpDone = false; 
    AL.gameFullyInitialized = false; 
    if not self.libsReady then self:InitializeLibs();end;
    self:RunSetScriptControlTest();
    self:AttemptPostItemHook();
    self:CreateFrames(); 
    self:ApplyWindowState(); 
    self:StartStopPeriodicRefresh(); 
end

function AL:HandlePlayerEnteringWorld()
    self.mailAPIsMissingLogged = false; 
    AL.gameFullyInitialized = true; 
    -- Removed debug chat messages for PEW event
    if not self.libsReady then self:InitializeLibs(); end; 
    if self.MainWindow and self.MainWindow:IsShown() then
        self:RefreshLedgerDisplay() 
    end
end

function AL:HandleMailShow()
    AL.mailAPIsMissingLogged = false; 
    if AL.mailRefreshTimer then AL.mailRefreshTimer:Cancel(); AL.mailRefreshTimer = nil; end
    AL.mailRefreshTimer = C_Timer.After(AL.MAIL_REFRESH_DELAY, function()
        AL:TriggerDebouncedRefresh("MAIL_SHOW_Delayed");
        AL.mailRefreshTimer = nil;
    end)
end

function AuctioneersLedger_Global_OnPostItemHook(itemLocation, duration, quantity, bid, buyout)
    if not itemLocation then return; end
    local itemID;
    local successGetID, itemIDValueOrErr = pcall(function() return itemLocation:GetItemID() end);
    if successGetID and itemIDValueOrErr then
        itemID = itemIDValueOrErr;
    elseif itemLocation and type(itemLocation.GetItemLink) == "function" then 
        local successGetLink, itemLinkValue = pcall(function() return itemLocation:GetItemLink() end);
        if successGetLink and itemLinkValue and AL and AL.GetItemIDFromLink then
            itemID = AL:GetItemIDFromLink(itemLinkValue);
        end
    end
    if not itemID then return; end 

    local isTracked = false;
    if _G.AL_SavedData and _G.AL_SavedData.trackedItems then
        for _, trackedItemData in ipairs(_G.AL_SavedData.trackedItems) do
            if trackedItemData.itemID == itemID and trackedItemData.characterName == UnitName("player") and trackedItemData.characterRealm == GetRealmName() then
                isTracked = true;
                break;
            end
        end
    end

    if isTracked then
        if C_AuctionHouse and type(C_AuctionHouse.RequestOwnerAuctionItems) == "function" then
            C_AuctionHouse.RequestOwnerAuctionItems();
        end
        if AL and AL.TriggerDebouncedRefresh then AL:TriggerDebouncedRefresh("GlobalPostItemHook_TrackedItem"); end
    end
end

local eventHandlerFrame = CreateFrame("Frame", "AL_EventHandler_v" .. AL.VERSION:gsub("%.","_"));
eventHandlerFrame:RegisterEvent("ADDON_LOADED");
eventHandlerFrame:RegisterEvent("PLAYER_LOGIN");
eventHandlerFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
eventHandlerFrame:RegisterEvent("BAG_UPDATE");
eventHandlerFrame:RegisterEvent("AUCTION_HOUSE_CLOSED");
eventHandlerFrame:RegisterEvent("AUCTION_HOUSE_SHOW"); 
eventHandlerFrame:RegisterEvent("MAIL_SHOW");
eventHandlerFrame:RegisterEvent("MAIL_INBOX_UPDATE");
eventHandlerFrame:RegisterEvent("MAIL_CLOSED");

eventHandlerFrame:SetScript("OnEvent", function(selfFrame, event, ...)
    if event == "ADDON_LOADED" then
        AL:HandleAddonLoaded(...);
    elseif event == "PLAYER_LOGIN" then
        AL:HandlePlayerLogin();
    elseif event == "PLAYER_ENTERING_WORLD" then
        AL:HandlePlayerEnteringWorld();
    elseif event=="BAG_UPDATE" or event=="AUCTION_HOUSE_CLOSED" or event=="MAIL_INBOX_UPDATE" or event=="MAIL_CLOSED" then
        AL:TriggerDebouncedRefresh(event);
    elseif event == "AUCTION_HOUSE_SHOW" then
        if C_AuctionHouse and type(C_AuctionHouse.RequestOwnerAuctionItems) == "function" then
            C_AuctionHouse.RequestOwnerAuctionItems();
        end
        AL:TriggerDebouncedRefresh(event); 
    elseif event == "MAIL_SHOW" then
        AL:HandleMailShow(); 
    end
end);
