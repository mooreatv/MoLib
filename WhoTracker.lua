-- WhoTracker -- (c) 2009 moorea@ymail.com
-- Covered by the GNU General Public License version 3 (GPLv3)
-- NO WARRANTY
-- (contact the author if you need a different license)

if WhoTracker == nil then
  -- create table/namespace for most of this addon state
  -- and functions (whoTrackerSaved containing the rest)
  WhoTracker = {};
end

-- to force debug from load time, uncomment: (otherwise "/wt debug on" to turn on later)
-- WhoTracker.debug = 1;

function WhoTracker.Print(...)
	DEFAULT_CHAT_FRAME:AddMessage(...);
end
function WhoTracker.Debug(msg)
    if WhoTracker.debug == 1 then
       WhoTracker.Print("WhoTracker DBG: "..msg,0,1,0);
    end
end

function WhoTracker.Help(msg) 
	WhoTracker.Print("WhoTracker: "..msg.."\n/wt pause --   stop tracking.\n/wt resume -- resume tracking\n/wt query ... -- who/what to track\n/wt history -- prints history");
end
 
function WhoTracker.Slash(arg)
  if #arg == 0 then
	WhoTracker.Help("commands");
	return;
  end
  local cmd = string.lower(string.sub(arg, 1, 1));
  local posRest =  string.find(arg, " ");
  local rest = "";
  if not (posRest == nil) then
    rest = string.sub(arg, posRest+1);
  end
  if cmd == "p" then
    -- off
    whoTrackerSaved.paused = 1;
    WhoTracker.Print("WhoTracker now off");
  elseif cmd == "r" then
    -- resume
    whoTrackerSaved.paused = nil;
    WhoTracker.Print("WhoTracker resuming tracking of "..whoTrackerSaved.query);
  elseif cmd == "q" then
    -- query 
    whoTrackerSaved.query=rest;
    local msg = "WhoTracker now tracking "..rest;
    WhoTracker.Print(msg);
    table.insert(whoTrackerSaved, msg);
    whoTrackerSaved.paused = nil; 
    WhoTracker.nextUpdate =  0;
  elseif cmd == "h" then
    -- history
    WhoTracker.Print("WhoTracker history:");
    for i=1, #whoTrackerSaved do
	WhoTracker.Print(whoTrackerSaved[i]);
    end
  -- for debug, needs exact match:
  elseif arg == "debug on" then
  	-- debug
  	WhoTracker.debug = 1;
  	WhoTracker.Print("WhoTracker Debug ON");
  elseif arg == "debug off" then
  	-- debug
  	WhoTracker.debug = nil;
  	WhoTracker.Print("WhoTracker Debug OFF");
  else 
    WhoTracker.Help("unknown command \""..arg.."\", usage:");
  end
end 

SlashCmdList["WhoTracker_Slash_Command"] = WhoTracker.Slash;

SLASH_WhoTracker_Slash_Command1 = "/WhoTracker";
SLASH_WhoTracker_Slash_Command2 = "/wt";


