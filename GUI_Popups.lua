-- Auctioneer's Ledger - GUI Popups
-- This file contains the functions for all popup windows (reminder, help, support).

-- Helper to set feedback message on the reminder popup
function AL:SetReminderPopupFeedback(message,isSuccess)
    if self.ReminderPopup and self.ReminderPopup.InstructionText then
        if isSuccess then self.ReminderPopup.InstructionText:SetTextColor(0.2,1,0.2) else self.ReminderPopup.InstructionText:SetTextColor(1,0.2,0.2) end
        self.ReminderPopup.InstructionText:SetText(message)
        if self.revertPopupTextTimer then self.revertPopupTextTimer:Cancel()
        self.revertPopupTextTimer=nil end
        self.revertPopupTextTimer=C_Timer.After(AL.POPUP_FEEDBACK_DURATION,function() if AL.ReminderPopup and AL.ReminderPopup:IsShown()and AL.ReminderPopup.InstructionText then AL.ReminderPopup.InstructionText:SetText(AL.ORIGINAL_POPUP_TEXT)
        AL.ReminderPopup.InstructionText:SetTextColor(1,1,1) end
        AL.revertPopupTextTimer=nil end)
    end
end

-- Creates the reminder popup frame for tracking new items
function AL:CreateReminderPopup()
    local frameNameSuffix = "_v" .. AL.VERSION:gsub("%.", "_")
    if self.ReminderPopup and self.ReminderPopup:IsObjectType("Frame") and self.ReminderPopup:GetName() == "AL_ReminderPopup" .. frameNameSuffix then return end
    local p=CreateFrame("Frame","AL_ReminderPopup" .. frameNameSuffix,UIParent,"BasicFrameTemplateWithInset")
    self.ReminderPopup=p
    p:SetSize(AL.POPUP_WIDTH,AL.POPUP_HEIGHT)
    p:SetFrameStrata("DIALOG")
    p:SetFrameLevel(10)
    p:EnableMouse(true)
    p:SetMovable(true)
    p:SetClampedToScreen(true)
    p.TitleText:SetText("Track New Item")
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart",function(s)if s.isMoving then return end s:StartMoving()
    s.isMoving=true end)
    p:SetScript("OnDragStop",function(s)s:StopMovingOrSizing()
    s.isMoving=false
    AL.reminderPopupLastX=s:GetLeft()
    AL.reminderPopupLastY=UIParent:GetHeight()-s:GetTop() end)
    
    local t=p:CreateFontString(nil,"ARTWORK","GameFontNormal")
    t:SetPoint("CENTER", 0, 20)
    t:SetText(AL.ORIGINAL_POPUP_TEXT)
    t:SetJustifyH("CENTER")
    t:SetJustifyV("MIDDLE")
    self.ReminderPopup.InstructionText=t
    
    local addAllBtn = CreateFrame("Button", "AL_ReminderAddAllButton" .. frameNameSuffix, p, "UIPanelButtonTemplate")
    addAllBtn:SetSize(AL.POPUP_WIDTH - 40, AL.BUTTON_HEIGHT)
    addAllBtn:SetText("Add All Eligible Items From Bags") 
    addAllBtn:SetPoint("BOTTOM", p, "BOTTOM", 0, 10)
    addAllBtn:SetScript("OnClick", function()
        if not AL.gameFullyInitialized then
            AL:SetReminderPopupFeedback("Game systems are initializing, please wait a moment and try again.", false)
            return
        end
        AL:AttemptAddAllEligibleItemsFromBags()
    end)
    self.ReminderPopup.AddAllButton = addAllBtn

    p:SetScript("OnReceiveDrag", function(self)
        local cursorType, itemID, itemLink, _, _, _, fromContainer, fromSlot = GetCursorInfo()
        ClearCursor()

        if cursorType ~= "item" or not itemLink then
            AL:SetReminderPopupFeedback("You must drag a valid item.", false)
            return
        end

        local charName = UnitName("player")
        local charRealm = GetRealmName()
        local charKey = charName .. "-" .. charRealm
        if _G.AL_SavedData.Items[itemID] and _G.AL_SavedData.Items[itemID].characters[charKey] then
            AL:SetReminderPopupFeedback("This item is already tracked by this character.", false)
            return
        end

        local isAuctionable = false
        
        if fromContainer and fromSlot then
            local itemLocation = ItemLocation:CreateFromBagAndSlot(fromContainer, fromSlot)
            if itemLocation and itemLocation:IsValid() then
                isAuctionable = AL:IsItemAuctionableByLocation(itemLocation)
            end
        end

        if not isAuctionable then
            isAuctionable = AL:IsItemAuctionable_Fallback(itemLink)
        end

        if isAuctionable then
            AL:ProcessAndStoreItem(itemLink)
        else
            AL:SetReminderPopupFeedback("This item cannot be auctioned.", false)
        end
    end)
    
    p.CloseButton:SetScript("OnClick",function()AL:HideReminderPopup() end)
    p:SetScript("OnHide",function() 
        if GetCursorInfo()then ClearCursor() end
        if AL.revertPopupTextTimer then AL.revertPopupTextTimer:Cancel()
        AL.revertPopupTextTimer=nil end
        if AL.ReminderPopup and AL.ReminderPopup.InstructionText then AL.ReminderPopup.InstructionText:SetText(AL.ORIGINAL_POPUP_TEXT)
        AL.ReminderPopup.InstructionText:SetTextColor(1,1,1) end
    end)
    p:Hide()
