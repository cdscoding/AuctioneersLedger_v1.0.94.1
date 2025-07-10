-- Auctioneer's Ledger - Data
-- This file handles data management, retrieval, and saved variables.

-- [[ BUG FIX: Re-introduced the missing InitializeSavedData function to the correct file. ]]
function AL:InitializeSavedData()
    if not _G.AL_SavedData then _G.AL_SavedData = {} end
    if not _G.AL_SavedData.Transactions then _G.AL_SavedData.Transactions = {} end
    if not _G.AL_SavedData.Items then _G.AL_SavedData.Items = {} end
end

-- Scans the financial history and applies any relevant transactions to a newly tracked item.
function AL:ReconcileHistory(newItemID, newItemName)
    local finances = _G.AuctioneersLedgerFinances
    if not finances then return end
    
    local newItemIDNum = tonumber(newItemID)
    if not newItemIDNum then return end

    local function processHistoryTable(historyTable, transactionType, source)
        if not historyTable then return end
        for _, entry in ipairs(historyTable) do
            -- Reconcile if the names match and the entry hasn't been linked yet
            if entry.itemName == newItemName and not entry.itemLink then
                local correctLink = _G.AL_SavedData.Items[newItemIDNum] and _G.AL_SavedData.Items[newItemIDNum].itemLink
                if correctLink then
                    entry.itemLink = correctLink
                    -- Record the transaction to update the P&L data
                    self:RecordTransaction(transactionType, source, newItemIDNum, entry.price, entry.quantity)
                end
            end
        end
    end

    processHistoryTable(finances.purchases, "BUY", "AUCTION")
    processHistoryTable(finances.sales, "SELL", "AUCTION")
end

-- One-time migration function for financial data
function AL:MigrateFinancialData()
    if not _G.AL_SavedData or not _G.AL_SavedData.Items then return end
    
    local itemIDLookup = {}
    for itemID, itemData in pairs(_G.AL_SavedData.Items) do
        if itemData.itemName then
            itemIDLookup[itemData.itemName] = tonumber(itemID)
        end
    end

    if _G.AuctioneersLedgerFinances and _G.AuctioneersLedgerFinances.purchases then
        for _, purchase in ipairs(_G.AuctioneersLedgerFinances.purchases) do
            local itemID = self:GetItemIDFromLink(purchase.itemLink) or itemIDLookup[purchase.itemName]
            if itemID then
                self:RecordTransaction("BUY", "AUCTION", itemID, purchase.price, purchase.quantity)
            end
        end
    end

    if _G.AuctioneersLedgerFinances and _G.AuctioneersLedgerFinances.sales then
        for _, sale in ipairs(_G.AuctioneersLedgerFinances.sales) do
            local itemID = self:GetItemIDFromLink(sale.itemLink) or itemIDLookup[sale.itemName]
            if itemID then
                self:RecordTransaction("SELL", "AUCTION", itemID, sale.price, sale.quantity)
            end
        end
    end
end

