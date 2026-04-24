LeafAllianceDB = LeafAllianceDB or {}
LeafAllianceGlobalDB = LeafAllianceGlobalDB or {}

LeafAlliance = LeafAlliance or {}
LeafAlliance.name = "LeafVillageAlliance"
LeafAlliance.prefix = "LeafVE"
LeafAlliance.version = "1.0"
LeafAlliance.isAllianceStandalone = true
LeafAlliance.requestTargets = LeafAlliance.requestTargets or { "Methl" }
_G.LeafAllianceCommAPI = _G.LeafAllianceCommAPI or {}
_G.LeafAllianceCommAPI.version = 1
_G.LeafAllianceCommAPI.tags = _G.LeafAllianceCommAPI.tags or {
  accessRequest = "ACCESSREQ:",
  accessResponse = "ACCESSRESP:",
  rosterRequest = "ROSTERREQ:",
  rosterData = "ROSTERDATA:",
  accessSnapshot = "CFGSYNC:",
}
_G.LeafAllianceCommAPI.transport = "PARTY_ADDON"
LeafAlliance.API = _G.LeafAllianceCommAPI
LeafAlliance.channel = {
  name = "Leaf",
  password = "Leafbiz",
  label = "Leaf Alliance",
  prefixColor = "|cFF73C8FF",
  messageColor = "|cFFFFD10D",
  hiddenPrefix = "~LVA1~",
  controlPrefix = "LVACTL:",
  fieldSep = "<~>",
  rosterMemberSep = "<#>",
}

local SEP = string.char(31)
local BROADCASTER_TTL = 90
local ACCESS_REQUEST_RETRY_INTERVAL = 20
local UI_WIDTH = 980
local UI_HEIGHT = 640
local CLASS_TOKEN_BY_LABEL = {
  deathknight = "DEATHKNIGHT",
  druid = "DRUID",
  hunter = "HUNTER",
  mage = "MAGE",
  paladin = "PALADIN",
  priest = "PRIEST",
  rogue = "ROGUE",
  shaman = "SHAMAN",
  warlock = "WARLOCK",
  warrior = "WARRIOR",
}

local function Trim(text)
  return string.gsub(string.gsub(tostring(text or ""), "^%s+", ""), "%s+$", "")
end

local function Lower(text)
  return string.lower(tostring(text or ""))
end

local function Now()
  return time and time() or 0
end

local function IsInGuildSafe()
  if type(IsInGuild) == "function" then
    return IsInGuild() and true or false
  end
  if type(GetGuildInfo) == "function" then
    return Trim(GetGuildInfo("player") or "") ~= ""
  end
  return false
end

local function ShortName(name)
  local trimmed = Trim(name or "")
  if trimmed == "" then
    return nil
  end
  local dash = string.find(trimmed, "-", 1, true)
  if dash then
    trimmed = string.sub(trimmed, 1, dash - 1)
  end
  return trimmed ~= "" and trimmed or nil
end

local function EncodeField(text)
  local value = tostring(text or "")
  value = string.gsub(value, "\r", " ")
  value = string.gsub(value, "\n", " ")
  value = string.gsub(value, SEP, " ")
  return value
end

local function DecodeField(text)
  return tostring(text or "")
end

local function SplitBySep(text, sep)
  local pieces = {}
  local value = tostring(text or "")
  local actualSep = tostring(sep or SEP)
  if value == "" then
    return pieces
  end

  local startPos = 1
  while true do
    local foundAt = string.find(value, actualSep, startPos, true)
    if not foundAt then
      table.insert(pieces, string.sub(value, startPos))
      break
    end
    table.insert(pieces, string.sub(value, startPos, foundAt - 1))
    startPos = foundAt + string.len(actualSep)
  end
  return pieces
end

local function PrintAlliance(message)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF2DD35CLeaf Alliance:|r " .. tostring(message or ""))
  end
end

local function GetClassColorHex(classLabel)
  local normalized = Lower(classLabel or "")
  normalized = string.gsub(normalized, "%s+", "")
  local classToken = CLASS_TOKEN_BY_LABEL[normalized]
  local classColor = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] or nil
  if classColor and classColor.colorStr and classColor.colorStr ~= "" then
    return "|c" .. tostring(classColor.colorStr)
  end
  return "|cFFEEEEEE"
end

local deferredTasks = {}
local deferredFrame = nil
local deferredSerial = 0

local function RunDeferredTasks()
  if not next(deferredTasks) then
    if this then
      this:SetScript("OnUpdate", nil)
      this:Hide()
    end
    return
  end

  local elapsed = arg1 or 0
  for key, task in pairs(deferredTasks) do
    task.remaining = (task.remaining or 0) - elapsed
    if task.remaining <= 0 then
      deferredTasks[key] = nil
      if type(task.callback) == "function" then
        local ok, err = pcall(task.callback)
        if not ok then
          PrintAlliance("Deferred task error: " .. tostring(err))
        end
      end
    end
  end

  if not next(deferredTasks) and this then
    this:SetScript("OnUpdate", nil)
    this:Hide()
  end
end

function LeafAlliance:Schedule(key, delay, callback)
  if type(callback) ~= "function" then
    return
  end

  if not key then
    deferredSerial = deferredSerial + 1
    key = "anon_" .. tostring(deferredSerial)
  end

  deferredTasks[key] = {
    remaining = tonumber(delay) or 0,
    callback = callback,
  }

  if not deferredFrame then
    deferredFrame = CreateFrame("Frame")
  end
  deferredFrame:SetScript("OnUpdate", RunDeferredTasks)
  deferredFrame:Show()
end

function LeafAlliance:EnsureDB()
  if type(LeafAllianceDB.ui) ~= "table" then LeafAllianceDB.ui = {} end
  if LeafAllianceDB.ui.w == nil then LeafAllianceDB.ui.w = UI_WIDTH end
  if LeafAllianceDB.ui.h == nil then LeafAllianceDB.ui.h = UI_HEIGHT end
  if LeafAllianceDB.ui.selectedGuild == nil then LeafAllianceDB.ui.selectedGuild = "" end
  if LeafAllianceDB.ui.point == nil then LeafAllianceDB.ui.point = "CENTER" end
  if LeafAllianceDB.ui.relativePoint == nil then LeafAllianceDB.ui.relativePoint = "CENTER" end
  if LeafAllianceDB.ui.x == nil then LeafAllianceDB.ui.x = 0 end
  if LeafAllianceDB.ui.y == nil then LeafAllianceDB.ui.y = 0 end
  if LeafAllianceDB.autoJoin == nil then LeafAllianceDB.autoJoin = true end
  if type(LeafAllianceDB.pendingAccessRequest) ~= "table" then LeafAllianceDB.pendingAccessRequest = nil end

  if type(LeafAllianceGlobalDB.chatLog) ~= "table" then LeafAllianceGlobalDB.chatLog = {} end
  if type(LeafAllianceGlobalDB.rosters) ~= "table" then LeafAllianceGlobalDB.rosters = {} end
  if type(LeafAllianceGlobalDB.accessSnapshot) ~= "table" then
    LeafAllianceGlobalDB.accessSnapshot = { updatedAt = 0, guilds = {} }
  end
  if type(LeafAllianceGlobalDB.accessSnapshot.guilds) ~= "table" then
    LeafAllianceGlobalDB.accessSnapshot.guilds = {}
  end
end

function LeafAlliance:GetPendingAccessRequest()
  self:EnsureDB()

  if type(LeafAllianceDB.pendingAccessRequest) ~= "table" then
    return nil
  end

  local request = LeafAllianceDB.pendingAccessRequest
  local guildName = Trim(request.guildName or "")
  if guildName == "" then
    LeafAllianceDB.pendingAccessRequest = nil
    return nil
  end

  request.guildName = guildName
  request.requester = ShortName(request.requester) or ShortName(UnitName("player")) or ""
  request.requestedAt = tonumber(request.requestedAt) or Now()
  request.lastSentAt = tonumber(request.lastSentAt) or 0
  return request
end

function LeafAlliance:SetPendingAccessRequest(guildName)
  self:EnsureDB()

  local trimmedGuild = Trim(guildName or "")
  if trimmedGuild == "" then
    LeafAllianceDB.pendingAccessRequest = nil
    return nil
  end

  local existing = self:GetPendingAccessRequest()
  LeafAllianceDB.pendingAccessRequest = {
    guildName = trimmedGuild,
    requester = ShortName(UnitName("player")) or "",
    requestedAt = existing and tonumber(existing.requestedAt) or Now(),
    lastSentAt = existing and tonumber(existing.lastSentAt) or 0,
  }
  return LeafAllianceDB.pendingAccessRequest
end

function LeafAlliance:ClearPendingAccessRequest()
  self:EnsureDB()
  LeafAllianceDB.pendingAccessRequest = nil
end

function LeafAlliance:GetPlayerGuildName(unitToken)
  local guildName = nil
  if type(GetGuildInfo) == "function" then
    guildName = GetGuildInfo(unitToken or "player")
  end
  return Trim(guildName or "")
end

function LeafAlliance:GetAllianceChannelName()
  return self.channel.name
end

function LeafAlliance:GetAllianceChannelPassword()
  return self.channel.password
end

function LeafAlliance:GetAllianceChannelId()
  if type(GetChannelName) ~= "function" then
    return 0
  end
  local channelId = GetChannelName(self:GetAllianceChannelName())
  return tonumber(channelId) or 0
end

function LeafAlliance:IsAllianceMessageChannel(channelString, channelName, channelNumber)
  local channelTag = Lower(channelName or channelString or "")
  if channelTag == "" and channelNumber then
    channelTag = tostring(channelNumber)
  end
  return string.find(channelTag, Lower(self:GetAllianceChannelName()), 1, true) ~= nil
end

function LeafAlliance:BuildAlliancePlainOutgoingPrefix()
  return "[" .. tostring(self.channel.label or "Leaf Alliance") .. "] "
end

function LeafAlliance:StripAllianceDecorators(message)
  local cleaned = tostring(message or "")
  local hiddenPrefix = self.channel.hiddenPrefix or ""
  if hiddenPrefix ~= "" and string.sub(cleaned, 1, string.len(hiddenPrefix)) == hiddenPrefix then
    return cleaned
  end
  local controlPrefix = self.channel.controlPrefix or ""
  if controlPrefix ~= "" and string.sub(cleaned, 1, string.len(controlPrefix)) == controlPrefix then
    return cleaned
  end
  local plainPrefix = self:BuildAlliancePlainOutgoingPrefix()
  if string.sub(cleaned, 1, string.len(plainPrefix)) == plainPrefix then
    cleaned = string.sub(cleaned, string.len(plainPrefix) + 1)
  end
  return cleaned
end

function LeafAlliance:IsHiddenAllianceControl(message)
  local cleaned = self:StripAllianceDecorators(message)
  local hiddenPrefix = self.channel.hiddenPrefix or ""
  if hiddenPrefix ~= "" and string.sub(cleaned, 1, string.len(hiddenPrefix)) == hiddenPrefix then
    return true
  end
  local controlPrefix = self.channel.controlPrefix or ""
  return controlPrefix ~= "" and string.sub(cleaned, 1, string.len(controlPrefix)) == controlPrefix
