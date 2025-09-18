-- Auctioneer's Ledger - Financial Tracker
-- This file contains all the secure hooks for tracking financial transactions

local AL = _G.AL or {}
_G.AL = AL

AL.recentlyViewedItems = {}
AL.pendingItem = nil
AL.pendingCost = nil
AL.isPrintingFromAddon = false

-- This function is now called only when a tooltip is shown, not every frame.
function AL:HandleTooltipShow()
    if GameTooltip:IsVisible() then
        local name, link = GameTooltip:GetItem()
        if name and link then
            -- Avoid adding the same item repeatedly if the tooltip flickers
            if #AL.recentlyViewedItems > 0 and AL.recentlyViewedItems[#AL.recentlyViewedItems].link == link then
                return
            end
            table.insert(AL.recentlyViewedItems, {name = name, link = link})
            -- Keep the cache from growing too large
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

function AL:BuildSalesCache()
    wipe(self.salesItemCache)
    wipe(self.salesPendingAuctionCache)
    if _G.AL_SavedData and _G.AL_SavedData.Items then
        for itemID, itemData in pairs(_G.AL_SavedData.Items) do
            if itemData and itemData.itemName then
                self.salesItemCache[itemData.itemName] = { itemID = tonumber(itemID), itemLink = itemData.itemLink }
            end
        end
    end
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    local pendingAuctions = _G.AL_SavedData.PendingAuctions and _G.AL_SavedData.PendingAuctions[charKey]
    if pendingAuctions then
        for i, auctionData in ipairs(pendingAuctions) do
            local itemID = self:GetItemIDFromLink(auctionData.itemLink)
            if itemID then
                if not self.salesPendingAuctionCache[itemID] then
                    self.salesPendingAuctionCache[itemID] = {}
                end
                table.insert(self.salesPendingAuctionCache[itemID], { originalIndex = i, data = auctionData })
            end
        end
    end
end

-- [[ DIRECTIVE: Mail Lag Fix ]]
-- This new function combines the logic of UpdateMailCache and ProcessInboxForSales.
-- It loops through the inbox only ONCE to perform both actions, significantly improving performance.
function AL:ProcessMailboxUpdate()
    -- Part 1: Update Mail Cache (formerly UpdateMailCache)
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    if not _G.AL_SavedData.MailCache then _G.AL_SavedData.MailCache = {} end
    
    local mailCounts = {}
    local numMailItems = GetInboxNumItems and GetInboxNumItems() or 0
    
    if numMailItems > 0 then
        for i = 1, numMailItems do
            if select(8, GetInboxHeaderInfo(i)) then -- hasItem
                for j = 1, AL.MAX_MAIL_ATTACHMENTS_TO_SCAN do
                    local link = GetInboxItemLink(i, j)
                    if link then
                        local itemID = AL:GetItemIDFromLink(link)
                        if itemID and _G.AL_SavedData.Items[itemID] then
                            local _, _, _, itemCount = GetInboxItem(i, j)
                            mailCounts[itemID] = (mailCounts[itemID] or 0) + (itemCount or 0)
                        end
                    else
                        break
                    end
                end
            end
        end
    end
    _G.AL_SavedData.MailCache[charKey] = mailCounts
    
    -- Part 2: Process Sales (formerly ProcessInboxForSales)
    self:BuildSalesCache()

    if numMailItems == 0 then return end
    
    local pendingAuctions = _G.AL_SavedData.PendingAuctions and _G.AL_SavedData.PendingAuctions[charKey]
    local itemsByName = self.salesItemCache
    local pendingByID = self.salesPendingAuctionCache
    local didUpdate = false
    local indicesToRemove = {}

    for i = 1, numMailItems do
        local _, _, sender, subject, money, _, _, _, _, _, textCreated = GetInboxHeaderInfo(i)
        local invoiceType, itemNameFromInvoice = GetInboxInvoiceInfo(i)
        local mailKey = sender .. subject .. tostring(money) .. tostring(textCreated or 0) .. tostring(itemNameFromInvoice or "")
        
        if _G.AuctioneersLedgerFinances and _G.AuctioneersLedgerFinances.processedMailIDs and not _G.AuctioneersLedgerFinances.processedMailIDs[mailKey] and invoiceType == "seller" and money > 0 then
            if itemNameFromInvoice then
                local itemName = itemNameFromInvoice:gsub("%s+$", "")
                
                local itemInfo = itemsByName[itemName]
                if itemInfo then
                    local itemID = itemInfo.itemID
                    local originalValue = math.floor((money / 0.95) + 0.5)
                    local matchedIndex, bestMatchArrayIndex = nil, nil
                    local candidates = pendingByID and pendingByID[itemID]
                    
                    if candidates and #candidates > 0 then
                        local smallestDiff = math.huge
                        for c_idx, candidate in ipairs(candidates) do
                            if candidate and candidate.data and candidate.data.totalValue then
                                local diff = math.abs(candidate.data.totalValue - originalValue)
                                if diff < smallestDiff then
                                    smallestDiff, matchedIndex, bestMatchArrayIndex = diff, candidate.originalIndex, c_idx
                                end
                            end
                        end
                        if smallestDiff > 1 then
                            matchedIndex = nil 
                        end
                    end

                    local quantity, itemLink, soldAuctionData
                    if matchedIndex then
                        soldAuctionData = pendingAuctions and pendingAuctions[matchedIndex]
                        if soldAuctionData then
                            quantity = soldAuctionData.quantity
                            itemLink = soldAuctionData.itemLink
                        end
                    end

                    if not quantity then
                        local qtyFromSubject = subject and tonumber(string.match(subject, "%((%d+)%)"))
                        if qtyFromSubject then
                            quantity = qtyFromSubject
                        else
                            quantity = 1
                        end
                    end
                    
                    if not itemLink then
                        itemLink = itemInfo.itemLink
                    end

                    local depositFee = 0
                    if matchedIndex and pendingAuctions and pendingAuctions[matchedIndex] then
                        local matchedAuctionData = pendingAuctions[matchedIndex]
                        if matchedAuctionData and matchedAuctionData.depositFee then
                            depositFee = matchedAuctionData.depositFee
                        end
                    end

                    self:RecordTransaction("SELL", "AUCTION", itemID, money, quantity)
                    self:AddToHistory("sales", { itemLink = itemLink, itemName = itemName, quantity = quantity, price = money, depositFee = depositFee, totalValue = originalValue, timestamp = time() })
                    
                    _G.AuctioneersLedgerFinances.processedMailIDs[mailKey] = true
                    didUpdate = true

                    if matchedIndex then
                        table.insert(indicesToRemove, matchedIndex)
                        if bestMatchArrayIndex and candidates then
                            table.remove(candidates, bestMatchArrayIndex)
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
    end

    if didUpdate and self.BlasterWindow and self.BlasterWindow:IsShown() then
        self:RefreshBlasterHistory()
    end
