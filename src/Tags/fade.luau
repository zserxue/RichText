local TweenService = game:GetService("TweenService")

return {
	Letterwise = false,
	Attributes = { "time" },
	Apply = function(Label: TextLabel, Attributes: { [string]: string }): { RBXScriptConnection }
		local time = tonumber(Attributes.time) or 0.3
		Label.TextTransparency = 1
		TweenService
			:Create(
				Label,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ TextTransparency = 0 }
			)
			:Play()
		return {}
	end,
}