-- This function initializes a clean, structured database or migrates data from old versions.
function AL:InitializeDB()
    if type(_G.AL_SavedData) ~= "table" then _G.AL_SavedData = {} end
    if type(_G.AL_SavedData.Settings) ~= "table" then _G.AL_SavedData.Settings = {} end

    if type(AL.InitializeFinancesDB) == "function" then
        AL:InitializeFinancesDB()
    end
    
    _G.AL_SavedData.Settings.dbVersion = _G.AL_SavedData.Settings.dbVersion or 1

    if _G.AL_SavedData.Settings.dbVersion < 9 then
        -- New data structure for finances
        for _, itemData in pairs(_G.AL_SavedData.Items or {}) do
            for _, charData in pairs(itemData.characters or {}) do
                -- Auction data
                charData.totalAuctionBoughtQty = charData.totalAuctionBoughtQty or 0
                charData.totalAuctionSoldQty = charData.totalAuctionSoldQty or 0
                charData.totalAuctionProfit = charData.totalAuctionProfit or 0
                charData.totalAuctionLoss = charData.totalAuctionLoss or 0
                
                -- Vendor data
                charData.totalVendorBoughtQty = charData.totalVendorBoughtQty or 0
                charData.totalVendorSoldQty = charData.totalVendorSoldQty or 0
                charData.totalVendorProfit = charData.totalVendorProfit or 0
                charData.totalVendorLoss = charData.totalVendorLoss or 0

                -- Remove old fields
                charData.totalAuctionBoughtValue = nil; charData.totalAuctionSoldValue = nil
                charData.lastAuctionBuyPrice = nil; charData.lastAuctionSellPrice = nil
                charData.lastAuctionBuyDate = nil; charData.lastAuctionSellDate = nil
                charData.totalVendorBoughtValue = nil; charData.totalVendorSoldValue = nil
                charData.lastVendorBuyPrice = nil; charData.lastVendorSellPrice = nil
                charData.lastVendorBuyDate = nil; charData.lastVendorSellDate = nil
            end
        end
        
        self:MigrateFinancialData()

        _G.AL_SavedData.Settings.dbVersion = 9
    end

    local defaultSettings = {
        window = {x=nil,y=nil,width=AL.DEFAULT_WINDOW_WIDTH,height=AL.DEFAULT_WINDOW_HEIGHT,visible=true},
        minimapIcon = {},
        itemExpansionStates = {},
        activeViewMode = AL.VIEW_WARBAND_STOCK,
        dbVersion = 9,
        filterSettings = {
            [AL.VIEW_WARBAND_STOCK]     = { sort = AL.SORT_ALPHA, quality = nil, stack = nil, view = "GROUPED_BY_ITEM"},
            [AL.VIEW_AUCTION_FINANCES]  = { sort = AL.SORT_ITEM_NAME_FLAT, quality = nil, stack = nil, view = "FLAT_LIST"},
            [AL.VIEW_VENDOR_FINANCES]   = { sort = AL.SORT_ITEM_NAME_FLAT, quality = nil, stack = nil, view = "FLAT_LIST"},
            [AL.VIEW_AUCTION_PRICING]   = { sort = AL.SORT_ITEM_NAME_FLAT, quality = nil, stack = nil, view = "FLAT_LIST"},
            [AL.VIEW_AUCTION_SETTINGS]  = { sort = AL.SORT_ITEM_NAME_FLAT, quality = nil, stack = nil, view = "FLAT_LIST"},
        }
    }

    for k, v in pairs(defaultSettings) do
        if _G.AL_SavedData.Settings[k] == nil then
            _G.AL_SavedData.Settings[k] = v
        end
    end
	
    if type(_G.AL_SavedData.Settings.filterSettings) ~= "table" then
        _G.AL_SavedData.Settings.filterSettings = defaultSettings.filterSettings
    end
    for _, viewMode in ipairs({AL.VIEW_WARBAND_STOCK, AL.VIEW_AUCTION_FINANCES, AL.VIEW_VENDOR_FINANCES, AL.VIEW_AUCTION_PRICING, AL.VIEW_AUCTION_SETTINGS}) do
        if type(_G.AL_SavedData.Settings.filterSettings[viewMode]) ~= "table" then
            _G.AL_SavedData.Settings.filterSettings[viewMode] = defaultSettings.filterSettings[viewMode]
        end
    end

    if type(_G.AL_SavedData.Items) ~= "table" then _G.AL_SavedData.Items = {} end
    if type(_G.AL_SavedData.PendingAuctions) ~= "table" then _G.AL_SavedData.PendingAuctions = {} end
    if type(_G.AL_SavedData.TooltipCache) ~= "table" then _G.AL_SavedData.TooltipCache = {} end
    if type(_G.AL_SavedData.TooltipCache.recentlyViewedItems) ~= "table" then _G.AL_SavedData.TooltipCache.recentlyViewedItems = {} end
end

