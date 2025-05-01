--[[
    OTXSIM OpenTX model simulator
    Copyright (C) 2024  Mike Shellim

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details. A copy of the GNU General
    Public License is available at <https://www.gnu.org/licenses/>


VERSION: 1.2

DESCRIPTION
	OpenTX model sim, for debugging setups in Companion.
	For use with Companion simulator with X9D(+) profile
	    (not recommended for use in tx)
	Specify as telemetry script in target model

	Page 1: model display
	Page 2: assignment editor

	Instructions: https://rc-soar.com/opentx/lua/otxsim/index.htm

HISTORY
	     22/11/2024 MS Re-released under GPL version 3
	v1.3 29/12/2021 MS Fixed drawing of verticals (e.g. rudder) if inverted output
	v1.2 30/04/2020 MS Added timers
	                   Undefined LS's now shown as dots
	                   Increased channels to 9
	                   Other cosmetic changes
	v1.1 20/04/2020 MS Fixed scaling bug
	v1.0 18/04/2020 MS Added 'right' and 'left' to autoconfig entries (for Wingy template)
	                   Tweaked scaling
	                   Toggle pages with Menu button (instead of Exit)
	                   Up to 8 channels
	v0.9 12/04/2020 MS 1st release
--]]


--[[
UI State
--]]
local pageNo = 1
local isEditing = false

--[[
Channel editing
--]]
local N_CHANS = 9
local activeChan = 1
local FLD_CHAN_NUM = 0
local FLD_SURFACE_TYPE = 1
local FLD_LR = 2
local FLD_ROT = 3
local activeField = FLD_CHAN_NUM

--[[
 GVAR editing
 --]]
local N_GVARS = 9
local activeGVAR = 1
local ATTR_NORMAL = SMLSIZE
local ATTR_EDIT = ATTR_NORMAL + INVERS + BLINK
local ATTR_ACTIVE = ATTR_NORMAL + INVERS
local GVAR_PITCH = 21

--[[
Model dimensions, arbitrary ('model') units
--]]
local SPAN_LEN = 3.6 -- total span
local ELE_LEN = 1
local RUD_LEN = 0.6
local MAX_DEFL = 0.22


local modWidth = SPAN_LEN -- width of model
local modHeight = RUD_LEN + 2*MAX_DEFL -- height of model
local modYOffset = RUD_LEN/2 -- drawing offset

-- Text box alignment
-- bit 0-1 : 0=centre, 1=right, 2=left,
-- bit 2: 0=top, 1=right
local TOP_CNTR = 0x00
local TOP_RT   = 0x01
local TOP_LT   = 0x02
local BOT_CNTR = 0x04
local BOT_RT   = 0x05
local BOT_LT   = 0x06

-- text and fonts
local FONT_HT = 7 -- device units
local FONT_WID = 5

--[[
Logical switch drawing
--]]
local LS_WID = 3 -- width of ls graphic
local LS_HT =  4 -- height of ls graphic
local LS_SPACE = 1 -- spacing
local LSDefLo -- bitmap of definition state for LS's 0-31
local LSDefHi -- bitmap of definition state for LS's 32-63

--[[
Hardware/screen dependent
--]]
local grid =  {rows={1,1,50,64 },cols={1,169,170,212}}
local SRC_LS -- base of logical switch id (= ID of L1)
local SRC_TMR1 -- base of timer fields (=ID of timer1)
local N_TMR -- number of timers

--[[
Control surface types are defined here.
The first three are reserved for three wing surfaces
(x0,y0) and (x1,y1) define base line
dx,dy represent 100% deflection
txtPos is text position as % distance along deflection line
txtAlign specifies alignment of text box relative to text position
All coordinates in model space,
--]]

