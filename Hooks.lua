-- Auctioneer's Ledger - Financial Tracker
-- This file contains all the secure hooks for tracking financial transactions

local AL = _G.AL or {}
_G.AL = AL

AL.recentlyViewedItems = {}
AL.pendingItem = nil
AL.pendingCost = nil
AL.isPrintingFromAddon = false

function AL:HandleOnUpdate(frame, elapsed)
    if GameTooltip:IsVisible() then
        local name, link = GameTooltip:GetItem()
        if name and link then
            if #AL.recentlyViewedItems > 0 and AL.recentlyViewedItems[#AL.recentlyViewedItems].name == name then
                return
            end
            table.insert(AL.recentlyViewedItems, {name = name, link = link})
            if #AL.recentlyViewedItems > 20 then
                table.remove(AL.recentlyViewedItems, 1)
            end
        end
    end
end

function AL:FinalizeAndPrintPurchase(itemName, quantity, moneySpent, purchaseDate)
    local foundLink = nil
    for i = #AL.recentlyViewedItems, 1, -1 do
        local cachedItem = AL.recentlyViewedItems[i]
        if cachedItem.name == itemName then
            foundLink = cachedItem.link
            break
        end
    end

    if not foundLink then
        -- This can be kept as a non-intrusive debug message for edge cases.
        AL:DebugPrint("Item '" .. itemName .. "' not found in tooltip cache. Recording by name only.")
    end

    AL:ProcessPurchase(itemName, foundLink, quantity, moneySpent)

    if foundLink then
        AL.recentlyViewedItems = {}
    end
end

function AL:TryToMatchEvents()
    if not AL.pendingItem or not AL.pendingCost then return end

    if math.abs(AL.pendingItem.time - AL.pendingCost.time) < 2.5 then
        AL:FinalizeAndPrintPurchase(
            AL.pendingItem.name,
            AL.pendingItem.quantity,
            AL.pendingCost.cost,
            AL.pendingItem.date
        )
        
        AL.pendingItem = nil
        AL.pendingCost = nil
    end
end

function AL:HandlePurchaseMessage(chatFrame, message, ...)
    if AL.isPrintingFromAddon then return end

    if message and string.find(message, "You won an auction for") then
        local itemName
        
        local itemLinkInMsg = string.match(message, "(|Hitem.-|h%[.-%]|h)")
        if itemLinkInMsg then
            itemName = string.match(itemLinkInMsg, "%[(.-)%]")
        else
            itemName = string.match(message, "You won an auction for ([^%(]+)")
        end

        if itemName then
            itemName = itemName:gsub("%s+$", "")
            
            AL.pendingItem = {
                name = itemName,
                quantity = tonumber(string.match(message, "%(x(%d+)%)") or "1"),
                date = date("%m/%d/%Y %H:%M"),
                time = GetTime()
            }
            AL:TryToMatchEvents()
        end
    end
end

AL.processedMailIDs = {}

function AL:BuildSalesCache()
    wipe(self.salesItemCache)
    wipe(self.salesPendingAuctionCache)
    if _G.AL_SavedData and _G.AL_SavedData.Items then
        for itemID, itemData in pairs(_G.AL_SavedData.Items) do
            if itemData and itemData.itemName then
                self.salesItemCache[itemData.itemName] = { itemID = itemID, itemLink = itemData.itemLink }
            end
        end
    end
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    local pendingAuctions = _G.AL_SavedData.PendingAuctions and _G.AL_SavedData.PendingAuctions[charKey]
    if pendingAuctions then
        for i, auctionData in ipairs(pendingAuctions) do
            local success, name = pcall(GetItemInfo, auctionData.itemLink)
            if success and name then
                if not self.salesPendingAuctionCache[name] then
                    self.salesPendingAuctionCache[name] = {}
                end
                table.insert(self.salesPendingAuctionCache[name], { originalIndex = i, data = auctionData })
            end
        end
    end
end

