-- CancelAuctions.lua
-- This file contains the logic for the "Cancel Undercut Auctions" feature.

AL = _G.AL or {}

AL.auctionsToCancel = {}
AL.isCancelScanning = false
AL.isCancelling = false
AL.cancelScanStatus = ""
AL.itemBeingCancelScanned = nil
AL.ownedAuctionsForScan = {}

-- A price cap to prevent errors from absurdly priced items.
local MAX_REASONABLE_PRICE = 2000000 * 10000 -- 2 million gold in copper

-- Re-uses the Blaster's status text frame to show progress updates.
function AL:UpdateCancelStatus(text, color)
    if AL.SetBlasterStatus then
        AL:SetBlasterStatus(text, color or {1, 1, 1, 1})
    else
        DEFAULT_CHAT_FRAME:AddMessage("AL Cancel Scan: " .. (text or ""))
    end
end

function AL:ProcessCancelScanResults(itemKey, eventName)
    if not self.itemBeingCancelScanned then return end

    local auctionToEvaluate = self.itemBeingCancelScanned
    self.itemBeingCancelScanned = nil

    AL:DebugPrint("---------------------------------")
    AL:DebugPrint(string.format("Processing cancel scan for: %s", auctionToEvaluate.itemLink))

    -- [[ BEGIN FIX: Differentiated Price Calculation ]]
    -- Determine if the item is a commodity based on the event that fired.
    local isCommodity = (eventName == "COMMODITY_SEARCH_RESULTS_UPDATED")
    
    -- Step 1: Get our own price from the specific auction we are evaluating.
    local myBuyout = auctionToEvaluate.buyoutAmount or 0
    if myBuyout <= 0 or myBuyout > MAX_REASONABLE_PRICE then
        AL:DebugPrint(string.format("  -> My auction's total buyout (%s) is invalid or over the safety limit. Skipping.", AL:FormatGoldWithIcons(myBuyout)))
        C_Timer.After(0.5, function() self:ScanNextAuctionForUndercut() end)
        return
    end

    -- For owned commodity auctions, buyoutAmount is per-item. For others, it's the total stack price.
    -- This ensures we are comparing apples to apples.
    local myPrice
    if isCommodity then
        myPrice = myBuyout
    else
        myPrice = math.floor(myBuyout / (auctionToEvaluate.quantity or 1))
    end
    -- [[ END FIX ]]

    AL:DebugPrint(string.format("  -> My Price Per Item: %s", AL:FormatGoldWithIcons(myPrice)))

    -- Step 2: Scan the market and build a list of all competitor prices.
    local numResults = isCommodity and C_AuctionHouse.GetNumCommoditySearchResults(itemKey.itemID) or C_AuctionHouse.GetNumItemSearchResults(itemKey)
    
    if numResults == 0 then
        AL:DebugPrint("  -> No other auctions found. Not undercut.")
        C_Timer.After(0.5, function() self:ScanNextAuctionForUndercut() end)
        return
    end

    local competitorPrices = {}
    local playerName = UnitName("player")

    for i = 1, numResults do
        local resultInfo = isCommodity and C_AuctionHouse.GetCommoditySearchResultInfo(itemKey.itemID, i) or C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
        if resultInfo then
            local isMyAuction = resultInfo.containsOwnerItem or (resultInfo.ownerName and resultInfo.ownerName == playerName)
            if not isMyAuction then
                local pricePerItemRaw = isCommodity and resultInfo.unitPrice or (resultInfo.buyoutAmount and resultInfo.buyoutAmount > 0 and resultInfo.quantity > 0 and (resultInfo.buyoutAmount / resultInfo.quantity))
                if pricePerItemRaw and pricePerItemRaw <= MAX_REASONABLE_PRICE then
                    table.insert(competitorPrices, math.floor(pricePerItemRaw))
                end
            end
        end
    end

    if #competitorPrices == 0 then
        AL:DebugPrint("  -> No competitor auctions found. Not undercut.")
        C_Timer.After(0.5, function() self:ScanNextAuctionForUndercut() end)
        return
    end

    -- Step 3: Find the absolute lowest price from our clean competitor list.
    local lowestCompetitorPrice = math.min(unpack(competitorPrices))
    AL:DebugPrint(string.format("  -> Lowest Competitor Price: %s", AL:FormatGoldWithIcons(lowestCompetitorPrice)))
    
    -- Step 4: Sanitize and compare prices to determine if undercut.
    local competitorPriceNum = tonumber(lowestCompetitorPrice)
    local myPriceNum = tonumber(myPrice)

    if competitorPriceNum and myPriceNum then
        local isUndercut = competitorPriceNum <= myPriceNum
        AL:DebugPrint(string.format("  -> Is Undercut or Matched? %s (%s <= %s)", tostring(isUndercut), tostring(competitorPriceNum), tostring(myPriceNum)))

        if isUndercut then
            table.insert(self.auctionsToCancel, auctionToEvaluate)
            AL:UpdateCancelStatus(string.format("Found undercut/matched auction for %s.", auctionToEvaluate.itemLink), {1, 0.8, 0, 1})
            AL:DebugPrint("  -> MARKED FOR CANCELLATION.")
        end
    else
        AL:DebugPrint("  -> ERROR: Could not compare prices due to an invalid number.")
    end

    C_Timer.After(0.5, function() self:ScanNextAuctionForUndercut() end)
