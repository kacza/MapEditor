local m_Logger = Logger("Util", false)

local matrix = require "__shared/Util/matrix"

local TEMP_GUID_PREFIX = "ED170120"
local CUSTOMOBJ_GUID_PREFIX = "ED170121"
local VANILLA_GUID_PREFIX = "ED170122"
local NOHAVOK_GUID_PREFIX = "ED170124"
EMPTY_GUID = Guid('00000000-0000-0000-0000-000000000000')
HAVOK_GUID = Guid('73756277-6f72-6c64-6e6f-006861766f6b')
PREVIEW_GUID = Guid('ED170120-0000-0000-0000-000000000000')

function MergeTables(p_Old, p_New)
	if p_New == nil then
		return p_Old
	end

	if p_Old == nil then
		return p_New
	end

	for l_Key, l_Value in pairs(p_New) do
		p_Old[l_Key] = l_Value
	end

	return p_Old
end

--function MergeGameObjectTransferData(p_Old, p_New)
--	if p_Old == nil then
--		return p_New
--	end

--	if p_New == nil then
--		return nil
--	end

--	for l_Key, l_Value in pairs(p_New) do
--		p_Old[l_Key] = l_Value
--	end

--	return p_Old
--end

function GetChanges(p_Old, p_New)
	local s_Changes = {}

	for l_Key, _ in pairs(p_New) do
		if tostring(p_Old[l_Key]) ~= tostring(p_New[l_Key]) then
			if type(p_Old[l_Key]) == "table" then
				for l_SecondKey, _ in pairs(p_Old[l_Key]) do
					if p_Old[l_Key][l_SecondKey] ~= p_New[l_Key][l_SecondKey] then
						table.insert(s_Changes, l_Key)
					end
				end
			else
				table.insert(s_Changes, l_Key)
			end
		end
	end

	return s_Changes
end

---Traverses the values of the given @p_Table substituting fb structures in plain Lua with the appropiate class (Vec3s and LinearTransforms)
---@param p_Table table
---@return table?
function DecodeParams(p_Table)
	if p_Table == nil then
		m_Logger:Warning("No table received")
		return nil
	end

	for l_Key, l_Value in pairs(p_Table) do
		if l_Key == 'transform' then
			local s_LinearTransform = LinearTransform(
				Vec3(l_Value.left.x, l_Value.left.y, l_Value.left.z),
				Vec3(l_Value.up.x, l_Value.up.y, l_Value.up.z),
				Vec3(l_Value.forward.x, l_Value.forward.y, l_Value.forward.z),
				Vec3(l_Value.trans.x, l_Value.trans.y, l_Value.trans.z))

			p_Table[l_Key] = s_LinearTransform
		elseif type(l_Value) == "table" then
			l_Value = DecodeParams(l_Value)
		end
	end

	return p_Table
end

function ToWorld(p_Local, p_ParentWorld)
	p_Local = SanitizeLT(p_Local)
	p_ParentWorld = SanitizeLT(p_ParentWorld)

	local s_LinearTransform = LinearTransform()

	local s_MatrixParent = matrix {
		{ p_ParentWorld.left.x, p_ParentWorld.left.y, p_ParentWorld.left.z, 0 },
		{ p_ParentWorld.up.x, p_ParentWorld.up.y, p_ParentWorld.up.z, 0 },
		{ p_ParentWorld.forward.x, p_ParentWorld.forward.y, p_ParentWorld.forward.z, 0 },
		{ p_ParentWorld.trans.x, p_ParentWorld.trans.y, p_ParentWorld.trans.z, 1 }
	}

	local s_MatrixLocal = matrix {
		{ p_Local.left.x, p_Local.left.y, p_Local.left.z, 0 },
		{ p_Local.up.x, p_Local.up.y, p_Local.up.z, 0 },
		{ p_Local.forward.x, p_Local.forward.y, p_Local.forward.z, 0 },
		{ p_Local.trans.x, p_Local.trans.y, p_Local.trans.z, 1 }
	}

	local s_MatrixWorld = s_MatrixLocal * s_MatrixParent

	s_LinearTransform.left = Vec3(s_MatrixWorld[1][1], s_MatrixWorld[1][2], s_MatrixWorld[1][3])
	s_LinearTransform.up = Vec3(s_MatrixWorld[2][1], s_MatrixWorld[2][2], s_MatrixWorld[2][3])
	s_LinearTransform.forward = Vec3(s_MatrixWorld[3][1], s_MatrixWorld[3][2], s_MatrixWorld[3][3])
	s_LinearTransform.trans = Vec3(s_MatrixWorld[4][1], s_MatrixWorld[4][2], s_MatrixWorld[4][3])

	return SanitizeLT(s_LinearTransform)
end