local surfType  = {
 [1] = {Name='Flap',draw=true, hasLR = true, x0=0,          y0=0, x1=0, y1=0, dx=0, dy=MAX_DEFL,txtPos=0.5, txtAlign=BOT_CNTR},
 [2] = {Name='Ail', draw=true, hasLR = true, x0=0,          y0=0, x1=0, y1=0, dx=0, dy=MAX_DEFL,txtPos=0.5, txtAlign=BOT_CNTR},
 [3] = {Name='Tip', draw=true, hasLR = true, x0=0,          y0=0, x1=0, y1=0, dx=0, dy=MAX_DEFL, txtPos=0.5, txtAlign=BOT_CNTR},
 [4] = {Name='Ele', draw=true, hasLR = false,x0=-ELE_LEN/2, y0=RUD_LEN, x1=ELE_LEN/2, y1=RUD_LEN, dx = 0, dy=MAX_DEFL, txtPos=0.9, txtAlign=TOP_LT},
 [5] = {Name='Rud', draw=true, hasLR = false,x0=0,          y0=0, x1=0, y1=RUD_LEN, dx=MAX_DEFL, dy=0, txtPos=0.65, txtAlign=TOP_RT},
 [6] = {Name='Vee', draw=true, hasLR = true, x0=0,          y0=0, x1=2*RUD_LEN/4, y1=RUD_LEN, dx=-2*MAX_DEFL/3, dy=MAX_DEFL/3, txtPos=1, txtAlign=TOP_LT},
 [7] = {Name='---', draw=false, hasLR = false}
 }


--[[
Channel assignments table. Populated in init()
--]]
local chAssign = {}
local LEFT = -1
local RIGHT = 1
local ROT_NORMAL = 1

-- ===============================================================================

--[[
FUNCTION: initLSDefs
Populate ls definition bitmap
--]]
local function initLSDefs ()
	LSDefLo = 0
	LSDefHi = 0
	for i = 0, 31 do
		local vLo = (model.getLogicalSwitch(i).func > 0) and 1 or 0
		local vHi = (model.getLogicalSwitch(i+32).func >0) and 1 or 0
		LSDefLo = bit32.replace (LSDefLo, vLo, i)
		LSDefHi = bit32.replace (LSDefHi, vHi, i)
	end
end

--[[
FUNCTION: isDefinedLS
Tests for definition of logical switch i
--]]
local function isDefinedLS (i)
	local long = i>31 and LSDefHi or LSDefLo
	return bit32.extract (long, i%32) == 1
end


--[[
FUNCTION: updateSurfaces
Distribute wing surfaces across SPEN_LEN
--]]
local function updateSurfaces()

	-- Count active wing panel types
	local cnt = 0
	for i = 1, 3 do
		for j = 1, #chAssign do
			local type = chAssign[j].type
			if type == i then
				cnt = cnt + 1
				break
			end
		end
	end

	-- distribute active wing panels across SPAN_LEN
	local xPanelOffset = SPAN_LEN / (2*cnt)
	local x = 0
	for i = 1, 3 do
		for j = 1, #chAssign do
			local type = chAssign[j].type
			if type == i then
				surfType[chAssign[j].type].x0 = x
				x = x + xPanelOffset
				surfType[chAssign[j].type].x1 = x
				break
			end
		end
	end
end

--[[
FUNCTION: ModAssignment
Create or modify channel assignment.
--]]
local function ModAssignment (iChan, surfType,  lr,  rot)
	if not chAssign[iChan] then
		chAssign[iChan] = {type=surfType, side=lr or RIGHT, rot=rot or ROT_NORMAL}
	else
		if lr then chAssign[iChan].side = lr end
		if rot then chAssign[iChan].rot = rot end
		if surfType then chAssign[iChan].type = surfType end
	end
end

--[[
FUNCTION: getItemCount
determines the number of items in a field
--]]

local function getItemCount (field, maxitems)
	local i = 1
	while true do
		if i > maxitems or not getFieldInfo(field ..i) then
			break
		end
		i = i + 1
	end
	return i-1
end