-- [[ REWRITTEN: RecordTransaction is now the central point for all financial calculations ]]
function AL:RecordTransaction(transactionType, source, itemID, value, quantity)
    if not itemID or not value or value < 0 then return end
    
    local numericItemID = tonumber(itemID)
    if not numericItemID then return end
    
    local itemEntry = _G.AL_SavedData and _G.AL_SavedData.Items and _G.AL_SavedData.Items[numericItemID]
    if not itemEntry then return end

    local charKey = UnitName("player") .. "-" .. GetRealmName()
    if not itemEntry.characters[charKey] then return end
    
    local charData = itemEntry.characters[charKey]
    local qty = quantity or 1
    local prefix = (source == "AUCTION") and "Auction" or "Vendor"

    if transactionType == "BUY" then
        charData["total" .. prefix .. "BoughtQty"] = (charData["total" .. prefix .. "BoughtQty"] or 0) + qty
        charData["total" .. prefix .. "Loss"] = (charData["total" .. prefix .. "Loss"] or 0) + value
    elseif transactionType == "SELL" then
        charData["total" .. prefix .. "SoldQty"] = (charData["total" .. prefix .. "SoldQty"] or 0) + qty
        charData["total" .. prefix .. "Profit"] = (charData["total" .. prefix .. "Profit"] or 0) + value
    elseif transactionType == "DEPOSIT" then
        charData["total" .. prefix .. "Loss"] = (charData["total" .. prefix .. "Loss"] or 0) + value
    end

    if (AL.currentActiveTab == AL.VIEW_AUCTION_FINANCES or AL.currentActiveTab == AL.VIEW_VENDOR_FINANCES) and AL.TriggerDebouncedRefresh then
        AL:TriggerDebouncedRefresh("FINANCE_UPDATE")
    end
end

function AL:InternalAddItem(itemLink, forCharName, forCharRealm)
    local itemName, realItemLink, itemRarity, _, _, _, _, maxStack, _, itemTexture = GetItemInfo(itemLink);
    
    if not itemName or not itemTexture or not realItemLink then
        return false, "Could not get item info from game client."
    end
    
    local itemID = self:GetItemIDFromLink(realItemLink);
    if not itemID then
        return false, "Could not get a valid item ID."
    end
    
    local charKey = forCharName .. "-" .. forCharRealm

    if _G.AL_SavedData.Items[itemID] and _G.AL_SavedData.Items[itemID].characters[charKey] then
        return false, "This item is already being tracked by this character."
    end
    
    if not _G.AL_SavedData.Items[itemID] then
        _G.AL_SavedData.Items[itemID] = {
            itemID = itemID, itemLink = realItemLink, itemName = itemName,
            itemTexture = itemTexture, itemRarity = itemRarity, characters = {}
        }
    end
	
    local isStackable = (tonumber(maxStack) or 1) > 1
    local defaultQuantity = isStackable and (tonumber(maxStack) or 100) or 1

    _G.AL_SavedData.Items[itemID].characters[charKey] = {
        characterName = forCharName, characterRealm = forCharRealm, itemLink = realItemLink, itemRarity = itemRarity,
        lastVerifiedLocation = nil, lastVerifiedCount = 0, lastVerifiedTimestamp = 0, awaitingMailAfterAuctionCancel = false,
        safetyNetBuyout = 0, normalBuyoutPrice = 0, undercutAmount = 0, autoUpdateFromMarket = true,
        auctionSettings = { duration = 720, quantity = defaultQuantity },
        marketData = { lastScan = 0, minBuyout = 0, marketValue = 0, numAuctions = 0, ALMarketPrice = 0 },

        totalAuctionBoughtQty = 0, totalAuctionSoldQty = 0, totalAuctionProfit = 0, totalAuctionLoss = 0,
        totalVendorBoughtQty = 0, totalVendorSoldQty = 0, totalVendorProfit = 0, totalVendorLoss = 0,
    }
    
    self:ReconcileHistory(itemID, itemName)
    self:BuildSalesCache()
    
    return true, "Item Added Successfully"
end

-- Other functions (GetSafe..., GetItemIDFromLink, IsItemAuctionable..., etc.) remain unchanged below this line...
function AL:GetSafeContainerNumSlots(bagIndex)
    if C_Container and type(C_Container.GetContainerNumSlots) == "function" then return C_Container.GetContainerNumSlots(bagIndex)
    elseif type(GetContainerNumSlots) == "function" then return GetContainerNumSlots(bagIndex) end
    return 0
end

function AL:GetSafeContainerItemLink(bagIndex, slotIndex)
    if C_Container and type(C_Container.GetContainerItemLink) == "function" then return C_Container.GetContainerItemLink(bagIndex, slotIndex)
    elseif type(GetContainerItemLink) == "function" then return GetContainerItemLink(bagIndex, slotIndex) end
    return nil
end

function AL:GetSafeContainerItemInfo(bagIndex, slotIndex)
    if C_Container and type(C_Container.GetContainerItemInfo) == "function" then return C_Container.GetContainerItemInfo(bagIndex, slotIndex)
    elseif type(GetContainerItemInfo) == "function" then return GetContainerItemInfo(bagIndex, slotIndex) end
    return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