end

function LeafAlliance:SuppressSystemMessage(message)
  local text = Lower(tostring(message or ""))
  local channelName = Lower(self:GetAllianceChannelName())
  if channelName == "" then
    return false
  end
  if string.find(text, channelName, 1, true) == nil then
    return false
  end
  if string.find(text, "joined channel", 1, true)
    or string.find(text, "left channel", 1, true)
    or string.find(text, "owner changed to", 1, true)
    or string.find(text, "changed owner to", 1, true)
    or string.find(text, "channel owner", 1, true) then
    return true
  end
  return false
end

function LeafAlliance:StripRenderedMarkup(text)
  local cleaned = tostring(text or "")
  cleaned = string.gsub(cleaned, "|c%x%x%x%x%x%x%x%x", "")
  cleaned = string.gsub(cleaned, "|r", "")
  cleaned = string.gsub(cleaned, "|H.-|h", "")
  cleaned = string.gsub(cleaned, "|h", "")
  return cleaned
end

function LeafAlliance:TryFormatRenderedAllianceText(text)
  local rendered = tostring(text or "")
  if rendered == "" then
    return nil
  end

  local renderedPlain = self:StripRenderedMarkup(rendered)
  local channelTag, author = string.match(renderedPlain, "^%[([^%]]+)%]%s*%[([^%]]+)%]:")
  if not channelTag then
    channelTag, author = string.match(renderedPlain, "^%[([^%]]+)%]%s*([^:]+):")
  end
  if not channelTag or not author then
    return nil
  end

  if string.find(Lower(channelTag), Lower(self:GetAllianceChannelName()), 1, true) == nil then
    return nil
  end

  local separatorStart, separatorEnd = string.find(rendered, ": ", 1, true)
  if not separatorEnd then
    return nil
  end

  local displayAuthor = ShortName(author) or Trim(author or "")
  if displayAuthor == "" then
    displayAuthor = "Unknown"
  end

  local message = string.sub(rendered, separatorEnd + 1)
  local prefixColor = tostring((self.channel and self.channel.prefixColor) or "|cFF73C8FF")
  local messageColor = tostring((self.channel and self.channel.messageColor) or "|cFFFFD10D")
  return prefixColor .. "[" .. tostring(self.channel.label or "Leaf Alliance") .. "] [" .. displayAuthor .. "]: |r"
    .. messageColor .. tostring(message or "") .. "|r"
end

function LeafAlliance:WrapChatFrame(frame)
  if type(frame) ~= "table" or type(frame.AddMessage) ~= "function" or frame.leafAllianceWrapped then
    return
  end

  frame.leafAllianceOriginalAddMessage = frame.AddMessage
  frame.AddMessage = function(selfFrame, text, r, g, b, chatTypeID, holdTime, accessID, lineID)
    local rendered = LeafAlliance:StripRenderedMarkup(text)
    if LeafAlliance:IsHiddenAllianceControl(rendered) then
      return
    end
    if LeafAlliance:SuppressSystemMessage(rendered) then
      return
    end
    local formatted = LeafAlliance:TryFormatRenderedAllianceText(text)
    if formatted then
      return selfFrame.leafAllianceOriginalAddMessage(selfFrame, formatted, r, g, b, chatTypeID, holdTime, accessID, lineID)
    end
    return selfFrame.leafAllianceOriginalAddMessage(selfFrame, text, r, g, b, chatTypeID, holdTime, accessID, lineID)
  end
  frame.leafAllianceWrapped = true
end

function LeafAlliance:InstallRenderedSuppression()
  if self.renderedSuppressionInstalled then
    return
  end

  local totalFrames = tonumber(NUM_CHAT_WINDOWS) or 7
  for i = 1, totalFrames do
    self:WrapChatFrame(_G["ChatFrame" .. tostring(i)])
  end
  self:WrapChatFrame(DEFAULT_CHAT_FRAME)
  self:WrapChatFrame(SELECTED_CHAT_FRAME)
  self.renderedSuppressionInstalled = true
end

function LeafAlliance:InstallChatSuppression()
  if self.chatSuppressionInstalled and ChatFrame_MessageEventHandler == self.wrappedChatHandler then
    return
  end
  if type(ChatFrame_MessageEventHandler) ~= "function" then
    return
  end

  self.chatSuppressionInstalled = true
  self.originalChatHandler = ChatFrame_MessageEventHandler
  self.wrappedChatHandler = function(...)
    local args = {n = select("#", ...), ...}
    local eventName
    local message
    local channelString
    local channelNumber
    local channelName

    if type(args[1]) == "table" and args[1].AddMessage then
      eventName = args[2]
      message = args[3]
      channelString = args[6]
      channelNumber = args[10]
      channelName = args[11]
    else
      eventName = args[1]
      message = args[2]
      channelString = args[5]
      channelNumber = args[9]
      channelName = args[10]
    end

    if eventName == "CHAT_MSG_CHANNEL" and LeafAlliance:IsAllianceMessageChannel(channelString, channelName, channelNumber) then
      if LeafAlliance:IsHiddenAllianceControl(message) then
        return
      end
      if not LeafAlliance:IsAuthorizedGuild(LeafAlliance:GetPlayerGuildName("player")) then
        return
      end
    end

    if (eventName == "CHAT_MSG_CHANNEL_NOTICE" or eventName == "CHAT_MSG_CHANNEL_NOTICE_USER" or eventName == "CHAT_MSG_SYSTEM") and LeafAlliance:SuppressSystemMessage(message) then
      return
    end

    return LeafAlliance.originalChatHandler(unpack(args, 1, args.n))
  end

  ChatFrame_MessageEventHandler = self.wrappedChatHandler
end

function LeafAlliance:EnsureChannelVisible()
  local channelName = self:GetAllianceChannelName()
  if type(ChatFrame_AddChannel) == "function" then
    local totalFrames = tonumber(NUM_CHAT_WINDOWS) or 7
    for i = 1, totalFrames do
      local frame = _G["ChatFrame" .. tostring(i)]
      if frame then
        pcall(ChatFrame_AddChannel, frame, channelName)
      end
    end
    if DEFAULT_CHAT_FRAME then
      pcall(ChatFrame_AddChannel, DEFAULT_CHAT_FRAME, channelName)
    end
    if SELECTED_CHAT_FRAME then
      pcall(ChatFrame_AddChannel, SELECTED_CHAT_FRAME, channelName)
    end
  end
end

function LeafAlliance:OpenAllianceChatInput()
  self:InstallStickyChatHook()
  if not self:IsAuthorizedGuild(self:GetPlayerGuildName("player")) then
    return false, "This guild has not been granted Leaf Alliance access yet."
  end
  local channelId = self:GetAllianceChannelId()
  if channelId <= 0 then
    return false, "Leaf Alliance is not connected yet."
  end
  if ChatTypeInfo and ChatTypeInfo["CHANNEL"] then
    ChatTypeInfo["CHANNEL"].sticky = 1
  end
  local targetFrame = DEFAULT_CHAT_FRAME
  if SELECTED_CHAT_FRAME and SELECTED_CHAT_FRAME.editBox then
    targetFrame = SELECTED_CHAT_FRAME
  end
  local editBox = targetFrame and targetFrame.editBox or nil
  if not editBox then
    return false, "Unable to open the chat input."
  end
  if type(ChatFrame_OpenChat) == "function" then
    ChatFrame_OpenChat("", targetFrame)
  elseif type(ChatEdit_ActivateChat) == "function" then
    ChatEdit_ActivateChat(editBox)
  end
  self.stickyChatEnabled = true
  self:ApplyStickyToEditBox(editBox)
  if type(editBox.SetText) == "function" then
    editBox:SetText("")
  end
  if type(editBox.SetFocus) == "function" then
    editBox:SetFocus()
  end
  return true
end

function LeafAlliance:ApplyStickyToEditBox(editBox)
  local channelId = self:GetAllianceChannelId()
  if channelId <= 0 or not editBox then
    return false
  end
  if ChatTypeInfo and ChatTypeInfo["CHANNEL"] then
    ChatTypeInfo["CHANNEL"].sticky = 1
  end
  editBox.stickyType = "CHANNEL"
  editBox.chatType = "CHANNEL"
  editBox.channelTarget = channelId
  if type(editBox.SetAttribute) == "function" then
    pcall(editBox.SetAttribute, editBox, "stickyType", "CHANNEL")
    pcall(editBox.SetAttribute, editBox, "chatType", "CHANNEL")
    pcall(editBox.SetAttribute, editBox, "channelTarget", channelId)
  end
  if type(ChatEdit_UpdateHeader) == "function" then
    pcall(ChatEdit_UpdateHeader, editBox)
  end
  return true
end

function LeafAlliance:InstallStickyChatHook()
  if self.stickyChatHookInstalled then
    return
  end

  if type(ChatFrame_OpenChat) == "function" then
    self.originalChatFrameOpenChat = self.originalChatFrameOpenChat or ChatFrame_OpenChat
    if ChatFrame_OpenChat ~= self.wrappedChatFrameOpenChat then
      self.wrappedChatFrameOpenChat = function(text, chatFrame)
        local result = { LeafAlliance.originalChatFrameOpenChat(text, chatFrame) }
        if LeafAlliance and LeafAlliance.stickyChatEnabled and (text == nil or text == "") then
          local targetFrame = chatFrame or SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
          local editBox = targetFrame and targetFrame.editBox or nil
          if editBox then
            LeafAlliance:ApplyStickyToEditBox(editBox)
          end
        end
        return unpack(result)
      end
      ChatFrame_OpenChat = self.wrappedChatFrameOpenChat
    end
  end

  if type(ChatEdit_ActivateChat) == "function" then
    self.originalChatEditActivate = self.originalChatEditActivate or ChatEdit_ActivateChat
    if ChatEdit_ActivateChat ~= self.wrappedChatEditActivate then
      self.wrappedChatEditActivate = function(editBox)
        local result = { LeafAlliance.originalChatEditActivate(editBox) }
        if LeafAlliance and LeafAlliance.stickyChatEnabled and editBox then
          LeafAlliance:ApplyStickyToEditBox(editBox)
        end
        return unpack(result)
      end
      ChatEdit_ActivateChat = self.wrappedChatEditActivate
    end
  end

  self.stickyChatHookInstalled = true
end

function LeafAlliance:SendAllianceSystemMessage(message)
  local channelId = self:GetAllianceChannelId()
  if channelId <= 0 or type(SendChatMessage) ~= "function" then
    return false
  end
  SendChatMessage(message, "CHANNEL", nil, channelId)
  return true
end

