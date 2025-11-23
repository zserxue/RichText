--!strict
local RichText = {}

local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Stack = require(script.Parent.Stack)

type Tag = {
	Type: "Tag",
	Name: string,
	Opening: boolean,
	Content: { [string]: string },
}

type Text = {
	Type: "Text",
	Content: string,
}

type Properties = {
	DerichDelay: number,
	AfterEnrichDelay: number,
	TypewriteTime: number,
	Sound: Sound,
}

type TextContainer = TextLabel | TextBox | TextButton

local Connections: { [Folder]: { RBXScriptConnection } } = {}

local Modules = {}
for _, Child in script.Tags:GetChildren() do
	if not Child:IsA("ModuleScript") then
		continue
	end
	Modules[Child.Name] = require(Child)
end

function RichText.ReadTag(Tag: string): Tag?
	local ValidTag = string.match(Tag, "<%s*/?%a+(.-)%s*>")
	if not ValidTag then -- No match found means the tag is invalid
		warn(`Parsed Tag ({Tag}) could not be read.`)
		return
	end

	while #ValidTag > 0 do
		local Attribute = string.match(ValidTag, '^%s+%a+%s*=%s*".-"')
		if not Attribute then -- Tag is invalid, syntax error with attributes
			warn(`Parsed Tag ({Tag}) could not be read.`)
			return
		end

		ValidTag = string.sub(ValidTag, #Attribute + 1, -1)
	end

	Tag = string.sub(Tag, 2, -2) -- Strip away the first and last character.

	local NameChunk = string.match(Tag, "^%s*/?%a+%s*") :: string -- We know this has to yield a result, otherwise the pattern above would have failed
	local Opening = string.find(NameChunk, "/") == nil -- If there is no forward slash, it is an opening tag
	local Name = string.gsub(NameChunk, "[%s/]", "") -- Removing all whitespace and forward slashes will leave only the name

	local AttributesChunk = string.sub(Tag, #NameChunk + 1, -1) -- The rest of the tag is all the attributes
	local Content = {} -- A dictionary containing all attributes

	for Attribute in string.gmatch(AttributesChunk, '%a+%s*=%s*".-"') do -- This loops over each attribute by matching the pattern of an attribute repeatedly through gmatch
		local Key, Value = table.unpack(string.split(Attribute, "="))
		Value = string.sub(Value, 2, -2) -- Remove the quotes around the value
		Content[Key] = Value -- Add attribute to content table
	end

	return { -- Build tag table and return it
		Type = "Tag",
		Name = Name,
		Opening = Opening,
		Content = Content,
	}
end

function RichText.ParseText(Input: string): { Tag | Text }
	local Tokens: { Tag | Text } = {}

	while #Input > 0 do
		local TagStart, TagEnd = string.find(Input, "<.->") -- Using the simple pattern to find tags.

		-- If there is no tag, process the rest of the string
		-- If there is a tag, and it is at the beginning, process it
		-- If there is a tag, but it is not at the beginning, process up until the tag
		local ProcessingTag = TagStart == 1
		local ChunkEnd = ProcessingTag and TagEnd or TagStart and TagStart - 1 or #Input

		local Chunk = string.sub(Input, 1, ChunkEnd) -- Separate the chunk

		if ProcessingTag then -- We are processing a tag
			table.insert(Tokens, RichText.ReadTag(Chunk) or {
				Type = "Text",
				Content = Chunk,
			})
		else -- We are processing text, just create a token with the content being the raw text
			table.insert(Tokens, {
				Type = "Text",
				Content = Chunk,
			})
		end

		Input = string.sub(Input, ChunkEnd + 1, -1) -- Remove the chunk we processed
	end

	return Tokens
end

function RichText.ValidateTokens(Tokens: { Tag | Text }): boolean
	local Tags = Stack.new()
	for _, Token in Tokens do
		if Token.Type ~= "Tag" then
			continue
		end -- We only care about tags for this validation
		if Token.Name == "br" then
			continue
		end

		if not Modules[Token.Name] then -- Tag does not exist
			warn(`Invalid token ({Token.Name}), tag does not exist.`)
			return false -- Invalidate tokens
		end

		for Attribute, _ in Token.Content do
			if not table.find(Modules[Token.Name].Attributes, Attribute) then -- Tag does not support attribute
				warn(`Invalid attribute ({Attribute}) defined for tag ({Token.Name}).`)
				return false -- Invalidate tokens
			end
		end

		if Token.Opening then
			Tags:Push(Token.Name) -- If it is an opening tag, push it to the stack
		else
			if next(Token.Content) ~= nil then
				warn(
					`Warning, attributes defined for closing tag ({Token.Name}), please define attributes in opening tag instead.`
				)
			end

			if Tags:Empty() then
				warn(`Unbalanced Tags. Could not close <{Token.Name}>.`)
				return false -- Invalidate tokens
			end

			local Top = Tags:Pop() -- Remove tag from top of stack
			if Top ~= Token.Name then -- Tag name mismatch
				warn(`Invalid nesting of Tags. Expected </{Top}>, got </{Token.Name}>.`) -- Output expected and recieved name of tag for debugging
				return false -- Invalidate tokens
			end
		end
	end

	if not Tags:Empty() then -- If not all tags were closed
		for _, Tag: Tag in Tags do
			warn(`Missing closing tag </{Tag}>.`) -- Output their name for debugging
		end
		return false -- Invalidate tokens
	end

	return true -- No validation issues found
end

local function BuildLabel(Text: string, RichTextContainer: Folder, State: Stack.Stack): ()
	local Frame = Instance.new("Frame")
	Frame.BackgroundTransparency = 1

	local Label = Instance.new("TextLabel")
	Label.BackgroundTransparency = 1 -- We want to show the background of the original label instead
	Label.Text = Text
	Label.LayoutOrder = #RichTextContainer:GetChildren()

	local TextBounds: Vector2 = RichTextContainer:GetAttribute("TextBounds")
	local TextFont: Font = RichTextContainer:GetAttribute("Font")
	local FontSize: number = math.ceil(TextBounds.Y)

	Label.FontFace = RichTextContainer:GetAttribute("FontFace")
	Label.LineHeight = RichTextContainer:GetAttribute("LineHeight")
	Label.TextColor3 = RichTextContainer:GetAttribute("TextColor3")
	Label.TextSize = FontSize
	Label.TextStrokeColor3 = RichTextContainer:GetAttribute("TextStrokeColor3")
	Label.TextStrokeTransparency = RichTextContainer:GetAttribute("TextStrokeTransparency")
	Label.TextTransparency = RichTextContainer:GetAttribute("TextTransparency")

	local Width = TextService:GetTextSize(Text, FontSize, TextFont, Vector2.one * math.huge).X

	Frame.Size = UDim2.fromOffset(Width, FontSize)
	Label.Size = UDim2.fromScale(1, 1)
	Label.Parent = Frame
	Frame.Parent = RichTextContainer

	local Attributes = {}
	for _, Tag in State do
		local Table = Attributes[Tag.Name] or {}
		Attributes[Tag.Name] = Table

		for Key, Value in Tag.Content do
			Table[Key] = Value
		end
	end

	for Tag, Table in Attributes do
		for _, Connection in Modules[Tag].Apply(Label, Table) do
			table.insert(Connections[RichTextContainer], Connection)
		end
	end
end

function RichText.EnrichAsync(TextContainer: TextContainer, Text: string?, Properties: Properties): ()
	local RichTextContainer = Instance.new("Folder")
	RichTextContainer.Name = "<RichTextContainer>" -- Name that is unlikely to be used by other systems
	RichTextContainer.Parent = TextContainer

	Connections[RichTextContainer] = {}

	TextContainer = TextContainer :: TextLabel
	Text = Text or TextContainer.Text

	local VerticalAlignment = TextContainer:GetAttribute("VerticalAlignment")
	local HorizontalAlignment = TextContainer:GetAttribute("HorizontalAlignment")

	local Layout = Instance.new("UIListLayout")
	Layout.FillDirection = Enum.FillDirection.Horizontal
	Layout.VerticalAlignment = VerticalAlignment or Enum.VerticalAlignment.Center
	Layout.HorizontalAlignment = HorizontalAlignment or Enum.HorizontalAlignment.Center
	Layout.ItemLineAlignment = Enum.ItemLineAlignment.End
	Layout.Wraps = TextContainer.TextWrapped
	Layout.Parent = RichTextContainer

	TextContainer.Text = " "

	RichTextContainer:SetAttribute("Raw", Text)
	RichTextContainer:SetAttribute("FontFace", TextContainer.FontFace)
	RichTextContainer:SetAttribute("Font", TextContainer.Font)
	RichTextContainer:SetAttribute("LineHeight", TextContainer.LineHeight)
	RichTextContainer:SetAttribute("TextColor3", TextContainer.TextColor3)
	RichTextContainer:SetAttribute("TextBounds", TextContainer.TextBounds)
	RichTextContainer:SetAttribute("TextStrokeColor3", TextContainer.TextStrokeColor3)
	RichTextContainer:SetAttribute("TextStrokeTransparency", TextContainer.TextStrokeTransparency)
	RichTextContainer:SetAttribute("TextTransparency", TextContainer.TextTransparency)

	local Tokens = RichText.ParseText(Text) -- Parse the text of the TextContainer
	if not RichText.ValidateTokens(Tokens) then
		return
	end -- Validate the tokens and halt if invalid

	local LetterwiseCount = 0
	local State = Stack.new()

	for _, Token in Tokens do -- Iterate over all tokens
		if Token.Type == "Tag" then -- Tags affect the state stack
			if Token.Name == "br" then
				local Linebreak = Instance.new("Frame")
				Linebreak.BackgroundTransparency = 1
				Linebreak.Size = UDim2.fromScale(1, 0)
				Linebreak.Parent = RichTextContainer
				continue
			end

			if Token.Opening then
				State:Push(Token)
				if Modules[Token.Name].Letterwise then
					LetterwiseCount += 1
				end
			else
				State:Pop()
				if Modules[Token.Name].Letterwise then
					LetterwiseCount -= 1
				end
			end
		else -- Text is create using label
			if LetterwiseCount == 0 then
				BuildLabel(Token.Content, RichTextContainer, State)
			else
				for _, Character in string.split(Token.Content, "") do
					BuildLabel(Character, RichTextContainer, State)
					task.wait(if not Properties then 0.05 else Properties.TypewriteTime)
				end
			end
		end
	end
end

function RichText.Derich(TextContainer: TextContainer, Delay: number?): ()
	local RichTextContainer: Instance? = TextContainer:FindFirstChild("<RichTextContainer>")
	if not RichTextContainer or not RichTextContainer:IsA("Folder") then
		return
	end

	TextContainer = TextContainer :: TextLabel

	if not RichTextContainer then
		return
	end

	if Delay then
		for _, Frame in RichTextContainer:GetChildren() do
			if Frame.ClassName ~= "Frame" then
				continue
			end

			for _, TextLabel in Frame:GetChildren() do
				if TextLabel.ClassName ~= "TextLabel" then
					continue
				end

				TextLabel = TextLabel :: TextLabel
				if TextLabel.TextTransparency == 1 then
					continue
				end

				TweenService:Create(
					TextLabel,
					TweenInfo.new(Delay, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ TextTransparency = 1 }
				):Play()
			end
		end

		task.wait(Delay)

		for _, Connection in Connections[RichTextContainer] do
			Connection:Disconnect()
		end

		table.clear(Connections[RichTextContainer])

		RichTextContainer:Destroy()
	else
		for _, Connection in Connections[RichTextContainer] do
			Connection:Disconnect()
		end

		table.clear(Connections[RichTextContainer])

		RichTextContainer:Destroy()
	end

	Delay = Delay or 0.5
end

function RichText.EnrichAndDerichAsync(TextContainer: TextContainer, Text: string?, Properties: any)
	setmetatable(Properties, {
		__index = {
			DerichDelay = 0.3,
			AfterEnrichDelay = 1,
			TypewriteTime = 0.05,
		},
	})

	RichText.EnrichAsync(TextContainer, Text, Properties)

	task.wait(Properties.AfterEnrichDelay)

	if not TextContainer then
		return
	end

	RichText.Derich(TextContainer, Properties.DerichDelay)
end

return RichText
