-- Auctioneer's Ledger - Core
-- This file contains the core logic for event handling and initialization.

AL.ahTabHooked = false -- Keep track of our hook

-- Internal function to process purchase events. This function is now called by our new system.
function AL:ProcessPurchase(itemName, itemLink, quantity, price)
    if not itemName or not quantity or not price or price <= 0 then
        return
    end

    -- Step 1: ALWAYS add the transaction to the history database.
    self:AddToHistory("purchases", { itemName = itemName, itemLink = itemLink, quantity = quantity, price = price, pricePerItem = price / quantity, timestamp = time() })
    self:RefreshBlasterHistory()

    if not itemLink then
        return
    end

    local itemID = self:GetItemIDFromLink(itemLink)
    if not itemID then return end

    -- Step 2: Check if the item is tracked in the main ledger.
    local isTracked = (_G.AL_SavedData.Items and _G.AL_SavedData.Items[itemID])
    
    if isTracked then
        -- Bug Fix: Corrected transaction type from "AUCTION_BUY" to "BUY", "AUCTION" and made price positive.
        self:RecordTransaction("BUY", "AUCTION", itemID, price, quantity)
    else
        -- [[ DIRECTIVE: Mail Persistence - Pass purchase context ]]
        -- This tells the next function that the item is coming from an AH purchase and should be added to the MailCache.
        local sourceDetails = { source = "AUCTION_PURCHASE", quantity = quantity }
        
        if _G.AL_SavedData and _G.AL_SavedData.Settings and _G.AL_SavedData.Settings.autoAddNewItems then
            -- Bypass popup and add automatically
            local success, msg = AL:InternalAddItem(itemLink, UnitName("player"), GetRealmName(), sourceDetails)
            if success then
                -- Retroactively record the transaction that triggered this
                self:RecordTransaction("BUY", "AUCTION", itemID, price, quantity)
                self:RefreshLedgerDisplay()
            end
        else
            -- Show the confirmation popup, passing the sourceDetails along
            local popupData = { itemName = itemName, itemLink = itemLink, itemID = itemID, price = price, quantity = quantity, sourceDetails = sourceDetails }
            StaticPopup_Show("AL_CONFIRM_TRACK_NEW_PURCHASE", itemName, nil, popupData)
        end
    end
end

function AL:InitializeLibs()
    if self.libsReady then return end
    self.LDB_Lib = LibStub("LibDataBroker-1.1", true)
    self.LibDBIcon_Lib = LibStub("LibDBIcon-1.0", true)
    if not self.LDB_Lib then DEFAULT_CHAT_FRAME:AddMessage(AL.ADDON_NAME .. " (v" .. AL.VERSION .. ") Warning: LibDataBroker-1.1 not found!") end
    if not self.LibDBIcon_Lib then DEFAULT_CHAT_FRAME:AddMessage(AL.ADDON_NAME .. " (v" .. AL.VERSION .. ") Warning: LibDBIcon-1.0 not found!") end
    self.libsReady = (self.LDB_Lib ~= nil and self.LibDBIcon_Lib ~= nil)
end

function AL:CreateLDBSourceAndMinimapIcon()
    if not self.libsReady or not self.LDB_Lib then return end
    
    local ldbObject = {
        type = "launcher",
        label = AL.ADDON_NAME,
        icon = "Interface\\Icons\\inv_7xp_inscription_talenttome01",
        OnClick = function(_, button)
            if IsShiftKeyDown() and IsControlKeyDown() and button == "LeftButton" then
                _G.AL_SavedData.Settings.minimapIcon.hide = not _G.AL_SavedData.Settings.minimapIcon.hide
                if AL.LibDBIcon_Lib then
                    if _G.AL_SavedData.Settings.minimapIcon.hide then AL.LibDBIcon_Lib:Hide(AL.LDB_PREFIX)
                    else AL.LibDBIcon_Lib:Show(AL.LDB_PREFIX) end
                end
            elseif IsShiftKeyDown() and button == "LeftButton" then
                _G.AL_SavedData.Settings.window.x = nil; _G.AL_SavedData.Settings.window.y = nil
                _G.AL_SavedData.Settings.window.width = AL.DEFAULT_WINDOW_WIDTH; _G.AL_SavedData.Settings.window.height = AL.DEFAULT_WINDOW_HEIGHT
                if AL.MainWindow and AL.MainWindow:IsShown() then AL:ApplyWindowState() else AL:ToggleMainWindow() end
            else
                AL:ToggleMainWindow()
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            tooltip:AddLine(AL.ADDON_NAME); tooltip:AddLine("Left-Click: Toggle Window"); tooltip:AddLine("Shift + Left-Click: Reset Window Position/Size."); tooltip:AddLine("Ctrl + Shift + Left-Click: Toggle Minimap Icon.")
        end
    }

    self.LDBObject = self.LDB_Lib:NewDataObject(AL.LDB_PREFIX, ldbObject)
    if self.LibDBIcon_Lib then self.LibDBIcon_Lib:Register(AL.LDB_PREFIX, self.LDBObject, _G.AL_SavedData.Settings.minimapIcon) end
