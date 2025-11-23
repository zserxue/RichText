local TweenService = game:GetService("TweenService")

return {
	Letterwise = true,
	Attributes = { "time" },
	Apply = function(Label: TextLabel, Attributes: { [string]: string }): { RBXScriptConnection }
		local Time = tonumber(Attributes.time) or 0.8

		Label.Size = UDim2.fromScale(4, 0)
		Label.TextXAlignment = Enum.TextXAlignment.Right
		TweenService:Create(
			Label,
			TweenInfo.new(Time, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(1, 1) }
		):Play()
		return {}
	end,
}
