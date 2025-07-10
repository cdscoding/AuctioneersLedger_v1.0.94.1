-- Auctioneer's Ledger - v1.0.59 - Created by Clint Seewald (CS&A-Software)
-- This file creates the main addon table and initializes all addon-wide variables.

-- Create the main addon table if it doesn't exist
AL = _G.AL or {}
_G.AL = AL

-- Define shared variables on the main AL table to make them globally accessible
AL.ADDON_NAME = "AuctioneersLedger"
AL.LDB_PREFIX = "AuctioneersLedgerDB"
AL.ADDON_MSG_PREFIX = "AL_MSG"

-- Set the addon version
AL.VERSION = "1.0.61"

-- This is the root of the addon's database.
_G.AL_SavedData = _G.AL_SavedData or {}

-- [[ DIRECTIVE: All debug flags disabled for release. ]]
AL.DEBUG_HOOKS = false
AL.DEBUG_INVOICE_TEST = false 

function AL:DebugPrint(message)
    if false then -- Master debug switch. Set to true to re-enable all prints.
        print("|cff00ff00[AL Debug]|r " .. tostring(message))
    end
end

-- This table will cache mail details to prevent processing duplicates.
AL.processedMailIDs = {}

-- Initialize all addon-wide variables to nil or their default empty state.
-- These will be populated by the other addon files as they load.
AL.reminderPopupLastX = nil
AL.reminderPopupLastY = nil
AL.revertPopupTextTimer = nil
AL.itemRowFrames = {}
AL.eventRefreshTimer = nil
AL.eventDebounceCounter = 0
AL.periodicRefreshTimer = nil
AL.addonLoadedProcessed = false
AL.libsReady = false
AL.LDB_Lib = nil
AL.LibDBIcon_Lib = nil
AL.LDBObject = nil
AL.MainWindow = nil
AL.LeftPanel = nil
AL.CreateReminderButton = nil
AL.RefreshListButton = nil
AL.HelpWindowButton = nil
AL.ToggleMinimapButton = nil
AL.SupportMeButton = nil
AL.WarbandStockTab = nil
AL.ProfitLossTab = nil
AL.AuctionPricingTab = nil
AL.AuctionSettingsTab = nil
AL.SortAlphaButton = nil
AL.SortItemNameFlatButton = nil
AL.SortBagsButton = nil
AL.SortBankButton = nil
AL.SortMailButton = nil
AL.SortAuctionButton = nil
AL.SortLimboButton = nil
AL.SortWarbandBankButton = nil
AL.SortReagentBankButton = nil
AL.SortCharacterButton = nil
AL.SortRealmButton = nil
AL.SortLastSellPriceButton = nil
AL.SortLastSellDateButton = nil
AL.SortLastBuyPriceButton = nil
AL.SortLastBuyDateButton = nil
AL.SortTotalProfitButton = nil
AL.SortTotalLossButton = nil
AL.LabelSortBy = nil
AL.LabelFilterLocation = nil
AL.LabelFilterQuality = nil
AL.LabelFilterLedger = nil
AL.LabelFilterStackability = nil
AL.ColumnHeaderFrame = nil
AL.ScrollFrame = nil
AL.ScrollChild = nil
AL.ReminderPopup = nil
AL.HelpWindow = nil
AL.HelpWindowScrollFrame = nil
AL.HelpWindowScrollChild = nil
AL.HelpWindowFontString = nil
AL.SupportWindow = nil
AL.BlasterWindow = nil
AL.testSetScriptControlDone = false
AL.mainDividers = AL.mainDividers or {}
AL.postItemHooked = false
AL.mailAPIsMissingLogged = false
AL.mailRefreshTimer = nil
AL.ahEntryDumpDone = false
AL.gameFullyInitialized = false
AL.warbandEnumWarningShown = false
AL.currentActiveTab = nil 
AL.dataHasChanged = false
AL.pendingPostDetails = nil

-- [[ NEW PURCHASE TRACKING LOGIC ]] --
-- These variables replace the old `lastSelectedItemDetails` system.
AL.previousMoney = 0
AL.lastKnownPurchaseDetails = nil -- Will store { itemLink, quantity }
AL.lastKnownMoneySpent = 0
-- [[ END NEW PURCHASE TRACKING LOGIC ]] --

-- [[ NEW CACHING FOR MAIL PROCESSING ]] --
AL.salesItemCache = {}
AL.salesPendingAuctionCache = {}
-- [[ END NEW CACHING FOR MAIL PROCESSING ]] --

-- Blaster State Variables
AL.itemsToScan = {}
AL.itemBeingScanned = nil
AL.isScanning = false
AL.blasterQueue = {}
AL.itemBeingPosted = nil
AL.isPosting = false 
AL.blasterQueueIsReady = false
AL.PricingData = {}

AL.auctionIDCache = {}

-- Button collections
AL.SortQualityButtons = {}
AL.StackFilterButtons = {}