end

-- Shows the reminder popup
function AL:ShowReminderPopup()
    if not self.MainWindow or not self.MainWindow:IsShown()then return end
    if not self.ReminderPopup then self:CreateReminderPopup()
    if not self.ReminderPopup then return end end
    self.ReminderPopup:ClearAllPoints()
    if self.reminderPopupLastX and self.reminderPopupLastY then self.ReminderPopup:SetPoint("TOPLEFT",nil,"TOPLEFT",self.reminderPopupLastX,-self.reminderPopupLastY)
    else self.ReminderPopup:SetPoint("TOPLEFT",self.MainWindow,"TOPRIGHT",AL.POPUP_OFFSET_X,0)
    local rE=self.ReminderPopup:GetLeft()+self.ReminderPopup:GetWidth()
    local sW=GetScreenWidth()/UIParent:GetEffectiveScale()
    if rE>sW-10 then self.ReminderPopup:ClearAllPoints()
    self.ReminderPopup:SetPoint("TOPRIGHT",self.MainWindow,"TOPLEFT",-AL.POPUP_OFFSET_X,0) end end
    if self.ReminderPopup.InstructionText then self.ReminderPopup.InstructionText:SetText(AL.ORIGINAL_POPUP_TEXT)
    AL.ReminderPopup.InstructionText:SetTextColor(1,1,1) end
    if self.revertPopupTextTimer then self.revertPopupTextTimer:Cancel()
    AL.revertPopupTextTimer=nil end
    self.ReminderPopup:Show()
    self.ReminderPopup:Raise()
end

-- Hides the reminder popup
function AL:HideReminderPopup()
    if self.ReminderPopup and self.ReminderPopup:IsShown()then self.ReminderPopup:Hide() end
end

-- Creates the help window for the addon
function AL:CreateHelpWindow()
    if self.HelpWindow then return end
    local frameNameSuffix = "_v" .. AL.VERSION:gsub("%.","_")
    local hw = CreateFrame("Frame", "AL_HelpWindow" .. frameNameSuffix, UIParent,"BasicFrameTemplateWithInset")
    self.HelpWindow = hw
    hw:SetSize(AL.HELP_WINDOW_WIDTH, AL.HELP_WINDOW_HEIGHT)
    hw:SetFrameStrata("DIALOG")
    local mainWinLevel = self.MainWindow and self.MainWindow:GetFrameLevel() or 5
    hw:SetFrameLevel(mainWinLevel + 5)
    hw.TitleText:SetText(AL.ADDON_NAME .. " - How To Use")
    hw:SetMovable(true)
    hw:RegisterForDrag("LeftButton")
    hw:SetScript("OnDragStart", function(self) self:StartMoving() end)
    hw:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    hw:SetClampedToScreen(true)
    hw.CloseButton:SetScript("OnClick", function() self:HideHelpWindow() end)
    local scroll = CreateFrame("ScrollFrame", "AL_HelpScrollFrame" .. frameNameSuffix, hw, "UIPanelScrollFrameTemplate")
    self.HelpWindowScrollFrame = scroll
    scroll:SetPoint("TOPLEFT", hw, "TOPLEFT", 8, -30)
    scroll:SetPoint("BOTTOMRIGHT", hw, "BOTTOMRIGHT", -30, 8)
    local child = CreateFrame("Frame", "AL_HelpScrollChild" .. frameNameSuffix, scroll)
    self.HelpWindowScrollChild = child
    child:SetWidth(AL.HELP_WINDOW_WIDTH - 50)
    child:SetHeight(10)
    scroll:SetScrollChild(child)
    local fs = child:CreateFontString("AL_HelpFontString" .. frameNameSuffix, "ARTWORK", "GameFontNormal")
    self.HelpWindowFontString = fs
    fs:SetPoint("TOPLEFT", child, "TOPLEFT", 10, -10)
    fs:SetWidth(child:GetWidth() - 20)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetTextColor(unpack(AL.COLOR_DEFAULT_TEXT_RGB))
    self:PopulateHelpWindowText()
    hw:Hide()
end

-- Shows the help window
function AL:ShowHelpWindow()
    if not self.HelpWindow then self:CreateHelpWindow() end
    if not self.HelpWindow then return end
    self:PopulateHelpWindowText()
    self.HelpWindow:ClearAllPoints()
    self.HelpWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.HelpWindow:Show()
    self.HelpWindow:Raise()
end

-- Hides the help window
function AL:HideHelpWindow()
    if self.HelpWindow and self.HelpWindow:IsShown() then self.HelpWindow:Hide() end
end

-- Toggles the visibility of the help window
function AL:ToggleHelpWindow()
    if not self.HelpWindow or not self.HelpWindow:IsShown() then self:ShowHelpWindow()
    else self:HideHelpWindow() end
end

