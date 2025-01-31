---@class GameObject
GameObject = class 'GameObject'

local m_Logger = Logger("GameObject", false)
local m_TraceableField_Suffix = "_original_value"

function GameObject:__init(arg)
	---@type Guid
	self.guid = arg.guid
	self.creatorName = arg.creatorName -- never gets sent to js
	---@type CtrRef
	self.blueprintCtrRef = arg.blueprintCtrRef
	self.origin = arg.origin -- never gets sent to js
	self.gameEntities = arg.gameEntities or { }
	self.children = arg.children or {} -- never gets sent to js
	---@type Realm|integer
	self.realm = arg.realm
	self.isUserModified = true
	self.userModifiedFields = {}
	---@type CtrRef
	self.originalRef = arg.originalRef -- never gets sent to js
	self.localTransform = arg.localTransform
	self.overrides = arg.overrides or {}
	self.internalBlueprint = nil
	self.name = arg.name
	---@type GameObjectParentData
	self.parentData = arg.parentData
	self.transform = arg.transform -- world transform
	self.variation = arg.variation
	self.isDeleted = arg.isDeleted --> only vanilla objects, dont appear in the browser anymore. entities get disabled, because we cannot destroy them
	self.isEnabled = arg.isEnabled

	self:RegisterUserModifiableField("name", arg.name)
	self:RegisterUserModifiableField("parentData", arg.parentData)
	self:RegisterUserModifiableField("transform", arg.transform)
	self:RegisterUserModifiableField("localTransform", arg.localTransform)
	self:RegisterUserModifiableField("variation", arg.variation)
	self:RegisterUserModifiableField("isDeleted", arg.isDeleted)
	self:RegisterUserModifiableField("isEnabled", arg.isEnabled)
	self:RegisterUserModifiableField("overrides", self.overrides)
end

function GameObject:RegisterUserModifiableField(p_FieldName, p_DefaultValue)
	self[p_FieldName] = p_DefaultValue
	self[p_FieldName .. m_TraceableField_Suffix] = p_DefaultValue
end

function GameObject:SetField(p_FieldName, p_NewValue, p_AutoModified)
	self[p_FieldName] = p_NewValue
	local originalValue = self[p_FieldName .. m_TraceableField_Suffix]
	local newValue = self[p_FieldName]

	if not p_AutoModified then
		self.userModifiedFields[p_FieldName] = newValue ~= originalValue
	end
end

function GameObject:IsUserModified()
	if self.origin == GameObjectOriginType.Custom or self.origin == GameObjectOriginType.CustomChild then
		return true
	end

	for l_FieldName, l_IsUserModified in pairs(self.userModifiedFields) do
		if l_IsUserModified == true then
			m_Logger:Write("GameObject: " .. self.name .. " has modified field: " .. l_FieldName .. " - original value: " .. tostring(self[l_FieldName .. m_TraceableField_Suffix]) .. " | new value: " .. tostring(self[l_FieldName]))
			return true
		end
	end

	return false
end

function GameObject:Disable(p_AutoModified)
	if self.children ~= nil then
		for _, l_ChildGameObject in pairs(self.children) do
			l_ChildGameObject:Disable(true)
		end
	end

	if self.gameEntities ~= nil then
		for _, l_GameEntity in pairs(self.gameEntities) do
			if l_GameEntity ~= nil then
				l_GameEntity:Disable()
			end
		end
	end

	self:SetField("isEnabled", false, p_AutoModified)
end

function GameObject:Enable(p_AutoModified)
	if self.children ~= nil then
		for _, l_ChildGameObject in pairs(self.children) do
			l_ChildGameObject:Enable(true)
		end
	end

	if self.gameEntities ~= nil then
		for _, l_GameEntity in pairs(self.gameEntities) do
			if l_GameEntity ~= nil then
				l_GameEntity:Enable()
			end
		end
	end

	self:SetField("isEnabled", true, p_AutoModified)
end

function GameObject:MarkAsDeleted(p_AutoModified)
	if self.origin == GameObjectOriginType.Custom or self.origin == GameObjectOriginType.CustomChild then
		m_Logger:Error("Cant delete a non-vanilla object, use destroy instead")
		return
	end

	if self.children ~= nil then
		for _, l_ChildGameObject in pairs(self.children) do
			l_ChildGameObject:MarkAsDeleted(true)
		end
	end

	if self.gameEntities ~= nil then
		for _, l_GameEntity in pairs(self.gameEntities) do
			if l_GameEntity ~= nil then
				l_GameEntity:Disable()
			end
		end
	end

	self:SetField("isDeleted", true, p_AutoModified)
end