--[[
FUNCTION: init
Initialisations
--]]
local function init()

	-- initialise timer and logical switches
	N_TMR = getItemCount ('timer',3)
	initLSDefs ()

	-- Store field offsets
	SRC_LS = getFieldInfo ('ls1').id
	SRC_TMR1 = getFieldInfo ('timer1').id

	-- Assign surfaces to channels according to channel labels
	for i = 1, N_CHANS do

		local outputName = string.lower(model.getOutput(i-1).name)
		chAssign [i] = nil

		if string.find (outputName, 'ail') and string.find (outputName, 'r') then
			ModAssignment (i, 2,  RIGHT, ROT_NORMAL)
		elseif string.find (outputName, 'ail') and not string.find (outputName, 'r') then
			ModAssignment (i, 2,  LEFT, ROT_NORMAL)
		elseif string.find (outputName, 'fl') and string.find (outputName, 'r') then
			ModAssignment (i, 1,  RIGHT, ROT_NORMAL)
		elseif string.find (outputName, 'fl') and not string.find (outputName, 'r') then
			ModAssignment (i, 1,  LEFT, ROT_NORMAL)
		elseif string.find (outputName, 'el') then
			ModAssignment (i, 4,  RIGHT, ROT_NORMAL)
		elseif string.find (outputName, 'rud') then
			ModAssignment (i, 5,  RIGHT, ROT_NORMAL)
		elseif string.find (outputName, 'v') and string.find (outputName, 'l') then
			ModAssignment (i, 6,  LEFT, ROT_NORMAL)
		elseif string.find (outputName, 'v') and string.find (outputName, 'r') then
			ModAssignment (i, 6,  RIGHT, ROT_NORMAL)
		elseif string.find (outputName, 'tip') and string.find (outputName, 'r') then
			ModAssignment (i, 3,  RIGHT, ROT_NORMAL)
		elseif string.find (outputName, 'tip') and string.find (outputName, 'l') then
			ModAssignment (i, 3, LEFT, ROT_NORMAL)
		elseif string.find (outputName, 'right') then
			ModAssignment (i, 2, RIGHT, ROT_NORMAL)
		elseif string.find (outputName, 'left') then
			ModAssignment (i, 2, LEFT, ROT_NORMAL)
		else
			ModAssignment (i, 7) -- 'Other'
		end
	end

	-- update surface dimensions
	updateSurfaces()
end


--[[
FUNCTION: getfmGVRoot
Get root FM of GVAR (val <= 1024)
Function is workaround for getGlogbalVariable not supporting linked GVs.
]]--
local function getfmGVRoot (igv)
	local fm = getFlightMode ()
	local fm0 = fm
	repeat
		local val = model.getGlobalVariable (igv-1, fm)
		if val <= 1024 then
			-- found!
			return fm
		end

		-- Advance to next FM in chain.
		fm = val - 1025
		if fm > fm0 then
			-- 'magic' correction if
			-- the next FM in chain is > current FM.
			fm = fm + 1
		end
	until false

	end

--[[
FUNCTION: getGV
Get value of a Gvar
 --]]
local function getGV(igv)
	return model.getGlobalVariable (igv-1, getfmGVRoot(igv))
	end

--[[
FUNCTION: setGV
Set GV value
--]]
local function setGV(igv, val)
	model.setGlobalVariable (igv-1,getfmGVRoot (igv), val)
	end

--[[
FUNCTION: m2d
Convert a point in model coordinates, to device coordinates in given row/col
row: row number starting from 1
col: col number starting from 1
--]]
local function m2d (row, col, x,y)

	-- calculate cell origin (device coords)
	local devWid= grid.cols [col+1] -  grid.cols [col] - 1
	local devHt = grid.rows [row+1] -  grid.rows [row] - 1
	local devOrgX = (grid.cols [col+1] + grid.cols [col]) / 2
	local devOrgY = (grid.rows [row+1] + grid.rows [row]) / 2

	-- convert x, y to device coordinates
	local scale = math.min (devWid/modWidth, devHt/modHeight)
	x = devOrgX + x * scale
	y = devOrgY - (y-modYOffset) * scale
	return x, y