function LeafAlliance:SendAllianceControlMessage(prefix, fields)
  local channelId = self:GetAllianceChannelId()
  if channelId <= 0 or type(SendChatMessage) ~= "function" then
    return false
  end
  local prefixText = tostring(prefix or "")
  if prefixText ~= "ACCESSREQ:" and not self:IsAuthorizedGuild(self:GetPlayerGuildName("player")) then
    return false
  end

  local payload = prefixText
  if type(fields) == "table" and table.getn(fields) > 0 then
    payload = payload .. table.concat(fields, (self.channel and self.channel.fieldSep) or SEP)
  end
  local hiddenPrefix = (self.channel and self.channel.hiddenPrefix) or ""
  SendChatMessage(hiddenPrefix .. payload, "CHANNEL", nil, channelId)
  return true
end

function LeafAlliance:RequestAccessSnapshot()
  return false
end

function LeafAlliance:BroadcastLocalAccessState(state, guildName)
  local trimmedState = Lower(Trim(state or ""))
  local trimmedGuild = Trim(guildName or "")
  if trimmedState == "" or trimmedGuild == "" or type(SendAddonMessage) ~= "function" then
    return false
  end
  SendAddonMessage(self.prefix, "ALLYSTATE:" .. EncodeField(trimmedState) .. SEP .. EncodeField(trimmedGuild), "GUILD")
  return true
end

function LeafAlliance:LeaveAllianceChannel()
  local channelName = self:GetAllianceChannelName()
  if type(LeaveChannelByName) == "function" then
    pcall(LeaveChannelByName, channelName)
  end
  self.allianceChannelId = 0
  self.stickyChatEnabled = false
  if self.UI and self.UI.Refresh then
    self.UI:Refresh()
  end
  return true
end

function LeafAlliance:GetAccessRequestTargets()
  local targets = {}
  local seen = {}
  for i = 1, table.getn(self.requestTargets or {}) do
    local target = ShortName(self.requestTargets[i])
    local lowerTarget = Lower(target or "")
    if target and lowerTarget ~= "" and not seen[lowerTarget] then
      seen[lowerTarget] = true
      table.insert(targets, target)
    end
  end
  return targets
end

function LeafAlliance:GetAllianceAccessAddonChatType()
  local raidCount = type(GetNumRaidMembers) == "function" and tonumber(GetNumRaidMembers()) or 0
  if raidCount and raidCount > 0 then
    return "RAID"
  end

  local partyCount = type(GetNumPartyMembers) == "function" and tonumber(GetNumPartyMembers()) or 0
  if partyCount and partyCount > 0 then
    return "PARTY"
  end

  return nil
end

function LeafAlliance:IsAccessRequestTargetInGroup()
  local targets = self:GetAccessRequestTargets()
  if table.getn(targets) < 1 then
    return false
  end

  local seenTargets = {}
  for i = 1, table.getn(targets) do
    local target = Lower(ShortName(targets[i]) or "")
    if target ~= "" then
      seenTargets[target] = true
    end
  end

  local raidCount = type(GetNumRaidMembers) == "function" and tonumber(GetNumRaidMembers()) or 0
  if raidCount and raidCount > 0 and type(GetRaidRosterInfo) == "function" then
    for i = 1, raidCount do
      local name = GetRaidRosterInfo(i)
      local lowerName = Lower(ShortName(name) or "")
      if lowerName ~= "" and seenTargets[lowerName] then
        return true
      end
    end
  end

  local partyCount = type(GetNumPartyMembers) == "function" and tonumber(GetNumPartyMembers()) or 0
  if partyCount and partyCount > 0 then
    for i = 1, partyCount do
      local lowerName = Lower(ShortName(UnitName("party" .. tostring(i))) or "")
      if lowerName ~= "" and seenTargets[lowerName] then
        return true
      end
    end
  end

  return false
end

function LeafAlliance:SendAllianceGroupAddonMessage(payload)
  local chatType = self:GetAllianceAccessAddonChatType()
  if chatType == nil or type(SendAddonMessage) ~= "function" then
    return false, 0
  end

  local maxPayloadLength = math.max(1, 254 - string.len(tostring(self.prefix or "")))
  if string.len(tostring(payload or "")) > maxPayloadLength then
    PrintAlliance("Alliance addon payload was too large for 3.3.5 and was skipped.")
    return false, 0
  end

  SendAddonMessage(self.prefix, payload, chatType)
  return true, 1
end

function LeafAlliance:SendAccessRequestGroupMessage(request)
  if type(request) ~= "table" then
    return false, 0
  end

  local guildName = Trim(request.guildName or "")
  if guildName == "" then
    return false, 0
  end

  if not self:IsAccessRequestTargetInGroup() then
    return false, 0
  end

  local fieldSep = (self.channel and self.channel.fieldSep) or SEP
  local payload = "ACCESSREQ:" .. table.concat({
    EncodeField(guildName),
    EncodeField(request.requester or ""),
    tostring(tonumber(request.requestedAt) or Now()),
  }, fieldSep)

  local ok, sentCount = self:SendAllianceGroupAddonMessage(payload)
  if ok then
    request.lastSentAt = Now()
    return true, sentCount
  end
  return false, 0
end

function LeafAlliance:SendAllianceAccessRequest(guildName, retryCount)
  local homeGuild = Trim(self:GetPlayerGuildName("player") or "")
  local trimmedGuild = Trim(guildName or "")
  if homeGuild == "" then
    return false, "You must be in a guild to request access."
  end
  if trimmedGuild == "" then
    return false, "Enter your guild name first."
  end
  if Lower(trimmedGuild) ~= Lower(homeGuild) then
    return false, "Guild name must match your current guild."
  end
  if self:IsAuthorizedGuild(homeGuild) then
    return false, "This guild already has Leaf Alliance access."
  end
  if not self:IsAccessRequestTargetInGroup() then
    return false, "You must be grouped with Methl to request access."
  end
  if self:GetAllianceAccessAddonChatType() == nil then
    return false, "You must be in a party or raid with Methl."
  end

  self:SetPendingAccessRequest(trimmedGuild)
  local ok = self:SendAccessRequestGroupMessage(LeafAllianceDB.pendingAccessRequest)
  if self.UI and self.UI.Refresh then
    self.UI:Refresh()
  end
  if ok then
    return true, "Access request sent through party chat."
  end
  return false, "Unable to reach your current party right now."
end

function LeafAlliance:MaybeSendPendingAccessRequest(force)
  local request = self:GetPendingAccessRequest()
  if not request then
    return false
  end

  local homeGuild = Trim(self:GetPlayerGuildName("player") or "")
  if homeGuild == "" then
    self:ClearPendingAccessRequest()
    return false
  end
  if self:IsAuthorizedGuild(homeGuild) then
    self:ClearPendingAccessRequest()
    return false
  end

  if Lower(request.guildName) ~= Lower(homeGuild) then
    request.guildName = homeGuild
  end
  if self.UI and self.UI.panel and self.UI.panel.statusText then
    self.UI.panel.statusText:SetText("|cFFFFD700Pending Leaf approval.|r")
  end
  return false, 0
end

function LeafAlliance:SendAllianceChannelAccessRequest(request)
  if type(request) ~= "table" then
    return false
  end

  local guildName = Trim(request.guildName or "")
  if guildName == "" then
    return false
  end

  local channelId = self:GetAllianceChannelId()
  if channelId <= 0 then
    if type(JoinChannelByName) ~= "function" then
      return false
    end
    JoinChannelByName(self:GetAllianceChannelName(), self:GetAllianceChannelPassword())
    self:Schedule("leafalliance_accessreq_after_join", 0.8, function()
      local pending = LeafAlliance:GetPendingAccessRequest()
      if pending then
        LeafAlliance:SendAllianceChannelAccessRequest(pending)
      end
    end)
    return true
  end
  return self:SendAllianceControlMessage("ACCESSREQ:", {
    EncodeField(guildName),
    EncodeField(request.requester or ""),
    tostring(tonumber(request.requestedAt) or Now()),
  })
end

function LeafAlliance:FinalizeAllianceJoin(channelId, announce, openInput)
  channelId = tonumber(channelId) or self:GetAllianceChannelId()
  if channelId <= 0 then
    return false
  end

  self.allianceChannelId = channelId
  self:EnsureChannelVisible()
  self:InstallChatSuppression()

  if announce then
    PrintAlliance("Joined Leaf Alliance [" .. self:GetAllianceChannelName() .. "]")
  end
  if openInput then
    self:OpenAllianceChatInput()
  end
  return true
end

function LeafAlliance:JoinAllianceChannel(openInput, announce)
  self:EnsureDB()
  self:InstallChatSuppression()

  if not self:IsAuthorizedGuild(self:GetPlayerGuildName("player")) then
    return false
  end

  local channelId = self:GetAllianceChannelId()
  if channelId > 0 then
    return self:FinalizeAllianceJoin(channelId, announce, openInput)
  end

  if type(JoinChannelByName) ~= "function" then
    return false
  end

  JoinChannelByName(self:GetAllianceChannelName(), self:GetAllianceChannelPassword())
  self.pendingOpenInput = openInput and true or false
  self.pendingAnnounceJoin = announce and true or false

  self:Schedule("leafalliance_join_retry", 0.8, function()
    local joinedId = LeafAlliance:GetAllianceChannelId()
    local shouldOpen = LeafAlliance.pendingOpenInput and true or false
    local shouldAnnounce = LeafAlliance.pendingAnnounceJoin and true or false
    LeafAlliance.pendingOpenInput = nil
    LeafAlliance.pendingAnnounceJoin = nil

    if joinedId > 0 then
      LeafAlliance:FinalizeAllianceJoin(joinedId, shouldAnnounce, shouldOpen)
    elseif shouldAnnounce then
      PrintAlliance("Unable to join Leaf Alliance.")
    end
  end)

  return true
end

function LeafAlliance:GetAccessSnapshot()
  self:EnsureDB()
  return LeafAllianceGlobalDB.accessSnapshot
end

function LeafAlliance:SetAccessSnapshot(updatedAt, guilds, source)
  self:EnsureDB()
  local homeGuild = self:GetPlayerGuildName("player")
  local wasAuthorized = self:IsAuthorizedGuild(homeGuild)

  local normalized = {}
  local seen = {}
  for i = 1, table.getn(guilds or {}) do
    local guildName = Trim(guilds[i] or "")
    local lowerName = Lower(guildName)
    if guildName ~= "" and not seen[lowerName] then
      seen[lowerName] = true
      table.insert(normalized, guildName)
    end
  end
  table.sort(normalized, function(a, b) return Lower(a or "") < Lower(b or "") end)

  LeafAllianceGlobalDB.accessSnapshot = {
    updatedAt = tonumber(updatedAt) or Now(),
    guilds = normalized,
  }

  local isAuthorized = self:IsAuthorizedGuild(homeGuild)
  if isAuthorized and not wasAuthorized then
    self:ClearPendingAccessRequest()
    if source ~= "guild" and homeGuild ~= "" then
      self:BroadcastLocalAccessState("approved", homeGuild)
    end
    if LeafAllianceDB.autoJoin ~= false then
      self:JoinAllianceChannel(false, false)
    end
    self:Schedule("leafalliance_initial_roster_sync", 1.0, function()
      LeafAlliance:SendInitialRosterSync()
    end)
  elseif isAuthorized then
    self:ClearPendingAccessRequest()
  elseif wasAuthorized and not isAuthorized then
    self:ClearPendingAccessRequest()
    if source ~= "guild" and homeGuild ~= "" then
      self:BroadcastLocalAccessState("removed", homeGuild)
    end
    self:LeaveAllianceChannel()
  end
