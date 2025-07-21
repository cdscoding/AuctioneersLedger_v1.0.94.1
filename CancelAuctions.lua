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

    local isCommodity = (eventName == "COMMODITY_SEARCH_RESULTS_UPDATED")
    
    local myBuyout = auctionToEvaluate.buyoutAmount or 0
    if myBuyout <= 0 or myBuyout > MAX_REASONABLE_PRICE then
        C_Timer.After(0.5, function() self:ScanNextAuctionForUndercut() end)
        return
    end

    local myPrice
    if isCommodity then
        myPrice = myBuyout
    else
        myPrice = math.floor(myBuyout / (auctionToEvaluate.quantity or 1))
    end

    local numResults = isCommodity and C_AuctionHouse.GetNumCommoditySearchResults(itemKey.itemID) or C_AuctionHouse.GetNumItemSearchResults(itemKey)
    
    if numResults == 0 then
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
        C_Timer.After(0.5, function() self:ScanNextAuctionForUndercut() end)
        return
    end

    local lowestCompetitorPrice = math.min(unpack(competitorPrices))
    
    local competitorPriceNum = tonumber(lowestCompetitorPrice)
    local myPriceNum = tonumber(myPrice)

    if competitorPriceNum and myPriceNum then
        local isUndercut = competitorPriceNum <= myPriceNum
        if isUndercut then
            table.insert(self.auctionsToCancel, auctionToEvaluate)
            AL:UpdateCancelStatus(string.format("Found undercut/matched auction for %s.", auctionToEvaluate.itemLink), {1, 0.8, 0, 1})
        end
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
    self:ScanNextAuctionForUndercut()
end

function AL:CancelSingleUndercutAuction()
    if self.isCancelling or self.isCancelScanning or #self.auctionsToCancel == 0 then return end

    if not C_AuctionHouse.IsThrottledMessageSystemReady() then
        AL:UpdateCancelStatus("Waiting for AH throttle...", {1, 0.8, 0, 1})
        C_Timer.After(2.0, function()
             if AL.BlasterWindow and AL.BlasterWindow.CancelNextButton then
                 AL.BlasterWindow.CancelNextButton:Enable()
             end
        end)
        return
    end

    self.isCancelling = true

    local bw = AL.BlasterWindow
    if bw and bw.CancelNextButton then
        bw.CancelNextButton:Disable()
    end

    local auctionToCancel = self.auctionsToCancel[1]
    if not auctionToCancel or not auctionToCancel.auctionID then
        table.remove(self.auctionsToCancel, 1)
        self.isCancelling = false
        AL:CancelSingleUndercutAuction()
        return
    end

    AL:UpdateCancelStatus(string.format("Cancelling %s...", auctionToCancel.itemLink), {0.7, 0.7, 1, 1})
    C_AuctionHouse.CancelAuction(auctionToCancel.auctionID)
    table.remove(self.auctionsToCancel, 1)

    if bw then
        if #self.auctionsToCancel > 0 then
            bw.CancelNextButton:SetText(string.format("Cancel Next (%d)", #self.auctionsToCancel))
            C_Timer.After(1.5, function()
                if bw.CancelNextButton then bw.CancelNextButton:Enable() end
                self.isCancelling = false
            end)
        else
            bw.CancelNextButton:Hide()
            bw.CancelNextButton:Disable()
            bw.CancelUndercutButton:Show()
            bw.CancelUndercutButton:Enable()
            AL:UpdateCancelStatus("All undercut auctions have been cancelled.", AL.COLOR_PROFIT)
            self.isCancelling = false
        end
    else
        self.isCancelling = false
    end
end