end

function AL:GetItemIDFromLink(itemLink) if not itemLink or type(itemLink) ~= "string" then return nil end return tonumber(string.match(itemLink, "item:(%d+)")) end
function AL:GetItemNameFromLink(itemLink) if not itemLink or type(itemLink) ~= "string" then return "Unknown Item" end local iN=GetItemInfo(itemLink) return iN or "Unknown Item" end

function AL:IsItemAuctionableByLocation(itemLocation)
    local isAuctionable = false
    if C_AuctionHouse and C_AuctionHouse.IsSellItemValid then
        isAuctionable = C_AuctionHouse.IsSellItemValid(itemLocation)
    end
    return isAuctionable
end

function AL:IsItemAuctionable_Fallback(itemLink)
    if not itemLink then return false end
    local itemName, _, _, _, _, itemType, _, _, _, _, _, _, bindType = GetItemInfo(itemLink)
    if not itemName then return false end
    if bindType == 1 or bindType == 4 then return false end -- "Bind on Pickup" or "Quest" items.
    if itemType == "Quest" then return false end
    
    local tooltip = GameTooltip
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(itemLink)
    for i=1, tooltip:NumLines() do
        local lineText = _G["GameTooltipTextLeft"..i]:GetText()
        if lineText then
            if (SOULBOUND and lineText:find(SOULBOUND)) or 
               (ITEM_SOULBOUND and lineText:find(ITEM_SOULBOUND)) or 
               (ITEM_BIND_QUEST and lineText:find(ITEM_BIND_QUEST)) then
                tooltip:Hide()
                return false
            end
        end
    end
    tooltip:Hide()
    return true
end

function AL:TriggerDebouncedRefresh(reason)
    local debounceSeconds = tonumber(AL.EVENT_DEBOUNCE_TIME)
    if type(debounceSeconds) ~= "number" or debounceSeconds <= 0 then debounceSeconds = 0.75 end
    AL.eventDebounceCounter = (AL.eventDebounceCounter or 0) + 1
    if AL.eventRefreshTimer then AL.eventRefreshTimer:Cancel() end
    AL.eventRefreshTimer = nil
    C_Timer.After(debounceSeconds, function()
        AL.eventDebounceCounter = 0
        if AL.RefreshLedgerDisplay then AL:RefreshLedgerDisplay() end
        AL.eventRefreshTimer = nil
    end)
end