-- Creates the support window for the addon
function AL:CreateSupportWindow()
    if self.SupportWindow then return end
    local frameNameSuffix = "_v" .. AL.VERSION:gsub("%.","_")
    local sw = CreateFrame("Frame", "AL_SupportWindow" .. frameNameSuffix, UIParent, "BasicFrameTemplateWithInset")
    self.SupportWindow = sw
    sw:SetSize(420, 480) -- Increased height for Discord info
    sw:SetFrameStrata("DIALOG")
    local mainWinLevel = self.MainWindow and self.MainWindow:GetFrameLevel() or 5
    sw:SetFrameLevel(mainWinLevel + 5)
    -- [[ DIRECTIVE: Change Title ]]
    sw.TitleText:SetText("Support & Community")
    sw:SetMovable(true)
    sw:RegisterForDrag("LeftButton")
    sw:SetScript("OnDragStart", function(self) self:StartMoving() end)
    sw:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    sw:SetClampedToScreen(true)
    sw.CloseButton:SetScript("OnClick", function() self:HideSupportWindow() end)

    -- [[ DIRECTIVE: Add Discord Logo ]]
    local discordLogo = sw:CreateTexture(nil, "ARTWORK")
    discordLogo:SetSize(256, 85) -- Adjusted size for Discord logo
    discordLogo:SetTexture(AL.DISCORD_LOGO_PATH)
    discordLogo:SetPoint("TOP", sw, "TOP", 0, -40)

    -- Discord link EditBox
    local discordLinkBox = CreateFrame("EditBox", "AL_DiscordLinkBox" .. frameNameSuffix, sw, "InputBoxTemplate")
    discordLinkBox:SetPoint("TOP", discordLogo, "BOTTOM", 0, -10)
    discordLinkBox:SetSize(sw:GetWidth() - 60, 30)
    discordLinkBox:SetText("https://discord.com/invite/5TfC7ey3Te")
    discordLinkBox:SetAutoFocus(false)
    discordLinkBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    discordLinkBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    discordLinkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    -- Instruction label for copying Discord link
    local discordInstructionLabel = sw:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    discordInstructionLabel:SetPoint("TOP", discordLinkBox, "BOTTOM", 0, -5)
    discordInstructionLabel:SetTextColor(1, 0.82, 0, 1) -- Yellowish color
    discordInstructionLabel:SetText("Press Ctrl+C to copy the URL for bug reports and community chat.")

    -- [[ DIRECTIVE: Add Patreon Logo, positioned below Discord info ]]
    local patreonLogo = sw:CreateTexture(nil, "ARTWORK")
    patreonLogo:SetSize(256, 64)
    patreonLogo:SetTexture(AL.PATREON_LOGO_PATH)
    patreonLogo:SetPoint("TOP", discordInstructionLabel, "BOTTOM", 0, -20)

    -- Main message FontString
    local messageFS = sw:CreateFontString("AL_SupportMessageFS" .. frameNameSuffix, "ARTWORK", "GameFontNormal")
    messageFS:SetPoint("TOP", patreonLogo, "BOTTOM", 0, -15)
    messageFS:SetWidth(sw:GetWidth() - 40)
    messageFS:SetJustifyH("CENTER")
    messageFS:SetJustifyV("TOP")
    messageFS:SetTextColor(unpack(AL.COLOR_BANK_GOLD))
    messageFS:SetText("Auctioneer's Ledger is a passion project that takes hundreds of hours to develop and maintain. If you find the addon valuable and want to support its continued development, please consider becoming a patron!")

    -- Donation link EditBox
    local patreonLinkBox = CreateFrame("EditBox", "AL_SupportLinkBox" .. frameNameSuffix, sw, "InputBoxTemplate")
    patreonLinkBox:SetPoint("TOP", messageFS, "BOTTOM", 0, -15)
    patreonLinkBox:SetSize(sw:GetWidth() - 60, 30)
    patreonLinkBox:SetText("https://www.patreon.com/csasoftware")
    patreonLinkBox:SetAutoFocus(false)
    patreonLinkBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    patreonLinkBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    patreonLinkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    -- Instruction label for copying Patreon link
    local patreonInstructionLabel = sw:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    patreonInstructionLabel:SetPoint("TOP", patreonLinkBox, "BOTTOM", 0, -5)
    patreonInstructionLabel:SetTextColor(1, 0.82, 0, 1) -- Yellowish color
    patreonInstructionLabel:SetText("Press Ctrl+C to copy the URL.")

    sw:Hide()
end

-- Shows the support window
function AL:ShowSupportWindow()
    if not self.SupportWindow then self:CreateSupportWindow() end
    if not self.SupportWindow then return end
    self.SupportWindow:ClearAllPoints()
    self.SupportWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.SupportWindow:Show()
    self.SupportWindow:Raise()
end

-- Hides the support window
function AL:HideSupportWindow()
    if self.SupportWindow and self.SupportWindow:IsShown() then self.SupportWindow:Hide() end
end

-- Toggles the visibility of the support window
function AL:ToggleSupportWindow()
    if not self.SupportWindow or not self.SupportWindow:IsShown() then self:ShowSupportWindow()
    else self:HideSupportWindow() end