end

function AL:InitializeCoreHooks()
    if self.coreHooksInitialized then return end
    hooksecurefunc(ChatFrame1, "AddMessage", function(...) AL:HandlePurchaseMessage(...) end)
    
    -- PERFORMANCE FIX: Replaced the OnUpdate script with a more efficient OnShow hook.
    -- This captures the same item data from tooltips but only runs when a tooltip appears, not every frame.
    GameTooltip:HookScript("OnShow", function() AL:HandleTooltipShow() end)

    hooksecurefunc("TakeInboxItem", function(mailIndex, attachmentIndex)
        local itemLink = GetInboxItemLink(mailIndex, attachmentIndex)
        if not itemLink then return end
        
        local itemID = AL:GetItemIDFromLink(itemLink)
        if not itemID then return end
        
        -- [[ DIRECTIVE: Mail Persistence ]]
        -- Update the new MailCache when an item is taken.
        local charKey = UnitName("player") .. "-" .. GetRealmName()
        if _G.AL_SavedData.MailCache and _G.AL_SavedData.MailCache[charKey] and _G.AL_SavedData.MailCache[charKey][itemID] then
            local _, _, _, itemCount = GetInboxItem(mailIndex, attachmentIndex)
            _G.AL_SavedData.MailCache[charKey][itemID] = math.max(0, _G.AL_SavedData.MailCache[charKey][itemID] - (itemCount or 0))
            if _G.AL_SavedData.MailCache[charKey][itemID] == 0 then
                _G.AL_SavedData.MailCache[charKey][itemID] = nil
            end
        end

        local _, _, _, subject = GetInboxHeaderInfo(mailIndex)
        if subject and (subject:find("expired") or subject:find("Expired")) then
            local _, _, itemCount = GetInboxItem(mailIndex, attachmentIndex)
            if itemCount then
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
        -- [[ DIRECTIVE: Reactive Refresh ]]
        -- Trigger a refresh after taking an item to update the UI immediately.
        AL:TriggerDebouncedRefresh("MAIL_ITEM_TAKEN")
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
            
            -- [[ DIRECTIVE: Mail Persistence ]]
            -- Flag the item as being in transit by adding it to the MailCache.
            local charKey = UnitName("player") .. "-" .. GetRealmName()
            if not _G.AL_SavedData.MailCache then _G.AL_SavedData.MailCache = {} end
            if not _G.AL_SavedData.MailCache[charKey] then _G.AL_SavedData.MailCache[charKey] = {} end

            _G.AL_SavedData.MailCache[charKey][cachedInfo.itemID] = (_G.AL_SavedData.MailCache[charKey][cachedInfo.itemID] or 0) + cachedInfo.quantity

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
            -- [[ NEW: Check setting before showing popup ]]
            if _G.AL_SavedData and _G.AL_SavedData.Settings and _G.AL_SavedData.Settings.autoAddNewItems then
                -- Bypass popup and add automatically
                local success, msg = AL:InternalAddItem(itemLink, UnitName("player"), GetRealmName())
                if success then
                    -- Now that the item is tracked, record the transaction that triggered this.
                    AL:RecordTransaction("BUY", "VENDOR", itemID, price, quantity)
                    AL:RefreshLedgerDisplay()
                end
            else
                -- Show confirmation popup
                local name = GetItemInfo(itemLink)
                if not name then return end
                local popupData = { itemLink = itemLink, itemID = itemID, price = price, quantity = quantity }
                StaticPopup_Show("AL_CONFIRM_TRACK_NEW_VENDOR_PURCHASE", name, nil, popupData)
            end
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