function AL:ProcessInboxForSales()
    local numItems = GetInboxNumItems()
    if numItems == 0 then return end
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    local pendingAuctions = _G.AL_SavedData.PendingAuctions and _G.AL_SavedData.PendingAuctions[charKey]
    local itemsByName = self.salesItemCache
    local pendingByName = self.salesPendingAuctionCache
    local didUpdate = false
    local indicesToRemove = {}

    for i = 1, numItems do
        local _, _, sender, subject, money, _, _, _, _, _, isInvoice = GetInboxHeaderInfo(i)
        local mailKey = sender .. subject .. tostring(money) .. tostring(i)
        if not AL.processedMailIDs[mailKey] and isInvoice and money > 0 then
            local invoiceType, itemName = GetInboxInvoiceInfo(i)
            if invoiceType == "seller" and itemName then
                local quantityFromSubject = subject and tonumber(string.match(subject, "%(x(%d+)%)"))
                if quantityFromSubject then
                    local itemInfo = itemsByName and itemsByName[itemName]
                    if itemInfo then
                        self:RecordTransaction("SELL", "AUCTION", itemInfo.itemID, money, quantityFromSubject)
                        self:AddToHistory("sales", { itemLink = itemInfo.itemLink, itemName = itemName, quantity = quantityFromSubject, price = money, totalValue = money / 0.95, timestamp = time() })
                        if pendingByName and pendingByName[itemName] then
                            local quantityToClear = quantityFromSubject
                            local pendingForThisItem = pendingByName[itemName]
                            table.sort(pendingForThisItem, function(a, b) return a.data.postTime < b.data.postTime end)
                            local tempCacheIndicesToRemove = {}
                            for p_idx = #pendingForThisItem, 1, -1 do
                                if quantityToClear > 0 then
                                    local pendingEntry = pendingForThisItem[p_idx]
                                    table.insert(indicesToRemove, pendingEntry.originalIndex)
                                    table.insert(tempCacheIndicesToRemove, p_idx)
                                    quantityToClear = quantityToClear - pendingEntry.data.quantity
                                end
                            end
                            for _, p_idx_to_remove in ipairs(tempCacheIndicesToRemove) do
                                table.remove(pendingForThisItem, p_idx_to_remove)
                            end
                        end
                        AL.processedMailIDs[mailKey] = true
                        didUpdate = true
                    end
                else
                    local originalValue = math.floor((money / 0.95) + 0.5)
                    local matchedIndex = nil
                    if pendingByName and pendingByName[itemName] then
                        local candidates = pendingByName[itemName]
                        local bestMatchArrayIndex, smallestDiff = nil, math.huge
                        for c_idx, candidate in ipairs(candidates) do
                            if candidate and candidate.data and candidate.data.totalValue then
                                local diff = math.abs(candidate.data.totalValue - originalValue)
                                if diff < smallestDiff then
                                    smallestDiff, matchedIndex, bestMatchArrayIndex = diff, candidate.originalIndex, c_idx
                                end
                            end
                        end
                        if bestMatchArrayIndex then table.remove(candidates, bestMatchArrayIndex) end
                    end
                    if matchedIndex then
                        local soldAuctionData = pendingAuctions and pendingAuctions[matchedIndex]
                        if soldAuctionData then
                            local itemID = self:GetItemIDFromLink(soldAuctionData.itemLink)
                            self:RecordTransaction("SELL", "AUCTION", itemID, money, soldAuctionData.quantity)
                            self:AddToHistory("sales", { itemLink = soldAuctionData.itemLink, itemName = itemName, quantity = soldAuctionData.quantity, price = money, totalValue = originalValue, timestamp = time() })
                            AL.processedMailIDs[mailKey] = true
                            didUpdate = true
                            table.insert(indicesToRemove, matchedIndex)
                        end
                    else
                        local fallbackItem = itemsByName and itemsByName[itemName]
                        if fallbackItem then
                            self:RecordTransaction("SELL", "AUCTION", fallbackItem.itemID, money, 1)
                            self:AddToHistory("sales", { itemLink = fallbackItem.itemLink, itemName = itemName, quantity = 1, price = money, totalValue = originalValue, timestamp = time() })
                            AL.processedMailIDs[mailKey] = true
                            didUpdate = true
                        end
                    end
                end
            end
        end
    end

    if #indicesToRemove > 0 then
        table.sort(indicesToRemove, function(a, b) return a > b end)
        if pendingAuctions then
            for _, index in ipairs(indicesToRemove) do
                table.remove(pendingAuctions, index)
            end
        end
        self:BuildSalesCache()
    end

    if didUpdate and self.BlasterWindow and self.BlasterWindow:IsShown() then
        self:RefreshBlasterHistory()
    end