end


-- Scans the next item in the owned auctions list.
function AL:ScanNextAuctionForUndercut()
    if #self.ownedAuctionsForScan == 0 then
        self.isCancelScanning = false
        AL:UpdateCancelStatus(string.format("Scan complete. Found %d undercut auctions.", #self.auctionsToCancel), AL.COLOR_PROFIT)
        
        local bw = AL.BlasterWindow
        if bw then
            bw.CancelUndercutButton:Enable()
            
            if #self.auctionsToCancel > 0 then
                bw.CancelUndercutButton:Hide()
                bw.CancelNextButton:SetText(string.format("Cancel Next (%d)", #self.auctionsToCancel))
                bw.CancelNextButton:Enable()
                bw.CancelNextButton:Show()
            else
                bw.CancelNextButton:Hide()
                bw.CancelUndercutButton:Show()
            end
        end
        return
    end

    if not C_AuctionHouse.IsThrottledMessageSystemReady() then
        AL:UpdateCancelStatus("Waiting for AH throttle...", {1, 0.8, 0, 1})
        C_Timer.After(2.0, function() self:ScanNextAuctionForUndercut() end)
        return
    end

    self.itemBeingCancelScanned = table.remove(self.ownedAuctionsForScan, 1)
    local itemToScan = self.itemBeingCancelScanned
    
    AL:UpdateCancelStatus(string.format("Scanning %s... (%d left)", itemToScan.itemLink, #self.ownedAuctionsForScan), {0.7, 0.7, 1, 1})

    local itemKey = itemToScan.itemKey
    local sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
    C_AuctionHouse.SendSearchQuery(itemKey, sorts, false)
end

-- Kicks off the scan of all owned auctions.
function AL:StartCancelScan()
    if self.isCancelScanning or self.isCancelling then return end

    if AL.BlasterWindow then
        AL.BlasterWindow.CancelUndercutButton:Disable()
        AL.BlasterWindow.CancelNextButton:Hide()
    end

    self:RegisterBlasterEvents() 

    self.isCancelScanning = true
    self.auctionsToCancel = {}
    
    local allOwnedAuctions = C_AuctionHouse.GetOwnedAuctions()
    self.ownedAuctionsForScan = {}
    if allOwnedAuctions then
        for _, auction in ipairs(allOwnedAuctions) do
            if not auction.buyoutAmount or auction.buyoutAmount <= MAX_REASONABLE_PRICE then
                table.insert(self.ownedAuctionsForScan, auction)
            else
                local itemName = auction.itemLink or (C_AuctionHouse.GetItemKeyInfo(auction.itemKey) and C_AuctionHouse.GetItemKeyInfo(auction.itemKey).name) or "Unknown Item"
                AL:DebugPrint(string.format("  -> Ignoring own auction for %s due to unreasonably high price (%s).", itemName, AL:FormatGoldWithIcons(auction.buyoutAmount)))
            end
        end
    end

    if not self.ownedAuctionsForScan or #self.ownedAuctionsForScan == 0 then
        AL:UpdateCancelStatus("You have no scannable auctions.", {1, 0.8, 0, 1})
        self.isCancelScanning = false
        if AL.BlasterWindow then AL.BlasterWindow.CancelUndercutButton:Enable() end
        return
    end

    for _, auction in ipairs(self.ownedAuctionsForScan) do
        if not auction.itemLink then
            local itemKeyInfo = C_AuctionHouse.GetItemKeyInfo(auction.itemKey)
            if itemKeyInfo and itemKeyInfo.itemLink then
                auction.itemLink = itemKeyInfo.itemLink
            else
                local _, link = GetItemInfo(auction.itemKey.itemID)
                auction.itemLink = link
            end
        end
    end

    AL:UpdateCancelStatus(string.format("Scanning %d auctions for undercuts...", #self.ownedAuctionsForScan))
    AL:DebugPrint(string.format("Cancel Scan Started: Found %d scannable owned auctions.", #self.ownedAuctionsForScan))
    self:ScanNextAuctionForUndercut()
end

-- [[ BEGIN REINFORCED LOGIC: CancelSingleUndercutAuction ]]
-- This function has been rewritten to be more robust. It uses an internal state flag
-- to prevent multiple clicks, handles potential API throttling, and uses safer timers
-- to ensure the UI remains responsive and stable during cancellations.
function AL:CancelSingleUndercutAuction()
    -- Add a check for the isCancelling flag to prevent re-entry
    if self.isCancelling or self.isCancelScanning or #self.auctionsToCancel == 0 then return end

    if not C_AuctionHouse.IsThrottledMessageSystemReady() then
        AL:UpdateCancelStatus("Waiting for AH throttle...", {1, 0.8, 0, 1})
        -- Re-enable the button after a delay so the user can try again
        C_Timer.After(2.0, function()
             if AL.BlasterWindow and AL.BlasterWindow.CancelNextButton then
                 AL.BlasterWindow.CancelNextButton:Enable()
             end
        end)
        return
    end

    self.isCancelling = true -- Set the flag to prevent spamming

    local bw = AL.BlasterWindow
    if bw and bw.CancelNextButton then
        bw.CancelNextButton:Disable()
    end

    -- Peek at the item without removing it yet, in case the cancellation fails.
    local auctionToCancel = self.auctionsToCancel[1]
    if not auctionToCancel or not auctionToCancel.auctionID then
        -- This handles if the table somehow contains a bad entry.
        table.remove(self.auctionsToCancel, 1) -- Remove the bad entry
        self.isCancelling = false -- Reset the flag
        AL:CancelSingleUndercutAuction() -- Try the next one immediately
        return
    end

    AL:UpdateCancelStatus(string.format("Cancelling %s...", auctionToCancel.itemLink), {0.7, 0.7, 1, 1})

    -- The actual API call to cancel the auction.
    C_AuctionHouse.CancelAuction(auctionToCancel.auctionID)

    -- Assume the API call was successful and remove the item from our queue.
    -- The game's OWNED_AUCTIONS_UPDATED event will eventually confirm the removal from the AH.
    table.remove(self.auctionsToCancel, 1)

    -- After the action, update the UI and prepare for the next potential action.
    if bw then
        if #self.auctionsToCancel > 0 then
            bw.CancelNextButton:SetText(string.format("Cancel Next (%d)", #self.auctionsToCancel))
            -- Using a timer to re-enable allows the AH UI to update and prevents API spam.
            C_Timer.After(1.5, function() -- Increased delay slightly for better stability
                if bw.CancelNextButton then bw.CancelNextButton:Enable() end
                self.isCancelling = false -- Reset the flag after the delay
            end)
        else
            -- All items in the cancel queue have been processed.
            bw.CancelNextButton:Hide()
            bw.CancelNextButton:Disable()
            bw.CancelUndercutButton:Show()
            bw.CancelUndercutButton:Enable()
            AL:UpdateCancelStatus("All undercut auctions have been cancelled.", AL.COLOR_PROFIT)
            self.isCancelling = false -- Reset the flag
        end
    else
        self.isCancelling = false -- Reset the flag if the window is gone
    end
end
-- [[ END REINFORCED LOGIC ]]