end

-- [[ DIRECTIVE: Create Welcome Window ]]
function AL:CreateWelcomeWindow()
    if self.WelcomeWindow then return end
    local frameNameSuffix = "_v" .. AL.VERSION:gsub("%.","_")
    local ww = CreateFrame("Frame", "AL_WelcomeWindow" .. frameNameSuffix, UIParent, "BasicFrameTemplateWithInset")
    self.WelcomeWindow = ww
    ww:SetSize(480, 580) -- A bit wider and taller to fit all content
    ww:SetFrameStrata("DIALOG")
    ww:SetFrameLevel(20)
    ww.TitleText:SetText("Welcome to Auctioneer's Ledger!")
    ww:SetMovable(true)
    ww:RegisterForDrag("LeftButton")
    ww:SetScript("OnDragStart", function(self) self:StartMoving() end)
    ww:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    ww:SetClampedToScreen(true)
    ww.CloseButton:SetScript("OnClick", function() self:HideWelcomeWindow() end)

    local currentY = -40

    -- Tutorial Section
    local tutorialHeader = ww:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    tutorialHeader:SetPoint("TOP", ww, "TOP", 0, currentY)
    tutorialHeader:SetTextColor(1, 0.82, 0, 1)
    tutorialHeader:SetText("Getting Started")
    currentY = currentY - 25

    local tutorialText = ww:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    tutorialText:SetPoint("TOP", tutorialHeader, "BOTTOM", 0, -10)
    tutorialText:SetWidth(ww:GetWidth() - 40)
    tutorialText:SetJustifyH("LEFT")
    tutorialText:SetText("• To open the main window, type |cffffd100/al|r or |cffffd100/aledger|r in chat, or click the minimap icon.\n\n• To track an item, click the '|cffffd100Track New Item|r' button in the ledger and drag an item from your bags onto the popup.")
    currentY = currentY - tutorialText:GetHeight() - 20

    -- Divider
    local divider = ww:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", ww, "TOPLEFT", 20, currentY)
    divider:SetPoint("TOPRIGHT", ww, "TOPRIGHT", -20, currentY)
    divider:SetHeight(1)
    divider:SetColorTexture(0.5, 0.5, 0.5, 0.5)
    currentY = currentY - 20

    -- Support & Community Section (copied and adapted from CreateSupportWindow)
    local discordLogo = ww:CreateTexture(nil, "ARTWORK")
    discordLogo:SetSize(256, 85)
    discordLogo:SetTexture(AL.DISCORD_LOGO_PATH)
    discordLogo:SetPoint("TOP", ww, "TOP", 0, currentY)
    currentY = currentY - 85 - 10

    local discordLinkBox = CreateFrame("EditBox", "AL_WelcomeDiscordLinkBox" .. frameNameSuffix, ww, "InputBoxTemplate")
    discordLinkBox:SetPoint("TOP", ww, "TOP", 0, currentY)
    discordLinkBox:SetSize(ww:GetWidth() - 80, 30)
    discordLinkBox:SetText("https://discord.com/invite/5TfC7ey3Te")
    discordLinkBox:SetAutoFocus(false)
    discordLinkBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    discordLinkBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    discordLinkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    currentY = currentY - 30 - 5

    local discordInstructionLabel = ww:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    discordInstructionLabel:SetPoint("TOP", ww, "TOP", 0, currentY)
    discordInstructionLabel:SetTextColor(1, 0.82, 0, 1)
    discordInstructionLabel:SetText("Press Ctrl+C to copy the URL for bug reports and community chat.")
    currentY = currentY - 15 - 20

    local patreonLogo = ww:CreateTexture(nil, "ARTWORK")
    patreonLogo:SetSize(256, 64)
    patreonLogo:SetTexture(AL.PATREON_LOGO_PATH)
    patreonLogo:SetPoint("TOP", ww, "TOP", 0, currentY)
    currentY = currentY - 64 - 15

    local messageFS = ww:CreateFontString("AL_WelcomeSupportMessageFS" .. frameNameSuffix, "ARTWORK", "GameFontNormal")
    messageFS:SetPoint("TOP", ww, "TOP", 0, currentY)
    messageFS:SetWidth(ww:GetWidth() - 40)
    messageFS:SetJustifyH("CENTER")
    messageFS:SetTextColor(unpack(AL.COLOR_BANK_GOLD))
    messageFS:SetText("Auctioneer's Ledger is a passion project that takes hundreds of hours to develop and maintain. If you find the addon valuable and want to support its continued development, please consider becoming a patron!")
    currentY = currentY - messageFS:GetHeight() - 15

    local patreonLinkBox = CreateFrame("EditBox", "AL_WelcomeSupportLinkBox" .. frameNameSuffix, ww, "InputBoxTemplate")
    patreonLinkBox:SetPoint("TOP", ww, "TOP", 0, currentY)
    patreonLinkBox:SetSize(ww:GetWidth() - 80, 30)
    patreonLinkBox:SetText("https://www.patreon.com/csasoftware")
    patreonLinkBox:SetAutoFocus(false)
    patreonLinkBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    patreonLinkBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    patreonLinkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    currentY = currentY - 30 - 5

    local patreonInstructionLabel = ww:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    patreonInstructionLabel:SetPoint("TOP", ww, "TOP", 0, currentY)
    patreonInstructionLabel:SetTextColor(1, 0.82, 0, 1)
    patreonInstructionLabel:SetText("Press Ctrl+C to copy the URL.")

    -- "Do not show again" Checkbox
    local dontShowCheck = CreateFrame("CheckButton", "AL_DontShowWelcomeCheck" .. frameNameSuffix, ww, "UICheckButtonTemplate")
    dontShowCheck:SetPoint("BOTTOMLEFT", ww, "BOTTOMLEFT", 15, 15)
    _G[dontShowCheck:GetName() .. "Text"]:SetText("Do not show this again")
    dontShowCheck:SetScript("OnClick", function(self)
        if _G.AL_SavedData and _G.AL_SavedData.Settings then
            _G.AL_SavedData.Settings.showWelcomeWindowOnLogin = not self:GetChecked()
        end
    end)
    
    ww:Hide()
