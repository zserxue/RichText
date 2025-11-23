local RunService = game:GetService("RunService")

return {
	Letterwise = true,
	Attributes = { "xmag", "ymag" },
	Apply = function(Label: TextLabel, Attributes: { [string]: string }): { RBXScriptConnection }
		local Connections = {}

		local XMagnitude = tonumber(Attributes.xmag) or 1
		local YMagnitude = tonumber(Attributes.ymag) or 1

		local LastTick = time()
		table.insert(
			Connections,
			RunService.RenderStepped:Connect(function()
				local DeltaTime = time() - LastTick
				if DeltaTime <= 0.05 then
					return
				end
				LastTick = time()

				Label.Position = UDim2.fromOffset(
					math.round((math.random() - 0.5) * 2) * XMagnitude,
					math.round((math.random() - 0.5) * 2) * YMagnitude
				)
			end)
		)

		return Connections
	end,
}