function ToLocal(p_World, p_ParentWorld)
	p_World = SanitizeLT(p_World)
	p_ParentWorld = SanitizeLT(p_ParentWorld)

	local s_LinearTransform = LinearTransform()

	local s_MatrixParent = matrix {
		{ p_ParentWorld.left.x, p_ParentWorld.left.y, p_ParentWorld.left.z, 0 },
		{ p_ParentWorld.up.x, p_ParentWorld.up.y, p_ParentWorld.up.z, 0 },
		{ p_ParentWorld.forward.x, p_ParentWorld.forward.y, p_ParentWorld.forward.z, 0 },
		{ p_ParentWorld.trans.x, p_ParentWorld.trans.y, p_ParentWorld.trans.z, 1 }
	}

	local s_MatrixWorld = matrix {
		{ p_World.left.x, p_World.left.y, p_World.left.z, 0 },
		{ p_World.up.x, p_World.up.y, p_World.up.z, 0 },
		{ p_World.forward.x, p_World.forward.y, p_World.forward.z, 0 },
		{ p_World.trans.x, p_World.trans.y, p_World.trans.z, 1 }
	}

	local s_MatrixParent_Inv = matrix.invert(s_MatrixParent)
	local s_MatrixLocal = s_MatrixWorld * s_MatrixParent_Inv


	s_LinearTransform.left = Vec3(s_MatrixLocal[1][1], s_MatrixLocal[1][2], s_MatrixLocal[1][3])
	s_LinearTransform.up = Vec3(s_MatrixLocal[2][1], s_MatrixLocal[2][2], s_MatrixLocal[2][3])
	s_LinearTransform.forward = Vec3(s_MatrixLocal[3][1], s_MatrixLocal[3][2], s_MatrixLocal[3][3])
	s_LinearTransform.trans = Vec3(s_MatrixLocal[4][1], s_MatrixLocal[4][2], s_MatrixLocal[4][3])

	return SanitizeLT(s_LinearTransform)
end

function SanitizeLT(p_LinearTransform)
	p_LinearTransform.left = SanitizeVec3(p_LinearTransform.left)
	p_LinearTransform.up = SanitizeVec3(p_LinearTransform.up)
	p_LinearTransform.forward = SanitizeVec3(p_LinearTransform.forward)
	p_LinearTransform.trans = SanitizeVec3(p_LinearTransform.trans)

	return p_LinearTransform
end

function SanitizeVec3(p_Vec3)
	p_Vec3.x = SanitizeFloat(p_Vec3.x)
	p_Vec3.y = SanitizeFloat(p_Vec3.y)
	p_Vec3.z = SanitizeFloat(p_Vec3.z)

	return p_Vec3
end

function SanitizeFloat(p_Float)
	if math.abs(p_Float) < 0.0001 or math.abs(p_Float) > 1000000 then
		return 0
	end

	return p_Float
end

function SanitizeEnum(p_Enum)
	return math.floor(0.01 + p_Enum)
end

function InverseSafe(p_Float)
	if p_Float > 0.00000000000001 then
		return 1.0 / p_Float
	else
		return 0.0
	end
end

function InverseVec3(p_Vec3)
	return Vec3(InverseSafe(p_Vec3.x), InverseSafe(p_Vec3.y), InverseSafe(p_Vec3.z));
end

function InverseQuat(p_Quat)
	return Quat(InverseSafe(p_Quat.x), InverseSafe(p_Quat.y), InverseSafe(p_Quat.z), InverseSafe(p_Quat.w));
end

function dus_MatrixParent(o)
	if o == nil then
		m_Logger:Write("tried to load jack shit")
	end

	if type(o) == 'table' then
		local s = '{ '

		for k, v in pairs(o) do
			if type(k) ~= 'number' then k = '"' .. k .. '"' end
			s = s .. '[' .. k .. '] = ' .. dus_MatrixParent(v) .. ','
		end

		return s .. '} '
	else
		return tostring(o)
	end
end

-- Don't use, use GameObject.origin == GameObjectOriginType.Vanilla instead
function IsVanilla(p_Guid)
	m_Logger:Warning('Don\'t use IsVanilla(), use GameObject.origin instead')
	if p_Guid == nil then
		return false
	end

	return p_Guid:sub(1, 8):upper() == VANILLA_GUID_PREFIX
end

function Set(p_List)
	local p_Set = {}

	for _, l_Value in ipairs(p_List) do p_Set[l_Value] = true end

	return p_Set
end