function WhoTracker.OnEvent(this, event) 
   WhoTracker.Debug("called for "..this:GetName().." e="..event.." q="..WhoTracker.inQueryFlag.." nr="..#WhoTracker.registered
   					.." ur="..#WhoTracker.unregistered);
   if WhoTracker.inQueryFlag == 0 then
      return; 
   end
   -- restore other handlers
   for i=1,#WhoTracker.unregistered do
		WhoTracker.unregistered[i]:RegisterEvent("WHO_LIST_UPDATE");
   end
   WhoTracker.registered={};
   WhoTracker.unregistered={};
   WhoTracker.frame:UnregisterEvent("WHO_LIST_UPDATE");
   -- check results
   local numWhos, totalCount = GetNumWhoResults();
   --if numWhos>0 then
   local status="";
   local levels={};
   local zones={};
   local minl=999;
   local maxl=0;
   local zoneList={};
   for i=1, numWhos do
      local charname, guildname, levelStr, race, class, zone, classFileName = GetWhoInfo(i);
      local level=tonumber(levelStr);
      if level<minl then
      	minl= level;
      end
      if level>maxl then
      	maxl= level;
      end
      if  levels[level] == nil then
         levels[level] = 1;
      else 
         levels[level] = levels[level] + 1;
      end
      if zones[zone] == nil then
         zones[zone] = 1;
         table.insert(zoneList, zone);
      else
         zones[zone] = zones[zone] + 1;
      end
   end
   local msg="";
   local level,count;
   local first = 1;
   table.sort(zoneList); 
   for level=minl, maxl do
   	  count = levels[level];
   	  if not(count == nil) then
	      if first == 1 then 
    	     first = 0;
      	  else 
         	msg = msg .. ", ";
      	  end
      	  msg = msg..count .. " x lvl " .. level;
      end
   end
   table.sort(zoneList); 
   for i=1, #zoneList do
   	  local zone=zoneList[i];
   	  local count=zones[zone];
      msg = msg..", "..count .. " in " .. zone;
   end
   if not(msg == WhoTracker.prevStatus) then
      WhoTracker.prevStatus = msg; 
      local ts=date("%a %b %d %H:%M ")
      local tsMsg = ts..totalCount.." online. "..msg;
      WhoTracker.Print(tsMsg, 1,0,0);
      table.insert(whoTrackerSaved, tsMsg); 
      PlaySound("AuctionWindowClose");
   else 
      --print("unchanged");
   end
   --end
   --print("---");
   WhoTracker.inQueryFlag = 0;
end 

WhoTracker.refresh =  60;
WhoTracker.nextUpdate = 0;
--if  WhoTracker.prevStatus==nil then
WhoTracker.prevStatus = "x";
--end
WhoTracker.inQueryFlag = 0;

WhoTracker.first = 1;

function WhoTracker.Init() 
  if not(WhoTracker.first == 1) then
     return;
  end
  WhoTracker.first = 0;
  -- saved vars handling
  if whoTrackerSaved == nil then
    whoTrackerSaved = {};
    WhoTracker.Print("Welcome to WhoTracker: type \"/wt query n-samdeath\" for instance to start tracking player names matching \"samdeath\" - \"/wt pause\" to stop tracking");
    whoTrackerSaved.query="n-samdeath";
    whoTrackerSaved.paused = 1;
  else
    if whoTrackerSaved.paused == 1 then
      WhoTracker.Print("WhoTracker is paused.  /wt resume or /wt query [query] to resume.");
    else
      WhoTracker.Print("WhoTracker loaded.  Will track \"".. whoTrackerSaved.query .."\" - type /wt pause to stop .");
    end 
  end
  -- end save vars
end

function WhoTracker.OnUpdate(self, elapsed) 
   WhoTracker.Init();
   local now = GetTime();
   if not(whoTrackerSaved.paused == 1 ) and (now >= WhoTracker.nextUpdate) then
      WhoTracker.nextUpdate = now + WhoTracker.refresh;
      WhoTracker.SendWho();
   end
end

function WhoTracker.SetRegistered( ... )
	WhoTracker.registered = {};
    for i = 1, select( "#", ... ) do
        WhoTracker.registered[i]=select( i, ... );
    end
end

-- Turns out the FriendsFrame is the only one we need to unregister;
-- in particular LibWho-2.0 needs to stay as it hooks SendWho so
-- we probably don't need to 2 lists (registered and unregistered)
-- but it may be useful later if we find other incompatibilities
function WhoTracker.SendWho()
    if (WhoTracker.inQueryFlag == 1) or (#WhoTracker.registered > 0) or (#WhoTracker.unregistered > 0) then
    	-- shouldn't happen... something is wrong/slow/... if it does, restore other handlers
     	WhoTracker.inQueryFlag=0;
    	WhoTracker.Print("WhoTracker found unexpected state i="
    		..WhoTracker.inQueryFlag.." r="
    		..#WhoTracker.registered.." u="
    		..#WhoTracker.unregistered,1,.6,.6);
	    for i=1,#WhoTracker.unregistered do
	    	WhoTracker.registered[i]:RegisterEvent("WHO_LIST_UPDATE");
	    end
	    WhoTracker.registered = {};
 		WhoTracker.unregistered = {};
    	WhoTracker.frame:UnregisterEvent("WHO_LIST_UPDATE");
    	WhoTracker.inQueryFlag=0;
    	return;
    end
    WhoTracker.inQueryFlag=1;
    WhoTracker.SetRegistered(GetFramesRegisteredForEvent("WHO_LIST_UPDATE"));
    WhoTracker.unregistered = {};
    local friendsFrame = nil;
    for i=1,#WhoTracker.registered do
    	local fname = WhoTracker.registered[i]:GetName();
    	if fname == nil then
        	WhoTracker.Debug("who events registered - nil name #"..i);
    	else
        	WhoTracker.Debug("who events registered for "..fname);
        end
        if fname == "FriendsFrame" then
        	friendsFrame = WhoTracker.registered[i];
    		friendsFrame:UnregisterEvent("WHO_LIST_UPDATE");
    		table.insert(WhoTracker.unregistered, friendsFrame);
    	end
    end
	WhoTracker.frame:RegisterEvent("WHO_LIST_UPDATE");
	SetWhoToUI(1);
	-- set regular /who ui in case the user wants to repeat/get detailed
	-- of the search, but only if there isn't another search in there
	-- note that the results aren't displayed (the list is unchanged)
	if #WhoFrameEditBox:GetText()==0 or WhoFrameEditBox:GetText()==WhoTracker.prevQuery then
		WhoFrameEditBox:SetText(whoTrackerSaved.query);
		WhoTracker.prevQuery = WhoFrameEditBox:GetText();
		WhoFrameEditBox:HighlightText();
		if WhoFrame:IsVisible() then
			if friendsFrame==nil then
				WhoTracker.Print("WhoFrame visible but FriendsFrame wasn't registered",1,.6,.6);
			else
				-- put it back
				friendsFrame:RegisterEvent("WHO_LIST_UPDATE");
				WhoTracker.Debug("put back FriendsFrame event hdlr");
			end
		end
	end
	SendWho(whoTrackerSaved.query);
end


if WhoTracker.frame==nil then
	WhoTracker.frame=CreateFrame("frame","WhoTracker", UIParent);
end
if WhoTracker.registered==nil then
	WhoTracker.registered={};
end
if WhoTracker.unregistered==nil then
    WhoTracker.unregistered = {};
end

WhoTracker.frame:SetScript("OnEvent", WhoTracker.OnEvent);
WhoTracker.frame:SetScript("OnUpdate", WhoTracker.OnUpdate);