end

function AL:InitializeCoreHooks()
    if self.coreHooksInitialized then return end
    hooksecurefunc(ChatFrame1, "AddMessage", function(...) AL:HandlePurchaseMessage(...) end)
    local eventHandler = _G["AL_EventHandler_v" .. AL.VERSION:gsub("%.","_")]
    if eventHandler then
        eventHandler:SetScript("OnUpdate", function(...) AL:HandleOnUpdate(...) end)
    end
    hooksecurefunc("TakeInboxItem", function(mailIndex, attachmentIndex)
        local _, _, _, subject = GetInboxHeaderInfo(mailIndex)
        if subject and (subject:find("expired") or subject:find("Expired")) then
            local itemLink = GetInboxItemLink(mailIndex, attachmentIndex)
            if itemLink then
                local itemID = self:GetItemIDFromLink(itemLink)
                local _, _, itemCount = GetInboxItem(mailIndex, attachmentIndex)
                if itemID and itemCount then
                    local charKey = UnitName("player") .. "-" .. GetRealmName()
                    local pendingAuctions = _G.AL_SavedData.PendingAuctions and _G.AL_SavedData.PendingAuctions[charKey]
                    if pendingAuctions then
                         for idx = #pendingAuctions, 1, -1 do
                            local auctionData = pendingAuctions[idx]
                            if self:GetItemIDFromLink(auctionData.itemLink) == itemID and auctionData.quantity == itemCount then
                                local removedAuction = table.remove(pendingAuctions, idx)
                                local reliableItemLink = removedAuction.itemLink
                                local itemName = reliableItemLink and GetItemInfo(reliableItemLink)
                                self:RecordTransaction("DEPOSIT", "AUCTION", itemID, removedAuction.depositFee or 0, removedAuction.quantity)
                                self:AddToHistory("cancellations", { itemName = itemName or "Unknown", itemLink = reliableItemLink, quantity = removedAuction.quantity, price = removedAuction.depositFee or 0, timestamp = time() })
                                self:RefreshBlasterHistory()
                                self:BuildSalesCache()
                                break
                            end
                        end
                    end
                end
            end
        end
    end)
    self.coreHooksInitialized = true
end

function AL:InitializeAuctionHooks()
    if self.auctionHooksInitialized then return end
    local function cachePendingPost(itemLocation, quantity, duration, postPrice, isCommodity)
        if not itemLocation or not itemLocation:IsValid() then return end
        local itemID, itemLink = C_Container.GetContainerItemID(itemLocation:GetBagAndSlot()), C_Container.GetContainerItemLink(itemLocation:GetBagAndSlot())
        if itemID and itemLink then
            local depositFee = isCommodity and C_AuctionHouse.CalculateCommodityDeposit(itemID, duration, quantity) or C_AuctionHouse.CalculateItemDeposit(itemLocation, duration, quantity)
            AL.pendingPostDetails = { itemID = itemID, itemLink = itemLink, quantity = quantity or 1, duration = duration, postPrice = postPrice, depositFee = depositFee }
            AL:RecordTransaction("DEPOSIT", "AUCTION", itemID, depositFee, quantity)
        end
    end
    if C_AuctionHouse and C_AuctionHouse.PostItem then
        hooksecurefunc(C_AuctionHouse, "PostItem", function(itemLocation, duration, quantity, bid, buyout)
            local pricePer = buyout and buyout > 0 and quantity > 0 and (buyout / quantity) or 0
            cachePendingPost(itemLocation, quantity, duration, pricePer, false)
        end)
    end
    if C_AuctionHouse and C_AuctionHouse.PostCommodity then
        hooksecurefunc(C_AuctionHouse, "PostCommodity", function(itemLocation, duration, quantity, unitPrice)
            cachePendingPost(itemLocation, quantity, duration, unitPrice, true)
        end)
    end
    if C_AuctionHouse and C_AuctionHouse.CancelAuction then
        hooksecurefunc(C_AuctionHouse, "CancelAuction", function(auctionID)
            if not auctionID then return end
            local cachedInfo = AL.auctionIDCache and AL.auctionIDCache[auctionID]
            if not cachedInfo or not cachedInfo.itemID then return end
            local charKey = UnitName("player") .. "-" .. GetRealmName()
            local pendingAuctions = _G.AL_SavedData.PendingAuctions and _G.AL_SavedData.PendingAuctions[charKey]
            if pendingAuctions then
                for idx = #pendingAuctions, 1, -1 do
                    local auctionData = pendingAuctions[idx]
                    local pendingItemID = self:GetItemIDFromLink(auctionData.itemLink)
                    if pendingItemID and pendingItemID == cachedInfo.itemID and auctionData.quantity == cachedInfo.quantity then
                        local removedAuction = table.remove(pendingAuctions, idx)
                        local reliableItemLink = removedAuction.itemLink
                        local itemName = reliableItemLink and GetItemInfo(reliableItemLink)
                        self:RecordTransaction("DEPOSIT", "AUCTION", pendingItemID, removedAuction.depositFee or 0, removedAuction.quantity)
                        self:AddToHistory("cancellations", { itemName = itemName or "Unknown", itemLink = reliableItemLink, quantity = removedAuction.quantity, price = removedAuction.depositFee or 0, timestamp = time() })
                        self:RefreshBlasterHistory()
                        self:BuildSalesCache()
                        break 
                    end
                end
            end
        end)
    end
    self.auctionHooksInitialized = true