end

function AL:ShowWelcomeWindow()
    if not self.WelcomeWindow then self:CreateWelcomeWindow() end
    if not self.WelcomeWindow then return end
    self.WelcomeWindow:ClearAllPoints()
    self.WelcomeWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.WelcomeWindow:Show()
    self.WelcomeWindow:Raise()
end

function AL:HideWelcomeWindow()
    if self.WelcomeWindow and self.WelcomeWindow:IsShown() then self.WelcomeWindow:Hide() end
end

-- Populates the text content of the help window
function AL:PopulateHelpWindowText()
    if not self.HelpWindowFontString then return end
    local function getWoWColorHex(colorTable, alphaOverride)
        if not colorTable or type(colorTable) ~= "table" or #colorTable < 3 then return "FFFFFFFF" end
        local r_val = math.max(0, math.min(1, colorTable[1] or 0))
        local g_val = math.max(0, math.min(1, colorTable[2] or 0))
        local b_val = math.max(0, math.min(1, colorTable[3] or 0))
        local a_val = colorTable[4]
        if alphaOverride ~= nil then a_val = alphaOverride end
        if a_val == nil then a_val = 1.0 end
        local finalA = math.floor(math.max(0, math.min(1, a_val)) * 255 + 0.5)
        local finalR = math.floor(r_val * 255 + 0.5)
        local finalG = math.floor(g_val * 255 + 0.5)
        local finalB = math.floor(b_val * 255 + 0.5)
        return string.format("%02X%02X%02X%02X", finalA, finalR, finalG, finalB)
    end
    local GOLD_C = "|c" .. getWoWColorHex(AL.COLOR_BANK_GOLD)
    local TAN_C = "|c" .. getWoWColorHex(AL.COLOR_MAIL_TAN)
    local AH_BLUE_C = "|c" .. getWoWColorHex(AL.COLOR_AH_BLUE)
    local LIMBO_C = "|c" .. getWoWColorHex(AL.COLOR_LIMBO)
    local WARBAND_C = "|c" .. getWoWColorHex(AL.COLOR_WARBAND_BANK)
    local REAGENT_C = "|c" .. getWoWColorHex(AL.COLOR_REAGENT_BANK)
    local PROFIT_C = "|c" .. getWoWColorHex(AL.COLOR_PROFIT)
    local LOSS_C = "|c" .. getWoWColorHex(AL.COLOR_LOSS)
    
    local WHITE = "|cFFFFFFFF"
    local YELLOW = "|cFFD4AF37"
    local ORANGE = "|cFFFF8000"
    local DIMMED_TEXT_C  = "|c" .. getWoWColorHex({(AL.COLOR_LIMBO[1] or 0)*0.85, (AL.COLOR_LIMBO[2] or 0)*0.85, (AL.COLOR_LIMBO[3] or 0)*0.85, 1.0})
    local SECTION_TITLE_C = YELLOW
    local HIGHLIGHT_C = WHITE
    local SUB_HIGHLIGHT_C = ORANGE
    local r_reset = "|r"
    local function CT(colorPipe, textSegment) return colorPipe .. textSegment .. r_reset end
    local textParts = {}

    table.insert(textParts, CT(SECTION_TITLE_C, "Welcome to Auctioneer's Ledger v" .. AL.VERSION .. "!") .. "\n")
    table.insert(textParts, "This addon helps you track items across your warband, manage stock, and streamline your gold-making with the AL Blaster.\n\n")

    table.insert(textParts, CT(SECTION_TITLE_C, "The Main Window & Ledger Tabs") .. "\n")
    table.insert(textParts, "The main window is your central hub. You can open it with " .. CT(SUB_HIGHLIGHT_C, "/al") .. " or " .. CT(SUB_HIGHLIGHT_C, "/aledger") .. ", or by clicking the minimap icon. It has five main tabs:\n")
    table.insert(textParts, "  • " .. CT(HIGHLIGHT_C, "Warband Stock:") .. " A master list of all your tracked items and where they are.\n")
    table.insert(textParts, "  • " .. CT(HIGHLIGHT_C, "Auction Finances:") .. " Tracks your profits and losses from the Auction House.\n")
    table.insert(textParts, "  • " .. CT(HIGHLIGHT_C, "Vendor Finances:") .. " Tracks your profits and losses from buying and selling to NPC vendors.\n")
    table.insert(textParts, "  • " .. CT(HIGHLIGHT_C, "Auction Pricing:") .. " Set your pricing rules for the Blaster.\n")
    table.insert(textParts, "  • " .. CT(HIGHLIGHT_C, "Auction Settings:") .. " Configure post duration and stack sizes for the Blaster.\n\n")

    table.insert(textParts, CT(SECTION_TITLE_C, "The AL Blaster: Rapid Posting & History") .. "\n")
    table.insert(textParts, "The Blaster is your high-speed posting tool. It appears automatically when you open the Auction House.\n")
    table.insert(textParts, CT(HIGHLIGHT_C, "Posting Workflow:") .. "\n")
    table.insert(textParts, "  1. " .. CT(SUB_HIGHLIGHT_C, "Scan Inventory:") .. " Click this to scan your bags for any items you're tracking in the Ledger.\n")
    table.insert(textParts, "  2. The addon scans the AH for competitor prices and builds a queue based on your settings in the 'Auction Pricing' tab.\n")
    table.insert(textParts, "  3. " .. CT(SUB_HIGHLIGHT_C, "Blast!:") .. " Once an item is ready, click 'Blast!' to post it. The addon handles the rest.\n")
    table.insert(textParts, CT(HIGHLIGHT_C, "Other Blaster Buttons:") .. "\n")
    table.insert(textParts, "  • " .. CT(SUB_HIGHLIGHT_C, "Skip:") .. " Manually skips the current item in the queue.\n")
    table.insert(textParts, "  • " .. CT(SUB_HIGHLIGHT_C, "Refresh:") .. " Clears the current queue and resets the Blaster.\n")
    table.insert(textParts, "  • " .. CT(SUB_HIGHLIGHT_C, "Auto Pricing:") .. " Scans the AH market value for " .. CT(ORANGE, "all items") .. " in your Ledger (not just what's in your bags) and updates their prices if 'Allow Auto-Pricing' is checked in the 'Auction Pricing' tab.\n")
    table.insert(textParts, CT(HIGHLIGHT_C, "Blaster History Panel:") .. "\n")
    table.insert(textParts, "  To the right of the Blaster, you can see a history of your recent activity: Posts, Sales, Purchases, and Cancellations.\n\n")

    table.insert(textParts, CT(SECTION_TITLE_C, "Tracking Items") .. "\n")
    table.insert(textParts, "  • " .. CT(HIGHLIGHT_C, "Add an Item:") .. " Click 'Track New Item' in the Ledger's left panel. Drag an item from your bags onto the popup that appears.\n")
    table.insert(textParts, "  • " .. CT(HIGHLIGHT_C, "Add All Items:") .. " Use the 'Add All Eligible Items From Bags' button in the popup to quickly track everything auctionable in your inventory.\n")
    table.insert(textParts, "  • " .. CT(HIGHLIGHT_C, "Remove an Item:") .. " In the 'Warband Stock' tab, click the 'X' button on a row to remove that specific character's entry. To remove all entries for an item across all characters, click the 'X' on the main parent row.\n\n")

    table.insert(textParts, CT(SECTION_TITLE_C, "Understanding Locations & Data Accuracy") .. "\n")
    table.insert(textParts, "The 'Warband Stock' tab shows where your items are. Colors indicate the location:\n")
    table.insert(textParts, "  • " .. CT(WHITE, "Live Data (Bright Colors):") .. " For your " .. CT(SUB_HIGHLIGHT_C, "current character") .. ", Bags ("..CT(WHITE, "Rarity Color").."), Bank ("..CT(GOLD_C, "Gold").."), Reagent Bank ("..CT(REAGENT_C, "Teal").."), Mail ("..CT(TAN_C, "Tan").."), and the Auction House ("..CT(AH_BLUE_C, "Blue")..") are updated live when their respective windows are open. The Warband Bank ("..CT(WARBAND_C, "Red")..") is always live.\n")
    table.insert(textParts, "  • " .. CT(DIMMED_TEXT_C, "Stale Data (Dimmed Colors):") .. " For " .. CT(SUB_HIGHLIGHT_C, "alts") .. ", or when a window like the Mailbox is closed, the addon shows the last known location. A note will provide context, like 'Inside mailbox.' or 'Being auctioned.'\n")
    table.insert(textParts, "  • " .. CT(LIMBO_C, "Limbo (Gray):") .. " The item's location is unknown. This happens if you vendored it, mailed it away, or if it was on an alt and has since moved.\n\n")

    table.insert(textParts, CT(SECTION_TITLE_C, "Financials & Pricing") .. "\n")
    table.insert(textParts, "  • " .. CT(HIGHLIGHT_C, "Finances Tabs:") .. " See your total " .. PROFIT_C .. "profit|r and " .. LOSS_C .. "loss|r per item, separated by Auction and Vendor transactions. Data is automatically recorded from sales, purchases, and lost deposits.\n")
    table.insert(textParts, "  • " .. CT(HIGHLIGHT_C, "Auction Pricing Tab:") .. " This is where you set the rules for the Blaster.\n")
    table.insert(textParts, "    - " .. CT(SUB_HIGHLIGHT_C, "Allow Auto-Pricing:") .. " Check this to let the 'Auto Pricing' scan update this item's price.\n")
    table.insert(textParts, "    - " .. CT(SUB_HIGHLIGHT_C, "Safety Net Buyout:") .. " The lowest price you'll accept. The Blaster will skip posting if the market is below this.\n")
    table.insert(textParts, "    - " .. CT(SUB_HIGHLIGHT_C, "Normal Buyout Price:") .. " Your ideal price, used when there's no competition.\n")
    table.insert(textParts, "    - " .. CT(SUB_HIGHLIGHT_C, "Undercut Amount:") .. " How much to undercut competitors by.\n")
    table.insert(textParts, "  • " .. CT(HIGHLIGHT_C, "Auction Settings Tab:") .. " Set the default auction duration (12h, 24h, 48h) and the quantity to post per stack for each item.\n\n")

    table.insert(textParts, CT(SECTION_TITLE_C, "Minimap Icon / LDB Launcher") .. "\n")
    table.insert(textParts, "  • " .. CT(HIGHLIGHT_C, "Left-Click:") .. " Toggle main window visibility.\n")
    table.insert(textParts, "  • " .. CT(HIGHLIGHT_C, "Shift + Left-Click:") .. " Reset window to default position and size.\n")
    table.insert(textParts, "  • " .. CT(HIGHLIGHT_C, "Ctrl + Shift + Left-Click:") .. " Toggle the minimap icon's visibility itself.\n\n")

    table.insert(textParts, CT(YELLOW, "Happy auctioneering and inventory management!"))

    local helpText = table.concat(textParts, "")
    self.HelpWindowFontString:SetText(helpText)
    C_Timer.After(0.05, function() if self.HelpWindowFontString and self.HelpWindowScrollChild and self.HelpWindowScrollFrame then local fsHeight = self.HelpWindowFontString:GetHeight()
    local scrollFrameHeight = self.HelpWindowScrollFrame:GetHeight()
    self.HelpWindowScrollChild:SetHeight(math.max(scrollFrameHeight - 10, fsHeight + 20)) end end)