end

function LeafAlliance:BuildApprovedAccessGuildList(primaryGuild)
  local guilds = {}
  local seen = {}

  local function addGuild(name)
    local trimmed = Trim(name or "")
    local lowerName = Lower(trimmed)
    if trimmed ~= "" and not seen[lowerName] then
      seen[lowerName] = true
      table.insert(guilds, trimmed)
    end
  end

  addGuild("Leaf Village")
  addGuild(primaryGuild)

  return guilds
end

function LeafAlliance:IsAuthorizedGuild(guildName)
  local trimmedGuild = Trim(guildName or "")
  if trimmedGuild == "" then
    return false
  end

  local snapshot = self:GetAccessSnapshot()
  for i = 1, table.getn(snapshot.guilds or {}) do
    if Lower(snapshot.guilds[i] or "") == Lower(trimmedGuild) then
      return true
    end
  end
  return false
end

function LeafAlliance:GetVisibleGuilds()
  if not self:IsAuthorizedGuild(self:GetPlayerGuildName("player")) then
    return {}
  end
  local snapshot = self:GetAccessSnapshot()
  local guilds = {}
  for i = 1, table.getn(snapshot.guilds or {}) do
    table.insert(guilds, snapshot.guilds[i])
  end
  return guilds
end

function LeafAlliance:SetRosterSnapshot(guildName, updatedAt, members, sourcePlayer)
  self:EnsureDB()

  local trimmedGuild = Trim(guildName or "")
  if trimmedGuild == "" then
    return false
  end

  local normalizedMembers = {}
  for i = 1, table.getn(members or {}) do
    local member = members[i]
    if type(member) == "table" and Trim(member.name or "") ~= "" then
      table.insert(normalizedMembers, {
        name = ShortName(member.name) or Trim(member.name or ""),
        rank = Trim(member.rank or ""),
        level = tonumber(member.level) or 0,
        classLabel = Trim(member.classLabel or member.classTag or "Unknown"),
      })
    end
  end

  table.sort(normalizedMembers, function(a, b) return Lower(a.name or "") < Lower(b.name or "") end)

  LeafAllianceGlobalDB.rosters[Lower(trimmedGuild)] = {
    guildName = trimmedGuild,
    updatedAt = tonumber(updatedAt) or Now(),
    sourcePlayer = ShortName(sourcePlayer) or "",
    onlineCount = table.getn(normalizedMembers),
    members = normalizedMembers,
  }
  return true
end

function LeafAlliance:GetRosterSnapshot(guildName)
  self:EnsureDB()
  return LeafAllianceGlobalDB.rosters[Lower(Trim(guildName or ""))] or nil
end

function LeafAlliance:ResolveGuildForPlayer(playerName)
  local shortName = ShortName(playerName)
  if not shortName then
    return ""
  end

  for _, snapshot in pairs(LeafAllianceGlobalDB.rosters or {}) do
    if type(snapshot) == "table" and type(snapshot.members) == "table" then
      for i = 1, table.getn(snapshot.members) do
        local member = snapshot.members[i]
        if member and Lower(member.name or "") == Lower(shortName) then
          return snapshot.guildName or ""
        end
      end
    end
  end
  return ""
end

function LeafAlliance:BuildLocalRosterSnapshot()
  local guildName = self:GetPlayerGuildName("player")
  if guildName == "" then
    return nil
  end

  local members = {}
  if type(GuildRoster) == "function" then
    GuildRoster()
  end

  local count = GetNumGuildMembers and GetNumGuildMembers() or 0
  for i = 1, count do
    local name, rank, rankIndex, level, class, zone, note, officernote, online = GetGuildRosterInfo(i)
    local shortName = ShortName(name)
    local isOnline = false
    if online then
      if type(online) == "number" then
        isOnline = online == 1
      else
        isOnline = online == true
      end
    end
    if shortName and isOnline then
      table.insert(members, {
        name = shortName,
        rank = rank or "",
        level = tonumber(level) or 0,
        classLabel = Trim(class or "Unknown"),
      })
    end
  end

  table.sort(members, function(a, b)
    local aRank = tostring(a.rank or "")
    local bRank = tostring(b.rank or "")
    if aRank == bRank then
      return Lower(a.name or "") < Lower(b.name or "")
    end
    return aRank < bRank
  end)

  return {
    guildName = guildName,
    updatedAt = Now(),
    members = members,
    onlineCount = table.getn(members),
  }
end

function LeafAlliance:BuildRosterHash(snapshot)
  if type(snapshot) ~= "table" then
    return ""
  end

  local parts = {
    tostring(snapshot.guildName or ""),
    tostring(snapshot.onlineCount or 0),
  }
  for i = 1, table.getn(snapshot.members or {}) do
    local member = snapshot.members[i]
    table.insert(parts, table.concat({
      tostring(member.name or ""),
      tostring(member.rank or ""),
      tostring(member.level or 0),
      tostring(member.classLabel or ""),
    }, ":"))
  end
  return table.concat(parts, "|")
end

function LeafAlliance:RecordBroadcasterPeer(playerName, seenAt)
  local shortName = ShortName(playerName)
  if not shortName then
    return
  end
  self.broadcasterPeers = self.broadcasterPeers or {}
  self.broadcasterPeers[Lower(shortName)] = {
    name = shortName,
    seenAt = tonumber(seenAt) or Now(),
  }
end

function LeafAlliance:PruneBroadcasterPeers()
  self.broadcasterPeers = self.broadcasterPeers or {}
  local now = Now()
  for lowerName, entry in pairs(self.broadcasterPeers) do
    local seenAt = type(entry) == "table" and tonumber(entry.seenAt or 0) or 0
    if seenAt <= 0 or (now - seenAt) > BROADCASTER_TTL then
      self.broadcasterPeers[lowerName] = nil
    end
  end
end

function LeafAlliance:BroadcastPresence(force)
  return false
end

function LeafAlliance:GetBroadcasterName()
  self:PruneBroadcasterPeers()

  local candidates = {}
  local me = ShortName(UnitName("player"))
  if me then
    table.insert(candidates, me)
  end
  for _, entry in pairs(self.broadcasterPeers or {}) do
    if entry and entry.name and (not me or Lower(entry.name) ~= Lower(me)) then
      table.insert(candidates, entry.name)
    end
  end
  if table.getn(candidates) == 0 then
    return me
  end

  table.sort(candidates, function(a, b) return Lower(a or "") < Lower(b or "") end)
  return candidates[1]
end

function LeafAlliance:IsBroadcaster()
  local me = ShortName(UnitName("player"))
  local broadcaster = self:GetBroadcasterName()
  return me ~= nil and broadcaster ~= nil and Lower(me) == Lower(broadcaster)
end

function LeafAlliance:BroadcastRosterSnapshot(force)
  local snapshot = self:BuildLocalRosterSnapshot()
  if not snapshot then
    return false
  end

  local now = Now()
  self.lastRosterBroadcastAt = tonumber(self.lastRosterBroadcastAt or 0)
  if not force and (now - self.lastRosterBroadcastAt) < 30 then
    return false
  end

  local snapshotHash = self:BuildRosterHash(snapshot)
  if not force and snapshotHash ~= "" and snapshotHash == (self.lastRosterBroadcastHash or "") then
    return false
  end

  self.lastRosterBroadcastAt = now
  local didSend = self:SendInitialRosterSync()
  if didSend then
    self.lastRosterBroadcastHash = snapshotHash
  end
  return didSend
end

function LeafAlliance:RequestRosterSnapshot(guildName, force)
  local trimmedGuild = Trim(guildName or "")
  if trimmedGuild == "" then
    return false
  end

  local lowerGuild = Lower(trimmedGuild)
  local now = Now()
  self.lastRosterRequestAt = self.lastRosterRequestAt or {}
  if not force and (now - tonumber(self.lastRosterRequestAt[lowerGuild] or 0)) < 20 then
    return false
  end

  self.lastRosterRequestAt[lowerGuild] = now
  local fields = {
    EncodeField(trimmedGuild),
    tostring(now),
  }
  if self:IsAccessRequestTargetInGroup() and self:GetAllianceAccessAddonChatType() ~= nil then
    return self:SendAllianceGroupAddonMessage("ROSTERREQ:" .. table.concat(fields, (self.channel and self.channel.fieldSep) or SEP))
  end
  return self:SendAllianceControlMessage("ROSTERREQ:", fields)
end

function LeafAlliance:MaybeBroadcastRoster(force)
  return self:BroadcastRosterSnapshot(force)
end

function LeafAlliance:SendInitialRosterSync()
  local snapshot = self:BuildLocalRosterSnapshot()
  if not snapshot then
    return false
  end

  local fieldSep = (self.channel and self.channel.fieldSep) or SEP
  local memberSep = (self.channel and self.channel.rosterMemberSep) or "<#>"
  local useGroupTransport = self:IsAccessRequestTargetInGroup() and self:GetAllianceAccessAddonChatType() ~= nil
  local chunks = {}
  local currentChunk = ""
  local maxPayloadLength = math.max(1, 254 - string.len(tostring(self.prefix or "")))
  local headerReserve = string.len("ROSTERDATA:")
    + string.len(EncodeField(snapshot.guildName or ""))
    + string.len(tostring(tonumber(snapshot.updatedAt) or Now()))
    + 20
  local maxChunkPayload = math.max(60, maxPayloadLength - headerReserve)

  for i = 1, table.getn(snapshot.members or {}) do
    local member = snapshot.members[i]
    local memberPayload = table.concat({
      EncodeField(member.name or ""),
      EncodeField(member.rank or ""),
      tostring(member.level or 0),
      EncodeField(member.classLabel or "Unknown"),
    }, fieldSep)
    local combined = currentChunk
    if combined ~= "" then
      combined = combined .. memberSep .. memberPayload
    else
      combined = memberPayload
    end
    if currentChunk ~= "" and string.len(combined) > maxChunkPayload then
      table.insert(chunks, currentChunk)
      currentChunk = memberPayload
    else
      currentChunk = combined
    end
  end

  if currentChunk ~= "" then
    table.insert(chunks, currentChunk)
  end
  if table.getn(chunks) < 1 then
    table.insert(chunks, "")
  end

  local totalChunks = table.getn(chunks)
  local updatedAt = tonumber(snapshot.updatedAt) or Now()
  local didSend = false
  for i = 1, totalChunks do
    local fields = {
      EncodeField(snapshot.guildName or ""),
      tostring(updatedAt),
      tostring(i),
      tostring(totalChunks),
      chunks[i] or "",
    }
    local ok
    if useGroupTransport then
      ok = self:SendAllianceGroupAddonMessage("ROSTERDATA:" .. table.concat(fields, fieldSep))
    else
      ok = self:SendAllianceControlMessage("ROSTERDATA:", fields)
    end
    didSend = ok or didSend
  end

  if didSend then
    self:SetRosterSnapshot(snapshot.guildName, updatedAt, snapshot.members, UnitName("player"))
  end
  return didSend