function h()
	local p_Vars = { "A", "B", "C", "D", "E", "F", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" }
	return p_Vars[math.floor(MathUtils:GetRandomInt(1, 16))] .. p_Vars[math.floor(MathUtils:GetRandomInt(1, 16))]
end

---@return Guid guid
function GenerateTempGuid()
	return Guid(TEMP_GUID_PREFIX .. "-" .. h() .. h() .. "-" .. h() .. h() .. "-" .. h() .. h() .. "-" .. h() .. h() .. h() .. h() .. h() .. h(), "D")
end

--- Generates a random guid.
---@return Guid guid
function GenerateCustomGuid()
	return Guid(CUSTOMOBJ_GUID_PREFIX .. "-" .. h() .. h() .. "-" .. h() .. h() .. "-" .. h() .. h() .. "-" .. h() .. h() .. h() .. h() .. h() .. h(), "D")
end

---@return Guid guid
function GenerateNoHavokGuid(p_ParentGuid, p_Name, p_Transform, p_Increment)
	-- Calculate offset from increment and extra data
	local s_IntHash = MathUtils:FNVHash(p_Name .. tostring(p_Transform))
	s_IntHash = math.abs(s_IntHash)
	local s_Offset = s_IntHash + p_Increment

	local s_NewGuid = OffsetGuid(p_ParentGuid, s_Offset, NOHAVOK_GUID_PREFIX)
	-- print(tostring(s_NewGuid) .. "  -   " .. tostring(p_ParentGuid) .. "  -   " .. s_Offset)
	return s_NewGuid
end

---@param p_ParentGuid Guid|string
---@param p_Offset number
---@return Guid
function GenerateChildGuid(p_ParentGuid, p_Offset)
	return OffsetGuid(p_ParentGuid, p_Offset)
end

---Adds an offset to a guid, also allowing a prefix for the first part of the guid
---@param p_OriginalGuid Guid | string
---@param p_Offset number
---@param p_Prefix string?
---@return Guid
function OffsetGuid(p_OriginalGuid, p_Offset, p_Prefix)
	-- Split parent guid
	---@diagnostic disable-next-line: param-type-mismatch
	local s_OriginalGuidParts = string.split(tostring(p_OriginalGuid), '-')

	-- Convert last part of guid from hex to dec number
	local s_GuidPart2Num = tonumber(s_OriginalGuidParts[2], 16)
	local s_GuidPart3Num = tonumber(s_OriginalGuidParts[3], 16)
	local s_GuidPart4Num = tonumber(s_OriginalGuidParts[4], 16)
	local s_GuidPart5Num = tonumber(s_OriginalGuidParts[5], 16)
	-- Add offset to the last part of the guid and convert it back to hex
	local s_NewGuidPart2Padded = string.format("%04x", s_GuidPart2Num ~ p_Offset):sub(-4):upper()
	local s_NewGuidPart3Padded = string.format("%04x", s_GuidPart3Num ~ p_Offset):sub(-4):upper()
	local s_NewGuidPart4Padded = string.format("%04x", s_GuidPart4Num ~ p_Offset):sub(-4):upper()
	local s_NewGuidPart5Padded = string.format("%012x", s_GuidPart5Num ~ p_Offset * p_Offset):sub(-12):upper()
	-- Merge the parts into a new guid
	p_Prefix = p_Prefix or s_OriginalGuidParts[1]
	local s_NewGuidString = p_Prefix .. '-' .. s_NewGuidPart2Padded .. '-' .. s_NewGuidPart3Padded .. '-' .. s_NewGuidPart4Padded .. '-' .. s_NewGuidPart5Padded
	-- local s_NewGuidString = p_Prefix .. '-' .. s_OriginalGuidParts[2] .. '-' .. s_OriginalGuidParts[3] .. '-' .. s_OriginalGuidParts[4] .. '-' .. s_NewGuidEndPadded
	return Guid(s_NewGuidString)
end

---@param p_Name string
---@param p_Transform LinearTransform|table
---@param p_Increment number
---@return Guid
function GenerateVanillaGuid(p_Name, p_Transform, p_Increment)
	local s_IntHash = MathUtils:FNVHash(p_Name .. tostring(p_Transform))

	s_IntHash = s_IntHash + p_Increment

	local s_HashAsString = tostring(s_IntHash)
	s_HashAsString = s_HashAsString:gsub('-', '1')

	--m_Logger:Write("created hash" .. hashAsString)

	return PadAndCreateGuid(VANILLA_GUID_PREFIX, s_HashAsString)
end

---@param p_Number number
---@param p_StringLength number
---@return string
function GetPaddedNumberAsString(p_Number, p_StringLength)
	local s_Number_String = tostring(p_Number)
	local s_Prefix = ""

	if string.len(s_Number_String) < p_StringLength then
		for _ = 1, p_StringLength - string.len(s_Number_String) do
			s_Prefix = s_Prefix .. "0"
		end
	else
		local s_TrimSize = ((string.len(s_Number_String) - p_StringLength) + 1) * -1
		s_Number_String = s_Number_String:sub(1, s_TrimSize)
	end

	return s_Prefix .. s_Number_String
end

-- Generates a guid based on a given number. Used for vanilla objects.
function PadAndCreateGuid(p_Prefix, p_Hash)
	return Guid(p_Prefix .. "-0000-0000-0000-" .. GetPaddedNumberAsString(p_Hash, 12), "D")
end

function GetLength(T)
	local s_Count = 0

	for _ in pairs(T) do s_Count = s_Count + 1 end

	return s_Count
end

function dump(o)
	if o == nil then
		m_Logger:Write("No table?")
	end
	if type(o) == 'table' then
		local s = '{ '

		for k, v in pairs(o) do
			if type(k) ~= 'number' then k = '"' .. k .. '"' end
			s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
		end

		return s .. '} '
	else
		return tostring(o)
	end
end

function Set(p_List)
	local s_Set = {}

	for _, l_Value in ipairs(p_List) do s_Set[l_Value] = true end

	return s_Set
end