end

-- [[ DIRECTIVE: Remove Periodic Timer ]]
-- This function is now removed. All refreshes are event-driven.
-- function AL:StartStopPeriodicRefresh() ... end

-- Applies the saved window state (position, size, visibility)
function AL:ApplyWindowState() 
    local frameNameSuffix = "_v" .. AL.VERSION:gsub("%.","_")
    local mainWindowName = "AL_MainWindow" .. frameNameSuffix
    if not AL.MainWindow then return end

    _G.AL_SavedData.Settings = _G.AL_SavedData.Settings or {}
    _G.AL_SavedData.Settings.window = _G.AL_SavedData.Settings.window or {x=nil,y=nil,width=AL.DEFAULT_WINDOW_WIDTH,height=AL.DEFAULT_WINDOW_HEIGHT,visible=true}

    local settings = _G.AL_SavedData.Settings.window

    AL.MainWindow:ClearAllPoints()
    
    AL.MainWindow:SetSize(settings.width or AL.DEFAULT_WINDOW_WIDTH, settings.height or AL.DEFAULT_WINDOW_HEIGHT)

    if settings.x and settings.y then
        AL.MainWindow:SetPoint("TOPLEFT", UIParent, "TOPLEFT", settings.x, -settings.y)
    else
        AL.MainWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    
    if settings.visible then 
        AL.MainWindow:Show()
        -- [[ DIRECTIVE: Reactive Refresh ]]
        -- Refresh the display when the window is shown.
        self:RefreshLedgerDisplay()
    else 
        AL.MainWindow:Hide()
        AL:HideReminderPopup()
        AL:HideHelpWindow()
        AL:HideSupportWindow()
    end