end

--[[
FUNCTION: drawLine
Draw line [(x0, y0), (x1, y1)] in given grid cell
--]]
local function drawLine (row, col, x0, y0, x1, y1, pattern)
	x0,y0 = m2d (row, col, x0, y0)
	x1,y1 = m2d (row, col, x1, y1)
	lcd.drawLine (x0, y0,x1, y1,pattern,FORCE)
end

--[[
FUNCTION: drawText
Draw text in grid cell
Input coordinates are in model space
--]]
local function drawText (row, col, x, y, text, txtAlign)
	x,y = m2d (row, col, x, y)

	-- Force to string
	text = text .. ""

	-- Adjust for alignment
	if txtAlign == TOP_RT or txtAlign == BOT_RT then
		x = x - (#text * FONT_WID)
	elseif txtAlign == TOP_CNTR or txtAlign == BOT_CNTR then
		x = x - (#text * FONT_WID)/2
	end
	if txtAlign == BOT_LT or txtAlign == BOT_RT or txtAlign == BOT_CNTR then
		y = y - FONT_HT
	end

	lcd.drawText (x,y, text,SMLSIZE)
end

--[[
FUNCTION: drawControlSurface
Draw control surface and mixer value
Show fixed part as dotted, deflection line as solid
	row: grid row number
	col: grid column number
	ich: channel number
--]]
local function drawControlSurface (row,col,ich)

	local st = surfType[chAssign[ich].type]  -- surface type
	local chVal = getValue ('ch'..ich)/10.24 -- mixer value
	local side = chAssign[ich].side       	-- left or right
	local rot = chAssign[ich].rot			-- rotation
	local defl = rot * math.min (math.max (chVal/100, -1), 1)

	-- base line
	local x0  = side*(st.x0)
	local x1  = side*(st.x1)
	local y0  = st.y0
	local y1  = st.y1


	-- deflection line
	local x2 = x0 + defl*side*st.dx
	local x3 = x1 + defl*side*st.dx
	local y2 = y0 + defl*st.dy
	local y3 = y1 + defl*st.dy

	-- Draw base and deflection lines
	drawLine (row, col, x0, y0, x1, y1, (defl ~= 0) and DOTTED or SOLID) -- surface
	drawLine (row,col, x2, y2, x3, y3, SOLID) -- deflection

	-- Draw ends
	drawLine (row,col, x0, y0, x2, y2, SOLID)
	drawLine (row,col, x1, y1, x3, y3, SOLID)

	-- Calculate position of label
	local x, y
	x = x2 * (1-st.txtPos) + x3 * st.txtPos
	y = y2 * (1-st.txtPos) + y3 * st.txtPos
	local txtAlign = st.txtAlign

	-- flip label if left-side
	if side < 1 then
		local hAlign = bit32.extract (txtAlign, 0,2)
		if hAlign > 0 then hAlign = 3 - hAlign end
		txtAlign = bit32.replace (txtAlign, hAlign, 0,2)
	end

	-- Draw label
	drawText (row,col, x, y, math.floor(chVal+.5), txtAlign)

end


--[[
FUNCTION drawGrid (debugging)
--]]
local function drawGrid ()
	local rows = grid.rows
	local cols = grid.cols
	lcd.drawLine (1,10, 200, 10, DOTTED,FORCE)
	for i=1, #rows do
		lcd.drawLine (0,rows[i], 211, rows[i], DOTTED,FORCE)

	end
	for i=1, #cols do
		lcd.drawLine (cols[i], 0, cols[i], 63, DOTTED,FORCE)
	end
end


--[[
FUNCTION hms
Break seconds into hh,mm, ss
--]]
local function hms (secs)
	local ss = secs % 60
	local hh = math.floor (secs/3600)
	local mm = (secs - hh*3600 - ss) / 60
	return hh, mm, ss
end

--[[
FUNCTION: drawTimers
--]]
local function drawTimers ()
	local x = grid.cols[1]
	local y = grid.rows[1] -- + FONT_HT + 1
	for i = 0, N_TMR -1 do
		lcd.drawText (x, y,
			string.format ("T%s:%02d:%02d:%02d",(i+1),hms(getValue(SRC_TMR1 +i))),
			SMLSIZE)
		y = y + FONT_HT
	end
end

--[[
FUNCTION: drawLogSwitches
--]]
local function drawLogSwitches ()

	-- show logical switch states in col 3 row 2
	local x0 = grid.cols[3] + LS_SPACE
	local x = x0
	local y = grid.rows[1] + LS_SPACE
	local i = 0

	while true do
		if isDefinedLS (i) then
			local flags = (1024 == getValue (SRC_LS + i)) and SOLID or GREY_DEFAULT
			lcd.drawRectangle(x, y, LS_WID, LS_HT, flags)
		else
			lcd.drawFilledRectangle(x+LS_WID/2, y+LS_HT/2, 1, 1, GREY_DEFAULT)
		end
		x = x + LS_WID + LS_SPACE
		i = i + 1
		if i > 63 then break end
		if (i+5)%10 == 0 then
			x = x + LS_SPACE
		end
		if i%10 == 0 then
			y = y + LS_HT + LS_SPACE
			x =x0
		end
	end

end

--[[
FUNCTION: isSubfieldVisible
Return true if subfield for given channel is visible
--]]
local function isSubfieldVisible (iChan, subfield)
	local isVisible
	if subfield == FLD_LR then
		isVisible = surfType[chAssign[iChan].type].hasLR
	else
		isVisible = true
	end
	return isVisible
end

--[[
FUNCTION: getFieldAttrs
Get display attributes for given subfield
--]]
local function getFieldAttrs (iChan, subfield)
	local attrs

	-- Determine attributes
	if iChan == activeChan then
		if subfield == activeField then
			if subfield == FLD_CHAN_NUM then
				attrs = ATTR_ACTIVE
			else
				attrs = isEditing and ATTR_EDIT or ATTR_ACTIVE
			end
		else
			attrs = ATTR_NORMAL
		end
	else
		attrs = ATTR_NORMAL
	end
	return attrs
end

--[[
FUNCTION: getGVAttrs
Get display attributes of given gvar
--]]
local function getGVAttrs (igv)
	local attrs
	if igv == activeGVAR then
		attrs = isEditing and ATTR_EDIT or ATTR_ACTIVE
	else
		attrs = ATTR_NORMAL
	end
	return attrs
end

--[[
FUNCTION: drawGvars
Draw GVars along bottom two rows (label followed by value)
--]]
local function drawGvars ()
	local y = grid.rows[3]
	for i = 1, N_GVARS, 1 do
		lcd.drawText ((i-1)*GVAR_PITCH + 1, y, 'GV'..i, ATTR_NORMAL)
		lcd.drawText ((i-1)*GVAR_PITCH + 1, y + FONT_HT, getGV(i), getGVAttrs (i))
	end
end

--[[
FUNCTION: drawChanAssign
Draw channel assignment fields
--]]
local function drawChanAssign ()
	local y = 1
	for i = 1, N_CHANS do

		-- channel number
		lcd.drawText (1, y, "CH"..i.."->", getFieldAttrs (i, FLD_CHAN_NUM))

		-- surface type
		lcd.drawText (30,  y, surfType[chAssign[i].type].Name, getFieldAttrs (i, FLD_SURFACE_TYPE))

		-- side
		if surfType[chAssign[i].type].hasLR then
			lcd.drawText (55, y, (chAssign[i].side == RIGHT) and 'Right' or 'Left', getFieldAttrs (i, FLD_LR))
		end

		-- rotation
		lcd.drawText (85, y, (chAssign[i].rot == ROT_NORMAL) and 'Normal' or 'Inv', getFieldAttrs (i, FLD_ROT))
		y = y + FONT_HT + 1
	end
end


--[[
FUNCTION: run
Run function
--]]
local function run(event)
	lcd.clear()
	if pageNo == 1 then

		-------------------------------------
		-- PAGE ONE or TWO renders model view
		-------------------------------------

		local inc = 0

		-- handle button presses

		if event == EVT_EXIT_BREAK then
			if isEditing then
				isEditing = false
			else
				return 1
			end
		elseif event == EVT_ENTER_BREAK then
			isEditing = not isEditing
		elseif event == EVT_MENU_BREAK then
			isEditing = false
			pageNo = 2
			-- killEvents (EVT_MENU_BREAK)
			return 0
		elseif event == EVT_PLUS_BREAK or event == EVT_PLUS_REPT then
			inc = 1
		elseif event == EVT_MINUS_BREAK or event == EVT_MINUS_REPT then
			inc = -1
		end

		-- +/- pressed?
		if inc ~= 0 then
			if isEditing then
				setGV(activeGVAR, getGV(activeGVAR) + inc)
			else
				activeGVAR = (activeGVAR-1+inc) % N_GVARS + 1
			end
		end


		-- Show top line info
		local fmNo, fmName = getFlightMode ()
		local s = 'fm'..fmNo ..':'..fmName
		lcd.drawText (55,1,s,SMLSIZE)
		drawTimers ()

		-- draw the model
		local yChPos = grid.rows[2]
		local cntValueListItems = 0
		for i=1, N_CHANS do
			-- surface
			if surfType[chAssign[i].type].draw  then
				drawControlSurface (2, 1, i)
			else
				-- up to 3 channel numbers (limited by available space)
				if cntValueListItems < 3 then
					lcd.drawText (130, yChPos, "Ch"..i.. ":".. math.floor(getValue ('ch'..i)/10.24 + 0.5), SMLSIZE)
					yChPos = yChPos + FONT_HT
					cntValueListItems = cntValueListItems + 1
				end
			end
		end

		-- Draw the rest
		drawLogSwitches ()
		drawGvars ()

	else

		---------------------------
		-- PAGE 2 is channel editor
		---------------------------

		-- handle button presses

		local inc = 0
		if event == EVT_EXIT_BREAK then
			if activeField == FLD_CHAN_NUM then
				pageNo = 1
			else
				if isEditing then
					isEditing = false
				end
				activeField = FLD_CHAN_NUM
			end
		elseif event == EVT_ENTER_BREAK then
			if activeField == FLD_ROT then
				chAssign[activeChan].rot = -chAssign[activeChan].rot
			elseif activeField == FLD_LR then
				chAssign[activeChan].side = -chAssign[activeChan].side
			elseif activeField == FLD_CHAN_NUM then
				activeField = 1
			elseif activeField == FLD_SURFACE_TYPE then
				isEditing = not isEditing
			end
		elseif event == EVT_MENU_BREAK then
			if isEditing then
				isEditing = false
			end
			pageNo = 1
			return 0
		elseif event == EVT_PLUS_BREAK then
			inc = 1
		elseif event == EVT_MINUS_BREAK then
			inc = -1
		end

		-- +/- pressed?

		if inc ~= 0 then
			if isEditing then
				if activeField == FLD_SURFACE_TYPE then
					local type = chAssign[activeChan].type
					ModAssignment (activeChan, (type + inc -1 ) % #surfType + 1)
					updateSurfaces()
				end
			elseif activeField == FLD_CHAN_NUM then
				activeChan = (activeChan-1-inc) % N_CHANS + 1
			elseif chAssign[activeChan] then
				-- Step to next/prev active subfield ignoring hidden fields
				repeat
					activeField = (activeField-1+inc) % 3 + 1
				until isSubfieldVisible (activeChan, activeField)
			end
		end

		-- draw assignments
		drawChanAssign ()
	end
	return 0
end

return {init=init, run=run}