end

function AL:HandleAddonLoaded(arg)
    if not (arg == AL.ADDON_NAME and not self.addonLoadedProcessed) then return end
    self.addonLoadedProcessed = true

    C_Timer.After(0, function()
        AL:InitializeDB()
        AL:InitializeSavedData() 
        AL.currentActiveTab = _G.AL_SavedData.Settings.activeViewMode
        SLASH_ALEDGER1="/aledger"; SLASH_ALEDGER2="/al";
        SlashCmdList["ALEDGER"] = function() AL:ToggleMainWindow() end
        AL:InitializeLibs()
        if AL.libsReady then AL:CreateLDBSourceAndMinimapIcon() end
    end)
end

function AL:HandlePlayerLogin()
    AL.gameFullyInitialized = false
    if not self.libsReady then self:InitializeLibs() end
    C_Timer.After(0, function()
        AL:CreateFrames()
        AL:ApplyWindowState()
        AL.previousMoney = GetMoney()
        AL:BuildSalesCache()
    end)
end

function AL:HandlePlayerEnteringWorld()
    AL:InitializeCoreHooks()
    AL:InitializeTradeHooks()
    AL.gameFullyInitialized = true
    C_Timer.After(2.0, function() if C_AuctionHouse.IsThrottledMessageSystemReady() then C_AuctionHouse.QueryOwnedAuctions({}) end end)
    if self.MainWindow and self.MainWindow:IsShown() then self:RefreshLedgerDisplay() end

    -- [[ DIRECTIVE: Show Welcome Window on Login ]]
    C_Timer.After(1.5, function() -- Short delay to let the UI settle
        if _G.AL_SavedData and _G.AL_SavedData.Settings then
            if _G.AL_SavedData.Settings.showWelcomeWindowOnLogin == nil or _G.AL_SavedData.Settings.showWelcomeWindowOnLogin == true then
                AL:ShowWelcomeWindow()
            end
        end
    end)
end

local eventHandlerFrame = CreateFrame("Frame", "AL_EventHandler_v" .. AL.VERSION:gsub("%.","_"))
eventHandlerFrame:RegisterEvent("ADDON_LOADED")
eventHandlerFrame:RegisterEvent("PLAYER_LOGIN")
eventHandlerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventHandlerFrame:RegisterEvent("BAG_UPDATE")
eventHandlerFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
eventHandlerFrame:RegisterEvent("AUCTION_HOUSE_SHOW") 
eventHandlerFrame:RegisterEvent("OWNED_AUCTIONS_UPDATED")
eventHandlerFrame:RegisterEvent("AUCTION_HOUSE_AUCTION_CREATED")
eventHandlerFrame:RegisterEvent("MAIL_SHOW")
eventHandlerFrame:RegisterEvent("MAIL_INBOX_UPDATE")
eventHandlerFrame:RegisterEvent("MAIL_CLOSED")
eventHandlerFrame:RegisterEvent("MAIL_SEND_SUCCESS") 
eventHandlerFrame:RegisterEvent("MERCHANT_SHOW")
eventHandlerFrame:RegisterEvent("MERCHANT_CLOSED")
eventHandlerFrame:RegisterEvent("TRADE_SHOW")
eventHandlerFrame:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED")
eventHandlerFrame:RegisterEvent("PLAYER_MONEY")