end

-- Toggles the main window's visibility
function AL:ToggleMainWindow()
    local frameNameSuffix = "_v" .. AL.VERSION:gsub("%.","_")
    local mainWindowName = "AL_MainWindow" .. frameNameSuffix
    if not self.MainWindow or self.MainWindow:GetName() ~= mainWindowName then 
        AL:CreateFrames()
        if self.MainWindow and self.MainWindow:GetName() == mainWindowName then 
            AL:ApplyWindowState()
        else 
            DEFAULT_CHAT_FRAME:AddMessage(AL.ADDON_NAME .. ": Error: MainWindow not created after calling CreateFrames.")
            return
        end
    end

    if self.MainWindow:IsShown() then
        if AL.dataHasChanged then
            StaticPopup_Show("AL_CONFIRM_RELOAD_SETTINGS")
            AL.dataHasChanged = false 
        else
            self.MainWindow:Hide()
            if _G.AL_SavedData.Settings and _G.AL_SavedData.Settings.window then
                _G.AL_SavedData.Settings.window.visible = false
            end
            AL:HideReminderPopup()
            AL:HideHelpWindow()
            AL:HideSupportWindow()
        end
    else 
        if _G.AL_SavedData.Settings and _G.AL_SavedData.Settings.window then
            _G.AL_SavedData.Settings.window.visible = true
        end
        AL:ApplyWindowState()
    end