end

function AL:InitializeVendorHooks()
    if self.vendorHooksInitialized then return end

    local function handleVendorPurchase(itemLink, itemID, price, quantity)
        if not itemLink or not itemID or not price or price <= 0 or not quantity or quantity <= 0 then
            return
        end
        
        local charKey = UnitName("player") .. "-" .. GetRealmName()
        local isTracked = _G.AL_SavedData.Items and _G.AL_SavedData.Items[itemID] and _G.AL_SavedData.Items[itemID].characters[charKey]
        
        if isTracked then
            AL:RecordTransaction("BUY", "VENDOR", itemID, price, quantity)
        else
            local name = GetItemInfo(itemLink)
            if not name then return end

            local popupData = { itemLink = itemLink, itemID = itemID, price = price, quantity = quantity }
            StaticPopup_Show("AL_CONFIRM_TRACK_NEW_VENDOR_PURCHASE", name, nil, popupData)
        end
    end

    hooksecurefunc("BuyMerchantItem", function(index, quantity)
        if not index then return end
        
        local itemLink = GetMerchantItemLink(index)
        if not itemLink then return end
        
        local itemID = AL:GetItemIDFromLink(itemLink)
        local _, _, price, numInStack = GetMerchantItemInfo(index)

        if itemID and price and price > 0 then
            local itemsToBuy = quantity or 1
            local stackSize = numInStack or 1
            
            local pricePerItem = price
            if stackSize > 1 then
                pricePerItem = price / stackSize
            end

            local totalPrice = math.floor(pricePerItem * itemsToBuy)
            handleVendorPurchase(itemLink, itemID, totalPrice, itemsToBuy)
        end
    end)
    
    hooksecurefunc("BuybackItem", function(index)
        if not index then return end

        local itemLink = GetBuybackItemLink(index)
        if not itemLink then return end

        local itemID = AL:GetItemIDFromLink(itemLink)
        local _, _, price, stackSize = GetBuybackItemInfo(index)
        
        if itemID and price and price > 0 then
            local totalItems = stackSize or 1
            local totalPrice = price
            handleVendorPurchase(itemLink, itemID, totalPrice, totalItems)
        end
    end)

    hooksecurefunc(C_Container, "UseContainerItem", function(bag, slot)
        if not MerchantFrame or not MerchantFrame:IsShown() then return end
        
        local itemLink = C_Container.GetContainerItemLink(bag, slot)
        if not itemLink then return end
        
        local sellPrice = select(11, GetItemInfo(itemLink))
        if sellPrice and sellPrice > 0 then
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            local itemCount = itemInfo and itemInfo.stackCount or 1
            local totalPrice = sellPrice * itemCount
            local itemID = AL:GetItemIDFromLink(itemLink)
            
            if itemID then 
                AL:RecordTransaction("SELL", "VENDOR", itemID, totalPrice, itemCount) 
            end
        end
    end)
    
    self.vendorHooksInitialized = true
end

function AL:InitializeTradeHooks()
    -- Trade hooks are not relevant to this financial restructure.
end

function AL:GetItemIDFromLink(itemLink)
    if not itemLink then return nil end
    return tonumber(itemLink:match("item:(%d+)"))
end
