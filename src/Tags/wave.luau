local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

return {
	Letterwise = true,
	Attributes = { "offset" },
	Apply = function(Label: TextLabel, Attributes: { [string]: string }): { RBXScriptConnection }
		local Connections = {}

		local Offset = tonumber(Attributes.offset) or 2
		local TweenUp = TweenService:Create(
			Label,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ Position = UDim2.fromOffset(0, Offset) }
		)
		local TweenDown = TweenService:Create(
			Label,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ Position = UDim2.fromOffset(0, -Offset) }
		)
		local CurrentTween = TweenDown

		TweenDown:Play()

		table.insert(
			Connections,
			RunService.RenderStepped:Connect(function()
				if CurrentTween.PlaybackState == Enum.PlaybackState.Completed then
					if CurrentTween == TweenUp then
						CurrentTween = TweenDown
					else
						CurrentTween = TweenUp
					end

					CurrentTween:Play()
				end
			end)
		)

		return Connections
	end,
}