end

-- Define StaticPopupDialogs for confirmation dialogs
StaticPopupDialogs["AL_CONFIRM_DELETE_ALL_ITEM_INSTANCES"] = {
    text = "Are you sure you want to remove all tracked entries for %s?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        if data and data.itemID then
            AL:RemoveAllInstancesOfItem(data.itemID)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3, 
}

-- Dialog for settings changes in the main addon window
StaticPopupDialogs["AL_CONFIRM_RELOAD_SETTINGS"] = {
    text = "Settings have been changed. A UI reload is recommended to ensure data is saved correctly.",
    button1 = "Reload UI",
    button2 = "Later",
    OnAccept = function()
        ReloadUI()
    end,
    OnCancel = function()
        if AL.MainWindow and AL.MainWindow:IsShown() then
            AL:ToggleMainWindow()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Popup to confirm tracking a newly purchased item
StaticPopupDialogs["AL_CONFIRM_TRACK_NEW_PURCHASE"] = {
    text = "You purchased %s. This item is not in your Ledger. Would you like to add it now to track its financial data?",
    button1 = "Yes, Track Item",
    button2 = "No, Ignore",
    OnAccept = function(self, data)
        if data and data.itemLink and data.itemID and data.price and data.quantity then
            local success, msg = AL:InternalAddItem(data.itemLink, UnitName("player"), GetRealmName(), data.sourceDetails)
            if success then
                -- [[ FIX: Retroactively record the transaction that triggered this popup ]]
                AL:RecordTransaction("BUY", "AUCTION", data.itemID, data.price, data.quantity)
                AL:RefreshLedgerDisplay()
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- NEW: Popup to recommend a reload after an Auto Pricing scan
StaticPopupDialogs["AL_MARKET_SCAN_COMPLETE"] = {
    text = "Auto Pricing scan complete. A UI reload is recommended to ensure all prices are correctly updated in the Ledger and saved permanently.",
    button1 = "Reload UI",
    button2 = "Later",
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- [[ NEW: Popup to confirm tracking a newly purchased vendor item ]]
StaticPopupDialogs["AL_CONFIRM_TRACK_NEW_VENDOR_PURCHASE"] = {
    text = "You purchased %s. This item is not in your Ledger. Would you like to add it now to track its financial data?",
    button1 = "Yes, Track Item",
    button2 = "No, Ignore",
    OnAccept = function(self, data)
        if data and data.itemLink and data.itemID and data.price and data.quantity then
            local success, msg = AL:InternalAddItem(data.itemLink, UnitName("player"), GetRealmName())
            if success then
                -- Now that the item is tracked, record the transaction that triggered this.
                AL:RecordTransaction("BUY", "VENDOR", data.itemID, data.price, data.quantity)
                AL:DebugPrint("Successfully added new vendor item to ledger and recorded transaction: " .. data.itemLink)
                AL:RefreshLedgerDisplay()
            else
                AL:DebugPrint("Failed to add new vendor item to ledger: " .. (msg or "Unknown error"))
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- [[ FIX: Add missing StaticPopupDialogs for Nuke buttons ]]
StaticPopupDialogs["AL_CONFIRM_NUKE_LEDGER"] = {
    text = "Are you sure you want to |cffff0000NUKE|r your entire Ledger and Financial History? Items or sales in your mailbox will NOT be recorded if you choose to nuke your ledger and history. To register them again, you’ll need to add the items to the ledger, post them, and complete the sale. This action is |cffff0000IRREVERSIBLE|r and will delete all tracked items and sales/purchase data.",
    button1 = "NUKE IT ALL",
    button2 = "Cancel",
    OnAccept = function()
        if AL and AL.NukeLedgerAndHistory then
            AL:NukeLedgerAndHistory()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    showAlert = true,
}

StaticPopupDialogs["AL_CONFIRM_NUKE_HISTORY"] = {
    text = "Are you sure you want to |cffff0000NUKE|r only your Financial History (posts, sales, purchases, cancellations, auction finances, and vendor finances)? Your list of tracked items will be preserved. Items or sales in your mailbox will NOT be recorded if you choose to nuke your history. To register them again, you’ll need to add the items to the ledger, post them, and complete the sale. This action is |cffff0000IRREVERSIBLE|r.",
    button1 = "NUKE HISTORY",
    button2 = "Cancel",
    OnAccept = function()
        if AL and AL.NukeHistoryOnly then
            AL:NukeHistoryOnly()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    showAlert = true,
}

-- [[ NEW: Popups for Cancel Undercut feature ]]
StaticPopupDialogs["AL_CONFIRM_CANCEL_UNDERCUT"] = {
    text = "Do you want to scan all of your current auctions to find items that have been undercut? This may take a moment.",
    button1 = "Yes, Scan Auctions",
    button2 = NO,
    OnAccept = function()
        if AL and AL.StartCancelScan then
            AL:StartCancelScan()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