function AL:GetItemOwnershipDetails(charData_in)
    local d = {
        liveLocation = nil, liveCount = 0,
        locationText = AL.LOCATION_LIMBO, 
        colorR, colorG, colorB, colorA = unpack(AL.COLOR_LIMBO),
        displayText = "00", notesText = "", isStale = false, isLink = false
    }
    if not charData_in or not charData_in.characterName then 
        return d 
    end

    local itemID = self:GetItemIDFromLink(charData_in.itemLink)
    local itemCharacterName = charData_in.characterName
    local itemCharacterRealm = charData_in.characterRealm 
    
    local charKey = itemCharacterName .. "-" .. itemCharacterRealm
    local charData = _G.AL_SavedData.Items[itemID] and _G.AL_SavedData.Items[itemID].characters[charKey]
    if not charData then
        return d
    end

    local currentCharacter = UnitName("player")
    local currentRealm = GetRealmName()
    local isCurrentCharacterItemForPersonalCheck = (itemCharacterName == currentCharacter and itemCharacterRealm == currentRealm)
    local itemFoundLiveThisPass = false

    if isCurrentCharacterItemForPersonalCheck then
        local bagsCount = GetItemCount(itemID, false, false, false)
        if bagsCount > 0 then 
            d.liveLocation = AL.LOCATION_BAGS; d.liveCount = bagsCount; itemFoundLiveThisPass = true;
        end

        if not itemFoundLiveThisPass then
            local totalInBagsAndBank = GetItemCount(itemID, true, false, false) 
            local bankCount = totalInBagsAndBank - bagsCount
            if bankCount > 0 then 
                d.liveLocation = AL.LOCATION_BANK; d.liveCount = bankCount; itemFoundLiveThisPass = true;
            end
        end
        
        if not itemFoundLiveThisPass then
            local reagentBankCount = GetItemCount(itemID, false, false, true) 
            if reagentBankCount > 0 then
                d.liveLocation = AL.LOCATION_REAGENT_BANK; d.liveCount = reagentBankCount; itemFoundLiveThisPass = true;
            end
        end
    end

    if not itemFoundLiveThisPass then
        local totalWarbandBankCount = 0;
        if Enum and type(Enum.BagIndex) == "table" then
            for i = 1, AL.MAX_WARBAND_BANK_TABS_TO_CHECK do
                 local warbandBagID = _G["WARBAND_BANK_TAB_"..i.."_BAG_INDEX"] or (_G["Enum"] and _G["Enum"].BagIndex and _G["Enum"].BagIndex["AccountBankTab_"..i])
                if warbandBagID and type(warbandBagID) == "number" then
                    local numSlots = self:GetSafeContainerNumSlots(warbandBagID);
                    if numSlots > 0 then
                        for slot = 1, numSlots do
                            local itemLink = self:GetSafeContainerItemLink(warbandBagID, slot);
                            if itemLink then
                                local linkItemID = self:GetItemIDFromLink(itemLink);
                                if linkItemID and linkItemID == itemID then
                                    local itemInfo1, itemInfo2 = self:GetSafeContainerItemInfo(warbandBagID, slot);
                                    local slotItemCount = (type(itemInfo1) == "table" and itemInfo1.stackCount) or (type(itemInfo2) == "number" and itemInfo2) or 0
                                    totalWarbandBankCount = totalWarbandBankCount + slotItemCount;
                                end
                            end
                        end
                    end
                end
            end
        end
        if totalWarbandBankCount > 0 then
            d.liveLocation = AL.LOCATION_WARBAND_BANK; d.liveCount = totalWarbandBankCount; itemFoundLiveThisPass = true; 
        end
    end
    
    if isCurrentCharacterItemForPersonalCheck then
        local itemFoundOnAHLive = false;
        local isAHOpen = AuctionHouseFrame and AuctionHouseFrame:IsShown()
        if isAHOpen then
            local ahCountThisScan = 0;
            if C_AuctionHouse and type(C_AuctionHouse.GetOwnedAuctions) == "function" then
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
                    if not itemFoundLiveThisPass then
                        d.liveLocation = AL.LOCATION_AUCTION_HOUSE; d.liveCount = ahCountThisScan; itemFoundLiveThisPass = true;
                    end
                    itemFoundOnAHLive = true;
                    charData.awaitingMailAfterAuctionCancel = false; 
                end
            end
        end
        
        if charData.lastVerifiedLocation == AL.LOCATION_AUCTION_HOUSE and isAHOpen and not itemFoundOnAHLive then
            charData.awaitingMailAfterAuctionCancel = true;
        end

        local isMailOpen = MailFrame and MailFrame:IsShown()
        local shouldCheckMail = isMailOpen or charData.awaitingMailAfterAuctionCancel;
        if not itemFoundLiveThisPass and shouldCheckMail and type(GetInboxNumItems) == "function" then 
            local mailCountThisScan = 0;
            for mailIndex = 1, GetInboxNumItems() do
                local _, _, _, _, _, _, _, hasItem = GetInboxHeaderInfo(mailIndex);
                if hasItem then
                    for attachIndex = 1, AL.MAX_MAIL_ATTACHMENTS_TO_SCAN do
                        local mailItemLink = GetInboxItemLink(mailIndex, attachIndex)
                        if mailItemLink then
                            if self:GetItemIDFromLink(mailItemLink) == itemID then
                                local _, _, mailItemCount = GetInboxItem(mailIndex, attachIndex)
                                mailCountThisScan = mailCountThisScan + mailItemCount
                            end
                        else
                            break
                        end
                    end
                end
            end
            if mailCountThisScan > 0 then
                d.liveLocation = AL.LOCATION_MAIL; d.liveCount = mailCountThisScan; itemFoundLiveThisPass = true;
                charData.awaitingMailAfterAuctionCancel = false; 
            elseif charData.awaitingMailAfterAuctionCancel then 
                charData.awaitingMailAfterAuctionCancel = false; 
            end
        end
    end
    
    if not itemFoundLiveThisPass then
        local lastLocation = charData.lastVerifiedLocation
        
        if isCurrentCharacterItemForPersonalCheck and charData.awaitingMailAfterAuctionCancel then
            d.locationText = AL.LOCATION_MAIL
            d.liveCount = charData.lastVerifiedCount > 0 and charData.lastVerifiedCount or 0
            d.displayText = string.format("%02d", d.liveCount)
            d.isStale = true
            d.notesText = "Returning from AH"
        elseif isCurrentCharacterItemForPersonalCheck and lastLocation == AL.LOCATION_AUCTION_HOUSE then
            d.locationText = AL.LOCATION_AUCTION_HOUSE
            d.displayText = string.format("%02d", charData.lastVerifiedCount)
            d.isStale = true
            d.notesText = "Being auctioned."
        elseif isCurrentCharacterItemForPersonalCheck and (lastLocation == AL.LOCATION_BAGS or lastLocation == AL.LOCATION_BANK or lastLocation == AL.LOCATION_REAGENT_BANK) then
            d.locationText = AL.LOCATION_LIMBO
            d.liveCount = 0
            d.displayText = "00"
            d.notesText = ""
            d.isStale = false
            charData.lastVerifiedLocation = AL.LOCATION_LIMBO
            charData.lastVerifiedCount = 0
            charData.lastVerifiedTimestamp = GetTime()
            charData.awaitingMailAfterAuctionCancel = false
        elseif lastLocation and charData.lastVerifiedCount > 0 then
            d.locationText = lastLocation
            d.displayText = string.format("%02d", charData.lastVerifiedCount)
            d.isStale = true
            d.notesText = ""
            if d.locationText == AL.LOCATION_MAIL then d.notesText = "Inside mailbox."
            elseif d.locationText == AL.LOCATION_AUCTION_HOUSE then d.notesText = "Being auctioned."
            elseif d.locationText == AL.LOCATION_WARBAND_BANK then d.notesText = "Warband Bank (Stale)"
            elseif d.locationText == AL.LOCATION_REAGENT_BANK then d.notesText = "Reagent Bank (Stale)"
            end
            if d.locationText == AL.LOCATION_BAGS then d.isLink = true end
        else
            d.locationText = AL.LOCATION_LIMBO
            d.displayText = "00"
            d.notesText = ""
            d.isStale = false
            charData.lastVerifiedLocation = AL.LOCATION_LIMBO
            charData.lastVerifiedCount = 0
            charData.lastVerifiedTimestamp = GetTime()
            charData.awaitingMailAfterAuctionCancel = false
        end
    else
        d.locationText = d.liveLocation;
        d.displayText = string.format("%02d", d.liveCount);
        d.isLink = (d.liveLocation == AL.LOCATION_BAGS);
        
        charData.lastVerifiedLocation = d.liveLocation;
        charData.lastVerifiedCount = d.liveCount;
        charData.lastVerifiedTimestamp = GetTime();
        d.notesText = ""; 
        d.isStale = false; 
    end

    if d.locationText == AL.LOCATION_BAGS then d.colorR, d.colorG, d.colorB = GetItemQualityColor(charData_in.itemRarity or 1); d.colorA = 1.0;
    elseif d.locationText == AL.LOCATION_BANK then d.colorR, d.colorG, d.colorB, d.colorA = unpack(AL.COLOR_BANK_GOLD);
    elseif d.locationText == AL.LOCATION_MAIL then d.colorR, d.colorG, d.colorB, d.colorA = unpack(AL.COLOR_MAIL_TAN);
    elseif d.locationText == AL.LOCATION_AUCTION_HOUSE then d.colorR, d.colorG, d.colorB, d.colorA = unpack(AL.COLOR_AH_BLUE);
    elseif d.locationText == AL.LOCATION_WARBAND_BANK then d.colorR, d.colorG, d.colorB, d.colorA = unpack(AL.COLOR_WARBAND_BANK);
    elseif d.locationText == AL.LOCATION_REAGENT_BANK then d.colorR, d.colorG, d.colorB, d.colorA = unpack(AL.COLOR_REAGENT_BANK);
    elseif d.locationText == AL.LOCATION_LIMBO then d.colorR, d.colorG, d.colorB, d.colorA = unpack(AL.COLOR_LIMBO);
    else d.colorR, d.colorG, d.colorB = GetItemQualityColor(charData_in.itemRarity or 1); d.colorA = 1.0; end 

    if d.isStale and d.locationText ~= AL.LOCATION_LIMBO then
        d.colorR, d.colorG, d.colorB = d.colorR * AL.COLOR_STALE_MULTIPLIER, d.colorG * AL.COLOR_STALE_MULTIPLIER, d.colorB * AL.COLOR_STALE_MULTIPLIER;
    end
    
    return d;