end

function LeafAlliance:RecordAllianceChatMessage(author, message, timestamp)
  self:EnsureDB()
  if not self:IsAuthorizedGuild(self:GetPlayerGuildName("player")) then
    return false
  end

  if self:IsHiddenAllianceControl(message) then
    return false
  end

  local cleaned = Trim(self:StripAllianceDecorators(message))
  if cleaned == "" then
    return false
  end

  table.insert(LeafAllianceGlobalDB.chatLog, {
    author = ShortName(author) or Trim(author or "Unknown"),
    guildName = self:ResolveGuildForPlayer(author),
    message = cleaned,
    timestamp = tonumber(timestamp) or Now(),
  })
  while table.getn(LeafAllianceGlobalDB.chatLog) > 200 do
    table.remove(LeafAllianceGlobalDB.chatLog, 1)
  end

  if self.UI and self.UI.RefreshChatHistory then
    self.UI:RefreshChatHistory(true)
  end
  return true
end

function LeafAlliance:GetChatLog()
  self:EnsureDB()
  return LeafAllianceGlobalDB.chatLog
end

function LeafAlliance:BuildChatLine(author, message, timestamp, guildName)
  local timeText = date("%H:%M", tonumber(timestamp) or Now())
  local displayAuthor = Trim(author or "")
  local displayMessage = Trim(message or "")
  local guildText = Trim(guildName or "")

  if displayAuthor == "" then
    displayAuthor = "Unknown"
  end
  if guildText == "" then
    guildText = self:ResolveGuildForPlayer(displayAuthor) or ""
  end
  if guildText == "" then
    guildText = "Unknown Guild"
  end

  return "|cFF888888[" .. timeText .. "]|r: |cFFFFD700" .. displayAuthor .. "|r: |cFF88CC88" .. guildText .. "|r: "
    .. tostring((self.channel and self.channel.messageColor) or "|cFFFFD10D") .. displayMessage .. "|r"
end

function LeafAlliance:HandleControlMessage(author, message)
  local cleaned = self:StripAllianceDecorators(message)
  if not self:IsHiddenAllianceControl(cleaned) then
    return false
  end

  local hiddenPrefix = self.channel.hiddenPrefix or ""
  local controlPrefix = self.channel.controlPrefix or ""
  local payload = nil
  if hiddenPrefix ~= "" and string.sub(cleaned, 1, string.len(hiddenPrefix)) == hiddenPrefix then
    payload = string.sub(cleaned, string.len(hiddenPrefix) + 1)
  elseif controlPrefix ~= "" and string.sub(cleaned, 1, string.len(controlPrefix)) == controlPrefix then
    payload = string.sub(cleaned, string.len(controlPrefix) + 1)
  else
    return false
  end

  local fieldSep = (self.channel and self.channel.fieldSep) or SEP

  if string.sub(payload, 1, 10) == "ROSTERREQ:" then
    local fields = SplitBySep(string.sub(payload, 11), fieldSep)
    local requestedGuild = DecodeField(fields[1] or "")
    local homeGuild = self:GetPlayerGuildName("player")
    if requestedGuild ~= "" and homeGuild ~= "" and Lower(requestedGuild) == Lower(homeGuild) and self:IsAuthorizedGuild(homeGuild) and self:IsBroadcaster() then
      self:Schedule("leafalliance_roster_request_" .. Lower(homeGuild), 1.0, function()
        LeafAlliance:MaybeBroadcastRoster(true)
      end)
    end
    return true
  end

  if string.sub(payload, 1, 11) == "ROSTERDATA:" then
    local fields = SplitBySep(string.sub(payload, 12), fieldSep)
    local guildName = DecodeField(fields[1] or "")
    local updatedAt = tonumber(fields[2]) or 0
    local chunkIndex = tonumber(fields[3]) or 1
    local totalChunks = tonumber(fields[4]) or 1
    local payloadChunk = ""
    if table.getn(fields) >= 5 then
      payloadChunk = table.concat(fields, fieldSep, 5)
    end
    local lowerGuild = Lower(guildName)
    if lowerGuild ~= "" then
      self.pendingRosterSyncs = self.pendingRosterSyncs or {}
      local pending = self.pendingRosterSyncs[lowerGuild]
      if type(pending) ~= "table" or tonumber(pending.updatedAt or 0) ~= updatedAt then
        pending = {
          guildName = guildName,
          updatedAt = updatedAt,
          sourcePlayer = ShortName(author) or "",
          totalChunks = totalChunks,
          chunks = {},
        }
        self.pendingRosterSyncs[lowerGuild] = pending
      end
      pending.totalChunks = totalChunks
      pending.chunks[chunkIndex] = payloadChunk

      local received = 0
      for i = 1, totalChunks do
        if pending.chunks[i] ~= nil then
          received = received + 1
        end
      end

      if received >= totalChunks then
        local members = {}
        local memberSep = (self.channel and self.channel.rosterMemberSep) or "<#>"
        for i = 1, totalChunks do
          local chunkText = pending.chunks[i] or ""
          if chunkText ~= "" then
            local entries = SplitBySep(chunkText, memberSep)
            for entryIndex = 1, table.getn(entries) do
              local memberFields = SplitBySep(entries[entryIndex] or "", fieldSep)
              if Trim(memberFields[1] or "") ~= "" then
                table.insert(members, {
                  name = DecodeField(memberFields[1] or ""),
                  rank = DecodeField(memberFields[2] or ""),
                  level = tonumber(memberFields[3]) or 0,
                  classLabel = DecodeField(memberFields[4] or "Unknown"),
                })
              end
            end
          end
        end
        self:SetRosterSnapshot(pending.guildName, pending.updatedAt, members, pending.sourcePlayer)
        self.pendingRosterSyncs[lowerGuild] = nil
        if self.UI and self.UI.Refresh then
          self.UI:Refresh()
        end
      end
    end
    return true
  end

  if string.sub(payload, 1, 11) == "ACCESSRESP:" then
    local fields = SplitBySep(string.sub(payload, 12), fieldSep)
    local guildName = DecodeField(fields[1] or "")
    local decision = Lower(DecodeField(fields[2] or ""))
    local homeGuild = self:GetPlayerGuildName("player")
    if guildName ~= "" and homeGuild ~= "" and Lower(guildName) == Lower(homeGuild) then
      if decision == "approved" then
        self:ClearPendingAccessRequest()
        PrintAlliance("Leaf Village approved your guild for Leaf Alliance.")
        self:SetAccessSnapshot(Now(), self:BuildApprovedAccessGuildList(guildName), "decision")
      elseif decision == "denied" then
        self:ClearPendingAccessRequest()
        PrintAlliance("Leaf Village denied this guild's Leaf Alliance request.")
        self:BroadcastLocalAccessState("denied", guildName)
      elseif decision == "removed" then
        self:ClearPendingAccessRequest()
        PrintAlliance("Leaf Village removed this guild from Leaf Alliance.")
        self:SetAccessSnapshot(Now(), {}, "decision")
      end
    end
    return true
  end

  if string.sub(payload, 1, 8) == "CFGSYNC:" then
    local wasAuthorized = self:IsAuthorizedGuild(self:GetPlayerGuildName("player"))
    local fields = SplitBySep(string.sub(payload, 9), fieldSep)
    local updatedAt = tonumber(fields[1]) or Now()
    local guilds = {}
    for i = 2, table.getn(fields) do
      table.insert(guilds, DecodeField(fields[i] or ""))
    end
    self:SetAccessSnapshot(updatedAt, guilds, "channel")
    local isAuthorized = self:IsAuthorizedGuild(self:GetPlayerGuildName("player"))
    if isAuthorized and not wasAuthorized then
      PrintAlliance("Your guild has been added to Leaf Alliance. Use /lva or /leafalliance to open it.")
    end
    if isAuthorized then
      self:Schedule("leafalliance_cfg_authorized_presence", 1.2, function()
        LeafAlliance:BroadcastPresence(true)
        LeafAlliance:MaybeBroadcastRoster(true)
      end)
    end
    if self.UI and self.UI.Refresh then
      self.UI:Refresh()
    end
    return true
  end

  return true
end

function LeafAlliance:SendAllianceChatMessage(text, retryCount)
  local outgoing = Trim(text or "")
  if outgoing == "" then
    return false, "Type a message first."
  end
  if not self:IsAuthorizedGuild(self:GetPlayerGuildName("player")) then
    return false, "This guild has not been granted Leaf Alliance access yet."
  end

  retryCount = tonumber(retryCount) or 0
  local channelId = self:GetAllianceChannelId()
  if channelId <= 0 then
    self:JoinAllianceChannel(false, true)
    if retryCount < 1 then
      self:Schedule("leafalliance_chat_retry", 1.0, function()
        LeafAlliance:SendAllianceChatMessage(outgoing, retryCount + 1)
      end)
    end
    return false, "Joining Leaf Alliance..."
  end

  if type(SendChatMessage) ~= "function" then
    return false, "Chat send is unavailable."
  end
  self.stickyChatEnabled = true
  SendChatMessage(outgoing, "CHANNEL", nil, channelId)
  return true
end

local function ApplySimpleInset(frame)
  frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = {left = 4, right = 4, top = 4, bottom = 4}
  })
  frame:SetBackdropColor(0.05, 0.06, 0.08, 0.92)
  frame:SetBackdropBorderColor(0.35, 0.35, 0.40, 0.9)
end

local function SkinAccentButton(button)
  if not button then
    return
  end

  button:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 8, edgeSize = 10,
    insets = {left = 2, right = 2, top = 2, bottom = 2}
  })
  button:SetBackdropColor(0.44, 0.05, 0.05, 0.95)
  button:SetBackdropBorderColor(0.70, 0.62, 0.38, 0.95)

  local fontString = button:GetFontString()
  if fontString then
    fontString:SetTextColor(1.0, 0.84, 0.16)
  end
end

local function CreateAllianceGuildButton(parent)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetWidth(140)
  btn:SetHeight(30)
  btn:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 8, edgeSize = 10,
    insets = {left = 2, right = 2, top = 2, bottom = 2}
  })
  btn:SetBackdropColor(0.08, 0.08, 0.09, 0.92)
  btn:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.75)

  btn.nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  btn.nameText:SetPoint("TOPLEFT", btn, "TOPLEFT", 8, -6)
  btn.nameText:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
  btn.nameText:SetJustifyH("LEFT")

  btn.metaText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  btn.metaText:SetPoint("TOPLEFT", btn.nameText, "BOTTOMLEFT", 0, -2)
  btn.metaText:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
  btn.metaText:SetJustifyH("LEFT")

  return btn