function GameObject:MarkAsUndeleted(p_AutoModified)
	if self.origin == GameObjectOriginType.Custom or self.origin == GameObjectOriginType.CustomChild then
		m_Logger:Error("Cant undelete a non-vanilla object, use spawn instead")
		return
	end

	if self.children ~= nil then
		for _, l_ChildGameObject in pairs(self.children) do
			l_ChildGameObject:MarkAsUndeleted(true)
		end
	end

	if self.gameEntities ~= nil then
		for _, l_GameEntity in pairs(self.gameEntities) do
			if l_GameEntity ~= nil then
				l_GameEntity:Enable()
			end
		end
	end

	self:SetField("isDeleted", false, p_AutoModified)
end

function GameObject:Destroy() -- this will effectively destroy all entities and childentities. the gameobject becomes useless and needs to be dereferenced
	if self.origin == GameObjectOriginType.Vanilla or self.origin == GameObjectOriginType.NoHavok then
		m_Logger:Error("Cant destroy vanilla object, use disable instead")
		return
	end

	if self.children ~= nil then
		for _, l_ChildGameObject in pairs(self.children) do
			l_ChildGameObject:Destroy()
		end
	end

	if self.gameEntities ~= nil then
		for _, l_GameEntity in pairs(self.gameEntities) do
			if l_GameEntity ~= nil then
				l_GameEntity:Disable()
			end
		end
	end
end

function GameObject:SetTransform(p_LinearTransform, p_UpdateCollision, p_AutoModified)
	if self.children ~= nil then
		for _, l_ChildGameObject in pairs(self.children) do
			if l_ChildGameObject == nil then
				m_Logger:Error("l_ChildGameObject is nil?")
				return false
			end

			-- We calculate the offset to get where the child gameobject should be
			local s_Offset = ToLocal(l_ChildGameObject.transform, self.transform)
			l_ChildGameObject.localTransform = s_Offset
			local s_LinearTransform = ToWorld(s_Offset, p_LinearTransform)

			local s_Response = l_ChildGameObject:SetTransform(s_LinearTransform, p_UpdateCollision, true)

			if not s_Response then
				return false
			end
		end
	end

	if self.gameEntities ~= nil then
		for _, l_GameEntity in pairs(self.gameEntities) do
			if l_GameEntity == nil then
				m_Logger:Error("GameEntity is nil?")
				return false
			end

			local s_Response = l_GameEntity:SetTransform(p_LinearTransform, p_UpdateCollision, self.isEnabled)

			if not s_Response then
				return false
			end
		end
	end

	self:SetField("transform", LinearTransform(p_LinearTransform), p_AutoModified)

	if self.parentData.guid ~= EMPTY_GUID then
		local s_Parent = GameObjectManager:GetGameObject(self.parentData.guid)

		if s_Parent ~= nil then
			local s_LocalTransform = ToLocal(self.transform, s_Parent.transform)
			self:SetField("localTransform", s_LocalTransform, p_AutoModified)
		else
			m_Logger:Write("Could not find parent")
		end
	end

	return true
end

function GameObject:GetGameObjectTransferData()
	local s_GameObjectTransferData = {
		guid = tostring(self.guid),
		name = self.name,
		blueprintCtrRef = self.blueprintCtrRef:GetTable(),
		parentData = self.parentData:GetTable(),
		transform = self.transform,
		localTransform = self.localTransform,
		variation = self.variation,
		isEnabled = self.isEnabled,
		isDeleted = self.isDeleted,
		creatorName = self.creatorName,
		origin = self.origin,
		realm = self.realm,
		isUserModified = self.isUserModified,
		overrides = self.overrides,
		originalRef = self.originalRef:GetTable()
		-- entities have to be set externally
	}

	local s_GameEntityTransferDatas = {}

	for _, l_GameEntity in pairs(self.gameEntities) do
		table.insert(s_GameEntityTransferDatas, l_GameEntity:GetGameEntityTransferData())
	end

	s_GameObjectTransferData.gameEntities = s_GameEntityTransferDatas

	return s_GameObjectTransferData
end

function GameObject:GetEntities()
	local s_Entities = {}

	for _, l_GameEntity in pairs(self.gameEntities) do
		table.insert(s_Entities, l_GameEntity.entity)
	end

	return s_Entities
end
function GameObject:SetOverrides(p_Overrides)
	if not self.internalBlueprint then
		self.internalBlueprint = self.blueprintCtrRef:Get() --:Clone(self.guid)
	end

	m_Logger:Write("Setting overrides")

	for l_Key, l_Field in pairs(p_Overrides) do
		m_Logger:Write(l_Key)
		m_Logger:Write(l_Field)
		self:SetOverride(l_Field)
	end

	self:SetField('overrides', self.overrides) -- Assigning to itself just to trigger the modified field.

	return true
end

function GameObject:SetOverride(p_Field)
	local s_Path = EBXManager:SetField(self.internalBlueprint, p_Field, '')

	if s_Path then
		self.overrides[s_Path] = p_Field
	end

	self:Disable(true)
	self:Enable(true)

	return s_Path ~= '', s_Path
end

function GameObject:HasOverrides()
	if self.overrides then
		return GetLength(self.overrides) > 0
	end

	return false
end

return GameObject
