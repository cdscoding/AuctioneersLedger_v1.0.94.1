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
        showWelcomeWindowOnLogin = true, -- [[ DIRECTIVE: Add setting for welcome window ]]
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
    if type(_G.AL_SavedData.WarbandCache) ~= "table" then _G.AL_SavedData.WarbandCache = {} end
    if type(_G.AL_SavedData.AuctionCache) ~= "table" then _G.AL_SavedData.AuctionCache = {} end
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
        awaitingMailCount = 0, -- [[ DIRECTIVE: Mail Persistence ]]
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
    return nil
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

-- [[ DIRECTIVE: Multi-Location Tracking ]]
-- This function replaces the old GetItemOwnershipDetails. It scans all possible locations for an item
-- and returns a table of details, one for each location where the item is found.
function AL:GetAllItemOwnershipDetails(charData_in)
    local allDetails = {}
    if not charData_in or not charData_in.characterName then return {} end

    local itemID = self:GetItemIDFromLink(charData_in.itemLink)
    if not itemID then return {} end

    local charKey = charData_in.characterName .. "-" .. charData_in.characterRealm
    local charData = _G.AL_SavedData.Items[itemID] and _G.AL_SavedData.Items[itemID].characters[charKey]
    if not charData then return {} end

    local isCurrentCharacter = (charData_in.characterName == UnitName("player") and charData_in.characterRealm == GetRealmName())

    local function addDetail(location, count, isStale, notes)
        local d = {
            liveLocation = isStale and nil or location,
            liveCount = count,
            locationText = location,
            colorR, colorG, colorB, colorA = 1, 1, 1, 1,
            displayText = string.format("%02d", count),
            notesText = notes or "",
            isStale = isStale,
            isLink = (location == AL.LOCATION_BAGS)
        }

        if location == AL.LOCATION_BAGS then d.colorR, d.colorG, d.colorB, d.colorA = GetItemQualityColor(charData_in.itemRarity or 1)
        elseif location == AL.LOCATION_BANK then d.colorR, d.colorG, d.colorB, d.colorA = unpack(AL.COLOR_BANK_GOLD)
        elseif location == AL.LOCATION_MAIL then d.colorR, d.colorG, d.colorB, d.colorA = unpack(AL.COLOR_MAIL_TAN)
        elseif location == AL.LOCATION_AUCTION_HOUSE then d.colorR, d.colorG, d.colorB, d.colorA = unpack(AL.COLOR_AH_BLUE)
        elseif location == AL.LOCATION_WARBAND_BANK then d.colorR, d.colorG, d.colorB, d.colorA = unpack(AL.COLOR_WARBAND_BANK)
        elseif location == AL.LOCATION_REAGENT_BANK then d.colorR, d.colorG, d.colorB, d.colorA = unpack(AL.COLOR_REAGENT_BANK)
        else d.colorR, d.colorG, d.colorB, d.colorA = unpack(AL.COLOR_LIMBO) end

        if isStale then
            d.colorR, d.colorG, d.colorB = d.colorR * AL.COLOR_STALE_MULTIPLIER, d.colorG * AL.COLOR_STALE_MULTIPLIER, d.colorB * AL.COLOR_STALE_MULTIPLIER
        end

        table.insert(allDetails, d)
    end

    if isCurrentCharacter then
        local bagsOnlyCount = C_Item.GetItemCount(itemID, false, false, false)
        if bagsOnlyCount > 0 then addDetail(AL.LOCATION_BAGS, bagsOnlyCount, false) end

        local totalInBagsAndReagent = C_Item.GetItemCount(itemID, false, false, true)
        local reagentBankOnlyCount = totalInBagsAndReagent - bagsOnlyCount
        if reagentBankOnlyCount > 0 then addDetail(AL.LOCATION_REAGENT_BANK, reagentBankOnlyCount, false) end

        local totalInBagsBankAndReagent = C_Item.GetItemCount(itemID, true, false, true)
        local bankOnlyCount = totalInBagsBankAndReagent - totalInBagsAndReagent
        if bankOnlyCount > 0 then addDetail(AL.LOCATION_BANK, bankOnlyCount, false) end
        
        local isMailOpen = MailFrame and MailFrame:IsShown()
        if isMailOpen and GetInboxNumItems then
            local mailCount = 0
            for i = 1, GetInboxNumItems() do
                if select(8, GetInboxHeaderInfo(i)) then -- hasItem
                    for j = 1, AL.MAX_MAIL_ATTACHMENTS_TO_SCAN do
                        local link = GetInboxItemLink(i, j)
                        if link and self:GetItemIDFromLink(link) == itemID then
                            mailCount = mailCount + (select(4, GetInboxItem(i, j)) or 0)
                        elseif not link then
                            break
                        end
                    end
                end
            end
            if mailCount > 0 then
                addDetail(AL.LOCATION_MAIL, mailCount, false)
                charData.awaitingMailCount = 0 -- Live scan confirms mail contents
            end
        end
    end

    local isWarbandBankViewable = C_Bank.CanViewBank(Enum.BankType.Account)
    if isWarbandBankViewable then
        _G.AL_SavedData.WarbandCache[itemID] = nil
        local warbandCount = 0
        if Enum and Enum.BagIndex then
            for i = 1, AL.MAX_WARBAND_BANK_TABS_TO_CHECK do
                local bagID = _G["WARBAND_BANK_TAB_"..i.."_BAG_INDEX"] or (Enum.BagIndex["AccountBankTab_"..i])
                if bagID then
                    for slot = 1, self:GetSafeContainerNumSlots(bagID) do
                        local link = self:GetSafeContainerItemLink(bagID, slot)
                        if link and self:GetItemIDFromLink(link) == itemID then
                            local itemInfo = self:GetSafeContainerItemInfo(bagID, slot)
                            if itemInfo and itemInfo.stackCount then
                                warbandCount = warbandCount + itemInfo.stackCount
                            end
                        end
                    end
                end
            end
        end
        if warbandCount > 0 then
            _G.AL_SavedData.WarbandCache[itemID] = warbandCount
            addDetail(AL.LOCATION_WARBAND_BANK, warbandCount, false)
        end
    else
        local cachedCount = _G.AL_SavedData.WarbandCache[itemID]
        if cachedCount and cachedCount > 0 then
            addDetail(AL.LOCATION_WARBAND_BANK, cachedCount, true, "Warband Bank (Stale)")
        end
    end
    
    local ahCachedCount = _G.AL_SavedData.AuctionCache and _G.AL_SavedData.AuctionCache[itemID]
    if ahCachedCount and ahCachedCount > 0 then
        local isAHOpen = AuctionHouseFrame and AuctionHouseFrame:IsShown()
        addDetail(AL.LOCATION_AUCTION_HOUSE, ahCachedCount, not isAHOpen, not isAHOpen and "Being auctioned." or nil)
    end

    -- [[ DIRECTIVE: Mail Persistence ]]
    if charData.awaitingMailCount and charData.awaitingMailCount > 0 then
        addDetail(AL.LOCATION_MAIL, charData.awaitingMailCount, true, "In transit to mailbox.")
    end

    if #allDetails == 0 then
        addDetail(AL.LOCATION_LIMBO, 0, false)
    end
    
    return allDetails
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