end

local function CreateRosterRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetWidth(300)
  row:SetHeight(24)

  row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  row.nameText:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  row.nameText:SetJustifyH("LEFT")

  row.metaText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.metaText:SetPoint("TOPLEFT", row.nameText, "BOTTOMLEFT", 0, -1)
  row.metaText:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  row.metaText:SetJustifyH("LEFT")

  return row
end

function LeafAlliance:BuildStyledPlayerName(name, classLabel)
  local displayName = Trim(name or "")
  if displayName == "" then
    displayName = "Unknown"
  end
  return GetClassColorHex(classLabel) .. displayName .. "|r"
end

local function GetRosterVisibleRowCount(scrollFrame, rowHeight)
  local height = (scrollFrame and scrollFrame.GetHeight and scrollFrame:GetHeight()) or 0
  rowHeight = tonumber(rowHeight) or 26
  if rowHeight < 1 then
    rowHeight = 26
  end
  local visibleRows = math.floor(height / rowHeight)
  if visibleRows < 1 then
    visibleRows = 1
  end
  return visibleRows + 1
end

LeafAlliance.UI = LeafAlliance.UI or {}

function LeafAlliance.UI:RefreshChatHistory(forceScrollToBottom)
  local panel = self.panel
  if not panel or not panel.chatHistory then
    return
  end

  local authorized = LeafAlliance:IsAuthorizedGuild(LeafAlliance:GetPlayerGuildName("player"))
  local chatLog = LeafAlliance:GetChatLog()
  local shouldScroll = forceScrollToBottom and true or (panel.chatHistory.AtBottom and panel.chatHistory:AtBottom())
  panel.chatHistory:Clear()

  if not authorized then
    panel.chatEmptyText:Show()
    panel.chatEmptyText:SetText("|cFF777777This guild has not been granted Leaf Alliance access yet.|r")
    return
  end

  if table.getn(chatLog) == 0 then
    panel.chatEmptyText:Show()
    panel.chatEmptyText:SetText("|cFF777777Leaf Alliance messages will appear here once someone speaks in the shared channel.|r")
    return
  end

  panel.chatEmptyText:Hide()
  for i = 1, table.getn(chatLog) do
    local entry = chatLog[i]
    panel.chatHistory:AddMessage(
      LeafAlliance:BuildChatLine(entry.author, entry.message, entry.timestamp, entry.guildName),
      1, 1, 1
    )
  end
  if shouldScroll and panel.chatHistory.ScrollToBottom then
    panel.chatHistory:ScrollToBottom()
  end
end

function LeafAlliance.UI:UnloadRosterView()
  local panel = self.panel
  if not panel then
    return
  end

  panel.loadedRosterGuild = nil
  panel.rosterOffset = 0

  for i = 1, table.getn(panel.rosterRows or {}) do
    if panel.rosterRows[i] then
      panel.rosterRows[i]:Hide()
    end
  end

  if panel.rosterTitle then
    panel.rosterTitle:SetText("|cFFFFD700Alliance Roster|r")
  end
  if panel.rosterSubtitle then
    panel.rosterSubtitle:SetText("|cFF777777Select a guild on the left to load its active roster.|r")
  end
  if panel.rosterEmptyText then
    panel.rosterEmptyText:Show()
    panel.rosterEmptyText:SetText("|cFF777777Select a guild on the left to load its active roster.|r")
  end
  if panel.rosterScrollBar then
    panel.rosterScrollBar:SetMinMaxValues(0, 0)
    panel.rosterScrollBar:SetValue(0)
    panel.rosterScrollBar:Disable()
    panel.rosterScrollBar:Hide()
  end
  if panel.rosterScrollFrame then
    panel.rosterScrollFrame:SetVerticalScroll(0)
  end
end

function LeafAlliance.UI:RefreshRosterView()
  local panel = self.panel
  if not panel then
    return
  end

  local homeGuild = LeafAlliance:GetPlayerGuildName("player")
  local selectedGuild = Trim(LeafAllianceDB.ui.selectedGuild or "")
  local loadedGuild = Trim(panel.loadedRosterGuild or "")
  local rosterGuild = ""
  if selectedGuild ~= "" and loadedGuild ~= "" and Lower(selectedGuild) == Lower(loadedGuild) then
    rosterGuild = selectedGuild
  end

  local rosterSnapshot = rosterGuild ~= "" and LeafAlliance:GetRosterSnapshot(rosterGuild) or nil
  local rosterMembers = rosterSnapshot and rosterSnapshot.members or {}
  local rowHeight = panel.rosterRowHeight or 26
  local visibleRows = GetRosterVisibleRowCount(panel.rosterScrollFrame, rowHeight)
  local maxOffset = math.max(0, table.getn(rosterMembers) - visibleRows)
  if (panel.rosterOffset or 0) > maxOffset then
    panel.rosterOffset = maxOffset
  end

  if rosterGuild ~= "" and Lower(rosterGuild) ~= Lower(homeGuild or "") then
    local snapshotAge = rosterSnapshot and (Now() - tonumber(rosterSnapshot.updatedAt or 0)) or nil
    if (not rosterSnapshot) or (snapshotAge and snapshotAge > 120) then
      LeafAlliance:RequestRosterSnapshot(rosterGuild, false)
    end
  end

  if panel.rosterTitle then
    if rosterGuild ~= "" then
      panel.rosterTitle:SetText("|cFFFFD700" .. tostring(rosterGuild) .. "|r")
    elseif selectedGuild ~= "" then
      panel.rosterTitle:SetText("|cFFFFD700" .. tostring(selectedGuild) .. "|r")
    else
      panel.rosterTitle:SetText("|cFFFFD700Alliance Roster|r")
    end
  end

  if panel.rosterSubtitle then
    if rosterSnapshot then
      panel.rosterSubtitle:SetText("|cFFAAAAAA" .. tostring(rosterSnapshot.onlineCount or 0) .. " active members  |  Updated " .. date("%m/%d %H:%M", tonumber(rosterSnapshot.updatedAt) or Now()) .. "|r")
    elseif rosterGuild ~= "" then
      panel.rosterSubtitle:SetText("|cFF777777Waiting for a roster broadcast from this guild.|r")
    elseif selectedGuild ~= "" then
      panel.rosterSubtitle:SetText("|cFF777777Click the selected guild again to load its active roster.|r")
    else
      panel.rosterSubtitle:SetText("|cFF777777Select a guild on the left to load its active roster.|r")
    end
  end

  while table.getn(panel.rosterRows) < visibleRows do
    table.insert(panel.rosterRows, CreateRosterRow(panel.rosterList))
  end

  local startIndex = (panel.rosterOffset or 0) + 1
  for i = 1, table.getn(panel.rosterRows) do
    local row = panel.rosterRows[i]
    local member = rosterMembers[startIndex + i - 1]
    if member and rosterGuild ~= "" and i <= visibleRows then
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", panel.rosterList, "TOPLEFT", 4, -((i - 1) * rowHeight) - 2)
      row:SetWidth((panel.rosterList:GetWidth() or 288) - 8)
      row.nameText:SetText(LeafAlliance:BuildStyledPlayerName(member.name or "Unknown", member.classLabel))
      row.metaText:SetText("|cFF888888" .. tostring(member.rank or "") .. "  |  " .. tostring(member.classLabel or "Unknown") .. "  |  Lv " .. tostring(member.level or 0) .. "|r")
      row:Show()
    else
      row:Hide()
    end
  end

  if panel.rosterList and panel.rosterScrollFrame then
    local visibleHeight = panel.rosterScrollFrame:GetHeight() or 0
    panel.rosterList:SetWidth(math.max(260, (panel.rosterScrollFrame:GetWidth() or 286) - 2))
    panel.rosterList:SetHeight(math.max(visibleHeight, (visibleRows * rowHeight) + 8))
    panel.rosterScrollFrame:SetVerticalScroll(0)
  end

  if panel.rosterScrollBar then
    panel.rosterScrollBar:SetMinMaxValues(0, maxOffset)
    panel.rosterScrollBar:SetValue(panel.rosterOffset or 0)
    if maxOffset > 0 and rosterGuild ~= "" then
      panel.rosterScrollBar:Enable()
      panel.rosterScrollBar:Show()
    else
      panel.rosterScrollBar:SetValue(0)
      panel.rosterScrollBar:Disable()
      panel.rosterScrollBar:Hide()
    end
  end

  if panel.rosterEmptyText then
    if table.getn(rosterMembers) > 0 and rosterGuild ~= "" then
      panel.rosterEmptyText:Hide()
    else
      panel.rosterEmptyText:Show()
      if rosterGuild ~= "" then
        panel.rosterEmptyText:SetText("|cFF777777Waiting for a roster broadcast from this guild.|r")
      elseif selectedGuild ~= "" then
        panel.rosterEmptyText:SetText("|cFF777777Click the selected guild again to load its active roster.|r")
      else
        panel.rosterEmptyText:SetText("|cFF777777Select a guild on the left to load its active roster.|r")
      end
    end
  end
end