end

function AL:ProcessAndStoreItem(itemLink)
    local charName = UnitName("player")
    local charRealm = GetRealmName()
    local success, resultOrMsg = self:InternalAddItem(itemLink, charName, charRealm)

    if success then
        self:SetReminderPopupFeedback(resultOrMsg, true)
        self:RefreshLedgerDisplay()
    else
        self:SetReminderPopupFeedback(resultOrMsg, false)
    end
end

function AL:AttemptAddAllEligibleItemsFromBags()
    local charName = UnitName("player")
    local charRealm = GetRealmName()
    local charKey = charName .. "-" .. charRealm
    local addedCount = 0
    local skippedAlreadyTracked = 0
    local skippedIneligible = 0

    local bagIDs = {}
    if C_Container and type(C_Container.GetBagIDs) == "function" then
        bagIDs = C_Container.GetBagIDs()
    else
        for i = 0, NUM_BAG_SLOTS do table.insert(bagIDs, i) end
        local reagentBagId = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or _G["REAGENT_BAG_INVENTORY_SLOT"]
        if reagentBagId then
            local alreadyExists = false
            for _, existingId in ipairs(bagIDs) do if existingId == reagentBagId then alreadyExists = true; break; end end
            if not alreadyExists then table.insert(bagIDs, reagentBagId) end
        end
    end

    for _, bagID in ipairs(bagIDs) do
        if bagID and type(bagID) == "number" then
            local numSlots = self:GetSafeContainerNumSlots(bagID)
            for slot = 1, numSlots do
                local itemLink = self:GetSafeContainerItemLink(bagID, slot)
                if itemLink then
                    local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slot)
                    local itemID = self:GetItemIDFromLink(itemLink)
                    
                    if itemID then
                        local isTracked = _G.AL_SavedData.Items[itemID] and _G.AL_SavedData.Items[itemID].characters[charKey]
                        if isTracked then skippedAlreadyTracked = skippedAlreadyTracked + 1
                        elseif not self:IsItemAuctionableByLocation(itemLocation) then skippedIneligible = skippedIneligible + 1
                        else
                            local success, _ = self:InternalAddItem(itemLink, charName, charRealm)
                            if success then addedCount = addedCount + 1
                            else skippedAlreadyTracked = skippedAlreadyTracked + 1 end
                        end
                    else
                        skippedIneligible = skippedIneligible + 1
                    end
                end
            end
        end
    end

    if addedCount > 0 then
        self:SetReminderPopupFeedback("Added " .. addedCount .. " new item(s).", true)
        self:BuildSalesCache()
        self:RefreshLedgerDisplay()
    else
        if skippedAlreadyTracked > 0 then
            self:SetReminderPopupFeedback("No new items found. " .. skippedAlreadyTracked .. " item(s) are already tracked.", false)
        else
            self:SetReminderPopupFeedback("No new auctionable items found in your bags.", false)
        end
    end
end

function AL:RemoveTrackedItem(itemIDToRemove, charNameToRemove, realmNameToRemove)
    local charKey = charNameToRemove .. "-" .. realmNameToRemove
    if _G.AL_SavedData.Items[itemIDToRemove] and _G.AL_SavedData.Items[itemIDToRemove].characters[charKey] then
        _G.AL_SavedData.Items[itemIDToRemove].characters[charKey] = nil
        
        if not next(_G.AL_SavedData.Items[itemIDToRemove].characters) then
            _G.AL_SavedData.Items[itemIDToRemove] = nil
        end
        self:BuildSalesCache()
        self:RefreshLedgerDisplay()
    end
end

function AL:RemoveAllInstancesOfItem(itemIDToRemove)
    if _G.AL_SavedData.Items[itemIDToRemove] then
        local itemName = _G.AL_SavedData.Items[itemIDToRemove].itemName or "Unknown Item"
        _G.AL_SavedData.Items[itemIDToRemove] = nil
        if _G.AL_SavedData.Settings.itemExpansionStates then
            _G.AL_SavedData.Settings.itemExpansionStates[itemIDToRemove] = nil
        end
        self:BuildSalesCache()
        self:RefreshLedgerDisplay()
    end
end