eventHandlerFrame:SetScript("OnEvent", function(selfFrame, event, ...)
    if event == "ADDON_LOADED" then
        AL:HandleAddonLoaded(...)
    elseif event == "PLAYER_LOGIN" then
        AL:HandlePlayerLogin()
    elseif event == "PLAYER_ENTERING_WORLD" then
        AL:HandlePlayerEnteringWorld()
    
    elseif event == "AUCTION_HOUSE_SHOW" then
        if not _G["AL_AHBlasterButton"] then
            if AuctionHouseFrame then
                local ahButton = CreateFrame("Button", "AL_AHBlasterButton", AuctionHouseFrame, "UIPanelButtonTemplate")
                ahButton:SetSize(80, 22)
                ahButton:SetText("Blaster")
                ahButton:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "TOPRIGHT", 0, 5)
                ahButton:SetScript("OnClick", function() AL:ToggleBlasterWindow() end)
            end
        end
        AL:InitializeAuctionHooks()
        C_AuctionHouse.QueryOwnedAuctions({})
        AL:ShowBlasterWindow()
        AL:TriggerDebouncedRefresh(event)

    elseif event == "AUCTION_HOUSE_CLOSED" then
        AL:HideBlasterWindow()
        AL:TriggerDebouncedRefresh(event)

    elseif event == "OWNED_AUCTIONS_UPDATED" then
        -- [[ DIRECTIVE: Auction House Persistence ]]
        -- This is the central point for keeping track of what the player has on the AH.
        -- It rebuilds two caches: one for quick cancellation lookups and one for the main ledger display.
        wipe(AL.auctionIDCache)
        if _G.AL_SavedData and _G.AL_SavedData.AuctionCache then
            wipe(_G.AL_SavedData.AuctionCache)
        end

        local liveAuctions = C_AuctionHouse.GetOwnedAuctions()
        if liveAuctions then
            for _, auctionEntry in ipairs(liveAuctions) do
                if auctionEntry.auctionID and auctionEntry.itemKey and auctionEntry.itemKey.itemID then
                    local itemID = auctionEntry.itemKey.itemID
                    local quantity = auctionEntry.quantity or 0
                    
                    -- Cache for cancellations (by auctionID)
                    AL.auctionIDCache[auctionEntry.auctionID] = { itemID = itemID, quantity = quantity, itemLink = auctionEntry.itemLink }
                    
                    -- Cache for ledger display (aggregated by itemID)
                    if _G.AL_SavedData.AuctionCache then
                        _G.AL_SavedData.AuctionCache[itemID] = (_G.AL_SavedData.AuctionCache[itemID] or 0) + quantity
                    end
                end
            end
        end
        AL:TriggerDebouncedRefresh(event)
    
    elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
        if AL.pendingPostDetails and AL.pendingPostDetails.itemLink then
            local details = AL.pendingPostDetails
            local totalAuctionValue = (details.postPrice or 0) * details.quantity
            AL:RecordTransaction("AUCTION_POST", details.itemID, details.depositFee, details.quantity)
            AL:AddToHistory("posts", { itemLink = details.itemLink, quantity = details.quantity, price = details.depositFee, totalValue = totalAuctionValue, timestamp = time() })
            
            local charKey = UnitName("player") .. "-" .. GetRealmName()
            if not _G.AL_SavedData.PendingAuctions[charKey] then _G.AL_SavedData.PendingAuctions[charKey] = {} end
            table.insert(_G.AL_SavedData.PendingAuctions[charKey], { itemLink = details.itemLink, quantity = details.quantity, totalValue = totalAuctionValue, depositFee = details.depositFee, postTime = time() })
            
            AL:BuildSalesCache()

            AL:RefreshBlasterHistory()
        end
        AL.pendingPostDetails = nil
        if AL.isPosting and AL.itemBeingPosted then AL:HandlePostSuccess() end
        
    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
        -- [[ DIRECTIVE: Mail Persistence ]]
        -- When a commodity is purchased, it is added to the persistent MailCache.
        local itemID, quantity, price = ...
        if not itemID or quantity <= 0 then return end
        
        local charKey = UnitName("player") .. "-" .. GetRealmName()
        if not _G.AL_SavedData.MailCache then _G.AL_SavedData.MailCache = {} end
        if not _G.AL_SavedData.MailCache[charKey] then _G.AL_SavedData.MailCache[charKey] = {} end

        _G.AL_SavedData.MailCache[charKey][itemID] = (_G.AL_SavedData.MailCache[charKey][itemID] or 0) + quantity

        C_Timer.After(2.0, function()
            local itemName, itemLink = GetItemInfo(itemID)
            if itemLink then AL:ProcessPurchase(itemName, itemLink, quantity, price) end
        end)

    elseif event == "PLAYER_MONEY" then
        local currentMoney = GetMoney()
        if currentMoney ~= AL.previousMoney then
            local moneyChange = currentMoney - AL.previousMoney
            if moneyChange < 0 then
                local moneySpent = -moneyChange
                AL.pendingCost = {
                    cost = moneySpent,
                    time = GetTime()
                }
                AL:TryToMatchEvents()
            end
            AL.previousMoney = currentMoney
        end

    elseif event == "MAIL_SHOW" then
        AL:ProcessMailboxUpdate()
        AL:TriggerDebouncedRefresh(event)
    elseif event == "MAIL_INBOX_UPDATE" then
        if AL.mailRefreshTimer then AL.mailRefreshTimer:Cancel() end
        AL.mailRefreshTimer = C_Timer.After(AL.MAIL_REFRESH_DELAY, function()
            AL:ProcessMailboxUpdate()
            AL:TriggerDebouncedRefresh(event)
        end)
    elseif event == "MAIL_CLOSED" then
        -- The MailCache persists, so just trigger a refresh to update the view to "stale".
        AL:TriggerDebouncedRefresh(event)
    elseif event == "AUCTION_HOUSE_SHOW_ERROR" then
        if AL.isPosting and AL.itemBeingPosted then AL:HandlePostFailure("Auction House Error: " .. (... or "Unknown")) end

    elseif event == "MERCHANT_SHOW" then
        AL:InitializeVendorHooks()
        -- [[ DIRECTIVE: Performance - Remove unnecessary refresh ]]
        -- The ledger does not need to refresh every time a vendor is opened.
        -- AL:TriggerDebouncedRefresh(event)
    elseif event == "TRADE_SHOW" then
        AL:InitializeTradeHooks()
    else
        AL:TriggerDebouncedRefresh(event)
    end
end)