function LeafAlliance.UI:Refresh()
  local panel = self.panel
  if not panel then
    return
  end

  local guilds = LeafAlliance:GetVisibleGuilds()
  local homeGuild = LeafAlliance:GetPlayerGuildName("player")
  local authorized = LeafAlliance:IsAuthorizedGuild(homeGuild)
  local pendingRequest = LeafAlliance:GetPendingAccessRequest()
  if panel.requestInput and ((panel.requestInput:GetText() or "") == "") then
    panel.requestInput:SetText(homeGuild or "")
  end

  if panel.requestTitle then
    if authorized then panel.requestTitle:Hide() else panel.requestTitle:Show() end
  end
  if panel.requestInputBG then
    if authorized then panel.requestInputBG:Hide() else panel.requestInputBG:Show() end
  end
  if panel.requestBtn then
    if authorized then panel.requestBtn:Hide() else panel.requestBtn:Show() end
  end
  if panel.guildTitle and panel.guildList then
    panel.guildTitle:ClearAllPoints()
    if authorized then
      panel.guildTitle:SetPoint("TOPLEFT", panel.guildPanel, "TOPLEFT", 10, -10)
    else
      panel.guildTitle:SetPoint("TOPLEFT", panel.guildPanel, "TOPLEFT", 10, -86)
    end
    panel.guildList:ClearAllPoints()
    panel.guildList:SetPoint("TOPLEFT", panel.guildTitle, "BOTTOMLEFT", 0, -10)
    panel.guildList:SetPoint("BOTTOMRIGHT", panel.guildPanel, "BOTTOMRIGHT", -10, 10)
  end

  local selectedGuild = Trim(LeafAllianceDB.ui.selectedGuild or "")
  if selectedGuild == "" and table.getn(guilds) > 0 then
    selectedGuild = guilds[1]
  end

  local exists = false
  for i = 1, table.getn(guilds) do
    if Lower(guilds[i] or "") == Lower(selectedGuild) then
      exists = true
      selectedGuild = guilds[i]
      break
    end
  end
  if not exists then
    selectedGuild = guilds[1] or ""
  end
  LeafAllianceDB.ui.selectedGuild = selectedGuild

  if panel.statusText then
    local channelId = LeafAlliance:GetAllianceChannelId()
    if channelId <= 0 then
      if pendingRequest then
        panel.statusText:SetText("|cFFFFD700Pending Leaf approval.|r")
      else
        panel.statusText:SetText("|cFFFFD700Request access from Leaf Village to unlock this panel.|r")
      end
    elseif not authorized then
      if pendingRequest then
        panel.statusText:SetText("|cFFFFD700Pending Leaf approval.|r")
      else
        panel.statusText:SetText("|cFFFF6666This guild has not been granted Leaf Alliance access yet.|r")
      end
    else
      local broadcaster = LeafAlliance:GetBroadcasterName() or "Unknown"
      panel.statusText:SetText("|cFF88CC88Connected to Leaf Alliance.|r |cFF888888Roster broadcaster: " .. tostring(broadcaster) .. "|r")
    end
  end

  while table.getn(panel.guildButtons) < math.max(1, table.getn(guilds)) do
    local btn = CreateAllianceGuildButton(panel.guildList)
    btn.panel = panel
    btn:SetScript("OnClick", function()
      if this.guildName then
        LeafAllianceDB.ui.selectedGuild = this.guildName
        this.panel.loadedRosterGuild = this.guildName
        this.panel.rosterOffset = 0
        LeafAlliance.UI:Refresh()
      end
    end)
    table.insert(panel.guildButtons, btn)
  end

  for i = 1, table.getn(panel.guildButtons) do
    local btn = panel.guildButtons[i]
    local guildName = guilds[i]
    if guildName then
      local snapshot = LeafAlliance:GetRosterSnapshot(guildName)
      local isLeafVillage = Lower(guildName) == Lower("Leaf Village")
      btn.guildName = guildName
      btn:ClearAllPoints()
      btn:SetPoint("TOPLEFT", panel.guildList, "TOPLEFT", 2, -((i - 1) * 32) - 2)
      btn:SetWidth((panel.guildList:GetWidth() or 136) - 4)
      btn.nameText:SetText((isLeafVillage and "|cFF88CCFF" or "|cFFFFD700") .. tostring(guildName) .. "|r")
      if snapshot then
        btn.metaText:SetText("|cFFAAAAAA" .. tostring(snapshot.onlineCount or 0) .. " active members|r")
      else
        btn.metaText:SetText("|cFF777777Awaiting roster sync|r")
      end
      if Lower(guildName) == Lower(selectedGuild) then
        btn:SetBackdropColor(0.08, 0.22, 0.12, 0.96)
        btn:SetBackdropBorderColor(0.18, 0.85, 0.38, 0.95)
      else
        btn:SetBackdropColor(0.08, 0.08, 0.09, 0.92)
        btn:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.75)
      end
      btn:Show()
    else
      btn.guildName = nil
      btn:Hide()
    end
  end

  self:RefreshRosterView()

  if panel.chatSendBtn then
    if authorized then
      panel.chatSendBtn:Enable()
    else
      panel.chatSendBtn:Disable()
    end
  end

  self:RefreshChatHistory(false)
end

function LeafAlliance.UI:Build()
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame", "LeafAllianceFrame", UIParent)
  frame:SetWidth(LeafAllianceDB.ui.w or UI_WIDTH)
  frame:SetHeight(LeafAllianceDB.ui.h or UI_HEIGHT)
  frame:SetPoint(LeafAllianceDB.ui.point or "CENTER", UIParent, LeafAllianceDB.ui.relativePoint or "CENTER", LeafAllianceDB.ui.x or 0, LeafAllianceDB.ui.y or 0)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local point, _, relativePoint, x, y = this:GetPoint()
    LeafAllianceDB.ui.point = point
    LeafAllianceDB.ui.relativePoint = relativePoint
    LeafAllianceDB.ui.x = x
    LeafAllianceDB.ui.y = y
  end)
  ApplySimpleInset(frame)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", frame, "TOP", 0, -14)
  title:SetText("|cFF2DD35CLeaf Alliance|r")

  local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
  subtitle:SetText("|cFF888888Shared shinobi alliance chat and live rosters|r")

  local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)

  local guildPanel = CreateFrame("Frame", nil, frame)
  guildPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -60)
  guildPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
  guildPanel:SetWidth(150)
  ApplySimpleInset(guildPanel)

  local chatPanel = CreateFrame("Frame", nil, frame)
  chatPanel:SetPoint("TOPLEFT", guildPanel, "TOPRIGHT", 10, 0)
  chatPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -344, 12)
  ApplySimpleInset(chatPanel)

  local rosterPanel = CreateFrame("Frame", nil, frame)
  rosterPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -60)
  rosterPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
  rosterPanel:SetWidth(320)
  ApplySimpleInset(rosterPanel)

  local guildTitle = guildPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  guildTitle:SetPoint("TOPLEFT", guildPanel, "TOPLEFT", 10, -86)
  guildTitle:SetText("|cFFFFD700Current Alliances|r")

  local requestTitle = guildPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  requestTitle:SetPoint("TOPLEFT", guildPanel, "TOPLEFT", 10, -10)
  requestTitle:SetText("|cFFFFD700Request Access|r")

  local requestInputBG = CreateFrame("Frame", nil, guildPanel)
  requestInputBG:SetPoint("TOPLEFT", requestTitle, "BOTTOMLEFT", 0, -6)
  requestInputBG:SetPoint("TOPRIGHT", guildPanel, "TOPRIGHT", -10, -28)
  requestInputBG:SetHeight(22)
  ApplySimpleInset(requestInputBG)

  local requestInput = CreateFrame("EditBox", nil, requestInputBG)
  requestInput:SetPoint("TOPLEFT", requestInputBG, "TOPLEFT", 5, -3)
  requestInput:SetPoint("BOTTOMRIGHT", requestInputBG, "BOTTOMRIGHT", -5, 3)
  requestInput:SetFontObject(GameFontHighlightSmall)
  requestInput:SetAutoFocus(false)
  requestInput:SetText(Trim(LeafAlliance:GetPlayerGuildName("player") or ""))
  requestInput:SetScript("OnEscapePressed", function() this:ClearFocus() end)

  local requestBtn = CreateFrame("Button", nil, guildPanel, "UIPanelButtonTemplate")
  requestBtn:SetWidth(110)
  requestBtn:SetHeight(22)
  requestBtn:SetPoint("TOPLEFT", requestInputBG, "BOTTOMLEFT", 0, -6)
  requestBtn:SetText("Request Access")
  SkinAccentButton(requestBtn)
  requestBtn:SetScript("OnClick", function()
    local ok, err = LeafAlliance:SendAllianceAccessRequest((requestInput and requestInput:GetText()) or "")
    if ok then
      if LeafAlliance.UI and LeafAlliance.UI.panel and LeafAlliance.UI.panel.statusText then
        LeafAlliance.UI.panel.statusText:SetText("|cFF88CC88Access request sent to Leaf Village.|r")
      end
    elseif LeafAlliance.UI and LeafAlliance.UI.panel and LeafAlliance.UI.panel.statusText and err and err ~= "" then
      LeafAlliance.UI.panel.statusText:SetText("|cFFFFD700" .. tostring(err) .. "|r")
    end
  end)

  local guildList = CreateFrame("Frame", nil, guildPanel)
  guildList:SetPoint("TOPLEFT", guildTitle, "BOTTOMLEFT", 0, -10)
  guildList:SetPoint("BOTTOMRIGHT", guildPanel, "BOTTOMRIGHT", -10, 10)

  local statusText = chatPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statusText:SetPoint("TOPLEFT", chatPanel, "TOPLEFT", 10, -12)
  statusText:SetPoint("RIGHT", chatPanel, "RIGHT", -10, 0)
  statusText:SetJustifyH("LEFT")
  statusText:SetText("")

  local chatTitle = chatPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  chatTitle:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -8)
  chatTitle:SetText("|cFFFFD700Leaf Alliance Feed|r")

  local chatHistory = CreateFrame("ScrollingMessageFrame", nil, chatPanel)
  chatHistory:SetPoint("TOPLEFT", chatPanel, "TOPLEFT", 10, -54)
  chatHistory:SetPoint("BOTTOMRIGHT", chatPanel, "BOTTOMRIGHT", -10, 44)
  chatHistory:SetFontObject(GameFontHighlightSmall)
  chatHistory:SetJustifyH("LEFT")
  chatHistory:SetFading(false)
  chatHistory:SetMaxLines(250)
  chatHistory:EnableMouseWheel(true)
  chatHistory:SetScript("OnMouseWheel", function()
    if (arg1 or 0) > 0 then
      if IsShiftKeyDown() and this.PageUp then
        this:PageUp()
      elseif this.ScrollUp then
        this:ScrollUp()
      end
    else
      if IsShiftKeyDown() and this.PageDown then
        this:PageDown()
      elseif this.ScrollDown then
        this:ScrollDown()
      end
    end
  end)

  local chatEmptyText = chatPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  chatEmptyText:SetPoint("TOPLEFT", chatHistory, "TOPLEFT", 2, -2)
  chatEmptyText:SetPoint("RIGHT", chatHistory, "RIGHT", -2, 0)
  chatEmptyText:SetJustifyH("LEFT")
  chatEmptyText:SetText("")

  local chatInputBG = CreateFrame("Frame", nil, chatPanel)
  chatInputBG:SetPoint("BOTTOMLEFT", chatPanel, "BOTTOMLEFT", 10, 12)
  chatInputBG:SetPoint("BOTTOMRIGHT", chatPanel, "BOTTOMRIGHT", -82, 12)
  chatInputBG:SetHeight(22)
  ApplySimpleInset(chatInputBG)

  local chatInput = CreateFrame("EditBox", nil, chatInputBG)
  chatInput:SetPoint("TOPLEFT", chatInputBG, "TOPLEFT", 5, -3)
  chatInput:SetPoint("BOTTOMRIGHT", chatInputBG, "BOTTOMRIGHT", -5, 3)
  chatInput:SetFontObject(GameFontHighlightSmall)
  chatInput:SetAutoFocus(false)
  chatInput:SetText("")
  chatInput:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  chatInput:SetScript("OnEnterPressed", function()
    local ok, err = LeafAlliance:SendAllianceChatMessage(this:GetText() or "")
    if ok then
      this:SetText("")
    elseif LeafAlliance.UI and LeafAlliance.UI.panel and LeafAlliance.UI.panel.statusText and err and err ~= "" then
      LeafAlliance.UI.panel.statusText:SetText("|cFFFFD700" .. tostring(err) .. "|r")
    end
  end)

  local chatSendBtn = CreateFrame("Button", nil, chatPanel, "UIPanelButtonTemplate")
  chatSendBtn:SetWidth(64)
  chatSendBtn:SetHeight(22)
  chatSendBtn:SetPoint("BOTTOMRIGHT", chatPanel, "BOTTOMRIGHT", -10, 12)
  chatSendBtn:SetText("Send")
  SkinAccentButton(chatSendBtn)
  chatSendBtn:SetScript("OnClick", function()
    local ok, err = LeafAlliance:SendAllianceChatMessage(chatInput:GetText() or "")
    if ok then
      chatInput:SetText("")
    elseif LeafAlliance.UI and LeafAlliance.UI.panel and LeafAlliance.UI.panel.statusText and err and err ~= "" then
      LeafAlliance.UI.panel.statusText:SetText("|cFFFFD700" .. tostring(err) .. "|r")
    end
  end)

  local rosterTitle = rosterPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  rosterTitle:SetPoint("TOPLEFT", rosterPanel, "TOPLEFT", 10, -10)
  rosterTitle:SetText("|cFFFFD700Alliance Roster|r")

  local rosterSubtitle = rosterPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  rosterSubtitle:SetPoint("TOPLEFT", rosterTitle, "BOTTOMLEFT", 0, -4)
  rosterSubtitle:SetPoint("RIGHT", rosterPanel, "RIGHT", -10, 0)
  rosterSubtitle:SetJustifyH("LEFT")
  rosterSubtitle:SetText("")

  local rosterScrollFrame = CreateFrame("ScrollFrame", nil, rosterPanel)
  rosterScrollFrame:SetPoint("TOPLEFT", rosterPanel, "TOPLEFT", 8, -52)
  rosterScrollFrame:SetPoint("BOTTOMRIGHT", rosterPanel, "BOTTOMRIGHT", -28, 10)
  rosterScrollFrame:EnableMouse(true)
  rosterScrollFrame:EnableMouseWheel(true)

  local rosterList = CreateFrame("Frame", nil, rosterScrollFrame)
  rosterList:SetWidth(280)
  rosterList:SetHeight(1)
  rosterScrollFrame:SetScrollChild(rosterList)

  local rosterScrollBar = CreateFrame("Slider", nil, rosterPanel)
  rosterScrollBar:SetPoint("TOPRIGHT", rosterPanel, "TOPRIGHT", -8, -52)
  rosterScrollBar:SetPoint("BOTTOMRIGHT", rosterPanel, "BOTTOMRIGHT", -8, 10)
  rosterScrollBar:SetWidth(16)
  rosterScrollBar:SetOrientation("VERTICAL")
  rosterScrollBar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
  rosterScrollBar:SetMinMaxValues(0, 0)
  rosterScrollBar:SetValue(0)
  local rosterThumb = rosterScrollBar:GetThumbTexture()
  if rosterThumb then
    rosterThumb:SetWidth(16)
    rosterThumb:SetHeight(24)
  end
  rosterScrollBar:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = {left = 2, right = 2, top = 2, bottom = 2}
  })
  rosterScrollBar:SetBackdropColor(0, 0, 0, 0.3)
  rosterScrollBar:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
  rosterScrollBar:SetScript("OnValueChanged", function()
    local value = math.floor((this:GetValue() or 0) + 0.5)
    if value ~= (LeafAlliance.UI.panel and LeafAlliance.UI.panel.rosterOffset or 0) then
      if LeafAlliance.UI.panel then
        LeafAlliance.UI.panel.rosterOffset = value
      end
      LeafAlliance.UI:RefreshRosterView()
    end
  end)
  rosterScrollFrame:SetScript("OnMouseWheel", function()
    local panelRef = LeafAlliance.UI.panel
    if not panelRef then return end
    local selectedGuild = Trim(LeafAllianceDB.ui.selectedGuild or "")
    local loadedGuild = Trim(panelRef.loadedRosterGuild or "")
    if selectedGuild == "" or loadedGuild == "" or Lower(selectedGuild) ~= Lower(loadedGuild) then
      return
    end

    local rosterSnapshot = LeafAlliance:GetRosterSnapshot(selectedGuild)
    local rosterMembers = rosterSnapshot and rosterSnapshot.members or {}
    local visibleRows = GetRosterVisibleRowCount(panelRef.rosterScrollFrame, panelRef.rosterRowHeight or 26)
    local maxOffset = math.max(0, table.getn(rosterMembers) - visibleRows)
    local newOffset = (panelRef.rosterOffset or 0) - (arg1 or 0)
    if newOffset < 0 then newOffset = 0 end
    if newOffset > maxOffset then newOffset = maxOffset end
    if newOffset ~= (panelRef.rosterOffset or 0) then
      panelRef.rosterOffset = newOffset
      LeafAlliance.UI:RefreshRosterView()
    end
  end)

  local rosterEmptyText = rosterList:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  rosterEmptyText:SetPoint("TOPLEFT", rosterList, "TOPLEFT", 4, -8)
  rosterEmptyText:SetPoint("RIGHT", rosterList, "RIGHT", -4, 0)
  rosterEmptyText:SetJustifyH("LEFT")
  rosterEmptyText:SetText("|cFF777777No active roster received yet.|r")

  self.frame = frame
  self.panel = {
    guildPanel = guildPanel,
    guildTitle = guildTitle,
    requestTitle = requestTitle,
    requestInputBG = requestInputBG,
    requestInput = requestInput,
    requestBtn = requestBtn,
    guildList = guildList,
    guildButtons = {},
    statusText = statusText,
    chatHistory = chatHistory,
    chatEmptyText = chatEmptyText,
    chatInput = chatInput,
    chatSendBtn = chatSendBtn,
    rosterTitle = rosterTitle,
    rosterSubtitle = rosterSubtitle,
    rosterScrollFrame = rosterScrollFrame,
    rosterScrollBar = rosterScrollBar,
    rosterList = rosterList,
    rosterRows = {},
    rosterRowHeight = 26,
    rosterOffset = 0,
    rosterEmptyText = rosterEmptyText,
  }

  frame:Hide()
end

function LeafAlliance.UI:Toggle()
  if not self.frame then
    self:Build()
  end

  if self.frame:IsShown() then
    self.frame:Hide()
  else
    self.frame:Show()
    self:Refresh()
  end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CHAT_MSG_CHANNEL")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")

eventFrame:SetScript("OnEvent", function()
  local event = event or _G.event
  local arg1 = arg1
  local arg2 = arg2
  local arg3 = arg3
  local arg4 = arg4
  local arg5 = arg5
  local arg6 = arg6
  local arg7 = arg7
  local arg8 = arg8
  local arg9 = arg9
  local arg10 = arg10
  local arg11 = arg11

  if event == "ADDON_LOADED" and arg1 == LeafAlliance.name then
    LeafAlliance:EnsureDB()
    if RegisterAddonMessagePrefix then
      RegisterAddonMessagePrefix(LeafAlliance.prefix)
    end
    LeafAlliance.UI:Build()
    return
  end

  if event == "PLAYER_LOGIN" then
    LeafAlliance:EnsureDB()
    LeafAlliance:InstallChatSuppression()
    LeafAlliance:InstallRenderedSuppression()
    LeafAlliance:Schedule("leafalliance_login_join", 4, function()
      if LeafAllianceDB.autoJoin and LeafAlliance:IsAuthorizedGuild(LeafAlliance:GetPlayerGuildName("player")) then
        LeafAlliance:JoinAllianceChannel(false, false)
      end
    end)
    return
  end

  if event == "CHAT_MSG_ADDON" then
    if arg1 == LeafAlliance.prefix and (
      string.sub(arg2 or "", 1, 10) == "ACCESSREQ:" or
      string.sub(arg2 or "", 1, 11) == "ACCESSRESP:" or
      string.sub(arg2 or "", 1, 10) == "ROSTERREQ:" or
      string.sub(arg2 or "", 1, 11) == "ROSTERDATA:" or
      string.sub(arg2 or "", 1, 8) == "CFGSYNC:" or
      string.sub(arg2 or "", 1, 7) == "CFGREQ:"
    ) then
      local sender = ShortName(arg4)
      if sender then
        LeafAlliance:HandleControlMessage(sender, tostring((LeafAlliance.channel and LeafAlliance.channel.controlPrefix) or "") .. tostring(arg2 or ""))
      end
      return
    end

    if arg1 == LeafAlliance.prefix and arg3 == "GUILD" then
      local sender = ShortName(arg4)
      if sender and string.sub(arg2 or "", 1, 9) == "ALLYPRES:" then
        LeafAlliance:RecordBroadcasterPeer(sender, tonumber(string.sub(arg2 or "", 10)) or Now())
      elseif string.sub(arg2 or "", 1, 10) == "ALLYSTATE:" then
        local fields = SplitBySep(string.sub(arg2 or "", 11), SEP)
        local state = Lower(DecodeField(fields[1] or ""))
        local guildName = DecodeField(fields[2] or "")
        local homeGuild = LeafAlliance:GetPlayerGuildName("player")
        local me = ShortName(UnitName("player"))
        if sender and me and Lower(sender) == Lower(me) then
          return
        end
        if guildName ~= "" and homeGuild ~= "" and Lower(guildName) == Lower(homeGuild) then
          if state == "approved" then
            LeafAlliance:ClearPendingAccessRequest()
            LeafAlliance:SetAccessSnapshot(Now(), LeafAlliance:BuildApprovedAccessGuildList(guildName), "guild")
            if LeafAllianceDB.autoJoin ~= false then
              LeafAlliance:JoinAllianceChannel(false, false)
            end
          elseif state == "removed" then
            LeafAlliance:ClearPendingAccessRequest()
            LeafAlliance:SetAccessSnapshot(Now(), {}, "guild")
          elseif state == "denied" then
            LeafAlliance:ClearPendingAccessRequest()
            PrintAlliance("Leaf Village denied this guild's Leaf Alliance request.")
          end
        end
      end
    end
    return
  end

  if event == "CHAT_MSG_CHANNEL" then
    local message = arg1
    local author = arg2
    local channelString = arg4
    local channelNumber = arg8
    local channelName = arg9
    if LeafAlliance:IsAllianceMessageChannel(channelString, channelName, channelNumber) then
      if LeafAlliance:HandleControlMessage(author, message) then
        return
      end
      LeafAlliance:RecordAllianceChatMessage(author, message, Now())
    end
    return
  end

  if event == "GUILD_ROSTER_UPDATE" then
    if LeafAlliance.UI and LeafAlliance.UI.frame and LeafAlliance.UI.frame:IsShown() then
      LeafAlliance.UI:Refresh()
    end
    return
  end
end)

SLASH_LEAFALLIANCE1 = "/lva"
SLASH_LEAFALLIANCE2 = "/leafalliance"
SlashCmdList["LEAFALLIANCE"] = function(msg)
  LeafAlliance:EnsureDB()
  local trimmed = Trim(msg or "")
  if trimmed ~= "" then
    local ok, err = LeafAlliance:SendAllianceChatMessage(trimmed)
    if not ok and err and err ~= "" then
      PrintAlliance(err)
    end
    return
  end
  LeafAlliance.UI:Toggle()
end

PrintAlliance("Loaded. Use /lva or /leafalliance to open Leaf Alliance.")
